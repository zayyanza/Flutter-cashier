import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../widgets/report_filter_widget.dart';
import '../models/sales_profit_report_item.dart'; 

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<SalesProfitReportItem> _reportData = [];
  bool _isLoading = false;
  String _currentFilterSummary = 'No filters applied yet.';
  final priceFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  double _grandTotalRevenue = 0.0;
  int _grandTotalQuantity = 0;

  void _generateReport(DateTime startDate, DateTime endDate, List<String> selectedCategories) async {
    setState(() {
      _isLoading = true;
      _reportData = [];
      _grandTotalRevenue = 0.0;
      _grandTotalQuantity = 0;
      _currentFilterSummary = 'Generating report for ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}'
                            + (selectedCategories.isNotEmpty ? '\nCategories: ${selectedCategories.join(', ')}' : '\nAll Categories');
    });

    try {
      final rawData = await DatabaseHelper.instance.getSalesData(
        startDate: startDate,
        endDate: endDate,
        categories: selectedCategories.isEmpty ? null : selectedCategories, // Pass null if all selected
      );

      double tempTotalRevenue = 0.0;
      int tempTotalQuantity = 0;

      final processedData = rawData.map((row) {
         tempTotalRevenue += (row['totalRevenue'] as double? ?? 0.0);
         tempTotalQuantity += (row['quantitySold'] as int? ?? 0);
        return SalesProfitReportItem(
          productName: row['productName'] as String,
          productId: row['productId'] as int,
          category: row['category'] as String,
          quantitySold: row['quantitySold'] as int? ?? 0,
          totalRevenue: row['totalRevenue'] as double? ?? 0.0,
          totalCost: row['totalCost'] as double?, // This might be null if buying price not set
        );
      }).toList();

      setState(() {
        _reportData = processedData;
        _grandTotalRevenue = tempTotalRevenue;
        _grandTotalQuantity = tempTotalQuantity;
      });
    } catch (e) {
      print("Error generating sales report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: Column(
        children: [
          ReportFilterWidget(onFilterApplied: _generateReport),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(_currentFilterSummary, style: TextStyle(color: Colors.grey[700]), textAlign: TextAlign.center),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_reportData.isEmpty && !_currentFilterSummary.contains('No filters'))
             Expanded(child: Center(child: Text('No sales data found for the selected criteria.', style: TextStyle(color: Colors.grey[600]))))
          else if (_reportData.isNotEmpty)
             Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Items Sold: $_grandTotalQuantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Total Revenue: ${idrFormatter.format(_grandTotalRevenue)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          headingRowColor: MaterialStateColor.resolveWith((states) => Theme.of(context).primaryColorLight.withOpacity(0.3)),
                          columns: const [
                            DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Qty Sold', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            DataColumn(label: Text('Total Revenue', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          ],
                          rows: _reportData.map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item.productName)),
                              DataCell(Text(item.category)),
                              DataCell(Text(item.quantitySold.toString())),
                              DataCell(Text(idrFormatter.format(item.totalRevenue))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
             ),
        ],
      ),
    );
  }
}