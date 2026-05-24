# PhBOX Fix #236 — QA manuale Target Assistiti Read-Only

## Scope

Questa checklist valida la pagina isolata `Assistiti target` introdotta in Fix #235.

Il test è solo manuale/QA.

Non modifica runtime, backend, Firestore, Gmail, Drive o PDF.

## Invarianti

- La dashboard legacy resta la pagina iniziale.
- `TenantPathResolver` resta in modalità `legacyRoot`.
- La pagina target non legge dati in automatico all'apertura.
- La lettura target parte solo dopo click esplicito su `Carica assistiti target`.
- `tenants/{tenantId}/assistiti` può non esistere.
- Collection assente o vuota = stato valido.
- Nessuna write Firestore.
- Nessun listener Firestore.
- Nessun polling.
- Nessuna copia target.
- Nessuna migrazione.
- Nessun backend GAS.
- Nessun Gmail/Drive/PDF.

## Precondizioni

- Branch aggiornato su `main` dopo Fix #235.
- Utente abilitato in `tenant_access/{loginEmail}`.
- Login email/password funzionante.
- `tenants/{tenantId}/assistiti` può essere assente.

## Test automatici minimi

Eseguire:

```bash
flutter analyze
flutter build web --release --base-href /PhBOX/
```

Se disponibile, eseguire anche:

```bash
flutter test test/data/multitenant/legacy_target_assistito_synthetic_test.dart
```

## Checklist manuale UI

### 1. Login e shell legacy

| Step | Azione | Atteso |
|---|---|---|
| 1.1 | Apri app | Login visibile se non autenticato |
| 1.2 | Login email/password | Accesso consentito solo se `tenant_access` valido |
| 1.3 | Dopo login | Dashboard legacy visibile come pagina iniziale |
| 1.4 | Controlla menu flottante | Voce `Assistiti target` presente |
| 1.5 | Non cliccare `Assistiti target` | Nessuna lettura target attesa |

Esito: PASS / FAIL

Note:

---

### 2. Apertura pagina target read-only

| Step | Azione | Atteso |
|---|---|---|
| 2.1 | Clicca `Assistiti target` | Si apre pagina isolata |
| 2.2 | Non premere `Carica assistiti target` | Nessuna query target automatica |
| 2.3 | Verifica testo/stato iniziale | Stato iniziale controllato, nessun errore |
| 2.4 | Verifica console browser | Nessun errore |

Esito: PASS / FAIL

Note:

---

### 3. Lettura manuale con collection assente/vuota

| Step | Azione | Atteso |
|---|---|---|
| 3.1 | Premi `Carica assistiti target` | Parte una sola query bounded |
| 3.2 | Se collection assente | Mostra stato vuoto valido |
| 3.3 | Se collection vuota | Mostra stato vuoto valido |
| 3.4 | Verifica Firestore | Nessuna collection/documento creato |
| 3.5 | Verifica console browser | Nessun errore |

Esito: PASS / FAIL

Note:

---

### 4. Guard anti-click ripetuto

| Step | Azione | Atteso |
|---|---|---|
| 4.1 | Premi rapidamente più volte `Carica assistiti target` | Nessuna sovrapposizione incontrollata |
| 4.2 | Durante loading | Pulsante disabilitato o richiesta ignorata |
| 4.3 | Fine caricamento | Stato coerente |

Esito: PASS / FAIL

Note:

---

### 5. Ritorno a legacy

| Step | Azione | Atteso |
|---|---|---|
| 5.1 | Torna a Dashboard | Dashboard legacy funzionante |
| 5.2 | Ricerca assistiti legacy | Funzionante come prima |
| 5.3 | Totali dashboard | Visibili e invariati |
| 5.4 | Logout | Funzionante |
| 5.5 | Refresh post-login | Funzionante |

Esito: PASS / FAIL

Note:

---

## Controllo Firestore

Durante i test verificare:

| Area | Atteso |
|---|---|
| Read target prima del click | 0 |
| Read target dopo click | massimo 1 query bounded |
| Write target | 0 |
| Listener target | 0 |
| Polling target | 0 |
| Root legacy collections | nessuna modifica causata dalla pagina target |
| `tenant_control` | non letto |
| `tenant_access` | letto solo dal gate login già esistente |

## Criterio merge

Merge consentito solo se:

- `flutter analyze` passa.
- `flutter build web --release --base-href /PhBOX/` passa.
- Codex review non segnala P1/P2.
- La checklist manuale non mostra regressioni.
- Nessuna write Firestore viene prodotta.
- La dashboard legacy resta invariata.

## Esito finale

- PASS:
- FAIL:
- Tester:
- Data:
- Note finali:
