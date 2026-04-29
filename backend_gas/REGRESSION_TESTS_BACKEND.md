# REGRESSION_TESTS_BACKEND

## Obiettivo
Checklist minima di validazione manuale Apps Script per ogni modifica backend.

## Prerequisiti
- Verifica allineamento GitHub ↔ Apps Script produzione completata.
- PR backend separata aperta.
- Ambiente Apps Script accessibile.

## Checklist manuale
1. Esecuzione trigger/funzioni principali senza errori runtime.
2. Verifica integrazioni Gmail ingest coinvolte.
3. Verifica integrazioni Drive/OCR coinvolte.
4. Verifica parser coinvolti.
5. Verifica manifest runtime, merge, rename.
6. Verifica Firestore sync, `phbox_runtime`, `phbox_signals`.
7. Verifica trigger Apps Script.
8. Verifica letture/scritture Firestore e stima letture/ora.

## Gate di rilascio
Una modifica backend è candidata al rilascio solo se:
- PR dedicata approvata,
- test manuali Apps Script eseguiti e tracciati,
- rischio residuo esplicitato,
- incluse istruzioni manuali di applicazione/deploy su Apps Script.

## Nota di governance
- Il backend GAS è presente in `backend_gas/src` come copia sorgente versionata; la produzione resta Apps Script e l’allineamento con la versione deployata va verificato.
- Nessun `clasp push`, `clasp deploy` o GitHub Actions verso Apps Script è autorizzato.
