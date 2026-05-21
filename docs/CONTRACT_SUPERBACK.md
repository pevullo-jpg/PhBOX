# CONTRACT_SUPERBACK

## Stato evidenze

PhBOX integra SuperBack in modo progressivo e read-only tramite Firestore.

Questo fix introduce solo il gate frontend farmacia basato su:

```text
tenant_access/{loginEmail}
```

Non introduce migrazioni dati, non modifica backend GAS e non tocca Gmail/Drive/PDF.

## Owner della verità

| Dato | Owner |
|---|---|
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
provider Firebase == google.com
email Google normalizzata non vuota
email Firebase verificata
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
email Google assente o non verificabile
lettura tenant_access fallita
```

## Costi Firestore

| Flusso | Reads |
|---|---:|
| login/reload con utente Google | 1 read `tenant_access/{loginEmail}` |
| retry manuale accesso | 1 read `tenant_access/{loginEmail}` |
| accesso negato per sessione non Google/email non verificata | 0 reads |
| accesso negato per email vuota | 0 reads |
| backend auth status | invariato, letto solo dopo accesso tenant consentito |

## Identità accettata

Il frontend PhBOX considera valido solo un utente Firebase con provider `google.com`, email normalizzata non vuota ed email verificata.
Sessioni Firebase diverse da Google, anonime o con email non verificata vengono bloccate prima della lettura `tenant_access`.

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
