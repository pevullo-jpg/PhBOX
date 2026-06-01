# MIGRATION_1_BACKEND_MULTITENANT_AUDIT

## Codice stabile

`M1-BEAUD`

## Scopo

Audit read-only del backend GAS rispetto alla Migration 1 multifarmacia.

Questo documento non abilita shadow-mode, non abilita cutover, non modifica backend, non introduce query, listener, trigger o write.

## Stato dati target prima dell'audit

Ultimo report Migration 1 comunicato:

```text
inputDocumentCount=2
verifiedCount=2
failedCount=0
cfCount=0
noCfCount=2
resolvedManualCount=2
pendingManualCount=0
contaminatedIdentityCount=0
staleSearchPrefixesCount=0
allVerified=true
hasFailures=false
firestoreReads=2
firestoreWrites=0
```

Gate dati target: PASS.

## Sorgente verificata

Audit eseguito sul sorgente reale presente in repository/zip corrente:

```text
backend_gas/src
```

File backend principali analizzati:

```text
CONFIG.gs
ENTRYPOINT.gs
FIRESTORE.gs
BUILD_ENTITIES.gs
PATIENT_DASHBOARD_INDEX.gs
DASHBOARD_TOTALS.gs
DASHBOARD_EXPIRING_RECIPES.gs
RUNTIME_SIGNALS.gs
PATIENT_DELETE.gs
GMAIL_INGEST.gs
OCR_AND_PARSER.gs
MERGE_CF.gs
FINALIZE_PDF_NAMES.gs
PATIENT_IDENTITY_AUDIT.gs
PATIENT_IDENTITY_CANONICALIZER.gs
PATIENT_IDENTITY_RESOLUTION_PLAN.gs
PATIENT_IDENTITY_RESOLUTION_REQUESTS.gs
```

## Diagnosi sintetica

Il backend GAS operativo è ancora legacy-root e CF-centric.

Path operativi ancora root:

```text
patients/{CF}
drive_pdf_imports/{driveFileId}
doctor_patient_links/{CF__primary}
patient_dashboard_index/{CF}
dashboard_totals/main
dashboard_expiring_recipes/main
phbox_runtime/main
phbox_signals/{signalId}
```

Path target Migration 1 non ancora usati dal backend:

```text
tenants/{tenantId}/assistiti/{assistitoId}
tenants/{tenantId}/dashboard_totals/main
tenants/{tenantId}/dashboard_expiring_recipes/main
tenants/{tenantId}/drive_pdf_imports/{importId}
tenants/{tenantId}/phbox_runtime/main
tenants/{tenantId}/phbox_signals/{signalId}
```

Conclusione: non si può procedere direttamente a publish target o cutover. Serve prima shadow-mode read-only.

## Owner della verità attuale

### Legacy operativo

```text
Gmail/Drive/runtime index backend-owned
patients/{CF} backend-owned
drive_pdf_imports/{driveFileId} backend-owned + FE deletePdfRequested consentito
patient_dashboard_index/{CF} backend-owned
doctor_patient_links/{CF__primary} backend-owned
dashboard_totals/main backend-owned
phbox_runtime/main backend-owned
phbox_signals/{signalId} FE/backend signal-owned secondo dominio
```

### Target Migration 1

```text
tenants/{tenantId}/assistiti/{assistitoId} target-owned per Migration 1
identityType/cf/identityAnchor/searchPrefixes/fullName già verificati da M1-RPT
```

Il backend non deve ancora considerare `tenants/{tenantId}/assistiti` come fonte operativa fino a M1-SHADOW e M1-GATE.

## Hard gate tenantId canonico per ogni target read futuro

Prima di qualunque lettura target in M1-SHADOW o step successivi, il backend deve validare `tenantId` come segmento Firestore canonico.

Questo è un prerequisito bloccante, non una raccomandazione.

Regola obbligatoria:

```text
1. Leggere PHBOX_TENANT_ID.
2. Normalizzare con trim.
3. Rifiutare valore vuoto.
4. Rifiutare qualunque valore contenente '/'.
5. Rifiutare qualunque valore diverso dal tenant canonico atteso per la farmacia corrente.
6. Solo dopo validazione canonica costruire tenants/{tenantId}/assistiti.
7. Nessuna fallback tenantId implicita.
8. Nessuna query tenants/* se la validazione fallisce.
```

La validazione deve avvenire prima di ogni target read, non solo all'avvio del backend e non solo nel test gate generale.

Esempi vietati:

```text
PHBOX_TENANT_ID assente ma sostituito con default
PHBOX_TENANT_ID vuoto ma shadow lasciato attivo
PHBOX_TENANT_ID con slash
PHBOX_TENANT_ID valido sintatticamente ma non uguale al tenant canonico atteso
costruzione del path prima della validazione
query tenants/{tenantId}/assistiti prima della validazione
```

Conseguenza operativa:

```text
Se PHBOX_MIGRATION1_SHADOW_ENABLED=true ma tenantId non è canonico e validato:
- nessuna lettura target
- nessuna query tenants/*
- nessun fallback a root legacy per simulare shadow riuscito
- log diagnostico di blocco shadow
- run legacy operativo invariato
```

## Contratto dati rilevato

### Legacy patients

Usato come documento per CF.

```text
collection: patients
documentId: CF
chiave logica: codice fiscale
```

### Legacy dashboard index

Usato come documento per CF.

```text
collection: patient_dashboard_index
documentId: CF
chiave logica: codice fiscale
```

### Legacy doctor link

```text
collection: doctor_patient_links
documentId: CF__primary
```

### Legacy drive imports

```text
collection: drive_pdf_imports
documentId: driveFileId
campo paziente: patientFiscalCode/fiscalCode/patientCf
```

### Target assistiti

```text
collection: tenants/{tenantId}/assistiti
documentId: assistitoId tecnico/opaco
cf: campo dati, non documentId
identityAnchor: CF o NOCF_<hash>
identityType: cf | nocf
```

Mismatch fondamentale: legacy backend usa CF come documentId; target usa assistitoId opaco.

## Flusso end-to-end backend legacy rilevato

```text
runPhboxBackendSimple
→ Gmail ingest
→ Drive/OCR/parser
→ canonicalize per CF
→ rename PDF
→ runtime signal gate
→ consume delete requests
→ syncRuntimeIndexToFirestore
→ dashboard totals/index
→ Gmail finalize
```

Il flusso ruota su:

```text
runtimeIndex.dirty.cfs
manifest.patientFiscalCode
normalizeCf_()
buildRuntimeCfProjectionUnit_(cf,...)
```

## File diretti / indiretti

### Diretti per futuro M1-SHADOW

```text
CONFIG.gs
FIRESTORE.gs
BUILD_ENTITIES.gs
PATIENT_DASHBOARD_INDEX.gs
RUNTIME_SIGNALS.gs
```

### Diretti per futuro M1-GATE/M1-PUB

```text
CONFIG.gs
FIRESTORE.gs
BUILD_ENTITIES.gs
PATIENT_DASHBOARD_INDEX.gs
DASHBOARD_TOTALS.gs
DASHBOARD_EXPIRING_RECIPES.gs
RUNTIME_SIGNALS.gs
PATIENT_DELETE.gs
```

### Indiretti da non alterare senza test dedicato

```text
GMAIL_INGEST.gs
OCR_AND_PARSER.gs
MERGE_CF.gs
FINALIZE_PDF_NAMES.gs
DRIVE_JSON_STORE.gs
RUN_BUDGET.gs
BACKEND_GUARDS.gs
```

## Stati asincroni e race condition

### Runtime index Drive

Il backend mantiene `runtime_index.json` su Drive e dirty flags:

```text
dirty.imports
dirty.cfs
dirty.threads
publishState.patients
publishState.imports
publishState.doctorLinks
```

Rischio: se target publish viene introdotto senza publishState separato, hash legacy e target possono mascherarsi a vicenda.

### Runtime signal gate

Il gate usa:

```text
phbox_runtime/main
phbox_signals/{signalId}
```

Rischio: segnali target identityAnchor-aware non devono riusare implicitamente CF come target universale.

### Firestore max writes

`syncRuntimeIndexToFirestore_` seleziona write fino a `maxWrites`.

Rischio: introduzione target path nello stesso batch legacy può produrre pubblicazioni parziali incoerenti se non esiste ordine esplicito.

### Delete PDF

`processRuntimeDeletePdfSignal_` risolve CF da signal/import doc e patcha:

```text
drive_pdf_imports/{id}
patient_dashboard_index/{CF}
dashboard_totals/main
```

Rischio: target path richiede mapping `identityAnchor/assistitoId`, non solo CF.

## Invarianti da preservare

```text
1 pagina PDF = 1 ricetta = 1 unità Ricette
Gmail ingest invariato
Drive/OCR/parser invariati
merge per CF legacy invariato finché gate target OFF
rename PDF invariato
root legacy operativo finché gate OFF
nessun fullName da CF o placeholder
nessun FE-owned truth critico
nessuna write target senza gate esplicito
nessun publish target senza shadow-mode pulito
rollback tramite gate OFF obbligatorio
```

## Effetti collaterali possibili se si procede male

```text
Duplicazione assistiti tra patients/{CF} e tenants/{tenantId}/assistiti/{assistitoId}
patient_dashboard_index scritto con chiave sbagliata
NOCF esclusi dal backend perché normalizeCf_ scarta identityAnchor non CF reale
Delete PDF non aggiorna dashboard target
Dashboard totals incoerenti tra root e tenant
Runtime publishState legacy considera no-op dati target non pubblicati
Doctor link associato a CF invece che assistito target
Aumento reads da rebuild dashboard full scan
```

## Impatto costi attuale

Questa PR documentale:

```text
Firestore reads/h: +0
Firestore writes/h: +0
listener: +0
query: +0
trigger: +0
Gmail/Drive/PDF: +0
```

Costo backend legacy esistente: non modificato.

## Matrice rischio backend

| Area | Stato attuale | Rischio per multifarmacia | Decisione |
|---|---|---:|---|
| CONFIG | nessun tenantId operativo nel backend | Alto | introdurre solo in shadow/gate |
| FIRESTORE sync | root collections + CF | Alto | non modificare in M1-BEAUD |
| BUILD_ENTITIES | build patient/doctor per CF | Alto | serve resolver identità |
| DASHBOARD index | documentId CF | Alto | serve compatibility layer |
| RUNTIME signals | target CF/path root | Alto | serve identityAnchor-aware |
| Gmail ingest | stabile e separato | Medio | non toccare in shadow iniziale |
| Drive/OCR/parser | stabile e separato | Medio | non toccare in shadow iniziale |
| Merge/rename | CF legacy | Alto | non convertire prima del gate |
| Delete PDF | root import + CF dashboard | Alto | target mapping dedicato |
| Dashboard totals | root main | Alto | tenant totals solo dopo gate |

## Piano modifica minimo per prossimo step

Prossimo codice ammesso: `M1-SHADOW`.

### Obiettivo M1-SHADOW

Leggere target assistiti in parallelo senza cambiare output operativo.

### Scope minimo M1-SHADOW

```text
Aggiungere helper read-only target assistiti backend
Aggiungere funzione shadow audit bounded
Non pubblicare da target
Non modificare root collections
Non modificare Gmail/Drive/OCR/merge/rename
Non modificare trigger
Non cambiare dashboard
Loggare mismatch legacy vs target
```

### Path ammesso in shadow

```text
tenants/{tenantId}/assistiti/{assistitoId}
```

### Prerequisito tecnico

Configurazione esplicita:

```text
PHBOX_TENANT_ID
PHBOX_EXPECTED_CANONICAL_TENANT_ID
PHBOX_MIGRATION1_SHADOW_ENABLED=false di default
```

Hard gate prima di qualunque target read:

```text
shadow OFF → nessuna lettura target
shadow ON + PHBOX_TENANT_ID mancante → nessuna lettura target
shadow ON + PHBOX_TENANT_ID non canonico → nessuna lettura target
shadow ON + PHBOX_TENANT_ID diverso da PHBOX_EXPECTED_CANONICAL_TENANT_ID → nessuna lettura target
shadow ON + tenantId canonico validato → query bounded tenants/{tenantId}/assistiti
```

Il path `tenants/{tenantId}/assistiti` può essere costruito solo dopo validazione canonica completata.

## Piano test esatto per M1-SHADOW futuro

```text
1. Gate shadow OFF → nessuna query tenants/*.
2. Gate shadow ON + tenantId mancante → nessuna query tenants/*.
3. Gate shadow ON + tenantId vuoto → nessuna query tenants/*.
4. Gate shadow ON + tenantId con slash → nessuna query tenants/*.
5. Gate shadow ON + tenantId sintatticamente valido ma non uguale al tenant canonico atteso → nessuna query tenants/*.
6. Gate shadow ON + tenantId canonico validato prima della costruzione path → query bounded tenants/{tenantId}/assistiti.
7. Ogni target read deve chiamare la validazione tenantId canonico prima di costruire il path.
8. Output legacy invariato con shadow ON.
9. NOCF target resolved_manual letto e contato.
10. CF target letto ma non usato per publish.
11. Nessuna write su tenants/*.
12. Nessuna write su root collection aggiuntiva.
13. Nessun Gmail/Drive/PDF lifecycle call nuovo.
14. Costo dichiarato: max reads/run bounded.
15. Rollback: gate OFF elimina ogni lettura target.
```

## Self-review preventiva

Top rischi residui:

```text
1. Apps Script produzione potrebbe non essere allineato a GitHub/backend_gas.
2. Shadow-mode può aumentare read se non hard-capped.
3. Path target può essere costruito male se tenantId non è canonico e validato prima di ogni target read.
4. NOCF non deve passare da normalizeCf_ come identità primaria.
5. publishState legacy e target devono restare separati.
```

## Decisione

```text
M1-BEAUD: PASS documentale
M1-SHADOW: autorizzabile solo come read-only bounded shadow con tenantId canonico validato prima di ogni target read
M1-IDRES/M1-GATE/M1-PUB: non autorizzabili prima di M1-SHADOW pulito
```
