import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/recurring.dart';
import 'package:family_boxes_2/models/recurring_group.dart';
import 'package:family_boxes_2/ui/widgets/choice_button.dart';
import 'package:family_boxes_2/ui/widgets/data_field.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class NuovaRicorrenzaPage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onSaved;
  final Recurring? existing;

  const NuovaRicorrenzaPage({
    super.key,
    required this.engine,
    required this.onSaved,
    this.existing,
  });

  @override
  State<NuovaRicorrenzaPage> createState() => _NuovaRicorrenzaPageState();
}

class _NuovaRicorrenzaPageState extends State<NuovaRicorrenzaPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  String? _fundId;
  String? _boxId;

  bool _manual = false;
  bool _isMonthly = true;
  bool _isIncome = false;

  DateTime _startDate = DateTime.now();
  DateTime _annualDate = DateTime.now();
  int _dayOfMonth = 1;

  @override
  void initState() {
    super.initState();

    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2).replaceAll('.', ',');
      _categoryCtrl.text = e.category;
      _fundId = e.fundId;
      _boxId = e.boxId;
      _startDate = e.startDate;
      _annualDate = e.annualDate ?? e.startDate;
      _dayOfMonth = e.dayOfMonth;
      _manual = e.manual;
      _isMonthly = e.isMonthly;
      _isIncome = e.isIncome;
      _durationCtrl.text = e.durationMonths?.toString() ?? '';

      if (e.groupId != null) {
        _groupCtrl.text = widget.engine.groupName(e.groupId);
      }
    } else {
      _dayOfMonth = DateTime.now().day.clamp(1, 28);
    }
  }

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _groupCtrl.dispose();
    _categoryCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickAnnualDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _annualDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _annualDate = picked);
    }
  }

  String? _resolveGroupId() {
    final name = _groupCtrl.text.trim();
    if (name.isEmpty) return null;

    try {
      return widget.engine.recurringGroups.firstWhere((g) => g.name == name).id;
    } catch (_) {
      final g = RecurringGroup(
        id: widget.engine.newId(),
        name: name,
      );
      widget.engine.addRecurringGroup(g);
      return g.id;
    }
  }

  Future<void> _save() async {
    if (widget.engine.writesLocked) {
      await _showReadOnlyBlockedDialog(
        widget.existing == null
            ? 'La creazione delle ricorrenze'
            : 'La modifica delle ricorrenze',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));
    final groupId = _resolveGroupId();

    final durationText = _durationCtrl.text.trim();
    final durationMonths =
        durationText.isEmpty ? null : int.tryParse(durationText);

    final model = Recurring(
      id: widget.existing?.id ?? widget.engine.newId(),
      title: _titleCtrl.text.trim(),
      amount: amount.abs(),
      boxId: (_boxId == null || _boxId!.isEmpty) ? null : _boxId,
      fundId: (_fundId == null || _fundId!.isEmpty) ? null : _fundId,
      category: _categoryCtrl.text.trim(),
      isIncome: _isIncome,
      isMonthly: _isMonthly,
      startDate: _startDate,
      dayOfMonth: _dayOfMonth,
      annualDate: _isMonthly ? null : _annualDate,
      manual: _manual,
      groupId: groupId,
      durationMonths: (durationMonths == null || durationMonths <= 0)
          ? null
          : durationMonths,
    );

    if (widget.existing == null) {
      widget.engine.addRecurring(model);
    } else {
      widget.engine.updateRecurring(model);
    }

    await widget.onSaved();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    if (widget.engine.writesLocked) {
      await _showReadOnlyBlockedDialog("L'eliminazione delle ricorrenze");
      return;
    }
    widget.engine.deleteRecurring(widget.existing!.id);
    await widget.onSaved();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Nuova spesa fissa'
              : 'Modifica spesa fissa',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                FormCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceButton(
                              label: 'Spesa',
                              selected: !_isIncome,
                              color: const Color(0xFFFF6B35),
                              onTap: () => setState(() => _isIncome = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceButton(
                              label: 'Introito',
                              selected: _isIncome,
                              color: const Color(0xFF00E676),
                              onTap: () => setState(() => _isIncome = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceButton(
                              label: 'Mensile',
                              selected: _isMonthly,
                              color: const Color(0xFFE91E8C),
                              onTap: () => setState(() => _isMonthly = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceButton(
                              label: 'Annuale',
                              selected: !_isMonthly,
                              color: const Color(0xFF00F5FF),
                              onTap: () => setState(() => _isMonthly = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceButton(
                              label: 'Automatica',
                              selected: !_manual,
                              color: const Color(0xFFE91E8C),
                              onTap: () => setState(() => _manual = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceButton(
                              label: 'Manuale',
                              selected: _manual,
                              color: const Color(0xFF00F5FF),
                              onTap: () => setState(() => _manual = true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FormCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Titolo',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisca un titolo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Importo',
                          prefixIcon: Icon(Icons.euro_rounded),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Importo non valido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _groupCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gruppo',
                          prefixIcon: Icon(Icons.folder_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Causale',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisca una causale';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Durata mesi (facoltativa)',
                          prefixIcon: Icon(Icons.timelapse_rounded),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final parsed = int.tryParse(text);
                          if (parsed == null || parsed <= 0) {
                            return 'Inserisca un numero valido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _fundId,
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: const InputDecoration(
                          labelText: 'Fondo',
                          prefixIcon:
                              Icon(Icons.account_balance_wallet_rounded),
                        ),
                        items: widget.engine.funds
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.id,
                                  child: Text(e.name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _fundId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selezioni un fondo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _boxId ?? '',
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: const InputDecoration(
                          labelText: 'Box',
                          prefixIcon: Icon(Icons.inbox_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Nessun box'),
                          ),
                          ...widget.engine.boxes
                              .map((e) => DropdownMenuItem<String>(
                                    value: e.id,
                                    child: Text(e.name),
                                  )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _boxId =
                                (value == null || value.isEmpty) ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_isMonthly)
                        DropdownButtonFormField<int>(
                          value: _dayOfMonth,
                          dropdownColor: const Color(0xFF281A4A),
                          decoration: const InputDecoration(
                            labelText: 'Giorno del mese',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          items: List.generate(28, (i) => i + 1)
                              .map((e) => DropdownMenuItem<int>(
                                    value: e,
                                    child: Text(e.toString()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _dayOfMonth = value);
                            }
                          },
                        )
                      else
                        DataField(
                          label: 'Data annuale',
                          value:
                              '${_annualDate.day.toString().padLeft(2, '0')}/${_annualDate.month.toString().padLeft(2, '0')}/${_annualDate.year}',
                          icon: Icons.event_available_rounded,
                          onTap: _pickAnnualDate,
                        ),
                      const SizedBox(height: 14),
                      DataField(
                        label: 'Data inizio',
                        value:
                            '${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
                        icon: Icons.play_arrow_rounded,
                        onTap: _pickStartDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (widget.existing != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _delete,
                          child: const Text('Elimina'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Salva'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
