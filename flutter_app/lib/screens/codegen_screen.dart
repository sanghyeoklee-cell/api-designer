import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class CodegenScreen extends StatefulWidget {
  final String sessionId;
  const CodegenScreen({super.key, required this.sessionId});

  @override
  State<CodegenScreen> createState() => _CodegenScreenState();
}

class _CodegenScreenState extends State<CodegenScreen> {
  String _selectedFile = '';
  final ScrollController _scrollController = ScrollController();
  int _lastContentLength = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollIfNeeded(String? content) {
    if (content == null) return;
    if (content.length != _lastContentLength) {
      _lastContentLength = content.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isStreaming = state.codegenStreaming;
    final files = isStreaming ? state.streamingFiles : state.generatedFiles;
    final fileOrder = isStreaming
        ? state.streamingFileOrder
        : state.generatedFiles.keys.toList();

    // Auto-select first file or follow current streaming file
    if (isStreaming && state.codegenCurrentFile != null) {
      if (_selectedFile != state.codegenCurrentFile) {
        _selectedFile = state.codegenCurrentFile!;
        _lastContentLength = 0;
      }
    } else if (_selectedFile.isEmpty && fileOrder.isNotEmpty) {
      _selectedFile = fileOrder.first;
    }

    final currentContent = files[_selectedFile];

    // Auto-scroll during streaming
    if (isStreaming) {
      _autoScrollIfNeeded(currentContent);
    }

    if (files.isEmpty && !isStreaming) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Column(
          children: [
            _header(context, isStreaming: false),
            const Expanded(
                child: Center(child: Text('No generated code'))),
          ],
        ),
      );
    }

    // Show waiting state when streaming just started but no files yet
    if (files.isEmpty && isStreaming) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Column(
          children: [
            _header(context, isStreaming: true),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'AI가 코드를 생성하고 있습니다...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          _header(context, isStreaming: isStreaming),
          Expanded(
            child: Row(
              children: [
                // File sidebar
                Container(
                  width: 200,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        right: BorderSide(color: Color(0xFFE5E5EA))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Text('FILES',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E93),
                                letterSpacing: 0.5)),
                      ),
                      ...fileOrder.map((f) => _FileTab(
                            filename: f,
                            selected: f == _selectedFile,
                            streaming:
                                isStreaming && f == state.codegenCurrentFile,
                            onTap: () {
                              setState(() {
                                _selectedFile = f;
                                _lastContentLength = 0;
                              });
                            },
                          )),
                    ],
                  ),
                ),

                // Code area
                Expanded(
                  child: Column(
                    children: [
                      // File tab bar
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E2E),
                        ),
                        child: Row(
                          children: [
                            Icon(_fileIcon(_selectedFile),
                                size: 14, color: const Color(0xFF8E8E93)),
                            const SizedBox(width: 8),
                            Text(_selectedFile,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.white70)),
                            if (isStreaming &&
                                _selectedFile == state.codegenCurrentFile) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  size: 14, color: Color(0xFF8E8E93)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: currentContent ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Copied'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    backgroundColor: Colors.grey[800],
                                    duration:
                                        const Duration(milliseconds: 800),
                                  ),
                                );
                              },
                              tooltip: 'Copy',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ),
                      // Code content with auto-scroll
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFF1E1E2E),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              currentContent ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                height: 1.6,
                                color: Color(0xFFD4D4D8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, {required bool isStreaming}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
            style:
                IconButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 4),
          const Text('Generated API Server',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text('Generating...',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED))),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 13, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text('Generated',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.py')) return Icons.code;
    if (name.endsWith('.txt')) return Icons.description;
    if (name.endsWith('.md')) return Icons.article;
    return Icons.insert_drive_file;
  }
}

class _FileTab extends StatelessWidget {
  final String filename;
  final bool selected;
  final bool streaming;
  final VoidCallback onTap;
  const _FileTab({
    required this.filename,
    required this.selected,
    required this.streaming,
    required this.onTap,
  });

  IconData get _icon {
    if (filename.endsWith('.py')) return Icons.code;
    if (filename.endsWith('.txt')) return Icons.description;
    if (filename.endsWith('.md')) return Icons.article;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: selected ? const Color(0xFFF0F4FF) : null,
        child: Row(
          children: [
            Icon(_icon,
                size: 15,
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF8E8E93)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filename,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF3C3C43),
                ),
              ),
            ),
            if (streaming)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF7C3AED),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
