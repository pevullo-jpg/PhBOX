# ARCHITECTURE

## Obiettivo
Questo documento descrive l'architettura osservabile dal codice del repository, senza assumere componenti non presenti.

## Componenti e confini

### Frontend (Flutter)
- Applicazione Flutter con entrypoint `lib/main.dart` e shell `lib/app.dart`.
- Pagine principali: Dashboard, Famiglie, Impostazioni.
- Accesso dati via repository che usano `FirestoreDatasource`.
- Accesso diretto API Google Drive/Gmail via servizi HTTP nel frontend.

### Firestore
- È il datastore primario usato dal frontend.
- Accesso astratto tramite `FirestoreDatasource` e implementazione concreta `FirestoreFirebaseDatasource`.
- Collezioni canoniche in `AppCollections`.

### Backend GAS (Google Apps Script)
- **DA VERIFICARE**: nel repository non ci sono file `.gs` o endpoint GAS.
- Dal codice è però evidente una separazione “backend-owned” su `drive_pdf_imports` e sui segnali runtime (`phbox_signals`, `phbox_runtime`).

### Superback
- **DA VERIFICARE**: nel repository non compaiono riferimenti espliciti a un servizio chiamato “Superback”.
- Possibile ruolo dedotto: orchestrazione backend per lavorazioni asincrone (totali/indici/cancellazioni PDF) a valle di segnali runtime.

### Gmail e Drive
- Il repository contiene servizi frontend che chiamano Gmail API (`gmail.googleapis.com`) e Drive API (`www.googleapis.com/drive/v3/...`).
- OAuth scope richiesti nel frontend: Drive e Gmail modify.
- La pipeline operativa completa Gmail/Drive/PDF può dipendere da backend GAS esterno: dettagli runtime end-to-end **DA VERIFICARE** se il backend non è nel repository.

## Flussi principali

### Flusso consultazione dashboard
1. Frontend legge `dashboard_totals/main` in listener.
2. Frontend interroga `patient_dashboard_index` per filtri/ricerca.
3. In fallback o per dati dettaglio, legge anche collezioni storiche (`patients`, subcollection, `drive_pdf_imports`, ecc.).

### Flusso modifica dati operativi (debiti/anticipi/prenotazioni)
1. Frontend salva su subcollection del paziente.
2. Frontend emette segnale runtime best-effort in `phbox_signals` + update `phbox_runtime/main`.
3. Backend esterno (non presente nel repo) dovrebbe riallineare aggregati (totali/indice).

### Flusso PDF da Gmail/Drive
- Esistono servizi per:
  - scansione email con allegati PDF,
  - upload file su Drive,
  - parsing testo PDF,
  - richieste su archivio `drive_pdf_imports` con confini di ownership.
- Contratto su `drive_pdf_imports`:
  - il frontend non deve creare record import/archive;
  - il frontend non deve eseguire write stile `saveImport()`;
  - il frontend non deve scrivere metadata parser/OCR, metadata merge/rename, archive mutation o lifecycle fields backend-owned;
  - il frontend può emettere solo patch limitate di richiesta eliminazione via `DrivePdfImportsRepository.requestPdfDelete()` usando i campi delete-request previsti;
  - il backend resta proprietario di eliminazione reale, mutazioni Drive, archive lifecycle e final state transition.
- Impatto: senza backend esterno reale/allegato aggiornato, i dettagli operativi end-to-end Gmail/Drive/PDF restano **DA VERIFICARE**.

## Aree ad alto rischio regressione
- Contratto ibrido `drive_pdf_imports` vs legacy `prescriptions`.
- Logica di risoluzione campi paziente tramite fallback multipli (`PhboxContractUtils`).
- Migrazione paziente temporaneo -> codice fiscale reale (batch multi-collezione).
- Coerenza tra mutazioni dati e segnali runtime.
- Ottimizzazioni dashboard basate su indice/materializzazione (`patient_dashboard_index`, `dashboard_totals`).

## Punti che possono aumentare letture Firestore
- Caricamenti “globali” con `collectionGroup` su `debts`, `advances`, `bookings`, `prescriptions`.
- `getAllImports()` su `drive_pdf_imports` senza limit.
- Ricerca dashboard che forza refresh dati completi quando non valida cache locale.
- Validazione appartenenza famiglia che itera per ogni membro (`arrayContains` ripetuti).
