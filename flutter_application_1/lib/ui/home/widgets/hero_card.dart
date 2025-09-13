import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.primaryGreen});
  final Color primaryGreen;

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(DateTime.now());
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.fromLTRB(20, 42, 96, 24),
          decoration: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                '3일 뒤 판매 시',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '+ 120,000원',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 14,
          left: 6,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1F8D3F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              dateText,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 44,
          child: Semantics(
            button: true,
            label: '새 항목 추가',
            child: _PlusCircleButton(size: 92, plusColor: Colors.green.shade700),
          ),
        ),
      ],
    );
  }
}

class _PlusCircleButton extends StatelessWidget {
  const _PlusCircleButton({required this.size, required this.plusColor});
  final double size;
  final Color plusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: CustomPaint(
        painter: _ThickPlusPainter(color: plusColor),
      ),
    );
  }
}

class _ThickPlusPainter extends CustomPainter {
  _ThickPlusPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double barW = size.width * 0.12;
    final double pad = size.width * 0.24;

    final rectV = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - barW / 2, pad, barW, size.height - pad * 2),
      Radius.circular(barW / 2),
    );
    final rectH = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, size.height / 2 - barW / 2, size.width - pad * 2, barW),
      Radius.circular(barW / 2),
    );

    canvas.drawRRect(rectV, paint);
    canvas.drawRRect(rectH, paint);
  }

  @override
  bool shouldRepaint(covariant _ThickPlusPainter oldDelegate) => oldDelegate.color != color;
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}
