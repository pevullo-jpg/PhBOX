import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/family_group.dart';
import '../../../data/repositories/families_repository.dart';
import '../../../theme/app_theme.dart';

class FamiliesPage extends StatefulWidget {
  const FamiliesPage({super.key});

  @override
  State<FamiliesPage> createState() => _FamiliesPageState();
}

class _FamiliesPageState extends State<FamiliesPage> {
  late final FamiliesRepository _repository;
  Future<List<FamilyGroup>>? _future;
  String _message = '';

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _repository = FamiliesRepository(datasource: datasource);
    _future = _repository.getAllFamilies();
  }

  void _refresh([String? message]) {
    setState(() {
      if (message != null) {
        _message = message;
      }
      _future = _repository.getAllFamilies();
    });
  }

  Future<void> _openCreateFamilyDialog({FamilyGroup? initial}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final membersController = TextEditingController(
      text: initial?.members.join('\n') ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(
          initial == null ? 'Nuova famiglia' : 'Modifica famiglia',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Nome gruppo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: membersController,
                minLines: 6,
                maxLines: 10,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('CF membri (uno per riga, virgola o ; )').copyWith(
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      membersController.dispose();
      return;
    }

    try {
      final members = membersController.text
          .split(RegExp(r'[\n,;]+'))
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (nameController.text.trim().isEmpty) {
        throw Exception('Il nome gruppo è obbligatorio.');
      }
      if (members.length < 2) {
        throw Exception('Inserisci almeno 2 CF nel gruppo.');
      }

      final now = DateTime.now();
      final family = FamilyGroup(
        id: initial?.id ?? 'family_${now.microsecondsSinceEpoch}',
        name: nameController.text.trim(),
        members: members,
        createdAt: initial?.createdAt ?? now,
        updatedAt: now,
      );
      await _repository.saveFamily(family);
      _refresh(initial == null ? 'Famiglia creata.' : 'Famiglia aggiornata.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Errore salvataggio famiglia: $e';
      });
    } finally {
      nameController.dispose();
      membersController.dispose();
    }
  }

  Future<void> _deleteFamily(FamilyGroup family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Elimina famiglia', style: TextStyle(color: Colors.white)),
        content: Text(
          'Eliminare il gruppo "${family.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteFamily(family.id);
    _refresh('Famiglia eliminata.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateFamilyDialog(),
        backgroundColor: AppColors.yellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nuova famiglia'),
      ),
      body: FutureBuilder<List<FamilyGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Errore caricamento famiglie: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          final families = snapshot.data ?? const <FamilyGroup>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 92, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Famiglie',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Crea gruppi di codici fiscali. In dashboard, richiamando un assistito del gruppo, verranno mostrati anche gli altri componenti con voci attive.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 20),
                if (families.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'Nessuna famiglia configurata.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                else
                  ...families.map((family) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          family.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${family.members.length} componenti',
                                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Modifica',
                                    onPressed: () => _openCreateFamilyDialog(initial: family),
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                                  ),
                                  IconButton(
                                    tooltip: 'Elimina',
                                    onPressed: () => _deleteFamily(family),
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: family.members
                                    .map(
                                      (cf) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          cf,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white70),
      ),
    );
  }
}
