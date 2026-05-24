# QA target assistiti synthetic copy

## Scope

Fix #248 documents the manual QA protocol for the synthetic assistiti target copy introduced and stabilized through Fix #243-Fix #247.

This checklist is documentation only.
It does not introduce runtime code, Firestore reads, Firestore writes, listeners, polling, backend_gas changes, Gmail/Drive/PDF lifecycle changes, dashboard changes, or SuperBack changes.

## Preconditions

Run this protocol only after Fix #247 is merged and deployed.

Expected Settings test dataset:

- `syn_assistito_0001`
- `syn_assistito_0002`
- `syn_assistito_0003`

Expected confirmation token:

```text
COPIA TEST ASSISTITI
```

Expected target path:

```text
tenants/{tenantId}/assistiti/{assistitoId}
```

## Cleanup before each manual retest

Before re-running the synthetic copy test, manually delete only these synthetic target documents if present:

```text
tenants/{tenantId}/assistiti/syn_assistito_0001
tenants/{tenantId}/assistiti/syn_assistito_0002
tenants/{tenantId}/assistiti/syn_assistito_0003
```

Also delete any obsolete synthetic documents created by older test versions if present:

```text
tenants/{tenantId}/assistiti/synthetic_family_villa_giuseppe
tenants/{tenantId}/assistiti/synthetic_family_villa_maria_grazia
tenants/{tenantId}/assistiti/synthetic_family_villa_luca_damico
```

Do not delete real assistiti.
Do not delete legacy root documents.
Do not delete patients, patient_dashboard_index, doctor_patient_links, drive_pdf_imports, phbox_runtime, or phbox_signals.

## Manual test flow

1. Log in with the authorized email/password account.
2. Open `Impostazioni`.
3. Locate `Test multifarmacia assistiti target`.
4. Press `Prepara anteprima test`.
5. Confirm that the preview contains exactly 3 synthetic assistiti.
6. Leave the confirmation token empty or enter an incorrect token.
7. Press `Copia test assistiti target`.
8. Confirm the operation is blocked and writes committed are `0`.
9. Enter the exact token:

```text
COPIA TEST ASSISTITI
```

10. Press `Copia test assistiti target` again.
11. Confirm the operation completes and writes committed are at most `3`.
12. Open `Assistiti target`.
13. Press `Carica assistiti target`.
14. Confirm the 3 synthetic assistiti are visible and normalized.
15. Return to Dashboard.
16. Confirm Dashboard legacy is unchanged.
17. Confirm logout still works.

## Expected target documents

### syn_assistito_0001

Expected root fields:

```text
assistitoId: syn_assistito_0001
nome: Giuseppe
cognome: Villa
fullName: Villa Giuseppe
cf: TSTVLL84H27A089I
nameSplitConfidence: explicit_fields
sourceVersion: 2
createdAt: non-null
updatedAt: non-null
```

Expected doctor fields:

```text
doctor.medicoNome: Elena
doctor.medicoCognome: Ferri
doctor.codiceMedico: MED-SYN-001
doctor.source: manual
```

### syn_assistito_0002

Expected root fields:

```text
assistitoId: syn_assistito_0002
nome: Maria Grazia
cognome: De Luca
fullName: De Luca Maria Grazia
cf: TSTDLU81B02H501X
nameSplitConfidence: explicit_fields
sourceVersion: 2
createdAt: non-null
updatedAt: non-null
```

Expected doctor fields:

```text
doctor.medicoNome: Elena
doctor.medicoCognome: Ferri
doctor.codiceMedico: MED-SYN-001
doctor.source: manual
```

### syn_assistito_0003

Expected root fields:

```text
assistitoId: syn_assistito_0003
nome: Luca
cognome: Villa D'Amico
fullName: Villa D'Amico Luca
cf: TSTDMC82C03H501X
nameSplitConfidence: explicit_fields
sourceVersion: 2
createdAt: non-null
updatedAt: non-null
```

Expected doctor fields:

```text
doctor.medicoNome: Elena
doctor.medicoCognome: Ferri
doctor.codiceMedico: MED-SYN-001
doctor.source: manual
```

## Fields that must not appear

The target assistiti documents must not contain:

```text
fiscalCode
codiceFiscale
syntheticFamilyRole
```

The `doctor` map must not contain:

```text
assistitoId
cf
fiscalCode
codiceFiscale
nome
cognome
fullName
name
nameSplitConfidence
searchPrefixes
ambulatorio
```

The synthetic metadata is allowed only inside `dashboard` and must remain clearly synthetic:

```text
dashboard.syntheticScenario
dashboard.syntheticFamilyId
```

## Firestore safety assertions

During the test:

- No legacy root collection must be modified.
- No `patients/{CF}` document must be modified.
- No `patient_dashboard_index/{CF}` document must be modified.
- No `doctor_patient_links` document must be modified.
- No `drive_pdf_imports` document must be modified.
- No `phbox_runtime` or `phbox_signals` document must be modified.
- No family collection must be created or modified.
- No target write may occur without the exact confirmation token.
- Writes are allowed only to `tenants/{tenantId}/assistiti/{assistitoId}`.
- The test must remain bounded to 3 synthetic assistiti.

## UI safety assertions

- The Settings page must not copy automatically.
- The preview button must not write Firestore.
- The copy button must require the exact token.
- The target assistiti page must still read only after explicit click.
- Dashboard remains the default page.
- No listener or polling is introduced by this QA protocol.

## Pass criteria

The test passes only if all conditions are true:

- `flutter analyze` passes.
- `flutter build web --release --base-href /PhBOX/` passes.
- Wrong token produces 0 writes.
- Correct token writes at most 3 target assistiti.
- Root identity fields are present and normalized.
- `doctor` contains only doctor semantic fields.
- `doctor.ambulatorio` is absent.
- `syntheticFamilyRole` is absent.
- Dashboard legacy remains unchanged.
- No legacy collections are modified.

## Fail criteria

Stop and open a new autonomous fix if any of these occur:

- Root `nome`, `cognome`, or `fullName` is missing.
- `doctor` contains assistito identity fields.
- `doctor.ambulatorio` appears again.
- `assistitoId` is derived from name, surname, CF, or family.
- More than 3 target assistiti are written.
- Any legacy document is changed.
- Any backend_gas, Gmail, Drive, or PDF behavior changes.
- Any listener or polling is introduced.
