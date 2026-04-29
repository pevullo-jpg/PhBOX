# BACKEND_CONTRACT

## Dichiarazioni vincolanti
1. Il backend Google Apps Script (GAS) di produzione è attualmente esterno a questo repository GitHub.
2. Finché la migrazione non è formalmente completata, la sorgente operativa di produzione resta Apps Script.
3. La cartella `backend_gas/` rappresenta la destinazione prevista per la copia sorgente controllata su GitHub.

## Policy di modifica
- Codex **non deve intervenire sul backend** senza presenza dei file GAS reali nel repository.
- Non è autorizzato alcun deploy automatico verso Apps Script da questa repository.
- Ogni intervento backend deve passare da:
  - analisi del cambiamento,
  - PR separata dedicata al backend,
  - review esplicita,
  - test manuale su ambiente Apps Script.

## Limiti di questa fase
Questa fase è esclusivamente documentale e di scaffolding: nessun comportamento applicativo backend viene modificato.
