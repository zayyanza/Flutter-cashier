import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/database_helper.dart';
import '../services/settings_service.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;
  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _buyingPriceController;
  XFile? _pickedImageFile;
  String? _currentImagePath;
  bool _imageRemoved = false;
  final ImagePicker _picker = ImagePicker();
  String? _selectedCategory;
  List<String> _availableCategories = [];
  bool _isLoadingCategories = true;
  final String _addNewCategoryOption = "+ Add New Category";
  bool _isBuyingPriceActuallyRequired = false;
  bool _isLoadingSettingsForDialog = true;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toStringAsFixed(2) ?? '');
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _buyingPriceController = TextEditingController(text: widget.product?.buyingPrice?.toStringAsFixed(2) ?? '');
    _currentImagePath = product?.imageUrl;
    _selectedCategory = product?.category;
    _loadAvailableCategories();
    _loadDialogSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _buyingPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadDialogSettings() async {
    setState(() => _isLoadingSettingsForDialog = true);
    final settings = await CompanySettings.load();
    setState(() {
      _isBuyingPriceActuallyRequired = settings.isBuyingPriceRequired;
      _isLoadingSettingsForDialog = false;
    });
  }

  Future<void> _loadAvailableCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await DatabaseHelper.instance.getAllProductCategories();
      setState(() {
        _availableCategories = categories;
        if (widget.product != null &&
            widget.product!.category.isNotEmpty &&
            !_availableCategories.contains(widget.product!.category)) {
          _availableCategories.add(widget.product!.category);
          _availableCategories.sort();
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      print("Error loading categories for dropdown: $e");
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _showAddNewCategoryDialogForProduct() async {
    final TextEditingController newCatController = TextEditingController();
    final newCatFormKey = GlobalKey<FormState>();
    final String? createdCategoryName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Category'),
        content: Form(
          key: newCatFormKey,
          child: TextFormField(
            controller: newCatController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Cannot be empty.';
              if (_availableCategories.map((c) => c.toLowerCase()).contains(value.trim().toLowerCase())) {
                return 'Category already exists.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newCatFormKey.currentState!.validate()) {
                Navigator.pop(dialogContext, newCatController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (createdCategoryName != null && createdCategoryName.isNotEmpty) {
      setState(() {
        if (!_availableCategories.contains(createdCategoryName)) {
          _availableCategories.add(createdCategoryName);
          _availableCategories.sort();
        }
        _selectedCategory = createdCategoryName;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (selectedImage != null) {
        setState(() {
          _pickedImageFile = selectedImage;
          _currentImagePath = null;
          _imageRemoved = false;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _saveImageLocally(XFile imageFile) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = p.basename(imageFile.path);
      final String localFilePath = p.join(appDocDir.path, 'product_images', fileName);
      final Directory imageDir = Directory(p.join(appDocDir.path, 'product_images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final File localImage = File(localFilePath);
      await localImage.writeAsBytes(await imageFile.readAsBytes());
      return localFilePath;
    } catch (e) {
      print("Error saving image locally: $e");
      return null;
    }
  }

  Future<void> _deleteOldImage(String? oldImagePath) async {
    if (oldImagePath != null && oldImagePath.isNotEmpty) {
      try {
        final File oldFile = File(oldImagePath);
        if (await oldFile.exists()) {
          await oldFile.delete();
          print("Deleted old image: $oldImagePath");
        }
      } catch (e) {
        print("Error deleting old image $oldImagePath: $e");
      }
    }
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or add a category.'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }
      String? finalImagePath = _currentImagePath;
      if (_imageRemoved) {
        await _deleteOldImage(widget.product?.imageUrl);
        finalImagePath = null;
      } else if (_pickedImageFile != null) {
        await _deleteOldImage(widget.product?.imageUrl);
        finalImagePath = await _saveImageLocally(_pickedImageFile!);
        if (finalImagePath == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save image.'), backgroundColor: Colors.red),
          );
          return;
        }
      }
      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text);
      final stock = int.tryParse(_stockController.text);
      final buyingPriceString = _buyingPriceController.text.trim();
      final buyingPrice = buyingPriceString.isEmpty ? null : double.tryParse(buyingPriceString);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid price format.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (stock == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid price format.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (buyingPriceString.isNotEmpty && buyingPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid buying price format.'), backgroundColor: Colors.red),
        );
        return;
      }
      final newProduct = Product(
        id: widget.product?.id ?? 0,
        name: name,
        category: _selectedCategory!,
        price: price,
        stock: stock,
        buyingPrice: buyingPrice,
        imageUrl: finalImagePath,
      );
      Navigator.of(context).pop(newProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    Widget imagePreviewWidget;
    if (_pickedImageFile != null) {
      imagePreviewWidget = Image.file(File(_pickedImageFile!.path), fit: BoxFit.cover, height: 100, width: 100);
    } else if (_currentImagePath != null && !_imageRemoved) {
      imagePreviewWidget = Image.file(File(_currentImagePath!), fit: BoxFit.cover, height: 100, width: 100);
    } else {
      imagePreviewWidget = Container(
        height: 100,
        width: 100,
        color: Colors.grey[300],
        child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 40),
      );
    }
    if (_isLoadingSettingsForDialog) {
      return const AlertDialog(
        title: Text("Loading..."),
        content: Center(child: CircularProgressIndicator()),
      );
    }
    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Text("Product Image", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: imagePreviewWidget,
                  ),
                  if ((_pickedImageFile != null || (_currentImagePath != null && !_currentImagePath!.isEmpty)) && !_imageRemoved)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.white70,
                          radius: 12,
                          child: Icon(Icons.close, size: 16, color: Colors.red),
                        ),
                        tooltip: 'Remove Image',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _pickedImageFile = null;
                            _imageRemoved = true;
                          });
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
              const Divider(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              if (_isLoadingCategories)
                const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  value: _selectedCategory,
                  hint: const Text('Select Category'),
                  isExpanded: true,
                  items: [
                    ..._availableCategories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }),
                    DropdownMenuItem<String>(
                      value: _addNewCategoryOption,
                      child: Text(_addNewCategoryOption, style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).primaryColor)),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue == _addNewCategoryOption) {
                      _showAddNewCategoryDialogForProduct();
                    } else {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                  validator: (value) => (value == null || value == _addNewCategoryOption || value.isEmpty)
                      ? 'Please select a category'
                      : null,
                ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price', prefixText: 'Rp'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid positive price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Invalid non-negative integer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _buyingPriceController,
                decoration: InputDecoration(
                  labelText: 'Buying Price ${_isBuyingPriceActuallyRequired ? "(Required)" : "(Optional)"}',
                  prefixText: 'Rp',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (_isBuyingPriceActuallyRequired) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Buying price is required.';
                    }
                  }
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value) == null || double.parse(value) < 0) {
                      return 'Invalid non-negative price.';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: _saveForm,
        ),
      ],
    );
  }
}
