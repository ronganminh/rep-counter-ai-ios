import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal key-value secret store, so tests can run without the platform
/// keychain.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// iOS Keychain / Android Keystore-backed storage (flutter_secure_storage).
class PlatformSecretStore implements SecretStore {
  const PlatformSecretStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps the Supabase session (access + refresh token) in the keychain
/// instead of SharedPreferences. Tokens are never logged.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this.store);
  final SecretStore store;

  static const key = 'repcoach.auth.session';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => (await store.read(key)) != null;
  @override
  Future<String?> accessToken() => store.read(key);
  @override
  Future<void> removePersistedSession() => store.delete(key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      store.write(key, persistSessionString);
}

/// PKCE code verifiers for email links, also in the keychain.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage(this.store);
  final SecretStore store;

  static const prefix = 'repcoach.auth.pkce.';

  @override
  Future<String?> getItem({required String key}) => store.read('$prefix$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      store.write('$prefix$key', value);
  @override
  Future<void> removeItem({required String key}) => store.delete('$prefix$key');
}
