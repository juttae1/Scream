import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secret_service.dart';
import 'log_manager.dart';

/// KAMIS "일별 부류별 도·소매 가격정보" 조회 서비스.
/// 필요한 환경변수(dart-define)
///   KAMIS_CERT_KEY  : p_cert_key 값
///   KAMIS_CERT_ID   : p_cert_id 값
/// 사용 예)
/// flutter run --dart-define=KAMIS_CERT_KEY=xxxx --dart-define=KAMIS_CERT_ID=yourid
class KamisDailyPriceService {
  KamisDailyPriceService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  // 문서 명시 URL은 http. https 응답 이슈 대비 기본은 http로 사용.
  static const _base = 'http://www.kamis.or.kr/service/price/xml.do';
  static const _action = 'dailyPriceByCategoryList';

  // 환경변수에서 주입 (빈 문자열이면 인증 실패 발생 → 사용자에게 안내)
  static const _certKeyEnv = String.fromEnvironment('KAMIS_CERT_KEY');
  static const _certIdEnv = String.fromEnvironment('KAMIS_CERT_ID');
  static String get _certKey => _certKeyEnv.isNotEmpty ? _certKeyEnv : SecretService.kamisCertKey;
  static String get _certId => _certIdEnv.isNotEmpty ? _certIdEnv : SecretService.kamisCertId;

  /// 현재 환경에서 인증 정보가 세팅되었는지 여부
  static bool get configured => _certKey.isNotEmpty && _certId.isNotEmpty;

  /// 디버그용 마스킹된 키 문자열 (앞 4글자 + ...)
  static String maskedKey() {
    if (_certKey.isEmpty) return '(empty)';
    if (_certKey.length <= 8) return _certKey;
    return _certKey.substring(0, 4) + '...' + _certKey.substring(_certKey.length - 4);
  }

  /// 샘플 요청 URL 생성기.
  /// 기본값은 문서 샘플과 동일한 형태(xml)이며, 날짜는 2025-09-11로 설정됩니다(요청에 맞게 변경 가능).
  static String sampleUrl({
    String productClsCode = '02',
    String categoryCode = '200',
    String? countryCode,
    DateTime? date,
    bool convertKg = false,
    String returnType = 'xml',
    bool useOfficialCategoryParam = true, // true -> p_item_category_code, else p_category_code
  }) {
    final day = date ?? DateTime(2025, 9, 11);
    final qp = <String, String>{
      'action': _action,
      'p_product_cls_code': productClsCode,
      if (useOfficialCategoryParam) 'p_item_category_code': categoryCode else 'p_category_code': categoryCode,
      'p_returntype': returnType,
      'p_cert_key': _certKey,
      'p_cert_id': _certId,
      'p_convert_kg_yn': convertKg ? 'Y' : 'N',
      'p_regday': '${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}',
      if (countryCode != null) 'p_country_code': countryCode,
    };
    return Uri.parse(_base).replace(queryParameters: qp).toString();
  }

  /// region 한글 → KAMIS 지역코드. (필요시 확장)
  static String? regionCode(String region) {
    if (region.contains('서울')) return '1101';
    if (region.contains('부산')) return '2100';
    if (region.contains('대구')) return '2200';
    if (region.contains('인천')) return '2300';
    if (region.contains('광주')) return '2401';
    if (region.contains('대전')) return '2501';
    if (region.contains('울산')) return '2601';
    // 소매만 존재하는 지역 다수 → 필요 시 추가
    return null; // null 이면 전체지역
  }

  /// 품목명 → 부류코드 추론 (간단 매핑). 확장 필요시 switch 문 확장.
  /// 100: 식량작물 200: 채소류 300: 특용작물 400: 과일류 500: 축산물 600: 수산물
  static String categoryCodeForItem(String name) {
    // 식량작물(100) / 채소류(200) / 과일류(400) / 수산물(600)
    // 괄호 표기나 부가 설명을 제거하고 매칭(예: '굴(참굴)' 등 대응)
    final cleaned = name.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    // 간단히 소문자화 (한글에는 영향 없음) 및 매칭 편의
    final key = cleaned.toLowerCase();
    // explicit overrides for edge cases (품목별로 다른 분류가 필요할 때 사용)
    // 예: '딸기'를 과일(400)이 아닌 특용작물(300)으로 처리하려면 여기에 추가
    const Map<String, String> overrides = {
      '딸기': '200',
    };
    for (final e in overrides.entries) {
      if (key.contains(e.key)) return e.value;
    }
    const grains = ['쌀', '찹쌀', '콩', '팥', '메밀', '보리', '옥수수', '감자', '고구마'];
    const vegetables = [
      '배추','양배추','시금치','상추','얼갈이배추','오이','호박','토마토','방울토마토','무','당근','열무','건고추','풋고추','붉은고추','피마늘','깐마늘','양파','파','생강','미나리','깻잎','피망','파프리카'
    ];
    const fruits = ['수박','참외','멜론','바나나','사과','배','딸기','포도','감귤','복숭아','자두','체리','레몬','오렌지'];
    // 수산물 목록 보강: 굴, 낙지, 문어, 조개류 등 추가
    const seafood = [
      '고등어','갈치','명태','동태','오징어','조기','새우','꽃게','멸치','광어','넙치','다시마','김','미역',
      '굴','참굴','낙지','문어','조개','가리비','홍합','멍게'
    ];

    if (grains.any((g) => key.contains(g))) return '100';
    if (vegetables.any((v) => key.contains(v))) return '200';
    if (fruits.any((f) => key.contains(f))) return '400';
    if (seafood.any((s) => key.contains(s))) return '600';

    // 기본: 식량작물
    return '100';
  }

  /// 오늘(or 지정일) 가격 조회.
  /// 자동으로 도매(02) 먼저 시도 후 데이터 없으면 소매(01) 재시도.
  Future<KamisPriceResult?> fetchTodayPrice({
    required String itemName,
    required String regionName,
  String? desiredRank, // '상품','중품','하품' 등 원하는 등급
    DateTime? date,
    bool convertKg = false,
    int backtrackDays = 2, // 오늘 데이터 없을 경우 이전 n일 재시도
  bool includeRegion = true, // false 이면 p_country_code 생략 → 전체지역
  bool broadenCategory = false, // true 이면 1차 카테고리 실패 시 다른 카테고리 순회
  bool useServerKg = false, // true 이면 p_convert_kg_yn=Y 로 서버 환산 활용
  }) async {
    if (_certKey.isEmpty || _certId.isEmpty) {
  LogManager.d('KAMIS', '[KAMIS] 인증키/ID 누락: --dart-define=KAMIS_CERT_KEY=... KAMIS_CERT_ID=...');
      return null;
    }
  final primaryCat = categoryCodeForItem(itemName);
  final regCode = includeRegion ? regionCode(regionName) : null; // null → 전체 지역
    // date 가 null 이더라도 p_regday 명시: 오늘 → 데이터 없으면 어제로 backtrack
    final baseDay = date ?? DateTime.now();
    final attemptDates = <DateTime>[];
    for (int i = 0; i <= backtrackDays; i++) {
      attemptDates.add(baseDay.subtract(Duration(days: i)));
    }

  Future<KamisPriceResult?> attemptWithCategory(String cat) async {
      for (final cls in ['02','01']) {
        for (final d in attemptDates) {
          final dayStr = _fmtDate(d);
          final result = await _request(
            productClsCode: cls,
            categoryCode: cat,
            regionCode: regCode,
            day: dayStr,
            convertKg: useServerKg ? true : convertKg,
            itemName: itemName,
            desiredRank: desiredRank,
            officialCategoryParam: true,
          );
          if (result != null) {
            if (d.day != baseDay.day) {
              LogManager.d('KAMIS', '[KAMIS] 오늘 데이터 없음 → ${dayStr} 데이터 사용(cat=$cat cls=$cls)');
            }
            return result.copyWith(productClassCode: cls);
          }
        }
      }
      return null;
    }

    // 1차: 추론 카테고리
    final first = await attemptWithCategory(primaryCat);
    if (first != null) return first;

    // 2차: broadenCategory 인 경우 다른 카테고리 순회 (100~600)
    if (broadenCategory) {
      for (final cat in ['100','200','300','400','500','600']) {
        if (cat == primaryCat) continue;
        final r = await attemptWithCategory(cat);
        if (r != null) {
          LogManager.d('KAMIS', '[KAMIS] broadenCategory 성공: primary=$primaryCat -> alt=$cat');
          return r;
        }
      }
    }
    return null;
  }

  /// 디버그용: 도매(02)+소매(01) 양쪽 목록을 백트래킹하며 최대 [maxItems]개까지 원자료를 그대로 로그로 덤프.
  /// 기존 fetchTodayPrice 는 첫 성공 클래스에서 멈추므로 더 많은 item[*] 보고 싶을 때 사용.
  Future<void> debugDumpAllItemLists({
    required String itemName,
    required String regionName,
    int maxItems = 50,
    int backtrackDays = 2,
    bool includeAllRegions = false,
    bool broadenCategory = true,
  }) async {
    if (_certKey.isEmpty || _certId.isEmpty) {
  LogManager.d('KAMIS', '[KAMIS][DUMP] 인증키/ID 누락');
      return;
    }
    final baseDay = DateTime.now();
    final attemptDates = <DateTime>[];
    for (int i = 0; i <= backtrackDays; i++) {
      attemptDates.add(baseDay.subtract(Duration(days: i)));
    }

    // region list
    final Map<String, String> knownRegions = {
      '서울': '1101', '부산': '2100', '대구': '2200', '인천': '2300', '광주': '2401', '대전': '2501', '울산': '2601'
    };
    List<String?> regionsToTry;
    if (includeAllRegions) {
      regionsToTry = <String?>[null, ...knownRegions.values.toList()]; // null = 전체
    } else {
      final rc = regionCode(regionName);
      regionsToTry = <String?>[rc];
    }

    // categories to try
    final primaryCat = categoryCodeForItem(itemName);
    final catsToTry = broadenCategory ? ['100','200','300','400','500','600'] : [primaryCat];

    int globalIdx = 0;
    final bool unlimited = maxItems < 0;
    int requests = 0;
    const int maxRequests = 600; // safety cap to avoid runaway

  LogManager.d('KAMIS', '[KAMIS][DUMP] 시작: item="$itemName" cats=${catsToTry.join(',')} regions=${regionsToTry.length} days=${attemptDates.length} cls=02|01');

    for (final cls in ['02','01']) {
      for (final reg in regionsToTry) {
        for (final cat in catsToTry) {
          if (!unlimited && globalIdx >= maxItems) break;
          for (final d in attemptDates) {
            if (!unlimited && globalIdx >= maxItems) break;
            if (requests++ > maxRequests) {
              LogManager.d('KAMIS', '[KAMIS][DUMP] 중단: 최대 요청 수($maxRequests) 초과');
              break;
            }
            final dayStr = _fmtDate(d);
            final list = await _fetchRawList(
              productClsCode: cls,
              categoryCode: cat,
              regionCode: reg,
              day: dayStr,
            );
            if (list.isEmpty) continue;
            LogManager.d('KAMIS', '[KAMIS][DUMP] cls=$cls day=$dayStr cat=$cat reg=${reg ?? '전체'} size=${list.length}');
            for (final m in list) {
              if (!unlimited && globalIdx >= maxItems) break;
              LogManager.d('KAMIS', '[KAMIS][DUMP] item[$globalIdx] cls=$cls name="${m['item_name']}" kind=${m['kind_name']} rank=${m['rank']} code=${m['rank_code']} price=${m['dpr1']} unit=${m['unit']}');
              globalIdx++;
            }
            if (!unlimited && globalIdx >= maxItems) break;
          }
        }
      }
    }
  LogManager.d('KAMIS', '[KAMIS][DUMP] 완료: 로그 출력 ${globalIdx}개${unlimited ? ' (무제한 모드)' : ' (요청 max=$maxItems)'} 요청수=$requests');
  }

  /// 지정된 product class(예: '01' 소매, '02' 도매)로 가격을 조회합니다.
  /// convertKg=true로 요청하면 서버에서 kg 단위로 환산된 가격을 반환하려 시도합니다.
  Future<KamisPriceResult?> fetchPriceForClass({
    required String itemName,
    required String regionName,
    required String productClassCode, // '01' 또는 '02'
    DateTime? date,
    bool convertKg = false,
    int backtrackDays = 2,
    bool includeRegion = false,
  }) async {
    if (_certKey.isEmpty || _certId.isEmpty) {
      LogManager.d('KAMIS', '[KAMIS] 인증키/ID 누락');
      return null;
    }
    final primaryCat = categoryCodeForItem(itemName);
    final regCode = includeRegion ? regionCode(regionName) : null;
    final baseDay = date ?? DateTime.now();
    final attemptDates = <DateTime>[];
    for (int i = 0; i <= backtrackDays; i++) {
      attemptDates.add(baseDay.subtract(Duration(days: i)));
    }

    for (final d in attemptDates) {
      final dayStr = _fmtDate(d);
      final result = await _request(
        productClsCode: productClassCode,
        categoryCode: primaryCat,
        regionCode: regCode,
        day: dayStr,
        convertKg: convertKg,
        itemName: itemName,
        desiredRank: null,
        officialCategoryParam: true,
      );
      if (result != null) return result.copyWith(productClassCode: productClassCode);
    }
    return null;
  }

  /// 내부용: 원시 목록만 받아오기 (선택/매칭 로직 없음)
  Future<List<Map<String,dynamic>>> _fetchRawList({
    required String productClsCode,
    required String categoryCode,
    required String? regionCode,
    required String? day,
  }) async {
    final qp = <String, String>{
      'action': _action,
      'p_product_cls_code': productClsCode,
      'p_category_code': categoryCode,
      'p_returntype': 'json',
      'p_cert_key': _certKey,
      'p_cert_id': _certId,
      if (regionCode != null) 'p_country_code': regionCode,
      if (day != null) 'p_regday': day,
    };
    final uri = Uri.parse(_base).replace(queryParameters: qp);
    try {
      final res = await _client.get(uri, headers: const {'Accept':'application/json, text/plain, */*'}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String,dynamic>) {
        return _extractItemList(decoded);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<KamisPriceResult?> _request({
    required String productClsCode,
    required String categoryCode,
    required String? regionCode,
    required String? day,
    required bool convertKg,
    required String itemName,
  String? desiredRank,
    bool officialCategoryParam = true, // true: p_item_category_code 사용, false: p_category_code 사용 (호환)
  }) async {
    final qp = <String, String>{
      'action': _action,
      'p_product_cls_code': productClsCode,
      // 공식 문서 명세는 p_item_category_code, 일부 샘플/레거시는 p_category_code 보고됨 → 둘 다 옵션화
      if (officialCategoryParam) 'p_item_category_code': categoryCode else 'p_category_code': categoryCode,
      'p_returntype': 'json',
      'p_cert_key': _certKey,
      'p_cert_id': _certId,
      'p_convert_kg_yn': convertKg ? 'Y' : 'N',
      if (regionCode != null) 'p_country_code': regionCode,
      if (day != null) 'p_regday': day,
    };
    final uri = Uri.parse(_base).replace(queryParameters: qp);
    http.Response res;
    try {
      res = await _client.get(uri, headers: const {'Accept':'application/json, text/plain, */*'}).timeout(const Duration(seconds: 15));
    } catch (e) {
  LogManager.d('KAMIS', '[KAMIS] 요청 실패: $e');
      return null;
    }
    if (res.statusCode != 200) {
  LogManager.d('KAMIS', '[KAMIS] HTTP ${res.statusCode}');
      return null;
    }
  final ct = res.headers['content-type'];
  final preview = res.body.length > 120 ? res.body.substring(0,120).replaceAll('\n',' ') : res.body.replaceAll('\n',' ');
  LogManager.d('KAMIS', '[KAMIS] resp ct=$ct bytes=${res.body.length} preview="$preview"');
  Map<String, dynamic>? root;
    try {
      root = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
  LogManager.d('KAMIS', '[KAMIS] JSON 파싱 실패 (본문 일부) ${res.body.substring(0, res.body.length.clamp(0, 120))}');
      return null;
    }
    // 응답 구조가 공식 JSON 예시 문서화가 부족하므로 유연 파싱
    final items = _extractItemList(root);
  LogManager.d('KAMIS', '[KAMIS] total items=${items.length} cls=$productClsCode cat=$categoryCode reg=$regionCode day=$day (match="$itemName")');
    
    // 디버그: 다량 출력 필요 시 한 번에 늘릴 수 있도록 상수로 제한 ( -1 이면 전체 )
  const int debugMaxItems = -1; // -1 : 전체 출력
  final int toLog = debugMaxItems < 0 ? items.length : (items.length < debugMaxItems ? items.length : debugMaxItems);
    for (int i = 0; i < toLog; i++) {
      final it = items[i];
  LogManager.d('KAMIS', '[KAMIS] item[$i]: "${it['item_name']}" kind=${it['kind_name']} rank=${it['rank']} price=${it['dpr1']} unit=${it['unit']}');
    }
    if (toLog < items.length) {
  LogManager.d('KAMIS', '[KAMIS] ...(총 ${items.length}개 중 ${toLog}개만 로그). 더 보려면 debugMaxItems 조정.');
    }
    
    if (items.isEmpty) return null;
    
    // 다단계 매칭 후 등급 필터 적용
    // 1) 입력/항목 이름 정리: 괄호/부가표기 제거 후 정규화
    final cleanedInput = itemName.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final targetNorm = _norm(cleanedInput);
    List<Map<String,dynamic>> nameMatches = [];
    for (final m in items) {
      final nRaw = (m['item_name'] ?? '').toString();
      final nClean = nRaw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final norm = _norm(nClean);
      // 1) 정확 일치
      if (norm == targetNorm) {
        nameMatches.add(m.cast<String,dynamic>());
        continue;
      }
      // 2) 포함/역포함 검사
      if (norm.contains(targetNorm) || targetNorm.contains(norm)) {
        nameMatches.add(m.cast<String,dynamic>());
        continue;
      }
      // 3) 토큰 단위 startsWith (입력이 2자 이상일 때만 적용)
      if (targetNorm.length >= 2) {
        final tokens = norm.split(RegExp(r'[^\w가-힣]+'))..removeWhere((t)=>t.isEmpty);
        final anyStarts = tokens.any((t) => t.startsWith(targetNorm));
        if (anyStarts) { nameMatches.add(m.cast<String,dynamic>()); continue; }
      }
      // 4) 입력의 첫 2글자 포함 여부(짧은 입력의 완화 매칭)
      if (targetNorm.length >= 2 && norm.contains(targetNorm.substring(0,2))) {
        nameMatches.add(m.cast<String,dynamic>());
        continue;
      }
    }
    if (nameMatches.isEmpty) {
      // 추가 시도: 항목명 내에 입력의 토큰이 포함되어 있는지 확인
      final parts = cleanedInput.split(RegExp(r'\s+')).where((p)=>p.isNotEmpty).toList();
      for (final p in parts) {
        final pnorm = _norm(p);
        for (final m in items) {
          final n = (m['item_name'] ?? '').toString().toLowerCase();
          if (n.contains(pnorm)) nameMatches.add(m.cast<String,dynamic>());
        }
        if (nameMatches.isNotEmpty) break;
      }
    }
    if (nameMatches.isEmpty) {
  LogManager.d('KAMIS', '[KAMIS] 이름 매칭 실패: "$itemName" -> 후보 없음 (items size=${items.length}). 자동 fallback 대신 null 반환');
      return null;
    }

    Map<String,dynamic>? picked;

    if (desiredRank != null) {
      // rank 코드 매핑
      String? targetCode;
      switch(desiredRank) {
        case '상품': targetCode = '04'; break;
        case '중품': targetCode = '05'; break;
        case '하품': targetCode = '06'; break; // 존재하지 않을 수도
      }
      // 1) rank 문자열 포함 우선
      for (final m in nameMatches) {
        final r = (m['rank'] ?? '').toString();
  if (r.contains(desiredRank)) { picked = m; LogManager.d('KAMIS', '[KAMIS] ◎ 등급 매칭(rank str): $desiredRank -> ${m['item_name']} ${m['rank']}'); break; }
      }
      // 2) rank_code 매칭
      if (picked == null && targetCode != null) {
        for (final m in nameMatches) {
          final code = (m['rank_code'] ?? '').toString();
    if (code == targetCode) { picked = m; LogManager.d('KAMIS', '[KAMIS] ◎ 등급 매칭(rank_code=$targetCode)'); break; }
        }
      }
      // 3) grade 요구했지만 못 찾음 → 후보 등급 목록 로그
      if (picked == null) {
        final ranks = nameMatches.map((m)=>'${m['rank']}(code:${m['rank_code']})').join(', ');
  LogManager.d('KAMIS', '[KAMIS] ◌ 요청 등급 "$desiredRank" 미발견, 후보 등급들: $ranks');
      }
    }
    // 4) 등급 미지정 또는 매칭 실패 시 첫 후보
    picked ??= nameMatches.first;
  LogManager.d('KAMIS', '[KAMIS] 최종 선택: ${picked['item_name']} rank=${picked['rank']} code=${picked['rank_code']} dpr1=${picked['dpr1']}');
  final dpr1 = (picked['dpr1'] ?? '').toString().replaceAll(',', '').trim();
  final price = int.tryParse(dpr1);
    if (price == null) return null;
    final unit = (picked['unit'] ?? '').toString();
    final rank = (picked['rank'] ?? '').toString();
    final day1 = (picked['day1'] ?? '').toString();

    return KamisPriceResult(
      itemName: (picked['item_name'] ?? '').toString(),
      unit: unit,
      rank: rank,
      day: day1,
      price: price,
      productClassCode: productClsCode,
    );
  }

  List<Map<String, dynamic>> _extractItemList(Map<String, dynamic> root) {
    // 흔히 data 안에 list 가 있거나, data 자체가 list
    final candidates = <dynamic>[
      root['data'],
      root['items'],
      root['item'],
    ];
    for (final c in candidates) {
      if (c is List) {
        return c.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    // data 가 Map 이고 그 안에 item 또는 items 가 list 인 경우
    final data = root['data'];
    if (data is Map) {
      if (data['item'] is List) {
        return (data['item'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      if (data['items'] is List) {
        return (data['items'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

class KamisPriceResult {
  final String itemName;
  final String unit;
  final String rank; // 상품, 중품 등
  final String day;  // 조회일자
  final int price;   // dpr1
  final String productClassCode; // 01 소매 02 도매
  const KamisPriceResult({
    required this.itemName,
    required this.unit,
    required this.rank,
    required this.day,
    required this.price,
    required this.productClassCode,
  });
  KamisPriceResult copyWith({String? productClassCode}) => KamisPriceResult(
        itemName: itemName,
        unit: unit,
        rank: rank,
        day: day,
        price: price,
        productClassCode: productClassCode ?? this.productClassCode,
      );
}