/// One line in the canteen cart — an item with a quantity being sold.
/// Carries enough info from the original StockItem to both decrement the
/// right stock record afterward and describe the sale.
class CanteenCartLine {
  final String stockKey; // StockItem.key
  final String sourceNode; // StockItem.sourceNode
  final String quantityField; // StockItem.quantityField
  final String name;
  final double price;
  final int quantity;

  const CanteenCartLine({
    required this.stockKey,
    required this.sourceNode,
    required this.quantityField,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  CanteenCartLine copyWith({int? quantity}) => CanteenCartLine(
        stockKey: stockKey,
        sourceNode: sourceNode,
        quantityField: quantityField,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
      );
}