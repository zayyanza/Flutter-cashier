import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import 'home_page.dart';
import '../services/settings_service.dart';
import 'dart:io';
import '../services/printer_service.dart';

class ReceiptPage extends StatefulWidget {
  final Receipt receipt;
  final bool isViewingPastReceipt;

  const ReceiptPage({
    super.key,
    required this.receipt,
    this.isViewingPastReceipt = false,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  CompanySettings? _companySettings;
  bool _isLoadingSettings = true;
  final PrinterService _printerService = PrinterService();
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
  }

  Future<void> _loadCompanySettings() async {
    setState(() => _isLoadingSettings = true);
    _companySettings = await CompanySettings.load();
    setState(() => _isLoadingSettings = false);
  }

  Future<void> _printCurrentReceipt() async {
    if (_companySettings == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company settings not loaded.')));
      return;
    }
    if (!_printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer not connected. Please connect in Printer Setup.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      await _printerService.printReceipt(widget.receipt, _companySettings!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent to printer!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printing failed: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        automaticallyImplyLeading: widget.isViewingPastReceipt,
        leading: widget.isViewingPastReceipt
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (!_isLoadingSettings && _printerService.isConnected)
            IconButton(
              icon: _isPrinting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.print_outlined),
              onPressed: _isPrinting ? null : _printCurrentReceipt,
              tooltip: 'Print Receipt',
            ),
        ],
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_companySettings != null) ...[
                    if (_companySettings!.printLogoOnReceipt &&
                        _companySettings!.logoPath != null &&
                        _companySettings!.logoPath!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Image.file(
                          File(_companySettings!.logoPath!),
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    if (_companySettings!.name.isNotEmpty)
                      Text(_companySettings!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    if (_companySettings!.address.isNotEmpty)
                      Text(_companySettings!.address, textAlign: TextAlign.center),
                    if (_companySettings!.phoneNumber.isNotEmpty) Text(_companySettings!.phoneNumber),
                    const SizedBox(height: 10),
                    const Divider(),
                  ],
                  const SizedBox(height: 10),
                  Text('Receipt ID: ${widget.receipt.id.substring(0, 8)}...', style: TextStyle(color: Colors.grey[600])),
                  Text('Date: ${dateFormat.format(widget.receipt.timestamp)}'),
                  const SizedBox(height: 10),
                  const Divider(),
                  const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.receipt.items.length,
                      itemBuilder: (context, index) {
                        final product = widget.receipt.items.keys.elementAt(index);
                        final quantity = widget.receipt.items[product]!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${product.name} (x$quantity)')),
                              const SizedBox(width: 10),
                              Text(idrFormatter.format(product.price * quantity)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Total Amount:', idrFormatter.format(widget.receipt.totalAmount), isTotal: true),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Payment Method:', widget.receipt.paymentMethodString),
                  if (widget.receipt.paymentMethod == PaymentMethod.cash) ...[
                    const SizedBox(height: 5),
                    _buildSummaryRow('Amount Paid:', widget.receipt.amountPaid != null ? idrFormatter.format(widget.receipt.amountPaid!) : 'N/A'),
                    const SizedBox(height: 5),
                    _buildSummaryRow('Change Given:', widget.receipt.changeGiven != null ? idrFormatter.format(widget.receipt.changeGiven!) : 'N/A'),
                  ],
                  if (_companySettings != null && _companySettings!.receiptFootnote.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(
                      _companySettings!.receiptFootnote,
                      style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!widget.isViewingPastReceipt) ...[
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text('Start New Order'),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    const Spacer(),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
