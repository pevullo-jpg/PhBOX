# CONTRACT_BACKEND_GAS

## Stato attuale nel repository
- Non sono presenti file Google Apps Script (`.gs`) o endpoint GAS.
- Non è possibile documentare API GAS con certezza dal solo codice corrente.

## Elementi che suggeriscono un backend esterno
- `drive_pdf_imports` marcata “backend-owned”.
- Presenza di code/segnali runtime (`phbox_signals`, `phbox_runtime`).
- Nota operativa su rebuild indice nel backend (`rebuildPhboxPatientDashboardIndex()`).
- Il repository può includere servizi frontend collegati a Gmail/Drive, ma non prova proprietà frontend dell'intera pipeline operativa Gmail/Drive/PDF.

## Contratto minimo deducibile con GAS (o backend equivalente)

### Input attesi dal backend
1. Documenti Firestore scritti dal frontend su:
   - `phbox_signals/*`
   - `phbox_runtime/main`
2. Mutazioni utente su:
   - `patients/*/debts/*`, `advances`, `bookings`
   - patch limitate di richiesta cancellazione PDF in `drive_pdf_imports/*` (`deletePdfRequested=true` e campi delete-request previsti).

### Output attesi dal backend
- Aggiornamento `dashboard_totals/main`.
- Aggiornamento `patient_dashboard_index/*`.
- Gestione stato archivio `drive_pdf_imports/*` (inclusi metadata parser/OCR, metadata merge/rename, archive mutation, lifecycle fields backend-owned e delete fisico PDF in Drive): **DA VERIFICARE**.

## Contratti NON verificabili dal repo
- Endpoint HTTP GAS, payload REST, autenticazione.
- Trigger (time-driven / onWrite) e retry policy.
- Idempotenza e dead-letter handling.
- Dettaglio operativo end-to-end Gmail/Drive/PDF pipeline senza codice backend reale.

Tutti questi punti: **DA VERIFICARE**.
