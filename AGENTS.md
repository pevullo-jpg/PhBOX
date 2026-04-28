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
- Su Gmail/Drive/PDF pipeline: se il backend GAS non è presente nel repository, ogni dettaglio operativo è **DA VERIFICARE** e non va modificato senza codice backend reale o allegato aggiornato.

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
