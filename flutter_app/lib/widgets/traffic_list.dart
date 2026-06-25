import 'package:flutter/material.dart';
import '../models/traffic_entry.dart';

class TrafficList extends StatelessWidget {
  final List<TrafficEntry> entries;
  final void Function(TrafficEntry)? onTap;

  const TrafficList({super.key, required this.entries, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.swap_vert,
                  size: 24, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 14),
            const Text('No traffic captured',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            const Text('Interact with the browser to see requests here.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return _TrafficRow(
          entry: entry,
          onTap: onTap != null ? () => onTap!(entry) : null,
          isEven: index.isEven,
        );
      },
    );
  }
}

class _TrafficRow extends StatelessWidget {
  final TrafficEntry entry;
  final VoidCallback? onTap;
  final bool isEven;

  const _TrafficRow({
    required this.entry,
    this.onTap,
    required this.isEven,
  });

  Color _methodColor(String m) {
    switch (m.toUpperCase()) {
      case 'GET':
        return const Color(0xFF2563EB);
      case 'POST':
        return const Color(0xFF059669);
      case 'PUT':
        return const Color(0xFFF59E0B);
      case 'DELETE':
        return const Color(0xFFDC2626);
      case 'PATCH':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statusColor(int s) {
    if (s >= 200 && s < 300) return const Color(0xFF059669);
    if (s >= 300 && s < 400) return const Color(0xFFF59E0B);
    if (s >= 400) return const Color(0xFFDC2626);
    return const Color(0xFF9CA3AF);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isEven ? Colors.white : const Color(0xFFF9FAFB),
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            // Method
            SizedBox(
              width: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: _methodColor(entry.requestMethod).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.requestMethod,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _methodColor(entry.requestMethod),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Status
            SizedBox(
              width: 32,
              child: Text(
                '${entry.responseStatus}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(entry.responseStatus),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // URL
            Expanded(
              child: Text(
                entry.shortUrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF3C3C43),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Duration
            SizedBox(
              width: 56,
              child: Text(
                '${entry.durationMs.toStringAsFixed(0)} ms',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
