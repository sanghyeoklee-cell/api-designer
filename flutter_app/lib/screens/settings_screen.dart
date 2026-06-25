import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  String? _selectedModel;
  bool _apiKeyObscured = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _selectedModel = state.claudeModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E2E),
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: API Key
                    _SectionHeader(
                      title: 'Anthropic API Key',
                      trailing: _StatusPill(
                        isActive: state.apiKeySet,
                        activeText: 'Configured',
                        inactiveText: 'Not set',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.apiKeySet &&
                              state.apiKeyMasked.isNotEmpty) ...[
                            Row(
                              children: [
                                const Text('Current key',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8E8E93))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.apiKeyMasked,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _apiKeyObscured,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'sk-ant-api03-...',
                              labelText: state.apiKeySet
                                  ? 'New API key'
                                  : 'API key',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _apiKeyObscured
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: const Color(0xFF8E8E93),
                                ),
                                onPressed: () => setState(
                                    () => _apiKeyObscured = !_apiKeyObscured),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Stored locally in backend/storage/settings.json. '
                            'Only sent to the Anthropic API.',
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFFA1A1AA)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section: Model
                    const _SectionHeader(title: 'Claude Model'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Column(
                        children: [
                          if (state.availableModels.isNotEmpty)
                            ...state.availableModels
                                .asMap()
                                .entries
                                .map((entry) {
                              final model = entry.value;
                              final isLast = entry.key ==
                                  state.availableModels.length - 1;
                              return Column(
                                children: [
                                  _ModelOption(
                                    model: model,
                                    description: _modelDesc(model),
                                    selected: _selectedModel == model,
                                    onTap: () => setState(
                                        () => _selectedModel = model),
                                  ),
                                  if (!isLast)
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFE5E5EA)),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Save button
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),

                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modelDesc(String model) {
    if (model.contains('opus')) return 'Most capable. Best for complex analysis.';
    if (model.contains('sonnet')) return 'Balanced speed and quality. Recommended.';
    if (model.contains('haiku')) return 'Fastest responses. Good for simple tasks.';
    return '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final newKey = _apiKeyController.text.trim().isNotEmpty
        ? _apiKeyController.text.trim()
        : null;
    final newModel =
        _selectedModel != state.claudeModel ? _selectedModel : null;

    if (newKey == null && newModel == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    await state.updateSettings(apiKey: newKey, model: newModel);
    setState(() => _saving = false);

    if (state.error == null && mounted) {
      _apiKeyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.3,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  final String activeText;
  final String inactiveText;
  const _StatusPill({
    required this.isActive,
    required this.activeText,
    required this.inactiveText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? activeText : inactiveText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      ),
    );
  }
}

class _ModelOption extends StatelessWidget {
  final String model;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  const _ModelOption({
    required this.model,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFFD1D1D6),
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF1E1E2E),
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8E8E93)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
