import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../utils/currency_formatter.dart';
import '../services/settings_service.dart';

class EditSavedReceiptPage extends StatefulWidget {
  final Receipt initialReceipt;

  const EditSavedReceiptPage({super.key, required this.initialReceipt});

  @override
  State<EditSavedReceiptPage> createState() => _EditSavedReceiptPageState();
}

class _EditSavedReceiptPageState extends State<EditSavedReceiptPage> {
  late Map<Product, int> _editableOrderItems;
  double _currentTotalAmount = 0.0;
  bool _isSaving = false;
  List<Product> _allAvailableProducts = [];
  bool _isLoadingProducts = true;
  late Map<Product, int> _originalItemsSnapshot;

  PaymentMethod _originalPaymentMethod = PaymentMethod.cash;
  double? _originalAmountPaid;
  double? _originalChangeGiven;

  late PaymentMethod _selectedPaymentMethod;
  TextEditingController _amountPaidController = TextEditingController();
  double _changeDue = 0.0;
  bool _showCashError = false;
  bool _paymentDetailsChanged =
      false;

  bool _isEmoneyPaymentActive = true;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _editableOrderItems = Map.fromEntries(
      widget.initialReceipt.items.entries.map(
        (e) => MapEntry(e.key.copyWith(), e.value),
      ),
    );
    _originalItemsSnapshot = Map.from(widget.initialReceipt.items);
    _recalculateTotal();
    _originalPaymentMethod = widget.initialReceipt.paymentMethod;
    _originalAmountPaid = widget.initialReceipt.amountPaid;
    _originalChangeGiven = widget.initialReceipt.changeGiven;
    _loadAvailableProducts();
    _selectedPaymentMethod = widget.initialReceipt.paymentMethod;
    if (widget.initialReceipt.amountPaid != null) {
      _amountPaidController.text = widget.initialReceipt.amountPaid!
          .toStringAsFixed(0);
    }
    _loadAvailableProducts();
  }

  Future<void> _loadPageSettings() async {
    setState(() => _isLoadingSettings = true);
    final settings = await CompanySettings.load();
    if (mounted) {
      setState(() {
        _isEmoneyPaymentActive = settings.isEmoneyActive;
        _isLoadingSettings = false;
      });
    }
  }

  void _recalculateTotalAndChange() {
    double total = 0.0;
    _editableOrderItems.forEach((product, quantity) {
      total += product.price * quantity;
    });

    double paidAmount = double.tryParse(_amountPaidController.text) ?? 0.0;
    double change = 0.0;
    bool showError = false;

    if (_selectedPaymentMethod == PaymentMethod.cash) {
      if (paidAmount >= total) {
        change = paidAmount - total;
      } else {
        showError = _amountPaidController.text.isNotEmpty;
      }
    }

    setState(() {
      _currentTotalAmount = total;
      _changeDue = change;
      _showCashError = showError;
    });
  }

  Future<void> _loadAvailableProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      _allAvailableProducts = await DatabaseHelper.instance.getAllProducts();
    } catch (e) {
      print("Error loading products: $e");
    }
    setState(() => _isLoadingProducts = false);
  }

  void _recalculateTotal() {
    double total = 0.0;
    _editableOrderItems.forEach((product, quantity) {
      total += product.price * quantity;
    });
    setState(() {
      _currentTotalAmount = total;
    });
  }

  void _addItemToEditableOrder(Product product) {
    setState(() {
      _editableOrderItems.update(
        product,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      _recalculateTotalAndChange();
    });
  }

  void _removeItemFromEditableOrder(Product product) {
    setState(() {
      if (_editableOrderItems.containsKey(product)) {
        if (_editableOrderItems[product]! > 1) {
          _editableOrderItems[product] = _editableOrderItems[product]! - 1;
        } else {
          _editableOrderItems.remove(product);
        }
        _recalculateTotalAndChange();
      }
    });
  }

  Future<void> _showProductSelectionDialog() async {
    if (_isLoadingProducts) return;

    Product? selectedProduct = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Add Products",
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                _allAvailableProducts.isEmpty
                    ? const Text("No products available to add.")
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allAvailableProducts.length,
                      itemBuilder: (ctx, index) {
                        final product = _allAvailableProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(idrFormatter.format(product.price)),
                          onTap: () => Navigator.of(ctx).pop(product),
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );

    if (selectedProduct != null) {
      _addItemToEditableOrder(selectedProduct);
    }
  }

  bool _isPaymentInputValid() {
    if (_selectedPaymentMethod == PaymentMethod.cash) {
      final paid = double.tryParse(_amountPaidController.text) ?? 0.0;
      return paid >= _currentTotalAmount;
    }
    return true;
  }

  Future<void> _confirmAndSaveChanges() async {
    if (_editableOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot save an empty receipt."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isPaymentInputValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment amount is insufficient for cash payment.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirm Changes to Receipt?'),
            content: const Text(
              'This will permanently alter the saved receipt and adjust product stock levels accordingly.\n\nProceed with caution!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm & Save'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    double? finalAmountPaid;
    double? finalChangeGiven;

    if (_selectedPaymentMethod == PaymentMethod.cash) {
      finalAmountPaid =
          double.tryParse(_amountPaidController.text) ?? _currentTotalAmount;
      finalChangeGiven = _changeDue;
    } else {
      finalAmountPaid = _currentTotalAmount;
      finalChangeGiven = 0.0;
    }

    final Receipt fullyEditedReceipt = Receipt(
      id: widget.initialReceipt.id,
      items: _editableOrderItems,
      totalAmount: _currentTotalAmount,
      paymentMethod: _selectedPaymentMethod,
      amountPaid: finalAmountPaid,
      changeGiven: finalChangeGiven,
      timestamp: widget.initialReceipt.timestamp,
    );

    try {
      await DatabaseHelper.instance.updateSavedReceipt(
        fullyEditedReceipt,
        _originalItemsSnapshot,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt and stock updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("Error updating saved receipt: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Receipt: ${widget.initialReceipt.id.substring(0, 8)}...',
        ),
        actions: [
          IconButton(
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : const Icon(Icons.save),
            onPressed: _isSaving ? null : _confirmAndSaveChanges,
            tooltip: 'Save Changes to Receipt',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              color: Colors.yellow[100],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Original Payment:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text("Method: ${_originalPaymentMethod.name}"),
                    if (_originalAmountPaid != null)
                      Text("Paid: ${idrFormatter.format(_originalAmountPaid)}"),
                    if (_originalChangeGiven != null)
                      Text(
                        "Change: ${idrFormatter.format(_originalChangeGiven)}",
                      ),
                    const Text(
                      "-------------------------------------------------------------------------------------------------------",
                      style: TextStyle(fontSize: 10, color: Color.fromARGB(255, 253, 247, 190) ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Current Order",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Total : ${idrFormatter.format(_currentTotalAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child:
                _editableOrderItems.isEmpty
                    ? Center(
                      child: Text(
                        "Tap products to add",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _editableOrderItems.length,
                      itemBuilder: (context, index) {
                        final product = _editableOrderItems.keys.elementAt(
                          index,
                        );
                        final quantity = _editableOrderItems[product]!;
                        return ListTile(
                          leading:
                              product.imageUrl != null &&
                                      product.imageUrl!.isNotEmpty
                                  ? Image.file(
                                    File(product.imageUrl!),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                  : const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 40,
                                  ),
                          title: Text('${product.name} (x$quantity)'),
                          subtitle: Text(idrFormatter.format(product.price)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                idrFormatter.format(product.price * quantity),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed:
                                    () => _removeItemFromEditableOrder(product),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed:
                                    () => _addItemToEditableOrder(product),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Re-enter Payment Details (if changed):",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentMethod>(
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedPaymentMethod,
                    items:
                        PaymentMethod.values
                            .where(
                              (pm) =>
                                  pm != PaymentMethod.other &&
                                  (_isEmoneyPaymentActive ||
                                      pm != PaymentMethod.eMoney),
                            )
                            .map((PaymentMethod method) {
                              return DropdownMenuItem<PaymentMethod>(
                                value: method,
                                child: Text(
                                  method.name,
                                ),
                              );
                            })
                            .toList(),
                    onChanged: (PaymentMethod? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPaymentMethod = newValue;
                          _paymentDetailsChanged = true;
                          if (newValue != PaymentMethod.cash) {
                            _amountPaidController.text = _currentTotalAmount
                                .toStringAsFixed(0);
                          }
                          _recalculateTotalAndChange();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPaymentMethod == PaymentMethod.cash)
                    TextFormField(
                      controller: _amountPaidController,
                      decoration: InputDecoration(
                        labelText: 'Amount Paid (Cash)',
                        prefixText: 'Rp ',
                        border: const OutlineInputBorder(),
                        errorText:
                            _showCashError
                                ? 'Amount must be at least ${idrFormatter.format(_currentTotalAmount)}'
                                : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        _paymentDetailsChanged = true;
                        _recalculateTotalAndChange();
                      },
                    ),
                  const SizedBox(height: 8),
                  if (_selectedPaymentMethod == PaymentMethod.cash)
                    Text(
                      'Change Due: ${idrFormatter.format(_changeDue)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    "Warning: Changing payment details here will overwrite the original payment record for this receipt.",
                    style: TextStyle(fontSize: 11, color: Colors.red[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showProductSelectionDialog,
        tooltip: 'Add Item to Receipt',
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
