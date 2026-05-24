import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:openpgp/openpgp.dart';

class GpgException implements Exception {
  final String message;
  GpgException(this.message);

  @override
  String toString() => 'GpgException: $message';
}

class GpgService {
  Future<String> decryptFile(String filePath, String passphrase) async {
    final file = File(filePath);
    if (!await file.exists()) throw GpgException('File not found: $filePath');
    final bytes = await file.readAsBytes();
    return decryptBytes(bytes, passphrase);
  }

  Future<String> decryptBytes(Uint8List bytes, String passphrase) async {
    try {
      final result = await OpenPGP.decryptSymmetricBytes(bytes, passphrase);
      return utf8.decode(result);
    } catch (e) {
      throw GpgException('Decryption failed — wrong passphrase or corrupt file: $e');
    }
  }

  Future<void> encryptFile(
      String filePath, String plaintext, String passphrase) async {
    final encrypted = await encryptToBytes(plaintext, passphrase);
    await File(filePath).writeAsBytes(encrypted);
  }

  Future<Uint8List> encryptToBytes(String plaintext, String passphrase) async {
    try {
      final inputBytes = utf8.encode(plaintext);
      return await OpenPGP.encryptSymmetricBytes(
        Uint8List.fromList(inputBytes),
        passphrase,
      );
    } catch (e) {
      throw GpgException('Encryption failed: $e');
    }
  }
}
