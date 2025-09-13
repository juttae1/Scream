import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/registered_item.dart';
import 'package:flutter_application_1/services/kamis_daily_price_service.dart';
import 'package:flutter_application_1/ui/items/item_add_screen.dart';

class CompareCard extends StatefulWidget {
  const CompareCard({super.key, this.item, this.onRefresh, this.refreshing = false});
  final RegisteredItem? item;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  State<CompareCard> createState() => _CompareCardState();
}

class _CompareCardState extends State<CompareCard> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedDatePrice;
  String? _selectedDateUnit;
  bool _loadingDatePrice = false;
  final _kamis = KamisDailyPriceService();
  int _computeTotalFromItem(RegisteredItem item) {
    // 간단 계산: 등록된 현재가 * 수량 (단위 변환 없음)
    return (item.currentPrice * item.quantity).round();
  }

  // unit normalization helper removed (handled elsewhere)

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  Future<void> _pickDateAndLoad() async {
    // allow up to 6 months (approx. 180 days) selection
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 180)), lastDate: DateTime.now());
    if (d == null) return;
    setState(() => _selectedDate = d);
    await _loadDatePrice();
  }

  Future<void> _loadDatePrice() async {
    final it = widget.item;
    if (it == null) return;
    setState(() => _loadingDatePrice = true);
  // request the exact selected date (no backward backtracking) to get that day's price
  final res = await _kamis.fetchTodayPrice(itemName: it.name, regionName: it.region, desiredRank: it.grade.isNotEmpty ? it.grade : null, date: _selectedDate, backtrackDays: 0);
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _selectedDatePrice = null;
        _selectedDateUnit = null;
        _loadingDatePrice = false;
      });
      return;
    }
    // normalize per-kg if unit indicates weight
    int finalPrice = res.price;
    String finalUnit = res.unit.isNotEmpty ? res.unit : it.unit;
    final m = RegExp(r"(\d+(?:\.\d+)?)\s*kg", caseSensitive: false).firstMatch(finalUnit);
    if (m != null) {
      final double? qty = double.tryParse(m.group(1)!);
      if (qty != null && qty > 0) {
        finalPrice = (res.price / qty).round();
        finalUnit = '1kg기준';
      }
    }
    setState(() {
      _selectedDatePrice = finalPrice;
      _selectedDateUnit = finalUnit;
      _loadingDatePrice = false;
    });
  }

  // priceDay(실제 시세 날짜)가 오늘과 다르면 표기
  String _dataDateNote() {
    final it = widget.item;
    if (it == null || it.priceDay == null) return '';
    final today = _todayString();
    if (it.priceDay != today) return ' · ${it.priceDay} 기준';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Empty-state when no item is selected/registered
    if (widget.item == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7EF),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SectionIcon(),
                SizedBox(width: 10),
                Expanded(
                  child: _SectionTitle(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3E6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: Text('🧺', style: TextStyle(fontSize: 34))),
                  ),
                  const SizedBox(height: 12),
                  const Text('등록된 품목이 없어요',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E4B33))),
                  const SizedBox(height: 6),
                  const Text(
                    '품목을 등록하고 오늘 가격과 수익 비교를 확인하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.35, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ItemAddScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('지금 품목 등록'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2FA24A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7EF),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F1E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_mall_directory, color: Color(0xFF91B48E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('판매 수익 비교', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('날짜별 예상 수익 참고 자료', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 14),

          // Inner white card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '선택 날짜: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2,'0')}-${_selectedDate.day.toString().padLeft(2,'0')}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                              IconButton(onPressed: _pickDateAndLoad, icon: const Icon(Icons.calendar_month)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _PriceColumn(
                            title: '가격 (${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2,'0')}-${_selectedDate.day.toString().padLeft(2,'0')})',
                            price: _loadingDatePrice
                                ? '조회중...'
                                : (_selectedDatePrice != null
                                    ? _formatWon(_selectedDatePrice!) + (_selectedDateUnit == '1kg기준' ? ' / 1kg기준' : '')
                                    : _formatWon(widget.item!.currentPrice)),
                            sub: '총 ${_formatWon(_computeTotalFromItem(widget.item!))}${_dataDateNote()}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 사용자 요청: 아래에는 등급만 표시 (지역/단위 제거)
                    Text(widget.item!.grade, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                  ],
                ),

                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
          child: _PriceColumn(
          title: '오늘 가격 (${_todayString()})',
          price: widget.item != null
            ? (() {
                // 가능하면 1kg 단가로 표시
                final unit = widget.item!.unit;
                final m = RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false).firstMatch(unit);
                if (m != null) {
                  final double? qty = double.tryParse(m.group(1)!);
                  if (qty != null && qty > 0) {
                    final perKg = (widget.item!.currentPrice / qty).round();
                    return _formatWon(perKg) + ' / 1kg기준';
                  }
                }
                return _formatWon(widget.item!.currentPrice);
              })()
            : '데이터 없음',
          sub: widget.item != null
            ? '총 ${_formatWon(_computeTotalFromItem(widget.item!))}${_dataDateNote()}'
            : null,
        ),
                            ),
                            const SizedBox(width: 8),
              if (widget.onRefresh != null)
                IconButton(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  icon: widget.refreshing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  tooltip: '가격 새로고침',
                ),
              if (widget.onRefresh == null) const SizedBox.shrink(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PriceColumn(
                          title: widget.item!.bestAfterDays <= 0
                              ? '오늘 예상'
                              : '${widget.item!.bestAfterDays}일후 예상',
                          price: _formatWon(_forecast(widget.item)),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info, size: 18, color: Color(0xFF7AA36E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '작년 이 시기에는 평균 가격이 15% 상승했습니다',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SectionIcon extends StatelessWidget {
  const _SectionIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFE7F1E2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store_mall_directory, color: Color(0xFF91B48E)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('판매 수익 비교', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        SizedBox(height: 2),
        Text('날짜별 예상 수익 참고 자료', style: TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.title, required this.price, this.sub, this.highlight = false});
  final String title;
  final String price;
  final String? sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFF2FA24A) : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        const SizedBox(height: 6),
        Text(
          price,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ],
    );
  }
}

// helper removed: short-grade helper and FreshBadge were unused

int _forecast(RegisteredItem? item) {
  if (item == null) return 300600;
  final base = item.currentPrice;
  final bump = item.bestAfterDays >= 2 ? 0.2 : (item.bestAfterDays == 1 ? 0.1 : 0.0);
  return (base * (1 + bump)).round();
}

String _formatWon(int value) {
  final s = value.toString();
  final buf = StringBuffer('₩');
  for (int i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final posFromEnd = s.length - i - 1;
    if (posFromEnd % 3 == 0 && posFromEnd != 0) buf.write(',');
  }
  return buf.toString();
}
