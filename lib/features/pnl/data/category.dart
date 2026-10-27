enum CategoryType { income, expense }

CategoryType _typeFromString(String s) =>
    s == 'income' ? CategoryType.income : CategoryType.expense;

/// An income/expense category. Seeded per-user on signup (Sales, Rent,
/// ...); this app only reads them — there's no category-management screen
/// yet, so creating custom categories isn't supported.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
  });

  final String id;
  final String name;
  final CategoryType type;
  final bool isDefault;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    type: _typeFromString(json['type'] as String),
    isDefault: json['is_default'] as bool,
  );
}
