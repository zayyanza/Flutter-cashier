import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import 'receipt_page.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';

class PaymentPage extends StatefulWidget {
  final Map<Product, int> order;
  final double totalAmount;

  const PaymentPage({
    super.key,
    required this.order,
    required this.totalAmount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  PaymentMethod? _selectedMethod;
  final TextEditingController _cashPaidController = TextEditingController();
  double _change = 0.0;
  bool _showCashError = false;
  bool _isProcessingPayment = false;

  bool _isEmoneyPaymentActive = true;
  bool _isLoadingPaymentSettings = true;

  @override
  void initState() {
    super.initState();
    _cashPaidController.addListener(_calculateChange);
    _loadPaymentPageSettings();
  }

  @override
  void dispose() {
    _cashPaidController.removeListener(_calculateChange);
    _cashPaidController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPaymentPageSettings() async {
    setState(() => _isLoadingPaymentSettings = true);
    final settings = await CompanySettings.load();
    setState(() {
      _isEmoneyPaymentActive = settings.isEmoneyActive;
      _isLoadingPaymentSettings = false;
    });
  }
  
  void _calculateChange() {
    if (_selectedMethod == PaymentMethod.cash) {
      final paidAmount = double.tryParse(_cashPaidController.text) ?? 0.0;
      setState(() {
        if (paidAmount >= widget.totalAmount) {
          _change = paidAmount - widget.totalAmount;
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

  bool _isPaymentValid() {
    if (_isProcessingPayment || _selectedMethod == null) return false;
    if (_selectedMethod == PaymentMethod.cash) {
      final paidAmount = double.tryParse(_cashPaidController.text) ?? 0.0;
      return paidAmount >= widget.totalAmount;
    }
    return true;
  }

  void _confirmPayment() async {
    if (!_isPaymentValid()) return;

    setState(() => _isProcessingPayment = true);

    final receiptId = const Uuid().v4();
    final timestamp = DateTime.now();

    final newReceipt = Receipt(
      id: receiptId,
      items: widget.order,
      totalAmount: widget.totalAmount,
      paymentMethod: _selectedMethod!,
      amountPaid: _selectedMethod == PaymentMethod.cash
          ? double.parse(_cashPaidController.text)
          : null,
      changeGiven: _selectedMethod == PaymentMethod.cash ? _change : null,
      timestamp: timestamp,
    );

    try {
      await DatabaseHelper.instance.insertReceipt(newReceipt);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptPage(receipt: newReceipt),
          ),
          (Route<dynamic> route) => route.isFirst,
        );
      }

    } catch (e) {
      print("Error saving receipt: $e");
      setState(() => _isProcessingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving receipt: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoadingPaymentSettings) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      const Text('Total Amount Due', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text(
                        idrFormatter.format(widget.totalAmount),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Select Payment Method:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            RadioListTile<PaymentMethod>(
              title: const Text('Cash'),
              value: PaymentMethod.cash,
              groupValue: _selectedMethod,
              onChanged: (PaymentMethod? value) {
                setState(() {
                  _selectedMethod = value;
                  _calculateChange();
                });
              },
              secondary: const Icon(Icons.money),
              activeColor: Theme.of(context).primaryColor,
            ),
            RadioListTile<PaymentMethod>(
              title: const Text('Card'),
              value: PaymentMethod.card,
              groupValue: _selectedMethod,
              onChanged: (PaymentMethod? value) {
                setState(() {
                  _selectedMethod = value;
                  _cashPaidController.clear();
                  _calculateChange();
                });
              },
              secondary: const Icon(Icons.credit_card),
              activeColor: Theme.of(context).primaryColor,
            ),
            if (_isEmoneyPaymentActive)
              RadioListTile<PaymentMethod>(
                title: const Text('E-money / Wallet'),
                value: PaymentMethod.eMoney,
                groupValue: _selectedMethod,
                onChanged: (PaymentMethod? value) {
                  setState(() {
                    _selectedMethod = value;
                    _cashPaidController.clear();
                    _calculateChange();
                  });
                },
                secondary: const Icon(Icons.account_balance_wallet_outlined),
                activeColor: Theme.of(context).primaryColor,
              ),
            const SizedBox(height: 20),

            if (_selectedMethod == PaymentMethod.cash)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Payment Details:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cashPaidController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount Paid',
                      prefixText: 'Rp',
                      errorText: _showCashError ? 'Amount must be at least ${idrFormatter.format(widget.totalAmount)}' : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Change Due: ${idrFormatter.format(_change)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isProcessingPayment
                     ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                     : const Icon(Icons.check_circle_outline),
                label: Text(_isProcessingPayment ? 'Processing...' : 'Confirm Payment'),
                onPressed: _isPaymentValid() ? _confirmPayment : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: _isPaymentValid() ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
