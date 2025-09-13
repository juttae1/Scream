import 'package:flutter/material.dart';
// Note: item add screen is not referenced on this redesigned home screen
// auth imports not needed on this screen for the current mock
// note: other home sections removed to match new mock layout
import 'package:flutter_application_1/ui/home/price_screen.dart';
import 'package:flutter_application_1/ui/home/weather_screen.dart';
import 'package:flutter_application_1/ui/home/forecast_screen.dart';
// Item list section intentionally omitted to match the provided mock exactly.
// removed old model/service imports which are not used by redesigned home
// market api 의존성 제거됨
// import 'package:flutter/foundation.dart' show debugPrint;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Old item bookkeeping removed for new home layout
  // services not used on redesigned home screen
  // API 체크 상태 제거

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // full-screen gradient background similar to mock
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFFAF5), Color(0xFFF4FBFF)],
          ),
        ),
        child: Column(
          children: [
            // Header with green gradient that fills status bar area
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF19C37E), Color(0xFF00C853)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
              ),
                child: SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  // move title slightly down (more top padding)
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('언제Farm', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
                            SizedBox(height: 6),
                            Text('농산물 판매 최적화 앱', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      ),
                      // 오른쪽 상단 로고 추가
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: AssetImage('assets/images/logo_farm.png'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: Offset(0, 4))],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // main content area with spaced cards
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionCard(
                      gradient: const LinearGradient(colors: [Color(0xFFFB6B86), Color(0xFFF64FA8)]),
                      icon: Icons.attach_money,
                      label: '오늘의 가격 보러가기',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceScreen())),
                    ),
                    const SizedBox(height: 22),
                      _ActionCard(
                        gradient: const LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF2D9CFF)]),
                        icon: Icons.warning_amber_rounded,
                        label: '오늘의 특보 보러가기',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen())),
                      ),
                    const SizedBox(height: 22),
                    _ActionCard(
                      gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF19C37E)]),
                      icon: Icons.show_chart,
                      label: '판매 금액 예측 보러가기',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastScreen())),
                    ),
                  ],
                ),
              ),
            ),

            // footer text (bigger, raised a bit for visibility)
            Padding(
              padding: const EdgeInsets.only(bottom: 42),
              child: Text('농민을 위한 스마트 판매 도우미', style: TextStyle(color: const Color(0xFF2E7D32), fontSize: 20, fontWeight: FontWeight.w800)),
            )
          ],
        ),
      ),
    );
  }
}

// 회원가입/로그인 버튼 위젯 제거

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    this.gradient,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Gradient? gradient;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
