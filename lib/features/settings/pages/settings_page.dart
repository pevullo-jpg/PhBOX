import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/services/drive_pdf_scanner_service.dart';
import '../../../core/services/google_auth_prep_service.dart';
import '../../../core/services/google_drive_service.dart';
import '../../../core/services/imported_pdf_processing_service.dart';
import '../../../core/services/intake_to_entities_service.dart';
import '../../../core/services/pdf_text_extraction_service.dart';
import '../../../core/services/prescription_pdf_parser_service.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/prescription_intake.dart';
import '../../../data/models/parser_reference_value.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/parser_reference_values_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescription_intakes_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsRepository repository;
  late final DrivePdfImportsRepository drivePdfImportsRepository;
  late final PrescriptionIntakesRepository prescriptionIntakesRepository;
  late final ParserReferenceValuesRepository parserReferenceValuesRepository;
  late final PatientsRepository patientsRepository;
  late final PrescriptionsRepository prescriptionsRepository;
  late final GoogleAuthPrepService googleAuthPrepService;

  final TextEditingController googleWebClientIdController =
      TextEditingController();
  final TextEditingController incomingPdfController = TextEditingController();
  final TextEditingController incomingImageController = TextEditingController();
  final TextEditingController processedController = TextEditingController();
  final TextEditingController mergedController = TextEditingController();
  final TextEditingController extensionsController = TextEditingController();
  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController scanIntervalController = TextEditingController();

  bool autoScanEnabled = false;
  bool autoMergeByPatient = true;
  bool autoDetectDpc = true;

  bool isSaving = false;
  bool isLoading = true;
  bool isGoogleLoading = false;
  bool isScanningDrive = false;
  bool isGoogleConnected = false;
  bool isProcessingImports = false;
  bool isImportingIntoApp = false;

  String message = '';
  bool isErrorMessage = false;

  String googleAccountEmail = '';
  String googleAccountName = '';
  String currentAccessToken = '';

  AppSettings currentSettings = AppSettings.empty();
  List<DrivePdfImport> recentImports = <DrivePdfImport>[];
  List<PrescriptionIntake> recentIntakes = <PrescriptionIntake>[];
  List<ParserReferenceValue> parserReferences = <ParserReferenceValue>[];

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);

    repository = SettingsRepository(datasource: datasource);
    drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    prescriptionIntakesRepository =
        PrescriptionIntakesRepository(datasource: datasource);
    parserReferenceValuesRepository =
        ParserReferenceValuesRepository(datasource: datasource);
    patientsRepository = PatientsRepository(datasource: datasource);
    prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: patientsRepository,
    );
    googleAuthPrepService = GoogleAuthPrepService();
    _load();
  }

  @override
  void dispose() {
    googleWebClientIdController.dispose();
    incomingPdfController.dispose();
    incomingImageController.dispose();
    processedController.dispose();
    mergedController.dispose();
    extensionsController.dispose();
    expiryWarningController.dispose();
    scanIntervalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final AppSettings settings = await repository.getSettings();
      final List<DrivePdfImport> imports =
          await drivePdfImportsRepository.getAllImports();
      final List<PrescriptionIntake> intakes =
          await prescriptionIntakesRepository.getAllIntakes();
      final List<ParserReferenceValue> references =
          await parserReferenceValuesRepository.getAllReferences();

      if (!mounted) return;

      setState(() {
        currentSettings = settings;
        googleWebClientIdController.text = settings.googleWebClientId;
        incomingPdfController.text = settings.incomingPdfDriveFolderId;
        incomingImageController.text = settings.incomingImageDriveFolderId;
        processedController.text = settings.processedDriveFolderId;
        mergedController.text = settings.mergedPdfDriveFolderId;
        extensionsController.text = settings.acceptedExtensions.join(', ');
        expiryWarningController.text = settings.expiryWarningDays.toString();
        scanIntervalController.text = settings.scanIntervalMinutes.toString();
        autoScanEnabled = settings.autoScanEnabled;
        autoMergeByPatient = settings.autoMergeByPatient;
        autoDetectDpc = settings.autoDetectDpc;
        recentImports = imports;
        recentIntakes = intakes;
        parserReferences = references;
        googleAccountEmail = settings.connectedGoogleEmail;
        googleAccountName = settings.connectedGoogleDisplayName;
        currentAccessToken = '';
        isGoogleConnected = false;
      });

      await _restoreGoogleSessionIfPossible();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore caricamento impostazioni: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _restoreGoogleSessionIfPossible() async {
    final String clientId = googleWebClientIdController.text.trim();
    if (clientId.isEmpty) return;

    try {
      final GoogleAuthPrepResult? result =
          await googleAuthPrepService.tryRestoreSession(clientId: clientId);

      if (result == null || !mounted) return;

      setState(() {
        googleAccountEmail = result.email;
        googleAccountName = result.displayName ?? '';
        currentAccessToken = result.accessToken ?? '';
        isGoogleConnected = true;
      });

      final AppSettings updated = currentSettings.copyWith(
        googleWebClientId: clientId,
        connectedGoogleEmail: googleAccountEmail,
        connectedGoogleDisplayName: googleAccountName,
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      currentSettings = updated;
    } catch (_) {}
  }


  Future<String> _ensureGoogleAccessToken({
    bool interactive = false,
  }) async {
    if (currentAccessToken.trim().isNotEmpty) {
      return currentAccessToken.trim();
    }

    final GoogleAuthPrepResult? result =
        await googleAuthPrepService.ensureDriveSession(
      clientId: googleWebClientIdController.text.trim(),
      interactive: interactive,
    );

    if (result == null || result.accessToken == null || result.accessToken!.trim().isEmpty) {
      throw Exception(
        interactive
            ? "Impossibile completare la sessione Google Drive. Ricollega l'account."
            : "Sessione Google Drive non valida. Premi prima “Verifica sessione” o ricollega l'account.",
      );
    }

    final AppSettings updated = currentSettings.copyWith(
      googleWebClientId: googleWebClientIdController.text.trim(),
      connectedGoogleEmail: result.email,
      connectedGoogleDisplayName: result.displayName ?? '',
      updatedAt: DateTime.now(),
    );
    await repository.saveSettings(updated);
    currentSettings = updated;

    if (mounted) {
      setState(() {
        googleAccountEmail = result.email;
        googleAccountName = result.displayName ?? '';
        currentAccessToken = result.accessToken ?? '';
        isGoogleConnected = true;
      });
    } else {
      googleAccountEmail = result.email;
      googleAccountName = result.displayName ?? '';
      currentAccessToken = result.accessToken ?? '';
      isGoogleConnected = true;
    }

    return currentAccessToken.trim();
  }

  Future<void> _save() async {
    setState(() {
      isSaving = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final List<String> extensions = extensionsController.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      final AppSettings settings = AppSettings(
        googleWebClientId: googleWebClientIdController.text.trim(),
        connectedGoogleEmail: googleAccountEmail,
        connectedGoogleDisplayName: googleAccountName,
        incomingPdfDriveFolderId: incomingPdfController.text.trim(),
        incomingImageDriveFolderId: incomingImageController.text.trim(),
        processedDriveFolderId: processedController.text.trim(),
        mergedPdfDriveFolderId: mergedController.text.trim(),
        autoScanEnabled: autoScanEnabled,
        autoMergeByPatient: autoMergeByPatient,
        autoDetectDpc: autoDetectDpc,
        acceptedExtensions:
            extensions.isEmpty ? const <String>['pdf'] : extensions,
        expiryWarningDays:
            int.tryParse(expiryWarningController.text.trim()) ?? 7,
        scanIntervalMinutes:
            int.tryParse(scanIntervalController.text.trim()) ?? 30,
        updatedAt: DateTime.now(),
      );

      await repository.saveSettings(settings);
      currentSettings = settings;

      if (!mounted) return;
      setState(() {
        message = 'Impostazioni salvate correttamente.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore salvataggio impostazioni: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _connectGoogle() async {
    setState(() {
      isGoogleLoading = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final GoogleAuthPrepResult result =
          await googleAuthPrepService.signInForDriveRead(
        clientId: googleWebClientIdController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        googleAccountEmail = result.email;
        googleAccountName = result.displayName ?? '';
        currentAccessToken = result.accessToken ?? '';
        isGoogleConnected = true;
      });

      final AppSettings updated = currentSettings.copyWith(
        googleWebClientId: googleWebClientIdController.text.trim(),
        connectedGoogleEmail: googleAccountEmail,
        connectedGoogleDisplayName: googleAccountName,
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      currentSettings = updated;

      if (!mounted) return;
      setState(() {
        message = 'Account Google collegato correttamente.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore login Google: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  Future<void> _disconnectGoogle() async {
    setState(() {
      isGoogleLoading = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      await googleAuthPrepService.signOut(
        clientId: googleWebClientIdController.text.trim(),
      );

      final AppSettings updated = currentSettings.copyWith(
        connectedGoogleEmail: '',
        connectedGoogleDisplayName: '',
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      currentSettings = updated;

      if (!mounted) return;
      setState(() {
        googleAccountEmail = '';
        googleAccountName = '';
        currentAccessToken = '';
        isGoogleConnected = false;
        message = 'Account Google scollegato.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore logout Google: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  Future<void> _refreshGoogleSession() async {
    setState(() {
      isGoogleLoading = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final GoogleAuthPrepResult? result =
          await googleAuthPrepService.tryRestoreSession(
        clientId: googleWebClientIdController.text.trim(),
      );

      if (result == null) {
        throw Exception('Nessuna sessione Google attiva trovata.');
      }

      final AppSettings updated = currentSettings.copyWith(
        googleWebClientId: googleWebClientIdController.text.trim(),
        connectedGoogleEmail: result.email,
        connectedGoogleDisplayName: result.displayName ?? '',
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      currentSettings = updated;

      if (!mounted) return;
      setState(() {
        googleAccountEmail = result.email;
        googleAccountName = result.displayName ?? '';
        currentAccessToken = result.accessToken ?? '';
        isGoogleConnected = true;
        message = 'Sessione Google aggiornata.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentAccessToken = '';
        isGoogleConnected = false;
        message = 'Errore verifica sessione Google: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  Future<void> _scanDriveNow() async {
    setState(() {
      isScanningDrive = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String folderId = incomingPdfController.text.trim();

      if (folderId.isEmpty) {
        throw Exception('Inserisci prima la cartella Drive PDF in ingresso.');
      }

      final String accessToken = await _ensureGoogleAccessToken();

      final DrivePdfScannerService scanner = DrivePdfScannerService(
        googleDriveService: GoogleDriveService(accessToken: accessToken),
        importsRepository: drivePdfImportsRepository,
      );

      final DrivePdfScannerResult result = await scanner.scanFolder(folderId);
      final List<DrivePdfImport> imports =
          await drivePdfImportsRepository.getAllImports();

      if (!mounted) return;
      setState(() {
        recentImports = imports;
        message = 'Scansione completata. PDF trovati: ${result.importedCount}.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore scansione Drive: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isScanningDrive = false;
      });
    }
  }

  Future<void> _processImportedPdfs() async {
    setState(() {
      isProcessingImports = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String accessToken = await _ensureGoogleAccessToken();

      final ImportedPdfProcessingService service = ImportedPdfProcessingService(
        googleDriveService: GoogleDriveService(accessToken: accessToken),
        drivePdfImportsRepository: drivePdfImportsRepository,
        prescriptionIntakesRepository: prescriptionIntakesRepository,
        pdfTextExtractionService: const PdfTextExtractionService(),
        prescriptionPdfParserService: const PrescriptionPdfParserService(),
        parserReferenceValuesRepository: parserReferenceValuesRepository,
      );

      final ImportedPdfProcessingResult result =
          await service.processPendingImports();

      final List<DrivePdfImport> imports =
          await drivePdfImportsRepository.getAllImports();
      final List<PrescriptionIntake> intakes =
          await prescriptionIntakesRepository.getAllIntakes();

      if (!mounted) return;
      setState(() {
        recentImports = imports;
        recentIntakes = intakes;
        message =
            'Analisi completata. Processati: ${result.processedCount}. Errori: ${result.failedCount}.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore analisi PDF: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isProcessingImports = false;
      });
    }
  }

  Future<void> _importIntakesIntoApp() async {
    setState(() {
      isImportingIntoApp = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final IntakeToEntitiesService service = IntakeToEntitiesService(
        prescriptionIntakesRepository: prescriptionIntakesRepository,
        patientsRepository: patientsRepository,
        prescriptionsRepository: prescriptionsRepository,
      );

      final IntakeImportResult result =
          await service.importAllPendingIntakes();

      final List<PrescriptionIntake> intakes =
          await prescriptionIntakesRepository.getAllIntakes();
      final List<ParserReferenceValue> references =
          await parserReferenceValuesRepository.getAllReferences();

      if (!mounted) return;
      setState(() {
        recentIntakes = intakes;
        parserReferences = references;
        message =
            'Import completato. Importati: ${result.importedCount}. Saltati: ${result.skippedCount}. Errori: ${result.errorCount}.';
        isErrorMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore import dati in app: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isImportingIntoApp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Impostazioni',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              SettingsFieldCard(
                title: 'Google Web Client ID',
                subtitle:
                    'Inserisci qui il Web Client ID OAuth della tua app. Non serve modificare il codice per cambiare account.',
                child: _input(
                  controller: googleWebClientIdController,
                  hint: '1234567890-xxxxx.apps.googleusercontent.com',
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Account Google Drive',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      googleAccountEmail.isEmpty
                          ? 'Nessun account collegato.'
                          : isGoogleConnected
                              ? 'Collegato: $googleAccountEmail'
                              : 'Account salvato: $googleAccountEmail (sessione da verificare)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (googleAccountName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Nome: $googleAccountName',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed: isGoogleLoading ? null : _connectGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          icon: const Icon(Icons.login),
                          label: Text(
                            isGoogleLoading ? 'Connessione...' : 'Collega account Google',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: isGoogleLoading ? null : _refreshGoogleSession,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.panelSoft,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Verifica sessione',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: isGoogleLoading || !isGoogleConnected
                              ? null
                              : _disconnectGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Cambia account',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SettingsFieldCard(
                title: 'Cartella Drive PDF in ingresso',
                subtitle: 'ID della cartella Google Drive da cui leggere le ricette PDF.',
                child: _input(
                  controller: incomingPdfController,
                  hint: 'Es. 1AbCDefGhIjKlMnOpQr',
                ),
              ),
              const SizedBox(height: 16),
              SettingsFieldCard(
                title: 'Cartella Drive immagini in ingresso',
                subtitle: 'ID della cartella immagini. Può restare vuota per ora.',
                child: _input(
                  controller: incomingImageController,
                  hint: 'ID cartella immagini',
                ),
              ),
              const SizedBox(height: 16),
              SettingsFieldCard(
                title: 'Cartella Drive PDF elaborati',
                subtitle: 'Cartella in cui archiviare i PDF già processati.',
                child: _input(
                  controller: processedController,
                  hint: 'ID cartella elaborati',
                ),
              ),
              const SizedBox(height: 16),
              SettingsFieldCard(
                title: 'Cartella Drive PDF unificati',
                subtitle: 'Cartella dove salvare i PDF fusi per assistito.',
                child: _input(
                  controller: mergedController,
                  hint: 'ID cartella unificati',
                ),
              ),
              const SizedBox(height: 16),
              SettingsFieldCard(
                title: 'Estensioni accettate',
                subtitle: 'Separate da virgola. Esempio: pdf, jpg, png',
                child: _input(
                  controller: extensionsController,
                  hint: 'pdf, jpg, png',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SettingsFieldCard(
                      title: 'Giorni soglia scadenza',
                      subtitle: 'Entro quanti giorni una ricetta viene segnalata in scadenza.',
                      child: _input(
                        controller: expiryWarningController,
                        hint: '7',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SettingsFieldCard(
                      title: 'Intervallo scansione minuti',
                      subtitle: 'Quanto spesso controllare la cartella Drive.',
                      child: _input(
                        controller: scanIntervalController,
                        hint: '30',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor: Colors.white54,
                    switchTheme: const SwitchThemeData(
                      thumbColor: WidgetStatePropertyAll(AppColors.yellow),
                      trackColor: WidgetStatePropertyAll(Color(0xFF3A3A3A)),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        activeColor: AppColors.yellow,
                        value: autoScanEnabled,
                        onChanged: (value) => setState(() => autoScanEnabled = value),
                        title: const Text(
                          'Scansione automatica attiva',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Controlla periodicamente la cartella Drive impostata.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      SwitchListTile(
                        activeColor: AppColors.yellow,
                        value: autoMergeByPatient,
                        onChanged: (value) => setState(() => autoMergeByPatient = value),
                        title: const Text(
                          'Unisci PDF per assistito',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Fonde le ricette con stesso nominativo in un unico PDF.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      SwitchListTile(
                        activeColor: AppColors.yellow,
                        value: autoDetectDpc,
                        onChanged: (value) => setState(() => autoDetectDpc = value),
                        title: const Text(
                          'Riconoscimento DPC automatico',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Marca automaticamente le ricette con dicitura DPC.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.save),
                    label: Text(
                      isSaving ? 'Salvataggio...' : 'Salva impostazioni',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isScanningDrive ? null : _scanDriveNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.search),
                    label: Text(
                      isScanningDrive ? 'Scansione...' : 'Scansiona Drive ora',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isProcessingImports ? null : _processImportedPdfs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(
                      isProcessingImports ? 'Analisi...' : 'Analizza PDF importati',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isImportingIntoApp ? null : _importIntakesIntoApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.move_down),
                    label: Text(
                      isImportingIntoApp ? 'Import...' : 'Importa in dashboard',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (message.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isErrorMessage ? AppColors.red : AppColors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _importsSection(),
              const SizedBox(height: 20),
              _intakesSection(),
              const SizedBox(height: 20),
              _learningSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _importsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PDF trovati in Drive',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (recentImports.isEmpty)
            const Text(
              'Nessun PDF importato finora.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...recentImports.take(20).map((DrivePdfImport item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.panelSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.picture_as_pdf, color: AppColors.coral),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          item.status,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    if (item.errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.errorMessage,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openDrivePdf(String driveFileId) async {
    final Uri uri = Uri.parse(GoogleDriveService.buildFileViewUrl(driveFileId));
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  String _normalizeReferenceId(String type, String value) {
    final String normalized = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9À-ÖØ-Ý]'), '');
    return '${type}_$normalized';
  }

  Future<void> _saveReferenceValue(String type, String value) async {
    final String cleaned = value.trim();
    if (cleaned.isEmpty) return;
    final DateTime now = DateTime.now();
    await parserReferenceValuesRepository.saveReference(
      ParserReferenceValue(
        id: _normalizeReferenceId(type, cleaned),
        type: type,
        value: cleaned,
        normalizedValue: cleaned.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9À-ÖØ-Ý]'), ''),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _editIntake(PrescriptionIntake item) async {
    final TextEditingController patientController = TextEditingController(text: item.patientName);
    final TextEditingController doctorController = TextEditingController(text: item.doctorName);
    final TextEditingController cityController = TextEditingController(text: item.city);
    final TextEditingController medicinesController = TextEditingController(text: item.medicines.join('\n'));

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Correggi estrazione', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: patientController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Assistito', labelStyle: TextStyle(color: Colors.white70))),
                  const SizedBox(height: 12),
                  TextField(controller: doctorController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Medico', labelStyle: TextStyle(color: Colors.white70))),
                  const SizedBox(height: 12),
                  TextField(controller: cityController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Città', labelStyle: TextStyle(color: Colors.white70))),
                  const SizedBox(height: 12),
                  TextField(controller: medicinesController, minLines: 3, maxLines: 8, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Terapie / un farmaco per riga', labelStyle: TextStyle(color: Colors.white70))),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
          ],
        );
      },
    );

    if (saved != true) return;

    final List<String> medicines = medicinesController.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final PrescriptionIntake updated = item.copyWith(
      patientName: patientController.text.trim(),
      doctorName: doctorController.text.trim(),
      city: cityController.text.trim(),
      medicines: medicines,
      updatedAt: DateTime.now(),
      status: item.status == 'imported' ? 'imported' : 'parsed',
      importErrorMessage: '',
    );

    await prescriptionIntakesRepository.saveIntake(updated);
    await _saveReferenceValue('patient', updated.patientName);
    await _saveReferenceValue('doctor', updated.doctorName);
    await _saveReferenceValue('city', updated.city);
    final List<PrescriptionIntake> intakes = await prescriptionIntakesRepository.getAllIntakes();
    final List<ParserReferenceValue> references =
        await parserReferenceValuesRepository.getAllReferences();
    if (!mounted) return;
    setState(() {
      recentIntakes = intakes;
      parserReferences = references;
      message = 'Correzione salvata. Verrà riusata nelle prossime estrazioni.';
      isErrorMessage = false;
    });
  }

  Future<void> _showAddReferenceDialog(String type) async {
    final TextEditingController controller = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(
            'Nuovo riferimento ${_referenceTypeLabel(type)}',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: _referenceTypeLabel(type),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    await _saveReferenceValue(type, controller.text);
    final List<ParserReferenceValue> references =
        await parserReferenceValuesRepository.getAllReferences();
    if (!mounted) return;
    setState(() {
      parserReferences = references;
      message = 'Riferimento salvato.';
      isErrorMessage = false;
    });
  }

  Future<void> _deleteReferenceValue(ParserReferenceValue item) async {
    await parserReferenceValuesRepository.deleteReference(item.id);
    final List<ParserReferenceValue> references =
        await parserReferenceValuesRepository.getAllReferences();
    if (!mounted) return;
    setState(() {
      parserReferences = references;
      message = 'Riferimento rimosso.';
      isErrorMessage = false;
    });
  }

  String _referenceTypeLabel(String type) {
    switch (type) {
      case 'patient':
        return 'Assistito';
      case 'doctor':
        return 'Medico';
      case 'city':
        return 'Città';
      default:
        return type;
    }
  }

  Widget _learningSection() {
    final List<ParserReferenceValue> patients =
        parserReferences.where((ParserReferenceValue item) => item.type == 'patient').toList();
    final List<ParserReferenceValue> doctors =
        parserReferences.where((ParserReferenceValue item) => item.type == 'doctor').toList();
    final List<ParserReferenceValue> cities =
        parserReferences.where((ParserReferenceValue item) => item.type == 'city').toList();

    Widget block({
      required String title,
      required String type,
      required List<ParserReferenceValue> values,
    }) {
      return Container(
        width: 320,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panelSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$title (${values.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiungi',
                  onPressed: () => _showAddReferenceDialog(type),
                  icon: const Icon(Icons.add, color: AppColors.yellow),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (values.isEmpty)
              const Text('Nessun riferimento salvato.', style: TextStyle(color: Colors.white54))
            else
              ...values.take(15).map(
                (ParserReferenceValue item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(item.value, style: const TextStyle(color: Colors.white70)),
                      ),
                      IconButton(
                        tooltip: 'Rimuovi',
                        onPressed: () => _deleteReferenceValue(item),
                        icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Archivio apprendimento parser',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Qui gestisci i riferimenti che guidano le estrazioni future. Puoi aggiungerli a mano, salvarli da una correzione intake o rimuoverli.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              block(title: 'Assistiti', type: 'patient', values: patients),
              block(title: 'Medici', type: 'doctor', values: doctors),
              block(title: 'Città', type: 'city', values: cities),
            ],
          ),
        ],
      ),
    );
  }

  Widget _intakesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Anteprima dati estratti dai PDF',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (recentIntakes.isEmpty)
            const Text(
              'Nessuna intake generata finora.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...recentIntakes.take(10).map((PrescriptionIntake item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.panelSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Stato: ${item.status}',
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        TextButton.icon(
                          onPressed: () => _openDrivePdf(item.driveFileId),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Apri PDF'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _editIntake(item),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Correggi e insegna'),
                        ),
                      ],
                    ),
                    Text('Assistito: ${item.patientName.isEmpty ? '-' : item.patientName}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('CF: ${item.fiscalCode.isEmpty ? '-' : item.fiscalCode}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Medico: ${item.doctorName.isEmpty ? '-' : item.doctorName}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Città: ${item.city.isEmpty ? '-' : item.city}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Esenzione: ${item.exemptionCode.isEmpty ? '-' : item.exemptionCode}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('DPC: ${item.dpcFlag ? 'SI' : 'NO'}',
                        style: const TextStyle(color: Colors.white70)),
                    Text(
                      'Terapie: ${item.medicines.isEmpty ? '-' : item.medicines.join(' | ')}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (item.importErrorMessage.isNotEmpty)
                      Text(
                        'Errore: ${item.importErrorMessage}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF151515),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.yellow, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
