import 'package:flutter_application_1/services/kamis_daily_price_service.dart';

Future<void> main() async {
  print('KAMIS manual test start');
  print('Configured: ${KamisDailyPriceService.configured}  MaskedKey: ${KamisDailyPriceService.maskedKey()}');

  final svc = KamisDailyPriceService();
  const region = '서울 가락시장';
  final items = ['배추', '토마토', '바나나'];

  for (final name in items) {
    final r = await svc.fetchTodayPrice(itemName: name, regionName: region);
    if (r == null) {
      print('[FAIL] $name -> null');
    } else {
      print('[OK] $name price=${r.price} unit=${r.unit} rank=${r.rank} cls=${r.productClassCode}');
    }
  }
  print('KAMIS manual test end');
}
