import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/registered_item.dart';
import 'package:flutter_application_1/services/item_service.dart';
import 'package:flutter_application_1/services/kamis_daily_price_service.dart';

class ItemAddScreen extends StatefulWidget {
  const ItemAddScreen({super.key});
  @override
  State<ItemAddScreen> createState() => _ItemAddScreenState();
}

class _ItemAddScreenState extends State<ItemAddScreen> {
  String? _item;
  String _selectedGrade = '상품';
  bool _normalizeKg = true; // 1kg 환산 옵션
  final _svc = ItemService();
  final _kamis = KamisDailyPriceService();
  bool _loading = false;
  static const String _defaultRegion = '서울 가락시장';
  static const List<_ItemOption> _options = [
    _ItemOption('팥', '🫘'),
    _ItemOption('감자', '🥔'),
    _ItemOption('고구마', '🍠'),
    _ItemOption('콩', '🫘'),
    _ItemOption('찹쌀', '🌾'),
    _ItemOption('쌀', '🌾'),
    // 과일류 대표 추가
    _ItemOption('사과', '🍎'),
    _ItemOption('배', '🍐'),
    _ItemOption('포도', '🍇'),
    _ItemOption('딸기', '🍓'),
    _ItemOption('감귤', '🍊'),
    // 수산물 대표 추가
    _ItemOption('고등어', '🐟'),
    _ItemOption('오징어', '🦑'),
    _ItemOption('새우', '🦐'),
    _ItemOption('꽃게', '🦀'),
    _ItemOption('멸치', '🐟'),
  // AI 학습에 사용했던 해산물/수산물 샘플
  _ItemOption('갈치', '🐟'),
  _ItemOption('굴', '🦪'),
  _ItemOption('김', '🍙'),
  _ItemOption('낙지', '🦑'),
  _ItemOption('넙치', '🐠'),
  _ItemOption('문어', '🐙'),
  ];
  
  List<_ItemOption> get _filteredOptions {
    final q = _controller.text.trim();
    if (q.isEmpty) return _options;
    final lower = q.toLowerCase();
    return _options.where((o) => o.value.toLowerCase().contains(lower)).toList();
  }
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  @override
  void dispose() { 
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAEE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 6),
              const Text('🌱  품목 등록', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            _buildSimpleCard(),
          ]),
        ),
      ),
    );
  }

  Widget _buildSimpleCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6))]),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('품목 선택', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _RoundedField(
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(border: InputBorder.none, hintText: '품목명을 입력하고 검색버튼 또는 엔터'),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  setState(() => _item = v.trim());
                  _fetchAndSubmit();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF2FA24A)),
              onPressed: () {
                final v = _controller.text.trim();
                if (v.isEmpty) return;
                setState(() => _item = v);
                _fetchAndSubmit();
              },
            )
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _filteredOptions.map((opt) => GestureDetector(
            onTap: () { setState(() { _item = opt.value; _controller.text = opt.value; }); _fetchAndSubmit(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF4F6F0), borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(opt.emoji), const SizedBox(width: 8), Text(opt.value)]),
            ),
          )).toList(),
        ),
        const SizedBox(height: 18),
        const Text('등급 / 옵션', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          _gradeChip('상품'), const SizedBox(width: 8), _gradeChip('중품'), const SizedBox(width: 8), _gradeChip('하품'), const Spacer(),
          Row(children: [
            const Text('1kg 환산', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(width: 4),
            Switch(value: _normalizeKg, onChanged: (v) => setState(() => _normalizeKg = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ])
        ]),
        if (_loading) ...[
          const SizedBox(height: 20), const Center(child: CircularProgressIndicator()), const SizedBox(height: 4), const Center(child: Text('가격 조회 중...')),
        ],
        if (!_loading && _item != null) ...[
          const SizedBox(height: 20), const Text('선택 즉시 가격을 불러와 홈으로 돌아갑니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ]),
    );
  }

  Future<void> _fetchAndSubmit() async {
    if (_item == null || _loading) return; setState(() => _loading = true);
  // 입력한 품목명이 추천 목록에 없을 수 있으므로 안전한 fallback 처리
  String emoji;
  final opt = _options.firstWhere((e) => e.value == _item!, orElse: () => _ItemOption(_item!, '🌱'));
  emoji = opt.emoji;
    final result = await _kamis.fetchTodayPrice(itemName: _item!, regionName: _defaultRegion, desiredRank: _selectedGrade);
    int price = result?.price ?? 0;
    String resolvedRank = result?.rank ?? _selectedGrade;
    final unitRaw = (result?.unit ?? '').trim();
    String unit = unitRaw.isEmpty ? 'kg' : unitRaw;

    // 1kg 환산
    double? qtyKg = _extractKg(unit);
    if (_normalizeKg && qtyKg != null && qtyKg > 0) { final perKg = price / qtyKg; price = perKg.round(); unit = '1kg기준'; }
    const bestDays = 2;
    final item = RegisteredItem(
      emoji: emoji,
      name: _item!,
      grade: resolvedRank,
      quantity: 1,
      unit: unit,
      packName: null,
      region: _defaultRegion,
      currentPrice: price,
      bestAfterDays: bestDays,
      priceDay: result?.day,
    );
    await _svc.addItem(item);
    if (!mounted) return; if (result == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API 가격 없음 / 실패'))); }
    setState(() => _loading = false); Navigator.of(context).pop(item);
  }

  Widget _gradeChip(String label) {
    final isSel = _selectedGrade == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedGrade = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isSel ? const Color(0xFF2FA24A) : const Color(0xFFF0F2ED), borderRadius: BorderRadius.circular(18)),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF445355), fontWeight: FontWeight.w800)),
      ),
    );
  }

  double? _extractKg(String unit) { final match = RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false).firstMatch(unit); if (match != null) { return double.tryParse(match.group(1)!); } return null; }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) { return Container(decoration: BoxDecoration(color: const Color(0xFFF4F6F0), borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: child); }
}

class _ItemOption { final String value; final String emoji; const _ItemOption(this.value, this.emoji); }
