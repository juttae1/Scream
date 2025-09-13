import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/common/custom_bottom_nav.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAEE),
      body: const SafeArea(
        child: Center(
          child: Text('기록 화면 (준비중)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        onTap: (idx) {
          if (idx == 0) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
