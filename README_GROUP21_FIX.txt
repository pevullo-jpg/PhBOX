FIX BUILD GROUP 21

Correzioni:
- AppSettings completo con copyWith e campi account Google
- GoogleAuthPrepService con tryRestoreSession
- parser PDF corretto
- SettingsPage completa e coerente
- IntakeToEntitiesService
- PrescriptionIntake con status/importErrorMessage/copyWith

Dopo il deploy:
1. CTRL+F5
2. flusso:
   - Collega account Google
   - Scansiona Drive ora
   - Analizza PDF importati
   - Importa in dashboard
