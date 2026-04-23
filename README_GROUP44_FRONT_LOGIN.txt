FRONTEND — LOGIN FIREBASE + TENANT_ACCESS + GATING FRONTEND

OBIETTIVO
Introdurre login nel frontend PhBOX senza esporre backendEnabled e senza creare dipendenze dirette col backend.

FLUSSO
1. utente farmacia fa login con Firebase Auth email/password
2. frontend legge tenant_access/{email}
3. frontend risolve tenantId
4. frontend legge tenants_public/{tenantId}
5. se frontendEnabled=false o tenantStatus=blocked => accesso negato
6. se accesso consentito => sessione tenant attiva
7. tutte le repository Firebase passano dal resolver tenant-aware

INVARIANTI
- frontend non legge mai tenant_control
- backendEnabled resta fuori dal frontend
- DB resta unica fonte di verità
- logout resetta sessione tenant e navigazione
- accesso frontend determinato solo da tenant_access + tenants_public

CAMPI MINIMI RICHIESTI
tenant_access/{email}
- tenantId
- pharmacyEmail
- frontendEnabled
- tenantStatus
- subscriptionStatus
- tenantName
- dataRootPath (opzionale)

tenants_public/{tenantId}
- frontendEnabled
- tenantStatus
- subscriptionStatus
- tenantName
- pharmacyEmail

NOTE SU dataRootPath
- se assente o vuoto, il frontend usa il root legacy attuale
- se valorizzato, il frontend prefissa i path applicativi con quel root
- uso previsto futuro: separazione tenant completa senza rompere il dataset attuale

TEST
1. login con utente presente in Firebase Auth
2. tenant_access presente => accesso consentito
3. tenant_access assente => schermata accesso non configurato
4. frontendEnabled=false => frontend bloccato
5. tenantStatus=blocked => frontend bloccato
6. logout => ritorno alla login
