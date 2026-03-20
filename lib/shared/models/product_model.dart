// lib/shared/models/product_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'transaction_model.dart' show TransactionType;

part 'product_model.freezed.dart';
part 'product_model.g.dart';

// Product Bundle (matches what's used in transaction_model.dart)
@freezed
abstract class ProductBundle with _$ProductBundle {
  const factory ProductBundle({
    required String id,
    required String name,
    required TransactionType type,
    required String network,
    required String value,
    required double price,
    required String ussdCode,
    @Default('') String description,
    @Default(0) int validityDays,
    @Default(true) bool isActive,
    @Default(0) int sortOrder,
    Map<String, dynamic>? metadata,
  }) = _ProductBundle;

  factory ProductBundle.fromJson(Map<String, dynamic> json) =>
      _$ProductBundleFromJson(json);
}

// Product Category
@freezed
abstract class ProductCategory with _$ProductCategory {
  const factory ProductCategory({
    required String id,
    required String name,
    required TransactionType type,
    @Default('') String description,
    @Default(0) int sortOrder,
    @Default(true) bool isActive,
    List<ProductBundle>? products,
  }) = _ProductCategory;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      _$ProductCategoryFromJson(json);
}