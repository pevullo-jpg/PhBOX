FRONTEND — RIDUZIONE LETTURE FIRESTORE / DASHBOARD POLLING SELETTIVO

Obiettivo:
- ridurre drasticamente le letture Firestore
- lasciare aggiornamento automatico solo alle cards in cima
- caricare i dati di dettaglio solo su richiesta utente
- azzerare ricerca e selezioni dopo 3 minuti

Modifiche principali:
1. Dashboard:
   - auto-refresh ogni 30s mantenuto solo sulla dashboard
   - _load() alleggerito: legge solo patients + families + app_settings
   - cards e righe base costruite dai dati aggregati presenti su patients
   - dettagli ricette / debiti / anticipi / prenotazioni caricati lazy solo al click

2. Patient detail:
   - rimosso auto-refresh periodico
   - doctor links letti per singolo assistito, non più globalmente

3. Families:
   - rimosso auto-refresh periodico

4. Settings:
   - rimosso auto-refresh periodico

5. Datasource / repository:
   - aggiunte query where ==
   - getImportsByPatient() ora tenta query mirata; fallback legacy solo se necessario
   - getLinksForPatient() ora tenta query mirata; fallback legacy solo se necessario

6. Stato transitorio dashboard:
   - filtri cards / ricerca / ricerca nei flag si azzerano dopo 3 minuti

Rischio residuo:
- le cards DPC / anticipi / prenotazioni in modalità base usano aggregati da patient; se alcuni aggregati non sono perfettamente mantenuti dal backend, il dettaglio al click resta corretto ma il numero base può essere meno preciso del caricamento full-scan precedente.
- non verificato con build runtime in questo ambiente.

Test esatto:
1. apri dashboard e lascia una sola tab aperta
2. verifica aggiornamento orologio refresh ogni 30s
3. verifica che cards restino aggiornate
4. clicca ricette / dpc / debiti / anticipi / prenotazioni e verifica caricamento dettaglio al click
5. apri patient detail e verifica assenza di refresh automatici continui
6. lascia ricerca o filtro attivo per oltre 3 minuti e verifica reset automatico
7. controlla nel grafico Firebase che le read/ora calino nettamente
