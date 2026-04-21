import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/box.dart';
import 'package:family_boxes_2/models/fund.dart';
import 'package:family_boxes_2/ui/widgets/choice_button.dart';
import 'package:family_boxes_2/ui/widgets/data_field.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class NuovoFlussoSingoloPage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onSaved;

  const NuovoFlussoSingoloPage({
    super.key,
    required this.engine,
    required this.onSaved,
  });

  @override
  State<NuovoFlussoSingoloPage> createState() => _NuovoFlussoSingoloPageState();
}

class _NuovoFlussoSingoloPageState extends State<NuovoFlussoSingoloPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isBoxFlow = true;
  String? _sourceId;
  String? _destinationId;
  DateTime _date = DateTime.now();

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
      await _showReadOnlyBlockedDialog('La creazione dei flussi');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));

    widget.engine.applySingleCashflow(
      isBoxFlow: _isBoxFlow,
      sourceId: _sourceId!,
      destinationId: _destinationId!,
      amount: amount,
      note: _noteCtrl.text.trim(),
      date: _date,
    );

    await widget.onSaved();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<BoxModel> boxItems = List<BoxModel>.from(widget.engine.boxes);
    final List<Fund> fundItems = List<Fund>.from(widget.engine.funds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo flusso singolo'),
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
                          label: 'Box → Box',
                          selected: _isBoxFlow,
                          color: const Color(0xFF7B2FBE),
                          onTap: () {
                            setState(() {
                              _isBoxFlow = true;
                              _sourceId = null;
                              _destinationId = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceButton(
                          label: 'Fondo → Fondo',
                          selected: !_isBoxFlow,
                          color: const Color(0xFFE91E8C),
                          onTap: () {
                            setState(() {
                              _isBoxFlow = false;
                              _sourceId = null;
                              _destinationId = null;
                            });
                          },
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
                      if (_isBoxFlow) ...[
                        DropdownButtonFormField<String>(
                          value: _sourceId,
                          dropdownColor: const Color(0xFF281A4A),
                          decoration: const InputDecoration(
                            labelText: 'Box provenienza',
                            prefixIcon: Icon(Icons.outbox_rounded),
                          ),
                          items: boxItems
                              .map((e) => DropdownMenuItem<String>(
                                    value: e.id,
                                    child: Text(e.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _sourceId = value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selezioni la provenienza';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _destinationId,
                          dropdownColor: const Color(0xFF281A4A),
                          decoration: const InputDecoration(
                            labelText: 'Box destinazione',
                            prefixIcon: Icon(Icons.move_to_inbox_rounded),
                          ),
                          items: boxItems
                              .map((e) => DropdownMenuItem<String>(
                                    value: e.id,
                                    child: Text(e.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _destinationId = value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selezioni la destinazione';
                            }
                            if (value == _sourceId) {
                              return 'Destinazione diversa';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          value: _sourceId,
                          dropdownColor: const Color(0xFF281A4A),
                          decoration: const InputDecoration(
                            labelText: 'Fondo provenienza',
                            prefixIcon: Icon(Icons.outbox_rounded),
                          ),
                          items: fundItems
                              .map((e) => DropdownMenuItem<String>(
                                    value: e.id,
                                    child: Text(e.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _sourceId = value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selezioni la provenienza';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _destinationId,
                          dropdownColor: const Color(0xFF281A4A),
                          decoration: const InputDecoration(
                            labelText: 'Fondo destinazione',
                            prefixIcon: Icon(Icons.move_to_inbox_rounded),
                          ),
                          items: fundItems
                              .map((e) => DropdownMenuItem<String>(
                                    value: e.id,
                                    child: Text(e.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _destinationId = value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selezioni la destinazione';
                            }
                            if (value == _sourceId) {
                              return 'Destinazione diversa';
                            }
                            return null;
                          },
                        ),
                      ],
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Registra flusso'),
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
