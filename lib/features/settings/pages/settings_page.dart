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
  late final SettingsRepository repository;

  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController doctorsCatalogController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      if (message == 'Impostazioni salvate.') {
        message = '';
        isErrorMessage = false;
      }
    });

    try {
      final AppSettings settings = await repository.getSettings();
      if (!mounted) return;
      setState(() {
        currentSettings = settings;
        expiryWarningController.text = settings.expiryWarningDays.toString();
        doctorsCatalogController.text = settings.doctorsCatalog.join('\n');
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
      final List<String> doctorsCatalog = doctorsCatalogController.text
          .split(RegExp(r'[\n,;]+'))
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final AppSettings updated = currentSettings.copyWith(
        expiryWarningDays: expiryWarningDays,
        doctorsCatalog: doctorsCatalog,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
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
                    'Configurazione essenziale dell’app. Nessuna logica backup nel frontend.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Scadenze',
                    subtitle:
                        'Numero di giorni di preavviso per evidenziare le ricette in prossimità di scadenza.',
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: expiryWarningController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Giorni preavviso scadenza',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: isSaving ? null : _save,
                            child: Text(isSaving ? 'Salvataggio...' : 'Salva'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Medici disponibili',
                    subtitle:
                        'Elenco usato nel menu a tendina degli anticipi. Un medico per riga oppure separati da virgola.',
                    child: Column(
                      children: <Widget>[
                        TextField(
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
                      ],
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
          onSelected: (int index) {
            if (appNavigationIndex.value != index) {
              appNavigationIndex.value = index;
            }
          },
        ),
      ],
    );
  }
}
