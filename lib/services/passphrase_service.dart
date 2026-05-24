import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the GPG passphrase using Android Keystore-backed secure storage.
/// The passphrase is stored under a fixed key and survives app restarts,
/// but is wiped on uninstall.
class PassphraseService {
  static const _passphraseKey = 'gpg_passphrase';

  final FlutterSecureStorage _storage;

  PassphraseService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  /// Returns the stored passphrase, or null if none has been saved.
  Future<String?> getPassphrase() async {
    return _storage.read(key: _passphraseKey);
  }

  /// Saves a passphrase to secure storage.
  Future<void> savePassphrase(String passphrase) async {
    await _storage.write(key: _passphraseKey, value: passphrase);
  }

  /// Deletes the stored passphrase (e.g. if it turns out to be wrong).
  Future<void> clearPassphrase() async {
    await _storage.delete(key: _passphraseKey);
  }

  /// Returns true if a passphrase is currently stored.
  Future<bool> hasPassphrase() async {
    return await _storage.containsKey(key: _passphraseKey);
  }
}
