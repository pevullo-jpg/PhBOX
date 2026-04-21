# Setup Firebase backend in FlutLab

## Obiettivo
Attivare login reale + trial remoto + stato accesso per utente senza Android Studio.

## Passi
1. Crea progetto Firebase.
2. Abilita Email/Password in Authentication.
3. Crea Cloud Firestore.
4. Copia le regole del file `docs/FIRESTORE_RULES_IT.txt` nella sezione Rules di Firestore.
5. Apri `lib/config/firebase_backend_config.dart` e incolla:
   - `apiKey`
   - `projectId`
6. Ricompila in FlutLab e testa sullo smartphone.

## Dati necessari
- `apiKey`: chiave Web API del progetto Firebase.
- `projectId`: ID progetto Firebase.

## Comportamento app
- senza config valida: schermata blocco setup backend
- con config valida: login reale Firebase REST
- primo login account nuovo: entitlement trial remoto di 3 mesi
- trial scaduto / no subscription: `read_only`
