import 'package:flutter/material.dart';
import 'stock_report_page.dart';
import 'sales_report_page.dart';
import 'profit_report_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildReportNavigationTile(
            context,
            title: 'Stock Report',
            subtitle: 'View current stock levels and values.',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StockReportPage()),
              );
            },
          ),
          const Divider(),
          _buildReportNavigationTile(
            context,
            title: 'Sales Report',
            subtitle: 'Analyze sales by date and category.',
            icon: Icons.point_of_sale_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesReportPage()),
              );
            },
          ),
          const Divider(),
          _buildReportNavigationTile(
            context,
            title: 'Profit Report',
            subtitle: 'Track profit margins by date and category.',
            icon: Icons.trending_up_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfitReportPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportNavigationTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 36.0, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
