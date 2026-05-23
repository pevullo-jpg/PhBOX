# CONTRACT_TARGET_MULTITENANT_FIRESTORE

## Scopo

Questo documento definisce la struttura Firestore target per PhBOX multifarmacia.

Il contratto è solo preparatorio: non abilita copie reali, non abilita migrazioni, non cambia path runtime, non modifica backend GAS e non tocca Gmail/Drive/PDF.

## Principio guida

Legacy PhBOX 0.2 e nuova struttura multifarmacia devono restare separati.

```text
Legacy root collections = operative, intoccate
Nuova struttura tenants/{tenantId}/... = target futura, parallela
```

È vietato mischiare dati legacy e dati target nello stesso flusso finché non esiste uno switch esplicito, testato e documentato.

## Raccolte legacy da preservare

Le raccolte root esistenti restano operative e non vengono migrate da questo contratto:

```text
app_settings
dashboard_expiring_recipes
dashboard_totals
drive_pdf_imports
patients
patient_dashboard_index
patient_therapeutic_advice
doctor_patient_links
phbox_runtime
phbox_runtime_manifests
phbox_signals
families
prescription_intakes
parser_reference_values
dashboard_summaries
```

Ogni fix multifarmacia deve dichiarare esplicitamente se modifica una di queste raccolte. In assenza di dichiarazione, sono considerate fuori scope.

## Regola legacy codice fiscale

Nella struttura legacy PhBOX 0.2 il codice fiscale resta dove già è usato come identificativo o componente di path.

Path legacy intoccabili da questo contratto:

```text
patients/{CF}
patient_dashboard_index/{CF}
patient_therapeutic_advice/{CF}
doctor_patient_links/{CF__manual}
doctor_patient_links/{CF__primary}
```

Questo contratto non rinomina, non migra e non corregge questi path legacy.

## Raccolte SuperBack globali

Le raccolte seguenti restano root/globali perché governano il SaaS e non rappresentano dati clinici di una singola farmacia:

```text
tenant_access/{loginEmail}
tenant_control/{tenantId}
tenants_public/{tenantId}
superback_config/main
superback_audit/{auditId}
```

## Struttura target multifarmacia

Root target:

```text
tenants/{tenantId}
```

Sotto ogni tenant:

```text
tenants/{tenantId}/app_settings/main
tenants/{tenantId}/dashboard_expiring_recipes/main
tenants/{tenantId}/dashboard_totals/main
tenants/{tenantId}/drive_pdf_imports/{importId}
tenants/{tenantId}/phbox_runtime/main
tenants/{tenantId}/phbox_runtime_manifests/{manifestId}
tenants/{tenantId}/phbox_signals/{signalId}
tenants/{tenantId}/assistiti/{assistitoId}
```

## Regole tenantId

`tenantId` è una chiave tecnica stabile.

Non deve dipendere dal nome commerciale modificabile della farmacia.

Esempi ammessi:

```text
farmacia_santa_venera
farmacia_rossi_agrigento
tenant_001
```

Esempi da evitare:

```text
Farmacia Santa Venera
FARMACIA X
ASSISTITI FARMACIA X
```

## Assistiti target

La raccolta target assistiti è:

```text
tenants/{tenantId}/assistiti/{assistitoId}
```

Questa struttura assorbirà in futuro, solo tramite fix dedicati e validati, le informazioni oggi distribuite tra:

```text
patients
patient_dashboard_index
patient_therapeutic_advice
doctor_patient_links
```

## Regole assistitoId target

`assistitoId` è l'identificativo tecnico del documento target.

Regole obbligatorie:

```text
assistitoId = documentId tecnico/opaco
generazione = Firestore auto-id o generatore tecnico equivalente
origine vietata = codice fiscale, nome, cognome, email, telefono o altri dati personali
semantica = nessun significato clinico/anagrafico
stabilità = persistente dopo creazione del documento
```

`assistitoId` non deve derivare da `cf` e non deve essere calcolabile a partire da dati personali.

Il campo `assistitoId` salvato nel documento deve coincidere con il documentId:

```text
tenants/{tenantId}/assistiti/{assistitoId}.assistitoId == assistitoId
```

In assenza di uno switch esplicito e validato, nessun runtime deve creare, leggere o scrivere documenti target `assistiti`.

## Regole cf target

`cf` nella struttura target è solo un campo dati.

Regole obbligatorie:

```text
cf != documentId
cf non governa il path
cf non garantisce unicità documentale
cf non è chiave tecnica primaria
cf può essere usato solo per ricerca, deduplica controllata o riconciliazione dichiarata
cf deve essere normalizzato in maiuscolo
cf deve comparire solo nel campo cf
```

È vietato propagare il codice fiscale in:

```text
nome
cognome
fullName
searchPrefixes
doctor
dashboard
therapeuticAdvice
```

Ogni futuro processo di deduplica basato su `cf` dovrà essere esplicito, bounded, testato e separato dalla generazione di `assistitoId`.

## Documento assistito target

Campi target minimi:

```text
assistitoId: string
cf: string
nome: string
cognome: string
fullName: string
nameSplitConfidence: string
searchPrefixes: array<string>
doctor: map
dashboard: map
therapeuticAdvice: map
createdAt: timestamp
updatedAt: timestamp
sourceVersion: number
```

Semantica campi:

```text
assistitoId = id tecnico/opaco, uguale al documentId target
cf = codice fiscale normalizzato come dato anagrafico, non id documento
nome = nome proprio normalizzato, se disponibile da fonte affidabile
cognome = cognome normalizzato, se disponibile da fonte affidabile
fullName = nome visualizzabile normalizzato, mai derivato da OCR-fragment o CF-like token
nameSplitConfidence = qualità dello split nome/cognome
searchPrefixes = prefissi bounded generati da nome/cognome/fullName valido, mai da cf
doctor = mappa medico consolidata secondo precedenza dichiarata
dashboard = mappa dashboard target, senza campi identità duplicati
therapeuticAdvice = mappa consiglio terapeutico target
createdAt = timestamp creazione target o origine controllata
updatedAt = timestamp aggiornamento target o origine controllata
sourceVersion = versione del mapping/contratto sorgente
```

Valori ammessi per `nameSplitConfidence`:

```text
explicit_fields = nome/cognome arrivano da campi sorgente separati e normalizzati
unverified_full_name = esiste solo fullName normalizzato, senza split forzato
fallback = nessun nome valido disponibile
```

## Normalizzazione identità target

La normalizzazione deve essere unica e riusabile sia per la copia target sia per futuri inserimenti.

Regole obbligatorie:

```text
cf = trim + rimozione spazi + maiuscolo
nome = trim + whitespace singolo + minuscolo con prima lettera maiuscola per ogni token
cognome = trim + whitespace singolo + minuscolo con prima lettera maiuscola per ogni token
fullName = derivato controllato dai campi normalizzati o da fullName valido
searchPrefixes = derivati solo da nome/cognome/fullName valido
```

Esempi:

```text
rssmra80a01h501u -> RSSMRA80A01H501U
mario -> Mario
ROSSI -> Rossi
mArIa gRaZiA -> Maria Grazia
de luca -> De Luca
d'amico -> D'Amico
```

Regole anti-inversione:

```text
nome/cognome separati solo se la sorgente fornisce campi separati affidabili
se la sorgente contiene solo fullName ambiguo, non forzare split cieco
se lo split non è certo, usare fullName e nameSplitConfidence = unverified_full_name
```

## Assenze/parziali

```text
assistitoId assente = documento target non valido
cf assente/parziale = campo dati incompleto, non blocca l'identità tecnica
nome/cognome assenti = split non disponibile
fullName assente/non valido = fallback dichiarato, senza searchPrefixes
mappe assenti = mappe vuote
sourceVersion assente = documento target incompleto
```

## Runtime target

```text
tenants/{tenantId}/phbox_runtime/main
tenants/{tenantId}/phbox_runtime_manifests/{manifestId}
tenants/{tenantId}/phbox_signals/{signalId}
```

Regole:

- `phbox_runtime/main` governa lo stato runtime del tenant.
- `phbox_signals` contiene segnali bounded.
- `phbox_runtime_manifests` contiene manifest legati al tenant.
- Nessun frontend deve creare trigger backend.
- Nessun frontend deve chiamare `runPhboxBackendSimple`.

## Drive/PDF target

```text
tenants/{tenantId}/drive_pdf_imports/{importId}
```

Owner primario: backend GAS.

Il frontend potrà eventualmente emettere solo patch bounded di richiesta, se il contratto specifico lo consente.

Non sono ammessi nel frontend:

```text
OCR metadata writes
merge metadata writes
rename metadata writes
archive lifecycle writes
Drive destructive writes
PDF lifecycle calls
```

## Sequenza di adozione

La sequenza ammessa è:

```text
1. Documentare struttura target
2. Tenere legacy operativo
3. Tenere resolver in legacyRoot
4. Preparare adapter repository
5. Agganciare repository uno per volta in legacyRoot
6. Creare writer target opzionale/dry-run
7. Confrontare legacy vs target
8. Eseguire copie target limitate, guarded e non distruttive
9. Abilitare letture target per un modulo isolato
10. Abilitare scritture target per lo stesso modulo
11. Aggiornare backend GAS tenant-aware
12. Solo dopo validazione, dismettere progressivamente legacy
```

## Divieti espliciti

Finché questo contratto non viene attivato da fix successivi, è vietato:

```text
spostare dati legacy
cancellare dati legacy
rinominare raccolte legacy
scrivere simultaneamente senza dichiarazione
leggere tenants/{tenantId}/... come fonte primaria
aggiornare backend GAS per target paths
modificare Gmail/Drive/PDF lifecycle
introdurre listener Firestore aggiuntivi
introdurre polling automatico aggiuntivo
derivare assistitoId da codice fiscale
derivare assistitoId da nome/cognome/email/telefono o altri dati personali
usare cf come documentId target
scrivere cf in nome/cognome/fullName/searchPrefixes
forzare split nome/cognome da fullName ambiguo
```

## Impatto costi previsto

Questo documento non introduce costi runtime.

```text
reads/h: 0
writes/h: 0
listener: 0
query: 0
fan-out: 0
```

## Invarianti anti-regressione

- Legacy PhBOX continua a funzionare su root collections.
- La nuova struttura target è parallela.
- Nessun dato clinico viene migrato da questo contratto.
- Nessun repository cambia path da questo contratto.
- SuperBack root collections restano globali.
- `tenant_access` resta il gate frontend.
- `tenant_control` resta destinato al backend.
- `tenants/{tenantId}/assistiti/{assistitoId}` è la destinazione futura per dati assistito unificati.
- `assistitoId` target è tecnico, opaco e non derivato da dati personali.
- `cf` target è solo campo dati e non è documentId.
- `cf` non deve contaminare nome, cognome, fullName o searchPrefixes.
- Ogni switch deve essere modulare, reversibile e testato.

## Test richiesti per ogni futuro switch/copia

Prima di attivare letture, scritture o copie target:

```text
conteggio legacy == conteggio target atteso
campi critici presenti
assistitoId presente e uguale al documentId target
assistitoId non derivato da cf/nome/cognome/email/telefono
cf presente come campo dati quando disponibile
cf non usato come documentId target
cf non presente in nome/cognome/fullName/searchPrefixes
nome/cognome normalizzati quando disponibili da campi affidabili
fullName normalizzato e non CF-like
searchPrefixes derivati da nome valido, non da cf
dashboard coerente e senza duplicazione campi identità
doctor link preservato
therapeutic advice preservato
nessun placeholder elevato a nome valido
nessun path legacy cancellato
nessun aumento Firestore non dichiarato
```

## Stato del contratto

```text
versione: 0.5-target-draft-clean-identity
stato: preparatorio
runtime: non attivo
copia target: non avviata
migrazione: non avviata
backend GAS: non modificato
Gmail/Drive/PDF: non modificati
```
