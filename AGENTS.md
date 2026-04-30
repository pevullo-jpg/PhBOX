# AGENTS.md — Istruzioni operative permanenti per PhBOX

## 1) Identità progetto
- PhBOX 0.2 è la versione evolutiva basata sul repository GitHub attuale.
- PhBOX 0.1 è baseline storica stabile, solo riferimento anti-regressione.
- Ogni modifica deve confrontarsi con il comportamento atteso della baseline.

## 2) Regole generali
- Non modificare file fuori dallo scope richiesto.
- Non fare refactor cosmetici o generali non richiesti.
- Non introdurre nuove dipendenze senza motivazione esplicita.
- Non duplicare logica esistente.
- Non cambiare contratti frontend/backend/superback senza autorizzazione.
- Non cambiare data model Firestore senza piano esplicito.
- Non aumentare letture Firestore senza dichiararlo.
- Il backend GAS è presente in `backend_gas/src` come copia sorgente versionata; la produzione resta Apps Script e l’allineamento con la versione deployata va verificato.
- Codex non deve mai assumere che una modifica su GitHub sia automaticamente deployata su Apps Script.
- Nessun `clasp push`, `clasp deploy` o GitHub Actions verso Apps Script è autorizzato.

## 3) Aree ad alto rischio
- Gmail ingest
- Drive OCR
- parser ricette
- manifest
- merge
- rename PDF
- Firestore reads/writes
- runtime gate
- tenant_control
- doctor_patient_links
- dashboard auto-refresh
- login e Superback

## 4) Regole prima di modificare codice
Prima di ogni modifica Codex deve produrre:
- diagnosi
- causa probabile
- file coinvolti
- flusso dati
- invarianti
- failure mode
- rischio regressione
- piano modifica minimo
- test previsti

## 5) Regole dopo modifica
Dopo ogni modifica Codex deve produrre:
- causa radice
- soluzione applicata
- file modificati
- perché la modifica è minima
- test eseguiti
- test non eseguiti
- rischio residuo
- impatto su Firestore
- impatto su Gmail
- impatto su Drive
- impatto su frontend
- impatto su backend GAS

## 6) Regole specifiche backend GAS
- `backend_gas/src` contiene la copia sorgente versionata del backend GAS.
- Apps Script resta l’ambiente di produzione reale.
- GitHub/`backend_gas` non implica deploy automatico.
- Ogni modifica backend deve passare da PR separata.
- Prima di modificare backend bisogna verificare allineamento GitHub ↔ Apps Script produzione.
- Se l’allineamento non è verificato, il comportamento produzione resta **DA VERIFICARE**.
- Ogni modifica backend deve indicare impatto su:
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
- Ogni PR backend deve includere:
  - diagnosi precisa
  - causa radice
  - file `.gs` modificati
  - funzioni modificate
  - test Apps Script manuali
  - rischio residuo
  - stima letture Firestore/ora
  - istruzioni manuali di applicazione/deploy su Apps Script


## 7) Protocollo obbligatorio anti-regressione PR (Codex)
- Ogni PR applicativa deve partire da `main` (branch base tecnico e storico unico).
- È vietato usare branch `work` per PR finali.
- Ogni PR deve dichiarare esplicitamente: `HEAD SHA`, `base branch`, `files changed`.
- La review Codex deve confermare in chiaro l'`HEAD SHA` revisionato.
- Se la review riguarda un commit vecchio (SHA diverso dall'ultimo HEAD), la review è invalida e va rifatta.
- È vietato cambiare la semantica di helper condivisi senza introdurre/helper dedicato approvato per il nuovo comportamento.
- Ogni PR deve elencare i pattern vietati specifici del bug che intende prevenire.
- Ogni PR deve dichiarare l'impatto stimato su Firestore (`reads/hour`).
- Se durante lavorazione o review la PR diventa confusa/non verificabile, va chiusa senza merge e rifatta pulita partendo da `main`.
- Merge consentito solo dopo review sull'ultimo `HEAD SHA` e GitHub Actions verdi.
