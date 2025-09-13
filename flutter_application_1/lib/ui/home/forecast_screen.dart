import 'package:flutter/material.dart';
import 'dart:math' as math;

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  String? _selected;
  bool _showOptions = false;

  // ignore: unused_field
  final Map<String, int> _packageKg = {
    '감자(수미)': 20,
    '고구마': 10,
    '양파': 15,
  '배추': 10,
  '무': 20,
  };

  final List<String> _options = ['감자(수미)', '고구마', '양파', '배추', '무'];
  // daily series (for 감자(수미) case)
  List<DateTime>? _actualDates;
  List<double>? _actualValues;
  List<DateTime>? _predDates;
  List<double>? _predValues;
  List<double>? _seriesAll; // monthly peak for Top3 (length 12)
  DateTime _boundaryDate = DateTime(2025, 9, 12);

  String _shortDate(DateTime d) => '${(d.year % 100).toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final themeGreen = const Color(0xFF2E7D32);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      body: Stack(
        children: [
          Column(
            children: [
              // header gradient that fills status bar
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF19C37E), Color(0xFF00C853)]),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Container(
                    height: 92,
                    alignment: Alignment.center,
                    child: const Text('판매 금액 예측', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      const Center(child: Text('품목 선택', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59)))),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () => setState(() => _showOptions = !_showOptions),
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
                              Expanded(child: Text(_selected ?? '품목을 선택하세요', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                              Icon(_showOptions ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),

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
                                    _generateForecastFor(o);
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 22),

                      // label for Top3 area: monthly average ranking
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Text('월별 평균 등수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59))),
                      ),

                      // top 3 cards (dynamic from _forecast)
                      Container(
                        padding: const EdgeInsets.all(18),
                        child: _seriesAll == null ?
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                decoration: BoxDecoration(color: const Color(0xFF06AF58), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 6))]),
                                child: Row(children: const [Text('예측 데이터 없음', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
                              ),
                            ],
                          ) : _buildTop3Cards(),
                      ),

                      const SizedBox(height: 0),

                      // prominent advisory: data is for reference only
                      Transform.translate(offset: const Offset(0, -6), child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0A800)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFE0A800), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('참고: 제공하는 데이터는 참고용입니다.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text('최종 결정은 언제나 농민분들의 몫입니다. 데이터를 참고하되, 현장 상황을 우선하세요.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),

                      // graph box
                      const Center(child: Text('연간 가격 예측 그래프', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59)))),
                      const SizedBox(height: 12),
                      Container(
                        height: 260,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF9EE6B9)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: (_actualValues == null && _predValues == null) ? Center(child: Text('그래프 자리 (품목 선택 시 예측 표시)', style: TextStyle(color: Colors.grey.shade500))) : CustomPaint(
                          painter: _ForecastPainter(
                            actualDates: _actualDates ?? [],
                            actualValues: _actualValues ?? [],
                            predDates: _predDates ?? [],
                            predValues: _predValues ?? [],
                            boundaryDate: _boundaryDate,
                            monthlyPeaks: _seriesAll ?? List.filled(12, 0),
                            legendActual: '실제(2025~09-12)',
                            legendPred: '예측(09/13~12/31)',
                          ),
                          child: Container(),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Simplified legend: only marker + label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF6FFF6), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Actual
                            Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFF1F77B4), borderRadius: BorderRadius.circular(6))),
                                    const SizedBox(width: 8),
                                    // small colored line to visually match 'line' style
                                    Container(width: 28, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F77B4), borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    Text('실제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(_shortDate(_boundaryDate), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            // Predicted
                            Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFD62728), borderRadius: BorderRadius.circular(6))),
                                    const SizedBox(width: 8),
                                    Container(width: 28, height: 4, decoration: BoxDecoration(color: const Color(0xFFD62728), borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    Text('예측', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text('${_shortDate(_boundaryDate.add(Duration(days:1)))}~', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // storage info (dynamic per selected item)
                      const Center(child: Text('저장 방법 & 보관 기간', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59)))),
                      const SizedBox(height: 12),
                      _storageWidget(),

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
            bottom: 36,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('뒤로가기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF19C37E),
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

  // When an item is selected, prepare actual and predicted series and combined list
  void _generateForecastFor(String item) {
  // helper removed (not needed with daily CSV)

    if (item == '감자(수미)') {
      // Parse provided CSV into daily series (use entries up to 2025-09-12)
      const csv = '''
일자,평균가
2025-09-12,39687
2025-09-11,39268
2025-09-10,39330
2025-09-09,38112
2025-09-08,37935
2025-09-06,39111
2025-09-05,36534
2025-09-04,38461
2025-09-03,37782
2025-09-02,37552
2025-09-01,37670
2025-08-30,37520
2025-08-29,37910
2025-08-28,38620
2025-08-27,37479
2025-08-26,38705
2025-08-25,36842
2025-08-23,37826
2025-08-22,38339
2025-08-21,37140
2025-08-20,36563
2025-08-19,37200
2025-08-18,38134
2025-08-16,34716
2025-08-15,36026
2025-08-14,35353
2025-08-13,37141
2025-08-12,37614
2025-08-11,39001
2025-08-09,41458
2025-08-08,35907
2025-08-07,33799
2025-08-06,35070
2025-08-05,36378
2025-08-04,38003
2025-08-01,38539
2025-07-31,37691
2025-07-30,34770
2025-07-29,33633
2025-07-28,33150
2025-07-26,34039
2025-07-25,34303
2025-07-24,35316
2025-07-23,33026
2025-07-22,32572
2025-07-21,31440
2025-07-19,32275
2025-07-18,34217
2025-07-17,35655
2025-07-16,36150
2025-07-15,33841
2025-07-14,32533
2025-07-12,29700
2025-07-11,28329
2025-07-10,27442
2025-07-09,28177
2025-07-08,29266
2025-07-07,28059
2025-07-05,26567
2025-07-04,24732
2025-07-03,24365
2025-07-02,24389
2025-07-01,23115
2025-06-30,24657
2025-06-28,26890
2025-06-27,28495
2025-06-26,28493
2025-06-25,29127
2025-06-24,29909
2025-06-23,30378
2025-06-21,33121
2025-06-20,35829
2025-06-19,37375
2025-06-18,37358
2025-06-17,35042
2025-06-16,34162
2025-06-14,35000
2025-06-13,29818
2025-06-12,26554
2025-06-11,24027
2025-06-10,23771
2025-06-09,24973
2025-06-07,27413
2025-06-06,32467
2025-06-05,35113
2025-06-04,37760
2025-06-03,32066
2025-06-02,29798
2025-05-31,32575
2025-05-30,35585
2025-05-29,41483
2025-05-28,47730
2025-05-27,51988
2025-05-26,53634
2025-05-24,56264
2025-05-23,64785
2025-05-22,66464
2025-05-21,70759
2025-05-20,65280
2025-05-19,66857
2025-05-17,64828
2025-05-16,63797
2025-05-15,63259
2025-05-14,61208
2025-05-13,62801
2025-05-12,59988
2025-05-10,55536
2025-05-09,49861
2025-05-08,51981
2025-05-07,56663
2025-05-06,59255
2025-05-05,60175
2025-05-03,59964
2025-05-02,57814
2025-05-01,54981
2025-04-30,51157
2025-04-29,49500
2025-04-28,47594
2025-04-26,48338
2025-04-25,55818
2025-04-24,60007
2025-04-23,59018
2025-04-22,58880
2025-04-21,61325
2025-04-19,60945
2025-04-18,61728
2025-04-17,60530
2025-04-16,62085
2025-04-15,60336
2025-04-14,61780
2025-04-12,62123
2025-04-11,63619
2025-04-10,62241
2025-04-09,58627
2025-04-08,58751
2025-04-07,61308
2025-04-05,58798
2025-04-04,65213
2025-04-03,70828
2025-04-02,64582
2025-04-01,71437
2025-03-31,71343
2025-03-29,69036
2025-03-28,68319
2025-03-27,71569
2025-03-26,69519
2025-03-25,66373
2025-03-24,70649
2025-03-22,68160
2025-03-21,62311
2025-03-20,69618
2025-03-19,67450
2025-03-18,66471
2025-03-17,58571
2025-03-15,56229
2025-03-14,56229
2025-03-13,52322
2025-03-12,42457
2025-03-11,58215
2025-03-10,63179
2025-03-08,57875
2025-03-07,60532
2025-03-06,67311
2025-03-04,68421
2025-03-03,69301
2025-03-01,65431
2025-02-28,64850
2025-02-27,65845
2025-02-26,71767
2025-02-25,75764
2025-02-24,74989
2025-02-22,70547
2025-02-21,30434
2025-02-20,59249
2025-02-19,66193
2025-02-18,66346
2025-02-17,67354
2025-02-15,67156
2025-02-14,69264
2025-02-13,63814
2025-02-11,71708
2025-02-10,60860
2025-02-08,62329
2025-02-07,68718
2025-02-06,51960
2025-02-05,54668
2025-02-04,50595
2025-02-03,61403
2025-02-01,64999
2025-01-28,60861
2025-01-27,60861
2025-01-25,60861
2025-01-24,37721
2025-01-23,32233
2025-01-22,49338
2025-01-21,43887
2025-01-20,63314
2025-01-18,47944
2025-01-17,55334
2025-01-16,72376
2025-01-15,72486
2025-01-14,76016
2025-01-13,44515
2025-01-11,42868
2025-01-10,42868
2025-01-09,57128
2025-01-08,54676
2025-01-07,46636
2025-01-06,46946
2025-01-04,46237
2025-01-03,42171
2025-01-02,37712
''';

      final lines = csv.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final Map<int, List<double>> byMonth = {};
      for (int i = 1; i <= 12; i++) byMonth[i] = [];
      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 2) continue;
        final date = parts[0];
        final val = double.tryParse(parts[1]) ?? 0.0;
        try {
          final dt = DateTime.parse(date);
          // for September, only include dates <= 2025-09-12
          if (dt.year == 2025 && dt.month == 9 && dt.day > 12) continue;
          byMonth[dt.month]!.add(val);
        } catch (_) {
          continue;
        }
      }
      // Build daily actual lists from CSV entries
      final Map<DateTime, double> dayMap = {};
      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 2) continue;
        final date = parts[0].trim();
        final val = double.tryParse(parts[1].trim()) ?? 0.0;
        try {
          final dt = DateTime.parse(date);
          if (dt.isAfter(_boundaryDate)) continue; // only include up to boundary
          dayMap[DateTime(dt.year, dt.month, dt.day)] = val;
        } catch (_) {
          continue;
        }
      }
      // construct daily arrays for the whole year (Jan 1 - Dec 31)
      final year = 2025;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      final actualDates = <DateTime>[];
      final actualValues = <double>[];
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        if (dayMap.containsKey(DateTime(d.year, d.month, d.day))) {
          actualDates.add(d);
          actualValues.add(dayMap[DateTime(d.year, d.month, d.day)]!);
        }
      }
      // If September has no data after filter, still allow the provided 9/12 value
      // but CSV includes 9/12 so above will set it.

      // parse provided per-day prediction CSV for 2025-09-13..2025-12-31
      final predCsv = '''
2025-09-13 39135
2025-09-14 38264
2025-09-15 38900
2025-09-16 38319
2025-09-17 38423
2025-09-18 37596
2025-09-19 37061
2025-09-20 36300
2025-09-21 35324
2025-09-22 35258
2025-09-23 35797
2025-09-24 35825
2025-09-25 36137
2025-09-26 36072
2025-09-27 37702
2025-09-28 37128
2025-09-29 36110
2025-09-30 35967
2025-10-01 36078
2025-10-02 36123
2025-10-03 36386
2025-10-04 36178
2025-10-05 38057
2025-10-06 36590
2025-10-07 35734
2025-10-08 35366
2025-10-09 35830
2025-10-10 35261
2025-10-11 35433
2025-10-12 35773
2025-10-13 37444
2025-10-14 36576
2025-10-15 36121
2025-10-16 36257
2025-10-17 35517
2025-10-18 35584
2025-10-19 36525
2025-10-20 35657
2025-10-21 37539
2025-10-22 36985
2025-10-23 36956
2025-10-24 36692
2025-10-25 36519
2025-10-26 36439
2025-10-27 36257
2025-10-28 37447
2025-10-29 37635
2025-10-30 37524
2025-10-31 36486
2025-11-01 36505
2025-11-02 36392
2025-11-03 36538
2025-11-04 36340
2025-11-05 36470
2025-11-06 37600
2025-11-07 37476
2025-11-08 36665
2025-11-09 36124
2025-11-10 36103
2025-11-11 36244
2025-11-12 36308
2025-11-13 36405
2025-11-14 38132
2025-11-15 37781
2025-11-16 38395
2025-11-17 38452
2025-11-18 38692
2025-11-19 38765
2025-11-20 39458
2025-11-21 39439
2025-11-22 40244
2025-11-23 40153
2025-11-24 40573
2025-11-25 40521
2025-11-26 39646
2025-11-27 39237
2025-11-28 39067
2025-11-29 39044
2025-11-30 39217
2025-12-01 38799
2025-12-02 38880
2025-12-03 39282
2025-12-04 39059
2025-12-05 39229
2025-12-06 39361
2025-12-07 39236
2025-12-08 39228
2025-12-09 39028
2025-12-10 39322
2025-12-11 39372
2025-12-12 39031
2025-12-13 38537
2025-12-14 38864
2025-12-15 39351
2025-12-16 39379
2025-12-17 40010
2025-12-18 40488
2025-12-19 40504
2025-12-20 42459
2025-12-21 42686
2025-12-22 43754
2025-12-23 43645
2025-12-24 43624
2025-12-25 43973
2025-12-26 43801
2025-12-27 43812
2025-12-28 43895
2025-12-29 43281
2025-12-30 43258
2025-12-31 42911
''';
      final predDates = <DateTime>[];
      final predValues = <double>[];
      for (final line in predCsv.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(RegExp(r"\s+"));
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1].replaceAll(',', '')) ?? 0.0;
          if (dt.isAfter(_boundaryDate)) {
            predDates.add(dt);
            predValues.add(v);
          }
        } catch (_) {}
      }

      // compute monthly peaks for Top3 from daily data ON/AFTER boundaryDate (2025-09-13)
      final monthlyPeak = List<double>.filled(12, 0);
      final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
      // include actualDates if they fall on/after boundaryExclusive
      for (int i = 0; i < actualDates.length; i++) {
        final d = actualDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = actualValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }
      for (int i = 0; i < predDates.length; i++) {
        final d = predDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = predValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }

      setState(() {
        _actualDates = actualDates;
        _actualValues = actualValues;
        _predDates = predDates;
        _predValues = predValues;
        _seriesAll = monthlyPeak;
        _boundaryDate = DateTime(2025, 9, 12);
      });
      return;
    }

    if (item == '무') {
      // prediction table (includes 2025-08-31 .. 2025-12-31)
  final predTable = '''
2025-08-31 14,503
2025-09-01 14,901
2025-09-02 15,172
2025-09-03 15,089
2025-09-04 14,692
2025-09-05 14,652
2025-09-06 14,737
2025-09-07 14,861
2025-09-08 14,827
2025-09-09 14,533
2025-09-10 14,109
2025-09-11 15,408
2025-09-12 15,718
2025-09-13 15,627
2025-09-14 15,516
2025-09-15 15,083
2025-09-16 15,013
2025-09-17 15,115
2025-09-18 15,198
2025-09-19 15,209
2025-09-20 15,540
2025-09-21 15,431
2025-09-22 14,895
2025-09-23 14,122
2025-09-24 14,210
2025-09-25 15,515
2025-09-26 16,054
2025-09-27 15,325
2025-09-28 15,153
2025-09-29 15,186
2025-09-30 15,234
2025-10-01 15,051
2025-10-02 14,763
2025-10-03 14,763
2025-10-04 14,734
2025-10-05 14,816
2025-10-06 14,826
2025-10-07 14,386
2025-10-08 14,545
2025-10-09 14,681
2025-10-10 14,740
2025-10-11 15,089
2025-10-12 15,205
2025-10-13 15,098
2025-10-14 14,779
2025-10-15 14,936
2025-10-16 15,131
2025-10-17 14,983
2025-10-18 14,872
2025-10-19 14,955
2025-10-20 15,064
2025-10-21 15,059
2025-10-22 14,494
2025-10-23 14,518
2025-10-24 14,629
2025-10-25 15,090
2025-10-26 15,271
2025-10-27 15,116
2025-10-28 15,005
2025-10-29 15,028
2025-10-30 14,980
2025-10-31 14,960
2025-11-01 15,144
2025-11-02 14,970
2025-11-03 14,751
2025-11-04 14,845
2025-11-05 14,867
2025-11-06 14,636
2025-11-07 14,630
2025-11-08 14,653
2025-11-09 14,717
2025-11-10 14,757
2025-11-11 15,234
2025-11-12 15,278
2025-11-13 15,087
2025-11-14 15,186
2025-11-15 14,664
2025-11-16 14,823
2025-11-17 15,196
2025-11-18 15,224
2025-11-19 14,976
2025-11-20 14,985
2025-11-21 15,015
2025-11-22 14,608
2025-11-23 14,654
2025-11-24 14,687
2025-11-25 15,060
2025-11-26 15,234
2025-11-27 15,266
2025-11-28 15,194
2025-11-29 15,178
2025-11-30 15,019
2025-12-01 14,804
2025-12-02 14,864
2025-12-03 14,929
2025-12-04 14,856
2025-12-05 14,743
2025-12-06 14,722
2025-12-07 14,686
2025-12-08 14,647
2025-12-09 14,663
2025-12-10 14,729
2025-12-11 15,026
2025-12-12 15,078
2025-12-13 15,092
2025-12-14 15,081
2025-12-15 14,878
2025-12-16 14,783
2025-12-17 15,038
2025-12-18 15,175
2025-12-19 15,160
2025-12-20 15,021
2025-12-21 14,898
2025-12-22 14,554
2025-12-23 14,683
2025-12-24 14,714
2025-12-25 15,071
2025-12-26 15,154
2025-12-27 15,185
2025-12-28 15,156
2025-12-29 15,096
2025-12-30 14,937
2025-12-31 14,834
''';

      // historical CSV up to 2025-08-30
      final histCsv = '''
일자,평균가
2025-08-30,14589
2025-08-29,14790
2025-08-28,15182
2025-08-27,12687
2025-08-26,13131
2025-08-25,13974
2025-08-23,8939
2025-08-22,9361
2025-08-21,10982
2025-08-20,11990
2025-08-19,10303
2025-08-18,11754
2025-08-16,12220
2025-08-15,14876
2025-08-14,12476
2025-08-13,13050
2025-08-12,11225
2025-08-11,13032
2025-08-09,10575
2025-08-08,13311
2025-08-07,12322
2025-08-06,12944
2025-08-05,18170
2025-08-04,18723
2025-08-01,13808
2025-07-31,12349
2025-07-30,12044
2025-07-29,12212
2025-07-28,14210
2025-07-26,12694
2025-07-25,13148
2025-07-24,9721
2025-07-23,10039
2025-07-22,12460
2025-07-21,13056
2025-07-19,14099
2025-07-18,18737
2025-07-17,14424
2025-07-16,15556
2025-07-15,18363
2025-07-14,15110
2025-07-12,13776
2025-07-11,14807
2025-07-10,17018
2025-07-09,16511
2025-07-08,14775
2025-07-07,14298
2025-07-05,8401
2025-07-04,11209
2025-07-03,9387
2025-07-02,8704
2025-07-01,7262
2025-06-30,9091
2025-06-28,9086
2025-06-27,10279
2025-06-26,16114
2025-06-25,10335
2025-06-24,9212
2025-06-23,10670
2025-06-21,12144
2025-06-20,12162
2025-06-19,9699
2025-06-18,8934
2025-06-17,11949
2025-06-16,13066
2025-06-14,14196
2025-06-13,14659
2025-06-12,11544
2025-06-11,12068
2025-06-10,11750
2025-06-09,13497
2025-06-07,12782
2025-06-06,12395
2025-06-05,14449
2025-06-04,17208
2025-06-03,14952
2025-06-02,12666
2025-05-31,11740
2025-05-30,17005
2025-05-29,17867
2025-05-28,19630
2025-05-27,19359
2025-05-26,17802
2025-05-24,17454
2025-05-23,18436
2025-05-22,18956
2025-05-21,20297
2025-05-20,18578
2025-05-19,20060
2025-05-17,18886
2025-05-16,20357
2025-05-15,19791
2025-05-14,21553
2025-05-13,20102
2025-05-12,24331
2025-05-10,24108
2025-05-09,20604
2025-05-08,21327
2025-05-07,20925
2025-05-06,22672
2025-05-05,24557
2025-05-03,24042
2025-05-02,23367
2025-05-01,21678
2025-04-30,22836
2025-04-29,22528
2025-04-28,25346
2025-04-26,22824
2025-04-25,21111
2025-04-24,21106
2025-04-23,23117
2025-04-22,26123
2025-04-21,25891
2025-04-19,21600
2025-04-18,25659
2025-04-17,26469
2025-04-16,25508
2025-04-15,25714
2025-04-14,27189
2025-04-12,24699
2025-04-11,25596
2025-04-10,20193
2025-04-09,17212
2025-04-08,21759
2025-04-07,24451
2025-04-05,26140
2025-04-04,27274
2025-04-03,25419
2025-04-02,25017
2025-04-01,27091
2025-03-31,29386
2025-03-29,29129
2025-03-28,25812
2025-03-27,23472
2025-03-26,25732
2025-03-25,27322
2025-03-24,27264
2025-03-22,24516
2025-03-21,25129
2025-03-20,25854
2025-03-19,25425
2025-03-18,26658
2025-03-17,24243
2025-03-15,22765
2025-03-14,23033
2025-03-13,24226
2025-03-12,25422
2025-03-11,25889
2025-03-10,26197
2025-03-08,30089
2025-03-07,34342
2025-03-06,33487
2025-03-04,32264
2025-03-03,31752
2025-03-01,30905
2025-02-28,30021
2025-02-27,29180
2025-02-26,28737
2025-02-25,27473
2025-02-24,27209
2025-02-22,25172
2025-02-21,25033
2025-02-20,26749
2025-02-19,26998
2025-02-18,25347
2025-02-17,26150
2025-02-15,29047
2025-02-14,32153
2025-02-13,34200
2025-02-11,31936
2025-02-10,29660
2025-02-08,30621
2025-02-07,30957
2025-02-06,31903
2025-02-05,32449
2025-02-04,31348
2025-02-03,29645
2025-02-01,25517
2025-01-28,26130
2025-01-27,28342
2025-01-25,29924
2025-01-24,25740
2025-01-23,23375
2025-01-22,23069
2025-01-21,22673
2025-01-20,23048
2025-01-18,24207
2025-01-17,25968
2025-01-16,26952
2025-01-15,27746
2025-01-14,27858
2025-01-13,25345
2025-01-11,23859
2025-01-10,25531
2025-01-09,25846
2025-01-08,25047
2025-01-07,28216
2025-01-06,31740
2025-01-04,34988
2025-01-03,30954
2025-01-02,33006
''';

      // parse historical CSV into day map
      final lines = histCsv.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final Map<DateTime, double> dayMap = {};
      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 2) continue;
        final date = parts[0].trim();
        final val = double.tryParse(parts[1].trim()) ?? 0.0;
        try {
          final dt = DateTime.parse(date);
          if (dt.isAfter(_boundaryDate)) continue;
          dayMap[DateTime(dt.year, dt.month, dt.day)] = val;
        } catch (_) {}
      }

      // parse prediction table into map (normalize commas)
      final predMap = <DateTime, double>{};
      for (final line in predTable.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(RegExp(r"\s+"));
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1].replaceAll(',', '')) ?? 0.0;
          predMap[DateTime(dt.year, dt.month, dt.day)] = v;
        } catch (_) {}
      }

      // construct daily actual arrays for the whole year from dayMap
      final year = 2025;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      final actualDates = <DateTime>[];
      final actualValues = <double>[];
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        if (dayMap.containsKey(key)) {
          actualDates.add(key);
          actualValues.add(dayMap[key]!);
        }
      }

      // build predDates/values for the full prediction table (08-31..12-31)
      final predDates = <DateTime>[];
      final predValues = <double>[];
      final predEntries = predMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final e in predEntries) {
        predDates.add(e.key);
        predValues.add(e.value);
      }

      // compute monthly peaks same as 감자 (use actualDates/predDates on/after 9/13)
      final monthlyPeak = List<double>.filled(12, 0);
      final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
      for (int i = 0; i < actualDates.length; i++) {
        final d = actualDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = actualValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }
      for (int i = 0; i < predDates.length; i++) {
        final d = predDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = predValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }

      setState(() {
        _actualDates = actualDates;
        _actualValues = actualValues;
        _predDates = predDates;
        _predValues = predValues;
        _seriesAll = monthlyPeak;
        _boundaryDate = DateTime(2025, 9, 12);
      });
      return;
    }

    if (item == '배추') {
      // history CSV contains data up to 2025-09-12
      final hist = '''
2025-09-12,12799
2025-09-11,11598
2025-09-10,10522
2025-09-09,12027
2025-09-08,14705
2025-09-06,12977
2025-09-05,12815
2025-09-04,16577
2025-09-03,21181
2025-09-02,15359
2025-09-01,15589
2025-08-30,13435
2025-08-29,15320
2025-08-28,18735
2025-08-27,13376
2025-08-26,13098
2025-08-25,13628
2025-08-23,12676
2025-08-22,13234
2025-08-21,13349
2025-08-20,14178
2025-08-19,11040
2025-08-18,11960
2025-08-16,15985
2025-08-15,14732
2025-08-14,13178
2025-08-13,12565
2025-08-12,11321
2025-08-11,14950
2025-08-09,15849
2025-08-08,13613
2025-08-07,13231
2025-08-06,15425
2025-08-05,17471
2025-08-04,19074
2025-08-01,17461
2025-07-31,14881
2025-07-30,18602
2025-07-29,13021
2025-07-28,12236
2025-07-26,10566
2025-07-25,8949
2025-07-24,8661
2025-07-23,9442
2025-07-22,7801
2025-07-21,11319
2025-07-19,13394
2025-07-18,12610
2025-07-17,12939
2025-07-16,12046
2025-07-15,13021
2025-07-14,11967
2025-07-12,13291
2025-07-11,12396
2025-07-10,9561
2025-07-09,7984
2025-07-08,5708
2025-07-07,8503
2025-07-05,10022
2025-07-04,6850
2025-07-03,4749
2025-07-02,7076
2025-07-01,5410
2025-06-30,8487
2025-06-28,5807
2025-06-27,5163
2025-06-26,7454
2025-06-25,6154
2025-06-24,6092
2025-06-23,6378
2025-06-21,10386
2025-06-20,8886
2025-06-19,6714
2025-06-18,5153
2025-06-17,7437
2025-06-16,5297
2025-06-14,9104
2025-06-13,7733
2025-06-12,7187
2025-06-11,6412
2025-06-10,6093
2025-06-09,7035
2025-06-07,7175
2025-06-06,6647
2025-06-05,6829
2025-06-04,7646
2025-06-03,6409
2025-06-02,7400
2025-05-31,6262
2025-05-30,6380
2025-05-29,5786
2025-05-28,5797
2025-05-27,5288
2025-05-26,5253
2025-05-24,4648
2025-05-23,4216
2025-05-22,4156
2025-05-21,5000
2025-05-20,5434
2025-05-19,5410
2025-05-17,4326
2025-05-16,4887
2025-05-15,4767
2025-05-14,5061
2025-05-13,5926
2025-05-12,6455
2025-05-10,5825
2025-05-09,7863
2025-05-08,7749
2025-05-07,7063
2025-05-06,7193
2025-05-05,6410
2025-05-03,7633
2025-05-02,6971
2025-05-01,8648
2025-04-30,9288
2025-04-29,7827
2025-04-28,8427
2025-04-26,8579
2025-04-25,7805
2025-04-24,8233
2025-04-23,8698
2025-04-22,8702
2025-04-21,9113
2025-04-19,9644
2025-04-18,9823
2025-04-17,8667
2025-04-16,9458
2025-04-15,10468
2025-04-14,11019
2025-04-12,9363
2025-04-11,9440
2025-04-10,11062
2025-04-09,11624
2025-04-08,11194
2025-04-07,11858
2025-04-05,12279
2025-04-04,13254
2025-04-03,14291
2025-04-02,14170
2025-04-01,13460
2025-03-31,14063
2025-03-29,11024
2025-03-28,11124
2025-03-27,11601
2025-03-26,12523
2025-03-25,13020
2025-03-24,13914
2025-03-22,12838
2025-03-21,12304
2025-03-20,12157
2025-03-19,14373
2025-03-18,15782
2025-03-17,14341
2025-03-15,14452
2025-03-14,12902
2025-03-13,13844
2025-03-12,13194
2025-03-11,13160
2025-03-10,13867
2025-03-08,13358
2025-03-07,14679
2025-03-06,15538
2025-03-04,16803
2025-03-03,16434
2025-03-01,15875
2025-02-28,15837
2025-02-27,15119
2025-02-26,15488
2025-02-25,15213
2025-02-24,15532
2025-02-22,14831
2025-02-21,14063
2025-02-20,13891
2025-02-19,13224
2025-02-18,13595
2025-02-17,13959
2025-02-15,13722
2025-02-14,14342
2025-02-13,15440
2025-02-11,15132
2025-02-10,15136
2025-02-08,14577
2025-02-07,14980
2025-02-06,13938
2025-02-05,13944
2025-02-04,15041
2025-02-03,15437
2025-02-01,15951
2025-01-28,12634
2025-01-27,14861
2025-01-25,13630
2025-01-24,13200
2025-01-23,12568
2025-01-22,12929
2025-01-21,12726
2025-01-20,12695
2025-01-18,13411
2025-01-17,13506
2025-01-16,14751
2025-01-15,14609
2025-01-14,14701
2025-01-13,14402
2025-01-11,14728
2025-01-10,14097
2025-01-09,14175
2025-01-08,15849
2025-01-07,15198
2025-01-06,15386
2025-01-04,15956
2025-01-03,17471
2025-01-02,17295
''';

      final predTable = '''
2025-09-13 12,785
2025-09-14 13,481
2025-09-15 14,093
2025-09-16 14,247
2025-09-17 14,635
2025-09-18 15,049
2025-09-19 16,055
2025-09-20 16,464
2025-09-21 17,424
2025-09-22 17,926
2025-09-23 18,104
2025-09-24 18,042
2025-09-25 18,607
2025-09-26 18,460
2025-09-27 18,079
2025-09-28 17,598
2025-09-29 17,328
2025-09-30 17,325
2025-10-01 15,268
2025-10-02 15,438
2025-10-03 15,229
2025-10-04 15,046
2025-10-05 15,041
2025-10-06 15,002
2025-10-07 14,716
2025-10-08 14,439
2025-10-09 14,417
2025-10-10 14,561
2025-10-11 14,411
2025-10-12 14,407
2025-10-13 14,230
2025-10-14 14,837
2025-10-15 14,799
2025-10-16 14,771
2025-10-17 14,761
2025-10-18 14,775
2025-10-19 14,865
2025-10-20 14,794
2025-10-21 14,865
2025-10-22 14,469
2025-10-23 14,228
2025-10-24 14,078
2025-10-25 14,276
2025-10-26 14,327
2025-10-27 13,868
2025-10-28 13,836
2025-10-29 13,855
2025-10-30 13,918
2025-10-31 13,771
2025-11-01 13,139
2025-11-02 13,410
2025-11-03 12,328
2025-11-04 12,446
2025-11-05 12,103
2025-11-06 11,316
2025-11-07 10,793
2025-11-08 10,575
2025-11-09 11,107
2025-11-10 11,175
2025-11-11 11,080
2025-11-12 11,078
2025-11-13 11,233
2025-11-14 11,678
2025-11-15 12,052
2025-11-16 12,188
2025-11-17 12,175
2025-11-18 12,283
2025-11-19 12,394
2025-11-20 11,697
2025-11-21 11,188
2025-11-22 11,284
2025-11-23 11,338
2025-11-24 10,872
2025-11-25 10,881
2025-11-26 11,025
2025-11-27 11,182
2025-11-28 11,491
2025-11-29 11,613
2025-11-30 11,914
2025-12-01 11,112
2025-12-02 11,475
2025-12-03 11,396
2025-12-04 11,052
2025-12-05 11,367
2025-12-06 11,307
2025-12-07 10,935
2025-12-08 10,742
2025-12-09 11,057
2025-12-10 10,844
2025-12-11 10,824
2025-12-12 10,864
2025-12-13 10,585
2025-12-14 10,974
2025-12-15 10,938
2025-12-16 10,929
2025-12-17 10,915
2025-12-18 10,837
2025-12-19 10,836
2025-12-20 10,824
2025-12-21 10,711
2025-12-22 10,661
2025-12-23 10,641
2025-12-24 10,540
2025-12-25 10,510
2025-12-26 10,627
2025-12-27 10,664
2025-12-28 10,664
2025-12-29 10,748
2025-12-30 10,737
2025-12-31 10,721
''';

      // parse history
      final Map<DateTime, double> dayMap = {};
      for (final line in hist.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(',');
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1]) ?? 0.0;
          if (!dt.isAfter(_boundaryDate)) {
            dayMap[DateTime(dt.year, dt.month, dt.day)] = v;
          }
        } catch (_) {}
      }

      // parse prediction table
      final predMap = <DateTime, double>{};
      for (final line in predTable.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(RegExp(r"\s+"));
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1].replaceAll(',', '')) ?? 0.0;
          predMap[DateTime(dt.year, dt.month, dt.day)] = v;
        } catch (_) {}
      }

      // build actual arrays from dayMap
      final year = 2025;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      final actualDates = <DateTime>[];
      final actualValues = <double>[];
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        if (dayMap.containsKey(key)) {
          actualDates.add(key);
          actualValues.add(dayMap[key]!);
        }
      }

      // pred arrays (9/13..)
      final predDates = <DateTime>[];
      final predValues = <double>[];
      final predEntries = predMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final e in predEntries) {
        predDates.add(e.key);
        predValues.add(e.value);
      }

      // monthly peaks after boundary
      final monthlyPeak = List<double>.filled(12, 0);
      final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
      for (int i = 0; i < actualDates.length; i++) {
        final d = actualDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = actualValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }
      for (int i = 0; i < predDates.length; i++) {
        final d = predDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = predValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }

      setState(() {
        _actualDates = actualDates;
        _actualValues = actualValues;
        _predDates = predDates;
        _predValues = predValues;
        _seriesAll = monthlyPeak;
        _boundaryDate = DateTime(2025, 9, 12);
      });
      return;
    }

    if (item == '고구마') {
      // history CSV (평균가) includes up to 2025-09-12
      final hist = '''
2025-09-12,25746
2025-09-11,25942
2025-09-10,25842
2025-09-09,26917
2025-09-08,28715
2025-09-06,24474
2025-09-05,26855
2025-09-04,26713
2025-09-03,27709
2025-09-02,28538
2025-09-01,30066
2025-08-30,28830
2025-08-29,29302
2025-08-28,29325
2025-08-27,28181
2025-08-26,27948
2025-08-25,30657
2025-08-23,28064
2025-08-22,27887
2025-08-21,29631
2025-08-20,30939
2025-08-19,33229
2025-08-18,34681
2025-08-16,31166
2025-08-15,32930
2025-08-14,32820
2025-08-13,34022
2025-08-12,32691
2025-08-11,35993
2025-08-09,34805
2025-08-08,35812
2025-08-07,34983
2025-08-06,36915
2025-08-05,35626
2025-08-04,33043
2025-08-01,33162
2025-07-31,30348
2025-07-30,30470
2025-07-29,29279
2025-07-28,30049
2025-07-26,24112
2025-07-25,30462
2025-07-24,27442
2025-07-23,31636
2025-07-22,31949
2025-07-21,33420
2025-07-19,31966
2025-07-18,29569
2025-07-17,29631
2025-07-16,29742
2025-07-15,22508
2025-07-14,26058
2025-07-12,21191
2025-07-11,23957
2025-07-10,26080
2025-07-09,25772
2025-07-08,30210
2025-07-07,30521
2025-07-05,30765
2025-07-04,25873
2025-07-03,25288
2025-07-02,27814
2025-07-01,29097
2025-06-30,27565
2025-06-28,32544
2025-06-27,27338
2025-06-26,32593
2025-06-25,32125
2025-06-24,27611
2025-06-23,33176
2025-06-21,29753
2025-06-20,28185
2025-06-19,33209
2025-06-18,30004
2025-06-17,29480
2025-06-16,28244
2025-06-14,32019
2025-06-13,22685
2025-06-12,24956
2025-06-11,26179
2025-06-10,26324
2025-06-09,27382
2025-06-07,29136
2025-06-06,28035
2025-06-05,33986
2025-06-04,27540
2025-06-03,29306
2025-06-02,30777
2025-05-31,39033
2025-05-30,29327
2025-05-29,31477
2025-05-28,35187
2025-05-27,36554
2025-05-26,36011
2025-05-24,36663
2025-05-23,27802
2025-05-22,24587
2025-05-21,26127
2025-05-20,29451
2025-05-19,27678
2025-05-17,29462
2025-05-16,24004
2025-05-15,27502
2025-05-14,26249
2025-05-13,25722
2025-05-12,27147
2025-05-10,29590
2025-05-09,28919
2025-05-08,26054
2025-05-07,30215
2025-05-06,29417
2025-05-05,28231
2025-05-03,26570
2025-05-02,27351
2025-05-01,30841
2025-04-30,26888
2025-04-29,24895
2025-04-28,22983
2025-04-26,22942
2025-04-25,27002
2025-04-24,23530
2025-04-23,23381
2025-04-22,25589
2025-04-21,26271
2025-04-19,26755
2025-04-18,27305
2025-04-17,24128
2025-04-16,23636
2025-04-15,24307
2025-04-14,25048
2025-04-12,23411
2025-04-11,24433
2025-04-10,25291
2025-04-09,23930
2025-04-08,23110
2025-04-07,24414
2025-04-05,24571
2025-04-04,23648
2025-04-03,24386
2025-04-02,23544
2025-04-01,23452
2025-03-31,24486
2025-03-29,25453
2025-03-28,23147
2025-03-27,25288
2025-03-26,21714
2025-03-25,24838
2025-03-24,22707
2025-03-22,24774
2025-03-21,24298
2025-03-20,26166
2025-03-19,25616
2025-03-18,25012
2025-03-17,24844
2025-03-15,26179
2025-03-14,22476
2025-03-13,26349
2025-03-12,23163
2025-03-11,24786
2025-03-10,23711
2025-03-08,26737
2025-03-07,24787
2025-03-06,26701
2025-03-04,26990
2025-03-03,26440
2025-03-01,27335
2025-02-28,26995
2025-02-27,26073
2025-02-26,26179
2025-02-25,27205
2025-02-24,25265
2025-02-22,24810
2025-02-21,25904
2025-02-20,24873
2025-02-19,25988
2025-02-18,27742
2025-02-17,26415
2025-02-15,28555
2025-02-14,29963
2025-02-13,30460
2025-02-11,29301
2025-02-10,28489
2025-02-08,31163
2025-02-07,29614
2025-02-06,29531
2025-02-05,29963
2025-02-04,30645
2025-02-03,31028
2025-02-01,30172
2025-01-28,27216
2025-01-27,27216
2025-01-25,28677
2025-01-24,26710
2025-01-23,26873
2025-01-22,24536
2025-01-21,24935
2025-01-20,26326
2025-01-18,29497
2025-01-17,28149
2025-01-16,27863
2025-01-15,27483
2025-01-14,28563
2025-01-13,26134
2025-01-11,30174
2025-01-10,24326
2025-01-09,27592
2025-01-08,27149
2025-01-07,29024
2025-01-06,29961
2025-01-04,26043
2025-01-03,27541
2025-01-02,28631
''';

      final predTable = '''
2025-09-13 24,673
2025-09-14 25,438
2025-09-15 25,195
2025-09-16 24,710
2025-09-17 24,820
2025-09-18 24,820
2025-09-19 25,011
2025-09-20 25,152
2025-09-21 25,215
2025-09-22 24,684
2025-09-23 25,126
2025-09-24 25,014
2025-09-25 25,105
2025-09-26 25,171
2025-09-27 25,307
2025-09-28 25,806
2025-09-29 25,763
2025-09-30 25,859
2025-10-01 26,250
2025-10-02 25,928
2025-10-03 26,213
2025-10-04 25,688
2025-10-05 25,211
2025-10-06 25,096
2025-10-07 25,273
2025-10-08 25,139
2025-10-09 25,028
2025-10-10 25,059
2025-10-11 25,015
2025-10-12 25,089
2025-10-13 25,097
2025-10-14 25,319
2025-10-15 25,340
2025-10-16 25,461
2025-10-17 25,400
2025-10-18 25,278
2025-10-19 25,005
2025-10-20 24,999
2025-10-21 25,147
2025-10-22 25,221
2025-10-23 25,208
2025-10-24 25,140
2025-10-25 25,455
2025-10-26 25,442
2025-10-27 25,526
2025-10-28 25,676
2025-10-29 25,810
2025-10-30 25,962
2025-10-31 26,000
2025-11-01 26,269
2025-11-02 25,951
2025-11-03 26,178
2025-11-04 25,372
2025-11-05 25,258
2025-11-06 25,353
2025-11-07 25,082
2025-11-08 25,103
2025-11-09 25,200
2025-11-10 25,236
2025-11-11 25,155
2025-11-12 25,186
2025-11-13 25,376
2025-11-14 25,545
2025-11-15 25,584
2025-11-16 25,488
2025-11-17 25,342
2025-11-18 25,230
2025-11-19 25,147
2025-11-20 25,225
2025-11-21 25,320
2025-11-22 25,379
2025-11-23 25,350
2025-11-24 25,320
2025-11-25 25,533
2025-11-26 25,539
2025-11-27 25,790
2025-11-28 25,867
2025-11-29 25,982
2025-11-30 26,151
2025-12-01 26,315
2025-12-02 26,117
2025-12-03 26,383
2025-12-04 25,659
2025-12-05 25,831
2025-12-06 25,709
2025-12-07 25,345
2025-12-08 25,547
2025-12-09 25,741
2025-12-10 25,632
2025-12-11 25,582
2025-12-12 25,609
2025-12-13 25,812
2025-12-14 26,079
2025-12-15 26,256
2025-12-16 26,531
2025-12-17 27,333
2025-12-18 28,153
2025-12-19 28,394
2025-12-20 28,020
2025-12-21 27,874
2025-12-22 27,837
2025-12-23 27,896
2025-12-24 28,028
2025-12-25 27,996
2025-12-26 27,937
2025-12-27 28,188
2025-12-28 28,458
2025-12-29 28,493
2025-12-30 28,539
2025-12-31 28,618
''';

      // parse history CSV into map
      final Map<DateTime, double> dayMap = {};
      for (final line in hist.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(',');
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1]) ?? 0.0;
          if (!dt.isAfter(_boundaryDate)) {
            dayMap[DateTime(dt.year, dt.month, dt.day)] = v;
          }
        } catch (_) {}
      }

      // parse prediction table into predMap
      final predMap = <DateTime, double>{};
      for (final line in predTable.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final parts = t.split(RegExp(r"\s+"));
        if (parts.length < 2) continue;
        try {
          final dt = DateTime.parse(parts[0]);
          final v = double.tryParse(parts[1].replaceAll(',', '')) ?? 0.0;
          predMap[DateTime(dt.year, dt.month, dt.day)] = v;
        } catch (_) {}
      }

      // build actual arrays
      final year = 2025;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      final actualDates = <DateTime>[];
      final actualValues = <double>[];
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        if (dayMap.containsKey(key)) {
          actualDates.add(key);
          actualValues.add(dayMap[key]!);
        }
      }

      // build pred arrays (full predTable)
      final predDates = <DateTime>[];
      final predValues = <double>[];
      final predEntries = predMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final e in predEntries) {
        predDates.add(e.key);
        predValues.add(e.value);
      }

      // monthly peaks after boundary
      final monthlyPeak = List<double>.filled(12, 0);
      final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
      for (int i = 0; i < actualDates.length; i++) {
        final d = actualDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = actualValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }
      for (int i = 0; i < predDates.length; i++) {
        final d = predDates[i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = predValues[i];
        final idx = d.month - 1;
        monthlyPeak[idx] = math.max(monthlyPeak[idx], v);
      }

      setState(() {
        _actualDates = actualDates;
        _actualValues = actualValues;
        _predDates = predDates;
        _predValues = predValues;
        _seriesAll = monthlyPeak;
        _boundaryDate = DateTime(2025, 9, 12);
      });
      return;
    }

    // Fallback: synthetic series for other items (split into actual/pred)
    final seed = item.hashCode;
    final rnd = math.Random(seed);
    final base = {
      '고구마': 30000.0,
      '양파': 9000.0,
      '배추': 7000.0,
      '무': 6000.0,
    }[item] ?? 10000.0;

    final s = List<double>.generate(12, (i) {
      final monthFactor = 1.0 + 0.10 * math.sin((i / 12.0) * 2 * math.pi + 0.4);
      final noise = (rnd.nextDouble() - 0.5) * 0.14; // +/-7%
      return base * (1 + noise) * monthFactor;
    });
    for (int k = 1; k < s.length - 1; k++) {
      s[k] = (s[k - 1] + s[k] + s[k + 1]) / 3.0;
    }

    // For other items, synthesize daily data across the year
    final year = 2025;
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final actualDates = <DateTime>[];
    final actualValues = <double>[];
    final predDates = <DateTime>[];
    final predValues = <double>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final m = d.month - 1;
      final basev = s[m];
      final noise = (rnd.nextDouble() - 0.5) * 0.12;
      final v = basev * (1 + noise);
      if (d.isBefore(_boundaryDate.add(const Duration(days: 1)))) {
        actualDates.add(d);
        actualValues.add(v);
      } else {
        predDates.add(d);
        predValues.add(v);
      }
    }
    // monthly peak computed only from dates on/after Sep 13
    final monthlyPeak = List<double>.filled(12, 0);
    final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
    for (int i = 0; i < actualDates.length; i++) {
      final d = actualDates[i];
      if (d.isBefore(boundaryExclusive)) continue;
      monthlyPeak[d.month - 1] = math.max(monthlyPeak[d.month - 1], actualValues[i]);
    }
    for (int i = 0; i < predDates.length; i++) {
      final d = predDates[i];
      if (d.isBefore(boundaryExclusive)) continue;
      monthlyPeak[d.month - 1] = math.max(monthlyPeak[d.month - 1], predValues[i]);
    }
    setState(() {
      _actualDates = actualDates;
      _actualValues = actualValues;
      _predDates = predDates;
      _predValues = predValues;
      _seriesAll = monthlyPeak;
      _boundaryDate = DateTime(2025, 9, 12);
    });
  }

  Widget _buildTop3Cards() {
    // Compute monthly averages (only considering dates on/after prediction boundary)
  final boundaryExclusive = _boundaryDate.add(const Duration(days: 1));
    final monthVals = List<List<double>>.generate(12, (_) => []);
    if (_actualDates != null && _actualValues != null) {
      for (int i = 0; i < _actualDates!.length; i++) {
        final d = _actualDates![i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = _actualValues![i];
        monthVals[d.month - 1].add(v);
      }
    }
    if (_predDates != null && _predValues != null) {
      for (int i = 0; i < _predDates!.length; i++) {
        final d = _predDates![i];
        if (d.isBefore(boundaryExclusive)) continue;
        final v = _predValues![i];
        monthVals[d.month - 1].add(v);
      }
    }

    // fallback: if a month has no values, use the monthlyPeaks value so UI remains filled
    final peaks = _seriesAll ?? List<double>.filled(12, 0);
    final monthlyAvg = List<double>.generate(12, (m) {
      final vals = monthVals[m];
      if (vals.isEmpty) return peaks[m];
      final sum = vals.reduce((a, b) => a + b);
      return sum / vals.length;
    });

    final indexed = monthlyAvg.asMap().entries.map((e) => MapEntry(e.key, e.value)).toList();
    indexed.sort((a, b) => b.value.compareTo(a.value));
    final top = indexed.take(3).toList();

    String fmtVal(double val) {
      return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",") }원';
    }

    String monthLabel(int idx) {
      final m = (idx + 1);
      return '$m월';
    }

    return Column(
      children: [
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: const Color(0xFFEFFFEF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFF7E6))),
            child: Column(children: [
              Text('1위', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
              const SizedBox(height: 8),
              Text(monthLabel(top[0].key), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700))),
              const SizedBox(height: 6),
              Text(fmtVal(top[0].value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFFD700))),
            ]),
          )),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFFFEF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFF7E6))),
            child: Column(children: [
              Text('2위', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
              const SizedBox(height: 8),
              Text(monthLabel(top[1].key), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFC0C0C0))),
              const SizedBox(height: 6),
              Text(fmtVal(top[1].value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFC0C0C0))),
            ]),
          )),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(color: const Color(0xFFEFFFEF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFF7E6))),
            child: Column(children: [
              Text('3위', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
              const SizedBox(height: 8),
              Text(monthLabel(top[2].key), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFCD7F32))),
              const SizedBox(height: 6),
              Text(fmtVal(top[2].value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFCD7F32))),
            ]),
          )),
        ]),
  const SizedBox(height: 8),
  const Text('집계 기준: 2025-09-12', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // Storage info per item. The guidance below summarizes common Korean best-practices
  // (농촌진흥청, aT 등 권장사항 기반 요약). For production, replace with
  // verified citations or localised content from official sources.
  Widget _storageWidget() {
    String title = '보관 방법';
    String desc = '품목을 선택하면 보관 방법과 보관 기간이 표시됩니다.';
    String tip = '';

    switch (_selected) {
      case '감자(수미)':
        title = '보관 방법';
        desc = '서늘하고 통풍이 잘 되는 곳에서 밀폐 용기나 종이상자에 담아 보관. 직사광선과 습기를 피하세요.';
        tip = '저온(약 4~10°C)에서 보관하면 품질 유지 기간이 길어지며, 약 60~120일 보관 가능(조건에 따라 다름).';
        break;
      case '고구마':
        title = '보관 방법';
        desc = '직사광선을 피하고 통풍이 잘되는 서늘하고 건조한 곳에 보관. 보관 전 충분히 건조시키세요.';
        tip = '저온저장은 동해를 일으킬 수 있으므로 12~16°C가 권장되며, 적정 보관 기간은 약 60~90일입니다.';
        break;
      case '양파':
        title = '보관 방법';
        desc = '껍질을 완전히 건조시킨 후 망에 넣어 통풍이 잘 되는 건조한 곳에 보관하세요.';
        tip = '저온(0~5°C)에서 건조 보관 시 약 120일 정도 유지 가능; 습도와 통풍 관리가 중요합니다.';
        break;
      case '배추':
        title = '보관 방법';
        desc = '세척 후 저장보다는 건조 상태로 보관. 냉장(0~4°C) 보관 시 신선도 유지 가능.';
        tip = '절임(김치)용으로는 보관기간이 연장되며, 신선한 상태로는 약 30~60일 정도 보관 가능합니다.';
        break;
      case '무':
        title = '보관 방법';
        desc = '흙을 털고 건조시킨 후 통풍이 잘되는 서늘한 곳이나 냉장(0~4°C)에서 보관하세요.';
        tip = '상온에서는 짧게(약 1~2주), 냉장 보관 시 약 30~60일 보관 가능하며 포장 상태와 습도에 따라 차이 있음.';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFEFFDF3), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF9EE6B9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF00C853), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.grain, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0E8B59)))),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 12),
          if (tip.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0F7EA))),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Color(0xFFF6C94A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('보관 팁\n$tip', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }

}

class _ForecastPainter extends CustomPainter {
  final List<DateTime> actualDates;
  final List<double> actualValues;
  final List<DateTime> predDates;
  final List<double> predValues;
  final DateTime boundaryDate;
  final String legendActual;
  final String legendPred;
  final List<double> monthlyPeaks;
  _ForecastPainter({
    required this.actualDates,
    required this.actualValues,
    required this.predDates,
    required this.predValues,
    required this.boundaryDate,
    required this.monthlyPeaks,
    required this.legendActual,
    required this.legendPred,
  });

  @override
  void paint(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  // gather stats from daily values
  final values = <double>[];
  values.addAll(actualValues);
  values.addAll(predValues);
  if (values.isEmpty) return;
  final maxv = values.reduce(math.max);
  final minv = values.reduce(math.min);
  final span = (maxv - minv == 0 ? 1 : maxv - minv).toDouble();

  // time mapping across the year
  final year = boundaryDate.year;
  final startOfYear = DateTime(year, 1, 1);
  final totalDays = DateTime(year + 1, 1, 1).difference(startOfYear).inDays.toDouble();
  double xAtDate(DateTime d) => ((d.difference(startOfYear).inDays.toDouble()) / (totalDays - 1)) * w;
  double yAt(double v) => h - ((v - minv) / span) * h;
  // x position of the boundary date (available to all later blocks)
  final bx = xAtDate(boundaryDate);

  // draw gridlines (no numeric labels on left as requested)
    int niceStep(double range) {
      final raw = range / 5.0; // aim for ~5 lines
      final pow10 = math.pow(10, (math.log(raw) / math.ln10).floor());
      final n = raw / pow10;
      double step;
      if (n < 1.5) step = 1 * pow10.toDouble();
      else if (n < 3) step = 2 * pow10.toDouble();
      else if (n < 7) step = 5 * pow10.toDouble();
      else step = 10 * pow10.toDouble();
      return step.round();
    }
    final step = niceStep(span);
    final yGridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
  final minTick = (minv / step).floor() * step;
    for (double v = minTick.toDouble(); v <= maxv + 0.1; v += step) {
      final yy = yAt(v);
      canvas.drawLine(Offset(0, yy), Offset(w, yy), yGridPaint);
    }

  // month labels moved to draw after fills so they're visible

  // draw actual (blue solid) - we only fill left side, no stroke
    // Smooth the actual daily series with a simple cubic Bezier interpolation between points
    Path? aPath;
    if (actualDates.isNotEmpty) {
      aPath = Path();
      for (int i = 0; i < actualDates.length; i++) {
        final x = xAtDate(actualDates[i]);
        final y = yAt(actualValues[i]);
        if (i == 0) {
          aPath.moveTo(x, y);
        } else {
          final prevX = xAtDate(actualDates[i - 1]);
          final prevY = yAt(actualValues[i - 1]);
          final midX = (prevX + x) / 2;
          final cp1 = Offset(midX, prevY);
          final cp2 = Offset(midX, y);
          aPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, x, y);
        }
      }
  // area fill under curve, but clipped to the left of the boundary date
  final area = Path.from(aPath)..lineTo(w, h)..lineTo(0, h)..close();
  canvas.save();
  canvas.clipRect(Rect.fromLTWH(0, 0, bx, h));
  canvas.drawPath(area, Paint()..color = const Color(0xFFDDEBF7)); // pale blue left fill
  // draw smooth solid actual stroke clipped to left side
  final actualStroke = Paint()
    ..color = const Color(0xFF1F77B4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(aPath, actualStroke);
  canvas.restore();
    }

    // draw predicted (red dashed) from boundary to months with pred
  final dashColor = const Color(0xFFD62728);
  Offset? prev;
  final List<Offset> predOffsets = [];
    // anchor: last actual on or before boundaryDate
    for (int i = actualDates.length - 1; i >= 0; i--) {
      if (!actualDates[i].isAfter(boundaryDate)) { prev = Offset(xAtDate(actualDates[i]), yAt(actualValues[i])); break; }
    }
    if (prev == null && predDates.isNotEmpty) {
      prev = Offset(xAtDate(predDates.first), yAt(predValues.first));
    }
  // dashed helper removed — using PathMetrics to draw dashed smoothed pred path
    if (predDates.isNotEmpty) {
      for (int i = 0; i < predDates.length; i++) {
        final p = Offset(xAtDate(predDates[i]), yAt(predValues[i]));
        predOffsets.add(p);
      }
      // build smooth pred path (cubic Bezier between pred offsets)
      if (predOffsets.isNotEmpty) {
        final smoothPred = Path();
        for (int i = 0; i < predOffsets.length; i++) {
          final pt = predOffsets[i];
          if (i == 0) {
            smoothPred.moveTo(pt.dx, pt.dy);
          } else {
            final prevPt = predOffsets[i - 1];
            final midX = (prevPt.dx + pt.dx) / 2;
            final cp1 = Offset(midX, prevPt.dy);
            final cp2 = Offset(midX, pt.dy);
            smoothPred.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pt.dx, pt.dy);
          }
        }

        // draw smooth solid predicted stroke
        final predPaint = Paint()
          ..color = dashColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(smoothPred, predPaint);

        // fill under predicted area (clipped to right of boundary)
        final predFillPath = Path.from(smoothPred);
        predFillPath.lineTo(w, h);
        predFillPath.lineTo(bx, h);
        predFillPath.close();
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(bx, 0, w - bx, h));
        canvas.drawPath(predFillPath, Paint()..color = const Color(0x33FFCDD2)); // pale red right fill
        canvas.restore();
      }
    }

    // draw Top3 monthly markers (use _seriesAll peaks)
    if (monthlyPeaks.isNotEmpty) {
      final markerColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
      final indexed = monthlyPeaks.asMap().entries.map((e) => MapEntry(e.key + 1, e.value)).toList();
      indexed.sort((a, b) => b.value.compareTo(a.value));
      final top3 = indexed.take(3).toList();
      for (int rank = 0; rank < top3.length; rank++) {
        final month = top3[rank].key;
        final value = top3[rank].value;
        final repDay = DateTime(boundaryDate.year, month, 15);
        final pos = Offset(xAtDate(repDay), yAt(value));
        final fill = Paint()..color = markerColors[rank];
        final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
        // offset slightly up so marker sits above the line
        final cpos = pos.translate(0, -6);
        canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: cpos, radius: 11)), Colors.black, 2.5, true);
        canvas.drawCircle(cpos, 11, fill);
        canvas.drawCircle(cpos, 11, border);
        final tp = TextPainter(text: TextSpan(text: '${rank + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(cpos.dx - tp.width / 2, cpos.dy - tp.height / 2));
      }
    }

    // month labels (1..12) - paint now so they appear above fills
    final monthStyle = const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w800);
    const double shiftRight = 8.0; // nudge labels slightly to the right
    const double sidePad = 6.0;
    for (int m = 1; m <= 12; m++) {
      final dt = DateTime(year, m, 1);
      final mx = xAtDate(dt);
      final tp = TextPainter(text: TextSpan(text: '$m', style: monthStyle), textDirection: TextDirection.ltr)..layout();
      double px = mx - tp.width / 2 + shiftRight;
      if (px < sidePad) px = sidePad;
      if (px + tp.width > w - sidePad) px = w - sidePad - tp.width;
      tp.paint(canvas, Offset(px, h - 12));
    }

    // vertical dashed boundary line with label
  // bx already computed earlier when drawing fills
    final bPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double yPos = 0;
    while (yPos < h) {
      final double yEnd = (yPos + 7).clamp(0, h);
      canvas.drawLine(Offset(bx, yPos), Offset(bx, yEnd), bPaint);
      yPos += 7 + 5;
    }
  // boundary label intentionally removed

  // no legend drawn on canvas (user requested removal)
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

