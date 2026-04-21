import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/access_mode.dart';
import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/models/entitlement.dart';
import 'package:family_boxes_2/models/backup_settings.dart';
import 'package:family_boxes_2/models/box.dart';
import 'package:family_boxes_2/models/fund.dart';
import 'package:family_boxes_2/services/backup_service.dart';
import 'package:family_boxes_2/services/storage_service.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/section_title.dart';
import 'package:family_boxes_2/ui/pages/subscription_status_page.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class SettingsPage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onChanged;
  final AccessMode accessMode;
  final AuthUser currentUser;
  final Entitlement entitlement;
  final AccessMode? debugOverride;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onEntitlementRefresh;
  final Future<void> Function(AccessMode? mode) onDebugAccessOverrideChanged;
  final Future<void> Function() onActivateDebugSubscription;
  final Future<void> Function() onResetDebugTrial;
  final Future<void> Function() onForceDebugReadOnly;

  const SettingsPage({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.accessMode,
    required this.currentUser,
    required this.entitlement,
    required this.debugOverride,
    required this.onSignOut,
    required this.onEntitlementRefresh,
    required this.onDebugAccessOverrideChanged,
    required this.onActivateDebugSubscription,
    required this.onResetDebugTrial,
    required this.onForceDebugReadOnly,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  BackupSettings _backupSettings = BackupSettings.defaults();
  bool _loadingBackup = true;
  late AccessMode _accessMode;

  @override
  void initState() {
    super.initState();
    _accessMode = widget.accessMode;
    _loadBackupSettings();
  }


  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessMode != widget.accessMode) {
      _accessMode = widget.accessMode;
    }
  }

  Future<void> _loadBackupSettings() async {
    final settings = await BackupService.loadSettings();
    if (!mounted) return;
    setState(() {
      _backupSettings = settings;
      _loadingBackup = false;
    });
  }

  Future<void> _saveBackupSettings() async {
    await BackupService.saveSettings(_backupSettings);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }

  Future<void> _setDebugOverride(AccessMode? mode) async {
    await widget.onDebugAccessOverrideChanged(mode);
    if (!mounted) return;
    setState(() {
      _accessMode = mode ?? widget.accessMode;
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleziona cartella backup',
    );

    if (path == null || path.trim().isEmpty) return;

    _backupSettings = _backupSettings.copyWith(
      folderPath: path,
      clearLastRun: true,
    );

    await _saveBackupSettings();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cartella backup aggiornata')),
    );
  }

  Future<void> _runBackupNow() async {
    if (_backupSettings.folderPath.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selezioni prima una cartella')),
      );
      return;
    }

    final file = await BackupService.createBackupInFolder(
      data: widget.engine.exportData(),
      folderPath: _backupSettings.folderPath,
      keepLast: _backupSettings.keepLast,
    );

    if (file != null) {
      _backupSettings = _backupSettings.copyWith(
        lastRunIso: DateTime.now().toIso8601String(),
      );
      await _saveBackupSettings();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          file != null ? 'Backup creato' : 'Backup non riuscito',
        ),
      ),
    );
  }

  Future<void> _importJson() async {
    if (!_accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog("L'import dei backup");
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final raw = String.fromCharCodes(bytes);
    final imported = await StorageService.parseJsonString(raw);
    widget.engine.replaceData(imported);
    await widget.onChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import completato')),
    );
    setState(() {});
  }

  Future<void> _exportJson() async {
    final file = await StorageService.exportToTempFile(
      data: widget.engine.exportData(),
    );

    if (file == null) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup Family Boxes',
      subject: 'Backup Family Boxes',
    );
  }

  Future<void> _openBoxEditor({BoxModel? existing}) async {
    if (!_accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog(
        existing == null ? 'La creazione dei box' : 'La modifica dei box',
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null
          ? existing.initialAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    int selectedColor = existing?.color ?? 0xFFE91E8C;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E0A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'Nuovo box' : 'Modifica box',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.inbox_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Importo iniziale',
                        prefixIcon: Icon(Icons.euro_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        0xFFE91E8C,
                        0xFF7B2FBE,
                        0xFFFF6B35,
                        0xFF00BCD4,
                        0xFFFFC107,
                        0xFF4CAF50,
                        0xFFE53935,
                      ].map((color) {
                        final selected = selectedColor == color;
                        return GestureDetector(
                          onTap: () => setModal(() => selectedColor = color),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (existing != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, 'delete'),
                              child: const Text('Elimina'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, 'save'),
                            child: const Text('Salva'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    final amount =
        double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    if (result == 'save') {
      if (name.isEmpty) return;

      final duplicate = widget.engine.boxes.any(
        (b) => b.name == name && b.id != existing?.id,
      );
      if (duplicate) return;

      final model = BoxModel(
        id: existing?.id ?? widget.engine.newId(),
        name: name,
        initialAmount: amount,
        color: selectedColor,
      );

      if (existing == null) {
        widget.engine.addBox(model);
      } else {
        widget.engine.updateBox(model);
      }

      await widget.onChanged();
      if (mounted) setState(() {});
    }

    if (result == 'delete' && existing != null) {
      widget.engine.deleteBox(existing.id);
      await widget.onChanged();
      if (mounted) setState(() {});
    }
  }

  Future<void> _openFundEditor({Fund? existing}) async {
    if (!_accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog(
        existing == null ? 'La creazione dei fondi' : 'La modifica dei fondi',
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null
          ? existing.initialAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E0A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Nuovo fondo' : 'Modifica fondo',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo iniziale',
                    prefixIcon: Icon(Icons.euro_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (existing != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, 'delete'),
                          child: const Text('Elimina'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, 'save'),
                        child: const Text('Salva'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    final name = nameCtrl.text.trim();
    final amount =
        double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    if (result == 'save') {
      if (name.isEmpty) return;

      final duplicate = widget.engine.funds.any(
        (f) => f.name == name && f.id != existing?.id,
      );
      if (duplicate) return;

      final model = Fund(
        id: existing?.id ?? widget.engine.newId(),
        name: name,
        initialAmount: amount,
      );

      if (existing == null) {
        widget.engine.addFund(model);
      } else {
        widget.engine.updateFund(model);
      }

      await widget.onChanged();
      if (mounted) setState(() {});
    }

    if (result == 'delete' && existing != null) {
      widget.engine.deleteFund(existing.id);
      await widget.onChanged();
      if (mounted) setState(() {});
    }
  }

  String _frequencyLabel(String value) {
    switch (value) {
      case 'daily':
        return 'Giornaliero';
      case 'weekly':
        return 'Settimanale';
      case 'monthly':
        return 'Mensile';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupLastRun = _backupSettings.lastRun;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Account e accesso'),
                const SizedBox(height: 12),
                Text(
                  widget.currentUser.visibleName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentUser.email,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text('Stato: ${widget.entitlement.phaseLabel}'),
                const SizedBox(height: 6),
                Text('Accesso corrente: ${widget.accessMode.label}'),
                const SizedBox(height: 6),
                Text('Trial fino al: ${_formatDate(widget.entitlement.trialEndAt)}'),
                Text('Abbonamento fino al: ${_formatDate(widget.entitlement.subscriptionEndAt)}'),
                const SizedBox(height: 12),
                const Text(
                  'Senza trial o abbonamento attivo l’app entra in sola lettura: dati visibili, scritture bloccate, oracolo sigillato.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubscriptionStatusPage(
                            user: widget.currentUser,
                            entitlement: widget.entitlement,
                            onRefresh: widget.onEntitlementRefresh,
                            onActivateDebugSubscription: widget.onActivateDebugSubscription,
                            onResetTrial: widget.onResetDebugTrial,
                            onForceReadOnly: widget.onForceDebugReadOnly,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('Stato piano'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Esci dall’account'),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<AccessMode?>(
                    value: widget.debugOverride,
                    dropdownColor: const Color(0xFF281A4A),
                    decoration: const InputDecoration(
                      labelText: 'Override debug accesso',
                      prefixIcon: Icon(Icons.bug_report_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<AccessMode?>(
                        value: null,
                        child: Text('Nessun override'),
                      ),
                      ...AccessMode.values.map(
                        (mode) => DropdownMenuItem<AccessMode?>(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      await _setDebugOverride(value);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Import / Export'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importJson,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Importa JSON'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportJson,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FormCard(
            child: _loadingBackup
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Backup automatico locale'),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Attiva auto backup'),
                        value: _backupSettings.enabled,
                        onChanged: (value) async {
                          _backupSettings =
                              _backupSettings.copyWith(enabled: value);
                          await _saveBackupSettings();
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _backupSettings.frequency,
                        dropdownColor: const Color(0xFF281A4A),
                        decoration: const InputDecoration(
                          labelText: 'Cadenza',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Giornaliero'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Settimanale'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Mensile'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          _backupSettings =
                              _backupSettings.copyWith(frequency: value);
                          await _saveBackupSettings();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _backupSettings.keepLast.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Copie da mantenere',
                          prefixIcon: Icon(Icons.layers_rounded),
                        ),
                        onChanged: (value) async {
                          final parsed = int.tryParse(value) ?? 10;
                          _backupSettings = _backupSettings.copyWith(
                            keepLast: parsed < 1 ? 1 : parsed,
                          );
                          await _saveBackupSettings();
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF281A4A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _backupSettings.folderPath.trim().isEmpty
                              ? 'Nessuna cartella selezionata'
                              : _backupSettings.folderPath,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (backupLastRun != null)
                        Text(
                          'Ultimo backup: '
                          '${backupLastRun.day.toString().padLeft(2, '0')}/'
                          '${backupLastRun.month.toString().padLeft(2, '0')}/'
                          '${backupLastRun.year} '
                          '${backupLastRun.hour.toString().padLeft(2, '0')}:'
                          '${backupLastRun.minute.toString().padLeft(2, '0')}'
                          ' • ${_frequencyLabel(_backupSettings.frequency)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickBackupFolder,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('Cartella'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _runBackupNow,
                              icon: const Icon(Icons.backup_rounded),
                              label: const Text('Esegui ora'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Fondi'),
                const SizedBox(height: 12),
                ...widget.engine.funds.map((fund) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(fund.name),
                    subtitle: Text(
                      'Iniziale: €${fund.initialAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openFundEditor(existing: fund),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openFundEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuovo fondo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Boxes'),
                const SizedBox(height: 12),
                ...widget.engine.boxes.map((box) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(box.name),
                    subtitle: Text(
                      'Iniziale: €${box.initialAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(box.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => _openBoxEditor(existing: box),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openBoxEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuovo box'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
