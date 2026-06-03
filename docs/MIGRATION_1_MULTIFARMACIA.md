# PhBOX 0.2 — Migration 1 Multifarmacia

Documento finale operativo della Migration 1. Questo file congela lo stato logico della migrazione multifarmacia prima di M1-FREEZE.

## Stato sintetico

| Step | Stato | Scopo | Effetto runtime |
|---|---:|---|---|
| M1-COPY | PASS | Copia controllata dati migration | Tool/manuale, non backend runtime |
| M1-RPT | PASS | Report migrazione | Tool/manuale, non backend runtime |
| M1-CLEAN | PASS | Cleanup mirati | Tool/manuale, non backend runtime |
| M1-BEAUD | PASS | Audit backend | Diagnostico |
| M1-SHADOW | PASS | Shadow validation | Test rimosso da Settings dopo step successivi |
| M1-IDRES | PASS | Resolver identità backend read-only | 0 reads, 0 writes |
| M1-GATE | PASS | Gate target runtime | Default OFF |
| M1-PUB | PASS | Preparazione publish target gate-aware | Nessun publish-from-target, nessun cutover |
| M1-SIG | PASS | Runtime signals identityAnchor-aware | Metadata CF/NOCF preservati |
| M1-DASH | PASS | Compatibilità dashboard frontend | Nessun target read/cutover |
| M1-DUAL | PASS | Verifier legacy vs target | Read-only, bounded, on-demand |
| M1-CUT | PASS | Gate cutover single-tenant | Default OFF |
| M1-E2E | PASS | Validazione end-to-end controllata | Diagnostica, no routing |
| M1-COST | PASS | Audit costi | Budget read/write esplicito |
| M1-FINALCLEAN | PASS | Cleanup Settings/debug | Solo test corrente esposto |
| M1-DOC | CURRENT | Documentazione finale | Zero-read/zero-write |
| M1-FREEZE | NEXT | Baseline multifarmacia | Da eseguire dopo merge DOC |

## Owner della verità

| Dominio | Owner | Nota |
|---|---|---|
| Identità assistito | Backend GAS | `identityType`, `identityAnchor`, `identityAnchorCanonical`, `legacyNoCfCode`, `identityResolutionReasons` |
| Legacy runtime | Firestore root legacy | Sorgente operativa finché cutover resta OFF |
| Target multifarmacia | `tenants/{tenantId}/...` | Accessibile solo dopo tenant canonico e gate autorizzato |
| Dashboard rendering | Frontend | Compatibile con CF/NOCF tramite identity key |
| Migrazione storico | Tool/manuale | Il backend non migra massivamente lo storico |
| Cutover decision | Backend GAS | Single tenant, default OFF, vincolato a DUAL clean |

## Contratti dati

### Identità

Campi backend-owned:

```text
identityType = cf | nocf | unknown
identityAnchor = CF canonico oppure anchor NOCF canonico
identityAnchorCanonical = boolean
legacyNoCfCode = codice legacy NOCF, se presente
identityResolutionReasons = motivi/provenienza risoluzione identità
targetFiscalCode = solo per identità CF valida
```

Regole:

- `identityType=nocf` non deve forzare un CF stale.
- `identityType=cf` può usare `identityAnchor` come CF canonico se `targetFiscalCode` manca.
- `identityAnchor` con slash è invalido prima di qualunque uso path.
- Metadata NOCF devono essere preservati anche nei done result dei runtime signals.

### Target runtime

Path target consentito solo dopo gate canonico:

```text
tenants/{tenantId}/{legacyCollection}/{legacyDocumentId}
```

Regole:

- Nessun fallback/default tenantId.
- Nessun path `tenants/{tenantId}/...` costruito prima della validazione canonica.
- Path legacy già prefissati `tenants/` sono rifiutati.
- Nessun bulk scan backend per migrare lo storico.

## Invarianti runtime

- `default_off`: gate target e cutover sono OFF di default.
- `no_fallback_tenant`: tenantId mancante, vuoto, non canonico o con slash blocca ogni percorso target.
- `canonical_tenant_before_target_path`: nessun target path prima della validazione tenant.
- `no_bulk_scan`: nessuna scansione massiva introdotta dal backend Migration 1.
- `no_cutover_until_authorized`: cutover autorizzabile solo con gate ON, tenant canonico e DUAL clean.
- `zero_write_diagnostic_tests`: test Settings Migration 1 restano diagnostici e zero-write.
- `legacy_runtime_preserved`: con gate OFF il comportamento legacy resta invariato.

## Properties operative

| Property | Scopo | Default sicuro |
|---|---|---:|
| `PHBOX_M1_TARGET_RUNTIME_ENABLED` | Abilita gate target runtime | false/off |
| `PHBOX_TENANT_ID` | Tenant runtime richiesto per target | assente |
| `PHBOX_EXPECTED_CANONICAL_TENANT_ID` | Tenant atteso per validazione canonica | assente |
| `PHBOX_M1_DUAL_SAMPLE_LEGACY_PATHS` | Sample path legacy espliciti per DUAL | vuoto |
| `PHBOX_M1_CUTOVER_ENABLED` | Abilita gate cutover | false/off |
| `PHBOX_M1_CUTOVER_TENANT_ID` | Tenant cutover single-tenant | assente |
| `PHBOX_M1_COST_MAX_READS` | Budget read audit costi | 20 |
| `PHBOX_M1_COST_MAX_WRITES` | Budget write audit costi | 0 |

## Evidenze di validazione

| Step | Test validato | Esito |
|---|---|---:|
| M1-IDRES | `MIGRATION_1_IDRES_TEST` | 7/7 PASS, 0 reads, 0 writes |
| M1-GATE | `MIGRATION_1_GATE_TEST` + runtime status | 8/8 PASS, gate OFF zero-read |
| M1-PUB | `MIGRATION_1_PUB_TEST` + runtime status | 7/7 PASS, no cutover |
| M1-SIG | `MIGRATION_1_SIG_TEST` | 18/18 PASS, metadata CF/NOCF preservati |
| M1-DASH | `MIGRATION_1_DASH_TEST` | 8/8 PASS, DPC identity key coperto |
| M1-DUAL | `MIGRATION_1_DUAL_TEST` + runtime status | 9/9 PASS, bounded verifier |
| M1-CUT | `MIGRATION_1_CUT_TEST` + runtime status | 8/8 PASS, default OFF |
| M1-E2E | `MIGRATION_1_E2E_TEST` + runtime status | 6/6 PASS, DUAL reads non duplicate |
| M1-COST | `MIGRATION_1_COST_TEST` + runtime status | 8/8 PASS, budget zero coperto |
| M1-FINALCLEAN | `MIGRATION_1_FINALCLEAN_TEST` + runtime status | 6/6 PASS, obsolete handlers 0 |

## Costi

Baseline attesa con gate OFF:

```text
firestoreReads=0
firestoreWrites=0
publishToTarget=false
targetPathBuilt=false
cutover=false
lifecycleTouched=false
```

Runtime diagnostic con gate ON:

- reads consentite solo da M1-DUAL/M1-E2E bounded verifier;
- sample paths DUAL massimo 10;
- writes sempre 0 nei test diagnostici;
- budget default M1-COST: `maxReads=20`, `maxWrites=0`;
- override `PHBOX_M1_COST_MAX_READS=0` deve essere rispettato come zero budget esplicito.

## Regola di merge

Merge consentito solo se:

- Actions/checks verdi;
- Codex review senza P1/P2;
- files changed esattamente in scope;
- reviewed HEAD = latest PR HEAD;
- test Settings corrente PASS;
- runtime status corrente PASS.

## Prossimo step

```text
M1-FREEZE — baseline multifarmacia
```

Obiettivo M1-FREEZE:

- congelare baseline Migration 1;
- confermare che gate/cutover restano OFF;
- confermare zero read/write in idle diagnostico;
- bloccare ulteriori modifiche M1 salvo fix P1/P2;
- passare a fase successiva solo con ownership e contratto dichiarati.
