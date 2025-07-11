import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../widgets/report_filter_widget.dart';
import '../models/sales_profit_report_item.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  List<SalesProfitReportItem> _reportData = [];
  bool _isLoading = false;
  String _currentFilterSummary = 'No filters applied yet.';
  final priceFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  double _grandTotalProfit = 0.0;
  double _grandTotalRevenueForProfit = 0.0;
  double _grandTotalCostForProfit = 0.0;

  void _generateReport(DateTime startDate, DateTime endDate, List<String> selectedCategories) async {
    setState(() {
      _isLoading = true;
      _reportData = [];
      _grandTotalProfit = 0.0;
      _grandTotalRevenueForProfit = 0.0;
      _grandTotalCostForProfit = 0.0;
      _currentFilterSummary = 'Generating report for ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}' +
          (selectedCategories.isNotEmpty ? '\nCategories: ${selectedCategories.join(', ')}' : '\nAll Categories');
    });

    try {
      final rawData = await DatabaseHelper.instance.getSalesData(
        startDate: startDate,
        endDate: endDate,
        categories: selectedCategories.isEmpty ? null : selectedCategories,
      );

      double tempTotalProfit = 0.0;
      double tempTotalRevenue = 0.0;
      double tempTotalCost = 0.0;

      final processedData = rawData.map((row) {
        final item = SalesProfitReportItem(
          productName: row['productName'] as String,
          productId: row['productId'] as int,
          category: row['category'] as String,
          quantitySold: row['quantitySold'] as int? ?? 0,
          totalRevenue: row['totalRevenue'] as double? ?? 0.0,
          totalCost: row['totalCost'] as double?,
        );
        tempTotalProfit += item.profit;
        tempTotalRevenue += item.totalRevenue;
        tempTotalCost += (item.totalCost ?? 0.0);
        return item;
      }).toList();

      setState(() {
        _reportData = processedData;
        _grandTotalProfit = tempTotalProfit;
        _grandTotalRevenueForProfit = tempTotalRevenue;
        _grandTotalCostForProfit = tempTotalCost;
      });
    } catch (e) {
      print("Error generating profit report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit Report')),
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
            Expanded(
              child: Center(child: Text('No data found for profit calculation.', style: TextStyle(color: Colors.grey[600]))),
            )
          else if (_reportData.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryProfitRow("Total Revenue:", _grandTotalRevenueForProfit, Colors.blue),
                        _buildSummaryProfitRow("Total Cost:", _grandTotalCostForProfit, Colors.orange),
                        const Divider(height: 10),
                        _buildSummaryProfitRow("Grand Total Profit:", _grandTotalProfit, _grandTotalProfit >= 0 ? Colors.green : Colors.red, isLarge: true),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 18,
                        headingRowColor: MaterialStateColor.resolveWith(
                          (states) => Theme.of(context).primaryColorLight.withOpacity(0.3),
                        ),
                        columns: const [
                          DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Qty Sold', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        ],
                        rows: _reportData.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.productName)),
                            DataCell(Text(item.category)),
                            DataCell(Text(item.quantitySold.toString())),
                            DataCell(Text(idrFormatter.format(item.totalRevenue))),
                            DataCell(Text(item.totalCost != null ? idrFormatter.format(item.totalCost!) : 'N/A')),
                            DataCell(
                              Text(
                                idrFormatter.format(item.profit),
                                style: TextStyle(
                                  color: item.profit >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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

  Widget _buildSummaryProfitRow(String label, double value, Color valueColor, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isLarge ? FontWeight.bold : FontWeight.normal, fontSize: isLarge ? 16 : 14)),
          Text(
            idrFormatter.format(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 18 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
