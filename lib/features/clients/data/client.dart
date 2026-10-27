class Client {
  const Client({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.businessName,
    this.notes,
    required this.openingBalance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? businessName;
  final String? notes;
  final double openingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    businessName: json['business_name'] as String?,
    notes: json['notes'] as String?,
    openingBalance: (json['opening_balance'] as num).toDouble(),
    isActive: json['is_active'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
  );
}
