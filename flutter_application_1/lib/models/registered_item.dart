class RegisteredItem {
  final String emoji;
  final String name;
  final String grade; // 상등급/중등급/하등급
  final int quantity;
  final String unit; // 단위명 (kg/톤 등). 기존 호환 유지
  final String? packName; // 포장명 (상자 등), optional
  final String region; // 판매 지역
  final int currentPrice; // 원
  final int bestAfterDays; // n일 뒤 추천
  final String? priceDay; // KAMIS 응답 day (YYYY-MM-DD)

  const RegisteredItem({
    required this.emoji,
    required this.name,
    required this.grade,
    required this.quantity,
    required this.unit,
  this.packName,
    required this.region,
    required this.currentPrice,
    required this.bestAfterDays,
  this.priceDay,
  });

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'name': name,
        'grade': grade,
        'quantity': quantity,
        'unit': unit,
  'packName': packName,
        'region': region,
        'currentPrice': currentPrice,
        'bestAfterDays': bestAfterDays,
  if (priceDay != null) 'priceDay': priceDay,
      };

  factory RegisteredItem.fromJson(Map<String, dynamic> json) => RegisteredItem(
        emoji: json['emoji'] as String? ?? '',
        name: json['name'] as String? ?? '',
        grade: json['grade'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        unit: json['unit'] as String? ?? '상자',
  packName: json['packName'] as String?,
        region: json['region'] as String? ?? '',
        currentPrice: json['currentPrice'] as int? ?? 0,
        bestAfterDays: json['bestAfterDays'] as int? ?? 0,
  priceDay: json['priceDay'] as String?,
      );

  RegisteredItem copyWith({
    String? emoji,
    String? name,
    String? grade,
    int? quantity,
    String? unit,
    String? packName,
    String? region,
    int? currentPrice,
    int? bestAfterDays,
  String? priceDay,
  }) => RegisteredItem(
        emoji: emoji ?? this.emoji,
        name: name ?? this.name,
        grade: grade ?? this.grade,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        packName: packName ?? this.packName,
        region: region ?? this.region,
        currentPrice: currentPrice ?? this.currentPrice,
        bestAfterDays: bestAfterDays ?? this.bestAfterDays,
    priceDay: priceDay ?? this.priceDay,
      );
}
