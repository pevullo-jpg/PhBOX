import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/multitenant/executors/target_assistiti_firestore_copy_sink.dart';
import '../../../data/multitenant/executors/target_write_executor_guarded.dart';
import '../../../data/multitenant/fixtures/target_assistiti_synthetic_copy_sources.dart';
import '../../../data/multitenant/workflows/target_assistiti_manual_copy_workflow.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';
import '../../auth/models/tenant_session.dart';

class SyntheticTargetAssistitiCopyTestCard extends StatefulWidget {
  const SyntheticTargetAssistitiCopyTestCard({super.key});

  @override
  State<SyntheticTargetAssistitiCopyTestCard> createState() =>
      _SyntheticTargetAssistitiCopyTestCardState();
}

class _SyntheticTargetAssistitiCopyTestCardState
    extends State<SyntheticTargetAssistitiCopyTestCard> {
  static const String _expectedApprovalToken = 'COPIA TEST ASSISTITI';
  static const int _maxAssistitiPerRun =
      TargetAssistitiManualCopyWorkflow.defaultMaxAssistitiPerRun;

  final TextEditingController _approvalTokenController = TextEditingController();

  bool _preparing = false;
  bool _copying = false;
  bool _isError = false;
  String _message = '';
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _copyResult;

  @override
  void dispose() {
    _approvalTokenController.dispose();
    super.dispose();
  }

  TargetAssistitiManualCopyWorkflow _buildWorkflow() {
    return TargetAssistitiManualCopyWorkflow(
      executor: TargetWriteExecutorGuarded(
        sink: TargetAssistitiFirestoreCopySink(
          firestore: FirebaseFirestore.instance,
        ),
      ),
    );
  }

  void _preparePreview() {
    if (_preparing || _copying) {
      return;
    }
    setState(() {
      _preparing = true;
      _isError = false;
      _message = '';
      _copyResult = null;
    });

    try {
      final TenantSession session = TenantSessionScope.of(context);
      final TargetAssistitiManualCopyPreparationResult preparation =
          _buildWorkflow().prepare(
        tenantId: session.tenantId,
        sources: TargetAssistitiSyntheticCopySources.familyNormalizationBatch,
        maxAssistitiPerRun: _maxAssistitiPerRun,
      );

      if (!mounted) return;
      setState(() {
        _preview = preparation.toMap();
        _message = preparation.canExecute
            ? 'Anteprima pronta: ${preparation.plannedAssistitiCount} assistiti sintetici normalizzati.'
            : 'Anteprima bloccata: ${_describePreparationBlock(preparation)}.';
        _isError = !preparation.canExecute;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _message = 'Errore anteprima copia test: $error';
        _isError = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _preparing = false;
      });
    }
  }

  Future<void> _copySyntheticAssistiti() async {
    if (_preparing || _copying) {
      return;
    }
    setState(() {
      _copying = true;
      _isError = false;
      _message = '';
      _copyResult = null;
    });

    try {
      final TenantSession session = TenantSessionScope.of(context);
      final TargetAssistitiManualCopyWorkflowResult result = await _buildWorkflow().copy(
        tenantId: session.tenantId,
        sources: TargetAssistitiSyntheticCopySources.familyNormalizationBatch,
        approvalToken: _approvalTokenController.text,
        expectedApprovalToken: _expectedApprovalToken,
        maxAssistitiPerRun: _maxAssistitiPerRun,
      );

      if (!mounted) return;
      setState(() {
        _copyResult = result.toMap();
        _preview = result.preparation.toMap();
        _isError = !result.completed;
        _message = result.completed
            ? 'Copia test completata: ${result.writesCommitted} assistiti sintetici scritti nel target.'
            : 'Copia test non completata: ${_describeCopyBlock(result)}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _copyResult = null;
        _message = 'Errore copia test assistiti target: $error';
        _isError = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _copying = false;
      });
    }
  }


  String _describePreparationBlock(TargetAssistitiManualCopyPreparationResult preparation) {
    if (preparation.sourceLimitExceeded) {
      return 'input troppo ampio per il limite manuale';
    }
    if (preparation.duplicateAssistitoIdCount > 0) {
      return 'assistitoId duplicati nel batch sintetico';
    }
    if (preparation.blockers.isNotEmpty) {
      return preparation.blockers.first.code;
    }
    if (preparation.validation.isNotValid) {
      return 'validazione piano fallita (${preparation.validation.issueCount})';
    }
    if (preparation.plan.isEmpty) {
      return 'piano vuoto';
    }
    return 'controllo manuale richiesto';
  }

  String _describeCopyBlock(TargetAssistitiManualCopyWorkflowResult result) {
    if (result.preparation.blocked) {
      return 'preparazione bloccata: ${_describePreparationBlock(result.preparation)}';
    }
    final TargetGuardedWriteExecutionResult? execution = result.execution;
    if (execution == null) {
      return 'esecuzione non avviata';
    }
    if (execution.blocked) {
      if (!execution.approvalTokenValid) {
        return 'token conferma assente o non valido; 0 write eseguite';
      }
      if (execution.blockers.isNotEmpty) {
        return 'guardia bloccata: ${execution.blockers.first.code}';
      }
      return 'guardia bloccata; 0 write eseguite';
    }
    if (execution.executionError.isNotEmpty) {
      return 'errore esecuzione dopo ${execution.writesCommitted} write: ${execution.executionError}';
    }
    return 'esito incompleto; write committate: ${execution.writesCommitted}';
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFieldCard(
      title: 'Test multifarmacia assistiti target',
      subtitle:
          'Copia manuale bounded di 3 assistiti sintetici per verificare normalizzazione nome/cognome e struttura target. Non usa dati reali, non legge legacy e non crea famiglie operative.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Dataset: famiglia sintetica Villa · casi: nome normale, nome composto, apostrofo. Scrive solo su tenants/{tenantId}/assistiti dopo conferma manuale.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _approvalTokenController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Token conferma copia test',
              helperText: 'Digitare: COPIA TEST ASSISTITI',
              labelStyle: TextStyle(color: Colors.white70),
              helperStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _preparing || _copying ? null : _preparePreview,
                icon: _preparing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_rounded),
                label: Text(_preparing ? 'Preparazione...' : 'Prepara anteprima test'),
              ),
              FilledButton.icon(
                onPressed: _preparing || _copying ? null : _copySyntheticAssistiti,
                icon: _copying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(_copying ? 'Copia...' : 'Copia test assistiti target'),
              ),
            ],
          ),
          if (_message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _message,
              style: TextStyle(
                color: _isError ? AppColors.red : AppColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          _DiagnosticMapPanel(title: 'Anteprima', data: _preview),
          _DiagnosticMapPanel(title: 'Risultato copia', data: _copyResult),
        ],
      ),
    );
  }
}

class _DiagnosticMapPanel extends StatelessWidget {
  final String title;
  final Map<String, dynamic>? data;

  const _DiagnosticMapPanel({
    required this.title,
    required this.data,
  });


  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? value = data;
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _formatDiagnosticValue(value),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDiagnosticValue(Object? value, {int indent = 0}) {
    final String pad = '  ' * indent;
    if (value is Map) {
      final List<String> lines = <String>[];
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final Object? entryValue = entry.value;
        if (entryValue is Map || entryValue is Iterable) {
          lines.add('$pad${entry.key}:');
          lines.add(_formatDiagnosticValue(entryValue, indent: indent + 1));
        } else {
          lines.add('$pad${entry.key}: $entryValue');
        }
      }
      return lines.join('\n');
    }
    if (value is Iterable) {
      final List<String> lines = <String>[];
      int index = 0;
      for (final Object? item in value) {
        if (item is Map || item is Iterable) {
          lines.add('$pad- [$index]');
          lines.add(_formatDiagnosticValue(item, indent: indent + 1));
        } else {
          lines.add('$pad- $item');
        }
        index += 1;
      }
      return lines.join('\n');
    }
    return '$pad$value';
  }
}
