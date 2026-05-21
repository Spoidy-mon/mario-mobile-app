import 'package:flutter/material.dart';

class SessionTile extends StatelessWidget {
  final String label;
  final String status; // active | offline | online
  final bool isPaused;
  final bool isLow;
  final String timeStr;
  final String customerName;
  final String paymentStatus;

  const SessionTile({
    super.key,
    required this.label,
    required this.status,
    this.isPaused = false,
    this.isLow = false,
    this.timeStr = '',
    this.customerName = '',
    this.paymentStatus = '',
  });

  Color get _statusColor {
    if (status == 'offline') return Colors.white24;
    if (status == 'active' && isPaused) return const Color(0xFFF59E0B);
    if (status == 'active' && isLow) return const Color(0xFFEF4444);
    if (status == 'active') return const Color(0xFF22C55E);
    return const Color(0xFF3B82F6);
  }

  String get _statusLabel {
    if (status == 'offline') return 'Offline';
    if (status == 'active' && isPaused) return 'Paused';
    if (status == 'active' && isLow) return 'Low time';
    if (status == 'active') return 'Active';
    return 'Online';
  }

  Color _payColor() {
    switch (paymentStatus) {
      case 'pending': return const Color(0xFFEF4444);
      case 'partial': return const Color(0xFFF59E0B);
      case 'paid': return const Color(0xFF22C55E);
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              boxShadow: status == 'active'
                  ? [BoxShadow(color: _statusColor.withOpacity(0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Label
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (customerName.isNotEmpty && status == 'active')
                  Text(customerName,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.5)),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Time
          if (status == 'active')
            Text(timeStr,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_statusLabel,
                style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w600)),
          ),
          // Payment dot
          if (paymentStatus == 'pending' || paymentStatus == 'partial') ...[
            const SizedBox(width: 6),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: _payColor(), shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
