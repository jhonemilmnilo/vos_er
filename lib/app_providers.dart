// lib/app_providers.dart
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/auth/auth_storage.dart";
import "core/network/api_client.dart";
import "data/repositories/auth_repository.dart";
import "state/host_provider.dart";

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage();
});

/// IMPORTANT: single shared ApiClient instance for the whole app
final apiClientProvider = Provider<ApiClient>((ref) {
  final selectedDepartment = ref.watch(hostProvider);
  if (selectedDepartment == null) {
    throw Exception("No department selected. Please select a department first.");
  }
  final baseUrl = selectedDepartment.baseUrl;
  final token = selectedDepartment.token;
  // ApiClient with department-specific token for Directus access (empty token for servers that don't require it)
  return ApiClient(baseUrl: baseUrl, token: token.isNotEmpty ? token : null);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.read(authStorageProvider);
  return AuthRepository(api, storage);
});

/// Used by the AuthGate to restore token + user_id on app start
final authInitProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  return auth.restoreSession();
});
