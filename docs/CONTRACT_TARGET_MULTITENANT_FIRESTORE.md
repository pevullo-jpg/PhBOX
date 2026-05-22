# CONTRACT_TARGET_MULTITENANT_FIRESTORE

## Scopo

Questo documento definisce la struttura Firestore target per PhBOX multifarmacia.

Il contratto è solo preparatorio: non abilita migrazioni, non cambia path runtime, non modifica backend GAS e non tocca Gmail/Drive/PDF.

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

Campi target minimi:

```text
fiscalCode: string
fullName: string
searchPrefixes: array<string>
doctor: map
dashboard: map
therapeuticAdvice: map
createdAt: timestamp
updatedAt: timestamp
sourceVersion: number
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
8. Abilitare letture target per un modulo isolato
9. Abilitare scritture target per lo stesso modulo
10. Aggiornare backend GAS tenant-aware
11. Solo dopo validazione, dismettere progressivamente legacy
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
- `tenants/{tenantId}/assistiti` è la destinazione futura per dati assistito unificati.
- Ogni switch deve essere modulare, reversibile e testato.

## Test richiesti per ogni futuro switch

Prima di attivare letture o scritture target:

```text
conteggio legacy == conteggio target
campi critici presenti
dashboard coerente
doctor link preservato
therapeutic advice preservato
nessun placeholder elevato a nome valido
nessun path legacy cancellato
nessun aumento Firestore non dichiarato
```

## Stato del contratto

```text
versione: 0.3-target-draft
stato: preparatorio
runtime: non attivo
migrazione: non avviata
backend GAS: non modificato
Gmail/Drive/PDF: non modificati
```
