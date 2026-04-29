# BACKEND_CONTRACT

## Dichiarazioni vincolanti
1. Il backend GAS è presente in `backend_gas/src` come copia sorgente versionata; la produzione resta Apps Script e l’allineamento con la versione deployata va verificato.
2. GitHub/`backend_gas` non implica deploy automatico.
3. Prima di qualsiasi modifica backend è obbligatoria la verifica di allineamento GitHub ↔ Apps Script produzione.
4. Se l’allineamento non è verificato, il comportamento produzione resta **DA VERIFICARE**.
5. Codex non deve mai assumere che una modifica su GitHub sia automaticamente deployata su Apps Script.
6. Nessun `clasp push`, `clasp deploy` o GitHub Actions verso Apps Script è autorizzato.

## Policy di modifica
- Ogni intervento backend deve passare da PR separata dedicata al backend.
- La PR backend deve includere:
  - diagnosi precisa
  - causa radice
  - file `.gs` modificati
  - funzioni modificate
  - test Apps Script manuali
  - rischio residuo
  - stima letture Firestore/ora
  - istruzioni manuali di applicazione/deploy su Apps Script

## Impatti obbligatori da dichiarare
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
