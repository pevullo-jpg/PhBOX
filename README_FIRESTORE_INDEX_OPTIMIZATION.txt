PhBOX Firestore index optimization

- Cards totali: listener solo su dashboard_totals/main.
- Liste dashboard richieste dall'utente: query su patient_dashboard_index, non su collezioni grezze globali.
- Apertura card Debiti: patient_dashboard_index where hasDebt == true, limit 120.
- Apertura card Anticipi: patient_dashboard_index where hasAdvance == true, limit 120.
- Apertura card Prenotazioni: patient_dashboard_index where hasBooking == true, limit 120.
- Dettagli grezzi del singolo assistito vengono letti solo quando l'utente apre il flag/riga specifica.
- Prima installazione: eseguire nel backend rebuildPhboxPatientDashboardIndex().
