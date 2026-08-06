import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_snackbar.dart';

/// Shows exactly what's really in your Firebase Realtime Database right
/// now — every top-level node, how many items it has, and a real sample
/// record with its actual field names. Use this to find out what your
/// canteen stock / membership nodes are actually called if the app's
/// guesses ("canteen_stock", "memberships", etc.) don't match.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic>? _summary;
  String? _error;
  bool _loading = true;
  String? _expandedKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FirebaseService.fetchRootSummary();
      if (!mounted) return;
      setState(() {
        _summary = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmClearNode(String nodeName, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear this node?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This permanently deletes all $count item${count == 1 ? '' : 's'} under '
          '"$nodeName". Use this only to remove stray test data — not your real data.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseService.clearNode(nodeName);
      if (mounted) {
        showAppSnackbar(context, '"$nodeName" cleared');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackbar(context, 'Failed: $e', error: true);
    }
  }

  String _prettySample(dynamic sample) {
    if (sample == null) return '(empty — no items yet)';
    try {
      if (sample is Map) {
        final clean = sample.map((k, v) => MapEntry(k.toString(), v));
        return const JsonEncoder.withIndent('  ').convert(clean);
      }
      return sample.toString();
    } catch (_) {
      return sample.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Firebase Diagnostics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error reading database:\n$_error',
                        style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'This lists every top-level node actually in your Firebase '
                        'database right now. Tap one to see a real sample record and '
                        'its exact field names — use this to spot what your canteen '
                        'stock / membership nodes are really called.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_summary == null || _summary!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('Database appears empty',
                              style: TextStyle(color: Colors.white38)),
                        ),
                      ),
                    ..._summary!.entries.map((e) {
                      final data = e.value as Map;
                      final count = data['count'] as int;
                      final sample = data['sample'];
                      final expanded = _expandedKey == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                              color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(
                                    () => _expandedKey = expanded ? null : e.key),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(e.key,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6)),
                                        child: Text('$count items',
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                          expanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Colors.white38,
                                          size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              if (expanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(8)),
                                        child: SelectableText(
                                          _prettySample(sample),
                                          style: const TextStyle(
                                              color: AppColors.green,
                                              fontSize: 11,
                                              fontFamily: 'monospace'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _confirmClearNode(e.key, count),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 15, color: AppColors.red),
                                        label: const Text('Clear Node',
                                            style: TextStyle(color: AppColors.red, fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}