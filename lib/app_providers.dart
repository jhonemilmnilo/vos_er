// lib/app_providers.dart
import "package:flutter_riverpod/flutter_riverpod.dart";
import 'package:shared_preferences/shared_preferences.dart';

import "core/auth/auth_storage.dart";
import "core/network/api_client.dart";
import "data/repositories/auth_repository.dart";

/// Change this if needed (or make it configurable later)
const String kBaseUrl = "http://192.168.0.143:8091";
enum Branch {
  branch1(8090, "Branch 1"),
  branch2(8091, "Branch 2"),
  branch3(8092, "Branch 3");

  final int port;
  final String label;
  const Branch(this.port, this.label);

  String get baseUrl => "http://192.168.0.143:$port";
}

class BranchNotifier extends StateNotifier<Branch> {
  BranchNotifier() : super(Branch.branch2) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final port = prefs.getInt('selected_branch_port');
    if (port != null) {
      state = Branch.values.firstWhere(
        (b) => b.port == port,
        orElse: () => Branch.branch2,
      );
    }
  }

  Future<void> setBranch(Branch branch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_branch_port', branch.port);
    state = branch;
  }
}

final branchProvider = StateNotifierProvider<BranchNotifier, Branch>((ref) {
  return BranchNotifier();
});

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage();
});

/// IMPORTANT: single shared ApiClient instance for the whole app
final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(baseUrl: kBaseUrl);
  final branch = ref.watch(branchProvider);
  final api = ApiClient(baseUrl: branch.baseUrl);
  return api;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.read(apiClientProvider);
  final api = ref.watch(apiClientProvider);
  final storage = ref.read(authStorageProvider);
  return AuthRepository(api, storage);
});

/// Used by the AuthGate to restore token + user_id on app start
final authInitProvider = FutureProvider<bool>((ref) async {
  final auth = ref.read(authRepositoryProvider);
  final auth = ref.watch(authRepositoryProvider);
  return auth.restoreSession();
});
