import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/multitenant/readers/target_assistiti_read_only_reader.dart';
import '../../../theme/app_theme.dart';
import '../../auth/models/tenant_session.dart';

class TargetAssistitiReadOnlyPage extends StatefulWidget {
  const TargetAssistitiReadOnlyPage({super.key});

  @override
  State<TargetAssistitiReadOnlyPage> createState() => _TargetAssistitiReadOnlyPageState();
}

class _TargetAssistitiReadOnlyPageState extends State<TargetAssistitiReadOnlyPage> {
  static const int _maxDocuments = TargetAssistitiReadOnlyReader.defaultMaxDocuments;

  TargetAssistitiReadOnlyResult? _result;
  Object? _error;
  bool _loading = false;
  bool _requested = false;

  Future<void> _loadTargetAssistiti() async {
    if (_loading) {
      return;
    }

    final TenantSession session = TenantSessionScope.of(context);
    final TargetAssistitiReadOnlyReader reader = TargetAssistitiReadOnlyReader(
      firestore: FirebaseFirestore.instance,
    );

    setState(() {
      _loading = true;
      _requested = true;
      _error = null;
    });

    try {
      final TargetAssistitiReadOnlyResult result = await reader.readAssistiti(
        tenantId: session.tenantId,
        maxDocuments: _maxDocuments,
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
              _TargetAssistitiHeader(
                tenantId: session.tenantId,
                tenantName: session.tenantName,
                loading: _loading,
                onLoad: _loadTargetAssistiti,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_requested) {
      return const _TargetAssistitiInfoCard(
        icon: Icons.touch_app_rounded,
        title: 'Lettura non avviata',
        message:
            'Questo modulo non legge automaticamente Firestore. Premi “Carica assistiti target” per eseguire una singola query bounded su tenants/{tenantId}/assistiti.',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Object? error = _error;
    if (error != null) {
      return _TargetAssistitiInfoCard(
        icon: Icons.error_outline_rounded,
        title: 'Lettura target non riuscita',
        message: error.toString(),
        warning: true,
      );
    }

    final TargetAssistitiReadOnlyResult? result = _result;
    if (result == null || result.empty) {
      return const _TargetAssistitiInfoCard(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun assistito target disponibile',
        message:
            'La collection target può essere assente o vuota: è uno stato valido. Il modulo non crea documenti e non modifica il legacy.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Documenti letti: ${result.returnedCount}/${result.requestedLimit}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: result.documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              return _TargetAssistitoCard(document: result.documents[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _TargetAssistitiHeader extends StatelessWidget {
  final String tenantId;
  final String tenantName;
  final bool loading;
  final VoidCallback onLoad;

  const _TargetAssistitiHeader({
    required this.tenantId,
    required this.tenantName,
    required this.loading,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.people_alt_rounded, color: AppColors.dpc, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Assistiti target',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Modulo isolato read-only · tenant: ${tenantName.trim().isEmpty ? tenantId : tenantName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nessun listener, nessuna write, nessuno switch dashboard. La collection target assente o vuota è gestita come stato valido.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                : const Icon(Icons.refresh_rounded),
            label: Text(loading ? 'Caricamento...' : 'Carica assistiti target'),
          ),
        ],
      ),
    );
  }
}

class _TargetAssistitoCard extends StatelessWidget {
  final TargetAssistitiReadDocument document;

  const _TargetAssistitoCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final String fullName = document.assistito.fullName.trim().isEmpty
        ? 'Assistito senza nome'
        : document.assistito.fullName.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: document.documentIdentityValid ? Colors.white10 : AppColors.expiry,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _IdentityBadge(valid: document.documentIdentityValid),
            ],
          ),
          const SizedBox(height: 8),
          _MetaLine(label: 'documentId', value: document.documentId),
          _MetaLine(label: 'assistitoId', value: document.assistito.assistitoId),
          _MetaLine(label: 'cf', value: document.assistito.cf.isEmpty ? '-' : document.assistito.cf),
          _MetaLine(
            label: 'nome/cognome',
            value: '${_dash(document.assistito.nome)} / ${_dash(document.assistito.cognome)}',
          ),
        ],
      ),
    );
  }

  static String _dash(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }
}

class _IdentityBadge extends StatelessWidget {
  final bool valid;

  const _IdentityBadge({required this.valid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: valid ? AppColors.recipe : AppColors.expiry,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        valid ? 'ID valido' : 'ID da verificare',
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

class _TargetAssistitiInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  const _TargetAssistitiInfoCard({
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
