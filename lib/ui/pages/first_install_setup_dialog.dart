import 'package:flutter/material.dart';

Future<List<String>> showFirstInstallSetupDialog(BuildContext context) async {
  final result = await showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _FirstInstallSetupDialog(),
  );

  return result ?? const [];
}

class _FirstInstallSetupDialog extends StatefulWidget {
  const _FirstInstallSetupDialog();

  @override
  State<_FirstInstallSetupDialog> createState() =>
      _FirstInstallSetupDialogState();
}

class _FirstInstallSetupDialogState extends State<_FirstInstallSetupDialog> {
  final TextEditingController _membersCtrl = TextEditingController();

  @override
  void dispose() {
    _membersCtrl.dispose();
    super.dispose();
  }

  List<String> _parseMembers() {
    final raw = _membersCtrl.text;
    final tokens = raw
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final result = <String>[];

    for (final token in tokens) {
      final key = token.toLowerCase();
      if (seen.add(key)) {
        result.add(token);
      }
    }

    return result;
  }

  void _submit() {
    Navigator.of(context).pop(_parseMembers());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E0A3E),
      title: const Text(
        'Configurazione iniziale',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La struttura base dei box verrà creata automaticamente: RISPARMI, NECESSITÀ, ABBONAMENTI e NECESSITÀ ANNUALI.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Inserisci ora i componenti della famiglia, uno per riga o separati da virgola, per creare i box personali iniziali.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _membersCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Es.\nGiuseppe\nAlessia\nEmma',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Puoi saltare ora e aggiungerli dopo dalle impostazioni.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const <String>[]),
          child: const Text('Salta'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
