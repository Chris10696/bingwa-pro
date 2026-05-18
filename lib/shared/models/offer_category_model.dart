// lib/shared/models/offer_category_model.dart
// W1 new model: replaces ProductCategory. Plain Dart per Q11 lock.
// Matches backend src/categories/entities/category.entity.ts.

class OfferCategory {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfferCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OfferCategory.fromJson(Map<String, dynamic> json) {
    return OfferCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}