import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/ui/home/home_screen.dart';
// auth service removed from start gate - signup flow disabled

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '홈',
      theme: AppTheme.light,
      home: const _StartGate(),
    );
  }
}

class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> {
  @override
  Widget build(BuildContext context) {
    // Always show home screen on app start (signup flow removed per request)
    return const HomeScreen();
  }
}
