# backend_gas

## Scopo
Questa cartella contiene la copia sorgente versionata del backend Google Apps Script (GAS) usato da PhBOX.

## Stato attuale
- Il backend GAS è presente in `backend_gas/src` come copia sorgente versionata; la produzione resta Apps Script e l’allineamento con la versione deployata va verificato.
- Apps Script resta l’ambiente di produzione reale.
- GitHub/`backend_gas` non implica deploy automatico.

## Regole operative
- Prima di modificare backend, verificare allineamento GitHub ↔ Apps Script produzione.
- Se l’allineamento non è verificato, il comportamento produzione resta **DA VERIFICARE**.
- Codex non deve mai assumere deploy automatico verso Apps Script.
- Nessun `clasp push`, `clasp deploy` o GitHub Actions verso Apps Script è autorizzato.
- Ogni modifica backend richiede PR separata, review esplicita e test manuale su Apps Script.
