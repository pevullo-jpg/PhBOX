GRUPPO FUNZIONALE 21

Obiettivo:
- trasformare le intake PDF in dati reali app
- creare/aggiornare automaticamente patients
- creare automaticamente prescriptions
- aggiornare la dashboard con i dati estratti

Cosa fa:
1. legge la collection prescription_intakes
2. per ogni intake crea o aggiorna il patient
3. crea la prescription collegata al fiscal code
4. marca l'intake come imported
5. dashboard e scadenze iniziano a popolarsi con dati reali

Nuovi stati intake:
- imported

Nota:
- il parser PDF resta euristico
- questo blocco è il primo ciclo completo PDF -> dati app
