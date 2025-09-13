import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:charset_converter/charset_converter.dart';
import 'dart:typed_data';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String _authKey = '-fGwWCvnTcexsFgr533Hzg';
  final String _baseUrl = 'https://apihub.kma.go.kr/api/typ01/url/wrn_now_data_new.php';

  bool _loading = false;
  // no summary string; we show grouped cards directly
  List<Map<String, String>> _items = [];
  Map<String, List<Map<String, String>>> _grouped = {};
  final Set<String> _expandedRegions = {};
  Map<String, int> _typeCounts = {};
  DateTime _selectedDate = DateTime(2025, 9, 12);

  bool _looksKorean(String s) {
    final matches = RegExp(r'[가-힣]').allMatches(s);
    final len = s.runes.length;
    if (matches.isEmpty) return false;
    final ratio = matches.length / (len == 0 ? 1 : len);
    return matches.length >= 5 || ratio > 0.05; // heuristic
  }

  Future<String> _decodeBest(List<int> bytes) async {
    // 1) strict UTF-8
    try {
      final s = utf8.decode(bytes);
      if (_looksKorean(s)) return s;
    } catch (_) {}
    // 2) EUC-KR
    try {
      final s = await CharsetConverter.decode('euc-kr', Uint8List.fromList(bytes));
      if (_looksKorean(s)) return s;
    } catch (_) {}
    // 3) CP949
    try {
      final s = await CharsetConverter.decode('cp949', Uint8List.fromList(bytes));
      if (_looksKorean(s)) return s;
    } catch (_) {}
    // 4) permissive UTF-8 or raw fallback
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  Future<void> _fetchWarningsForDate(String tm) async {
    setState(() {
      _loading = true;
    });

    try {
  // Prefer machine-friendly output
  final uri = Uri.parse('$_baseUrl?fe=f&tm=$tm&disp=0&help=0&authKey=$_authKey');
  final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      final String body = await _decodeBest(resp.bodyBytes);
      List<Map<String, String>> parsed = _parseItems(body);
      if (parsed.isEmpty) {
        // fallback for help=1 or plain text format
        parsed = _parsePlainTable(body);
      }

      // group by region (use REG_UP_KO first, fallback to REG_KO)
      final Map<String, List<Map<String, String>>> grouped = {};
      for (final it in parsed) {
        final key = (it['REG_UP_KO'] ?? '').trim().isNotEmpty
            ? (it['REG_UP_KO'] ?? '').trim()
            : ((it['REG_KO'] ?? '').trim().isNotEmpty ? (it['REG_KO'] ?? '').trim() : '기타');
        (grouped[key] ??= []).add(it);
      }

      setState(() {
        _items = parsed;
        _grouped = grouped;
  _typeCounts = _buildTypeCounts(parsed);
      });
    } catch (e) {
      setState(() {
  // keep items/grouped as-is; show empty state in UI
      });
    } finally {
      setState(() => _loading = false);
    }
  }
  @override
  void initState() {
    super.initState();
    // fetch for default date 2025-09-12
    _fetchWarningsForDate(_tmForDate(_selectedDate));
  }

  String _pad2(int v) => v.toString().padLeft(2, '0');
  String _tmForDate(DateTime d) => '${d.year}${_pad2(d.month)}${_pad2(d.day)}0000';

  Future<void> _pickDate() async {
    final pick = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (pick == null) return;
    setState(() {
      _selectedDate = pick;
      _loading = true;
    });
    await _fetchWarningsForDate(_tmForDate(_selectedDate));
  }

  List<Map<String, String>> _parseItems(String body) {
    final List<Map<String, String>> out = [];
    final itemRe = RegExp(r'<item[\s\S]*?>[\s\S]*?<\/item>', multiLine: true, caseSensitive: false);
    final matches = itemRe.allMatches(body).toList();
    if (matches.isEmpty) return out;
    for (final m in matches) {
      final block = m.group(0) ?? '';
      String getTag(String tag) {
        final re = RegExp('<${tag}[^>]*>([\s\S]*?)<\/${tag}>', caseSensitive: false);
        final mm = re.firstMatch(block);
        return mm?.group(1)?.trim() ?? '';
      }

      final map = <String, String>{
        'REG_UP_KO': getTag('REG_UP_KO'),
        'REG_KO': getTag('REG_KO'),
        'WRN': getTag('WRN'),
        'LVL': getTag('LVL'),
        'CMD': getTag('CMD'),
        'TM_FC': getTag('TM_FC'),
        'TM_EF': getTag('TM_EF'),
      };
      final hasCore = (map['WRN']?.isNotEmpty ?? false) || (map['REG_KO']?.isNotEmpty ?? false) || (map['REG_UP_KO']?.isNotEmpty ?? false);
      if (hasCore) out.add(map);
    }
    return out;
  }

  Map<String, int> _buildTypeCounts(List<Map<String, String>> items) {
    final m = <String, int>{};
    for (final it in items) {
      final t = (it['WRN'] ?? '').trim();
      if (t.isEmpty) continue;
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }

  Widget _typeChip(String type, int count) {
    // 기본 색상 (파란 계열). 위험도가 높은 유형 추정 키워드에 따라 붉은 계열로 표시
    Color bg = const Color(0xFFEAF2FF);
    Color fg = const Color(0xFF1E40AF);
    Color bd = const Color(0xFFBFDBFE);
    final dangerHints = ['태풍', '호우', '대설', '풍랑', '폭염', '한파'];
    if (dangerHints.any((k) => type.contains(k))) {
      bg = const Color(0xFFFFECEC);
      fg = const Color(0xFFB00020);
      bd = const Color(0xFFFFC9C9);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 6),
          Text('$type $count건', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  // Parse plain text table rows (when help=1 or provider returns non-XML list)
  List<Map<String, String>> _parsePlainTable(String body) {
    final out = <Map<String, String>>[];
    final lines = body.split(RegExp(r'\r?\n'));
    final codeRe = RegExp(r'^[A-Z][0-9]{4,}');
    for (var line in lines) {
      var t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      // drop trailing ",=" if present
      t = t.replaceFirst(RegExp(r',=\s*$'), '');
      // fast check: code at start and at least a few commas
      if (!codeRe.hasMatch(t) || ','.allMatches(t).length < 8) continue;
      final parts = t.split(',').map((s) => s.trim()).toList();
      if (parts.length < 9) continue;
      String get(int idx) => idx < parts.length ? parts[idx] : '';
      out.add({
        'REG_UP': get(0),
        'REG_UP_KO': get(1),
        'REG_ID': get(2),
        'REG_KO': get(3),
        'TM_FC': get(4),
        'TM_EF': get(5),
        'WRN': get(6),
        'LVL': get(7),
        'CMD': get(8),
        'ED_TM': get(9),
      });
    }
    return out;
  }

  Widget _regionCard(String region, List<Map<String, String>> items) {
  String shortFmt(String t) {
      // return 25.09.11 style
      try {
        // try digits-only like 202509112300 or 20250911
        final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 8) {
          final y = digits.substring(0,4);
          final m = digits.substring(4,6);
          final d = digits.substring(6,8);
          final yy = int.parse(y) % 100;
          return '${yy.toString().padLeft(2, '0')}.${m}.${d}';
        }
        // try ISO-like 2025-09-11
        final re = RegExp(r'(\d{4})[-/.](\d{2})[-/.](\d{2})');
        final mm = re.firstMatch(t);
        if (mm != null) {
          final yy = int.parse(mm.group(1)!.substring(2));
          return '${yy.toString().padLeft(2, '0')}.${mm.group(2)}.${mm.group(3)}';
        }
      } catch (_) {}
      return t;
    }

    // summarize by WRN within region
    final Map<String, int> byType = {};
    for (final it in items) {
      final wrn = (it['WRN'] ?? '').trim();
      if (wrn.isEmpty) continue;
      byType[wrn] = (byType[wrn] ?? 0) + 1;
    }
    final summary = byType.entries.map((e) => '${e.key} ${e.value}건').join(' · ');

    final expanded = _expandedRegions.contains(region);

    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expandedRegions.remove(region);
        } else {
          _expandedRegions.add(region);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
          border: Border.all(color: const Color(0xFFE5F3FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEBF5FF), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.place, color: Color(0xFF2D9CFF), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(region, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEFFDF3), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF9EE6B9))),
                  child: Text('${items.length}건', style: const TextStyle(color: Color(0xFF0E8B59), fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                const SizedBox(width: 8),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.black54),
              ],
            ),
            const SizedBox(height: 10),
            Text(summary.isEmpty ? '요약 없음' : summary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            if (expanded) ...[
              const SizedBox(height: 12),
              ...items.map((it) {
                final wrn = it['WRN'] ?? '';
                final lvl = it['LVL'] ?? '';
                final cmd = it['CMD'] ?? '';
                final fc = it['TM_FC'] ?? '';
                final ef = it['TM_EF'] ?? '';
                final name = it['REG_KO'] ?? '';

                Color badgeColor = const Color(0xFF9EE6B9);
                Color badgeText = const Color(0xFF0E8B59);
                if (lvl.contains('경보')) { badgeColor = const Color(0xFFFFE0E0); badgeText = const Color(0xFFB00020); }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name.isEmpty ? region : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                              child: Text('${wrn}${lvl.isNotEmpty ? '·$lvl' : ''}', style: TextStyle(color: badgeText, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (cmd.isNotEmpty) Text(cmd, style: const TextStyle(color: Colors.black87, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (fc.isNotEmpty) Flexible(child: Text('발표 ${shortFmt(fc)}', style: const TextStyle(color: Colors.black54), overflow: TextOverflow.ellipsis)),
                        if (ef.isNotEmpty) ...[const SizedBox(width: 8), Flexible(child: Text('효력 ${shortFmt(ef)}', style: const TextStyle(color: Colors.black54), overflow: TextOverflow.ellipsis))],
                      ]),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF2D9CFF)]),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Container(
                    height: 84,
                    alignment: Alignment.center,
                    child: const Text('오늘의 특보', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 날짜/통계 (큰 글씨로 간단 표기)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2D9CFF)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Text('조회일: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    if (!_loading) Text('지역 ${_grouped.length} · 건수 ${_items.length}', style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 상단 요약 칩(경보 종류별)
              if (!_loading && _items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _typeCounts.entries.map((e) => _typeChip(e.key, e.value)).toList(),
                  ),
                ),
              if (!_loading && _items.isNotEmpty) const SizedBox(height: 12),
              // 지역별 카드 목록
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _grouped.isEmpty
                        ? const Center(child: Text('해당 날짜 활성 특보가 없습니다.'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: _grouped.entries.map((e) => _regionCard(e.key, e.value)).toList(),
                          ),
              ),
            ],
          ),

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
                backgroundColor: const Color(0xFF00B0FF),
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
