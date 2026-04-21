# Family Box — Auth & Entitlement Architecture

## Stato attuale implementato
- Login reale con Firebase Authentication REST (email/password)
- Sessione persistente con refresh token locale
- Entitlement remoto per utente letto/scritto su Cloud Firestore REST
- Trial iniziale di 3 mesi creato al primo accesso dell'account se il documento entitlement non esiste
- Modalità `read_only` automatica a trial scaduto o abbonamento assente
- Storage locale separato per utente (`family_boxes_data_<scope>.json`)
- Override debug accesso nascosto in build debug

## Fonte di verità
- Identità: Firebase Authentication
- Stato accesso: documento Firestore `entitlements/{uid}`
- Dataset economico: file locale scoped-user

## Comportamento offline
- Se il backend non è raggiungibile, Family Box usa l'ultimo entitlement in cache.
- Se non esiste cache valida, entra prudenzialmente in `read_only`.

## Step successivo previsto
- Play Billing trial 3 mesi + annuale
- verifica purchase token server-side
- sostituzione dei debug entitlement con entitlements reali da billing
