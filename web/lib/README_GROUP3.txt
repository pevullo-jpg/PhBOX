GRUPPO FUNZIONALE 3

Contiene:
- interfaccia FirestoreDatasource
- repository base per patients, prescriptions, advances, debts, bookings
- costanti collezioni e status

SCHEMA FIRESTORE ADOTTATO

patients/{fiscalCode}
  fiscalCode
  fullName
  city
  exemptionCode
  doctorName
  therapiesSummary[]
  lastPrescriptionDate
  hasDebt
  debtTotal
  hasBooking
  hasAdvance
  hasDpc
  archivedRecipeCount
  createdAt
  updatedAt

patients/{fiscalCode}/prescriptions/{prescriptionId}
patients/{fiscalCode}/advances/{advanceId}
patients/{fiscalCode}/debts/{debtId}
patients/{fiscalCode}/bookings/{bookingId}

NOTE IMPORTANTI
- documentId paziente = codice fiscale
- le sottocollezioni sono legate al paziente
- il datasource è astratto: nel gruppo successivo si collega a Firebase Firestore reale
