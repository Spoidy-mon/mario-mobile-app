import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/canteen_cart_line.dart';
import '../theme/app_colors.dart';
import '../theme/app_snackbar.dart';

class _ChargeableCustomer {
  final String label; // e.g. "PC-3 · Rohan"
  final String customerName;
  final String pcName;
  const _ChargeableCustomer({
    required this.label,
    required this.customerName,
    required this.pcName,
  });
}

/// Shows the cart total, lets staff either charge it to an active PC/PS5
/// customer's tab (becomes a pending due, same as unpaid gaming time) or
/// take cash on the spot (an immediate walk-in sale). On confirm, sells
/// the items and decrements stock for each.
Future<void> showCanteenCheckoutDialog(
  BuildContext context, {
  required List<CanteenCartLine> cart,
  required VoidCallback onComplete,
}) async {
  if (cart.isEmpty) return;

  final total = cart.fold<double>(0, (sum, i) => sum + i.lineTotal);
  final prov = Provider.of<DashboardProvider>(context, listen: false);

  // Only customers with a name on record can be charged — an "active"
  // session with no name has nothing to attach the due to.
  final chargeable = <_ChargeableCustomer>[
    ...prov.stats.pcs
        .where((p) => p.isActive && p.customerName.trim().isNotEmpty)
        .map((p) => _ChargeableCustomer(
              label: '${p.name} · ${p.customerName}',
              customerName: p.customerName,
              pcName: p.name,
            )),
    ...prov.stats.ps5s
        .where((p) => p.isActive && p.customerName.trim().isNotEmpty)
        .map((p) => _ChargeableCustomer(
              label: 'PS5 #${p.slot} · ${p.customerName}',
              customerName: p.customerName,
              pcName: 'PS5 #${p.slot}',
            )),
  ];

  bool cashSale = chargeable.isEmpty; // default to cash if nobody to charge
  _ChargeableCustomer? selected;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Checkout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...cart.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${line.name} × ${line.quantity}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                          Text('₹${line.lineTotal.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    )),
                const Divider(color: AppColors.border, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppColors.green, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 18),

                // Cash sale option
                RadioListTile<bool>(
                  value: true,
                  groupValue: cashSale,
                  onChanged: (v) => setState(() {
                    cashSale = true;
                    selected = null;
                  }),
                  activeColor: AppColors.green,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cash sale now',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Walk-in customer, paid immediately',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ),

                // Charge-to-customer option
                if (chargeable.isNotEmpty) ...[
                  RadioListTile<bool>(
                    value: false,
                    groupValue: cashSale,
                    onChanged: (v) => setState(() => cashSale = false),
                    activeColor: AppColors.amber,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Add to a customer's tab",
                        style: TextStyle(color: Colors.white, fontSize: 13.5)),
                    subtitle: const Text('Becomes a pending due, collected later',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                  if (!cashSale) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chargeable.map((c) {
                        final isSelected = selected?.customerName == c.customerName &&
                            selected?.pcName == c.pcName;
                        return GestureDetector(
                          onTap: () => setState(() => selected = c),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.amber : AppColors.cardRaised,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isSelected ? AppColors.amber : AppColors.border),
                            ),
                            child: Text(
                              c.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: cashSale ? AppColors.green : AppColors.amber),
              onPressed: () {
                if (!cashSale && selected == null) return;
                Navigator.pop(ctx, true);
              },
              child: Text(cashSale ? 'Take Cash' : 'Add to Tab'),
            ),
          ],
        );
      });
    },
  );

  if (confirmed != true) return;

  try {
    await FirebaseService.sellCanteenItems(
      items: cart,
      chargeToCustomerName: cashSale ? null : selected!.customerName,
      chargeToPcName: cashSale ? null : selected!.pcName,
    );
    if (context.mounted) {
      showAppSnackbar(
        context,
        cashSale
            ? 'Sale recorded — ₹${total.toStringAsFixed(0)}'
            : "Added ₹${total.toStringAsFixed(0)} to ${selected!.customerName}'s tab",
      );
    }
    onComplete();
  } catch (e) {
    if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
  }
}
