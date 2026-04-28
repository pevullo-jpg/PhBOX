# AI_WORKFLOW

## Stato reale nel codice
Nel repository non esiste integrazione con modelli LLM esterni.

## Workflow “AI-like” realmente presente
La parte intelligente è euristica/regole:
1. Estrazione testo PDF (`PdfTextExtractionService`).
2. Parsing prescrizione con regex/regole (`PrescriptionPdfParserService`).
3. Arricchimento con reference set (`parser_reference_values`).
4. Conversione in entità (`prescription_intakes`, `patients`, `prescriptions`).

## Confini sistemi
- Frontend: orchestrazione servizi parser/OCR e servizi collegati a Gmail/Drive presenti nel repository.
- Firestore: persistenza intakes, pazienti e prescrizioni legacy.
- Gmail/Drive: sorgente file + trasporto documenti.
- Backend GAS/Superback: la pipeline operativa completa Gmail/Drive/PDF può dipendere da backend esterno; dettagli **DA VERIFICARE** se non implementati nel repo.

## Criticità operative
- `drive_pdf_imports` ha ownership backend:
  - frontend non crea record import/archive;
  - frontend non esegue write stile `saveImport()`;
  - frontend non scrive metadata parser/OCR, merge/rename metadata, archive mutation o lifecycle fields backend-owned;
  - frontend può solo inviare patch delete-request limitate via `DrivePdfImportsRepository.requestPdfDelete()`.
- Eliminazione reale, mutazioni Drive, archive lifecycle e final state transition restano backend.
- Se backend GAS non è nel repository, i dettagli operativi end-to-end Gmail/Drive/PDF restano **DA VERIFICARE** e non vanno modificati senza codice backend reale o allegato aggiornato.

## Rischi di incremento letture Firestore
- Caricamento reference values completo ad ogni scansione/import.
- Poll/refresh di intakes e dataset globali senza finestra incrementale.
