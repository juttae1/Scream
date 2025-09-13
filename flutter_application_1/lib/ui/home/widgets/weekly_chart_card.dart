import 'package:flutter/material.dart';

class WeeklyChartCard extends StatelessWidget {
  const WeeklyChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = ['어제', '오늘', '내일', '09/10', '09/11', '09/12', '09/13'];
    final values = [0.35, 0.15, 0.28, 1.00, 0.86, 0.82, 0.3];
    const peakIndex = 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 판매 수익 예상',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: List.generate(
                      5,
                      (i) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green.shade100, width: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '530,000',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.black.withOpacity(0.85),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < labels.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _Bar(
                                value: values[i],
                                color:
                                    i == peakIndex ? const Color(0xFFE53935) : const Color(0xFF2FA24A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        for (final text in labels)
                          Expanded(
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
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
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value; // 0.0 ~ 1.0
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = constraints.maxHeight * value;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}
