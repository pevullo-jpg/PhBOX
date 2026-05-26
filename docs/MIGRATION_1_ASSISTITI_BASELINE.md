# Migration 1 — Assistiti target baseline post-refactor

## Stato

Baseline accettata dopo il merge di Fix #284.

- Main HEAD validato: `81da2fd506b424879f2fee642cbdd5b42eed9db7`
- Fix precedente: `#284 reduce assistiti preview mapping entropy`
- Scopo di questo documento: congelare il comportamento accettato prima degli step successivi della Migration 1.

## Owner della verità

- Legacy assistiti: sorgente storica da cui leggere dati bounded.
- Target multitenant: destinazione canonica della migrazione.
- CF lock target: vincolo atomico anti-duplicazione per codice fiscale.
- Mapper assistiti: unico punto puro per normalizzazione/mapping preview target.
- Reader preview: solo orchestratore di letture bounded e duplicate guard.

## Contratto target assistiti accettato

Il payload target generato dalla preview/copia deve contenere, salvo mappe vuote dove ammesso:

- `assistitoId`
- `cf`
- `fullName`
- `cognome`
- `nome`
- `createdAt`
- `updatedAt`
- `dashboard`
- `nameSplitConfidence`
- `searchPrefixes`
- `doctor`
- `therapeuticAdvice`

Nota operativa: `updatedAt` e `searchPrefixes` restano obbligatori finché writer/sink li validano.

## Regole identità

- CF valido da solo: accettabile.
- Nome solo: accettabile se normalizzato.
- Cognome solo: accettabile se normalizzato.
- FullName valido: accettabile.
- Nessun CF/nome/cognome/fullName valido: non accettabile.
- Due assistiti con stesso CF: non accettabili.
- Alias/famiglia/dashboard non devono mai diventare `nome` o `cognome`.
- Campi doctor non devono mai diventare identità assistito.

## Baseline reale validata

### CRPGNN48B19D514Z

Output accettato:

- `nome = Giovanni`
- `cognome = Crapanzano`
- `fullName = Giovanni Crapanzano`
- `searchPrefixes` presenti
- `doctor.manual` preservato
- `therapeuticAdvice.updatedAt` presente

### VLLGPP84H27A089I / equivalente Vullo Giuseppe

Output atteso/accettato:

- `nome = Giuseppe`
- `cognome = Vullo`
- `searchPrefixes` presenti se `fullName` valido
- nessuna contaminazione doctor con identità assistito

## Dashboard snapshot

La mappa `dashboard` deve restare limitata ai soli campi operativi:

- `advanceCount`
- `bookingCount`
- `debtAmount`
- `debtCount`
- `exemptionCode`
- `exemptions`
- `hasAdvance`
- `hasBooking`
- `hasDebt`
- `hasDpc`
- `hasExpiry`
- `hasRecipes`
- `lastPrescriptionDate`
- `nearestExpiryDate`
- `recipeCount`

Campi vietati nel dashboard target:

- `alias`
- `familyId`
- `familyColorIndex`
- `doctorFullName`
- `source`
- `schemaVersion`
- `updatedAt`

## Doctor payload

`doctor.manual` e `doctor.primary` devono essere preservati quando validi.

Sono ammessi solo campi medico legacy sicuri e scalari, tra cui:

- `doctorId`
- `doctorCode`
- `doctorName`
- `doctorFullName`
- `doctorFiscalCode`
- `doctorLicense`
- `doctorPhone`
- `doctorEmail`
- `medicoId`
- `medicoCodice`
- `medicoNome`
- `medicoCognome`
- `medicoFullName`
- `medicoCodiceFiscale`
- `medicoTelefono`
- `medicoEmail`
- `specialization`
- `specializzazione`

Qualsiasi valore che replica CF, nome, cognome o fullName assistito deve essere filtrato.

## Therapeutic advice

`therapeuticAdvice` deve preservare i campi non-identità.

Devono essere esclusi i campi identità o metadata non utili alla migrazione target, tra cui:

- `cf`
- `fiscalCode`
- `codiceFiscale`
- `nome`
- `cognome`
- `firstName`
- `givenName`
- `lastName`
- `surname`
- `familyName`
- `fullName`
- `displayName`
- `patientName`
- `assistitoName`
- `name`
- `alias`
- `familyId`
- `familyColorIndex`
- `doctorFullName`
- `source`
- `schemaVersion`
- `searchPrefixes`

`updatedAt` deve essere preservato se presente.

## Divieti anti-regressione

Durante Migration 1, salvo fix esplicitamente autorizzato, è vietato:

- scrivere su `patients`
- scrivere su `patient_dashboard_index`
- scrivere su `patient_therapeutic_advice`
- scrivere su `doctor_patient_links`
- scrivere su `drive_pdf_imports`
- cancellare sorgenti legacy
- modificare Gmail/Drive/PDF lifecycle
- introdurre listener, polling o collectionGroup
- introdurre trigger o chiamate a `runPhboxBackendSimple`
- cambiare writer/verifier senza dichiarare nuovo contratto

## Test gate per step successivi

Prima di procedere oltre la Migration 1:

- `flutter analyze`
- `flutter test`
- `flutter build web --release --base-href /PhBOX/`
- test mapper dedicati
- test reale su almeno due CF già validati
- verifica manuale assenza write legacy
- verifica dashboard invariata

## Regola operativa

Da questa baseline in poi:

- 1 fix = 1 step
- P1/P2 = stop
- conflitto = rigenerare da main HEAD
- ogni modifica al mapping assistiti deve aggiornare o aggiungere test mapper mirati
- nuove funzioni di migrazione read-only devono restare bounded
- nuove funzioni con write reali devono dichiarare max write e rollback operativo
