# DATA_MODEL_FIRESTORE

## Collezioni principali osservate
- `patients`
- `app_settings`
- `drive_pdf_imports`
- `doctor_patient_links`
- `families`
- `prescription_intakes`
- `parser_reference_values`
- `patient_therapeutic_advice`
- `dashboard_totals`
- `dashboard_summaries`
- `patient_dashboard_index`
- `phbox_runtime`
- `phbox_signals`

## Sottocollezioni sotto `patients/{fiscalCode}`
- `prescriptions`
- `advances`
- `debts`
- `bookings`

## Dati persistenti (e ownership)

### Frontend-managed (scrivibili da frontend)
- `patients/*` + subcollection (`prescriptions`, `advances`, `debts`, `bookings`)
- `families/*`
- `doctor_patient_links/*` (in particolare override manuale)
- `app_settings/main`
- `patient_therapeutic_advice/*`
- `prescription_intakes/*`
- `parser_reference_values/*`
- `patient_dashboard_index/*` (patch frontend managed)
- `dashboard_totals/main` (delta frontend managed)
- `phbox_signals/*`, `phbox_runtime/main` (best effort)

### Backend-owned (da contratto codice)
- `drive_pdf_imports/*`

## Vincoli chiave
- `patients` documentId = codice fiscale (normalizzato uppercase).
- `doctor_patient_links` usa convenzione id `CF__manual` / `CF__primary`.
- `patient_dashboard_index` include `searchPrefixes` per ricerca `arrayContains`.

## Punti che possono aumentare letture Firestore
- `collectionGroup` globali per `debts`, `advances`, `bookings`, `prescriptions`.
- `getCollection` senza `limit` su `drive_pdf_imports`.
- Refresh dashboard che carica molte sorgenti in parallelo.
- Query ripetute `arrayContains` su `families.memberFiscalCodes` in validazioni membri.

## Indici / materializzazioni
- `dashboard_totals/main` usato come snapshot rapido card dashboard.
- `patient_dashboard_index/*` usato per filtri flag e ricerca prefissi.
- `dashboard_summaries` presente ma non centrale nel flusso pagina dashboard corrente.

