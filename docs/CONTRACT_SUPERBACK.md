# CONTRACT_SUPERBACK

## Stato evidenze

PhBOX integra SuperBack in modo progressivo e read-only tramite Firestore.

Questo contratto riguarda solo il gate frontend farmacia basato su:

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
utente non anonimo
email Firebase normalizzata non vuota
provider Firebase password presente con provider.email non vuota e coerente
sessione confermata localmente da signInWithEmailAndPassword
frontendEnabled == true
tenantStatus == active
subscriptionStatus == active OR subscriptionStatus == trial
```

Sessioni non valide prima della lettura `tenant_access`:

```text
utente non loggato
utente anonimo
email Firebase vuota
provider password assente
provider.email assente o non coerente con email Firebase
sessione ripristinata/non confermata da signInWithEmailAndPassword
sessione email-link o comunque non generata dalla form email/password PhBOX
```

Comportamento UI per sessioni non valide prima di `tenant_access`:

```text
cancellare marker locale
eseguire signOut Firebase
mostrare direttamente TenantLoginPage
nessun pannello errore
nessuna read Firestore
```

Comportamento UI per login email/password non riuscito:

```text
restare su TenantLoginPage
non mostrare pannelli errore
non leggere tenant_access
non scrivere Firestore
```

Accesso negato dopo 1 read `tenant_access/{loginEmail}` se:

```text
tenant_access/{loginEmail} assente
frontendEnabled == false
tenantStatus != active
subscriptionStatus non in [active, trial]
lettura tenant_access fallita
```

In questi casi resta ammessa la schermata `TenantAccessDeniedPage`, perché il login è valido ma l'autorizzazione SuperBack è negata o non leggibile.

## Nota su email-link

Il client Firebase usa provider ID `password` anche per scenari email-link. Per evitare che una sessione email-link passi il gate, PhBOX non si basa solo su `providerId`.

Il gate accetta la sessione solo se il login è stato completato dalla form PhBOX tramite:

```text
FirebaseAuth.signInWithEmailAndPassword
```

Il marker locale persistente consente il refresh senza richiedere di nuovo la password, ma è valido solo se `uid` ed email normalizzata coincidono con l'utente Firebase corrente.

## Costi Firestore

| Flusso | Reads |
|---|---:|
| login email/password valido | 1 read `tenant_access/{loginEmail}` |
| refresh dopo login email/password valido | 1 read `tenant_access/{loginEmail}` |
| retry manuale accesso dopo sessione confermata | 1 read `tenant_access/{loginEmail}` |
| utente non loggato | 0 reads |
| sessione anonima | 0 reads |
| provider password assente/incoerente | 0 reads |
| sessione non confermata da form email/password | 0 reads |
| sessione locale non valida ripulita verso login | 0 reads |
| login email/password non riuscito | 0 reads |
| backend auth status | invariato, letto solo dopo accesso tenant consentito |

## Dipendenze

`firebase_auth` è necessario per autenticazione email/password e futura compatibilità con Firestore Rules basate su `request.auth`.

`google_sign_in` resta temporaneamente in `pubspec.yaml` perché esiste codice legacy esterno al gate tenant che lo importa. Il gate tenant non usa Google OAuth e `web/index.html` non deve iniettare `google-signin-client_id`.

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
