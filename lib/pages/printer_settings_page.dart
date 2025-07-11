import 'package:cashier_app/models/product.dart';
import 'package:cashier_app/models/receipt.dart';
import 'package:cashier_app/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDeviceState;
  bool _isLoadingDevices = false;
  bool _isConnecting = false;
  String _connectionStatus = "Not Connected";

  @override
  void initState() {
    super.initState();
    _selectedDeviceState = _printerService.selectedDevice;
    _updateConnectionStatus();
    _loadPairedDevices();
  }

  void _updateConnectionStatus() {
    setState(() {
      if (_printerService.isConnected && _printerService.selectedDevice != null) {
        _connectionStatus = "Connected to: ${_printerService.selectedDevice!.name}";
      } else {
        _connectionStatus = "Not Connected";
      }
    });
  }

  Future<void> _loadPairedDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      _devices = await _printerService.getPairedDevices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading devices: $e')));
    }
    setState(() => _isLoadingDevices = false);
  }

  Future<void> _connectToDevice() async {
    if (_selectedDeviceState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a printer.')));
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await _printerService.connect(_selectedDeviceState!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${_selectedDeviceState!.name}!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
    _updateConnectionStatus();
    setState(() => _isConnecting = false);
  }

  Future<void> _disconnectDevice() async {
    await _printerService.disconnect();
    _updateConnectionStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected from printer.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_connectionStatus, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _isLoadingDevices
                ? const Center(child: CircularProgressIndicator())
                : _devices.isEmpty
                    ? const Text('No paired Bluetooth devices found. Please pair a printer in your device settings.')
                    : DropdownButtonFormField<BluetoothDevice>(
                        decoration: const InputDecoration(labelText: 'Select Paired Printer', border: OutlineInputBorder()),
                        value: _selectedDeviceState,
                        isExpanded: true,
                        items: _devices.map((device) {
                          return DropdownMenuItem<BluetoothDevice>(
                            value: device,
                            child: Text(device.name ?? device.address ?? 'Unknown Device'),
                          );
                        }).toList(),
                        onChanged: (BluetoothDevice? newValue) {
                          setState(() {
                            _selectedDeviceState = newValue;
                          });
                        },
                      ),
            const SizedBox(height: 20),
            _isConnecting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text('Connect to Selected Printer'),
                    onPressed: _selectedDeviceState == null ? null : _connectToDevice,
                  ),
            const SizedBox(height: 10),
            if (_printerService.isConnected)
              OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth_disabled, color: Colors.orange),
                label: const Text('Disconnect Printer', style: TextStyle(color: Colors.orange)),
                onPressed: _disconnectDevice,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Test Print'),
              onPressed: !_printerService.isConnected
                  ? null
                  : () async {
                      try {
                        final companySettings = await CompanySettings.load();
                        final dummyReceipt = Receipt(
                          id: "TEST-001",
                          items: {
                            Product(id: 1, name: "Test Item A", category: "Test", price: 10.00, stock: 1): 1,
                            Product(id: 2, name: "Test Item B", category: "Test", price: 5.50, stock: 1): 2,
                          },
                          totalAmount: 21.00,
                          paymentMethod: PaymentMethod.cash,
                          amountPaid: 25.00,
                          changeGiven: 4.00,
                          timestamp: DateTime.now(),
                        );
                        await _printerService.printReceipt(dummyReceipt, companySettings);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test print sent!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
