import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../services/database_helper.dart';

class EditReceiptPage extends StatefulWidget {
  final Receipt initialReceipt;

  const EditReceiptPage({super.key, required this.initialReceipt});

  @override
  State<EditReceiptPage> createState() => _EditReceiptPageState();
}

class _EditReceiptPageState extends State<EditReceiptPage> {
  late Receipt _editedReceipt; 
  final TextEditingController _cashPaidController = TextEditingController();
  double _change = 0.0;
  bool _showCashError = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>(); // For validation

  @override
  void initState() {
    super.initState();
    _editedReceipt = widget.initialReceipt;
    _change = _editedReceipt.changeGiven ?? 0.0;
    if (_editedReceipt.paymentMethod == PaymentMethod.cash && _editedReceipt.amountPaid != null) {
      _cashPaidController.text = _editedReceipt.amountPaid!.toStringAsFixed(2);
    }
    _cashPaidController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashPaidController.removeListener(_calculateChange);
    _cashPaidController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    if (_editedReceipt.paymentMethod == PaymentMethod.cash) {
      final paidAmount = double.tryParse(_cashPaidController.text) ?? 0.0;
      final totalAmount = _editedReceipt.totalAmount; 
      setState(() {
        if (paidAmount >= totalAmount) {
          _change = paidAmount - totalAmount;
          _showCashError = false;
        } else {
          _change = 0.0;
          _showCashError = _cashPaidController.text.isNotEmpty;
        }
      });
    } else {
      setState(() {
        _change = 0.0;
        _showCashError = false;
      });
    }
  }

  bool _validateInput() {
     if (_editedReceipt.paymentMethod == PaymentMethod.cash) {
        final paidAmount = double.tryParse(_cashPaidController.text) ?? 0.0;
        return paidAmount >= _editedReceipt.totalAmount;
     }
     return true; 
   }


  Future<void> _saveChanges() async {
    if (!_validateInput() || _isSaving) return;

     // Update the receipt object with current form values
     final finalReceipt = Receipt(
       id: _editedReceipt.id, 
       items: _editedReceipt.items, 
       totalAmount: _editedReceipt.totalAmount, 
       timestamp: _editedReceipt.timestamp, 
       paymentMethod: _editedReceipt.paymentMethod, 
       amountPaid: _editedReceipt.paymentMethod == PaymentMethod.cash
                   ? double.tryParse(_cashPaidController.text)
                   : null, 
       changeGiven: _editedReceipt.paymentMethod == PaymentMethod.cash
                   ? _change
                   : null, 
     );


    setState(() => _isSaving = true);

    try {
      int updatedRows = await DatabaseHelper.instance.updateReceiptHeader(finalReceipt);
      if (updatedRows > 0) {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Receipt updated successfully!'), backgroundColor: Colors.green),
             );
             Navigator.pop(context, true); 
         }
      } else {
         throw Exception('Receipt not found or could not be updated.');
      }

    } catch (e) {
      print("Error updating receipt: $e");
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error updating receipt: $e'), backgroundColor: Colors.red),
          );
      }
    } finally {
      // Ensure isSaving is reset even if mounted check fails 
       if (mounted) {
          setState(() => _isSaving = false);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Receipt ${widget.initialReceipt.id.substring(0, 8)}...'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form( 
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Non-Editable Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       Text('Receipt ID: ${widget.initialReceipt.id}', style: TextStyle(color: Colors.grey[700])),
                       Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.initialReceipt.timestamp)}', style: TextStyle(color: Colors.grey[700])), // Make sure DateFormat is imported
                       const SizedBox(height: 10),
                       Text(
                         'Total Amount: \$${widget.initialReceipt.totalAmount.toStringAsFixed(2)}',
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                       ),
                       const SizedBox(height: 10),
                       const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...widget.initialReceipt.items.entries.map((entry) => Padding(
                           padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                           child: Text('- ${entry.key.name} (x${entry.value})'),
                        )).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Editable Payment Method ---
              const Text('Payment Method:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              RadioListTile<PaymentMethod>(
                title: const Text('Cash'),
                value: PaymentMethod.cash,
                groupValue: _editedReceipt.paymentMethod,
                onChanged: (PaymentMethod? value) {
                  if (value != null) {
                    setState(() {
                      _editedReceipt = _editedReceipt.copyWith(paymentMethod: value);
                      _calculateChange(); 
                    });
                  }
                },
                secondary: const Icon(Icons.money),
                activeColor: Theme.of(context).primaryColor,
              ),
              RadioListTile<PaymentMethod>(
                title: const Text('Card'),
                value: PaymentMethod.card,
                groupValue: _editedReceipt.paymentMethod,
                onChanged: (PaymentMethod? value) {
                  if (value != null) {
                    setState(() {
                      _editedReceipt = _editedReceipt.copyWith(paymentMethod: value);
                      _cashPaidController.clear(); 
                      _calculateChange(); 
                    });
                  }
                },
                 secondary: const Icon(Icons.credit_card),
                 activeColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),

              // --- Editable Cash Details  ---
              if (_editedReceipt.paymentMethod == PaymentMethod.cash)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash Payment Details:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField( 
                      controller: _cashPaidController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        prefixText: '\$ ',
                         errorText: _showCashError ? 'Amount must be at least \$${widget.initialReceipt.totalAmount.toStringAsFixed(2)}' : null,
                      ),
                       validator: (value) { 
                         if (value == null || value.isEmpty) {
                           return 'Please enter amount paid';
                         }
                         final paid = double.tryParse(value);
                         if (paid == null) {
                            return 'Invalid amount';
                         }
                         if (paid < widget.initialReceipt.totalAmount) {
                           return 'Amount too low';
                         }
                         return null; 
                       },
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Change Due: \$${_change.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // --- Save Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                     backgroundColor: Colors.orange, 
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}