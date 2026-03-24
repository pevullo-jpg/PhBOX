import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/families_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../theme/app_theme.dart';

class FamiliesPage extends StatefulWidget {
  const FamiliesPage({super.key});

  @override
  State<FamiliesPage> createState() => _FamiliesPageState();
}

class _FamiliesPageState extends State<FamiliesPage> {
  late final PatientsRepository _patientsRepository;
  late final FamiliesRepository _familiesRepository;
  Future<_FamiliesData>? _future;
  String _message = '';

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _familiesRepository = FamiliesRepository(datasource: datasource);
    _future = _load();
  }

  Future<_FamiliesData> _load() async {
    final patients = await _patientsRepository.getAllPatients();
    final families = await _familiesRepository.getAllFamilies();
    families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _FamiliesData(patients: patients, families: families);
  }

  void _refresh([String? message]) {
    setState(() {
      if (message != null) _message = message;
      _future = _load();
    });
  }

  Future<void> _openFamilyDialog(_FamiliesData data, {FamilyGroup? family}) async {
    final nameController = TextEditingController(text: family?.name ?? '');
    final searchController = TextEditingController();
    final selectedCfs = <String>{...?(family?.fiscalCodes)};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final query = searchController.text.trim().toUpperCase();
          final suggestions = data.patients.where((patient) {
            final cf = patient.fiscalCode.trim().toUpperCase();
            final fullName = patient.fullName.trim().toUpperCase();
            if (selectedCfs.contains(cf)) return false;
            if (query.isEmpty) return false;
            return cf.contains(query) || fullName.contains(query);
          }).take(8).toList();

          void addPatient(Patient patient) {
            final cf = patient.fiscalCode.trim().toUpperCase();
            if (cf.isEmpty) return;
            setLocalState(() {
              selectedCfs.add(cf);
              searchController.clear();
            });
          }

          return AlertDialog(
            backgroundColor: AppColors.panel,
            title: Text(family == null ? 'Nuova famiglia' : 'Modifica famiglia', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nome gruppo',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setLocalState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Aggiungi componente per CF o nome',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: suggestions.map((patient) {
                            return ListTile(
                              dense: true,
                              title: Text(patient.fiscalCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              subtitle: Text(patient.fullName.trim().toUpperCase(), style: const TextStyle(color: Colors.white70)),
                              trailing: IconButton(
                                onPressed: () => addPatient(patient),
                                icon: const Icon(Icons.add_circle_rounded, color: AppColors.green),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (selectedCfs.isEmpty)
                      const Text('Nessun componente inserito.', style: TextStyle(color: Colors.white54))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedCfs.map((cf) {
                          final patient = _findPatientByCf(data.patients, cf);
                          final label = patient == null ? cf : '$cf · ${patient.fullName.trim().toUpperCase()}';
                          return Chip(
                            label: Text(label),
                            onDeleted: () => setLocalState(() => selectedCfs.remove(cf)),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty || selectedCfs.isEmpty) return;
                  final now = DateTime.now();
                  final item = FamilyGroup(
                    id: family?.id ?? now.microsecondsSinceEpoch.toString(),
                    name: name,
                    fiscalCodes: selectedCfs.toList()..sort(),
                    createdAt: family?.createdAt ?? now,
                    updatedAt: now,
                  );
                  await _familiesRepository.saveFamily(item);
                  if (context.mounted) Navigator.of(context).pop();
                  _refresh(family == null ? 'Famiglia creata.' : 'Famiglia aggiornata.');
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteFamily(FamilyGroup family) async {
    await _familiesRepository.deleteFamily(family.id);
    _refresh('Famiglia eliminata.');
  }


  Patient? _findPatientByCf(List<Patient> patients, String cf) {
    final normalizedCf = cf.trim().toUpperCase();
    for (final patient in patients) {
      if (patient.fiscalCode.trim().toUpperCase() == normalizedCf) {
        return patient;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FamiliesData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _FamiliesData(patients: <Patient>[], families: <FamilyGroup>[]);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 72),
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Famiglie', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text('Gruppi di CF usati per richiamare nuclei collegati in dashboard.', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: snapshot.hasData ? () => _openFamilyDialog(data) : null,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nuova famiglia'),
                        ),
                      ],
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 18),
                    Expanded(
                      child: snapshot.connectionState != ConnectionState.done
                          ? const Center(child: CircularProgressIndicator())
                          : data.families.isEmpty
                              ? const Center(child: Text('Nessuna famiglia configurata.', style: TextStyle(color: Colors.white70, fontSize: 16)))
                              : ListView.separated(
                                  itemCount: data.families.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final family = data.families[index];
                                    return Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: AppColors.panel,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(family.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                              ),
                                              IconButton(
                                                onPressed: () => _openFamilyDialog(data, family: family),
                                                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                                              ),
                                              IconButton(
                                                onPressed: () => _deleteFamily(family),
                                                icon: const Icon(Icons.delete_rounded, color: AppColors.red),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: family.fiscalCodes.map((cf) {
                                              final patient = _findPatientByCf(data.patients, cf);
                                              final text = patient == null ? cf : '$cf · ${patient.fullName.trim().toUpperCase()}';
                                              return Chip(label: Text(text));
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
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
          ),
        );
      },
    );
  }
}

class _FamiliesData {
  final List<Patient> patients;
  final List<FamilyGroup> families;

  const _FamiliesData({required this.patients, required this.families});
}
