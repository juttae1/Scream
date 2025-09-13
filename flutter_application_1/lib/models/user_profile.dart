class UserProfile {
  final String name;
  final String phone;
  final String pin; // 4-digit simple PIN

  const UserProfile({required this.name, required this.phone, required this.pin});

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'pin': pin,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        pin: json['pin'] as String? ?? '',
      );
}
