import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/gpg_service.dart';
import '../services/passphrase_service.dart';
import '../widgets/passphrase_dialog.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _gpgService = GpgService();
  final _passphraseService = PassphraseService();
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _handleIncomingIntents();
  }

  /// Handles files shared/opened while the app is already running.
  void _handleIncomingIntents() {
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _openSharedFile(files.first.path);
      },
      onError: (err) => _setStatus('Intent error: $err'),
    );

    // Handles the intent that launched the app cold.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _openSharedFile(files.first.path);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  /// Main entry point: given a file path (or null for picker), decrypt and open.
  Future<void> _openSharedFile(String? filePath) async {
    filePath ??= await _pickFile();
    if (filePath == null) return;

    if (!filePath.toLowerCase().endsWith('.gpg')) {
      _setStatus('Not a .gpg file: $filePath');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      await _decryptAndOpen(filePath);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpg'],
    );
    return result?.files.single.path;
  }

  Future<void> _decryptAndOpen(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Try stored passphrase first.
    String? storedPassphrase = await _passphraseService.getPassphrase();
    if (storedPassphrase != null) {
      final plaintext = await _tryDecrypt(bytes, storedPassphrase);
      if (plaintext != null) {
        return _openEditor(filePath, plaintext, storedPassphrase);
      }
      // Stored passphrase didn't work — fall through to prompt.
      await _passphraseService.clearPassphrase();
    }

    // Prompt the user.
    String? errorMessage;
    while (true) {
      if (!mounted) return;
      final result = await showPassphraseDialog(
        context,
        offerSave: true,
        errorMessage: errorMessage,
      );
      if (result == null) return; // User cancelled.

      try {
        final plaintext =
          await _gpgService.decryptBytes(bytes, result.passphrase);
        if (result.save) {
          await _passphraseService.savePassphrase(result.passphrase);
        }
        return _openEditor(filePath, plaintext, result.passphrase);
      } on GpgException catch (e) {
        errorMessage = e.toString();
      }
    }
  }

  /// Returns decrypted text, or null if the passphrase was wrong.
  Future<String?> _tryDecrypt(Uint8List bytes, String passphrase) async {
    try {
      return await _gpgService.decryptBytes(bytes, passphrase);
    } on GpgException {
      return null;
    }
  }

  void _openEditor(String filePath, String content, String passphrase) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          filePath: filePath,
          initialContent: _expandTabs(content),
          passphrase: passphrase,
        ),
      ),
    );
  }

  String _expandTabs(String text) {
    final buffer = StringBuffer();
    int col = 0;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\t') {
        final spaces = 8 - (col % 8);
        buffer.write(' ' * spaces);
        col += spaces;
      } else {
        buffer.write(ch);
        if (ch == '\n') col = 0; else col++;
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPG Editor')),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Decrypting…'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Open a .gpg file from Material Files,\nor pick one below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Pick a .gpg file'),
                    onPressed: () => _openSharedFile(null),
                  ),
                ],
              ),
      ),
    );
  }
}
