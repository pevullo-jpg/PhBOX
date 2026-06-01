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

## M1-IDRES — test manuale obbligatorio

Da eseguire per ogni fix che modifica il resolver identità Migration 1.

1. Aprire pagina Settings backend.
2. Eseguire `Esegui test M1-IDRES`.
3. Verificare output copiabile `MIGRATION_1_IDRES_TEST`.
4. Atteso:
   - `ok=true`;
   - `failedCount=0`;
   - `firestoreReads=0`;
   - `firestoreWrites=0`;
   - `publishFromTarget=false`.
5. Verificare casi coperti:
   - CF valido → `identityType=cf`, `identityAnchor=CF`;
   - NOCF manuale → `identityType=nocf`, `identityAnchor=NOCF/manual anchor`;
   - placeholder name → `fullNameSafe=Assistito senza nome`;
   - CF-like name → non usato come `fullNameSafe`;
   - OCR/CF fragment → non usato come `fullNameSafe`;
   - `identityType` non supportato + CF valido → `ok=false`, `identityType=unknown`, motivo `identity_type_unsupported`;
   - identity mancante → `ok=false`, nessuna write.
6. Verificare che un `identityType` non supportato venga rigettato prima di qualunque fallback CF.
7. Verificare che il resolver non venga collegato a publish target prima di M1-PUB.
8. Verificare che non siano presenti nella Settings UI i preset test M1-SHADOW già chiusi.
