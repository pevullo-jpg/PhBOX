# PhBOX 0.2 — Migration 1 FREEZE Baseline Multifarmacia

## 1. Stato baseline

**Versione freeze:** M1_FREEZE_v1  
**Stato:** baseline_frozen  
**Sorgente documentale:** docs/MIGRATION_1_MULTIFARMACIA.md  
**Sorgente validata:** M1_DOC_v2  
**Next roadmap:** Migration 2 — Cutover operativo controllato

Migration 1 chiude la preparazione multifarmacia senza rendere il routing target il default produttivo. Il comportamento legacy resta il comportamento operativo predefinito.

## 2. Scope congelato

Migration 1 include:

1. M1-COPY
2. M1-RPT
3. M1-CLEAN
4. M1-BEAUD
5. M1-SHADOW
6. M1-IDRES
7. M1-GATE
8. M1-PUB
9. M1-SIG
10. M1-DASH
11. M1-DUAL
12. M1-CUT
13. M1-E2E
14. M1-COST
15. M1-FINALCLEAN
16. M1-DOC
17. M1-FREEZE

## 3. Owner della verità

- Legacy production data: Firestore root collections.
- Target multifarmacia: `tenants/{tenantId}/...`, autorizzabile solo dopo tenant canonico.
- Tenant identity: backend-owned.
- Runtime gate/cutover decision: backend GAS.
- Dashboard compatibility: frontend-owned, ma basata su metadata identity backend-owned.
- Settings migration test panel: espone solo il test corrente dello step attivo.

## 4. Contratti dati congelati

### Tenant

- Nessun tenant di default.
- Nessun fallback tenant.
- Nessun slash nel tenant.
- Nessuno spazio iniziale/finale.
- `PHBOX_TENANT_ID` deve corrispondere a `PHBOX_EXPECTED_CANONICAL_TENANT_ID`.

### Identity

- `identityType=cf`
- `identityType=nocf`
- `identityAnchor`
- `identityAnchorCanonical`
- `legacyNoCfCode`
- `identityResolutionReasons`

CF stale non deve sovrascrivere identità NOCF.

### Runtime target

- Gate default OFF.
- Target path costruito solo dopo validazione tenant canonico.
- Cutover autorizzabile solo dopo DUAL match.
- Nessun cutover automatico in Migration 1.

## 5. Invarianti runtime congelate

1. Legacy default ON.
2. Target runtime default OFF.
3. No default tenant.
4. No target path before canonical tenant.
5. No cutover without DUAL match.
6. Zero-write diagnostics.
7. Settings exposes only current migration test.

## 6. Evidenze validazione

- M1-IDRES: 7/7 PASS.
- M1-GATE: 8/8 PASS.
- M1-PUB: 7/7 PASS.
- M1-SIG: 18/18 PASS.
- M1-DASH: 8/8 PASS.
- M1-DUAL: 9/9 PASS.
- M1-CUT: 8/8 PASS.
- M1-E2E: 6/6 PASS.
- M1-COST: 8/8 PASS.
- M1-FINALCLEAN: 6/6 PASS.
- M1-DOC: 8/8 PASS.

## 7. Costi congelati

Con gate OFF:

- Firestore reads: 0.
- Firestore writes: 0.
- Publish target: false.
- Cutover: false.
- Gmail/Drive/PDF lifecycle touched: false.

Con gate ON, i soli costi ammessi in Migration 1 derivano dai verifier diagnostici bounded già introdotti.

## 8. Regola di freeze

M1-FREEZE può essere considerato baseline solo se:

- Actions/checks verdi.
- Codex senza P1/P2.
- Files changed esattamente in scope.
- `MIGRATION_1_FREEZE_TEST` PASS.
- `MIGRATION_1_FREEZE_RUNTIME_STATUS` PASS.
- Nessun handler Settings obsoleto esposto.
- Nessuna write Firestore.
- Nessun publish target.
- Nessun cutover.
- Nessun lifecycle Gmail/Drive/PDF.

## 9. Cosa NON è incluso

Migration 1 non include:

- migrazione massiva storico;
- bulk scan;
- cleanup automatico storico;
- routing target-first produttivo;
- dashboard target-first;
- gestione simultanea produttiva di più tenant;
- cutover automatico.

## 10. Stato finale

PhBOX resta legacy-safe e acquisisce una baseline multifarmacia verificata, documentata e congelata.

La roadmap successiva è:

**Migration 2 — Cutover operativo controllato**
