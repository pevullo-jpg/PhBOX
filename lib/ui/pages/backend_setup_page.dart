import 'package:flutter/material.dart';

import 'package:family_boxes_2/config/firebase_backend_config.dart';

class BackendSetupPage extends StatelessWidget {
  const BackendSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0A3E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF3D2966)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud_sync_rounded, size: 56, color: Color(0xFFE91E8C)),
                    const SizedBox(height: 16),
                    const Text(
                      'Configura Firebase backend',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Per login reale, trial remoto e stato accesso per utente, Family Box ora richiede un progetto Firebase configurato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    _step('1', 'In Firebase abilita Email/Password in Authentication.'),
                    _step('2', 'In Firestore crea il database in modalità Production o Test.'),
                    _step('3', 'Apri lib/config/firebase_backend_config.dart in FlutLab.'),
                    _step('4', 'Incolla apiKey e projectId del tuo progetto.'),
                    _step('5', 'Applica le regole Firestore del file docs/FIRESTORE_RULES_IT.txt.'),
                    const SizedBox(height: 20),
                    const Text(
                      'Stato attuale file config:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'apiKey: ${FirebaseBackendConfig.apiKey}',
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'projectId: ${FirebaseBackendConfig.projectId}',
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Finché questi placeholder restano invariati, l’app non apre il login reale.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE91E8C),
              shape: BoxShape.circle,
            ),
            child: Text(number, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
