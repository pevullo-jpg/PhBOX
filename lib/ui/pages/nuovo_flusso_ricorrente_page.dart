import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/box.dart';
import 'package:family_boxes_2/models/cashflow.dart';
import 'package:family_boxes_2/models/fund.dart';
import 'package:family_boxes_2/ui/widgets/choice_button.dart';
import 'package:family_boxes_2/ui/widgets/data_field.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class NuovoFlussoRicorrentePage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onSaved;
  final Cashflow? existing;

  const NuovoFlussoRicorrentePage({
    super.key,
    required this.engine,
    required this.onSaved,
    this.existing,
  });

  @override
  State<NuovoFlussoRicorrentePage> createState() =>
      _NuovoFlussoRicorrentePageState();
}

class _NuovoFlussoRicorrentePageState extends State<NuovoFlussoRicorrentePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  bool _isBoxFlow = true;
  bool _isMonthly = true;

  String? _sourceId;
  String? _destinationId;

  DateTime _startDate = DateTime.now();
  DateTime _annualDate = DateTime.now();
  int _dayOfMonth = 1;

  @override
  void initState() {
    super.initState();

    final e = widget.existing;
    if (e != null) {
      _isBoxFlow = e.isBoxFlow;
      _isMonthly = e.isMonthly;
      _sourceId = e.sourceId.isEmpty ? null : e.sourceId;
      _destinationId = e.destinationId.isEmpty ? null : e.destinationId;
      _startDate = e.startDate;
      _annualDate = e.annualDate ?? e.startDate;
      _dayOfMonth = e.dayOfMonth;
      _amountCtrl.text = e.amount.toStringAsFixed(2).replaceAll('.', ',');
    } else {
      _dayOfMonth = DateTime.now().day.clamp(1, 28);
    }
  }

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  List<BoxModel> get _boxes => widget.engine.boxes;
  List<Fund> get _funds => widget.engine.funds;

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

  Future<void> _save() async {
    if (widget.engine.writesLocked) {
      await _showReadOnlyBlockedDialog(
        widget.existing == null
            ? 'La creazione dei flussi ricorrenti'
            : 'La modifica dei flussi ricorrenti',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));

    final model = Cashflow(
      id: widget.existing?.id ?? widget.engine.newId(),
      amount: amount.abs(),
      sourceId: _sourceId ?? '',
      destinationId: _destinationId ?? '',
      isBoxFlow: _isBoxFlow,
      isMonthly: _isMonthly,
      dayOfMonth: _dayOfMonth,
      startDate: _startDate,
      annualDate: _isMonthly ? null : _annualDate,
    );

    if (widget.existing == null) {
      widget.engine.addCashflow(model);
    } else {
      widget.engine.updateCashflow(model);
    }

    await widget.onSaved();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    if (widget.engine.writesLocked) {
      await _showReadOnlyBlockedDialog("L'eliminazione dei flussi ricorrenti");
      return;
    }

    widget.engine.deleteCashflow(widget.existing!.id);
    await widget.onSaved();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> sourceMenuItems = _isBoxFlow
        ? _boxes
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.id,
                child: Text(e.name),
              ),
            )
            .toList()
        : _funds
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.id,
                child: Text(e.name),
              ),
            )
            .toList();

    final List<DropdownMenuItem<String>> destinationMenuItems = _isBoxFlow
        ? _boxes
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.id,
                child: Text(e.name),
              ),
            )
            .toList()
        : _funds
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.id,
                child: Text(e.name),
              ),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Nuovo flusso ricorrente'
              : 'Modifica flusso ricorrente',
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
                              label: 'Tra box',
                              selected: _isBoxFlow,
                              color: const Color(0xFFE91E8C),
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
                              label: 'Tra fondi',
                              selected: !_isBoxFlow,
                              color: const Color(0xFF00F5FF),
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
                      DropdownButtonFormField<String>(
                        value: _sourceId,
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: InputDecoration(
                          labelText:
                              _isBoxFlow ? 'Box sorgente' : 'Fondo sorgente',
                          prefixIcon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        items: sourceMenuItems,
                        onChanged: (value) => setState(() => _sourceId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selezioni una sorgente';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _destinationId,
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: InputDecoration(
                          labelText: _isBoxFlow
                              ? 'Box destinazione'
                              : 'Fondo destinazione',
                          prefixIcon: const Icon(Icons.arrow_downward_rounded),
                        ),
                        items: destinationMenuItems,
                        onChanged: (value) =>
                            setState(() => _destinationId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selezioni una destinazione';
                          }
                          if (value == _sourceId) {
                            return 'Origine e destinazione devono differire';
                          }
                          return null;
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
                              .map(
                                (e) => DropdownMenuItem<int>(
                                  value: e,
                                  child: Text(e.toString()),
                                ),
                              )
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
