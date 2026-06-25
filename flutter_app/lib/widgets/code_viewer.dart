import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeViewer extends StatelessWidget {
  final String code;
  final String filename;

  const CodeViewer({super.key, required this.code, this.filename = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filename.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(_fileIcon(filename), color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  filename,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: filename.isNotEmpty
                ? const BorderRadius.vertical(bottom: Radius.circular(8))
                : BorderRadius.circular(8),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.py')) return Icons.code;
    if (name.endsWith('.txt')) return Icons.description;
    if (name.endsWith('.md')) return Icons.article;
    return Icons.insert_drive_file;
  }
}
