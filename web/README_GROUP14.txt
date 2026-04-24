GRUPPO FUNZIONALE 14

Obiettivo:
- fix colori pagina Impostazioni
- messaggi errore/successo più visibili
- preparazione login Google web reale

Contiene:
- pubspec.yaml
- lib/features/settings/pages/settings_page.dart
- lib/shared/widgets/settings_field_card.dart
- lib/core/services/google_auth_prep_service.dart

Nota:
- questo blocco prepara il login Google, ma NON completa ancora il flusso OAuth
- il prossimo blocco collegherà davvero l'access token al servizio Drive
