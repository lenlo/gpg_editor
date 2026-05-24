import 'package:flutter/material.dart';

/// A dialog that prompts the user for their GPG passphrase.
/// Returns the passphrase string, or null if cancelled.
/// [offerSave] controls whether the "remember passphrase" checkbox is shown.
class PassphraseDialog extends StatefulWidget {
  final bool offerSave;
  final String? errorMessage;

  const PassphraseDialog({
    super.key,
    this.offerSave = true,
    this.errorMessage,
  });

  @override
  State<PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<PassphraseDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _save = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final passphrase = _controller.text.trim();
    if (passphrase.isEmpty) return;
    Navigator.of(context).pop(PassphraseResult(
      passphrase: passphrase,
      save: widget.offerSave && _save,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Passphrase'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.errorMessage != null) ...[
            Text(
              widget.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.offerSave) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? true),
              title: const Text('Remember passphrase'),
              subtitle: const Text('Stored securely in Android Keystore'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Decrypt'),
        ),
      ],
    );
  }
}

class PassphraseResult {
  final String passphrase;
  final bool save;
  PassphraseResult({required this.passphrase, required this.save});
}

/// Convenience function to show the passphrase dialog.
/// Returns null if cancelled.
Future<PassphraseResult?> showPassphraseDialog(
  BuildContext context, {
  bool offerSave = true,
  String? errorMessage,
}) {
  return showDialog<PassphraseResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PassphraseDialog(
      offerSave: offerSave,
      errorMessage: errorMessage,
    ),
  );
}
