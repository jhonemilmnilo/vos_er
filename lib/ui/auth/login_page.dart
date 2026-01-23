// lib/modules/auth/login_page.dart
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:connectivity_plus/connectivity_plus.dart";

import "../../app_providers.dart"; // authRepositoryProvider
import "../shell/shell.dart";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  bool _isOnline = false;
  StreamSubscription<dynamic>? _connSub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    _applyConnectivity(initial);
    _connSub = connectivity.onConnectivityChanged.listen(_applyConnectivity);
  }

  void _applyConnectivity(dynamic result) {
    bool online;
    if (result is List<ConnectivityResult>) {
      online = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      online = result != ConnectivityResult.none;
    } else {
      online = false;
    }

    if (!mounted) {
      _isOnline = online;
      return;
    }
    setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Shell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          _buildBackground(cs),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(cs, theme),
                    const SizedBox(height: 40),
                    _buildLoginCard(cs, theme),
                    const SizedBox(height: 24),
                    _onlineStatusFooter(cs, theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ColorScheme cs) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withOpacity(0.2),
              cs.surface,
              cs.secondaryContainer.withOpacity(0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme cs, ThemeData theme) {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              "assets/images/logo.jpg",
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Vertex",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Employee Relationship Management System",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(ColorScheme cs, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration("Email Address", Icons.email_outlined, cs),
              validator: (v) {
                final s = (v ?? "").trim();
                if (s.isEmpty) return "Email is required";
                if (!s.contains("@")) return "Enter a valid email";
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: _inputDecoration("Password", Icons.lock_outline_rounded, cs).copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                ),
              ),
              validator: (v) => (v ?? "").trim().isEmpty ? "Password is required" : null,
            ),
            if (_error != null) _buildErrorSection(cs),
            const SizedBox(height: 32),
            _buildLoginButton(cs),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: cs.surfaceContainerLow.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildErrorSection(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(ColorScheme cs) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: _loading ? null : _onLogin,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
              )
            : const Text(
                "Sign In",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _onlineStatusFooter(ColorScheme cs, ThemeData theme) {
    final statusColor = _isOnline ? Colors.green : Colors.orange;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          _isOnline ? "System Online" : "Offline Mode",
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}