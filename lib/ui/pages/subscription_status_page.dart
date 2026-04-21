import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/models/entitlement.dart';
import 'package:family_boxes_2/services/billing_service.dart';
import 'package:family_boxes_2/services/entitlement_service.dart';
import 'package:family_boxes_2/ui/pages/paywall_page.dart';

class SubscriptionStatusPage extends StatefulWidget {
  final AuthUser user;
  final Entitlement entitlement;
  final Future<void> Function()? onActivateDebugSubscription;
  final Future<void> Function()? onResetTrial;
  final Future<void> Function()? onForceReadOnly;
  final Future<void> Function()? onRefresh;

  const SubscriptionStatusPage({
    super.key,
    required this.user,
    required this.entitlement,
    this.onActivateDebugSubscription,
    this.onResetTrial,
    this.onForceReadOnly,
    this.onRefresh,
  });

  @override
  State<SubscriptionStatusPage> createState() => _SubscriptionStatusPageState();
}

class _SubscriptionStatusPageState extends State<SubscriptionStatusPage> {
  BillingService get _billing => BillingService.instance;
  late Entitlement _entitlement;

  @override
  void initState() {
    _entitlement = widget.entitlement;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _billing.bindUser(widget.user);
      await _reloadEntitlement();
      if (mounted) setState(() {});
    });
  }

  Future<void> _reloadEntitlement() async {
    final fresh = await EntitlementService.refreshForUser(widget.user);
    if (!mounted) return;
    setState(() {
      _entitlement = fresh;
    });
  }

  @override
  void didUpdateWidget(covariant SubscriptionStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid || oldWidget.entitlement != widget.entitlement) {
      _entitlement = widget.entitlement;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _billing.bindUser(widget.user);
        await _reloadEntitlement();
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final accessMode = _entitlement.accessModeAt(now);
    final remainingDays = _entitlement.remainingDaysAt(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Stato accesso')),
      body: ValueListenableBuilder<BillingState>(
        valueListenable: _billing.stateListenable,
        builder: (context, billingState, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0A3E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF3D2966)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.visibleName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(widget.user.email, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Text('Stato: ${_entitlement.phaseLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Accesso attuale: ${accessMode.label}'),
                    const SizedBox(height: 8),
                    Text('Trial fino al: ${_formatDate(_entitlement.trialEndAt)}'),
                    Text('Abbonamento fino al: ${_formatDate(_entitlement.subscriptionEndAt)}'),
                    if (remainingDays != null) ...[
                      const SizedBox(height: 8),
                      Text('Giorni residui: $remainingDays'),
                    ],
                    if (_entitlement.productId != null) ...[
                      const SizedBox(height: 8),
                      Text('Prodotto Play: ${_entitlement.productId}'),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Trial e sola lettura sono già reali. Billing Play ora è innestato come layer separato, pronto per la verifica server-side nel passo successivo.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (billingState.message != null)
                Text(
                  billingState.message!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (billingState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  billingState.error!,
                  style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaywallPage(
                        user: widget.user,
                        entitlement: _entitlement,
                        onEntitlementRefresh: widget.onRefresh ?? () async {},
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Apri paywall'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: billingState.purchasePending
                    ? null
                    : () async {
                        await _billing.restorePurchases();
                        await _reloadEntitlement();
                        if (!mounted) return;
                        setState(() {});
                      },
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Ripristina acquisti'),
              ),
              const SizedBox(height: 10),
              if (widget.onRefresh != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onRefresh!.call();
                    await _reloadEntitlement();
                    await _billing.refreshCatalog();
                    if (!mounted) return;
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Ricarica stato accesso'),
                ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Text('Debug entitlement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (widget.onActivateDebugSubscription != null)
                  OutlinedButton.icon(
                    onPressed: widget.onActivateDebugSubscription,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('Attiva abbonamento debug'),
                  ),
                if (widget.onResetTrial != null)
                  OutlinedButton.icon(
                    onPressed: widget.onResetTrial,
                    icon: const Icon(Icons.timelapse_rounded),
                    label: const Text('Resetta trial da oggi'),
                  ),
                if (widget.onForceReadOnly != null)
                  OutlinedButton.icon(
                    onPressed: widget.onForceReadOnly,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Forza sola lettura'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
