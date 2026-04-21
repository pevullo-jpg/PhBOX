import 'package:flutter/material.dart';

Future<void> showReadOnlyBlockedDialog(
  BuildContext context, {
  String action = 'Questa azione',
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Modalità sola lettura'),
        content: Text(
          "$action è bloccata. Con trial o abbonamento scaduti l'app resta consultabile, ma non permette modifiche.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    },
  );
}
