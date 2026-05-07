import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/patient_identity_utils.dart';
import '../../../core/utils/patient_input_normalizer.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/patient_dashboard_index.dart';
import '../../../data/repositories/identity_resolution_requests_repository.dart';
import '../../../data/repositories/patient_dashboard_index_repository.dart';
import '../../../theme/app_theme.dart';

class IdentityResolutionPage extends StatefulWidget {
  const IdentityResolutionPage({super.key});

  @override
  State<IdentityResolutionPage> createState() => _IdentityResolutionPageState();
}

class _IdentityResolutionPageState extends State<IdentityResolutionPage> {
  late final PatientDashboardIndexRepository _indexRepository;
  late final IdentityResolutionRequestsRepository _requestsRepository;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _targetFiscalCodeController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<PatientDashboardIndex> _candidates = const <PatientDashboardIndex>[];
  PatientDashboardIndex? _sourceCandidate;
  PatientDashboardIndex? _targetCandidate;
  bool _loading = false;
  bool _submitting = false;
  String _message = '';
  int _searchRequestToken = 0;

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _indexRepository = PatientDashboardIndexRepository(datasource: datasource);
    _requestsRepository = IdentityResolutionRequestsRepository(datasource: datasource);
  }

  @override
  void dispose() {
    _searchRequestToken++;
    _searchController.dispose();
    _targetFiscalCodeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _searchCandidates() async {
    final String query = _searchController.text.trim();
    final int requestToken = ++_searchRequestToken;
    if (query.length < 3) {
      setState(() {
        _loading = false;
        _message = 'Inserisci almeno 3 caratteri per cercare nell’indice dashboard.';
        _candidates = const <PatientDashboardIndex>[];
        _sourceCandidate = null;
        _targetCandidate = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final List<PatientDashboardIndex> results =
          await _indexRepository.searchByPrefix(query, limit: 60);
      if (!_isCurrentSearch(requestToken, query)) return;
      setState(() {
        _candidates = results;
        _sourceCandidate = null;
        _targetCandidate = null;
        _message = results.isEmpty
            ? 'Nessun candidato trovato nell’indice dashboard.'
            : 'Candidati trovati: ${results.length}. Seleziona origine e destinazione.';
      });
    } catch (e) {
      if (!_isCurrentSearch(requestToken, query)) return;
      setState(() {
        _message = 'Errore ricerca identità: $e';
      });
    } finally {
      if (_isCurrentSearch(requestToken, query)) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _isCurrentSearch(int requestToken, String query) {
    if (!mounted) return false;
    return requestToken == _searchRequestToken && _searchController.text.trim() == query;
  }

  Future<void> _submitRequest(IdentityResolutionRequestAction action) async {
    final String manualTargetCf =
        PatientInputNormalizer.normalizeFiscalCode(_targetFiscalCodeController.text);
    final String targetCf = manualTargetCf.isNotEmpty
        ? manualTargetCf
        : PatientInputNormalizer.normalizeFiscalCode(_targetCandidate?.fiscalCode ?? '');
    final String sourceCf =
        PatientInputNormalizer.normalizeFiscalCode(_sourceCandidate?.fiscalCode ?? '');
    final String normalizedName = _sameNameKey(_sourceCandidate, _targetCandidate);
    final List<String> candidateFiscalCodes = <String>{
      if (sourceCf.isNotEmpty) sourceCf,
      if (targetCf.isNotEmpty) targetCf,
      if (_targetCandidate != null)
        PatientInputNormalizer.normalizeFiscalCode(_targetCandidate!.fiscalCode),
    }.where((String item) => item.isNotEmpty).toList()
      ..sort();

    final String? validationError = _validateRequest(action, sourceCf, targetCf);
    if (validationError != null) {
      setState(() {
        _message = validationError;
      });
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(_confirmTitle(action), style: const TextStyle(color: Colors.white)),
        content: Text(
          _confirmBody(action, sourceCf, targetCf),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crea richiesta'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _message = '';
    });

    try {
      final String requestId = await _requestsRepository.createUserConfirmedRequest(
        action: action,
        sourceFiscalCode: sourceCf,
        targetFiscalCode: targetCf,
        sourcePatientId: _sourceCandidate?.id,
        targetPatientId: _targetCandidate?.id,
        selectedFiscalCode: targetCf,
        normalizedName: normalizedName,
        candidateFiscalCodes: candidateFiscalCodes,
        reason: _reasonController.text.trim().isEmpty
            ? action.defaultReason
            : _reasonController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _message = action.backendProcessable
            ? 'Richiesta creata: $requestId. Il backend può processarla nel batch manuale.'
            : 'Richiesta creata: $requestId. Resterà in attesa del futuro executor backend merge.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Errore creazione richiesta identità: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String? _validateRequest(
    IdentityResolutionRequestAction action,
    String sourceCf,
    String targetCf,
  ) {
    if (targetCf.isEmpty) {
      return 'Seleziona o inserisci il codice fiscale corretto.';
    }
    if (action == IdentityResolutionRequestAction.createCanonicalPatient) {
      if (_isTemporaryCf(targetCf)) {
        return 'Il paziente canonico richiede un codice fiscale reale, non TMP.';
      }
      return null;
    }
    if (sourceCf.isEmpty) {
      return 'Seleziona un assistito origine.';
    }
    if (sourceCf == targetCf) {
      return 'Origine e destinazione coincidono: nessuna richiesta necessaria.';
    }
    if (action == IdentityResolutionRequestAction.mergeSameNamePatient &&
        !_hasSameNormalizedName(_sourceCandidate, _targetCandidate)) {
      return 'Per merge nome/cognome uguale seleziona due candidati con stesso nome normalizzato.';
    }
    if (action == IdentityResolutionRequestAction.mergeSimilarFiscalCodePatient &&
        !_hasSimilarFiscalCode(sourceCf, targetCf)) {
      return 'Per merge CF simile seleziona codici fiscali con variazione minima.';
    }
    return null;
  }

  bool _isTemporaryCf(String value) {
    return isTemporaryPatientKey(PatientInputNormalizer.normalizeFiscalCode(value));
  }

  bool _hasSameNormalizedName(PatientDashboardIndex? a, PatientDashboardIndex? b) {
    final String keyA = _normalizedName(a?.fullName ?? '');
    final String keyB = _normalizedName(b?.fullName ?? '');
    return keyA.isNotEmpty && keyA == keyB;
  }

  String _sameNameKey(PatientDashboardIndex? a, PatientDashboardIndex? b) {
    if (_hasSameNormalizedName(a, b)) {
      return _normalizedName(a?.fullName ?? '');
    }
    return _normalizedName(a?.fullName ?? b?.fullName ?? '');
  }

  String _normalizedName(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _hasSimilarFiscalCode(String a, String b) {
    final String left = PatientInputNormalizer.normalizeFiscalCode(a);
    final String right = PatientInputNormalizer.normalizeFiscalCode(b);
    if (left.length != 16 || right.length != 16 || left == right) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) diff++;
    }
    return diff > 0 && diff <= 3;
  }

  String _confirmTitle(IdentityResolutionRequestAction action) {
    switch (action) {
      case IdentityResolutionRequestAction.createCanonicalPatient:
        return 'Conferma creazione paziente canonico';
      case IdentityResolutionRequestAction.mergeSameNamePatient:
        return 'Conferma richiesta merge per nome uguale';
      case IdentityResolutionRequestAction.mergeSimilarFiscalCodePatient:
        return 'Conferma richiesta merge per CF simile';
      case IdentityResolutionRequestAction.chooseCorrectFiscalCode:
        return 'Conferma scelta codice fiscale corretto';
    }
  }

  String _confirmBody(
    IdentityResolutionRequestAction action,
    String sourceCf,
    String targetCf,
  ) {
    final String source = sourceCf.isEmpty ? '-' : sourceCf;
    final String target = targetCf.isEmpty ? '-' : targetCf;
    final String base = 'Origine: $source\nDestinazione scelta: $target\n\n';
    if (action.backendProcessable) {
      return '${base}Il frontend non correggerà direttamente i dati. Verrà creata una richiesta che il backend potrà processare.';
    }
    return '${base}Questa richiesta non verrà processata dal backend attuale. Rimarrà in attesa del futuro executor merge dedicato.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 82, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identità assistiti',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Segnala incoerenze e crea richieste backend-owned. Nessuna correzione multi-documento viene eseguita dal frontend.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            _searchPanel(),
            const SizedBox(height: 14),
            _actionPanel(),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _message,
                style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(child: _candidateList()),
          ],
        ),
      ),
    );
  }

  Widget _searchPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Cerca nome, cognome o CF nell’indice dashboard',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _searchCandidates(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _searchCandidates,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Cerca'),
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    final String sourceCf =
        PatientInputNormalizer.normalizeFiscalCode(_sourceCandidate?.fiscalCode ?? '');
    final String targetCf = PatientInputNormalizer.normalizeFiscalCode(
      _targetFiscalCodeController.text.trim().isNotEmpty
          ? _targetFiscalCodeController.text
          : (_targetCandidate?.fiscalCode ?? ''),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _infoChip('Origine', sourceCf.isEmpty ? '-' : sourceCf),
              _infoChip('Destinazione', targetCf.isEmpty ? '-' : targetCf),
              _infoChip(
                'Nome uguale',
                _hasSameNormalizedName(_sourceCandidate, _targetCandidate) ? 'SI' : 'NO',
              ),
              _infoChip(
                'CF simile',
                _hasSimilarFiscalCode(sourceCf, targetCf) ? 'SI' : 'NO',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetFiscalCodeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'CF corretto manuale, opzionale',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Motivo/note, opzionale',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submitRequest(
                          IdentityResolutionRequestAction.createCanonicalPatient,
                        ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Crea canonico'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submitRequest(
                          IdentityResolutionRequestAction.chooseCorrectFiscalCode,
                        ),
                icon: const Icon(Icons.fact_check),
                label: const Text('Scegli CF corretto'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submitRequest(
                          IdentityResolutionRequestAction.mergeSameNamePatient,
                        ),
                icon: const Icon(Icons.badge),
                label: const Text('Merge nome uguale'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submitRequest(
                          IdentityResolutionRequestAction.mergeSimilarFiscalCodePatient,
                        ),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Merge CF simile'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _candidateList() {
    if (_candidates.isEmpty) {
      return const Center(
        child: Text(
          'Nessun candidato selezionato. Cerca dall’indice dashboard per iniziare.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final PatientDashboardIndex candidate = _candidates[index];
        final bool isSource = _sourceCandidate?.fiscalCode == candidate.fiscalCode;
        final bool isTarget = _targetCandidate?.fiscalCode == candidate.fiscalCode;
        final bool isTmp = _isTemporaryCf(candidate.fiscalCode);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSource || isTarget ? AppColors.yellow : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.fullName.trim().isEmpty
                          ? candidate.fiscalCode
                          : candidate.fullName.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.fiscalCode} · ${candidate.city.trim().isEmpty ? '-' : candidate.city.trim()}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isTmp) _badge('TMP', AppColors.red),
                        if (candidate.hasRecipes) _badge('Ricette', AppColors.green),
                        if (candidate.hasDebt) _badge('Debito', AppColors.amber),
                        if (candidate.hasAdvance) _badge('Anticipo', AppColors.yellow),
                        if (candidate.familyId.trim().isNotEmpty) _badge('Famiglia', AppColors.coral),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _sourceCandidate = candidate),
                    child: Text(isSource ? 'Origine ✓' : 'Origine'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _targetCandidate = candidate;
                      _targetFiscalCodeController.text = candidate.fiscalCode;
                    }),
                    child: Text(isTarget ? 'Destinazione ✓' : 'Destinazione'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
    );
  }
}
