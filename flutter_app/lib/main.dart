import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/project_list_screen.dart';
import 'screens/shell.dart';
import 'services/app_state.dart';

void main() {
  runApp(const ApiStudioApp());
}

class ApiStudioApp extends StatelessWidget {
  const ApiStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'API Designer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5),
            brightness: Brightness.light,
            surface: const Color(0xFFFAFAFA),
            onSurface: const Color(0xFF1E1E2E),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F5F7),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE5E5EA)),
            ),
            color: Colors.white,
          ),
          dividerColor: const Color(0xFFE5E5EA),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            isDense: true,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Color(0xFF1E1E2E)),
            titleMedium: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1E1E2E)),
            bodyMedium:
                TextStyle(fontSize: 13.5, color: Color(0xFF3C3C43)),
            bodySmall: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            labelLarge:
                TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
          ),
        ),
        home: const _RootNavigator(),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startBackend();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<ui.AppExitResponse> didRequestAppExit() async {
    final state = context.read<AppState>();

    // If nothing is running, exit immediately
    if (!state.backendConnected && !state.browserRunning) {
      return ui.AppExitResponse.exit;
    }

    // Show shutdown dialog
    if (mounted) {
      await _showShutdownDialog(context, state);
    }
    return ui.AppExitResponse.exit;
  }

  Future<void> _showShutdownDialog(BuildContext context, AppState state) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ShutdownDialog(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.activeProjectId != null) {
      return const AppShell();
    }

    return const ProjectListScreen();
  }
}

class _ShutdownDialog extends StatefulWidget {
  final AppState state;
  const _ShutdownDialog({required this.state});

  @override
  State<_ShutdownDialog> createState() => _ShutdownDialogState();
}

class _ShutdownDialogState extends State<_ShutdownDialog> {
  final List<_ShutdownStep> _steps = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _runShutdown();
  }

  Future<void> _runShutdown() async {
    final state = widget.state;

    // Step 1: Browser
    if (state.browserRunning) {
      setState(() {
        _steps.add(_ShutdownStep('Closing Chromium browser...', StepState.running));
      });
      try {
        await state.api.closeBrowser();
        state.browserRunning = false;
        setState(() {
          _steps.last.state = StepState.done;
        });
      } catch (_) {
        setState(() {
          _steps.last.state = StepState.error;
        });
      }
    }

    // Step 2: Backend
    if (state.python.isRunning) {
      setState(() {
        _steps.add(_ShutdownStep('Stopping backend server...', StepState.running));
      });
      await state.python.stop();
      setState(() {
        _steps.last.state = StepState.done;
      });
    }

    // Done
    setState(() {
      _done = true;
    });

    // Auto-close after brief delay so user can see the result
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pop();
    }
    // Force exit the app
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _done ? Icons.check_circle : Icons.power_settings_new,
                    color: _done
                        ? const Color(0xFF059669)
                        : const Color(0xFF4F46E5),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _done ? 'Shutdown Complete' : 'Shutting Down...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Steps list
              ...List.generate(_steps.length, (i) {
                final step = _steps[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      if (step.state == StepState.running)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4F46E5),
                          ),
                        )
                      else if (step.state == StepState.done)
                        const Icon(Icons.check_circle,
                            size: 16, color: Color(0xFF059669))
                      else
                        const Icon(Icons.error,
                            size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: step.state == StepState.done
                              ? const Color(0xFF059669)
                              : step.state == StepState.error
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF3C3C43),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_steps.isEmpty)
                const Text(
                  'No active services to stop.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StepState { running, done, error }

class _ShutdownStep {
  final String label;
  StepState state;
  _ShutdownStep(this.label, this.state);
}
