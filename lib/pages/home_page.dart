import 'package:cashier_app/pages/order_summary_page.dart';
import 'package:cashier_app/pages/past_receipts_page.dart';
import 'package:cashier_app/pages/product_management_page.dart';
import 'package:flutter/material.dart';
import 'package:cashier_app/models/product.dart';
import '../services/database_helper.dart';
import 'dart:io';
import 'reports_page.dart';
import 'settings_page.dart';
import '../main.dart';
import '../models/user_role.dart';
import '../utils/currency_formatter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  List<Product> _allProducts = [];
  List<String> _categories = ['All'];
  bool _isLoadingProducts = true;

  final Map<Product, int> _currentOrder = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool resetCategory = false, bool forceReloadCategories = false}) async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      final categories = <String>{'All'};
      for (var product in products) {
        categories.add(product.category);
      }
      setState(() {
        _allProducts = products;
        _categories = categories.toList()..sort((a, b) => a == 'All' ? -1 : (b == 'All' ? 1 : a.compareTo(b)));
        if (resetCategory || !_categories.contains(_selectedCategory)) {
           _selectedCategory = 'All';
        }
        _isLoadingProducts = false;
      });
    } catch (e) {
       print("Error loading products: $e");
       setState(() => _isLoadingProducts = false);
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Error loading products from database.'), backgroundColor: Colors.red)
        );
    }
  }

  List<Product> get _filteredProducts {
    List<Product> products = _allProducts;

    if (_selectedCategory != 'All') {
      products =
          products
              .where((product) => product.category == _selectedCategory)
              .toList();
    }

    if (_searchQuery.isNotEmpty) {
      products =
          products
              .where(
                (product) => product.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }

    return products;
  }

  void _addProduct(Product product) {
    setState(() {
      _currentOrder.update(
        product,
        (existingQuantity) => existingQuantity + 1,
        ifAbsent: () => 1,
      );
    });
  }

  void _removeProduct(Product product) {
    setState(() {
      if (_currentOrder.containsKey(product)) {
        if (_currentOrder[product]! > 1) {
          _currentOrder[product] = _currentOrder[product]! - 1;
        } else {
          _currentOrder.remove(product);
        }
      }
    });
  }

  void _clearOrder() {
    setState(() {
      _currentOrder.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  double get _totalPrice {
    double total = 0.0;
    _currentOrder.forEach((product, quantity) {
      total += product.price * quantity;
    });
    return total;
  }

  void _goToOrderPage() {
    if (_currentOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot proceed with an empty order.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderSummaryPage(order: _currentOrder),
      ),
    ).then((_) {
    });
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(BuildContext context) {
    List<PopupMenuEntry<String>> items = [];

    items.add(
      const PopupMenuItem<String>(
        value: 'view_receipts',
        child: ListTile(leading: Icon(Icons.history), title: Text('View Past Receipts')),
      ),
    );

    if (currentUserRole == UserRole.admin) {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem<String>(
          value: 'manage_products',
          child: ListTile(leading: Icon(Icons.inventory_2_outlined), title: Text('Manage Products')),
        ),
      );
      items.add(
        const PopupMenuItem<String>(
          value: 'reports',
          child: ListTile(leading: Icon(Icons.bar_chart_outlined), title: Text('View Reports')),
        ),
      );
      items.add(
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings')),
        ),
      );
      items.add(const PopupMenuDivider());
      items.add(
         PopupMenuItem<String>(
           value: 'switch_role_to_cashier',
           child: const ListTile(leading: Icon(Icons.switch_account), title: Text('Switch to Cashier Role')),
         ),
      );
    } else {
        items.add(const PopupMenuDivider());
         items.add(
           PopupMenuItem<String>(
             value: 'switch_role_to_admin',
             child: const ListTile(leading: Icon(Icons.switch_account), title: Text('Switch to Admin Role')),
           ),
        );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Row(
          children: [
            const Text('Cashier App'),
            const Spacer(),
            Text(
              'Role: ${currentUserRole.name.toUpperCase()}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String result) async {
              switch (result) {
                case 'view_receipts':
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PastReceiptsPage()));
                  break;

                case 'manage_products':
                  if (currentUserRole == UserRole.admin) {
                    final dataChanged = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const ProductManagementPage()));
                    if (dataChanged == true && mounted) _loadData(resetCategory: true);
                  }
                  break;
                case 'reports':
                  if (currentUserRole == UserRole.admin) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage()));
                  }
                  break;
                case 'settings':
                if (currentUserRole == UserRole.admin) {
                    final bool? settingsChangedAnythingRelevant = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                    if (settingsChangedAnythingRelevant == true && mounted) {
                        print("Settings changed, potentially reloading data in HomePage");
                        _loadData(resetCategory: true, forceReloadCategories: true);
                    }
                  }
                  break;
                case 'switch_role_to_cashier':
                   setState(() { currentUserRole = UserRole.cashier; });
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched to Cashier Role')));
                   break;
                case 'switch_role_to_admin':
                   setState(() { currentUserRole = UserRole.admin; });
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched to Admin Role')));
                   break;
              }
            },
            itemBuilder: (BuildContext context) => _buildPopupMenuItems(context),
          ),
        ],
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : _allProducts.isEmpty
             ? Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Text("No products available.", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                         icon: const Icon(Icons.add_box_outlined),
                         label: const Text('Add Products'),
                         onPressed: () async {
                            final dataChanged = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (context) => const ProductManagementPage()),
                            );
                            if (dataChanged == true && mounted) {
                              _loadData(resetCategory: true);
                            }
                          },
                       )
                   ],
                 )
              )
             : Column(
                  children: [
                    _buildCategorySelector(),
                    Expanded(child: _buildProductGrid()),
                    _buildCurrentOrderSummary(),
                    _buildActionButtons(),
                  ],
                ),
    );
  }   

  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
              backgroundColor: Colors.white,
              shape: StadiumBorder(side: BorderSide(color: Colors.grey[400]!)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    final productsToShow = _filteredProducts;

    if (productsToShow.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No products match "$_searchQuery"'
              : 'No products available in this category',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: productsToShow.length,
      itemBuilder: (context, index) {
        final product = productsToShow[index];
        return Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _addProduct(product),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                      ? Image.file(
                          File(product.imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[600]),
                        ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          idrFormatter.format(product.price),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentOrderSummary() {
    if (_currentOrder.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: Text(
          'Tap products to add them to the order',
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 150,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Total: ${idrFormatter.format(_totalPrice)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentOrder.length,
              itemBuilder: (context, index) {
                final product = _currentOrder.keys.elementAt(index);
                final quantity = _currentOrder[product]!;
                return ListTile(
                  dense: true,
                  title: Text('${product.name} (x$quantity)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        idrFormatter.format(product.price * quantity)
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _removeProduct(product),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              label: const Text(
                'Clear',
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed:
                  _currentOrder.isEmpty
                      ? null
                      : _clearOrder,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _currentOrder.isEmpty ? Colors.grey : Colors.redAccent,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Order'),
              onPressed:
                  _currentOrder.isEmpty
                      ? null
                      : _goToOrderPage,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
