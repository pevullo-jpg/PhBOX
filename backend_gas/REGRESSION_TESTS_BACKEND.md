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

## M1-SHADOW — test manuale obbligatorio

Da eseguire per ogni fix che modifica lo shadow-mode Migration 1.

1. `PHBOX_M1_SHADOW_TARGET_ENABLED` assente o diverso da `true`:
   - `migration1Shadow.enabled=false`
   - `migration1Shadow.firestoreReads=0`
   - nessun path `tenants/{tenantId}/assistiti` viene costruito, esposto o letto;
   - il summary disabled non contiene `targetCollection`.
2. `PHBOX_M1_SHADOW_TARGET_ENABLED=true` con `PHBOX_TENANT_ID` mancante:
   - stage `migration1_target_shadow` fallisce in modo diagnostico;
   - `migration1Shadow.firestoreReads=0`;
   - `migration1Shadow.firestoreWrites=0`;
   - `migration1Shadow.publishFromTarget=false`;
   - nessuna target read viene eseguita;
   - nessun write diagnostico su `phbox_runtime` o `phbox_signals` viene eseguito.
3. `PHBOX_M1_SHADOW_TARGET_ENABLED=true` con `PHBOX_TENANT_ID` vuoto:
   - stage `migration1_target_shadow` fallisce in modo diagnostico;
   - `migration1Shadow.firestoreReads=0`;
   - `migration1Shadow.firestoreWrites=0`;
   - `migration1Shadow.publishFromTarget=false`;
   - nessuna target read viene eseguita;
   - nessun write diagnostico su `phbox_runtime` o `phbox_signals` viene eseguito.
4. `PHBOX_M1_SHADOW_TARGET_ENABLED=true` con `PHBOX_TENANT_ID` contenente `/`:
   - stage `migration1_target_shadow` fallisce in modo diagnostico;
   - `migration1Shadow.firestoreReads=0`;
   - `migration1Shadow.firestoreWrites=0`;
   - `migration1Shadow.publishFromTarget=false`;
   - nessuna target read viene eseguita;
   - nessun write diagnostico su `phbox_runtime` o `phbox_signals` viene eseguito.
5. `PHBOX_M1_SHADOW_TARGET_ENABLED=true` con `PHBOX_TENANT_ID` diverso da `PHBOX_EXPECTED_CANONICAL_TENANT_ID`:
   - stage `migration1_target_shadow` fallisce in modo diagnostico;
   - `migration1Shadow.firestoreReads=0`;
   - `migration1Shadow.firestoreWrites=0`;
   - `migration1Shadow.publishFromTarget=false`;
   - nessuna target read viene eseguita;
   - nessun write diagnostico su `phbox_runtime` o `phbox_signals` viene eseguito.
6. `PHBOX_M1_SHADOW_TARGET_ENABLED=true` con tenant canonico validato:
   - una sola lettura bounded su `tenants/{tenantId}/assistiti`;
   - `migration1Shadow.firestoreReads <= 100`;
   - `migration1Shadow.firestoreWrites=0`;
   - `publishFromTarget=false`;
   - nessun Gmail/Drive/OCR/parser/merge/rename viene modificato.
7. Verificare che il backend legacy continui a pubblicare solo sui path legacy finché M1-PUB non è autorizzato.


## M1-SHADOW — invariant P2 Codex #346

- Lo stage `migration1_target_shadow` non deve essere eseguito tramite `runProtectedStage_`, perché quella wrapper può pubblicare snapshot autorizzativi su `phbox_runtime/main` in caso di errore authorization.
- Gli errori shadow devono restare diagnostici/read-only: `firestoreWrites=0`, nessuna modifica a `phbox_runtime`, nessuna modifica a `phbox_signals`.
- Quando il gate shadow è OFF, il risultato non deve includere `targetCollection` né altri path target materializzati.


## M1-SHADOW — invariant P2 Codex #347

- Anche quando `migration1_target_shadow` fallisce, il summary normalizzato deve preservare diagnostica read-only esplicita:
  - `migration1Shadow.firestoreReads=0`;
  - `migration1Shadow.firestoreWrites=0`;
  - `migration1Shadow.publishFromTarget=false`;
  - `migration1Shadow.lifecycleTouched=false`.
- Il fallback usato da `normalizeStageSummary_` per M1-SHADOW deve essere `buildMigration1ShadowReadOnlyErrorFallback_()` o equivalente, non un fallback generico privo dei contatori read/write.
