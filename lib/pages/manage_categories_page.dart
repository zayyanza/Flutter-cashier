import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  late Future<List<String>> _categoriesFuture;
  bool _categoriesChanged = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = DatabaseHelper.instance.getAllProductCategories();
    });
  }

  Future<void> _showAddEditCategoryDialog({String? oldCategoryName}) async {
    final TextEditingController nameController = TextEditingController(text: oldCategoryName ?? '');
    final formKey = GlobalKey<FormState>();

    final String? newCategoryName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(oldCategoryName == null ? 'Add New Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Category name cannot be empty.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCategoryName != null && newCategoryName.isNotEmpty && mounted) {
      try {
        if (oldCategoryName == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "$newCategoryName" can now be used.'), backgroundColor: Colors.green),
          );
        } else {
          if (oldCategoryName != newCategoryName) {
            await DatabaseHelper.instance.updateCategoryForProducts(oldCategoryName, newCategoryName);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Category "$oldCategoryName" updated to "$newCategoryName". Products reassigned.'), backgroundColor: Colors.green),
            );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No changes made to category name.')),
            );
          }
        }
        _categoriesChanged = true;
        _loadCategories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete category "$categoryName"?\nThis cannot be undone if no products are using it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await DatabaseHelper.instance.ensureCategoryIsDeletable(categoryName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "$categoryName" is no longer in active use or was removed (if not tied to products).'), backgroundColor: Colors.orange),
        );
        _categoriesChanged = true;
        _loadCategories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _categoriesChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Categories'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _categoriesChanged),
          ),
        ),
        body: FutureBuilder<List<String>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No categories found. Add products with categories or add a category here.'));
            } else {
              final categories = snapshot.data!;
              return ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(category),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                          tooltip: 'Edit Category',
                          onPressed: () => _showAddEditCategoryDialog(oldCategoryName: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Category',
                          onPressed: () => _deleteCategory(category),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditCategoryDialog(),
          tooltip: 'Add New Category',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
