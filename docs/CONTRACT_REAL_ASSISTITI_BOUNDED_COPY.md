# PhBOX — Contratto copia reale assistiti legacy → target bounded

Fix #249 — contratto operativo.  
Stato: documentazione pre-runtime.  
Scope: nessun codice Dart, nessuna read/write Firestore, nessun backend_gas.

## Obiettivo

Definire il contratto minimo per copiare assistiti reali dalla struttura legacy root alla struttura target multifarmacia, senza migrazione, senza copia massiva e senza modifica del legacy.

## Principio base

La copia reale assistiti è:

- manuale;
- bounded;
- verificabile;
- reversibile solo tramite cancellazione manuale del target copiato;
- parallela al legacy;
- non automatica;
- non tenant-aware backend GAS in questa fase.

Non è:

- migrazione;
- switch dashboard;
- copia massiva;
- write legacy;
- aggiornamento backend GAS;
- workflow Gmail/Drive/PDF.

## Source of truth legacy

Le sorgenti legacy ammesse sono solo documenti root esistenti e già usati da PhBOX 0.2:

- `patients/{CF}`
- `patient_dashboard_index/{CF}`
- `patient_therapeutic_advice/{CF}`
- `doctor_patient_links/{CF__manual}`
- `doctor_patient_links/{CF__primary}`

La chiave legacy resta il codice fiscale dove già previsto dal legacy.

## Destinazione target

La destinazione ammessa è solo:

```text
tenants/{tenantId}/assistiti/{assistitoId}
```

`assistitoId` deve essere tecnico, opaco e non derivato da dati personali.

Vietato usare come `assistitoId`:

- codice fiscale;
- nome;
- cognome;
- nome+cognome;
- email;
- telefono;
- hash banale o reversibile del codice fiscale;
- ID legacy basato su CF.

## Campi target richiesti

Ogni documento target deve contenere almeno:

```text
assistitoId: string
cf: string
nome: string
cognome: string
fullName: string
searchPrefixes: array<string>
doctor: map
dashboard: map
therapeuticAdvice: map
createdAt: timestamp | string parseable | null solo se sorgente legacy assente
updatedAt: timestamp | string parseable | null solo se sorgente legacy assente
sourceVersion: number
```

Regole semantiche:

- `cf` è solo campo dati, sempre maiuscolo;
- `nome`, `cognome`, `fullName` sono campi identità assistito root;
- `doctor` contiene solo dati medico, mai dati identità assistito;
- `dashboard` non deve duplicare CF/nome/cognome/fullName/searchPrefixes;
- `therapeuticAdvice` conserva solo dati terapeutici sanitizzati;
- `searchPrefixes` deriva da `fullName` sicuro;
- placeholder o frammenti OCR non devono generare searchPrefixes.

## Input manuale ammesso

L’operatore può fornire al massimo 3 CF per run.

Regole:

- CF normalizzati in maiuscolo;
- CF vuoti ignorati o bloccati;
- CF duplicati nello stesso input bloccano il run;
- più di 3 CF bloccano il run;
- nessuna ricerca globale;
- nessun caricamento massivo;
- nessun listener;
- nessun polling.

## Duplicate guard target

Prima di creare un nuovo documento target reale, il sistema deve controllare se esiste già un assistito target con lo stesso `cf`.

Comportamento obbligatorio:

- se `cf` target già esiste: blocco duplicato, 0 write;
- se `cf` target non esiste: il run può procedere alla preview;
- se il controllo duplicato fallisce: blocco, 0 write;
- il controllo deve essere bounded per CF selezionato.

Nessun secondo documento target con stesso `cf` deve essere creato.

## Generazione assistitoId

Per ogni nuovo assistito reale target:

- `assistitoId` deve essere generato con auto-id Firestore o meccanismo tecnico equivalente;
- il valore deve essere assegnato prima della scrittura;
- `assistitoId` nel payload deve coincidere con il documentId;
- mismatch documentId/payload deve bloccare la write.

## Workflow previsto

Sequenza obbligatoria:

1. Operatore inserisce massimo 3 CF.
2. Sistema normalizza e valida i CF.
3. Sistema legge sorgenti legacy bounded per ogni CF.
4. Sistema controlla duplicati target per `cf`.
5. Sistema produce dry-run preview.
6. Operatore conferma con token manuale.
7. Sistema scrive al massimo 3 documenti target.
8. Sistema richiede verifica post-copia.
9. Verifica confronta legacy vs target preservando raw payload.

## Limiti Firestore

Budget per run reale iniziale:

```text
reads legacy: bounded per CF selezionato
reads target duplicate guard: massimo 1 query limit(1) per CF
writes target: massimo 3
writes legacy: 0
listener: 0
polling: 0
fan-out: bounded dai CF selezionati
```

## Stati di blocco

Il run deve bloccarsi con 0 write se:

- input vuoto;
- più di 3 CF;
- CF duplicati;
- CF non valido o non normalizzabile;
- sorgente legacy assente;
- target con stesso `cf` già presente;
- preview non valida;
- token assente o errato;
- `doctor` contiene identità assistito;
- `nome`, `cognome`, `fullName` root mancanti;
- `assistitoId` non opaco o non coerente con documentId;
- path target non canonico;
- qualsiasi tentativo di patch/delete.

## Invarianti anti-regressione

- Legacy root collections intoccabili.
- Dashboard legacy resta default.
- Nessuna write su `patients`.
- Nessuna write su `patient_dashboard_index`.
- Nessuna write su `patient_therapeutic_advice`.
- Nessuna write su `doctor_patient_links`.
- Nessuna write su `drive_pdf_imports`.
- Nessun backend GAS.
- Nessun Gmail/Drive/PDF lifecycle.
- Nessun trigger.
- Nessun listener.
- Nessun polling.
- Nessun path switch globale.

## Verifica post-copia obbligatoria

Dopo ogni copia reale:

- confrontare dati attesi legacy → target;
- preservare raw target payload;
- verificare documentId == payload.assistitoId;
- verificare `cf`, `nome`, `cognome`, `fullName`, `searchPrefixes`;
- verificare `doctor` semanticamente pulito;
- verificare assenza di contaminazione CF nei campi nome/search;
- verificare assenza duplicati target per CF.

Se la verifica fallisce:

- non procedere con altri batch;
- nessun retry cieco;
- blocco operativo fino a diagnosi.

## Piano test minimo per runtime futuro

Quando verrà implementato il runtime:

1. CF inesistente in legacy → 0 write.
2. Input con 4 CF → 0 write.
3. Input con CF duplicato → 0 write.
4. Target già contiene stesso CF → 0 write.
5. Token errato → 0 write.
6. Token corretto + 1 CF valido → 1 write target.
7. Token corretto + 3 CF validi → massimo 3 write target.
8. `doctor.nome` nel payload → reject.
9. `nome` root mancante → reject.
10. Post-copia mismatch assistitoId → verifica fallita.

## Regola di avanzamento

Il prossimo fix operativo può introdurre solo il reader legacy bounded da CF manuali.

Non è ancora ammesso:

- UI completa di copia reale;
- write reale da dati legacy;
- switch letture frontend;
- backend GAS tenant-aware;
- copia famiglia;
- copia massiva.
