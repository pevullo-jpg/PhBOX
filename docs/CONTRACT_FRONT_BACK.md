# CONTRACT_FRONT_BACK

## Scopo
Definire il contratto osservabile tra frontend Flutter e backend dati/eventi.

## Confine Frontend ↔ Firestore
Il frontend legge/scrive Firestore tramite repository.

### Scritture frontend esplicite
- `patients` (creazione/patch/migrazione profilo).
- Subcollection paziente: `debts`, `advances`, `bookings`, `prescriptions`.
- `families`, `doctor_patient_links`, `app_settings`, `patient_therapeutic_advice`.
- `phbox_signals`, `phbox_runtime` (best-effort runtime signal).
- `patient_dashboard_index` patch “frontend managed”.
- `dashboard_totals/main` delta “frontend managed” (solo alcuni campi).

### Scritture frontend vietate per contratto
- `drive_pdf_imports`: `saveImport()` lancia `UnsupportedError` (backend-owned).

## Confine Frontend ↔ Backend (non presente nel repo)
Il frontend assume implicitamente un backend che:
- gestisce pipeline archivistica su `drive_pdf_imports`,
- consuma segnali runtime,
- riallinea aggregati dashboard/index.

Dettagli implementativi backend: **DA VERIFICARE**.

## Event contract: `phbox_signals`
Campi inviati dal frontend:
- `signalId`, `status=pending`, `domain`, `operation`,
- `targetPath`, `targetFiscalCode`, `targetDocumentId`,
- `requiresTotalsUpdate`, `requiresIndexUpdate`,
- `createdAt`, `updatedAt`, `processedAt`, `attempts`, `lastError`.

Il frontend non garantisce consegna: usa `emitBestEffort()`.

## Contratto di consistenza (best effort)
- Salvataggio dato utente deve riuscire anche se segnale runtime fallisce.
- Quindi possibili finestre di inconsistenza su totali/index finché backend non riallinea.

## Rischi regressione
- Cambiare nomi campi segnale rompe consumer backend.
- Cambiare semantica di `requiresTotalsUpdate/requiresIndexUpdate` altera riallineamenti.
- Rimozione patch frontend su index/totals può peggiorare UX realtime.

