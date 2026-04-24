GRUPPO FUNZIONALE 16

Obiettivo:
- primo scanner Drive funzionante
- lettura reale dei PDF dalla cartella Drive configurata
- salvataggio metadati dei PDF trovati su Firestore
- lista risultati nella pagina Impostazioni

ATTENZIONE
- questo blocco NON fa ancora OCR del PDF
- questo blocco NON popola ancora automaticamente i pazienti
- questo blocco salva i PDF trovati in Firestore come importazioni da processare

Nuova collection Firestore:
- drive_pdf_imports

Flusso:
1. collega account Google
2. inserisci cartella Drive PDF in ingresso
3. salva impostazioni
4. premi "Scansiona Drive ora"
5. i PDF trovati vengono salvati in Firestore
