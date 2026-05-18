// lib/shared/models/offer_model.dart
// W1 new model: replaces ProductBundle. Plain Dart per Q11 lock.
// Fields match backend src/offers/entities/offer.entity.ts exactly.

import 'offer_category_model.dart';

class Offer {
  final String id;
  final String name;
  // USSD template with BH placeholder for customer phone, optional AMT for amount.
  final String ussdTemplate;
  // KES whole shillings (matches backend int).
  final int price;
  // Free-text validity label like "3 Hrs", "7 Days".
  final String validityLabel;
  final String categoryId;
  final OfferCategory? category;
  final bool isActive;
  final String agentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Offer({
    required this.id,
    required this.name,
    required this.ussdTemplate,
    required this.price,
    required this.validityLabel,
    required this.categoryId,
    this.category,
    required this.isActive,
    required this.agentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'] as String,
      name: json['name'] as String,
      ussdTemplate: json['ussdTemplate'] as String,
      price: (json['price'] as num).toInt(),
      validityLabel: json['validityLabel'] as String,
      categoryId: json['categoryId'] as String,
      category: json['category'] != null
          ? OfferCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      agentId: json['agentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ussdTemplate': ussdTemplate,
        'price': price,
        'validityLabel': validityLabel,
        'categoryId': categoryId,
        'isActive': isActive,
        'agentId': agentId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Offer copyWith({
    String? id,
    String? name,
    String? ussdTemplate,
    int? price,
    String? validityLabel,
    String? categoryId,
    OfferCategory? category,
    bool? isActive,
    String? agentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Offer(
      id: id ?? this.id,
      name: name ?? this.name,
      ussdTemplate: ussdTemplate ?? this.ussdTemplate,
      price: price ?? this.price,
      validityLabel: validityLabel ?? this.validityLabel,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      agentId: agentId ?? this.agentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}