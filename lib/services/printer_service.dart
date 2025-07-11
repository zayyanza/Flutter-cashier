import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../models/product.dart';
import '../services/settings_service.dart';

class PrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } on PlatformException catch (e) {
      print("Error getting paired devices: $e");
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnected && _selectedDevice?.address == device.address) {
      print("Already connected to ${device.name}");
      return true;
    }
    try {
      _selectedDevice = device;
      await bluetooth.connect(_selectedDevice!);
      _isConnected = true;
      print("Connected to printer: ${device.name}");
      return true;
    } on PlatformException catch (e) {
      _isConnected = false;
      _selectedDevice = null;
      print("Error connecting to printer: $e");
      throw Exception("Failed to connect: ${e.message}");
    }
  }

  Future<void> disconnect() async {
    if (_isConnected) {
      try {
        await bluetooth.disconnect();
        _isConnected = false;
        _selectedDevice = null;
        print("Disconnected from printer");
      } on PlatformException catch (e) {
        print("Error disconnecting from printer: $e");
      }
    }
  }

  bool get isConnected => _isConnected;
  BluetoothDevice? get selectedDevice => _selectedDevice;

  Future<void> printReceipt(Receipt receipt, CompanySettings companySettings) async {
    if (!_isConnected || _selectedDevice == null) {
      throw Exception('Printer not connected. Please connect to a printer first.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    if (companySettings.printLogoOnReceipt && companySettings.logoPath != null) {
      // Image printing skipped for simplicity
    }
    if (companySettings.name.isNotEmpty) {
      bytes += generator.text(companySettings.name, styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    }
    if (companySettings.address.isNotEmpty) {
      bytes += generator.text(companySettings.address, styles: PosStyles(align: PosAlign.center));
    }
    if (companySettings.phoneNumber.isNotEmpty) {
      bytes += generator.text(companySettings.phoneNumber, styles: PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr(ch: '-');

    bytes += generator.text('RECEIPT', styles: PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('ID: ${receipt.id.substring(0, 8)}...', styles: PosStyles(align: PosAlign.left));
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(receipt.timestamp)}', styles: PosStyles(align: PosAlign.left));
    bytes += generator.hr(ch: '-');

    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'Price', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    for (var entry in receipt.items.entries) {
      Product product = entry.key;
      int quantity = entry.value;
      bytes += generator.row([
        PosColumn(text: product.name, width: 6),
        PosColumn(text: quantity.toString(), width: 2, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: (product.price * quantity).toStringAsFixed(2), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr(ch: '-');

    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
      PosColumn(text: receipt.totalAmount.toStringAsFixed(2), width: 6, styles: PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
    ]);
    bytes += generator.hr(ch: '-');

    bytes += generator.text('Payment Method: ${receipt.paymentMethodString}');
    if (receipt.paymentMethod == PaymentMethod.cash) {
      if (receipt.amountPaid != null) {
        bytes += generator.text('Amount Paid: ${receipt.amountPaid!.toStringAsFixed(2)}');
      }
      if (receipt.changeGiven != null) {
        bytes += generator.text('Change Given: ${receipt.changeGiven!.toStringAsFixed(2)}');
      }
    }
    bytes += generator.feed(1);

    if (companySettings.receiptFootnote.isNotEmpty) {
      bytes += generator.text(companySettings.receiptFootnote, styles: PosStyles(align: PosAlign.center));
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    try {
      await bluetooth.writeBytes(Uint8List.fromList(bytes));
      print("Receipt sent to printer.");
    } on PlatformException catch (e) {
      print("Error writing to printer: $e");
      throw Exception("Failed to print: ${e.message}");
    }
  }
}
