class SalesProfitReportItem {
  final String productName;
  final int productId;
  final String category;
  final int quantitySold;
  final double totalRevenue;
  final double? totalCost; 

  SalesProfitReportItem({
    required this.productName,
    required this.productId,
    required this.category,
    required this.quantitySold,
    required this.totalRevenue,
    this.totalCost,
  });

  double get profit => totalRevenue - (totalCost ?? 0.0);
}