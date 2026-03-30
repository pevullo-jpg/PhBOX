import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final RegExp _splitPattern = RegExp(r'[\n,;]+');
  static final RegExp _emailPattern = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  late final SettingsRepository repository;
  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController doctorsCatalogController = TextEditingController();
  final TextEditingController ignoredEmailsController = TextEditingController();
  final TextEditingController acceptedCitiesController = TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  String message = '';
  bool isErrorMessage = false;

  AppSettings currentSettings = AppSettings.empty();

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    repository = SettingsRepository(datasource: datasource);
    _load();
  }

  @override
  void dispose() {
    expiryWarningController.dispose();
    doctorsCatalogController.dispose();
    ignoredEmailsController.dispose();
    acceptedCitiesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final AppSettings settings = await repository.getSettings();
      if (!mounted) return;
      setState(() {
        currentSettings = settings;
        expiryWarningController.text = settings.expiryWarningDays.toString();
        doctorsCatalogController.text = settings.doctorsCatalog.join('\n');
        ignoredEmailsController.text = settings.ignoredSenderEmails.join('\n');
        acceptedCitiesController.text = settings.acceptedCities.join('\n');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore caricamento impostazioni: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      isSaving = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final int expiryWarningDays =
          int.tryParse(expiryWarningController.text.trim()) ?? 7;
      final List<String> doctorsCatalog = _parseDoctorsCatalog();
      final List<String> ignoredSenderEmails = _parseIgnoredSenderEmails();
      final List<String> acceptedCities = _parseAcceptedCities();

      final AppSettings updated = currentSettings.copyWith(
        expiryWarningDays: expiryWarningDays,
        doctorsCatalog: doctorsCatalog,
        ignoredSenderEmails: ignoredSenderEmails,
        acceptedCities: acceptedCities,
        updatedAt: DateTime.now(),
      );

      await repository.saveSettings(updated);
      if (!mounted) return;
      setState(() {
        currentSettings = updated;
        message = 'Impostazioni salvate.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore salvataggio: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  List<String> _parseDoctorsCatalog() {
    return doctorsCatalogController.text
        .split(_splitPattern)
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _parseIgnoredSenderEmails() {
    final List<String> emails = ignoredEmailsController.text
        .split(_splitPattern)
        .map((String item) => item.trim().toLowerCase())
        .where((String item) => item.isNotEmpty)
        .toList();

    final List<String> invalidEmails = emails
        .where((String item) => !_emailPattern.hasMatch(item))
        .toSet()
        .toList()
      ..sort();

    if (invalidEmails.isNotEmpty) {
      throw FormatException(
        'Email non valide: ${invalidEmails.join(', ')}',
      );
    }

    return emails.toSet().toList()..sort();
  }

  List<String> _parseAcceptedCities() {
    return acceptedCitiesController.text
        .split(_splitPattern)
        .map((String item) => item.trim().toUpperCase())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (isLoading)
          const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          )
        else
          Scaffold(
            backgroundColor: AppColors.background,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 8),
                  const Text(
                    'Qui configuri i parametri che devono guidare frontend e backend.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Scadenze',
                    subtitle:
                        'Numero di giorni di preavviso per evidenziare le ricette in prossimità di scadenza.',
                    child: TextField(
                      controller: expiryWarningController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Giorni preavviso scadenza',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Email escluse dalla scansione',
                    subtitle:
                        'Il backend dovrà ignorare i mittenti presenti qui. Una email per riga oppure separate da virgola.',
                    child: TextField(
                      controller: ignoredEmailsController,
                      minLines: 4,
                      maxLines: 8,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Lista email escluse',
                        alignLabelWithHint: true,
                        hintText: 'esempio@dominio.it',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Città accettate',
                    subtitle:
                        'Il backend dovrà accettare le ricette con una di queste città oppure senza città valorizzata. Una città per riga oppure separate da virgola.',
                    child: TextField(
                      controller: acceptedCitiesController,
                      minLines: 4,
                      maxLines: 8,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Lista città accettate',
                        alignLabelWithHint: true,
                        hintText: 'AGRIGENTO',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Medici disponibili',
                    subtitle:
                        'Elenco usato nel menu a tendina degli anticipi. Un medico per riga oppure separati da virgola.',
                    child: TextField(
                      controller: doctorsCatalogController,
                      minLines: 4,
                      maxLines: 8,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Lista medici',
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: isSaving ? null : _save,
                      child: Text(isSaving ? 'Salvataggio...' : 'Salva'),
                    ),
                  ),
                  if (message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color: isErrorMessage ? AppColors.red : AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        FloatingPageMenu(
          currentIndex: appNavigationIndex.value,
          onSelected: (index) {
            if (appNavigationIndex.value != index) {
              appNavigationIndex.value = index;
            }
          },
        ),
      ],
    );
  }
}
