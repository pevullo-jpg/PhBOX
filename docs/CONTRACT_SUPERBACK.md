# CONTRACT_SUPERBACK

## Stato

PhBOX main introduce un primo gate frontend in sola lettura verso SuperBack.

Questa fase non migra dati clinici, non modifica backend GAS e non cambia i path operativi root esistenti.

## Owner della verità

| Dato | Owner |
|---|---|
| accesso frontend farmacia | `tenant_access/{loginEmail}` |
| stato backend farmacia | `tenant_control/{tenantId}` |
| dati clinici PhBOX | PhBOX legacy root collections, fino a migrazione dedicata |
| Gmail/Drive/PDF lifecycle | backend GAS PhBOX |

## Contratto letto da PhBOX frontend

Documento:

```text
tenant_access/{loginEmail}
```

Campi letti:

```text
loginEmail: string
tenantId: string
tenantName: string
frontendEnabled: boolean
tenantStatus: active|blocked
subscriptionStatus: trial|active|suspended|expired
updatedAt: ISO string
updatedBy: string
schemaVersion: number
```

## Semantica accesso

Il frontend PhBOX consente ingresso solo se:

```text
frontendEnabled == true
tenantStatus == active
subscriptionStatus == active || subscriptionStatus == trial
```

In tutti gli altri casi mostra pagina di blocco accesso.

## Costi Firestore

| Flusso | Reads |
|---|---:|
| login/reload farmacia | 1 read `tenant_access/{loginEmail}` |
| utente non loggato | 0 read Firestore |
| accesso negato | 1 read `tenant_access/{loginEmail}` |
| app caricata | letture legacy già esistenti |

Non vengono introdotti listener Firestore o polling.

## Fuori scope

- Nessuna migrazione a `tenants/{tenantId}/...`.
- Nessuna modifica a `patients`.
- Nessuna modifica a `patient_dashboard_index`.
- Nessuna modifica a `drive_pdf_imports`.
- Nessuna modifica a `dashboard_totals`.
- Nessuna modifica a backend GAS.
- Nessuna chiamata Gmail/Drive/PDF.
- Nessun cambio ai writer backend-owned.

## Fasi successive

1. Validare gate login frontend.
2. Introdurre tenant context centralizzato.
3. Switch graduale letture frontend verso `tenants/{tenantId}/...`.
4. Switch graduale writer backend GAS.
5. Migrazione dati solo con copia, verifica, switch letture, switch scritture, archiviazione legacy.
