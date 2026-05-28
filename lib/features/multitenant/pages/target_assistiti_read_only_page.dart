import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/multitenant/readers/assistiti_target_with_legacy_fallback_reader.dart';
import '../../../data/multitenant/readers/real_assistiti_dry_run_preview_reader.dart';
import '../../../data/multitenant/readers/real_assistiti_nocf_identity_resolution_reader.dart';
import '../../../data/multitenant/reports/real_assistiti_migration1_data_report_reader.dart';
import '../../../data/multitenant/reports/real_assistiti_migration1_firestore_report_reader.dart';
import '../../../data/multitenant/verifiers/real_assistiti_post_copy_verifier.dart';
import '../../../data/multitenant/writers/real_assistiti_nocf_identity_resolution_writer.dart';
import '../../../data/multitenant/writers/real_assistiti_nocf_target_copy_writer.dart';
import '../../../data/multitenant/writers/real_assistiti_target_copy_writer.dart';
import '../../../theme/app_theme.dart';
import '../../auth/models/tenant_session.dart';

class TargetAssistitiReadOnlyPage extends StatefulWidget {
  const TargetAssistitiReadOnlyPage({super.key});

  @override
  State<TargetAssistitiReadOnlyPage> createState() => _TargetAssistitiReadOnlyPageState();
}

class _TargetAssistitiReadOnlyPageState extends State<TargetAssistitiReadOnlyPage> {
  final TextEditingController _cfController = TextEditingController();
  final TextEditingController _nocfController = TextEditingController();

  AssistitiTargetWithLegacyFallbackResult? _result;
  RealAssistitiTargetCopyResult? _copyResult;
  RealAssistitiPostCopyVerificationResult? _verificationResult;
  RealAssistitiDryRunPreviewResult? _dryRunDiagnosticResult;
  RealAssistitiNoCfTargetCopyResult? _nocfCopyResult;
  RealAssistitiNoCfIdentityResolutionPendingResult? _nocfIdentityPendingResult;
  RealAssistitiNoCfIdentityResolutionWriteResult? _nocfIdentityWriteResult;
  RealAssistitiMigration1DataReportResult? _migration1ReportResult;

  Object? _error;
  Object? _copyError;
  Object? _nocfCopyError;
  Object? _nocfIdentityError;
  Object? _migration1ReportError;

  bool _loading = false;
  bool _copying = false;
  bool _nocfCopying = false;
  bool _nocfIdentityLoading = false;
  bool _migration1ReportLoading = false;
  bool _requested = false;
  bool _enableLegacyFallback = true;
  bool _copyConfirmed = false;
  bool _nocfCopyConfirmed = false;
  int _nocfIdentityRequestSerial = 0;
  int _migration1ReportRequestSerial = 0;

  @override
  void dispose() {
    _cfController.dispose();
    _nocfController.dispose();
    super.dispose();
  }

  Future<void> _loadAssistitiByManualCf() async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final AssistitiTargetWithLegacyFallbackReader reader = AssistitiTargetWithLegacyFallbackReader(
      firestore: FirebaseFirestore.instance,
    );
    final List<String> fiscalCodes = _parseManualFiscalCodes(_cfController.text);

    setState(() {
      _loading = true;
      _requested = true;
      _error = null;
      _copyError = null;
      _copyResult = null;
      _verificationResult = null;
      _dryRunDiagnosticResult = null;
      _copyConfirmed = false;
    });

    try {
      final AssistitiTargetWithLegacyFallbackResult result = await reader.readByManualFiscalCodes(
        tenantId: session.tenantId,
        fiscalCodes: fiscalCodes,
        enableLegacyFallback: _enableLegacyFallback,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _result = null;
        _loading = false;
      });
    }
  }

  Future<void> _copyLegacyFallbackItems() async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final AssistitiTargetWithLegacyFallbackResult? result = _result;
    if (result == null) {
      setState(() {
        _copyError = const _FrontendCopyRejectedException(
          code: 'read_result_missing',
          message: 'Eseguire prima una lettura CF con fallback legacy.',
        );
      });
      return;
    }

    final List<String> candidateFiscalCodes = _copyCandidateFiscalCodes(result);
    if (candidateFiscalCodes.isEmpty) {
      setState(() {
        _copyError = const _FrontendCopyRejectedException(
          code: 'copy_candidates_empty',
          message: 'Nessun assistito LEGACY candidabile alla copia target.',
        );
      });
      return;
    }

    if (!_copyConfirmed) {
      setState(() {
        _copyError = const _FrontendCopyRejectedException(
          code: 'manual_copy_confirmation_missing',
          message: 'Spuntare la conferma manuale prima della copia target.',
        );
      });
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final RealAssistitiTargetCopyWriter writer = RealAssistitiTargetCopyWriter(
      firestore: FirebaseFirestore.instance,
    );
    final RealAssistitiPostCopyVerifier verifier = RealAssistitiPostCopyVerifier(
      firestore: FirebaseFirestore.instance,
    );
    final String technicalToken = RealAssistitiTargetCopyWriter.buildRequiredManualConfirmationToken(
      tenantId: session.tenantId,
      normalizedFiscalCodes: candidateFiscalCodes,
    );

    setState(() {
      _copying = true;
      _copyError = null;
      _copyResult = null;
      _verificationResult = null;
      _dryRunDiagnosticResult = null;
    });

    try {
      final RealAssistitiTargetCopyResult copyResult = await writer.copyByManualFiscalCodes(
        tenantId: session.tenantId,
        fiscalCodes: candidateFiscalCodes,
        manualConfirmationToken: technicalToken,
      );
      final RealAssistitiPostCopyVerificationResult verificationResult =
          await verifier.verifyCopyResult(copyResult: copyResult);

      if (!mounted) {
        return;
      }
      setState(() {
        _copyResult = copyResult;
        _verificationResult = verificationResult;
        _copying = false;
        _copyConfirmed = false;
      });
    } catch (error) {
      RealAssistitiDryRunPreviewResult? diagnosticResult;
      if (error is RealAssistitiTargetCopyRejectedException &&
          error.code == 'dry_run_preview_blocked') {
        diagnosticResult = await _loadDryRunDiagnostic(
          tenantId: session.tenantId,
          fiscalCodes: candidateFiscalCodes,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _copyError = diagnosticResult == null
            ? error
            : _FrontendCopyRejectedException(
                code: 'dry_run_preview_blocked',
                message: _formatDryRunBlockingReasons(diagnosticResult),
              );
        _dryRunDiagnosticResult = diagnosticResult;
        _copyResult = null;
        _verificationResult = null;
        _copying = false;
      });
    }
  }

  Future<void> _copyNoCfItems() async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final List<String> identityCodes = _parseManualIdentityCodes(_nocfController.text);
    if (identityCodes.isEmpty) {
      setState(() {
        _nocfCopyError = const _FrontendCopyRejectedException(
          code: 'nocf_identity_codes_empty',
          message: 'Inserire almeno un codice NOCF legacy TMP/manuale.',
        );
      });
      return;
    }
    if (!_nocfCopyConfirmed) {
      setState(() {
        _nocfCopyError = const _FrontendCopyRejectedException(
          code: 'nocf_manual_copy_confirmation_missing',
          message: 'Spuntare la conferma manuale prima della copia NOCF.',
        );
      });
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final RealAssistitiNoCfTargetCopyWriter writer = RealAssistitiNoCfTargetCopyWriter(
      firestore: FirebaseFirestore.instance,
    );

    setState(() {
      _nocfCopying = true;
      _nocfCopyError = null;
      _nocfCopyResult = null;
    });

    try {
      final String technicalToken = RealAssistitiNoCfTargetCopyWriter.buildRequiredManualConfirmationToken(
        tenantId: session.tenantId,
        identityCodes: identityCodes,
      );
      final RealAssistitiNoCfTargetCopyResult copyResult = await writer.copyByManualIdentityCodes(
        tenantId: session.tenantId,
        identityCodes: identityCodes,
        manualConfirmationToken: technicalToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _nocfCopyResult = copyResult;
        _nocfCopying = false;
        _nocfCopyConfirmed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nocfCopyError = error;
        _nocfCopyResult = null;
        _nocfCopying = false;
      });
    }
  }

  Future<void> _loadNoCfIdentityResolutionPending() async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final RealAssistitiNoCfIdentityResolutionReader reader = RealAssistitiNoCfIdentityResolutionReader(
      firestore: FirebaseFirestore.instance,
    );

    final int requestToken = ++_nocfIdentityRequestSerial;

    setState(() {
      _nocfIdentityLoading = true;
      _nocfIdentityError = null;
      _nocfIdentityWriteResult = null;
    });

    try {
      final RealAssistitiNoCfIdentityResolutionPendingResult result =
          await reader.readPendingManual(tenantId: session.tenantId);
      if (!mounted || requestToken != _nocfIdentityRequestSerial) {
        return;
      }
      setState(() {
        _nocfIdentityPendingResult = result;
        _nocfIdentityLoading = false;
      });

      if (result.pendingCount == 1) {
        await _openNoCfIdentityResolutionDialog(result.items.single);
      }
    } catch (error) {
      if (!mounted || requestToken != _nocfIdentityRequestSerial) {
        return;
      }
      setState(() {
        _nocfIdentityError = error;
        _nocfIdentityPendingResult = null;
        _nocfIdentityLoading = false;
      });
    }
  }

  Future<void> _openNoCfIdentityResolutionDialog(
    RealAssistitiNoCfIdentityResolutionPendingItem item,
  ) async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final _NoCfIdentityResolutionFormResult? formResult =
        await showDialog<_NoCfIdentityResolutionFormResult>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _NoCfIdentityResolutionDialog(item: item);
      },
    );
    if (formResult == null) {
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final RealAssistitiNoCfIdentityResolutionWriter writer =
        RealAssistitiNoCfIdentityResolutionWriter(firestore: FirebaseFirestore.instance);
    final int requestToken = ++_nocfIdentityRequestSerial;

    setState(() {
      _nocfIdentityLoading = true;
      _nocfIdentityError = null;
      _nocfIdentityWriteResult = null;
    });

    try {
      final RealAssistitiNoCfIdentityResolutionWriteResult writeResult =
          await writer.resolvePendingManual(
        tenantId: session.tenantId,
        assistitoId: item.assistitoId,
        nome: formResult.nome,
        cognome: formResult.cognome,
      );
      final RealAssistitiNoCfIdentityResolutionReader reader =
          RealAssistitiNoCfIdentityResolutionReader(firestore: FirebaseFirestore.instance);
      final RealAssistitiNoCfIdentityResolutionPendingResult pendingResult =
          await reader.readPendingManual(tenantId: session.tenantId);
      if (!mounted || requestToken != _nocfIdentityRequestSerial) {
        return;
      }
      setState(() {
        _nocfIdentityWriteResult = writeResult;
        _nocfIdentityPendingResult = pendingResult;
        _nocfIdentityLoading = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _nocfIdentityRequestSerial) {
        return;
      }
      setState(() {
        _nocfIdentityError = error;
        _nocfIdentityWriteResult = null;
        _nocfIdentityLoading = false;
      });
    }
  }

  Future<void> _runMigration1FirestoreReport() async {
    if (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading) {
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final RealAssistitiMigration1FirestoreReportReader reader =
        RealAssistitiMigration1FirestoreReportReader(firestore: FirebaseFirestore.instance);
    final int requestToken = ++_migration1ReportRequestSerial;

    setState(() {
      _migration1ReportLoading = true;
      _migration1ReportError = null;
      _migration1ReportResult = null;
    });

    try {
      final RealAssistitiMigration1DataReportResult result = await reader.readReport(
        tenantId: session.tenantId,
      );
      if (!mounted || requestToken != _migration1ReportRequestSerial) {
        return;
      }
      setState(() {
        _migration1ReportResult = result;
        _migration1ReportLoading = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _migration1ReportRequestSerial) {
        return;
      }
      setState(() {
        _migration1ReportError = error;
        _migration1ReportResult = null;
        _migration1ReportLoading = false;
      });
    }
  }

  Future<RealAssistitiDryRunPreviewResult?> _loadDryRunDiagnostic({
    required String tenantId,
    required List<String> fiscalCodes,
  }) async {
    try {
      final RealAssistitiDryRunPreviewReader reader = RealAssistitiDryRunPreviewReader(
        firestore: FirebaseFirestore.instance,
      );
      return await reader.previewByManualFiscalCodes(
        tenantId: tenantId,
        fiscalCodes: fiscalCodes,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatDryRunBlockingReasons(RealAssistitiDryRunPreviewResult result) {
    final List<String> lines = <String>[];
    for (final RealAssistitiDryRunPreviewItem item in result.items) {
      if (item.blocked) {
        lines.add('${item.cf}: ${item.blockingReasons.join(', ')}');
      }
    }
    if (lines.isEmpty) {
      return 'Dry-run bloccato, ma nessun dettaglio diagnostico disponibile.';
    }
    return 'Copia bloccata dal dry-run: ${lines.join(' | ')}';
  }

  static List<String> _copyCandidateFiscalCodes(AssistitiTargetWithLegacyFallbackResult result) {
    final List<String> candidates = <String>[];
    for (final AssistitiTargetWithLegacyFallbackItem item in result.items) {
      if (item.usedLegacyFallback && !item.missing) {
        candidates.add(item.cf);
      }
    }
    return List<String>.unmodifiable(candidates);
  }

  static List<String> _parseManualFiscalCodes(String rawInput) {
    final List<String> values = <String>[];
    final String normalizedSeparators = rawInput
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ');
    final List<String> tokens = normalizedSeparators.split(' ');
    for (final String token in tokens) {
      final String value = token.trim();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values;
  }

  static List<String> _parseManualIdentityCodes(String rawInput) {
    final List<String> values = <String>[];
    final String normalizedSeparators = rawInput
        .replaceAll(',', '\n')
        .replaceAll(';', '\n')
        .replaceAll('\t', '\n');
    final List<String> tokens = normalizedSeparators.split('\n');
    for (final String token in tokens) {
      final String value = token.trim();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final TenantSession session = TenantSessionScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AssistitiFallbackHeader(
                tenantId: session.tenantId,
                tenantName: session.tenantName,
                controller: _cfController,
                loading: _loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading,
                legacyFallbackEnabled: _enableLegacyFallback,
                onLegacyFallbackChanged: (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading)
                    ? null
                    : (bool value) {
                        setState(() {
                          _enableLegacyFallback = value;
                        });
                      },
                onLoad: _loadAssistitiByManualCf,
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final AssistitiTargetWithLegacyFallbackResult? result = _result;
    final List<String> copyCandidateFiscalCodes = result == null
        ? const <String>[]
        : _copyCandidateFiscalCodes(result);

    return ListView(
      children: <Widget>[
        _NoCfCopyPanel(
          controller: _nocfController,
          copyConfirmed: _nocfCopyConfirmed,
          copying: _nocfCopying,
          copyError: _nocfCopyError,
          copyResult: _nocfCopyResult,
          onCopyConfirmedChanged: (_loading || _copying || _nocfCopying || _nocfIdentityLoading || _migration1ReportLoading)
              ? null
              : (bool value) {
                  setState(() {
                    _nocfCopyConfirmed = value;
                    _nocfCopyError = null;
                  });
                },
          onCopy: _nocfCopyConfirmed ? _copyNoCfItems : null,
        ),
        const SizedBox(height: 16),
        _NoCfIdentityResolutionPanel(
          loading: _nocfIdentityLoading,
          error: _nocfIdentityError,
          pendingResult: _nocfIdentityPendingResult,
          writeResult: _nocfIdentityWriteResult,
          onLoadPending: _loadNoCfIdentityResolutionPending,
          onResolve: _openNoCfIdentityResolutionDialog,
        ),
        const SizedBox(height: 16),
        _Migration1FirestoreReportPanel(
          loading: _migration1ReportLoading,
          error: _migration1ReportError,
          result: _migration1ReportResult,
          onRun: _runMigration1FirestoreReport,
        ),
        const SizedBox(height: 16),
        _buildCfBody(copyCandidateFiscalCodes),
      ],
    );
  }

  Widget _buildCfBody(List<String> copyCandidateFiscalCodes) {
    if (!_requested) {
      return const _AssistitiInfoCard(
        icon: Icons.touch_app_rounded,
        title: 'Lettura CF non avviata',
        message:
            'Inserisci massimo 3 CF manuali. Il modulo legge prima tenants/{tenantId}/assistiti e usa il legacy solo come fallback controllato.',
      );
    }

    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final Object? error = _error;
    if (error != null) {
      return _AssistitiInfoCard(
        icon: Icons.error_outline_rounded,
        title: 'Lettura assistiti non riuscita',
        message: error.toString(),
        warning: true,
      );
    }

    final AssistitiTargetWithLegacyFallbackResult? result = _result;
    if (result == null || result.items.isEmpty) {
      return const _AssistitiInfoCard(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun risultato CF disponibile',
        message: 'La lettura è bounded e manuale: nessun documento viene creato o modificato.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AssistitiReadSummary(result: result),
        const SizedBox(height: 12),
        _AssistitiCopyPanel(
          candidateFiscalCodes: copyCandidateFiscalCodes,
          copyConfirmed: _copyConfirmed,
          copying: _copying,
          copyError: _copyError,
          copyResult: _copyResult,
          verificationResult: _verificationResult,
          dryRunDiagnosticResult: _dryRunDiagnosticResult,
          onCopyConfirmedChanged: _copying
              ? null
              : (bool value) {
                  setState(() {
                    _copyConfirmed = value;
                    _copyError = null;
                    _dryRunDiagnosticResult = null;
                  });
                },
          onCopy: _copyConfirmed ? _copyLegacyFallbackItems : null,
        ),
        const SizedBox(height: 12),
        for (final AssistitiTargetWithLegacyFallbackItem item in result.items) ...<Widget>[
          _AssistitoFallbackCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FrontendCopyRejectedException implements Exception {
  final String code;
  final String message;

  const _FrontendCopyRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return '_FrontendCopyRejectedException($code): $message';
  }
}

class _AssistitiFallbackHeader extends StatelessWidget {
  final String tenantId;
  final String tenantName;
  final TextEditingController controller;
  final bool loading;
  final bool legacyFallbackEnabled;
  final ValueChanged<bool>? onLegacyFallbackChanged;
  final VoidCallback onLoad;

  const _AssistitiFallbackHeader({
    required this.tenantId,
    required this.tenantName,
    required this.controller,
    required this.loading,
    required this.legacyFallbackEnabled,
    required this.onLegacyFallbackChanged,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.people_alt_rounded, color: AppColors.dpc, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Assistiti target + migrazione NOCF',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Modulo isolato read/write controllato · tenant: ${tenantName.trim().isEmpty ? tenantId : tenantName}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nessun listener, nessuno switch dashboard. CF e NOCF restano due flussi separati e bounded.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: !loading,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'CF manuali, massimo 3',
              hintText: 'RSSMRA80A01H501U, VRDLGI90B02F205X',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.panelSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.outlineSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.outlineSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.dpc, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Checkbox(
                value: legacyFallbackEnabled,
                onChanged: onLegacyFallbackChanged == null
                    ? null
                    : (bool? value) {
                        onLegacyFallbackChanged!(value ?? false);
                      },
              ),
              const Expanded(
                child: Text(
                  'Usa fallback legacy se il CF non è presente nel target',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: loading ? null : onLoad,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(loading ? 'Operazione...' : 'Leggi CF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoCfCopyPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool copyConfirmed;
  final bool copying;
  final Object? copyError;
  final RealAssistitiNoCfTargetCopyResult? copyResult;
  final ValueChanged<bool>? onCopyConfirmedChanged;
  final VoidCallback? onCopy;

  const _NoCfCopyPanel({
    required this.controller,
    required this.copyConfirmed,
    required this.copying,
    required this.copyError,
    required this.copyResult,
    required this.onCopyConfirmedChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dpc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.badge_outlined, color: AppColors.dpc, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Copia NOCF legacy → TARGET',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Inserisci codici TMP/manuali legacy NOCF. Non inserire CF reali e non inserire NOCF_<hash>: lo pseudo-CF canonico viene calcolato dal sistema.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !copying,
            maxLines: 3,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Codici NOCF legacy, massimo 5',
              hintText: 'TMP_SOFIA_CASTELLI_1778262346407000\nCODICE_MANUALE_STABILE',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.outlineSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.outlineSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.dpc, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: copyConfirmed,
                onChanged: onCopyConfirmedChanged == null
                    ? null
                    : (bool? value) {
                        onCopyConfirmedChanged!(value ?? false);
                      },
              ),
              const Expanded(
                child: Text(
                  'Confermo la copia reale NOCF verso TARGET. Verranno scritti assistito, identity lock e CF lock compatibile. Nessuna sorgente legacy viene modificata.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: copying || !copyConfirmed ? null : onCopy,
              icon: copying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_rounded),
              label: Text(copying ? 'Copia NOCF...' : 'Conferma e copia NOCF → TARGET'),
            ),
          ),
          if (copyError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              copyError.toString(),
              style: const TextStyle(
                color: AppColors.expiry,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (copyResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(label: 'NOCF copiati', value: '${copyResult!.writtenCount}'),
                _SummaryChip(label: 'Write assistiti', value: '${copyResult!.attemptedAssistitiWrites}'),
                _SummaryChip(label: 'Write identity lock', value: '${copyResult!.attemptedIdentityLockWrites}'),
                _SummaryChip(label: 'Write CF lock', value: '${copyResult!.attemptedCfLockWrites}'),
                _SummaryChip(label: 'Totale write', value: '${copyResult!.attemptedWrites}'),
                _SummaryChip(label: 'Read legacy', value: '${copyResult!.attemptedLegacyDocumentReads}'),
                _SummaryChip(label: 'Lookup duplicate', value: '${copyResult!.attemptedDuplicateGuardLookups}'),
              ],
            ),
            const SizedBox(height: 8),
            for (final RealAssistitiNoCfTargetCopyWrittenDocument document
                in copyResult!.writtenDocuments) ...<Widget>[
              _MetaLine(label: 'NOCF', value: document.identityAnchor),
              _MetaLine(label: 'assistitoPath', value: document.documentPath),
            ],
          ],
        ],
      ),
    );
  }
}


class _Migration1FirestoreReportPanel extends StatelessWidget {
  final bool loading;
  final Object? error;
  final RealAssistitiMigration1DataReportResult? result;
  final VoidCallback onRun;

  const _Migration1FirestoreReportPanel({
    required this.loading,
    required this.error,
    required this.result,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final RealAssistitiMigration1DataReportResult? report = result;
    final List<String> failedDocumentIds = report?.failedDocumentIds ?? const <String>[];
    final List<String> visibleFailedDocumentIds = failedDocumentIds.take(20).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.fact_check_rounded, color: AppColors.dpc, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Report Migration 1 dati target',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Esecuzione straordinaria read-only: una query bounded su tenants/{tenantId}/assistiti, massimo 100 read, nessuna write.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: loading ? null : onRun,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_rounded),
                label: Text(loading ? 'Report...' : 'Esegui report Migration 1'),
              ),
            ],
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              error.toString(),
              style: const TextStyle(
                color: AppColors.expiry,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (report != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(label: 'Scansionati', value: '${report.summary.inputDocumentCount}/${report.maxInputDocuments}'),
                _SummaryChip(label: 'Verificati', value: '${report.summary.verifiedCount}'),
                _SummaryChip(label: 'Falliti', value: '${report.summary.failedCount}'),
                _SummaryChip(label: 'CF', value: '${report.summary.cfCount}'),
                _SummaryChip(label: 'NOCF', value: '${report.summary.noCfCount}'),
                _SummaryChip(label: 'Resolved manual', value: '${report.summary.resolvedManualCount}'),
                _SummaryChip(label: 'Pending manual', value: '${report.summary.pendingManualCount}'),
                _SummaryChip(label: 'Contaminati', value: '${report.summary.contaminatedIdentityCount}'),
                _SummaryChip(label: 'Prefix stale', value: '${report.summary.staleSearchPrefixesCount}'),
                _SummaryChip(label: 'Read Firestore', value: '${report.firestoreReads}'),
                _SummaryChip(label: 'Write Firestore', value: '${report.firestoreWrites}'),
              ],
            ),
            if (report.summary.mismatchReasonCounts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'Mismatch rilevati',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: <Widget>[
                  for (final MapEntry<String, int> entry in report.summary.mismatchReasonCounts.entries)
                    _SummaryChip(label: entry.key, value: '${entry.value}'),
                ],
              ),
            ],
            if (failedDocumentIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _MetaLine(
                label: 'Documenti falliti',
                value: visibleFailedDocumentIds.join(', '),
              ),
              if (failedDocumentIds.length > visibleFailedDocumentIds.length)
                _MetaLine(
                  label: 'Altri documenti falliti',
                  value: '${failedDocumentIds.length - visibleFailedDocumentIds.length}',
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NoCfIdentityResolutionPanel extends StatelessWidget {
  final bool loading;
  final Object? error;
  final RealAssistitiNoCfIdentityResolutionPendingResult? pendingResult;
  final RealAssistitiNoCfIdentityResolutionWriteResult? writeResult;
  final VoidCallback onLoadPending;
  final ValueChanged<RealAssistitiNoCfIdentityResolutionPendingItem> onResolve;

  const _NoCfIdentityResolutionPanel({
    required this.loading,
    required this.error,
    required this.pendingResult,
    required this.writeResult,
    required this.onLoadPending,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final RealAssistitiNoCfIdentityResolutionPendingResult? result = pendingResult;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.rule_rounded, color: AppColors.dpc, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Risoluzione manuale ambiguità NOCF',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Lettura bounded dei soli assistiti target pending_manual. Il salvataggio aggiorna solo tenants/{tenantId}/assistiti/{assistitoId}.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: loading ? null : onLoadPending,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_search_rounded),
                label: Text(loading ? 'Controllo...' : 'Controlla ambiguità NOCF'),
              ),
            ],
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              error.toString(),
              style: const TextStyle(
                color: AppColors.expiry,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (writeResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(label: 'Risolto', value: writeResult!.assistitoId),
                _SummaryChip(label: 'fullName', value: writeResult!.fullName),
                _SummaryChip(label: 'Read tx', value: '${writeResult!.attemptedReads}'),
                _SummaryChip(label: 'Write tx', value: '${writeResult!.attemptedWrites}'),
              ],
            ),
          ],
          if (result != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(label: 'Pending', value: '${result.pendingCount}/${result.maxPendingItems}'),
                _SummaryChip(label: 'Read tentate', value: '${result.attemptedReads}'),
              ],
            ),
            const SizedBox(height: 10),
            if (result.items.isEmpty)
              const Text(
                'Nessuna ambiguità NOCF pending_manual trovata.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              for (final RealAssistitiNoCfIdentityResolutionPendingItem item in result.items) ...<Widget>[
                _NoCfIdentityResolutionPendingCard(
                  item: item,
                  loading: loading,
                  onResolve: onResolve,
                ),
                const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }
}

class _NoCfIdentityResolutionPendingCard extends StatelessWidget {
  final RealAssistitiNoCfIdentityResolutionPendingItem item;
  final bool loading;
  final ValueChanged<RealAssistitiNoCfIdentityResolutionPendingItem> onResolve;

  const _NoCfIdentityResolutionPendingCard({
    required this.item,
    required this.loading,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.fullName.isEmpty ? item.identityAnchor : item.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _MetaLine(label: 'assistitoId', value: item.assistitoId),
                _MetaLine(label: 'identityAnchor', value: item.identityAnchor),
                _MetaLine(label: 'candidateSplits', value: '${item.candidateSplits.length}'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: loading ? null : () => onResolve(item),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Risolvi'),
          ),
        ],
      ),
    );
  }
}

class _NoCfIdentityResolutionDialog extends StatefulWidget {
  final RealAssistitiNoCfIdentityResolutionPendingItem item;

  const _NoCfIdentityResolutionDialog({required this.item});

  @override
  State<_NoCfIdentityResolutionDialog> createState() => _NoCfIdentityResolutionDialogState();
}

class _NoCfIdentityResolutionDialogState extends State<_NoCfIdentityResolutionDialog> {
  late final TextEditingController _nomeController;
  late final TextEditingController _cognomeController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Map<String, String> firstSplit = widget.item.candidateSplits.isEmpty
        ? const <String, String>{}
        : widget.item.candidateSplits.first;
    _nomeController = TextEditingController(
      text: firstSplit['nome'] ?? widget.item.nome,
    );
    _cognomeController = TextEditingController(
      text: firstSplit['cognome'] ?? widget.item.cognome,
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final String nome = RealAssistitiNoCfIdentityResolutionWriter.normalizeManualNamePart(
        fieldName: 'nome',
        value: _nomeController.text,
      );
      final String cognome = RealAssistitiNoCfIdentityResolutionWriter.normalizeManualNamePart(
        fieldName: 'cognome',
        value: _cognomeController.text,
      );
      RealAssistitiNoCfIdentityResolutionWriter.buildCanonicalFullName(
        nome: nome,
        cognome: cognome,
      );
      Navigator.of(context).pop(_NoCfIdentityResolutionFormResult(nome: nome, cognome: cognome));
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text(
        'Risolvi identità NOCF',
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MetaLine(label: 'assistitoId', value: widget.item.assistitoId),
            _MetaLine(label: 'identityAnchor', value: widget.item.identityAnchor),
            if (widget.item.fullName.isNotEmpty) _MetaLine(label: 'fullName attuale', value: widget.item.fullName),
            const SizedBox(height: 12),
            TextField(
              controller: _nomeController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nome',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cognomeController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Cognome',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.expiry,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Salva risoluzione'),
        ),
      ],
    );
  }
}

class _NoCfIdentityResolutionFormResult {
  final String nome;
  final String cognome;

  const _NoCfIdentityResolutionFormResult({
    required this.nome,
    required this.cognome,
  });
}


class _AssistitiReadSummary extends StatelessWidget {
  final AssistitiTargetWithLegacyFallbackResult result;

  const _AssistitiReadSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: <Widget>[
          _SummaryChip(label: 'CF', value: '${result.requestedCount}/${result.maxFiscalCodes}'),
          _SummaryChip(label: 'Query target', value: '${result.targetAttemptedQueries}'),
          _SummaryChip(label: 'Read legacy', value: '${result.legacyAttemptedDocumentReads}'),
          _SummaryChip(label: 'Fallback', value: result.legacyFallbackEnabled ? 'attivo' : 'disattivo'),
          _SummaryChip(label: 'Missing', value: result.hasMissingItems ? result.missingFiscalCodes.join(', ') : '-'),
        ],
      ),
    );
  }
}

class _AssistitiCopyPanel extends StatelessWidget {
  final List<String> candidateFiscalCodes;
  final bool copyConfirmed;
  final bool copying;
  final Object? copyError;
  final RealAssistitiTargetCopyResult? copyResult;
  final RealAssistitiPostCopyVerificationResult? verificationResult;
  final RealAssistitiDryRunPreviewResult? dryRunDiagnosticResult;
  final ValueChanged<bool>? onCopyConfirmedChanged;
  final VoidCallback? onCopy;

  const _AssistitiCopyPanel({
    required this.candidateFiscalCodes,
    required this.copyConfirmed,
    required this.copying,
    required this.copyError,
    required this.copyResult,
    required this.verificationResult,
    required this.dryRunDiagnosticResult,
    required this.onCopyConfirmedChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCandidates = candidateFiscalCodes.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasCandidates ? AppColors.dpc : AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                hasCandidates ? Icons.upload_file_rounded : Icons.lock_outline_rounded,
                color: hasCandidates ? AppColors.dpc : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasCandidates
                      ? 'Copia target disponibile per CF LEGACY: ${candidateFiscalCodes.join(', ')}'
                      : 'Nessun assistito LEGACY candidabile alla copia target.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hasCandidates) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: copyConfirmed,
                  onChanged: onCopyConfirmedChanged == null
                      ? null
                      : (bool? value) {
                          onCopyConfirmedChanged!(value ?? false);
                        },
                ),
                const Expanded(
                  child: Text(
                    'Confermo la copia reale degli assistiti LEGACY selezionati verso TARGET. Il token tecnico viene generato automaticamente.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: copying || !copyConfirmed ? null : onCopy,
                icon: copying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded),
                label: Text(copying ? 'Copia e verifica...' : 'Conferma e copia LEGACY → TARGET'),
              ),
            ),
          ],
          if (copyError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              copyError.toString(),
              style: const TextStyle(
                color: AppColors.expiry,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (dryRunDiagnosticResult != null) ...<Widget>[
            const SizedBox(height: 10),
            _DryRunDiagnosticCard(result: dryRunDiagnosticResult!),
          ],
          if (copyResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(label: 'Write assistiti', value: '${copyResult!.attemptedAssistitiWrites}'),
                _SummaryChip(label: 'Write lock CF', value: '${copyResult!.attemptedCfLockWrites}'),
                _SummaryChip(label: 'Totale write', value: '${copyResult!.attemptedWrites}'),
              ],
            ),
          ],
          if (verificationResult != null) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(
                  label: 'Verifica post-copia',
                  value: verificationResult!.allVerified ? 'OK' : 'KO',
                ),
                _SummaryChip(label: 'Read verifica', value: '${verificationResult!.totalAttemptedReads}'),
                _SummaryChip(
                  label: 'Falliti',
                  value: verificationResult!.failedFiscalCodes.isEmpty
                      ? '-'
                      : verificationResult!.failedFiscalCodes.join(', '),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DryRunDiagnosticCard extends StatelessWidget {
  final RealAssistitiDryRunPreviewResult result;

  const _DryRunDiagnosticCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final List<RealAssistitiDryRunPreviewItem> blockedItems = result.items
        .where((RealAssistitiDryRunPreviewItem item) => item.blocked)
        .toList(growable: false);
    if (blockedItems.isEmpty) {
      return const _DiagnosticBox(
        title: 'Dry-run diagnostico',
        message: 'Nessun blocco rilevato nella diagnostica.',
      );
    }
    return _DiagnosticBox(
      title: 'Copia bloccata dal dry-run',
      message: blockedItems
          .map((RealAssistitiDryRunPreviewItem item) {
            return '${item.cf}: ${item.blockingReasons.join(', ')}';
          })
          .join('\n'),
    );
  }
}

class _DiagnosticBox extends StatelessWidget {
  final String title;
  final String message;

  const _DiagnosticBox({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.expiry),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.expiry,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AssistitoFallbackCard extends StatelessWidget {
  final AssistitiTargetWithLegacyFallbackItem item;

  const _AssistitoFallbackCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final String displayName = _displayName(item);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor(item)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SourceBadge(source: item.source),
            ],
          ),
          const SizedBox(height: 8),
          _MetaLine(label: 'cf', value: item.cf),
          _MetaLine(label: 'source', value: item.source),
          if (item.foundInTarget) _MetaLine(label: 'targetDocumentId', value: item.targetDocumentId),
          if (item.usedLegacyFallback)
            _MetaLine(
              label: 'legacySources',
              value: '${item.legacyBundle?.existingSourceCount ?? 0}',
            ),
          if (item.usedLegacyFallback)
            const _MetaLine(
              label: 'copyCandidate',
              value: 'true',
            ),
          if (item.reasons.isNotEmpty) _MetaLine(label: 'reasons', value: item.reasons.join(', ')),
        ],
      ),
    );
  }

  static Color _borderColor(AssistitiTargetWithLegacyFallbackItem item) {
    if (item.foundInTarget) {
      return Colors.white10;
    }
    if (item.usedLegacyFallback) {
      return AppColors.dpc;
    }
    return AppColors.expiry;
  }

  static String _displayName(AssistitiTargetWithLegacyFallbackItem item) {
    if (item.foundInTarget) {
      return _firstString(item.targetRawData, const <String>[
        'fullName',
        'displayName',
        'patientName',
        'assistitoName',
        'name',
      ]);
    }
    final Map<String, dynamic> patient = item.legacyBundle?.patient.rawData ?? const <String, dynamic>{};
    final Map<String, dynamic> dashboard =
        item.legacyBundle?.dashboardIndex.rawData ?? const <String, dynamic>{};
    final String patientName = _firstString(patient, const <String>[
      'fullName',
      'displayName',
      'patientName',
      'assistitoName',
      'name',
    ]);
    if (patientName != 'Assistito senza nome') {
      return patientName;
    }
    return _firstString(dashboard, const <String>[
      'fullName',
      'displayName',
      'patientName',
      'assistitoName',
      'name',
    ]);
  }

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return 'Assistito senza nome';
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (source == AssistitiTargetWithLegacyFallbackItem.sourceTarget) {
      label = 'TARGET';
      color = AppColors.recipe;
    } else if (source == AssistitiTargetWithLegacyFallbackItem.sourceLegacyFallback) {
      label = 'LEGACY';
      color = AppColors.dpc;
    } else {
      label = 'MISSING';
      color = AppColors.expiry;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF121212),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AssistitiInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  const _AssistitiInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: warning ? AppColors.expiry : AppColors.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: warning ? AppColors.expiry : AppColors.dpc, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
