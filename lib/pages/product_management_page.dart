import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../widgets/add_edit_product_dialog.dart';
import 'dart:io';
import '../main.dart';
import '../models/user_role.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  late Future<List<Product>> _productsFuture;
  bool _dataChanged = false;
  final priceFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = DatabaseHelper.instance.getAllProducts();
    });
  }

  Future<void> _addProduct() async {
    final result = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return const AddEditProductDialog();
      },
    );

    if (result != null && mounted) {
      try {
        await DatabaseHelper.instance.insertProduct(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.name} added successfully!'), backgroundColor: Colors.green),
        );
        _dataChanged = true;
        _loadProducts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editProduct(Product productToEdit) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return AddEditProductDialog(product: productToEdit);
      },
    );

    if (result != null && mounted) {
      try {
        int updatedRows = await DatabaseHelper.instance.updateProduct(result);
        if (updatedRows > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result.name} updated!'), backgroundColor: Colors.green),
          );
          _dataChanged = true;
          _loadProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found or no changes made.'), backgroundColor: Colors.orangeAccent),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewProduct(Product product) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(product.name),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Center(child: Image.file(File(product.imageUrl!), height: 100, fit: BoxFit.contain)),
                  ),
                _buildDetailRow('ID:', product.id.toString()),
                _buildDetailRow('Category:', product.category),
                _buildDetailRow('Selling Price:', priceFormat.format(product.price)),
                _buildDetailRow('Stock:', product.stock.toString()),
                _buildDetailRow('Buying Price:', product.buyingPrice != null ? priceFormat.format(product.buyingPrice!) : 'N/A'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      try {
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          try {
            final File imageFile = File(product.imageUrl!);
            if (await imageFile.exists()) {
              await imageFile.delete();
              print("Deleted image file: ${product.imageUrl}");
            }
          } catch (e) {
            print("Error deleting image file for product ${product.id}: $e");
          }
        }
        int deletedRows = await DatabaseHelper.instance.deleteProduct(product.id);
        if (deletedRows > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} deleted successfully!'), backgroundColor: Colors.orange),
          );
          _dataChanged = true;
          _loadProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found.'), backgroundColor: Colors.grey),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Products'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataChanged),
          ),
        ),
        body: FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No products found. Add some!'));
            } else {
              final products = snapshot.data!;
              final categories = <String>{};
              for (var p in products) {
                categories.add(p.category);
              }
              final sortedCategories = categories.toList()..sort();

              return ListView.builder(
                itemCount: sortedCategories.length,
                itemBuilder: (context, index) {
                  final category = sortedCategories[index];
                  final categoryProducts = products.where((p) => p.category == category).toList();
                  return ExpansionTile(
                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    initiallyExpanded: true,
                    children: categoryProducts.map((product) {
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                            'Sell: ${idrFormatter.format(product.price)} | Stock: ${product.stock}'),
                        leading: SizedBox(
                          width: 50,
                          height: 50,
                          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Image.file(
                                    File(product.imageUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Icon(Icons.inventory_2_outlined, color: Colors.grey[500]),
                                ),
                        ),
                        trailing: currentUserRole == UserRole.admin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () => _viewProduct(product)),
                                  IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.orange), onPressed: () => _editProduct(product)),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteProduct(product)),
                                ],
                              )
                            : IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () => _viewProduct(product)),
                      );
                    }).toList(),
                  );
                },
              );
            }
          },
        ),
        floatingActionButton: currentUserRole == UserRole.admin
            ? FloatingActionButton(
                onPressed: _addProduct,
                tooltip: 'Add Product',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}
