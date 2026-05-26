# MIGRATION 1 — NOCF identity anchor contract

## Obiettivo

Definire una regola canonica per migrare assistiti senza codice fiscale reale, mantenendo compatibilità con i flussi Migration 1 già orientati al campo `cf`.

## Regola principale

Gli assistiti NOCF non devono ricevere un codice fiscale falso. Devono ricevere uno pseudo-CF tecnico canonico nel formato:

```text
NOCF_<HASH_16_HEX>
```

Esempio:

```text
NOCF_A8F39C2D91E4ABCD
```

## Campi target previsti

Per assistiti con CF reale:

```text
cf = CF reale
identityType = cf
identityAnchor = CF reale
legacyNoCfCode = assente
generatedNoCf = false
```

Per assistiti NOCF legacy con codice TMP o manuale:

```text
cf = NOCF_<hash>
identityType = nocf
identityAnchor = NOCF_<hash>
legacyNoCfCode = codice originale legacy
generatedNoCf = false
```

Per nuovi assistiti futuri senza CF:

```text
cf = NOCF_<hash>
identityType = nocf
identityAnchor = NOCF_<hash>
legacyNoCfCode = assente
generatedNoCf = true
```

## Sorgenti hash

### NOCF legacy

Gli assistiti legacy senza CF ma con codice esistente, per esempio:

```text
TMP_SOFIA_CASTELLI_1778262346407000
```

oppure codici manuali stabili, generano il NOCF canonico da:

```text
legacy_nocf|<codice_legacy_normalizzato>
```

Il codice originale resta solo come `legacyNoCfCode`, non come chiave finale target.

### Nuovi NOCF futuri

Gli assistiti futuri senza CF generano il NOCF canonico da:

```text
new_nocf|<tenantId>|<createdAtMillis>|<nome>|<cognome>|<nonce>
```

Il `nonce` deve essere stabile e serve a distinguere omonimi reali.

## Invarianti

- Nessun NOCF deve sembrare un CF reale.
- Nessun codice TMP/manuale deve diventare direttamente la chiave finale target.
- `identityAnchor` è la chiave universale prevista per deduplica futura.
- `cf` resta valorizzato con `NOCF_<hash>` per compatibilità temporanea con i flussi esistenti.
- `legacyNoCfCode` è audit/source trace, non chiave primaria.
- Cambiare nome/cognome dopo la creazione non deve cambiare `identityAnchor`.
- Due assistiti NOCF diversi devono poter ricevere anchor diversi anche se omonimi.
- Codici vuoti, con slash o non canonici sono vietati.

## Scope Fix #293

Fix #293 introduce solo contratto, normalizzatore e test.

Non introduce:

- copia NOCF;
- write Firestore;
- modifica writer;
- modifica duplicate guard;
- modifica audit;
- modifica UI;
- modifica backend_gas;
- modifica Gmail/Drive/PDF lifecycle.

## Step successivi

- Fix successivo: audit NOCF read-only.
- Poi duplicate guard basato su `identityAnchor`.
- Poi copy NOCF small batch.
