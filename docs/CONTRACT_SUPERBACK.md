# CONTRACT_SUPERBACK

## Stato evidenze
Nel codice non compare il termine “Superback” in classi, endpoint o config.

## Decisione documentale
Questo documento registra solo ciò che è verificabile.

## Contratto con Superback
- Identificativo servizio, URL, auth, payload: **DA VERIFICARE**.
- Mapping responsabilità rispetto a GAS: **DA VERIFICARE**.

## Interfacce indirette potenzialmente correlate
Se “Superback” è il worker backend, i punti di contatto probabili sono:
- Firestore `phbox_signals` / `phbox_runtime`.
- Firestore `drive_pdf_imports` (backend-owned).
- Materializzazioni `dashboard_totals` e `patient_dashboard_index`.

Questa è un’inferenza architetturale, non una prova diretta.

