# RUNBOOK

## 1. Avvio applicazione (locale)
- Prerequisiti Flutter + Firebase configurati.
- Entry point: `lib/main.dart`.
- Firebase project impostato in codice (`phbox-369e8`).

## 2. Diagnostica rapida per inconsistenze dashboard
1. Verificare documento `dashboard_totals/main`.
2. Verificare `patient_dashboard_index/{CF}` del paziente coinvolto.
3. Verificare mutazione sorgente (`debts/advances/bookings` sotto `patients/{CF}`).
4. Verificare presenza segnale in `phbox_signals/*` e stato runtime in `phbox_runtime/main`.

Se mutazione esiste ma aggregati no:
- backlog/backend worker non allineato (**DA VERIFICARE** lato backend).

## 3. Problemi su gestione PDF
- Se una funzione tenta di scrivere `drive_pdf_imports` dal frontend, è comportamento non consentito.
- Uso corretto lato frontend: sola lettura + `requestPdfDelete`.

## 4. Gmail/Drive auth issues
- Verificare Web Client ID Google in impostazioni (se previsto dalla UI web).
- Verificare scope concessi: Drive + Gmail modify.
- Verificare token `Authorization: Bearer ...` disponibile.

## 5. Backup operativo
- Da Impostazioni usare export backup JSON.
- Verificare presenza sezioni `collections` e `counts` nel file esportato.

## 6. Migrazione paziente TMP -> CF
- Eseguire da flusso UI profilo paziente.
- Verificare post-migrazione:
  - nuovo `patients/{CF}` presente,
  - vecchio `patients/{TMP...}` assente,
  - subcollection e riferimenti correlati migrati.

