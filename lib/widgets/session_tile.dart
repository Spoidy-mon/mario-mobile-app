import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/dashboard_model.dart';

class SessionTile extends StatelessWidget {
  final String label;
  final String status; // whatever string the client software writes
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

  /// Live-ish means the status isn't one of the known "nobody's here"
  /// words — same rule used everywhere else in the app, so this tile
  /// never disagrees with the count on the home screen.
  bool get _live => isStatusActive(status);

  Color get _statusColor {
    if (!_live) return Colors.white24;
    if (isPaused) return AppColors.amber;
    if (isLow) return AppColors.red;
    return AppColors.green;
  }

  String get _statusLabel {
    if (!_live) return 'Free';
    if (isPaused) return 'Paused';
    if (isLow) return 'Low time';
    return 'Playing';
  }

  Color _payColor() {
    switch (paymentStatus) {
      case 'pending':
        return AppColors.red;
      case 'partial':
        return AppColors.amber;
      case 'paid':
        return AppColors.green;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a name whenever one is assigned — a paused session still has a
    // customer sitting at it, so it shouldn't disappear from the tile.
    final showName = customerName.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
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
              boxShadow: _live
                  ? [BoxShadow(color: _statusColor.withOpacity(0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Label + who's on it
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                if (showName)
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(customerName,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )
                else if (_live)
                  const Text('No name on record',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          // Time
          if (_live && timeStr.isNotEmpty)
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _payColor(), shape: BoxShape.circle),
            ),
          ],
          // Software health tick — shows whether the client app on this
          // machine is actively reporting to Firebase at all (any status
          // string other than "offline" counts as reporting in).
          const SizedBox(width: 6),
          Tooltip(
            message: status.toLowerCase() == 'offline' ? 'Software offline' : 'Software healthy',
            child: Icon(
              status.toLowerCase() == 'offline'
                  ? Icons.cancel_rounded
                  : Icons.check_circle_rounded,
              size: 14,
              color: status.toLowerCase() == 'offline' ? Colors.white24 : AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}