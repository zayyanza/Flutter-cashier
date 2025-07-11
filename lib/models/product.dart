// lib/models/product.dart
import 'package:cashier_app/services/database_helper.dart';

class Product {
  final int id;
  final String name;
  final String category;
  final double price;
  final String? imageUrl; 
  final int stock;
  final double? buyingPrice;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.stock = 0, 
    this.buyingPrice, 
    this.imageUrl
  });

  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

   
  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    String? imageUrl,
    int? stock,
    double? buyingPrice, 
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      buyingPrice: buyingPrice ?? this.buyingPrice,
    );
  }
}

extension ProductDbExtension on Product {
  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.colProductId: id == 0 ? null : id, // Don't include 0 ID
      DatabaseHelper.colProductName: name,
      DatabaseHelper.colProductCategory: category,
      DatabaseHelper.colProductPrice: price,
      DatabaseHelper.colProductImageUrl: imageUrl,
    };
  }
}