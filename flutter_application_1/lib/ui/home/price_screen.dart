import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/kamis_daily_price_service.dart';
import 'package:flutter_application_1/services/log_manager.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final KamisDailyPriceService _kamis = KamisDailyPriceService();
  String? _selected;
  bool _showOptions = false;
  // status string removed; UI shows results directly
  int? _packagePrice;
  String _region = '전국';
  double? _pctChange; // percent (e.g. 2.3 means +2.3%)

  final Map<String, int> _packageKg = {
    '감자(수미)': 20, // 20kg 상자
  '고구마': 10, // 10kg 상자
  '양파': 15, // 15kg 상자
  '배추': 10, // 10kg 상자
  '무': 20, // 20kg 상자
  };

  final List<String> _options = ['감자(수미)', '고구마', '양파', '배추', '무'];

  Future<void> _fetchPriceFor(String name) async {
    setState(() {
      _packagePrice = null;
    });
    try {
  // 요청: 도매('02') 기준, 서버 kg 환산 시도
      final includeRegion = _region != '전국';
  // Per request: use fixed lookup date (2025-09-12) and compare to 2025-09-11 for all items.
  // If you later want item-specific or dynamic dates, we can make this configurable.
  DateTime targetDate = DateTime(2025, 9, 12);
  DateTime prevDate = DateTime(2025, 9, 11);

      // Fetch target date price (no backtrack) and explicit previous-date price
      final resTarget = await _kamis.fetchPriceForClass(
        itemName: name,
        regionName: includeRegion ? _region : '',
        productClassCode: '02', // 도매 기준
        convertKg: true,
        includeRegion: includeRegion,
        backtrackDays: 0,
        date: targetDate,
      );

      final resPrevDay = await _kamis.fetchPriceForClass(
        itemName: name,
        regionName: includeRegion ? _region : '',
        productClassCode: '02',
        convertKg: true,
        includeRegion: includeRegion,
        backtrackDays: 0,
        date: prevDate,
      );

      final res = resTarget ?? resPrevDay; // prefer targetDate; if missing, show prev if available
      if (res == null) {
        setState(() {
          _packagePrice = null;
          _pctChange = null;
        });
        return;
      }
      // res.price 는 dpr1, 단위는 res.unit
      // 서버에 convertKg=Y 를 요청했으므로 res.unit 이 'kg' 이거나 숫자/문자 조합일 수 있음
      int perKg = res.price; // 기본으로는 반환된 값이 kg 단위로 온다고 가정
      // 만약 단위가 '박스'나 'kg' 등 다른 문자열이면, 추가 처리 (단위가 kg 아닐 때는 우선 그대로 사용)
      final unit = res.unit.toLowerCase();
      if (unit.contains('kg')) {
        // already per kg
      } else if (unit.contains('박') || unit.contains('상자') || unit.contains('box')) {
        // 일부 데이터는 상자 단위로 제공될 수 있으므로, 서버의 가격이 상자 단위라면
        // 우리는 패키지 kg 기준으로 그대로 사용 (ex: 감자 20kg 상자 가격이면 그대로 사용)
        // 여기서는 패키지Kg이 의미하는 상자 kg과 일치한다고 가정
      } else {
        // fallback: leave perKg as-is
      }

      final pkgKg = _packageKg[name] ?? 1;
      // If server returned per kg, compute price = perKg * pkgKg
      // If server returned per package (e.g., 박스), then perKg already equals package price; attempt to detect using unit
      int computed;
      if (unit.contains('kg')) {
        computed = perKg * pkgKg;
      } else if (unit.contains('박') || unit.contains('상자') || unit.contains('box')) {
        // assume returned price is per box
        computed = perKg;
      } else {
        // fallback: if unit is numeric or empty, assume perKg
        computed = perKg * pkgKg;
      }


      // Compute prevComputed from explicit previous-day result (resPrevDay)
      int? prevComputed;
      if (resPrevDay != null) {
        int prevPerKg = resPrevDay.price;
        final prevUnit = resPrevDay.unit.toLowerCase();
        if (prevUnit.contains('kg')) {
          prevComputed = prevPerKg * pkgKg;
        } else if (prevUnit.contains('박') || prevUnit.contains('상자') || prevUnit.contains('box')) {
          prevComputed = prevPerKg;
        } else {
          prevComputed = prevPerKg * pkgKg;
        }
      }

      double? pct;
      if (prevComputed != null && prevComputed > 0) {
        pct = ((computed - prevComputed) / prevComputed) * 100.0;
      }

      // debug logs
      try {
        LogManager.d('PRICE', 'item=$name region=$_region resDay=${res.day} resPrice=${res.price} unit=${res.unit} computed=$computed prevComputed=$prevComputed pct=${pct?.toStringAsFixed(2)}');
      } catch (_) {}

      setState(() {
        _packagePrice = computed;
        _pctChange = pct;
      });
    } catch (e) {
      LogManager.d('PRICE', '가격 조회 실패: $e');
      setState(() {
        _packagePrice = null;
        _pctChange = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeGreen = const Color(0xFF2E7D32);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      body: Stack(
        children: [
          Column(
            children: [
          // gradient header that fills status bar area
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF19C37E)]),
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: SafeArea(
              top: true,
              bottom: false,
              child: Container(
                height: 92,
                alignment: Alignment.center,
                child: const Text('오늘의 가격', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(height: 18),
              const SizedBox(height: 18),

              // body content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Center(child: Text('품목 선택', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59)))),
                      const SizedBox(height: 18),

                      // styled selection card - tap to toggle inline dropdown
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOptions = !_showOptions;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFFFF8),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: themeGreen.withOpacity(0.3), width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selected ?? '품목을 선택하세요',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                              Icon(_showOptions ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),

                      // inline dropdown list shown under the selection card
                      if (_showOptions)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            children: [
                              for (final o in _options) ...[
                                ListTile(
                                  title: Text(o, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  onTap: () {
                                    setState(() {
                                      _selected = o;
                                      _showOptions = false;
                                    });
                                    _fetchPriceFor(o);
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 18),

                      // region selection card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place, color: Color(0xFF0E8B59)),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('지역 선택', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            DropdownButton<String>(
                              value: _region,
                              items: const [
                                DropdownMenuItem(value: '전국', child: Text('전국')),
                                DropdownMenuItem(value: '서울', child: Text('서울')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _region = v;
                                });
                                if (_selected != null) _fetchPriceFor(_selected!);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Price card area
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFBDEBCB)),
                        ),
                        child: Column(
                          children: [
                              Text('${_selected ?? ''} 오늘의 가격은', style: const TextStyle(color: Color(0xFF0E8B59), fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Column(
                                children: [
                                  Text('${_packageKg[_selected ?? ''] ?? 0}kg당', style: const TextStyle(color: Color(0xFF0E8B59), fontSize: 22, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _packagePrice != null ? '${_packagePrice!.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ',')}원' : '-- 원',
            style: const TextStyle(color: Color(0xFF0E8B59), fontSize: 36, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
          const Text('입니다.', style: TextStyle(color: Color(0xFF0E8B59), fontSize: 16)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // info box (show actual percent change when available)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F6FF),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lightbulb, color: Color(0xFF2D9CFF)),
                                const SizedBox(width: 8),
                                Text(
                                    '최근 가격 대비 변동률: ${_pctChange != null ? (_pctChange! >= 0 ? '+' : '') + _pctChange!.toStringAsFixed(1) + '%' : '--'}',
                                  style: const TextStyle(color: Color(0xFF0E6EB8), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('최근 일주일 평균 대비 높은 가격입니다', style: TextStyle(color: Color(0xFF0E6EB8))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // bottom fixed back button
          Positioned(
            left: 18,
            right: 18,
            bottom: 36, // raised slightly
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('뒤로가기', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 12,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
