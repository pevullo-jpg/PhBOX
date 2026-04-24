GRUPPO FUNZIONALE 20

Obiettivo:
- scaricare i PDF da Google Drive
- estrarre il testo dal PDF
- creare intake strutturati su Firestore
- aggiornare lo stato delle importazioni Drive

Cosa fa:
1. Scansiona Drive e salva i PDF trovati
2. Analizza i PDF importati
3. Estrae il testo
4. Tenta parsing di:
   - codice fiscale
   - data ricetta
   - DPC
   - nome assistito
   - medico
   - esenzione
5. Salva i risultati in Firestore

Nuova collection:
- prescription_intakes

Nota:
- non crea ancora automaticamente patients/prescriptions in dashboard
- questo è il ponte reale tra PDF e dati strutturati
