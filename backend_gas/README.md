# backend_gas

## Scopo
Questa cartella prepara il repository PhBOX ad accogliere il backend Google Apps Script (GAS) reale in forma versionata.

## Stato attuale
- Il backend GAS reale è **attualmente esterno a GitHub**.
- Fino al completamento della migrazione, **Apps Script resta la sorgente di produzione**.
- `backend_gas/` su GitHub è destinata a diventare la **copia sorgente controllata** del backend.

## Regole operative
- In assenza dei file GAS reali in repository, **Codex non deve modificare il backend**.
- **Nessun deploy automatico** verso Apps Script è autorizzato.
- Ogni modifica backend richiede obbligatoriamente:
  1. analisi tecnica,
  2. PR separata,
  3. review,
  4. test manuale su Apps Script.

## Struttura minima iniziale
- `BACKEND_CONTRACT.md`: vincoli e governance della migrazione.
- `REGRESSION_TESTS_BACKEND.md`: checklist manuale anti-regressione backend.
- `src/.gitkeep`: placeholder per future sorgenti GAS versionate.
