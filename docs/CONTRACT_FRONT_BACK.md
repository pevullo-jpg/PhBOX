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

### Scritture frontend limitate per contratto su `drive_pdf_imports`
- Il frontend non deve creare record import/archive in `drive_pdf_imports`.
- Il frontend non deve eseguire write stile `saveImport()` (`saveImport()` lancia `UnsupportedError`).
- Il frontend non deve scrivere parser/OCR metadata, merge metadata, rename metadata, archive mutation o lifecycle fields backend-owned.
- Il frontend può emettere solo patch limitate di richiesta eliminazione tramite `DrivePdfImportsRepository.requestPdfDelete()`, usando i campi delete-request previsti.
- Il backend resta proprietario di eliminazione reale, mutazioni Drive, archive lifecycle e final state transition.

## Confine Frontend ↔ Backend (non presente nel repo)
Il frontend assume implicitamente un backend che:
- gestisce pipeline archivistica su `drive_pdf_imports`,
- consuma segnali runtime,
- riallinea aggregati dashboard/index.

Il repository può contenere servizi frontend collegati a Gmail/Drive, ma la pipeline operativa completa Gmail/Drive/PDF può dipendere da backend GAS esterno.
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
