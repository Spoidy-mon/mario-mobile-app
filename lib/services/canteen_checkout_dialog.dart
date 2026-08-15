import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/firebase_service.dart';
import '../services/canteen_cart_line.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_snackbar.dart';

/// Shows the cart total, lets staff either charge it to a customer's tab
/// (becomes a pending due, same as unpaid gaming time) or take cash on the
/// spot (an immediate walk-in sale). On confirm, sells the items and
/// decrements stock for each.
///
/// The customer/PC picker is always available and always editable — it
/// does NOT require an already-active gaming session. If someone is
/// currently playing, tapping their name/PC chip auto-fills it, but staff
/// can also just type any name and pick any PC manually (e.g. selling to
/// someone who hasn't started a gaming session yet, or fixing a session
/// that has no customer name recorded).
Future<void> showCanteenCheckoutDialog(
  BuildContext context, {
  required List<CanteenCartLine> cart,
  required VoidCallback onComplete,
}) async {
  if (cart.isEmpty) return;

  final total = cart.fold<double>(0, (sum, i) => sum + i.lineTotal);
  final prov = Provider.of<DashboardProvider>(context, listen: false);

  final nameCtrl = TextEditingController();
  bool cashSale = true;
  String paymentMode = 'cash'; // 'cash' | 'upi' — only relevant when cashSale is true
  String? selectedPcName; // null = no PC picked / not linked to a device

  // Every PC/wheel/PS5 that exists at all, regardless of whether it's
  // currently mid-session — staff should be able to charge to any of
  // them, not just ones that happen to be "active" right now.
  final allDevices = <String>[
    ...prov.stats.pcs.map((p) => p.name),
    if (prov.stats.wheel != null) prov.stats.wheel!.name,
    ...prov.stats.ps5s.map((p) => 'PS5 #${p.slot}'),
  ];

  // Quick-fill suggestions: anyone currently playing with a name on
  // record. Tapping one fills both the name field and the PC picker.
  final liveSuggestions = <MapEntry<String, String>>[
    ...prov.stats.pcs
        .where((p) => p.isActive && p.customerName.trim().isNotEmpty)
        .map((p) => MapEntry(p.customerName, p.name)),
    ...prov.stats.ps5s
        .where((p) => p.isActive && p.customerName.trim().isNotEmpty)
        .map((p) => MapEntry(p.customerName, 'PS5 #${p.slot}')),
  ];

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

                // ── PC / Device selection — always visible. For a tab
                // charge this decides which session's bill it merges into;
                // for a cash sale it just tags the sale for reporting. ──
                const Text('SELECT PC / DEVICE (OPTIONAL)',
                    style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cardRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DeviceChip(
                        label: 'None',
                        selected: selectedPcName == null,
                        onTap: () => setState(() => selectedPcName = null),
                      ),
                      ...allDevices.map((d) => _DeviceChip(
                            label: d,
                            selected: selectedPcName == d,
                            onTap: () => setState(() {
                              selectedPcName = d;
                              // Auto-fill the name if this device has a
                              // live customer already.
                              final match =
                                  liveSuggestions.where((e) => e.value == d);
                              if (match.isNotEmpty && nameCtrl.text.isEmpty) {
                                nameCtrl.text = match.first.key;
                              }
                            }),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Cash sale option
                RadioListTile<bool>(
                  value: true,
                  groupValue: cashSale,
                  onChanged: (v) => setState(() => cashSale = true),
                  activeColor: AppColors.green,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cash sale now',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Walk-in customer, paid immediately',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ),
                if (cashSale) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Row(
                      children: [
                        _PayModeChip(
                          label: '💵 Cash',
                          selected: paymentMode == 'cash',
                          onTap: () => setState(() => paymentMode = 'cash'),
                        ),
                        const SizedBox(width: 8),
                        _PayModeChip(
                          label: '📱 UPI',
                          selected: paymentMode == 'upi',
                          onTap: () => setState(() => paymentMode = 'upi'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Charge-to-customer option — always shown, always editable
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
                  const SizedBox(height: 10),

                  const Text('CUSTOMER NAME',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: appInputDecoration('Customer name', accent: AppColors.amber),
                    onChanged: (_) => setState(() {}),
                  ),

                  if (liveSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Currently playing — tap to auto-fill both fields',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: liveSuggestions.map((entry) {
                        final isSelected = nameCtrl.text == entry.key &&
                            selectedPcName == entry.value;
                        return GestureDetector(
                          onTap: () => setState(() {
                            nameCtrl.text = entry.key;
                            selectedPcName = entry.value;
                          }),
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
                              '${entry.value} · ${entry.key}',
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
                if (!cashSale && nameCtrl.text.trim().isEmpty) return;
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

  final customerName = nameCtrl.text.trim();

  try {
    await FirebaseService.sellCanteenItems(
      items: cart,
      chargeToCustomerName: cashSale ? null : customerName,
      chargeToPcName: selectedPcName,
      paymentMode: paymentMode,
    );
    if (context.mounted) {
      showAppSnackbar(
        context,
        cashSale
            ? 'Sale recorded (${paymentMode.toUpperCase()}) — ₹${total.toStringAsFixed(0)}'
            : "Added ₹${total.toStringAsFixed(0)} to $customerName's tab",
      );
    }
    onComplete();
  } catch (e) {
    if (context.mounted) showAppSnackbar(context, 'Failed: $e', error: true);
  }
}

class _PayModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PayModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.cardRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.green : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DeviceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardRaised,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}