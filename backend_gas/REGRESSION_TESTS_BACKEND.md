# REGRESSION_TESTS_BACKEND

## Obiettivo
Definire una checklist minima di validazione manuale da eseguire su Apps Script per ogni futura modifica backend.

## Prerequisiti
- File GAS reali presenti e allineati con la PR backend.
- Revisione completata.
- Ambiente Apps Script accessibile.

## Checklist manuale (da adattare al backend reale)
1. Esecuzione dei trigger/funzioni principali senza errori runtime.
2. Verifica delle integrazioni Gmail coinvolte (se presenti).
3. Verifica delle integrazioni Drive/OCR coinvolte (se presenti).
4. Verifica letture/scritture Firestore coinvolte (se presenti).
5. Verifica dei contratti API/endpoint backend consumati dal resto del sistema.
6. Verifica dei log di esecuzione e assenza di regressioni evidenti.

## Gate di rilascio
Una modifica backend è candidata al rilascio solo se:
- la PR dedicata è approvata,
- i test manuali Apps Script sono eseguiti e tracciati,
- non esistono regressioni bloccanti note.

## Nota di governance
Nessun deploy automatico verso Apps Script è consentito in questa fase.
