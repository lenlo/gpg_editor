import 'package:flutter/material.dart';
import '../services/gpg_service.dart';
import '../services/passphrase_service.dart';
import '../widgets/passphrase_dialog.dart';

class EditorScreen extends StatefulWidget {
  final String filePath;
  final String initialContent;
  final String passphrase;

  const EditorScreen({
    super.key,
    required this.filePath,
    required this.initialContent,
    required this.passphrase,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _controller;
  late String _passphrase;
  final _gpgService = GpgService();
  final _passphraseService = PassphraseService();
  bool _isDirty = false;
  bool _isSaving = false;
  double _fontSize = 14.0;
  static const double _minFontSize = 10.0;
  static const double _maxFontSize = 24.0;

  @override
  void initState() {
    super.initState();
    _passphrase = widget.passphrase;
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      if (!_isDirty) setState(() => _isDirty = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _fileName => widget.filePath.split('/').last;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _gpgService.encryptFile(
        widget.filePath,
        _controller.text,
        _passphrase,
      );
      setState(() => _isDirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved and encrypted.')),
        );
      }
    } on GpgException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassphrase() async {
    final result = await showPassphraseDialog(
      context,
      offerSave: true,
      errorMessage: null,
    );
    if (result == null) return;
    setState(() => _passphrase = result.passphrase);
    if (result.save) {
      await _passphraseService.savePassphrase(result.passphrase);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passphrase updated. Save the file to apply it.'),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Discard changes and close?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isDirty ? '$_fileName •' : _fileName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.text_decrease),
              tooltip: 'Smaller text',
              onPressed: _fontSize > _minFontSize
              ? () => setState(() => _fontSize -= 1.0)
              : null,
            ),
            IconButton(
              icon: const Icon(Icons.text_increase),
              tooltip: 'Larger text',
              onPressed: _fontSize < _maxFontSize
              ? () => setState(() => _fontSize += 1.0)
              : null,
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save (encrypted)',
                onPressed: _isDirty ? _save : null,
              ),
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'change_passphrase',
                  child: Text('Change passphrase'),
                ),
                const PopupMenuItem(
                  value: 'clear_passphrase',
                  child: Text('Forget saved passphrase'),
                ),
              ],
              onSelected: (value) async {
                switch (value) {
                  case 'change_passphrase':
                    await _changePassphrase();
                  case 'clear_passphrase':
                    await _passphraseService.clearPassphrase();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passphrase forgotten.')),
                      );
                    }
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontFamily: 'monospace', fontSize: _fontSize),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start typing…',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
