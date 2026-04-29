PHBOX BACKEND — RUNTIME INDEX UNICO + FIRESTORE COMMIT UNICO

ARCHITETTURA
1. Gmail ingest
   - scarica tutti i PDF veri
   - nessun side effect sulle email
   - registra il PDF nel runtime index unico

2. Analisi PDF
   - OCR + parsing una sola volta per file
   - classificazione valida / non ricetta
   - le non ricette vengono cestinate subito

3. Merge CF
   - un solo canonico finale per CF
   - i componenti diventano merged_component e vengono cestinati
   - prescriptionCount del canonico = numero ricette rappresentate

4. Rename finale
   - solo PDF finali attivi
   - naming canonico: CF_DATA[_DPC].pdf

5. Delete frontend
   - una sola lettura Firestore per run: drive_pdf_imports con deletePdfRequested = true
   - il backend cestina il PDF e aggiorna lo stato runtime

6. Publish Firestore
   - una sola write request per run: documents:commit
   - collezioni finali preservate:
     - drive_pdf_imports
     - patients
     - doctor_patient_links

7. Finalize Gmail
   - solo dopo publish Firestore
   - processed se almeno un PDF del thread è valido e tutti sono terminali
   - rejected se tutti i PDF del thread sono terminali e tutti non validi

STATO RUNTIME
- non esistono più manifest JSON uno per file nel path principale
- esiste un solo file runtime_index.json nella cartella di sistema
- il file mantiene:
  - filesById
  - threadsById
  - dirty imports/cfs/threads
  - publishState con hash di publish

INVARIANTI
- 1 pagina PDF = 1 ricetta = 1 unità nel flag Ricette
- nessuna email toccata in ingest
- nessuna re-analisi dopo merge
- nessuna non-ricetta in merge/rename/DB attivo
- il frontend continua a leggere le stesse collection Firestore

NOTE OPERATIVE
- SETTINGS.html e le funzioni di settings restano invariate
- il backend supporta migrazione legacy iniziale dai vecchi manifest JSON al runtime index unico
- la prima run dopo il deploy può essere più pesante se trova manifest legacy da migrare


Aggiornamento v1.1
- finalize Gmail ora chiude anche thread senza PDF riconosciuti come no_pdf interno (senza label distruttive)
- ingest salta i messaggi già noti no_pdf per evitare rivalutazioni ripetute
- thread orfani legacy vengono terminalizzati senza tenere acceso needsAnotherRun
- contatore firestore.synced allineato alle unità realmente sincronizzate


DASHBOARD TOTALS / RIDUZIONE LETTURE FRONTEND
- Il backend pubblica automaticamente il documento Firestore dashboard_totals/main durante lo stage firestore_publish.
- Il frontend ottimizzato legge questo solo documento ogni 30 secondi per aggiornare le cards in cima alla dashboard.
- Campi pubblicati: recipeCount, dpcCount, debtAmount, advanceCount, bookingCount, expiringCount, updatedAt.
- recipeCount, dpcCount, expiringCount derivano dal runtime_index Drive, senza letture Firestore aggiuntive.
- debtAmount, advanceCount, bookingCount derivano da aggregazioni Firestore collection-group su debts, advances, bookings.
- Funzione manuale di test: refreshPhboxDashboardTotals().

FIX DASHBOARD TOTALS V1.1.1
- Il calcolo di dashboard_totals/main non pubblica più zeri se il runtime_index è temporaneamente vuoto o non allineato.
- Prima usa runtime_index; se i totali archivio risultano vuoti, usa fallback Firestore mirato su drive_pdf_imports/prescriptions.
- Il documento espone archiveTotalsSource: runtime_index oppure firestore_fallback.

FIX DASHBOARD TOTALS V1.1.2 — NO INDEX REQUIRED PER DEBTS
- Risolto errore Firestore FAILED_PRECONDITION su collection group debts / residualAmount.
- Il backend non usa più di default la SUM aggregation su debts, perché richiede indice COLLECTION_GROUP_ASC su residualAmount.
- Il totale debiti viene calcolato con scan collection-group senza orderBy/filter, quindi non richiede indici custom.
- advanceCount e bookingCount restano su count aggregation; se Firestore richiede indici anche lì, il backend usa fallback scan senza bloccare il run.
- Nuovo campo diagnostico in dashboard_totals/main: appManagedTotalsSource.
- Proprietà opzionale per riattivare la SUM aggregation dopo creazione indice: PHBOX_DASHBOARD_TOTALS_USE_DEBT_AGGREGATION=true.

PHBOX DASHBOARD INDEX V1
- Nuova collezione Firestore: patient_dashboard_index/{CF}
- Il frontend usa questa collezione per aprire le card Debiti/Anticipi/Prenotazioni/Ricette/DPC/Scadenze senza leggere eventi grezzi globali.
- Funzione manuale di primo popolamento/riallineamento completo: rebuildPhboxPatientDashboardIndex()
- Il run backend aggiorna in modo incrementale solo la parte archivio/ricette per i CF sporchi.
- Le parti frontend-owned (debiti, anticipi, prenotazioni, nome assistito) vengono aggiornate subito dal frontend.

PATCH 2026-04-26 - patient_dashboard_index
- Aggiunte funzioni pubbliche GAS:
  - rebuildPatientDashboardIndex()
  - syncPatientDashboardIndexForFiscalCode(cf)
  - validatePatientDashboardIndex()
- rebuildPhboxPatientDashboardIndex() resta alias compatibile.
- La collezione patient_dashboard_index/{CF} viene ricostruita da patients, drive_pdf_imports, prescriptions, doctor_patient_links, debts, advances, bookings, families.
- La pubblicazione Firestore sincronizza patient_dashboard_index per i CF modificati dopo il commit di Stage C.
- La sincronizzazione singolo CF usa query mirate e subcollection patients/{CF}/..., evitando la rilettura completa del database.

RUNTIME SIGNAL GATE
- phbox_runtime/main governa il fast-exit backend.
- status=red: il trigger legge solo il gate e termina.
- status=green: il trigger processa il prossimo phbox_signals pending.
- Funzione setup manuale: initializeRuntimeSignalGateRed().
- Funzione creazione segnale backend: createRuntimeSignal_(payload).
- Domini gestiti in modo puntuale: debts, advances, bookings, deletePdf.

PATCH RUNTIME SIGNAL DELETE TARGET ABSENT
- Per segnali runtime `debts`, `advances`, `bookings` con `operation=delete`, se `targetPath` non esiste più e `targetFiscalCode` è presente, il backend tratta la cancellazione come già applicata.
- In questo caso aggiorna comunque `patient_dashboard_index/{CF}` e `dashboard_totals/main` se richiesto, poi marca il segnale come `done`.
- Resta errore se manca anche il CF, perché non è possibile riallineare il paziente corretto.
