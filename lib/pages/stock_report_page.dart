import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/database_helper.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  late Future<List<Product>> _stockDataFuture;
  final priceFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _stockDataFuture = DatabaseHelper.instance.getProductsForStockReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Report'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _stockDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No product data found.'));
          } else {
            final products = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Theme.of(context).primaryColorLight.withOpacity(0.3),
                ),
                columns: const [
                  DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Buying Price', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Total Stock Value (Buy)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Total Stock Value (Sell)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: products.map((product) {
                  final totalStockValueBuy = (product.buyingPrice ?? 0.0) * product.stock;
                  final totalStockValueSell = product.price * product.stock;
                  return DataRow(cells: [
                    DataCell(Text(product.name)),
                    DataCell(Text(product.stock.toString())),
                    DataCell(Text(product.buyingPrice != null ? idrFormatter.format(product.buyingPrice!) : 'N/A')),
                    DataCell(Text(idrFormatter.format(product.price))),
                    DataCell(Text(idrFormatter.format(totalStockValueBuy))),
                    DataCell(Text(idrFormatter.format(totalStockValueSell))),
                  ]);
                }).toList(),
              ),
            );
          }
        },
      ),
    );
  }
}
