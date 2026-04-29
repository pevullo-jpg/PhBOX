# CONTRACT_BACKEND_GAS

## Stato attuale nel repository
- Il backend GAS è presente in `backend_gas/src` come copia sorgente versionata; la produzione resta Apps Script e l’allineamento con la versione deployata va verificato.
- GitHub/`backend_gas` non implica deploy automatico verso Apps Script.

## Regole vincolanti
1. Prima di modificare backend, verificare esplicitamente allineamento GitHub ↔ Apps Script produzione.
2. Se l’allineamento non è verificato, il comportamento produzione resta **DA VERIFICARE**.
3. Codex non deve mai assumere che una modifica su GitHub sia automaticamente deployata su Apps Script.
4. Nessun `clasp push`, `clasp deploy` o GitHub Actions verso Apps Script è autorizzato.
5. Ogni modifica backend deve passare da PR separata.

## Contratto minimo deducibile
### Input backend
- `phbox_signals/*`
- `phbox_runtime/main`
- Mutazioni utente su `patients/*` e patch delete-request su `drive_pdf_imports/*`.

### Output backend
- aggiornamento `dashboard_totals/main`
- aggiornamento `patient_dashboard_index/*`
- gestione lifecycle `drive_pdf_imports/*` (parser/OCR, merge/rename, mutazioni archive, delete fisico Drive)

## Requisiti obbligatori per PR backend
Ogni PR backend deve includere:
- diagnosi precisa
- causa radice
- file `.gs` modificati
- funzioni modificate
- test Apps Script manuali
- rischio residuo
- stima letture Firestore/ora
- istruzioni manuali di applicazione/deploy su Apps Script

## Impatti da dichiarare in ogni modifica backend
- Gmail ingest
- Drive/OCR
- parser
- manifest runtime
- merge
- rename
- Firestore sync
- phbox_runtime
- phbox_signals
- trigger Apps Script
- letture/scritture Firestore
