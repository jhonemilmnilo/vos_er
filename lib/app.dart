// lib/app.dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app_providers.dart"; // Import providers from app_providers.dart
import "core/theme/app_theme.dart";
import "state/host_provider.dart";
import "ui/auth/host_selection_page.dart";
import "ui/auth/login_page.dart";
import "ui/shell/shell.dart";

// -------------------------
// App
// -------------------------

class VOSApp extends StatelessWidget {
  const VOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "VOS Mobile",
      themeMode: ThemeMode.system,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

// app.dart (AuthGate part only)
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDepartment = ref.watch(hostProvider);
    if (selectedDepartment == null) {
      return const HostSelectionPage();
    }

    return FutureBuilder<bool>(
      future: ref.read(authRepositoryProvider).restoreSession(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final ok = snap.data ?? false;
        return ok ? const Shell() : const LoginPage();
      },
    );
  }
}
