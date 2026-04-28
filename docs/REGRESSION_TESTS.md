# REGRESSION_TESTS

## Scopo
Checklist regressione funzionale focalizzata sui contratti dati e sulle aree ad alto rischio.

## 1) Dashboard e letture ottimizzate
- [ ] Verificare listener su `dashboard_totals/main` aggiornato senza full reload.
- [ ] Verificare ricerca >=3 caratteri su `patient_dashboard_index.searchPrefixes`.
- [ ] Verificare filtri card (debiti/anticipi/prenotazioni/scadenze) senza query globali non necessarie.

## 2) Mutazioni operative + segnali runtime
- [ ] Salvataggio debito crea/aggiorna `patients/{cf}/debts/{id}`.
- [ ] Salvataggio anticipo crea/aggiorna `patients/{cf}/advances/{id}`.
- [ ] Salvataggio prenotazione crea/aggiorna `patients/{cf}/bookings/{id}`.
- [ ] Ogni mutazione emette `phbox_signals/*` con `requiresTotalsUpdate=true` e `requiresIndexUpdate=true`.
- [ ] In caso di errore segnale runtime, il salvataggio dato utente resta riuscito.

## 3) Contratto `drive_pdf_imports` backend-owned
- [ ] Verificare che il frontend non crei record import/archive in `drive_pdf_imports`.
- [ ] Verificare che write stile `saveImport` fallisca per contratto.
- [ ] Verificare che il frontend non scriva parser/OCR metadata, merge metadata, rename metadata, archive mutation o lifecycle fields backend-owned.
- [ ] Verificare `requestPdfDelete` imposti `deletePdfRequested` + metadata richiesta.
- [ ] Verificare che `requestPdfDelete` sia l'unica write frontend consentita su `drive_pdf_imports` (patch delete-request limitata).

## 4) Contratto ibrido dati prescrizioni
- [ ] Se esistono import `drive_pdf_imports` per paziente, UI usa quelli come fonte primaria.
- [ ] Se non esistono import, fallback a legacy `patients/{cf}/prescriptions/*`.

## 5) Migrazione paziente temporaneo
- [ ] Migrazione TMP -> CF reale copia subcollection manuali.
- [ ] Migrazione riallinea `doctor_patient_links`, `patient_therapeutic_advice`, membership `families`.
- [ ] Documento paziente temporaneo viene rimosso a fine batch.

## 6) Settings e backup
- [ ] Salvataggio impostazioni su `app_settings/main` (`expiryWarningDays`, `doctorsCatalog`).
- [ ] Export backup include collezioni previste e conteggi coerenti.

## Aree con rischio regressione alto
- Fallback multipli in `PhboxContractUtils`.
- Pipeline PDF frontend (servizi esistenti) vs blocco write su `drive_pdf_imports`.
- Coerenza eventuale tra dato utente, index dashboard e totali.
- Assenza backend GAS nel repository: dettagli end-to-end Gmail/Drive/PDF da considerare **DA VERIFICARE**.
