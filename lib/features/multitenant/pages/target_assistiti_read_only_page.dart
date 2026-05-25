import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/multitenant/readers/assistiti_target_with_legacy_fallback_reader.dart';
import '../../../data/multitenant/verifiers/real_assistiti_post_copy_verifier.dart';
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
  final TextEditingController _manualCopyTokenController = TextEditingController();

  AssistitiTargetWithLegacyFallbackResult? _result;
  RealAssistitiTargetCopyResult? _copyResult;
  RealAssistitiPostCopyVerificationResult? _verificationResult;
  Object? _error;
  Object? _copyError;
  bool _loading = false;
  bool _copying = false;
  bool _requested = false;
  bool _enableLegacyFallback = true;

  @override
  void dispose() {
    _cfController.dispose();
    _manualCopyTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadAssistitiByManualCf() async {
    if (_loading || _copying) {
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

  Future<void> _copyLegacyFallbackItemsToTarget() async {
    if (_loading || _copying) {
      return;
    }

    final List<String> fiscalCodes = _copyEligibleFiscalCodes();
    if (fiscalCodes.isEmpty) {
      setState(() {
        _copyError = 'Nessun assistito legacy_fallback copiabile. Eseguire prima una lettura con fallback attivo.';
        _copyResult = null;
        _verificationResult = null;
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

    setState(() {
      _copying = true;
      _copyError = null;
      _copyResult = null;
      _verificationResult = null;
    });

    try {
      final RealAssistitiTargetCopyResult copyResult = await writer.copyByManualFiscalCodes(
        tenantId: session.tenantId,
        fiscalCodes: fiscalCodes,
        manualConfirmationToken: _manualCopyTokenController.text,
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _copyError = error;
        _copyResult = null;
        _verificationResult = null;
        _copying = false;
      });
    }
  }

  List<String> _copyEligibleFiscalCodes() {
    final AssistitiTargetWithLegacyFallbackResult? result = _result;
    if (result == null) {
      return const <String>[];
    }
    final List<String> fiscalCodes = <String>[];
    for (final AssistitiTargetWithLegacyFallbackItem item in result.items) {
      if (item.usedLegacyFallback) {
        fiscalCodes.add(item.cf);
      }
    }
    return List<String>.unmodifiable(fiscalCodes);
  }

  String _expectedManualCopyToken(TenantSession session) {
    final List<String> fiscalCodes = _copyEligibleFiscalCodes();
    if (fiscalCodes.isEmpty) {
      return '';
    }
    try {
      return RealAssistitiTargetCopyWriter.buildRequiredManualConfirmationToken(
        tenantId: session.tenantId,
        normalizedFiscalCodes: fiscalCodes,
      );
    } catch (_) {
      return '';
    }
  }

  static List<String> _parseManualFiscalCodes(String rawInput) {
    final String normalized = rawInput.replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final bool hasExplicitSeparators = RegExp(r'[,;\n\t]').hasMatch(normalized);
    if (!hasExplicitSeparators) {
      return normalized
          .split(RegExp(r'\s+'))
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    }

    final List<String> values = <String>[];
    final List<String> segments = normalized.split(RegExp(r'[,;\n\t]'));
    for (final String segment in segments) {
      final String trimmedSegment = segment.trim();
      if (trimmedSegment.isEmpty) {
        values.add('');
        continue;
      }
      final List<String> tokens = trimmedSegment.split(RegExp(r'\s+'));
      for (final String token in tokens) {
        values.add(token.trim());
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final TenantSession session = TenantSessionScope.of(context);
    final List<String> copyEligibleFiscalCodes = _copyEligibleFiscalCodes();
    final String expectedManualCopyToken = _expectedManualCopyToken(session);
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
                loading: _loading,
                legacyFallbackEnabled: _enableLegacyFallback,
                onLegacyFallbackChanged: _loading || _copying
                    ? null
                    : (bool value) {
                        setState(() {
                          _enableLegacyFallback = value;
                        });
                      },
                onLoad: _loadAssistitiByManualCf,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _buildBody(
                  expectedManualCopyToken: expectedManualCopyToken,
                  copyEligibleFiscalCodes: copyEligibleFiscalCodes,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required String expectedManualCopyToken,
    required List<String> copyEligibleFiscalCodes,
  }) {
    if (!_requested) {
      return const _AssistitiInfoCard(
        icon: Icons.touch_app_rounded,
        title: 'Lettura non avviata',
        message:
            'Inserisci massimo 3 CF manuali. Il modulo legge prima tenants/{tenantId}/assistiti e usa il legacy solo come fallback controllato.',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
        title: 'Nessun risultato disponibile',
        message: 'La lettura è bounded e manuale: nessun documento viene creato o modificato.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AssistitiReadSummary(result: result),
        const SizedBox(height: 12),
        _AssistitiCopyPanel(
          tokenController: _manualCopyTokenController,
          copying: _copying,
          copyEligibleFiscalCodes: copyEligibleFiscalCodes,
          expectedManualCopyToken: expectedManualCopyToken,
          copyError: _copyError,
          copyResult: _copyResult,
          verificationResult: _verificationResult,
          onCopy: copyEligibleFiscalCodes.isEmpty ? null : _copyLegacyFallbackItemsToTarget,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: result.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              return _AssistitoFallbackCard(item: result.items[index]);
            },
          ),
        ),
      ],
    );
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
                      'Assistiti target + fallback legacy',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Modulo isolato manuale · tenant: ${tenantName.trim().isEmpty ? tenantId : tenantName}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nessun listener, nessuno switch dashboard. Lettura manuale max 3 CF; copia target solo con token manuale e verifica post-copia.',
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
                label: Text(loading ? 'Lettura...' : 'Leggi CF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
  final TextEditingController tokenController;
  final bool copying;
  final List<String> copyEligibleFiscalCodes;
  final String expectedManualCopyToken;
  final Object? copyError;
  final RealAssistitiTargetCopyResult? copyResult;
  final RealAssistitiPostCopyVerificationResult? verificationResult;
  final VoidCallback? onCopy;

  const _AssistitiCopyPanel({
    required this.tokenController,
    required this.copying,
    required this.copyEligibleFiscalCodes,
    required this.expectedManualCopyToken,
    required this.copyError,
    required this.copyResult,
    required this.verificationResult,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasEligibleItems = copyEligibleFiscalCodes.isNotEmpty;
    final bool canCopy = hasEligibleItems && !copying && onCopy != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lock_rounded, color: AppColors.dpc, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasEligibleItems
                      ? 'Copia target controllata: ${copyEligibleFiscalCodes.join(', ')}'
                      : 'Copia target controllata non disponibile',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasEligibleItems
                ? 'Sono copiabili solo i CF letti da LEGACY fallback. La copia richiede token manuale e avvia verifica post-copia.'
                : 'Esegui una lettura con fallback attivo: solo gli item LEGACY diventano candidati alla copia target.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (expectedManualCopyToken.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _CopyTokenBox(token: expectedManualCopyToken),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: tokenController,
                  enabled: !copying,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Token manuale copia',
                    hintText: 'Incolla il token richiesto',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.panelSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.outlineSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.outlineSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.dpc, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: canCopy ? onCopy : null,
                icon: copying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(copying ? 'Copia...' : 'Copia target'),
              ),
            ],
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
            _SummaryChip(label: 'Write target', value: '${copyResult!.attemptedAssistitiWrites} assistiti + ${copyResult!.attemptedCfLockWrites} lock'),
          ],
          if (verificationResult != null) ...<Widget>[
            const SizedBox(height: 6),
            _SummaryChip(
              label: 'Verifica post-copia',
              value: verificationResult!.allVerified
                  ? 'OK ${verificationResult!.verifiedCount}/${verificationResult!.items.length}'
                  : 'FAIL ${verificationResult!.failedFiscalCodes.join(', ')}',
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyTokenBox extends StatelessWidget {
  final String token;

  const _CopyTokenBox({required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: SelectableText(
        'Token richiesto: $token',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
