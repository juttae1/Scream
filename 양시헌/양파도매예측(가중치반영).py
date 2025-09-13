# -*- coding: utf-8 -*-
"""
일별 도매가격 예측 파이프라인 (양파)
- 입력: 양파도매/*.csv  (가능 헤더: [일자, 평균가] 또는 [구분, 평균])
- 사용: 일자/평균가만 추출하여 병합(같은 일자는 평균)
- 피처: 달력/주기/추세/다중 랙/EMA/롤링/차분/수익률 (+옵션 YoY)
- 학습: 2020~2024
- 검증: '실제 레이블이 있는 마지막 날짜' 기준 마지막 90일
- 테스트: 2025-01-01 ~ 2025-09-12
- 미래예측: 2025-09-13 ~ 2025-12-31 (순차 예측, 강제)
- 다운웨이트: 2022-01~04 (저장양파 소진 → 폭락)
- 출력: outputs_daily/ 아래 CSV/PNG 저장
"""

import numpy as np
import pandas as pd
from pathlib import Path
from glob import glob
import xgboost as xgb
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import matplotlib.pyplot as plt

# =======================
# 설정
# =======================
DATA_DIR   = Path("양파도매")     # 사용 폴더명
TARGET_COL = "평균가"
OUT_DIR    = Path("outputs_daily")
OUT_DIR.mkdir(parents=True, exist_ok=True)

USE_YOY        = False
EVAL_END_2025  = pd.Timestamp("2025-09-12")
FORECAST_START = pd.Timestamp("2025-09-13")
FORECAST_END   = pd.Timestamp("2025-12-31")

FILL_RECENT_DAYS = 180
PREF = "양파_평균가"

# ▼ 다운웨이트 기간(캘린더 기반): [(시작,끝,가중치), ...]
DW_PERIODS = [
    ("2022-01-01", "2022-04-30", 0.3),   # 저장양파 소진 여파로 폭락 구간
]
np.random.seed(42)

# =======================
# 유틸
# =======================
def smape(y_true, y_pred):
    denom = np.abs(y_true) + np.abs(y_pred)
    m = denom != 0
    return 100.0 * np.mean(2.0 * np.abs(y_pred - y_true)[m] / denom[m])

def report(y_true, y_pred, tag):
    mae  = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    r2   = r2_score(y_true, y_pred)
    s    = smape(y_true, y_pred)
    print(f"{tag} -> MAE:{mae:.1f}  RMSE:{rmse:.1f}  R^2:{r2:.3f}  SMAPE:{s:.2f}%")

# =======================
# 로딩
# =======================
def read_one_csv(path: Path) -> pd.DataFrame:
    """일자/평균가만 사용. 구형 포맷(구분/평균)도 허용. 같은 일자는 평균."""
    df = pd.read_csv(path, header=0, dtype=str, encoding="utf-8", engine="python", on_bad_lines="skip")
    df.columns = df.columns.str.strip()

    if "일자" in df.columns and TARGET_COL in df.columns:
        date_s = df["일자"].astype(str)
        val_s  = df[TARGET_COL].astype(str)
    elif "구분" in df.columns and "평균" in df.columns:
        date_s = df["구분"].astype(str)
        val_s  = df["평균"].astype(str)
    else:
        raise ValueError(f"[{path.name}] '일자/평균가' 또는 '구분/평균' 컬럼이 필요합니다.")

    date_str = (
        date_s.str.replace(r"[^0-9\.\-\/]", "", regex=True)
              .str.replace("/", ".", regex=False)
              .str.replace("-", ".", regex=False)
    )
    dt = pd.to_datetime(date_str, format="%Y.%m.%d", errors="coerce")

    val = pd.to_numeric(
        val_s.str.replace(",", "", regex=False).str.replace("원", "", regex=False).str.strip(),
        errors="coerce"
    )

    out = pd.DataFrame({"date": dt, TARGET_COL: val}).dropna()
    out = out.groupby("date", as_index=False)[TARGET_COL].mean()
    return out

# =======================
# 피처 (행 유지; 결측은 후처리)
# =======================
def build_features(df: pd.DataFrame, target: str) -> pd.DataFrame:
    s = df.sort_values("date").reset_index(drop=True)
    s["y"] = s[target].astype(float)

    # ffill로 듬성듬성 날짜 안정화(미래 누수 없음: 과거만 사용)
    y_ffill = s["y"].ffill()

    # 달력/계절성
    s["year"]  = s["date"].dt.year
    s["month"] = s["date"].dt.month
    s["day"]   = s["date"].dt.day
    s["dow"]   = s["date"].dt.dayofweek
    s["doy"]   = s["date"].dt.dayofyear
    s["week"]  = s["date"].dt.isocalendar().week.astype(int)
    s["quarter"] = s["date"].dt.quarter
    s["is_harvest"] = s["month"].between(9, 11).astype(int)

    # 연/월 주기
    s["sin_year"]  = np.sin(2*np.pi*s["doy"]/365.25)
    s["cos_year"]  = np.cos(2*np.pi*s["doy"]/365.25)
    s["sin_month"] = np.sin(2*np.pi*s["day"]/31.0)
    s["cos_month"] = np.cos(2*np.pi*s["day"]/31.0)

    # 추세
    base = s["date"].min()
    s["trend"]  = (s["date"] - base).dt.days.astype(float)
    s["trend2"] = s["trend"]**2 / 1e6

    # 랙/EMA/롤링: 보정된 과거값으로 계산
    for L in [1,2,3,7,14,21,28,56,84]:
        s[f"lag_{L}"] = y_ffill.shift(L)

    s["ema_7"]  = y_ffill.shift(1).ewm(span=7,  adjust=False).mean()
    s["ema_28"] = y_ffill.shift(1).ewm(span=28, adjust=False).mean()

    for W in [7,14,28,56]:
        s[f"rmean_{W}"] = y_ffill.shift(1).rolling(W, min_periods=1).mean()
        s[f"rstd_{W}"]  = y_ffill.shift(1).rolling(W, min_periods=1).std()

    # 변화율/차분
    s["diff_1"] = y_ffill.shift(1) - y_ffill.shift(2)
    s["diff_7"] = y_ffill.shift(1) - y_ffill.shift(8)
    s["ret_1"]  = y_ffill.shift(1) / y_ffill.shift(2) - 1
    s["ret_7"]  = y_ffill.shift(1) / y_ffill.shift(8) - 1

    # (옵션) YoY
    if USE_YOY:
        for L in [364, 365, 366]:
            s[f"lag_{L}"] = y_ffill.shift(L)
        s["yoy_diff"]  = y_ffill.shift(1) - y_ffill.shift(366)
        s["yoy_ratio"] = (y_ffill.shift(1) / y_ffill.shift(366)) - 1

    if target in s.columns:
        s = s.drop(columns=[target])
    return s

# =======================
# 순차 예측
# =======================
def recursive_forecast_force(model, base_raw: pd.DataFrame,
                             start_date: pd.Timestamp, end_date: pd.Timestamp,
                             feature_cols, fill_values: pd.Series) -> pd.DataFrame:
    work = base_raw.copy().sort_values("date").reset_index(drop=True)
    preds = []
    for d in pd.date_range(start_date, end_date, freq="D"):
        feat_now = build_features(
            work.rename(columns={TARGET_COL:"val"}).rename(columns={"val":TARGET_COL}),
            TARGET_COL
        )
        row = feat_now.loc[feat_now["date"] == d, feature_cols]
        row = (pd.DataFrame([fill_values]) if row.empty else row.fillna(fill_values))
        y_pred = float(model.predict(row)[0])
        preds.append({"date": d, "pred": y_pred})

        # 예측값 누적(다음 날 랙/EMA/롤링 갱신)
        if (work["date"] == d).any():
            work.loc[work["date"] == d, TARGET_COL] = y_pred
        else:
            work = pd.concat([work, pd.DataFrame({"date":[d], TARGET_COL:[y_pred]})], ignore_index=True)
    return pd.DataFrame(preds)

# =======================
# (선택) 2021~2023 → 2024 예측
# =======================
def backtest_21_23_to_24(feat: pd.DataFrame, feature_cols):
    tr = feat[(feat["date"].dt.year >= 2021) & (feat["date"].dt.year <= 2023) & (feat["y"].notna())].copy()
    te = feat[(feat["date"].dt.year == 2024) & (feat["y"].notna())].copy()
    tr = tr.dropna(subset=feature_cols + ["y"]).reset_index(drop=True)
    te = te.dropna(subset=feature_cols + ["y"]).reset_index(drop=True)

    if len(tr) == 0 or len(te) == 0:
        print("[INFO] 2021~23 또는 2024 데이터가 부족해 백테스트를 건너뜁니다.")
        return

    X_tr, y_tr = tr[feature_cols], tr["y"]
    X_te, y_te = te[feature_cols], te["y"]

    params = dict(
        n_estimators=5000, learning_rate=0.01, max_depth=8,
        subsample=0.8, colsample_bytree=0.8, reg_lambda=2.0, reg_alpha=0.0,
        random_state=42, tree_method="hist", early_stopping_rounds=200, eval_metric="rmse",
    )
    m = xgb.XGBRegressor(**params)
    m.fit(X_tr, y_tr, eval_set=[(X_te, y_te)], verbose=False)

    pred = m.predict(X_te)
    report(y_te, pred, "BACKTEST (2021~23 → 2024)")

    plt.rcParams["font.family"] = "Malgun Gothic"
    plt.rcParams["axes.unicode_minus"] = False
    plt.figure(figsize=(14,6))
    plt.plot(te["date"], y_te, label="실제 2024", linewidth=2)
    plt.plot(te["date"], pred,  label="예측 2024", alpha=0.9)
    plt.plot(te["date"], pd.Series(pred).rolling(7, min_periods=1).mean(), label="예측 2024 (7일MA)", linewidth=2)
    plt.title("양파 도매가 예측 — (학습: 2021~2023 → 예측: 2024)")
    plt.xlabel("날짜"); plt.ylabel("가격(원)")
    plt.grid(True, alpha=0.4); plt.legend(); plt.tight_layout()
    out_png = OUT_DIR / f"plot_2024_{PREF}_from_21_23.png"
    plt.savefig(out_png, dpi=150); plt.show()
    print(f"[저장] 2024 예측 플롯: {out_png}")

    out_csv = OUT_DIR / f"pred_2024_{PREF}_from_21_23.csv"
    pd.DataFrame({"date": te["date"].values, "actual": y_te.values, "pred": pred}).to_csv(out_csv, index=False, encoding="utf-8-sig")
    print(f"[저장] 2024 예측 CSV : {out_csv}")

# =======================
# 메인 파이프라인
# =======================
def main():
    # 병합
    paths = sorted(glob(str(DATA_DIR/"*.csv")))
    if not paths:
        raise FileNotFoundError(f"{DATA_DIR.resolve()} 에 CSV가 없습니다.")
    frames = [read_one_csv(Path(p)) for p in paths]
    raw = (pd.concat(frames, ignore_index=True)
           .drop_duplicates(subset=["date"])
           .sort_values("date"))

    # 학습/평가 범위 제한
    raw = raw[(raw["date"].dt.year>=2020) & (raw["date"].dt.year<=2025)].copy()

    # 날짜 뼈대(연말까지)
    full_dates = pd.date_range(raw["date"].min(), FORECAST_END, freq="D")
    raw = (raw.set_index("date").reindex(full_dates).rename_axis("date").reset_index())

    # 피처
    feat = build_features(
        raw.rename(columns={TARGET_COL:"val"}).rename(columns={"val":TARGET_COL}),
        TARGET_COL
    )

    # 피처 목록
    feature_cols = [c for c in feat.columns if c not in ["date","y", TARGET_COL]]
    assert TARGET_COL not in feature_cols and "y" not in feature_cols

    # ---- 스플릿: '실제 레이블 존재 마지막 날짜' 기준 검증 90일 ----
    labeled = feat[feat["y"].notna()].copy()
    if labeled.empty:
        raise ValueError("레이블(y)이 존재하지 않습니다. 원본 CSV의 '평균가/평균'을 확인해 주세요.")
    last_y_date = labeled["date"].max()
    cut = last_y_date - pd.Timedelta(days=89)

    train = labeled[labeled["date"] < cut].copy()
    valid = labeled[(labeled["date"] >= cut) & (labeled["date"] <= last_y_date)].copy()

    # 결측 제거
    train = train.dropna(subset=feature_cols + ["y"]).reset_index(drop=True)
    valid = valid.dropna(subset=feature_cols + ["y"]).reset_index(drop=True)

    if len(train) == 0:
        raise ValueError("train이 비었습니다. 데이터 기간을 늘리거나 피처 설정을 조정하세요.")

    X_tr, y_tr = train[feature_cols], train["y"]
    X_va, y_va = valid[feature_cols], valid["y"]

    # 결측 보정값(최근 180일 중앙값)
    recent_cut = X_tr["trend"].max() - FILL_RECENT_DAYS if "trend" in X_tr.columns else None
    if recent_cut is not None:
        X_recent = X_tr[X_tr["trend"] >= recent_cut]
        fill_values = X_recent.median(numeric_only=True).reindex(feature_cols)
    else:
        fill_values = X_tr.median(numeric_only=True).reindex(feature_cols)

    # --------- 가중치(2022-01~04 다운웨이트 적용) ---------
    w_tr = np.ones(len(train), dtype=float)
    tr_dates = train["date"].to_numpy()
    for start, end, w in DW_PERIODS:
        mask = (tr_dates >= np.datetime64(start)) & (tr_dates <= np.datetime64(end))
        w_tr[mask] = np.minimum(w_tr[mask], w)
    # ----------------------------------------------------

    # ---- 학습 ----
    params = dict(
        n_estimators=5000, learning_rate=0.01, max_depth=8,
        subsample=0.8, colsample_bytree=0.8, reg_lambda=2.0, reg_alpha=0.0,
        random_state=42, tree_method="hist", eval_metric="rmse",
    )
    model = xgb.XGBRegressor(**params)

    if len(valid) == 0:
        print("[WARN] valid set is empty → fit without eval_set / early_stopping")
        model.fit(X_tr, y_tr, sample_weight=w_tr, verbose=False)
        val_pred = np.array([])
    else:
        model.set_params(early_stopping_rounds=200)
        model.fit(X_tr, y_tr, sample_weight=w_tr,
                  eval_set=[(X_va, y_va)],
                  sample_weight_eval_set=[np.ones(len(valid))],
                  verbose=False)
        val_pred = model.predict(X_va)
        report(y_va, val_pred, "VALID (last 90d)")

    # 평가(~09/12, 2025)
    test_2025 = feat[feat["date"].dt.year==2025].copy()
    mask_eval = (test_2025["date"] <= EVAL_END_2025) & (test_2025["y"].notna())
    test_eval = test_2025.loc[mask_eval].dropna(subset=feature_cols + ["y"]).reset_index(drop=True)
    y_hat_eval = (model.predict(test_eval[feature_cols]) if not test_eval.empty else np.array([]))
    if not test_eval.empty:
        report(test_eval["y"], y_hat_eval, "TEST  (2025~09-12)")

    # 미래 예측(09/13~12/31)
    base_for_forecast = raw[["date", TARGET_COL]].copy()  # 미래는 NaN
    future_df = recursive_forecast_force(
        model=model,
        base_raw=base_for_forecast,
        start_date=FORECAST_START,
        end_date=FORECAST_END,
        feature_cols=feature_cols,
        fill_values=fill_values,
    )
    future_df["pred_ma7"] = future_df["pred"].rolling(7, min_periods=1).mean()

    # =======================
    # 결과 저장/시각화
    # =======================
    eval_df = test_eval[["date","y"]].rename(columns={"y":"actual"}).copy() if not test_eval.empty else pd.DataFrame(columns=["date","actual"])
    if len(y_hat_eval)>0:
        eval_df["pred"] = y_hat_eval
        eval_df["pred_ma7"] = pd.Series(eval_df["pred"]).rolling(7, min_periods=1).mean()
    else:
        if not eval_df.empty:
            eval_df["pred"] = np.nan; eval_df["pred_ma7"] = np.nan

    csv_eval = OUT_DIR / f"pred_2025_{PREF}_upto_{EVAL_END_2025.strftime('%Y%m%d')}.csv"
    eval_df.to_csv(csv_eval, index=False, encoding="utf-8-sig")

    csv_future = OUT_DIR / f"pred_2025_{PREF}_forecast_{FORECAST_START.strftime('%Y%m%d')}_{FORECAST_END.strftime('%Y%m%d')}.csv"
    future_df.to_csv(csv_future, index=False, encoding="utf-8-sig")

    plt.rcParams["font.family"] = "Malgun Gothic"
    plt.rcParams["axes.unicode_minus"] = False
    plt.figure(figsize=(14,6))

    if not eval_df.empty:
        plt.plot(eval_df["date"], eval_df["actual"], label="실제(2025~09-12)", linewidth=2)
        if "pred" in eval_df:
            plt.plot(eval_df["date"], eval_df["pred"],     label="예측(원값·~09/12)", alpha=0.8)
            plt.plot(eval_df["date"], eval_df["pred_ma7"], label="예측(7일MA·~09/12)", linewidth=2)

    plt.plot(future_df["date"], future_df["pred"],     linestyle="--", label="예측(원값·09/13~12/31)", alpha=0.95)
    plt.plot(future_df["date"], future_df["pred_ma7"], linestyle="--", linewidth=2, label="예측(7일MA·09/13~12/31)")

    ymin, ymax = plt.gca().get_ylim()
    plt.axvspan(EVAL_END_2025, FORECAST_END, color="lightgray", alpha=0.25, lw=0)
    plt.axvline(EVAL_END_2025, color="gray", linestyle="--", linewidth=1.5)
    plt.text(EVAL_END_2025, ymax*0.98, "  2025-09-12 (실측 종료)", va="top", ha="left", fontsize=9, color="gray")

    plt.title("양파 도매 평균가: 실측(~09/12) + 미래 순차 예측(09/13~12/31)\n(ffill 안정화 + 2022-01~04 다운웨이트)")
    plt.xlabel("날짜"); plt.ylabel("가격(원)")
    plt.grid(True, alpha=0.4); plt.legend(ncol=2); plt.tight_layout()

    plot_path = OUT_DIR / f"plot_2025_{PREF}_actual_to_0912_and_forecast_to_1231.png"
    plt.savefig(plot_path, dpi=150)
    plt.show()

    print(f"[저장] 평가 CSV : {csv_eval}")
    print(f"[저장] 예측 CSV : {csv_future}")
    print(f"[저장] 통합 플롯: {plot_path}")

    # (선택) 추가 실험
    backtest_21_23_to_24(feat, feature_cols)

# ========= 실행 =========
if __name__ == "__main__":
    main()
