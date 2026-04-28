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
- Frontend: orchestrazione servizi parser/OCR e chiamate Gmail/Drive.
- Firestore: persistenza intakes, pazienti e prescrizioni legacy.
- Gmail/Drive: sorgente file + trasporto documenti.
- Backend GAS/Superback: **DA VERIFICARE** (non implementati nel repo).

## Criticità operative
- Servizi scanner/import email tentano `saveImport()` su `drive_pdf_imports`, ma il repository frontend lo vieta.
- Quindi il workflow end-to-end lato frontend è parzialmente disaccoppiato e richiede backend esterno.

## Rischi di incremento letture Firestore
- Caricamento reference values completo ad ogni scansione/import.
- Poll/refresh di intakes e dataset globali senza finestra incrementale.

