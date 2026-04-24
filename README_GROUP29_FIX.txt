GROUP 29 FIX

Fix sessione Google Drive per scansione e analisi PDF.

Modifiche:
- non considera più "collegato" solo l'email salvata
- ripristino silenzioso sessione Drive quando manca il token in memoria
- helper centralizzato per ottenere access token valido prima di scansione/analisi
- messaggio UI più coerente: account salvato ma sessione da verificare
- servizio auth con metodo ensureDriveSession

Obiettivo:
- evitare errore "Collega prima un account Google" quando l'account risulta salvato ma il token non è stato ripristinato.
