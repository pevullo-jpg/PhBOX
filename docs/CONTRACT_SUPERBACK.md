# CONTRACT_SUPERBACK

## Stato evidenze

PhBOX integra SuperBack in modo progressivo e read-only tramite Firestore.

Questo fix usa Firebase Authentication email/password come livello di autenticazione e `tenant_access/{loginEmail}` come livello di autorizzazione frontend.

Non introduce migrazioni dati, non modifica backend GAS e non tocca Gmail/Drive/PDF.

## Owner della verità

| Dato | Owner |
|---|---|
| account farmacia autenticato | Firebase Authentication email/password |
| account farmacia autorizzato | `tenant_access/{loginEmail}` |
| abilitazione frontend | `tenant_access/{loginEmail}.frontendEnabled` |
| stato tenant | `tenant_access/{loginEmail}.tenantStatus` |
| stato abbonamento | `tenant_access/{loginEmail}.subscriptionStatus` |
| abilitazione backend | `tenant_control/{tenantId}` — non letto dal frontend PhBOX |
| dati clinici PhBOX legacy | raccolte root attuali, non migrate in questo fix |
| dati clinici PhBOX target | `tenants/{tenantId}/...`, fase futura separata |

## Contratto tenant_access

Documento:

```text
tenant_access/{loginEmailLowercase}
```

Campi letti dal frontend PhBOX:

```text
loginEmail: string
tenantId: string
tenantName: string
frontendEnabled: boolean
tenantStatus: active|blocked
subscriptionStatus: trial|active|suspended|expired
schemaVersion: number
```

## Semantica accesso frontend

Accesso consentito solo se:

```text
FirebaseAuth user presente
utente non anonimo
provider Firebase password presente
email Firebase normalizzata non vuota
email provider password non vuota e coerente con email Firebase
ID token Firebase con signInProvider == password
frontendEnabled == true
tenantStatus == active
subscriptionStatus == active OR subscriptionStatus == trial
```

Accesso negato se:

```text
tenant_access/{loginEmail} assente
frontendEnabled == false
tenantStatus != active
subscriptionStatus non in [active, trial]
utente anonimo
email Firebase assente o non verificabile
provider password assente
email provider password incoerente
ID token Firebase con signInProvider diverso da password, incluso email-link
lettura tenant_access fallita
```

## Costi Firestore

| Flusso | Reads |
|---|---:|
| login/reload con utente email/password valido | 1 read `tenant_access/{loginEmail}` |
| retry manuale accesso | 1 read `tenant_access/{loginEmail}` |
| accesso negato per sessione anonima/provider non password | 0 reads |
| accesso negato per email vuota/non coerente | 0 reads |
| accesso negato per signInProvider diverso da password | 0 reads |
| backend auth status | invariato, letto solo dopo accesso tenant consentito |

## Identità accettata

Il frontend PhBOX considera valido solo un utente Firebase Authentication email/password con provider `password`, email Firebase normalizzata non vuota, email provider coerente e ID token Firebase con `signInProvider == password`. Questo controllo respinge sessioni email-link prima della lettura `tenant_access`.

Google OAuth non è usato in questo flusso. PhBOX non richiede Web OAuth Client ID e non usa `google-signin-client_id`.

## Invarianti anti-regressione

- PhBOX frontend non legge `tenant_control`.
- PhBOX frontend non scrive `tenant_access`.
- PhBOX frontend non scrive `tenant_control`.
- PhBOX frontend non scrive `tenants_public`.
- PhBOX frontend non scrive `superback_audit`.
- Nessuna migrazione verso `tenants/{tenantId}/...` in questo fix.
- Le raccolte legacy root restano in uso dopo accesso consentito.
- Nessuna modifica a `patients`, `patient_dashboard_index`, `drive_pdf_imports`, `dashboard_totals`.
- Nessuna modifica a backend GAS.
- Nessuna chiamata Gmail/Drive/PDF.
- Nessun listener Firestore e nessun polling automatico.

## Fasi future

1. Stabilizzare il gate frontend con test reali.
2. Introdurre tenant path resolver in sola lettura.
3. Migrare dati per moduli con sequenza copia → verifica → switch letture → switch scritture.
4. Solo dopo, aggiornare backend GAS per scrivere sotto `tenants/{tenantId}/...`.

## Nota dipendenze auth

La dipendenza `google_sign_in` può restare nel progetto finché esistono servizi legacy che la importano, ma non è usata dal login tenant introdotto da questo gate. Il login tenant usa esclusivamente `FirebaseAuth.signInWithEmailAndPassword` e il gate verifica anche `IdTokenResult.signInProvider == password`.
