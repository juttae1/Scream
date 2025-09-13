import 'package:flutter_application_1/services/kamis_daily_price_service.dart';

/// 수동 실행: flutter run -d windows -t lib/dev/kamis_category_200_manual_test.dart --dart-define=KAMIS_CERT_KEY=... --dart-define=KAMIS_CERT_ID=...
/// 채소류(200) 주요 품목 price 매칭 확인.
void main() async {
  final svc = KamisDailyPriceService();
  final items = [
    '배추','양배추','시금치','상추','얼갈이배추','오이','호박','토마토','방울토마토','무','당근','열무','건고추','풋고추','붉은고추','피마늘','깐마늘(국산)','양파','파','생강','미나리','깻잎','피망','파프리카'
  ];
  for (final name in items) {
    final r = await svc.fetchTodayPrice(itemName: name, regionName: '서울 가락시장');
    // ignore: avoid_print
    print('[TEST] $name => price=${r?.price} unit=${r?.unit} rank=${r?.rank} day=${r?.day} matchedItem=${r?.itemName} cls=${r?.productClassCode}');
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
