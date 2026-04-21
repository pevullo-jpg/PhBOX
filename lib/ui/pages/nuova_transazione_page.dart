import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/transaction.dart';
import 'package:family_boxes_2/ui/widgets/choice_button.dart';
import 'package:family_boxes_2/ui/widgets/data_field.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class NuovaTransazionePage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onSaved;
  final TransactionModel? existing;

  const NuovaTransazionePage({
    super.key,
    required this.engine,
    required this.onSaved,
    this.existing,
  });

  @override
  State<NuovaTransazionePage> createState() => _NuovaTransazionePageState();
}

class _NuovaTransazionePageState extends State<NuovaTransazionePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  bool _isIncome = false;
  String? _fundId;
  String? _boxId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();

    final e = widget.existing;
    if (e != null) {
      _isIncome = e.amount >= 0;
      _amountCtrl.text = e.amount.abs().toStringAsFixed(2).replaceAll('.', ',');
      _noteCtrl.text = e.note;
      _categoryCtrl.text = e.category;
      _fundId = e.fundId;
      _boxId = e.boxId;
      _date = e.date;
    }
  }

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  bool get _warnMisalignment {
    final hasFund = _fundId != null && _fundId!.isNotEmpty;
    final hasBox = _boxId != null && _boxId!.isNotEmpty;
    return hasFund != hasBox;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (widget.engine.writesLocked) {
      await _showReadOnlyBlockedDialog(
        widget.existing == null
            ? 'La creazione delle transazioni'
            : 'La modifica delle transazioni',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final parsed = double.parse(
      _amountCtrl.text.trim().replaceAll(',', '.'),
    );

    final signedAmount = _isIncome ? parsed.abs() : -parsed.abs();

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(_date.year, _date.month, _date.day);

    final isRecurringLinked = widget.existing?.recurringId != null &&
        widget.existing!.recurringId!.isNotEmpty;

    final confirmed = isRecurringLinked
        ? (widget.existing?.confirmed ?? !dateOnly.isAfter(todayOnly))
        : !dateOnly.isAfter(todayOnly);

    final tx = TransactionModel(
      id: widget.existing?.id ?? widget.engine.newId(),
      boxId: (_boxId == null || _boxId!.isEmpty) ? null : _boxId,
      fundId: (_fundId == null || _fundId!.isEmpty) ? null : _fundId,
      amount: signedAmount,
      category: _categoryCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      date: _date,
      confirmed: confirmed,
      recurringId: widget.existing?.recurringId,
    );

    if (widget.existing == null) {
      widget.engine.addTransaction(tx);
    } else {
      widget.engine.updateTransaction(tx);
    }

    await widget.onSaved();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Nuova transazione'
            : 'Modifica transazione'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                FormCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceButton(
                          label: 'Uscita',
                          selected: !_isIncome,
                          color: const Color(0xFFFF6B35),
                          onTap: () => setState(() => _isIncome = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceButton(
                          label: 'Entrata',
                          selected: _isIncome,
                          color: const Color(0xFF00E676),
                          onTap: () => setState(() => _isIncome = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FormCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                      DropdownButtonFormField<String>(
                        value: _fundId ?? '',
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: const InputDecoration(
                          labelText: 'Fondo (facoltativo)',
                          prefixIcon:
                              Icon(Icons.account_balance_wallet_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Nessun fondo'),
                          ),
                          ...widget.engine.funds.map(
                            (e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(e.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _fundId =
                                (value == null || value.isEmpty) ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _boxId ?? '',
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: const InputDecoration(
                          labelText: 'Box (facoltativo)',
                          prefixIcon: Icon(Icons.inbox_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Nessun box'),
                          ),
                          ...widget.engine.boxes.map(
                            (e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(e.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _boxId =
                                (value == null || value.isEmpty) ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DataField(
                        label: 'Data',
                        value:
                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                        icon: Icons.calendar_today_rounded,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _noteCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_warnMisalignment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFB300),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x66FFB300)),
                    ),
                    child: const Text(
                      'Avviso: è stato compilato solo fondo o solo box. Possibile disallineamento.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Salva transazione'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
