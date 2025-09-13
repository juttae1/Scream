import 'package:flutter/material.dart';

class HelperHeader extends StatelessWidget {
  const HelperHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF67BE74);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFE7F6E7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF5AAE67), size: 24),
        ),
        const SizedBox(height: 10),
  Text(
          '수익 정보 도우미',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: green,
                fontSize: 26,
              ),
        ),
        const SizedBox(height: 6),
  Text(
          '농산물 판매 참고 정보를 확인해보세요',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.35,
                color: const Color(0xFF8BC28C),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
