import 'product.dart'; 


enum PaymentMethod { cash, card, eMoney, other }

class Receipt {
  final String id; 
  final Map<Product, int> items; 
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double? amountPaid; 
  final double? changeGiven; 
  final DateTime timestamp;

  Receipt({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.amountPaid,
    this.changeGiven,
    required this.timestamp,
  });

  // Helper to get a formatted string for the payment method
  String get paymentMethodString {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.eMoney: 
        return 'E-money';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

// Helper extension to easily update Receipt fields 
extension ReceiptCopy on Receipt {
  Receipt copyWith({
    PaymentMethod? paymentMethod,
    double? amountPaid, 
    double? changeGiven,
  }) {
    return Receipt(
      id: id,
      items: items,
      totalAmount: totalAmount,
      timestamp: timestamp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
       amountPaid: (paymentMethod ?? this.paymentMethod) == PaymentMethod.cash ? (amountPaid ?? this.amountPaid) : null,
       changeGiven: (paymentMethod ?? this.paymentMethod) == PaymentMethod.cash ? (changeGiven ?? this.changeGiven) : null,
    );
  }
}