GROUP 47

Base usata: PhBOX_FRONT3_debt_negative_no_partial_fix_build_full

Obiettivo:
integrare il login frontend tenant-aware senza importare le modifiche di tenant path/data source della build login_tenant_access.

Modifiche applicate:
- Firebase Auth email/password lato frontend
- gate di accesso tramite tenant_access/{email}
- validazione tenant su tenants_public/{tenantId}
- blocco frontend se frontendEnabled=false o tenantStatus=blocked
- logout dalla shell principale
- mantenuta invariata la logica dati della base stabile

File modificati/aggiunti:
- pubspec.yaml
- lib/app.dart
- lib/shared/widgets/floating_page_menu.dart
- lib/core/services/frontend_access_service.dart
- lib/core/session/phbox_frontend_access.dart
- lib/core/session/phbox_tenant_session.dart
- lib/features/auth/pages/login_page.dart
- lib/features/auth/pages/frontend_access_status_page.dart

Scelta architetturale:
non sono state importate in questa build le modifiche a datasource/repository/settings della build login_tenant_access, per non alterare il profilo di letture della base stabile.
