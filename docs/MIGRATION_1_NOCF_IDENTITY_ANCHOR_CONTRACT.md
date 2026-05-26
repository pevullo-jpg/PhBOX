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

## Promozione NOCF → CF reale

Il frontend deve poter richiedere in qualunque momento la sostituzione di uno pseudo-CF canonico con un CF reale, ma questa operazione non è un semplice edit del campo `cf`.

È una promozione di identità.

### Stato prima della promozione

```text
cf = NOCF_<hash>
identityType = nocf
identityAnchor = NOCF_<hash>
legacyNoCfCode = eventuale codice TMP/manuale originario
generatedNoCf = true/false
```

### Stato dopo la promozione

```text
cf = CF reale
identityType = cf
identityAnchor = CF reale
previousIdentityAnchors = [NOCF_<hash>, ...eventuali precedenti]
legacyNoCfCode = preservato se presente
generatedNoCf = false oppure non più rilevante
```

### Regole obbligatorie

- La promozione è ammessa solo da `identityType = nocf`.
- Il valore corrente deve essere un NOCF canonico.
- `currentCf` e `currentIdentityAnchor` devono coincidere.
- Il nuovo CF deve essere un CF reale valido/canonico.
- Il vecchio NOCF deve essere salvato in `previousIdentityAnchors`.
- `legacyNoCfCode` deve essere preservato per audit.
- Il frontend non deve scrivere direttamente `cf`.
- La futura implementazione operativa deve essere atomica.

### Transazione futura obbligatoria

Quando sarà implementata la promozione reale, la procedura dovrà:

```text
1. validare CF reale di destinazione;
2. verificare assenza target/lock per il nuovo CF;
3. verificare esistenza e coerenza dell'assistito NOCF corrente;
4. aggiornare cf, identityType, identityAnchor;
5. aggiungere il NOCF corrente a previousIdentityAnchors;
6. preservare legacyNoCfCode;
7. creare lock per il CF reale;
8. mantenere o tombstonare il lock NOCF secondo contratto dedicato;
9. fallire interamente in caso di qualunque conflitto.
```

## Invarianti

- Nessun NOCF deve sembrare un CF reale.
- Nessun codice TMP/manuale deve diventare direttamente la chiave finale target.
- `identityAnchor` è la chiave universale prevista per deduplica futura.
- `cf` resta valorizzato con `NOCF_<hash>` per compatibilità temporanea con i flussi esistenti.
- `legacyNoCfCode` è audit/source trace, non chiave primaria.
- Cambiare nome/cognome dopo la creazione non deve cambiare `identityAnchor`.
- Due assistiti NOCF diversi devono poter ricevere anchor diversi anche se omonimi.
- Codici vuoti, con slash o non canonici sono vietati.
- La promozione NOCF → CF reale deve preservare la storia dell'anchor.
- La promozione NOCF → CF reale non deve essere un edit diretto del campo `cf`.

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

## Scope Fix #294

Fix #294 introduce solo contratto/helper/test per la promozione NOCF → CF reale.

Non introduce:

- UI di promozione;
- write Firestore;
- transazione reale di promozione;
- modifica writer;
- modifica duplicate guard;
- modifica audit;
- modifica backend_gas;
- modifica Gmail/Drive/PDF lifecycle.

## Step successivi

- Fix successivo: audit NOCF read-only.
- Poi duplicate guard basato su `identityAnchor`.
- Poi copy NOCF small batch.
- Poi promozione operativa NOCF → CF reale con transazione dedicata.
