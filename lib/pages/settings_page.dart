import 'package:cashier_app/pages/printer_settings_page.dart';
import 'package:flutter/material.dart';
import 'company_settings_page.dart';
import 'manage_categories_page.dart';
import 'transaction_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Company Information'),
            subtitle: const Text('Name, address, logo, receipt details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompanySettingsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add, edit, or delete product categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final bool? categoriesChanged = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const ManageCategoriesPage()),
              );
              if (categoriesChanged == true) {
                print("Categories were modified.");
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Transaction & Operational Settings'),
            subtitle: const Text('Payment methods, product data rules'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransactionSettingsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Printer Setup'),
            subtitle: const Text('Configure receipt printer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrinterSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
