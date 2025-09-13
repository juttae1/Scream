import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key, required this.selectedIndex, required this.onTap});
  final int selectedIndex; // 0: 홈, 1: 기록
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF67BE74);
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    return SafeArea(
      top: false,
      bottom: false, // fill to the very bottom edge
      child: SizedBox(
        height: 78,
        width: double.infinity,
        child: Stack(
          children: [
            Row(
              children: [
                // Left half
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(0),
                    child: Container(
                      color: selectedIndex == 0 ? green : Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_outlined,
                            color: selectedIndex == 0 ? Colors.white : const Color(0xFF6D7B74),
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '홈',
                            style: labelStyle.copyWith(
                              color: selectedIndex == 0 ? Colors.white : const Color(0xFF567065),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right half
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(1),
                    child: Container(
                      color: selectedIndex == 1 ? green : Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            color: selectedIndex == 1 ? Colors.white : const Color(0xFF6D7B74),
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '기록',
                            style: labelStyle.copyWith(
                              color: selectedIndex == 1 ? Colors.white : const Color(0xFF567065),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Vertical divider line
            Align(
              alignment: Alignment.center,
              child: Container(width: 1, height: 48, color: const Color(0x14333333)),
            ),
          ],
        ),
      ),
    );
  }
}
