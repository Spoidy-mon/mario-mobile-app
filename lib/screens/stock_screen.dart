import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/report_model.dart';
import '../services/canteen_cart_line.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/canteen_checkout_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  // Cart quantity per item, keyed by StockItem.key. This is completely
  // separate from the item's stored stock count — it's just "how many of
  // this item is the customer buying right now", built up before checkout.
  final Map<String, int> _cart = {};

  int _cartQtyFor(String key) => _cart[key] ?? 0;

  void _incCart(StockItem item) {
    if (_cartQtyFor(item.key) >= item.quantity) return; // can't sell more than in stock
    setState(() => _cart[item.key] = _cartQtyFor(item.key) + 1);
  }

  void _decCart(StockItem item) {
    final current = _cartQtyFor(item.key);
    if (current <= 0) return;
    setState(() {
      if (current == 1) {
        _cart.remove(item.key);
      } else {
        _cart[item.key] = current - 1;
      }
    });
  }

  double get _cartTotal {
    final stock = context.read<DashboardProvider>().stock;
    double total = 0;
    _cart.forEach((key, qty) {
      StockItem? item;
      for (final s in stock) {
        if (s.key == key) { item = s; break; }
      }
      if (item != null) total += item.price * qty;
    });
    return total;
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  List<CanteenCartLine> _buildCartLines(List<StockItem> stock) {
    final lines = <CanteenCartLine>[];
    _cart.forEach((key, qty) {
      StockItem? item;
      for (final s in stock) {
        if (s.key == key) { item = s; break; }
      }
      if (item != null) {
        lines.add(CanteenCartLine(
          stockKey: item.key,
          sourceNode: item.sourceNode,
          quantityField: item.quantityField,
          name: item.name,
          price: item.price,
          quantity: qty,
        ));
      }
    });
    return lines;
  }

  Future<void> _checkout() async {
    final stock = context.read<DashboardProvider>().stock;
    final lines = _buildCartLines(stock);
    if (lines.isEmpty) return;
    await showCanteenCheckoutDialog(
      context,
      cart: lines,
      onComplete: () => setState(() => _cart.clear()),
    );
  }

  Future<void> _addItem(BuildContext context, String sourceNode) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    final priceCtrl = TextEditingController();
    final lowCtrl = TextEditingController(text: '5');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Stock Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Item name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Quantity'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Unit (pcs/kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Price (₹)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lowCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Low alert at'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );

    if (result != true) return;
    try {
      await FirebaseService.addStockItem(
        node: sourceNode,
        name: nameCtrl.text.trim(),
        quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
        unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
        price: double.tryParse(priceCtrl.text.trim()) ?? 0,
        lowThreshold: double.tryParse(lowCtrl.text.trim()) ?? 5,
      );
      if (context.mounted) showAppSnackbar(context, 'Item added');
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  InputDecoration _dec(String label) => appInputDecoration(label, accent: AppColors.green);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final stock = prov.stock;
    final lowCount = stock.where((s) => s.isLow || s.isOut).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Canteen Stock',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: _cartCount == 0
          ? FloatingActionButton.extended(
              onPressed: () => _addItem(context, prov.stockSourceNode),
              backgroundColor: AppColors.green,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      body: Stack(
        children: [
          stock.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📦', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 12),
                        const Text('No stock items yet',
                            style: TextStyle(color: Colors.white54, fontSize: 15)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DEBUG — build v3',
                                  style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                              const SizedBox(height: 6),
                              Text('active source: ${prov.stockSourceNode}',
                                  style: const TextStyle(
                                      color: AppColors.green,
                                      fontSize: 11,
                                      fontFamily: 'monospace')),
                              Text('parsed items: ${prov.stock.length}',
                                  style: const TextStyle(
                                      color: AppColors.green,
                                      fontSize: 11,
                                      fontFamily: 'monospace')),
                              const SizedBox(height: 6),
                              Text(prov.stockCandidateCounts,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontFamily: 'monospace')),
                              if (prov.stockError != null) ...[
                                const SizedBox(height: 6),
                                Text('ERROR: ${prov.stockError}',
                                    style: const TextStyle(
                                        color: AppColors.red,
                                        fontSize: 10,
                                        fontFamily: 'monospace')),
                              ],
                              if (prov.error != null) ...[
                                const SizedBox(height: 6),
                                Text('STREAM: ${prov.error}',
                                    style: const TextStyle(
                                        color: AppColors.amber,
                                        fontSize: 10,
                                        fontFamily: 'monospace')),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, _cartCount > 0 ? 100 : 90),
                  children: [
                    if (lowCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  '$lowCount item${lowCount == 1 ? '' : 's'} low or out of stock',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ...stock.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 35 * e.key),
                            child: _StockTile(
                              item: e.value,
                              cartQty: _cartQtyFor(e.value.key),
                              onCartInc: () => _incCart(e.value),
                              onCartDec: () => _decCart(e.value),
                            ),
                          ),
                        )),
                  ],
                ),

          // ── Checkout bar ────────────────────────────────────────────
          if (_cartCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _checkout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$_cartCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            const Text('Checkout',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Text('₹${_cartTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final StockItem item;
  final int cartQty;
  final VoidCallback onCartInc;
  final VoidCallback onCartDec;

  const _StockTile({
    required this.item,
    required this.cartQty,
    required this.onCartInc,
    required this.onCartDec,
  });

  Future<void> _adjust(BuildContext context, double delta) async {
    try {
      await FirebaseService.adjustStock(
        item.key,
        delta,
        sourceNode: item.sourceNode,
        quantityField: item.quantityField,
      );
    } catch (e) {
      if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = item.isOut ? AppColors.red : (item.isLow ? AppColors.amber : AppColors.green);
    final qtyStr = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);
    final inCart = cartQty > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: inCart ? AppColors.primary : color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        item.emoji.isNotEmpty ? '${item.emoji}  ${item.name}' : item.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                        item.category.isNotEmpty
                            ? '₹${item.price.toStringAsFixed(0)} · ${item.category}'
                            : '₹${item.price.toStringAsFixed(0)} / ${item.unit}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                    if (item.isOut)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text('Out of stock',
                            style: TextStyle(color: AppColors.red, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      )
                    else if (item.isLow)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text('Running low',
                            style: TextStyle(color: AppColors.amber, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              // Small stock-correction controls (adjusts inventory count,
              // NOT a sale) — kept compact/secondary since selling is the
              // primary action on this screen now.
              Column(
                children: [
                  const Text('stock', style: TextStyle(color: Colors.white24, fontSize: 8)),
                  Row(
                    children: [
                      _MiniBtn(icon: Icons.remove, onTap: () => _adjust(context, -1)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 24),
                        child: Text(
                          qtyStr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                      _MiniBtn(icon: Icons.add, onTap: () => _adjust(context, 1)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          // ── Sell quantity stepper — this is what builds the cart ──────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sell', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Row(
                children: [
                  _SellBtn(
                    icon: Icons.remove,
                    enabled: cartQty > 0,
                    color: AppColors.primary,
                    onTap: onCartDec,
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      '$cartQty',
                      style: TextStyle(
                        color: inCart ? AppColors.primary : Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _SellBtn(
                    icon: Icons.add,
                    enabled: !item.isOut && cartQty < item.quantity,
                    color: AppColors.primary,
                    onTap: onCartInc,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 12, color: Colors.white54),
      ),
    );
  }
}

class _SellBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;
  const _SellBtn({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? color.withOpacity(0.4) : Colors.transparent),
        ),
        child: Icon(icon, size: 16, color: enabled ? color : Colors.white24),
      ),
    );
  }
}