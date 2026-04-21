import 'package:flutter/material.dart';

import 'package:family_boxes_2/config/billing_config.dart';
import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/models/entitlement.dart';
import 'package:family_boxes_2/services/billing_service.dart';
import 'package:family_boxes_2/services/entitlement_service.dart';

class PaywallPage extends StatefulWidget {
  final AuthUser user;
  final Entitlement entitlement;
  final Future<void> Function() onEntitlementRefresh;

  const PaywallPage({
    super.key,
    required this.user,
    required this.entitlement,
    required this.onEntitlementRefresh,
  });

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Box Premium')),
      body: ValueListenableBuilder<BillingState>(
        valueListenable: _billing.stateListenable,
        builder: (context, state, _) {
          final product = state.annualProduct;
          final statusText = _entitlement.phaseLabel;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0A3E),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF3D2966)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Premium annuale',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Accesso completo all’app, con trial gratuito iniziale e ritorno automatico alla sola lettura in assenza di piano attivo.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    _bullet('Trial iniziale: ${BillingConfig.trialLabel}'),
                    _bullet('Formula: ${BillingConfig.renewalLabel}'),
                    _bullet('Dopo la scadenza: sola lettura totale'),
                    _bullet('Export sempre consentito'),
                    const SizedBox(height: 16),
                    Text(
                      'Stato attuale: $statusText',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (product != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Prezzo Play: ${product.price}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (state.loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (state.message != null)
                  _infoCard(
                    icon: Icons.info_outline_rounded,
                    text: state.message!,
                  ),
                if (state.error != null)
                  _infoCard(
                    icon: Icons.error_outline_rounded,
                    text: state.error!,
                    danger: true,
                  ),
                if (state.notFoundIds.isNotEmpty)
                  _infoCard(
                    icon: Icons.search_off_rounded,
                    text: 'Prodotto non trovato su Play: ${state.notFoundIds.join(', ')}',
                    danger: true,
                  ),
                if (!state.storeAvailable && state.error == null)
                  _infoCard(
                    icon: Icons.store_mall_directory_outlined,
                    text: 'Store Play non disponibile. Su FlutLab/test locale il catalogo può risultare vuoto fuori dalla track di test.',
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.loading || state.purchasePending || product == null
                    ? null
                    : () async {
                        await _billing.buyAnnualSubscription();
                        if (!mounted) return;
                        setState(() {});
                      },
                icon: state.purchasePending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium_rounded),
                label: Text(product == null ? 'Prodotto Play non disponibile' : 'Attiva trial / abbonamento'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: state.loading || state.purchasePending
                    ? null
                    : () async {
                        await _billing.restorePurchases();
                        if (!mounted) return;
                        setState(() {});
                      },
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Ripristina acquisti'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: state.loading
                    ? null
                    : () async {
                        await _billing.refreshCatalog();
                        if (!mounted) return;
                        setState(() {});
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Aggiorna catalogo Play'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nota sviluppo: l’accesso viene aggiornato subito dopo acquisto o restore, ma la verifica server-side del token Play è il passo successivo prima della release finale.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String text,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFF4A1626) : const Color(0xFF281A4A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: danger ? const Color(0xFFFF8A80) : const Color(0xFF3D2966),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: danger ? const Color(0xFFFF8A80) : Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: danger ? const Color(0xFFFFC1BC) : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
