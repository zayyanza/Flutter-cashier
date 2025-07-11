import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class TransactionSettingsPage extends StatefulWidget {
  const TransactionSettingsPage({super.key});

  @override
  State<TransactionSettingsPage> createState() => _TransactionSettingsPageState();
}

class _TransactionSettingsPageState extends State<TransactionSettingsPage> {
  late CompanySettings _currentSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    _currentSettings = await CompanySettings.load();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await _currentSettings.save();

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction settings saved!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Settings'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              title: const Text('Buying Price Required for Products'),
              subtitle: Text(_currentSettings.isBuyingPriceRequired
                  ? 'Buying price must be entered for products.'
                  : 'Buying price is optional for products.'),
              value: _currentSettings.isBuyingPriceRequired,
              onChanged: (bool value) {
                setState(() {
                  _currentSettings.isBuyingPriceRequired = value;
                });
              },
              secondary: const Icon(Icons.attach_money_outlined),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Enable E-money Payment Method'),
              subtitle: Text(_currentSettings.isEmoneyActive
                  ? 'E-money will be an available payment option.'
                  : 'E-money payment option will be hidden.'),
              value: _currentSettings.isEmoneyActive,
              onChanged: (bool value) {
                setState(() {
                  _currentSettings.isEmoneyActive = value;
                });
              },
              secondary: const Icon(Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Transaction Settings'),
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
