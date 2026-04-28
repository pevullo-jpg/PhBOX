# RELEASE_PROTOCOL

## Scopo
Protocollo minimo di rilascio per ridurre regressioni su contratti dati.

## Pre-release checklist
1. Verifica schema/contratti Firestore:
   - nessun rename campi critici in `phbox_signals`, `patient_dashboard_index`, `dashboard_totals`, `drive_pdf_imports`.
2. Eseguire checklist `docs/REGRESSION_TESTS.md`.
3. Verificare coerenza ownership:
   - frontend non deve creare record import/archive in `drive_pdf_imports`.
   - frontend non deve eseguire write stile `saveImport()`.
   - frontend non deve scrivere parser/OCR metadata, merge/rename metadata, archive mutation o lifecycle fields backend-owned.
   - frontend può solo inviare patch delete-request limitate via `requestPdfDelete`; eliminazione reale/final state restano backend.
4. Validare filtri/ricerca dashboard e carichi Firestore.
5. Se il backend GAS non è presente nel repository, marcare come **DA VERIFICARE** ogni dettaglio operativo Gmail/Drive/PDF e bloccare modifiche pipeline senza codice backend reale o allegato aggiornato.

## Gate di rilascio
- Gate 1: build app OK.
- Gate 2: smoke test dashboard + dettaglio paziente OK.
- Gate 3: mutazioni debiti/anticipi/prenotazioni con segnale runtime OK.
- Gate 4: backup export OK.
- Gate 5: nessuna regressione evidente su performance letture Firestore.

## Post-release monitoraggio
- Monitorare errori UI su listener/dashboard.
- Monitorare drift tra mutazioni utente e aggregati dashboard.
- Monitorare backlog segnali runtime (`pending`) se disponibile osservabilità backend (**DA VERIFICARE**).

## Rollback
- Non documentato nel repository: **DA VERIFICARE**.
- Raccomandazione minima: ripristino build precedente frontend + verifica compatibilità schema Firestore.
