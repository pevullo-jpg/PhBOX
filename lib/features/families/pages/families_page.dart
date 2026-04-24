import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/family_group_color_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/family_groups_repository.dart';
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
  Patient? _findPatient(List<Patient> patients, String cf) {
    final normalized = cf.trim().toUpperCase();
    for (final patient in patients) {
      if (patient.fiscalCode.trim().toUpperCase() == normalized) return patient;
    }
    return null;
  }

  late final FamilyGroupsRepository _familiesRepository;
  late final PatientsRepository _patientsRepository;
  Future<_FamiliesData>? _future;
  String _message = '';


  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _familiesRepository = FamilyGroupsRepository(datasource: datasource);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _future = _load();
  }


  Future<_FamiliesData> _load() async {
    final families = await _familiesRepository.getAllFamilies();
    final patients = await _patientsRepository.getAllPatients();
    return _FamiliesData(families: families, patients: patients);
  }

  void _refresh([String? message]) {
    setState(() {
      if (message != null) _message = message;
      _future = _load();
    });
  }

  Future<void> _openFamilyDialog({FamilyGroup? initial, required List<Patient> patients}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final cfSearchController = TextEditingController();
    final bulkController = TextEditingController();
    final selected = <String>{...?(initial?.memberFiscalCodes)};
    String? errorText;

    Set<String> parseFiscalCodes(String raw) {
      return raw
          .split(RegExp(r'[\s,;|]+'))
          .map((item) => item.trim().toUpperCase())
          .map((item) => item.replaceAll(RegExp(r'[^A-Z0-9]'), ''))
          .where((item) => item.isNotEmpty)
          .toSet();
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            void addBulkCodes() {
              final parsed = parseFiscalCodes(bulkController.text);
              if (parsed.isEmpty) {
                setLocalState(() => errorText = 'Inserisci almeno un CF valido.');
                return;
              }
              setLocalState(() {
                selected.addAll(parsed);
                bulkController.clear();
                errorText = null;
              });
            }

            final query = cfSearchController.text.trim().toUpperCase();
            final suggestions = patients.where((patient) {
              if (query.isEmpty) return false;
              final cf = patient.fiscalCode.trim().toUpperCase();
              final fullName = patient.fullName.trim().toUpperCase();
              return !selected.contains(cf) && (cf.contains(query) || fullName.contains(query));
            }).take(8).toList();
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: Text(initial == null ? 'Nuova famiglia' : 'Modifica famiglia', style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Nome gruppo', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bulkController,
                        maxLines: 4,
                        minLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Incolla uno o più CF',
                          hintText: 'Un CF per riga oppure separati da virgole, spazi o punto e virgola',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: addBulkCodes,
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Aggiungi CF'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Puoi incollare tutti i CF in un solo inserimento.',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: cfSearchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Cerca paziente per CF o nome', labelStyle: TextStyle(color: Colors.white70)),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: suggestions.map((patient) {
                              return ListTile(
                                dense: true,
                                title: Text(patient.fiscalCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                subtitle: Text(patient.fullName.trim().toUpperCase(), style: const TextStyle(color: Colors.white70)),
                                trailing: const Icon(Icons.add_circle_outline, color: Colors.white70),
                                onTap: () {
                                  setLocalState(() {
                                    selected.add(patient.fiscalCode.trim().toUpperCase());
                                    cfSearchController.clear();
                                    errorText = null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(errorText!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Componenti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                          Text('${selected.length} CF', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (selected.isEmpty)
                        const Text('Nessun CF inserito.', style: TextStyle(color: Colors.white54))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selected.map((cf) {
                            final patient = _findPatient(patients, cf);
                            final label = patient == null ? cf : '$cf · ${patient.fullName.trim().toUpperCase()}';
                            return Chip(
                              backgroundColor: AppColors.panelSoft,
                              label: Text(label, style: const TextStyle(color: Colors.white)),
                              deleteIconColor: Colors.white70,
                              onDeleted: () => setLocalState(() => selected.remove(cf)),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Chiudi')),
                FilledButton(
                  onPressed: () async {
                    final pending = parseFiscalCodes(bulkController.text);
                    if (pending.isNotEmpty) {
                      selected.addAll(pending);
                    }
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setLocalState(() => errorText = 'Inserisci il nome del nucleo.');
                      return;
                    }
                    if (selected.isEmpty) {
                      setLocalState(() => errorText = 'Inserisci almeno un CF nel nucleo.');
                      return;
                    }
                    final family = FamilyGroup(
                      id: initial?.id ?? 'family_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      memberFiscalCodes: selected.toList()..sort(),
                      colorIndex: initial?.colorIndex ?? ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % FamilyGroupColorUtils.palette.length),
                      createdAt: initial?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await _familiesRepository.saveFamily(family);
                    if (mounted) Navigator.of(context).pop();
                    _refresh('Famiglia salvata.');
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFamily(FamilyGroup family) async {
    await _familiesRepository.deleteFamily(family.id);
    _refresh('Famiglia eliminata.');
  }

  Color _familyColor(int index) => FamilyGroupColorUtils.colorForIndex(index);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FamiliesData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final families = data?.families ?? const <FamilyGroup>[];
        final patients = data?.patients ?? const <Patient>[];
        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppColors.background,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Famiglie', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        ),
                        FilledButton.icon(
                          onPressed: snapshot.connectionState == ConnectionState.waiting ? null : () => _openFamilyDialog(patients: patients),
                          icon: const Icon(Icons.add),
                          label: const Text('Nuova famiglia'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                      ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (snapshot.hasError)
                      Expanded(child: Center(child: Text('Errore famiglie: ${snapshot.error}', style: const TextStyle(color: Colors.white))))
                    else if (families.isEmpty)
                      const Expanded(child: Center(child: Text('Nessun gruppo famiglia.', style: TextStyle(color: Colors.white70))))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: families.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final family = families[index];
                            final members = family.memberFiscalCodes.map((cf) {
                              final patient = _findPatient(patients, cf);
                              return patient == null ? cf : '$cf · ${patient.fullName.trim().toUpperCase()}';
                            }).toList();
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.panel,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _familyColor(family.colorIndex),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(family.name.trim().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                      ),
                                      IconButton(
                                        onPressed: () => _openFamilyDialog(initial: family, patients: patients),
                                        icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteFamily(family),
                                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: members.map((label) => Chip(
                                      backgroundColor: AppColors.panelSoft,
                                      label: Text(label, style: const TextStyle(color: Colors.white)),
                                    )).toList(),
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
      },
    );
  }
}

class _FamiliesData {
  final List<FamilyGroup> families;
  final List<Patient> patients;

  const _FamiliesData({required this.families, required this.patients});
}
