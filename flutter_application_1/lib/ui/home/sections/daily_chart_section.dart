import 'package:flutter/material.dart';

class DailyChartSection extends StatelessWidget {
  const DailyChartSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Explicit values shown in the mock
    final values = const [
      180000.0,
      194400.0,
      219600.0,
      300600.0,
      284400.0,
      259200.0,
      239400.0,
      210600.0,
    ];
    final xLabels = const ['오늘', '1일후', '2일후', '3일후', '09/13', '09/14', '09/15', '09/16'];
    final max = values.reduce((a, b) => a > b ? a : b);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _IconBadge(icon: Icons.bar_chart, bg: Color(0xFFE7F1E2), fg: Color(0xFF91B48E)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('일별 예상 수익', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('0~7일간 수익 비교 자료', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < values.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // value label above bar
                        Text(
                          _formatWon(values[i]),
                          style: const TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 26,
                            height: (values[i] / max) * 130,
                            decoration: BoxDecoration(
                              color: i == 3 ? const Color(0xFF67BE74) : const Color(0xFFBFC8C6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(xLabels[i], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 14),
          // data evidence box
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF7D8FA0)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('데이터 근거', style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text(
                        '과거 3년간의 시장 데이터와 계절별 가격 변동을 분석한 참고 자료입니다. 실제 시장 상황에 따라 결과가 다를 수 있습니다.',
                        style: TextStyle(height: 1.5, color: Colors.black87),
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

String _formatWon(double v) {
  final s = v.round().toString();
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(reg, (m) => ',') + '원';
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.bg, required this.fg});
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg),
    );
  }
}
