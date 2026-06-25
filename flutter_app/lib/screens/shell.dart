import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/python_service.dart';
import 'home_screen.dart';
import 'manual_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = [
      const ManualScreen(),
      const HomeScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2E),
              border: Border(
                  right: BorderSide(color: Color(0xFF2D2D3F))),
            ),
            child: Column(
              children: [
                // Project header with back button
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Back to projects
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => state.leaveProject(),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.arrow_back,
                                color: Color(0xFF8E8E93), size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.activeProjectName ?? 'Project',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'API Designer',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2D2D3F), height: 1),
                const SizedBox(height: 8),

                // Nav items
                _NavItem(
                  icon: Icons.touch_app_outlined,
                  activeIcon: Icons.touch_app,
                  label: 'Record',
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'History',
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  selected: _selectedIndex == 2,
                  badge: !state.apiKeySet,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),

                const Spacer(),

                // Backend status
                const Divider(color: Color(0xFF2D2D3F), height: 1),
                _BackendStatus(state: state),
              ],
            ),
          ),

          // Main content
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    this.badge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF2D2D3F) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: const Color(0xFF2D2D3F),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF8E8E93),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.white : const Color(0xFFA1A1AA),
                  ),
                ),
                if (badge) ...[
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendStatus extends StatelessWidget {
  final AppState state;

  const _BackendStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final python = state.python;
    final Color dotColor;
    final String label;

    if (state.backendConnected) {
      dotColor = const Color(0xFF34D399);
      label = 'Backend running';
    } else if (python.status == PythonStatus.starting) {
      dotColor = const Color(0xFFFBBF24);
      label = 'Starting...';
    } else if (python.status == PythonStatus.error) {
      dotColor = const Color(0xFFEF4444);
      label = 'Error';
    } else {
      dotColor = const Color(0xFF6B7280);
      label = 'Offline';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: dotColor,
              ),
            ),
          ),
          if (!state.backendConnected &&
              python.status != PythonStatus.starting)
            GestureDetector(
              onTap: () => state.startBackend(),
              child: const Icon(Icons.refresh,
                  size: 14, color: Color(0xFF8E8E93)),
            ),
        ],
      ),
    );
  }
}
