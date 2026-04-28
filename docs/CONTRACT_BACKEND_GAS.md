# CONTRACT_BACKEND_GAS

## Stato attuale nel repository
- Non sono presenti file Google Apps Script (`.gs`) o endpoint GAS.
- Non è possibile documentare API GAS con certezza dal solo codice corrente.

## Elementi che suggeriscono un backend esterno
- `drive_pdf_imports` marcata “backend-owned”.
- Presenza di code/segnali runtime (`phbox_signals`, `phbox_runtime`).
- Nota operativa su rebuild indice nel backend (`rebuildPhboxPatientDashboardIndex()`).

## Contratto minimo deducibile con GAS (o backend equivalente)

### Input attesi dal backend
1. Documenti Firestore scritti dal frontend su:
   - `phbox_signals/*`
   - `phbox_runtime/main`
2. Mutazioni utente su:
   - `patients/*/debts/*`, `advances`, `bookings`
   - richieste cancellazione PDF in `drive_pdf_imports/*` (`deletePdfRequested=true`).

### Output attesi dal backend
- Aggiornamento `dashboard_totals/main`.
- Aggiornamento `patient_dashboard_index/*`.
- Gestione stato archivio `drive_pdf_imports/*` (incluso delete fisico PDF in Drive): **DA VERIFICARE**.

## Contratti NON verificabili dal repo
- Endpoint HTTP GAS, payload REST, autenticazione.
- Trigger (time-driven / onWrite) e retry policy.
- Idempotenza e dead-letter handling.

Tutti questi punti: **DA VERIFICARE**.

