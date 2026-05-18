import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../core/utils/family_group_color_utils.dart';
import '../../../core/utils/patient_identity_utils.dart';
import '../../../core/utils/patient_input_normalizer.dart';
import '../../../core/utils/phbox_contract_utils.dart';
import '../../../core/utils/pending_pdf_delete_storage.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/doctor_patient_link.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/patient_dashboard_index.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/therapeutic_advice_note.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/dashboard_totals_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/family_groups_repository.dart';
import '../../../data/repositories/identity_resolution_requests_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/patient_dashboard_index_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../data/repositories/runtime_signal_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/therapeutic_advice_repository.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../theme/app_theme.dart';

class _PendingFamilyMembershipUpdate {
  final DocumentReference<Map<String, dynamic>> reference;
  final List<String> memberFiscalCodes;

  const _PendingFamilyMembershipUpdate({
    required this.reference,
    required this.memberFiscalCodes,
  });
}

class PatientDetailDashboardArchiveDelta {
  final int recipeCountDelta;
  final int dpcCountDelta;
  final String patientFiscalCode;
  final List<String> deletedImportIds;
  final bool patientDeleted;

  const PatientDetailDashboardArchiveDelta({
    this.recipeCountDelta = 0,
    this.dpcCountDelta = 0,
    this.patientFiscalCode = '',
    this.deletedImportIds = const <String>[],
    this.patientDeleted = false,
  });

  bool get hasDelta => recipeCountDelta != 0 || dpcCountDelta != 0;
  bool get hasDeletedImports => deletedImportIds.isNotEmpty;
  bool get hasAnyResult => hasDelta || hasDeletedImports || patientDeleted;
}

class PatientDetailPage extends StatefulWidget {
  final String fiscalCode;

  const PatientDetailPage({super.key, required this.fiscalCode});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late final PatientsRepository _patientsRepository;
  late final AdvancesRepository _advancesRepository;
  late final DebtsRepository _debtsRepository;
  late final BookingsRepository _bookingsRepository;
  late final PrescriptionsRepository _prescriptionsRepository;
  late final DrivePdfImportsRepository _drivePdfImportsRepository;
  late final FamilyGroupsRepository _familyGroupsRepository;
  late final SettingsRepository _settingsRepository;
  late final DoctorPatientLinksRepository _doctorPatientLinksRepository;
  late final TherapeuticAdviceRepository _therapeuticAdviceRepository;
  late final DashboardTotalsRepository _dashboardTotalsRepository;
  late final PatientDashboardIndexRepository _patientDashboardIndexRepository;
  late final IdentityResolutionRequestsRepository _identityResolutionRequestsRepository;
  late final RuntimeSignalRepository _runtimeSignalRepository;

  Future<_PatientDetailData>? _future;
  String _message = '';
  late String _currentFiscalCode;
  int _archiveRecipeCountDeltaForDashboard = 0;
  int _archiveDpcCountDeltaForDashboard = 0;
  final Set<String> _deletedArchiveImportIdsForDashboard = <String>{};

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _advancesRepository = AdvancesRepository(datasource: datasource);
    _debtsRepository = DebtsRepository(datasource: datasource);
    _bookingsRepository = BookingsRepository(datasource: datasource);
    _prescriptionsRepository = PrescriptionsRepository(datasource: datasource);
    _drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _familyGroupsRepository = FamilyGroupsRepository(datasource: datasource);
    _settingsRepository = SettingsRepository(datasource: datasource);
    _doctorPatientLinksRepository = DoctorPatientLinksRepository(datasource: datasource);
    _therapeuticAdviceRepository = TherapeuticAdviceRepository(datasource: datasource);
    _dashboardTotalsRepository = DashboardTotalsRepository(datasource: datasource);
    _patientDashboardIndexRepository = PatientDashboardIndexRepository(datasource: datasource);
    _identityResolutionRequestsRepository = IdentityResolutionRequestsRepository(datasource: datasource);
    _runtimeSignalRepository = RuntimeSignalRepository(datasource: datasource);
    _currentFiscalCode = PatientInputNormalizer.normalizeFiscalCode(widget.fiscalCode);
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PatientDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(widget.fiscalCode);
    final String previousFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(oldWidget.fiscalCode);
    if (nextFiscalCode != previousFiscalCode) {
      _currentFiscalCode = nextFiscalCode;
      _future = _load();
    }
  }


  PatientDetailDashboardArchiveDelta? _buildDashboardArchiveDeltaResult() {
    if (_archiveRecipeCountDeltaForDashboard == 0 &&
        _archiveDpcCountDeltaForDashboard == 0 &&
        _deletedArchiveImportIdsForDashboard.isEmpty) {
      return null;
    }
    return PatientDetailDashboardArchiveDelta(
      recipeCountDelta: _archiveRecipeCountDeltaForDashboard,
      dpcCountDelta: _archiveDpcCountDeltaForDashboard,
      patientFiscalCode: _currentFiscalCode,
      deletedImportIds: _deletedArchiveImportIdsForDashboard.toList()..sort(),
    );
  }

  void _popWithDashboardArchiveDelta() {
    Navigator.of(context).pop(_buildDashboardArchiveDeltaResult());
  }

  Future<void> _copyToClipboard(String value, {String message = 'CF copiato negli appunti.'}) async {
    final String normalized = value.trim();
    if (normalized.isEmpty || normalized == '-') {
      return;
    }
    await Clipboard.setData(ClipboardData(text: normalized));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.green,
        content: Text(message),
      ),
    );
  }

  Future<_PatientDetailData> _load() async {
    final patient = await _patientsRepository.getPatientByFiscalCode(_currentFiscalCode);
    final advances = await _advancesRepository.getPatientAdvances(_currentFiscalCode);
    final debts = await _debtsRepository.getPatientDebts(_currentFiscalCode);
    final bookings = await _bookingsRepository.getPatientBookings(_currentFiscalCode);
    final allImports = await _drivePdfImportsRepository.getImportsByPatient(
      _currentFiscalCode,
      includeHidden: true,
    );
    final Map<String, PendingPdfDeleteEntry> pendingByImportId = await loadPendingPdfDeletesByImportId();
    final imports = allImports.where((DrivePdfImport item) {
      if (item.isHiddenFromFrontend) return false;
      final PendingPdfDeleteEntry? pending = pendingByImportId[item.id];
      if (pending == null) return true;
      final String status = item.status.trim().toLowerCase();
      final bool removePending = item.pdfDeleted || status == 'deleted_pdf' || status == 'rejected' || status == 'cancelled' || status == 'delete_rejected' || status == 'delete_cancelled';
      if (removePending) {
        unawaited(removePendingPdfDeleteByImportId(item.id));
        return true;
      }
      return false;
    }).toList();
    final prescriptions = allImports.isNotEmpty
        ? imports.map(_prescriptionsRepository.importToPrescription).toList()
        : await _prescriptionsRepository.getLegacyPatientPrescriptions(_currentFiscalCode);
    final doctorLinks = await _doctorPatientLinksRepository.getLinksForPatient(_currentFiscalCode);
    final settings = await _settingsRepository.getSettings();
    final therapeuticAdvice = await _therapeuticAdviceRepository.getByFiscalCode(_currentFiscalCode);
    final familyContext = await _loadFamilyContext(patient);
    final identityContext = await _loadIdentityResolutionContext(patient);
    final doctorName = _resolveDoctor(
      patient: patient,
      doctorLinks: doctorLinks,
      prescriptions: prescriptions,
      imports: imports,
    );
    return _PatientDetailData(
      patient: patient,
      advances: advances,
      debts: debts,
      bookings: bookings,
      prescriptions: prescriptions,
      imports: imports,
      allImports: allImports,
      settings: settings,
      resolvedDoctorName: doctorName,
      therapeuticAdvice: therapeuticAdvice,
      familyContext: familyContext,
      identityContext: identityContext,
    );
  }


  Future<_PatientFamilyContext?> _loadFamilyContext(Patient? patient) async {
    if (patient == null) {
      return null;
    }
    final String normalizedCurrentCode =
        PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
    final FamilyGroup? currentFamily =
        await _familyGroupsRepository.findFamilyByMemberFiscalCode(normalizedCurrentCode);
    if (currentFamily == null) {
      return null;
    }

    return _buildFamilyContextFromFamily(
      family: currentFamily,
      currentPatient: patient,
    );
  }

  Future<_PatientFamilyContext> _buildFamilyContextFromFamily({
    required FamilyGroup family,
    required Patient currentPatient,
  }) async {
    final String normalizedCurrentCode =
        PatientInputNormalizer.normalizeFiscalCode(currentPatient.fiscalCode);
    final List<String> orderedCodes = <String>[];
    final Set<String> seenCodes = <String>{};
    for (final String rawCode in family.memberFiscalCodes) {
      final String normalized =
          PatientInputNormalizer.normalizeFiscalCode(rawCode);
      if (normalized.isEmpty || !seenCodes.add(normalized)) {
        continue;
      }
      orderedCodes.add(normalized);
    }

    final Map<String, Patient> patientsByCode = <String, Patient>{};
    for (final String code in orderedCodes) {
      if (code == normalizedCurrentCode) {
        continue;
      }
      final Patient? member = await _patientsRepository.getPatientByFiscalCode(code);
      if (member != null) {
        patientsByCode[PatientInputNormalizer.normalizeFiscalCode(member.fiscalCode)] = member;
      }
    }

    final List<_PatientFamilyMember> members = orderedCodes
        .map((String fiscalCode) {
          final bool isCurrentPatient = fiscalCode == normalizedCurrentCode;
          final Patient? resolvedPatient = isCurrentPatient
              ? currentPatient
              : patientsByCode[fiscalCode];
          return _PatientFamilyMember(
            fiscalCode: fiscalCode,
            patient: resolvedPatient,
            isCurrentPatient: isCurrentPatient,
          );
        })
        .toList();

    return _PatientFamilyContext(
      family: family,
      members: members,
    );
  }

  void _replaceData(_PatientDetailData data, String message) {
    setState(() {
      _message = message;
      _future = Future<_PatientDetailData>.value(data);
    });
  }

  Patient _copyPatientProfile(
    Patient patient, {
    required String fiscalCode,
    required String fullName,
    String? alias,
  }) {
    return Patient(
      fiscalCode: fiscalCode,
      fullName: fullName,
      alias: alias,
      city: patient.city,
      exemptionCode: patient.exemptionCode,
      exemptions: patient.exemptions,
      doctorName: patient.doctorName,
      therapiesSummary: patient.therapiesSummary,
      lastPrescriptionDate: patient.lastPrescriptionDate,
      hasDebt: patient.hasDebt,
      debtTotal: patient.debtTotal,
      hasBooking: patient.hasBooking,
      hasAdvance: patient.hasAdvance,
      hasDpc: patient.hasDpc,
      archivedRecipeCount: patient.archivedRecipeCount,
      archivedPdfCount: patient.archivedPdfCount,
      activeArchiveDocuments: patient.activeArchiveDocuments,
      createdAt: patient.createdAt,
      updatedAt: DateTime.now(),
      hasArchivedRecipeCountAggregate: patient.hasArchivedRecipeCountAggregate,
      hasHasDpcAggregate: patient.hasHasDpcAggregate,
      hasLastPrescriptionDateAggregate: patient.hasLastPrescriptionDateAggregate,
      hasTherapiesSummaryAggregate: patient.hasTherapiesSummaryAggregate,
    );
  }

  String? _nullableTrimmed(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int _recipeCountForImport(DrivePdfImport item) {
    return item.prescriptionCount > 0 ? item.prescriptionCount : 1;
  }

  int _recipeCountForVisibleArchive(
    List<DrivePdfImport> imports,
    List<Prescription> prescriptions,
  ) {
    if (imports.isNotEmpty) {
      return imports.fold<int>(0, (int sum, DrivePdfImport item) => sum + _recipeCountForImport(item));
    }
    return prescriptions.fold<int>(0, (int sum, Prescription item) {
      return sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1);
    });
  }

  int _dpcCountForVisibleArchive(
    List<DrivePdfImport> imports,
    List<Prescription> prescriptions,
  ) {
    if (imports.isNotEmpty) {
      return imports.where((DrivePdfImport item) => item.isDpc).length;
    }
    return prescriptions.where((Prescription item) => item.dpcFlag).length;
  }

  bool _hasExpiryAlertForVisibleArchive(
    List<DrivePdfImport> imports,
    List<Prescription> prescriptions,
  ) {
    final bool hasImportExpiry = imports.any((DrivePdfImport item) {
      final DateTime baseDate = item.prescriptionDate ?? item.createdAt;
      final PrescriptionExpiryInfo info = PrescriptionExpiryUtils.evaluate(
        baseDate.add(const Duration(days: 30)),
      );
      return info.status == PrescriptionValidityStatus.expiringSoon ||
          info.status == PrescriptionValidityStatus.expired;
    });
    final bool hasPrescriptionExpiry = prescriptions.any((Prescription item) {
      final PrescriptionExpiryInfo info = PrescriptionExpiryUtils.evaluate(
        item.expiryDate ?? item.prescriptionDate.add(const Duration(days: 30)),
      );
      return info.status == PrescriptionValidityStatus.expiringSoon ||
          info.status == PrescriptionValidityStatus.expired;
    });
    return hasImportExpiry || hasPrescriptionExpiry;
  }

  Future<void> _applyFrontendManagedTotalsDelta({
    double debtAmountDelta = 0,
    int advanceCountDelta = 0,
    int bookingCountDelta = 0,
  }) async {
    if (debtAmountDelta == 0 && advanceCountDelta == 0 && bookingCountDelta == 0) {
      return;
    }
    try {
      await _dashboardTotalsRepository.applyFrontendManagedDelta(
        debtAmountDelta: debtAmountDelta,
        advanceCountDelta: advanceCountDelta,
        bookingCountDelta: bookingCountDelta,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Dati salvati. Totali rapidi non riallineati: ' + e.toString();
      });
    }
  }

  Future<void> _syncPatientDashboardIndex(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    try {
      await _patientDashboardIndexRepository.patchFrontendManagedState(
        fiscalCode: patient.fiscalCode,
        fullName: patient.fullName,
        alias: patient.alias,
        doctorFullName: data.resolvedDoctorName == '-' ? patient.doctorName : data.resolvedDoctorName,
        city: patient.city,
        exemptionCode: patient.primaryExemption,
        recipeCount: _recipeCountForVisibleArchive(data.imports, data.prescriptions),
        dpcCount: _dpcCountForVisibleArchive(data.imports, data.prescriptions),
        hasExpiry: _hasExpiryAlertForVisibleArchive(data.imports, data.prescriptions),
        debtCount: data.debts.length,
        debtAmount: data.debts.fold<double>(0, (double sum, Debt item) => sum + item.residualAmount),
        advanceCount: data.advances.length,
        bookingCount: data.bookings.length,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Dati salvati. Indice dashboard non riallineato: ' + e.toString();
      });
    }
  }


  Future<_PatientIdentityResolutionContext?> _loadIdentityResolutionContext(Patient? patient) async {
    if (patient == null) {
      return null;
    }
    final String sourceId = PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
    final bool isTemporaryIdentity = isTemporaryPatientKey(sourceId) ||
        isTemporaryPatientKey(patient.fiscalCode);
    if (!isTemporaryIdentity) {
      return null;
    }
    final String nameKey = _identityNameKey(patient.fullName);
    if (nameKey.length < 3) {
      return _PatientIdentityResolutionContext(
        sourceId: sourceId,
        sourceFullName: patient.fullName,
        candidates: const <PatientDashboardIndex>[],
      );
    }
    final List<PatientDashboardIndex> rawCandidates =
        await _patientDashboardIndexRepository.searchByPrefix(patient.fullName, limit: 20);
    final List<PatientDashboardIndex> candidates = rawCandidates.where((PatientDashboardIndex item) {
      final String candidateId = PatientInputNormalizer.normalizeFiscalCode(item.fiscalCode);
      if (candidateId.isEmpty || candidateId == sourceId) {
        return false;
      }
      return _identityNameKey(item.fullName) == nameKey;
    }).toList()
      ..sort((PatientDashboardIndex a, PatientDashboardIndex b) {
        final bool aTmp = isTemporaryPatientKey(a.fiscalCode);
        final bool bTmp = isTemporaryPatientKey(b.fiscalCode);
        if (aTmp != bTmp) return aTmp ? 1 : -1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
    return _PatientIdentityResolutionContext(
      sourceId: sourceId,
      sourceFullName: patient.fullName,
      candidates: candidates.length > 8 ? candidates.sublist(0, 8) : candidates,
    );
  }

  String _identityNameKey(String value) {
    return PatientInputNormalizer.normalizeFullName(value).toUpperCase();
  }

  Map<String, String> _identitySourceFieldValues(Patient patient) {
    final Map<String, String> values = <String, String>{};
    final String fullName = patient.fullName.trim();
    if (fullName.isNotEmpty) values['fullName'] = fullName;
    return values;
  }

  Map<String, String> _identityTargetFieldValues(PatientDashboardIndex candidate) {
    final Map<String, String> values = <String, String>{};
    final String fullName = candidate.fullName.trim();
    if (fullName.isNotEmpty) values['fullName'] = fullName;
    return values;
  }

  List<String> _identityConflictFields({
    required Map<String, String> sourceValues,
    required Map<String, String> targetValues,
  }) {
    final List<String> fields = <String>[];
    for (final String field in <String>['fullName']) {
      final String source = (sourceValues[field] ?? '').trim().toUpperCase();
      final String target = (targetValues[field] ?? '').trim().toUpperCase();
      if (source.isNotEmpty && target.isNotEmpty && source != target) {
        fields.add(field);
      }
    }
    return fields;
  }

  Future<void> _openIdentityResolutionDialog(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    final _PatientIdentityResolutionContext? identityContext = data.identityContext;
    if (patient == null || identityContext == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        String localError = '';

        Future<void> submitMergeRequest(
          StateSetter setLocalState,
          PatientDashboardIndex candidate,
        ) async {
          setLocalState(() {
            busy = true;
            localError = '';
          });
          try {
            final String sourceId = identityContext.sourceId;
            final String targetId = PatientInputNormalizer.normalizeFiscalCode(candidate.fiscalCode);
            final bool targetIsTemporary = isTemporaryPatientKey(targetId);
            final Map<String, String> sourceValues = _identitySourceFieldValues(patient);
            final Map<String, String> targetValues = _identityTargetFieldValues(candidate);
            final List<String> conflictFields = _identityConflictFields(
              sourceValues: sourceValues,
              targetValues: targetValues,
            );
            final Map<String, String> selectedValues = <String, String>{
              for (final String field in conflictFields)
                if ((sourceValues[field] ?? '').trim().isNotEmpty)
                  field: sourceValues[field]!.trim(),
            };
            await _identityResolutionRequestsRepository.createUserConfirmedRequest(
              action: targetIsTemporary
                  ? IdentityResolutionRequestAction.mergeSameNamePatient
                  : IdentityResolutionRequestAction.chooseCorrectFiscalCode,
              sourceFiscalCode: sourceId,
              targetFiscalCode: targetId,
              sourcePatientId: sourceId,
              targetPatientId: targetId,
              selectedFiscalCode: targetIsTemporary ? null : targetId,
              normalizedName: patient.fullName,
              candidateFiscalCodes: targetIsTemporary ? const <String>[] : <String>[targetId],
              conflictFields: conflictFields,
              sourceFieldValues: sourceValues,
              targetFieldValues: targetValues,
              selectedFieldValues: selectedValues,
              reason: targetIsTemporary
                  ? 'frontend_contextual_same_name_user_confirmed'
                  : 'frontend_contextual_tmp_cf_user_confirmed',
            );
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (!mounted) return;
            setState(() {
              _message = 'Richiesta risoluzione identità creata. Il backend completerà la correzione.';
            });
          } catch (e) {
            if (dialogContext.mounted) {
              setLocalState(() {
                busy = false;
                localError = 'Errore creazione richiesta identità: $e';
              });
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.panel,
            title: const Text('Risolvi identità assistito', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistito temporaneo: ${visiblePatientTitle(fullName: patient.fullName, patientKey: patient.fiscalCode)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scegli un candidato solo se sei certo che rappresenti lo stesso assistito. Il frontend creerà una richiesta: il merge resta backend-owned.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  if (identityContext.candidates.isEmpty)
                    const Text(
                      'Nessun candidato trovato dalla segnaletica dashboard.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          children: identityContext.candidates.map((PatientDashboardIndex candidate) {
                            final String candidateId = PatientInputNormalizer.normalizeFiscalCode(candidate.fiscalCode);
                            final bool targetIsTemporary = isTemporaryPatientKey(candidateId);
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.panelSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: targetIsTemporary ? AppColors.amber : AppColors.green),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    visiblePatientTitle(
                                      fullName: candidate.fullName,
                                      patientKey: candidateId,
                                    ),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _pill(targetIsTemporary ? 'TMP/no CF' : 'CF reale', targetIsTemporary ? AppColors.amber : AppColors.green),
                                      _pill(visiblePatientFiscalCode(candidateId), AppColors.yellow),
                                      if (candidate.hasRecipes) _pill('Ricette ${candidate.recipeCount}', AppColors.green),
                                      if (candidate.hasDebt) _pill('Debiti', AppColors.wine),
                                      if (candidate.hasAdvance) _pill('Anticipi', AppColors.amber),
                                      if (candidate.hasBooking) _pill('Prenotazioni', AppColors.yellow),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      onPressed: busy ? null : () => submitMergeRequest(setLocalState, candidate),
                                      icon: const Icon(Icons.merge_type_rounded),
                                      label: const Text('Sono lo stesso assistito'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (localError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(localError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Lascia separato / annulla', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdentityResolutionBanner(_PatientDetailData data) {
    final _PatientIdentityResolutionContext? identityContext = data.identityContext;
    if (identityContext == null) {
      return const SizedBox.shrink();
    }
    final bool hasCandidates = identityContext.candidates.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasCandidates ? AppColors.amber : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: hasCandidates ? AppColors.amber : Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identità assistito da verificare',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCandidates
                          ? 'Questo assistito è temporaneo e ci sono possibili candidati con stesso nome. Conferma solo se rappresentano lo stesso assistito.'
                          : 'Questo assistito è temporaneo. Nessun candidato automatico trovato: puoi completare il CF dalla modifica assistito.',
                      style: const TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasCandidates) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openIdentityResolutionDialog(data),
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Risolvi identità assistito'),
            ),
          ],
        ],
      ),
    );
  }

  String _resolveDoctor({
    required Patient? patient,
    required List<DoctorPatientLink> doctorLinks,
    required List<Prescription> prescriptions,
    required List<DrivePdfImport> imports,
  }) {
    return PhboxContractUtils.resolveDoctor(
      fiscalCode: _currentFiscalCode,
      doctorLinks: doctorLinks,
      patientDoctorFullName: patient?.doctorFullName,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  Future<void> _openPdf(DrivePdfImport item) async {
    final String directLink = item.effectiveViewLink.trim();
    final String fallbackLink = item.driveFileId.trim().isNotEmpty
        ? 'https://drive.google.com/file/d/${item.driveFileId.trim()}/view'
        : '';
    final String url = directLink.isNotEmpty ? directLink : fallbackLink;
    if (url.isEmpty) return;
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _editTherapeuticAdvice(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final controller = TextEditingController(text: data.therapeuticAdvice?.text ?? '');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Consigli terapeutici', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: _dialogField(
            controller,
            'Note libere di presa in carico',
            maxLines: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    try {
      final String textValue = controller.text.trim();
      final DateTime now = DateTime.now();
      if (textValue.isEmpty) {
        await _therapeuticAdviceRepository.clear(patient.fiscalCode);
        _replaceData(
          data.copyWith(therapeuticAdvice: null),
          'Consigli terapeutici rimossi.',
        );
      } else {
        await _therapeuticAdviceRepository.save(
          fiscalCode: patient.fiscalCode,
          text: textValue,
        );
        final TherapeuticAdviceNote nextNote = TherapeuticAdviceNote(
          patientFiscalCode: patient.fiscalCode,
          text: textValue,
          createdAt: data.therapeuticAdvice?.createdAt ?? now,
          updatedAt: now,
        );
        _replaceData(
          data.copyWith(therapeuticAdvice: nextNote),
          'Consigli terapeutici salvati.',
        );
      }
    } catch (e) {
      setState(() => _message = 'Errore salvataggio consigli terapeutici: $e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _clearTherapeuticAdvice(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null || data.therapeuticAdvice == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Rimuovi consigli terapeutici', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Il testo libero associato a questo assistito verrà eliminato. Continuare?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _therapeuticAdviceRepository.clear(patient.fiscalCode);
      _replaceData(
        data.copyWith(therapeuticAdvice: null),
        'Consigli terapeutici rimossi.',
      );
    } catch (e) {
      setState(() => _message = 'Errore eliminazione consigli terapeutici: $e');
    }
  }

  Future<void> _openManageDialog({
    required String title,
    required List<Widget> children,
    Widget? action,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.panel,
        child: SizedBox(
          width: 820,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    if (action != null) action,
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: children.isEmpty
                      ? const Text('Nessuna voce.', style: TextStyle(color: Colors.white70))
                      : SingleChildScrollView(child: Column(children: children)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _managePrescriptions(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Ricette',
      children: data.prescriptions.map((prescription) {
        final matchingImport = _findImportForPrescription(data.imports, prescription.id);
        final expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
        return _managerCard(
          title: _prescriptionLabel(prescription),
          subtitle: '${_formatDate(prescription.prescriptionDate)} · ${prescription.doctorName ?? '-'} · ${expiryInfo.label}',
          actions: [
            if (matchingImport != null)
              TextButton.icon(
                onPressed: () => _openPdf(matchingImport),
                icon: const Icon(Icons.open_in_new),
                label: const Text('PDF'),
              ),
            if (matchingImport != null)
              IconButton(
                onPressed: () => _requestPrescriptionDelete(data, matchingImport),
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
              ),
          ],
          extra: [
            _detailLine('Esenzione', (prescription.exemptionCode ?? '-').trim().isEmpty ? '-' : prescription.exemptionCode!.trim()),
            _detailLine('DPC', prescription.dpcFlag ? 'SI' : 'NO'),
            _detailLine('Terapie', _prescriptionLabel(prescription)),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _manageDebts(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Debiti',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addDebt(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.debts.map((debt) {
        return _managerCard(
          title: '${debt.description} · € ${debt.residualAmount.toStringAsFixed(2)}',
          subtitle: 'Creazione ${_formatDate(debt.createdAt)} · Scadenza ${_formatDate(debt.dueDate)}',
          actions: [
            IconButton(
              onPressed: () => _deleteDebt(data, debt),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((debt.note ?? '').trim().isNotEmpty) _detailLine('Nota', debt.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _manageAdvances(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Anticipi',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addAdvance(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.advances.map((advance) {
        return _managerCard(
          title: advance.drugName,
          subtitle: '${advance.doctorName.isEmpty ? '-' : advance.doctorName} · ${_formatDate(advance.createdAt)}',
          actions: [
            IconButton(
              onPressed: () => _deleteAdvance(data, advance),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((advance.note ?? '').trim().isNotEmpty) _detailLine('Nota', advance.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _manageBookings(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Prenotazioni',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addBooking(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.bookings.map((booking) {
        return _managerCard(
          title: '${booking.drugName} x${booking.quantity}',
          subtitle: 'Registrata ${_formatDate(booking.createdAt)} · Prevista ${_formatDate(booking.expectedDate)}',
          actions: [
            IconButton(
              onPressed: () => _deleteBooking(data, booking),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((booking.note ?? '').trim().isNotEmpty) _detailLine('Nota', booking.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _addDebt(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            final String description = descriptionController.text.trim();
            final double amount = _parseEuro(amountController.text);
            if (description.isEmpty || amount == 0) {
              setLocalState(() => localError = 'Causale e importo sono obbligatori.');
              return;
            }
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final DateTime now = DateTime.now();
              final Debt debt = Debt.createNew(
                id: _localId('debt'),
                patientFiscalCode: patient.fiscalCode,
                patientName: patient.fullName,
                description: description,
                amount: amount,
                initialPaidAmountRaw: 0,
                createdAt: now,
                dueDate: now,
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );
              await _debtsRepository.saveDebt(debt);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                await _applyFrontendManagedTotalsDelta(debtAmountDelta: debt.residualAmount);
                final _PatientDetailData nextData = data.copyWith(debts: <Debt>[debt, ...data.debts]);
                await _syncPatientDashboardIndex(nextData);
                _replaceData(
                  nextData,
                  'Debito aggiunto.',
                );
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore salvataggio debito: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setLocalState) => AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Nuovo debito', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(descriptionController, 'Causale'),
                    const SizedBox(height: 12),
                    _dialogField(
                      amountController,
                      'Importo debito (€)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,\.]'))],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Data inserimento: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 12),
                    _dialogField(noteController, 'Nota', maxLines: 3),
                    if (localError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(localError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                ),
                FilledButton(
                  onPressed: busy ? null : () => submit(setLocalState),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _addAdvance(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final drugController = TextEditingController();
    final noteController = TextEditingController();
    String selectedDoctor = data.resolvedDoctorName != '-' ? data.resolvedDoctorName : _fallbackDoctorFromHistory(data);
    final doctorCandidates = <String>{
      ...data.settings.doctorsCatalog.map((item) => item.trim()).where((item) => item.isNotEmpty),
      if (selectedDoctor.trim().isNotEmpty && selectedDoctor.trim() != '-') selectedDoctor.trim(),
    }.toList()
      ..sort();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            final String doctor = selectedDoctor.trim();
            final List<String> drugNames = _splitMultiEntryInput(drugController.text);
            if (drugNames.isEmpty || doctor.isEmpty || doctor == '-') {
              setLocalState(() => localError = 'Farmaco e medico sono obbligatori.');
              return;
            }
            setLocalState(() {
              busy = true;
              localError = '';
            });
            final DateTime now = DateTime.now();
            final String? note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
            final List<Advance> advances = <Advance>[
              for (int i = 0; i < drugNames.length; i++)
                Advance(
                  id: _localId('advance_${i + 1}'),
                  patientFiscalCode: patient.fiscalCode,
                  patientName: patient.fullName,
                  drugName: drugNames[i],
                  doctorName: doctor,
                  note: note,
                  createdAt: now,
                  updatedAt: now,
                ),
            ];
            final List<Advance> savedAdvances = <Advance>[];
            Object? saveLoopError;
            for (final Advance advance in advances) {
              try {
                await _advancesRepository.saveAdvance(advance);
                savedAdvances.add(advance);
              } catch (e) {
                saveLoopError = e;
                break;
              }
            }
            if (saveLoopError != null) {
              if (savedAdvances.isNotEmpty && mounted) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _applyFrontendManagedTotalsDelta(advanceCountDelta: savedAdvances.length);
                final _PatientDetailData nextData = data.copyWith(
                  advances: <Advance>[...savedAdvances, ...data.advances],
                  resolvedDoctorName: doctor,
                );
                await _syncPatientDashboardIndex(nextData);
                _replaceData(
                  nextData,
                  'Anticipi parzialmente aggiunti: ${savedAdvances.length}/${advances.length}. Verifica prima di reinserire. Errore: $saveLoopError',
                );
                return;
              }
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore salvataggio anticipo: $saveLoopError';
                });
              }
              return;
            }

            String postSaveWarning = '';
            try {
              await _doctorPatientLinksRepository.saveManualOverride(
                patientFiscalCode: patient.fiscalCode,
                patientFullName: patient.fullName,
                doctorFullName: doctor,
                city: patient.city,
              );
            } catch (e) {
              postSaveWarning = ' Override medico non riallineato: $e';
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (mounted) {
              await _applyFrontendManagedTotalsDelta(advanceCountDelta: savedAdvances.length);
              final _PatientDetailData nextData = data.copyWith(
                advances: <Advance>[...savedAdvances, ...data.advances],
                resolvedDoctorName: doctor,
              );
              await _syncPatientDashboardIndex(nextData);
              _replaceData(
                nextData,
                (savedAdvances.length == 1 ? 'Anticipo aggiunto.' : 'Anticipi aggiunti: ${savedAdvances.length}.') + postSaveWarning,
              );
            }
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                backgroundColor: AppColors.panel,
                title: const Text('Nuovo anticipo', style: TextStyle(color: Colors.white)),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                        drugController,
                        'Farmaco / articolo',
                        maxLines: 4,
                        helperText: 'Per più voci usa virgola o vai a capo.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedDoctor == '-' || selectedDoctor.isEmpty ? null : selectedDoctor,
                        dropdownColor: AppColors.panelSoft,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Medico',
                          hintText: 'Seleziona medico',
                          hintStyle: const TextStyle(color: Colors.white54),
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white70),
                          ),
                        ),
                        items: doctorCandidates
                            .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) {
                          setLocalState(() {
                            selectedDoctor = value ?? '';
                            localError = '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Data registrazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 12),
                      _dialogField(noteController, 'Nota', maxLines: 3),
                      if (localError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(localError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => submit(setLocalState),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salva'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      drugController.dispose();
      noteController.dispose();
    }
  }

  List<String> _splitMultiEntryInput(String value) {
    return value
        .split(RegExp(r'[,\n\r]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _fallbackDoctorFromHistory(_PatientDetailData data) {
    if (data.resolvedDoctorName != '-' && data.resolvedDoctorName.trim().isNotEmpty) {
      return data.resolvedDoctorName.trim();
    }
    for (final advance in data.advances) {
      if (advance.doctorName.trim().isNotEmpty) return advance.doctorName.trim();
    }
    for (final prescription in data.prescriptions) {
      if ((prescription.doctorName ?? '').trim().isNotEmpty) return prescription.doctorName!.trim();
    }
    return '-';
  }

  Future<void> _addBooking(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final drugController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Nuova prenotazione', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                drugController,
                'Farmaco / articolo',
                maxLines: 4,
                helperText: 'Per più voci usa virgola o vai a capo.',
              ),
              const SizedBox(height: 12),
              _dialogField(
                quantityController,
                'Quantità',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Data prevista: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              _dialogField(noteController, 'Nota', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
        ],
      ),
    );
    if (confirmed != true) return;
    final List<Booking> savedBookings = <Booking>[];
    List<Booking> bookings = const <Booking>[];
    try {
      final List<String> drugNames = _splitMultiEntryInput(drugController.text);
      if (drugNames.isEmpty) {
        setState(() => _message = 'Farmaco / articolo obbligatorio.');
        return;
      }
      final DateTime now = DateTime.now();
      final int quantity = int.tryParse(quantityController.text.trim()) ?? 1;
      final String? note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
      bookings = <Booking>[
        for (int i = 0; i < drugNames.length; i++)
          Booking(
            id: _localId('booking_${i + 1}'),
            patientFiscalCode: patient.fiscalCode,
            patientName: patient.fullName,
            drugName: drugNames[i],
            quantity: quantity,
            createdAt: now,
            expectedDate: now,
            note: note,
          ),
      ];
      Object? saveLoopError;
      for (final Booking booking in bookings) {
        try {
          await _bookingsRepository.saveBooking(booking);
          savedBookings.add(booking);
        } catch (e) {
          saveLoopError = e;
          break;
        }
      }
      if (saveLoopError != null) {
        if (savedBookings.isNotEmpty) {
          await _applyFrontendManagedTotalsDelta(bookingCountDelta: savedBookings.length);
          final _PatientDetailData nextData = data.copyWith(bookings: <Booking>[...savedBookings, ...data.bookings]);
          await _syncPatientDashboardIndex(nextData);
          _replaceData(
            nextData,
            'Prenotazioni parzialmente aggiunte: ${savedBookings.length}/${bookings.length}. Verifica prima di reinserire. Errore: $saveLoopError',
          );
          return;
        }
        setState(() => _message = 'Errore salvataggio prenotazione: $saveLoopError');
        return;
      }
      await _applyFrontendManagedTotalsDelta(bookingCountDelta: savedBookings.length);
      final _PatientDetailData nextData = data.copyWith(bookings: <Booking>[...savedBookings, ...data.bookings]);
      await _syncPatientDashboardIndex(nextData);
      _replaceData(
        nextData,
        savedBookings.length == 1 ? 'Prenotazione aggiunta.' : 'Prenotazioni aggiunte: ${savedBookings.length}.',
      );
    } catch (e) {
      setState(() => _message = 'Errore salvataggio prenotazione: $e');
    } finally {
      drugController.dispose();
      quantityController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _requestPatientDelete(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    final String fiscalCode = PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
    if (fiscalCode.isEmpty) {
      _showTransientError('Codice fiscale assistito non valido.');
      return;
    }

    final int debtCount = data.debts.length;
    final int advanceCount = data.advances.length;
    final int bookingCount = data.bookings.length;
    final bool hasArchiveData = data.allImports.isNotEmpty || data.prescriptions.isNotEmpty;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          'Elimina assistito definitivamente',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visiblePatientTitle(
                  fullName: patient.fullName,
                  patientKey: patient.fiscalCode,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Il frontend eliminerà subito profilo assistito, indice Home e dati gestionali frontend-owned: debiti, anticipi, prenotazioni e consigli terapeutici.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 10),
              Text(
                hasArchiveData
                    ? 'Le ricette/PDF collegati resteranno backend-owned: verrà creato un segnale e il backend eliminerà/cestinerà Drive PDF, import archivio e totali Ricette/DPC/In scadenza.'
                    : 'Non risultano ricette/PDF collegati dalla scheda: verrà comunque creato un segnale backend di verifica archivio per evitare dati orfani.',
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(
                'Dati gestionali rilevati: $debtCount debiti, $advanceCount anticipi, $bookingCount prenotazioni.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              const Text(
                'Operazione irreversibile. Non eliminare manualmente file da Drive.',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Elimina definitivamente'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _runtimeSignalRepository.emit(
        domain: 'patientDelete',
        operation: 'deleteArchive',
        targetPath: 'patients/$fiscalCode',
        targetFiscalCode: fiscalCode,
        targetDocumentId: fiscalCode,
        requiresTotalsUpdate: true,
        requiresIndexUpdate: true,
      );
      await _deleteFrontendOwnedPatientData(
        data: data,
        fiscalCode: fiscalCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        PatientDetailDashboardArchiveDelta(
          patientFiscalCode: fiscalCode,
          patientDeleted: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Errore eliminazione assistito: $e';
      });
    }
  }

  Future<void> _deleteFrontendOwnedPatientData({
    required _PatientDetailData data,
    required String fiscalCode,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<DocumentReference<Map<String, dynamic>>> deletes = <DocumentReference<Map<String, dynamic>>>[];
    final List<_PendingFamilyMembershipUpdate> familyUpdates = <_PendingFamilyMembershipUpdate>[];
    final DocumentReference<Map<String, dynamic>> patientRef =
        firestore.collection(AppCollections.patients).doc(fiscalCode);

    for (final Debt item in data.debts) {
      final String id = item.id.trim();
      if (id.isEmpty) continue;
      deletes.add(patientRef.collection(AppCollections.debts).doc(id));
    }
    for (final Advance item in data.advances) {
      final String id = item.id.trim();
      if (id.isEmpty) continue;
      deletes.add(patientRef.collection(AppCollections.advances).doc(id));
    }
    for (final Booking item in data.bookings) {
      final String id = item.id.trim();
      if (id.isEmpty) continue;
      deletes.add(patientRef.collection(AppCollections.bookings).doc(id));
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootDebtDocs =
        await _getBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.debts, fiscalCode);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootAdvanceDocs =
        await _getBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.advances, fiscalCode);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootBookingDocs =
        await _getBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.bookings, fiscalCode);

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in rootDebtDocs) {
      deletes.add(doc.reference);
    }
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in rootAdvanceDocs) {
      deletes.add(doc.reference);
    }
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in rootBookingDocs) {
      deletes.add(doc.reference);
    }

    deletes.add(firestore.collection(AppCollections.patientTherapeuticAdvice).doc(fiscalCode));
    deletes.add(firestore.collection(AppCollections.patientDashboardIndex).doc(fiscalCode));
    deletes.add(firestore.collection(AppCollections.doctorPatientLinks).doc('${fiscalCode}__manual'));
    deletes.add(patientRef);

    final _PatientFamilyContext? familyContext = data.familyContext;
    if (familyContext != null) {
      final FamilyGroup family = familyContext.family;
      final String familyId = family.id.trim();
      if (familyId.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> familyRef =
            firestore.collection(AppCollections.families).doc(familyId);
        final List<String> nextMembers = family.memberFiscalCodes
            .map(PatientInputNormalizer.normalizeFiscalCode)
            .where((String value) => value.isNotEmpty && value != fiscalCode)
            .toSet()
            .toList()
          ..sort();
        if (nextMembers.isEmpty) {
          deletes.add(familyRef);
        } else {
          familyUpdates.add(_PendingFamilyMembershipUpdate(
            reference: familyRef,
            memberFiscalCodes: nextMembers,
          ));
        }
      }
    }

    await _commitDeleteRefsInChunks(firestore, deletes);
    await _commitFamilyMembershipUpdates(familyUpdates);

    final double subcollectionDebtAmount = data.debts.fold<double>(
      0,
      (double sum, Debt item) => sum + item.residualAmount,
    );
    final double rootDebtAmount = rootDebtDocs.fold<double>(
      0,
      (double sum, QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
          sum + _readFrontendManagedDebtAmount(doc.data()),
    );
    await _applyFrontendManagedTotalsDelta(
      debtAmountDelta: -(subcollectionDebtAmount + rootDebtAmount),
      advanceCountDelta: -(data.advances.length + rootAdvanceDocs.length),
      bookingCountDelta: -(data.bookings.length + rootBookingDocs.length),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getBoundedRootDocsByPatientFiscalCode(
    FirebaseFirestore firestore,
    String collectionPath,
    String fiscalCode,
  ) async {
    const int maxDocs = 300;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .where('patientFiscalCode', isEqualTo: fiscalCode)
        .limit(maxDocs + 1)
        .get();
    if (snapshot.docs.length > maxDocs) {
      throw Exception('Troppi documenti gestionali collegati a $fiscalCode in $collectionPath. Eliminazione bloccata.');
    }
    return snapshot.docs;
  }

  double _readFrontendManagedDebtAmount(Map<String, dynamic> data) {
    for (final String key in <String>['residualAmount', 'amount', 'debtAmount']) {
      final Object? value = data[key];
      if (value is num) return value.toDouble();
      final double? parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  Future<void> _commitFamilyMembershipUpdates(
    List<_PendingFamilyMembershipUpdate> updates,
  ) async {
    if (updates.isEmpty) return;
    const int chunkSize = 450;
    for (int offset = 0; offset < updates.length; offset += chunkSize) {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final Iterable<_PendingFamilyMembershipUpdate> chunk =
          updates.skip(offset).take(chunkSize);
      for (final _PendingFamilyMembershipUpdate update in chunk) {
        batch.set(
          update.reference,
          <String, dynamic>{
            'memberFiscalCodes': update.memberFiscalCodes,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _commitDeleteRefsInChunks(
    FirebaseFirestore firestore,
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    final Set<String> seen = <String>{};
    final List<DocumentReference<Map<String, dynamic>>> uniqueRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (final DocumentReference<Map<String, dynamic>> ref in refs) {
      if (seen.add(ref.path)) {
        uniqueRefs.add(ref);
      }
    }
    const int chunkSize = 450;
    for (int offset = 0; offset < uniqueRefs.length; offset += chunkSize) {
      final WriteBatch batch = firestore.batch();
      final Iterable<DocumentReference<Map<String, dynamic>>> chunk = uniqueRefs.skip(offset).take(chunkSize);
      for (final DocumentReference<Map<String, dynamic>> ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDebt(_PatientDetailData data, Debt debt) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    if (!await _confirmDelete(message: 'Eliminare questo debito?')) return;
    await _debtsRepository.deleteDebt(patient.fiscalCode, debt.id);
    await _applyFrontendManagedTotalsDelta(debtAmountDelta: -debt.residualAmount);
    final _PatientDetailData nextData = data.copyWith(debts: data.debts.where((Debt item) => item.id != debt.id).toList());
    await _syncPatientDashboardIndex(nextData);
    _replaceData(
      nextData,
      'Debito eliminato.',
    );
  }

  Future<void> _deleteAdvance(_PatientDetailData data, Advance advance) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    if (!await _confirmDelete(message: 'Eliminare questo anticipo?')) return;
    await _advancesRepository.deleteAdvance(patient.fiscalCode, advance.id);
    await _applyFrontendManagedTotalsDelta(advanceCountDelta: -1);
    final _PatientDetailData nextData = data.copyWith(advances: data.advances.where((Advance item) => item.id != advance.id).toList());
    await _syncPatientDashboardIndex(nextData);
    _replaceData(
      nextData,
      'Anticipo eliminato.',
    );
  }

  Future<void> _deleteBooking(_PatientDetailData data, Booking booking) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    if (!await _confirmDelete(message: 'Eliminare questa prenotazione?')) return;
    await _bookingsRepository.deleteBooking(patient.fiscalCode, booking.id);
    await _applyFrontendManagedTotalsDelta(bookingCountDelta: -1);
    final _PatientDetailData nextData = data.copyWith(bookings: data.bookings.where((Booking item) => item.id != booking.id).toList());
    await _syncPatientDashboardIndex(nextData);
    _replaceData(
      nextData,
      'Prenotazione eliminata.',
    );
  }

  Future<void> _requestPrescriptionDelete(_PatientDetailData data, DrivePdfImport item) async {
    if (!await _confirmDelete(message: 'Eliminare questa ricetta?')) return;
    await _drivePdfImportsRepository.requestPdfDelete(item.id, fiscalCode: item.patientFiscalCode);
    await savePendingPdfDelete(importId: item.id, fiscalCode: item.patientFiscalCode);
    if (item.id.trim().isNotEmpty) {
      _deletedArchiveImportIdsForDashboard.add(item.id.trim());
    }
    // Archive totals are backend-owned and will be converged by the deletePdf signal.
    _archiveRecipeCountDeltaForDashboard -= _recipeCountForImport(item);
    if (item.isDpc) {
      _archiveDpcCountDeltaForDashboard -= 1;
    }
    final DrivePdfImport hiddenItem = item.copyWith(
      deletePdfRequested: true,
      deleteRequestedAt: DateTime.now(),
    );
    final List<DrivePdfImport> nextAllImports = data.allImports
        .map((DrivePdfImport current) => current.id == item.id ? hiddenItem : current)
        .toList();
    final List<DrivePdfImport> nextVisibleImports = data.imports
        .where((DrivePdfImport current) => current.id != item.id)
        .toList();
    final List<Prescription> nextPrescriptions = data.prescriptions
        .where((Prescription current) => current.id != item.id)
        .toList();
    final _PatientDetailData nextData = data.copyWith(
      imports: nextVisibleImports,
      allImports: nextAllImports,
      prescriptions: nextPrescriptions,
    );
    await _syncPatientDashboardIndex(nextData);
    _replaceData(
      nextData,
      'Richiesta delete PDF registrata.',
    );
  }

  Future<bool> _confirmDelete({
    String title = 'Conferma',
    required String message,
  }) async {
    final String effectiveMessage = message.trim().isEmpty
        ? 'Confermare eliminazione?'
        : message.trim();
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          effectiveMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return value == true;
  }


  Future<void> _editPatient(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) {
      return;
    }
    final List<String> nameParts = PatientInputNormalizer.splitFullName(patient.fullName);
    final bool temporaryKey = isTemporaryPatientKey(patient.fiscalCode);
    final nameController = TextEditingController(text: nameParts.first);
    final surnameController = TextEditingController(text: nameParts.last);
    final aliasController = TextEditingController(text: patient.alias?.trim() ?? '');
    final fiscalCodeController = TextEditingController(
      text: temporaryKey ? '' : PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final PatientProfileUpdateResult result =
                  await _patientsRepository.updatePatientProfile(
                currentDocumentId: patient.fiscalCode,
                name: nameController.text,
                surname: surnameController.text,
                fiscalCodeInput: fiscalCodeController.text,
                alias: aliasController.text,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (!mounted) {
                return;
              }
              _currentFiscalCode = result.effectiveDocumentId;
              if (result.migratedFromTemporaryKey) {
                setState(() {
                  _message = 'Assistito completato e migrato su codice fiscale reale.';
                  _future = _load();
                });
              } else {
                final Patient updatedPatient = _copyPatientProfile(
                  patient,
                  fiscalCode: result.fiscalCode,
                  fullName: result.fullName,
                  alias: _nullableTrimmed(aliasController.text),
                );
                final _PatientDetailData nextData = data.copyWith(patient: updatedPatient);
                await _syncPatientDashboardIndex(nextData);
                _replaceData(
                  nextData,
                  'Assistito aggiornato.',
                );
              }
            } on PatientProfileUpdateException catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = e.message;
                });
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore aggiornamento assistito: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setLocalState) => AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Modifica assistito', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(nameController, 'Nome'),
                    const SizedBox(height: 12),
                    _dialogField(surnameController, 'Cognome'),
                    const SizedBox(height: 12),
                    _dialogField(aliasController, 'Alias / nomignolo'),
                    const SizedBox(height: 12),
                    _dialogField(
                      fiscalCodeController,
                      'Codice fiscale',
                      helperText: temporaryKey
                          ? 'Se inserisci un CF reale, verrà creata una richiesta backend-owned: nessun merge diretto dal frontend.'
                          : 'Il codice fiscale resta visibile ma non può essere rinominato da questa schermata.',
                      readOnly: !temporaryKey,
                    ),
                    if (localError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(localError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                ),
                FilledButton(
                  onPressed: busy ? null : () => submit(setLocalState),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      nameController.dispose();
      surnameController.dispose();
      aliasController.dispose();
      fiscalCodeController.dispose();
    }
  }


  Future<void> _editCurrentPatientFromMenu() async {
    try {
      final Future<_PatientDetailData>? currentFuture = _future;
      if (currentFuture == null) {
        return;
      }
      final _PatientDetailData data = await currentFuture;
      if (!mounted || data.patient == null) {
        return;
      }
      await _editPatient(data);
    } catch (e) {
      _showTransientError('Errore apertura modifica assistito: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _popWithDashboardArchiveDelta();
        return false;
      },
      child: Stack(
        children: [
        FutureBuilder<_PatientDetailData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                foregroundColor: Colors.white,
                title: const Text('Scheda assistito'),
              ),
              body: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? Center(child: Text('Errore caricamento: ${snapshot.error}', style: const TextStyle(color: Colors.white)))
                      : data == null || data.patient == null
                          ? const Center(child: Text('Assistito non trovato.', style: TextStyle(color: Colors.white)))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(data),
                                  if (data.identityContext != null) ...[
                                    const SizedBox(height: 12),
                                    _buildIdentityResolutionBanner(data),
                                  ],
                                  if (_message.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                                  ],
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      _summaryCard(
                                        label: 'Ricette',
                                        value: '${data.totalRecipeCount}',
                                        subtitle: '${data.prescriptions.length} documenti',
                                        color: AppColors.green,
                                        onTap: () => _managePrescriptions(data),
                                      ),
                                      _summaryCard(
                                        label: 'DPC',
                                        value: data.hasDpc ? 'SI' : 'NO',
                                        subtitle: 'flag ricette',
                                        color: AppColors.coral,
                                        onTap: () => _managePrescriptions(data),
                                      ),
                                      _summaryCard(
                                        label: 'Debiti',
                                        value: '€ ${data.totalDebt.toStringAsFixed(2)}',
                                        subtitle: '${data.debts.length} voci',
                                        color: AppColors.wine,
                                        onTap: () => _manageDebts(data),
                                      ),
                                      _summaryCard(
                                        label: 'Anticipi',
                                        value: '${data.advances.length}',
                                        subtitle: 'gestione rapida',
                                        color: AppColors.amber,
                                        onTap: () => _manageAdvances(data),
                                      ),
                                      _summaryCard(
                                        label: 'Prenotazioni',
                                        value: '${data.bookings.length}',
                                        subtitle: 'gestione rapida',
                                        color: AppColors.yellow,
                                        onTap: () => _manageBookings(data),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _section(
                                    title: 'Consigli terapeutici',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((data.therapeuticAdvice?.text.trim() ?? '').isEmpty)
                                          const Text(
                                            'Nessun consiglio terapeutico registrato.',
                                            style: TextStyle(color: Colors.white70),
                                          )
                                        else
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: AppColors.panelSoft,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white10),
                                            ),
                                            child: Text(
                                              data.therapeuticAdvice!.text,
                                              style: const TextStyle(color: Colors.white, height: 1.45),
                                            ),
                                          ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            FilledButton.icon(
                                              onPressed: () => _editTherapeuticAdvice(data),
                                              icon: Icon(data.therapeuticAdvice == null ? Icons.add_comment_outlined : Icons.edit_outlined),
                                              label: Text(data.therapeuticAdvice == null ? 'Aggiungi' : 'Modifica'),
                                            ),
                                            if (data.therapeuticAdvice != null)
                                              TextButton.icon(
                                                onPressed: () => _clearTherapeuticAdvice(data),
                                                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                                label: const Text('Svuota', style: TextStyle(color: AppColors.red)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _section(
                                    title: 'Terapie riepilogative',
                                    child: data.therapiesSummary.isEmpty
                                        ? const Text('Nessuna terapia disponibile.', style: TextStyle(color: Colors.white70))
                                        : Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: data.therapiesSummary
                                                .map((item) => Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.panelSoft,
                                                        borderRadius: BorderRadius.circular(14),
                                                      ),
                                                      child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                    ))
                                                .toList(),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  _section(
                                    title: 'Dettaglio ricette',
                                    child: data.prescriptions.isEmpty
                                        ? const Text('Nessuna ricetta registrata.', style: TextStyle(color: Colors.white70))
                                        : Column(
                                            children: data.prescriptions.map((prescription) {
                                              final matchingImport = _findImportForPrescription(data.imports, prescription.id);
                                              final expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
                                              return Container(
                                                width: double.infinity,
                                                margin: const EdgeInsets.only(bottom: 12),
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: AppColors.panelSoft,
                                                  borderRadius: BorderRadius.circular(18),
                                                  border: Border.all(color: Colors.white10),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            _prescriptionLabel(prescription),
                                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                                          ),
                                                        ),
                                                        if (matchingImport != null)
                                                          TextButton.icon(
                                                            onPressed: () => _openPdf(matchingImport),
                                                            icon: const Icon(Icons.open_in_new),
                                                            label: const Text('PDF'),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        _pill(expiryInfo.label, expiryInfo.color),
                                                        _pill(prescription.dpcFlag ? 'DPC' : 'NO DPC', prescription.dpcFlag ? AppColors.coral : AppColors.green),
                                                        _pill('${prescription.prescriptionCount} ricetta/e', AppColors.yellow),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    _detailLine('Data', _formatDate(prescription.prescriptionDate)),
                                                    _detailLine('Scadenza', _formatDate(prescription.expiryDate)),
                                                    _detailLine('Medico', (prescription.doctorName ?? '-').trim().isEmpty ? '-' : prescription.doctorName!.trim()),
                                                    _detailLine('Esenzione', (prescription.exemptionCode ?? '-').trim().isEmpty ? '-' : prescription.exemptionCode!.trim()),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildFamilySection(data),
                                ],
                              ),
                            ),
            );
          },
        ),
        FloatingPageMenu(
          currentIndex: appNavigationIndex.value,
          includeBack: true,
          onBack: _popWithDashboardArchiveDelta,
          pageIcon: Icons.badge_outlined,
          pageTooltip: 'Scheda assistito',
          onPageTap: _editCurrentPatientFromMenu,
          onSelected: (index) {
            appNavigationIndex.value = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
      ),
    );
  }

  Widget _buildHeader(_PatientDetailData data) {
    final patient = data.patient!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            visiblePatientTitle(
              fullName: patient.fullName,
              patientKey: patient.fiscalCode,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metaBadge(
                'CF',
                visiblePatientFiscalCode(patient.fiscalCode),
                tooltip: 'Copia CF',
                icon: Icons.copy_rounded,
                onTap: () => _copyToClipboard(visiblePatientFiscalCode(patient.fiscalCode)),
              ),
              if ((patient.alias ?? '').trim().isNotEmpty)
                _metaBadge('Alias', patient.alias!.trim()),
              _metaBadge('Medico', data.resolvedDoctorName),
              _metaBadge('Esenzione', data.primaryExemption),
              _metaBadge('Città', data.displayCity),
              _metaBadge('Ultima ricetta', _formatDate(data.lastPrescriptionDate)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _requestPatientDelete(data),
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.red),
              label: const Text(
                'Elimina assistito',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showTransientError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        content: Text(message),
      ),
    );
  }


  Patient? _findPatientByFiscalCode(List<Patient> patients, String fiscalCode) {
    final String normalizedFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(fiscalCode);
    for (final Patient patient in patients) {
      if (PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode) ==
          normalizedFiscalCode) {
        return patient;
      }
    }
    return null;
  }


  Future<void> _patchFamilyIndexForMembers(FamilyGroup family) async {
    final List<String> members = family.memberFiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
    for (final String fiscalCode in members) {
      try {
        await _patientDashboardIndexRepository.patchFamilyMetadata(
          fiscalCode: fiscalCode,
          familyId: family.id,
          familyName: family.name,
          familyColorIndex: family.colorIndex,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _message = 'Famiglia aggiornata. Badge Home non riallineato: $e';
        });
      }
    }
  }

  Future<void> _clearFamilyIndexForMembers(Iterable<String> fiscalCodes) async {
    final List<String> members = fiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
    for (final String fiscalCode in members) {
      try {
        await _patientDashboardIndexRepository.clearFamilyMetadata(fiscalCode);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _message = 'Famiglia aggiornata. Badge Home non riallineato: $e';
        });
      }
    }
  }

  Future<void> _openCreateFamilyFromPatientDialog(_PatientDetailData data) async {
    final Patient? currentPatient = data.patient;
    if (currentPatient == null) {
      return;
    }
    final String currentCode =
        PatientInputNormalizer.normalizeFiscalCode(currentPatient.fiscalCode);
    final List<Patient> allPatients = await _patientsRepository.getAllPatients();
    final List<Patient> availablePatients = allPatients
        .where(
          (Patient item) =>
              PatientInputNormalizer.normalizeFiscalCode(item.fiscalCode) !=
              currentCode,
        )
        .toList();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController searchController = TextEditingController();
    final Set<String> selectedCodes = <String>{};

    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final FamilyGroup family = await _familyGroupsRepository.createFamily(
                name: nameController.text,
                memberFiscalCodes: <String>[currentCode, ...selectedCodes],
              );
              await _patchFamilyIndexForMembers(family);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (!mounted) {
                return;
              }
              final _PatientFamilyContext familyContext =
                  await _buildFamilyContextFromFamily(
                family: family,
                currentPatient: currentPatient,
              );
              _replaceData(
                data.copyWith(familyContext: familyContext),
                "Famiglia creata e collegata all'assistito.",
              );
            } on FamilyMutationException catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = e.message;
                });
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore creazione famiglia: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setLocalState) {
              final String query = searchController.text.trim().toUpperCase();
              final List<Patient> suggestions = availablePatients.where((Patient patient) {
                final String fiscalCode =
                    PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
                if (selectedCodes.contains(fiscalCode)) {
                  return false;
                }
                if (query.isEmpty) {
                  return false;
                }
                final String fullName = patient.fullName.trim().toUpperCase();
                final String alias = (patient.alias ?? '').trim().toUpperCase();
                return fiscalCode.contains(query) || fullName.contains(query) || alias.contains(query);
              }).take(8).toList();

              return AlertDialog(
                backgroundColor: AppColors.panel,
                title: const Text(
                  'Nuova famiglia da assistito',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField(
                          nameController,
                          'Nome gruppo famiglia',
                          helperText:
                              "L'assistito corrente viene incluso automaticamente nel nucleo.",
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Assistito corrente',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _familySelectionChip(
                          label: visiblePatientTitle(
                            fullName: currentPatient.fullName,
                            patientKey: currentPatient.fiscalCode,
                          ),
                          sublabel: visiblePatientFiscalCode(currentPatient.fiscalCode),
                          color: AppColors.green,
                        ),
                        const SizedBox(height: 18),
                        _dialogField(
                          searchController,
                          'Aggiungi altri membri per nome, alias o CF',
                          helperText:
                              'I pazienti già assegnati ad altri nuclei verranno bloccati in salvataggio.',
                          onChanged: (_) => setLocalState(() {}),
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.panelSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: suggestions.map((Patient patient) {
                                final String fiscalCode =
                                    PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    visiblePatientTitle(
                                      fullName: patient.fullName,
                                      patientKey: patient.fiscalCode,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    visiblePatientFiscalCode(patient.fiscalCode),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.white70,
                                  ),
                                  onTap: () {
                                    setLocalState(() {
                                      selectedCodes.add(fiscalCode);
                                      searchController.clear();
                                      localError = '';
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Membri aggiuntivi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedCodes.isEmpty)
                          const Text(
                            'Nessun altro membro selezionato.',
                            style: TextStyle(color: Colors.white60),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedCodes.map((String fiscalCode) {
                              final Patient? patient = _findPatientByFiscalCode(
                                availablePatients,
                                fiscalCode,
                              );
                              return InputChip(
                                backgroundColor: AppColors.panelSoft,
                                label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visiblePatientTitle(
                                        fullName: patient?.fullName ?? '',
                                        patientKey: fiscalCode,
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      visiblePatientFiscalCode(fiscalCode),
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                  ],
                                ),
                                onDeleted: busy
                                    ? null
                                    : () {
                                        setLocalState(() {
                                          selectedCodes.remove(fiscalCode);
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        if (localError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            localError,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Annulla',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => submit(setLocalState),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crea famiglia'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      searchController.dispose();
    }
  }

  Future<void> _openJoinExistingFamilyDialog(_PatientDetailData data) async {
    final Patient? currentPatient = data.patient;
    if (currentPatient == null) {
      return;
    }
    final List<FamilyGroup> families = await _familyGroupsRepository.getAllFamilies();
    if (families.isEmpty) {
      _showTransientError("Non esistono famiglie a cui aggiungere l'assistito.");
      return;
    }
    final List<Patient> patients = await _patientsRepository.getAllPatients();
    final Map<String, Patient> patientsByCode = <String, Patient>{
      for (final Patient patient in patients)
        PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode): patient,
    };
    final String currentCode =
        PatientInputNormalizer.normalizeFiscalCode(currentPatient.fiscalCode);
    final TextEditingController searchController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          String localError = '';
          bool busy = false;
          String? selectedFamilyId;

          Future<void> submit(StateSetter setLocalState) async {
            if (selectedFamilyId == null || selectedFamilyId!.trim().isEmpty) {
              setLocalState(() {
                localError = 'Seleziona una famiglia esistente.';
              });
              return;
            }
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final FamilyGroup family = await _familyGroupsRepository.addMembersToFamily(
                familyId: selectedFamilyId!,
                memberFiscalCodes: <String>[currentCode],
              );
              await _patchFamilyIndexForMembers(family);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (!mounted) {
                return;
              }
              final _PatientFamilyContext familyContext =
                  await _buildFamilyContextFromFamily(
                family: family,
                currentPatient: currentPatient,
              );
              _replaceData(
                data.copyWith(familyContext: familyContext),
                'Assistito aggiunto al nucleo familiare.',
              );
            } on FamilyMutationException catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = e.message;
                });
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore collegamento famiglia: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setLocalState) {
              final String query = searchController.text.trim().toUpperCase();
              final List<FamilyGroup> filteredFamilies = families.where((FamilyGroup family) {
                if (query.isEmpty) {
                  return true;
                }
                final String familyName = family.name.trim().toUpperCase();
                final String familyId = family.id.trim().toUpperCase();
                if (familyName.contains(query) || familyId.contains(query)) {
                  return true;
                }
                for (final String code in family.memberFiscalCodes) {
                  if (code.toUpperCase().contains(query)) {
                    return true;
                  }
                  final Patient? patient = patientsByCode[
                    PatientInputNormalizer.normalizeFiscalCode(code)
                  ];
                  if ((patient?.fullName ?? '').trim().toUpperCase().contains(query)) {
                    return true;
                  }
                  if ((patient?.alias ?? '').trim().toUpperCase().contains(query)) {
                    return true;
                  }
                }
                return false;
              }).toList();

              return AlertDialog(
                backgroundColor: AppColors.panel,
                title: const Text(
                  'Aggiungi a famiglia esistente',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visiblePatientTitle(
                            fullName: currentPatient.fullName,
                            patientKey: currentPatient.fiscalCode,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          visiblePatientFiscalCode(currentPatient.fiscalCode),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        _dialogField(
                          searchController,
                          'Cerca famiglia per nome, ID, nome assistito, alias o CF',
                          onChanged: (_) => setLocalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        if (filteredFamilies.isEmpty)
                          const Text(
                            'Nessuna famiglia trovata.',
                            style: TextStyle(color: Colors.white60),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.panelSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: filteredFamilies.map((FamilyGroup family) {
                                final bool selected = family.id == selectedFamilyId;
                                final String label = family.name.trim().isNotEmpty
                                    ? family.name.trim()
                                    : family.id.trim();
                                final List<String> members = family.memberFiscalCodes.map((String code) {
                                  final Patient? patient = patientsByCode[
                                    PatientInputNormalizer.normalizeFiscalCode(code)
                                  ];
                                  final String title = visiblePatientTitle(
                                    fullName: patient?.fullName ?? '',
                                    patientKey: code,
                                  );
                                  return '$title · ${visiblePatientFiscalCode(code)}';
                                }).toList();
                                return RadioListTile<String>(
                                  value: family.id,
                                  groupValue: selectedFamilyId,
                                  activeColor: FamilyGroupColorUtils.colorForIndex(family.colorIndex),
                                  onChanged: busy
                                      ? null
                                      : (String? value) {
                                          setLocalState(() {
                                            selectedFamilyId = value;
                                            localError = '';
                                          });
                                        },
                                  title: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: FamilyGroupColorUtils.colorForIndex(family.colorIndex),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Family ID: ${family.id}',
                                          style: const TextStyle(color: Colors.white60),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          members.join('\n'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                  selected: selected,
                                );
                              }).toList(),
                            ),
                          ),
                        if (localError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            localError,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Annulla',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => submit(setLocalState),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Collega'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _openAddFamilyMembersDialog({
    required _PatientDetailData data,
    required _PatientFamilyContext familyContext,
  }) async {
    final List<Patient> allPatients = await _patientsRepository.getAllPatients();
    final Set<String> existingMembers = familyContext.members
        .map((_PatientFamilyMember item) =>
            PatientInputNormalizer.normalizeFiscalCode(item.fiscalCode))
        .where((String item) => item.isNotEmpty)
        .toSet();
    final List<Patient> availablePatients = allPatients.where((Patient patient) {
      final String fiscalCode =
          PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
      return !existingMembers.contains(fiscalCode);
    }).toList();
    final TextEditingController searchController = TextEditingController();
    final Set<String> selectedCodes = <String>{};

    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final FamilyGroup family = await _familyGroupsRepository.addMembersToFamily(
                familyId: familyContext.family.id,
                memberFiscalCodes: selectedCodes,
              );
              await _patchFamilyIndexForMembers(family);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (!mounted || data.patient == null) {
                return;
              }
              final _PatientFamilyContext nextFamilyContext =
                  await _buildFamilyContextFromFamily(
                family: family,
                currentPatient: data.patient!,
              );
              _replaceData(
                data.copyWith(familyContext: nextFamilyContext),
                'Membri famiglia aggiornati.',
              );
            } on FamilyMutationException catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = e.message;
                });
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore aggiunta membri: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setLocalState) {
              final String query = searchController.text.trim().toUpperCase();
              final List<Patient> suggestions = availablePatients.where((Patient patient) {
                final String fiscalCode =
                    PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
                if (selectedCodes.contains(fiscalCode)) {
                  return false;
                }
                if (query.isEmpty) {
                  return false;
                }
                final String fullName = patient.fullName.trim().toUpperCase();
                final String alias = (patient.alias ?? '').trim().toUpperCase();
                return fiscalCode.contains(query) || fullName.contains(query) || alias.contains(query);
              }).take(8).toList();

              return AlertDialog(
                backgroundColor: AppColors.panel,
                title: const Text(
                  'Aggiungi membri al nucleo',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          familyContext.displayLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Family ID: ${familyContext.family.id}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        _dialogField(
                          searchController,
                          'Cerca assistito per nome, alias o CF',
                          helperText:
                              'Sono esclusi i membri già presenti nel nucleo. Se il paziente appartiene a un altro nucleo il salvataggio verrà bloccato.',
                          onChanged: (_) => setLocalState(() {}),
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.panelSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: suggestions.map((Patient patient) {
                                final String fiscalCode =
                                    PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    visiblePatientTitle(
                                      fullName: patient.fullName,
                                      patientKey: patient.fiscalCode,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    visiblePatientFiscalCode(patient.fiscalCode),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.white70,
                                  ),
                                  onTap: () {
                                    setLocalState(() {
                                      selectedCodes.add(fiscalCode);
                                      searchController.clear();
                                      localError = '';
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Nuovi membri selezionati',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedCodes.isEmpty)
                          const Text(
                            'Nessun nuovo membro selezionato.',
                            style: TextStyle(color: Colors.white60),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedCodes.map((String fiscalCode) {
                              final Patient? patient = _findPatientByFiscalCode(
                                availablePatients,
                                fiscalCode,
                              );
                              return InputChip(
                                backgroundColor: AppColors.panelSoft,
                                label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visiblePatientTitle(
                                        fullName: patient?.fullName ?? '',
                                        patientKey: fiscalCode,
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      visiblePatientFiscalCode(fiscalCode),
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                  ],
                                ),
                                onDeleted: busy
                                    ? null
                                    : () {
                                        setLocalState(() {
                                          selectedCodes.remove(fiscalCode);
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        if (localError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            localError,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Annulla',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => submit(setLocalState),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aggiungi'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _removeFamilyMember({
    required _PatientDetailData data,
    required _PatientFamilyContext familyContext,
    required _PatientFamilyMember member,
  }) async {
    final String memberTitle = visiblePatientTitle(
      fullName: member.patient?.fullName ?? '',
      patientKey: member.fiscalCode,
    );
    final bool confirmed = await _confirmDelete(
      title: member.isCurrentPatient
          ? 'Uscire dal nucleo familiare?'
          : 'Rimuovere membro dal nucleo?',
      message: member.isCurrentPatient
          ? "L'assistito corrente verrà scollegato dal nucleo ${familyContext.displayLabel}."
          : '$memberTitle verrà rimosso dal nucleo ${familyContext.displayLabel}.',
    );
    if (!confirmed) {
      return;
    }
    try {
      final FamilyRemovalResult result =
          await _familyGroupsRepository.removeMemberFromFamily(
        familyId: familyContext.family.id,
        memberFiscalCode: member.fiscalCode,
      );
      await _clearFamilyIndexForMembers(<String>[member.fiscalCode]);
      if (!result.deletedFamily && result.family != null) {
        await _patchFamilyIndexForMembers(result.family!);
      } else if (result.deletedFamily) {
        await _clearFamilyIndexForMembers(
          familyContext.members.map((_PatientFamilyMember item) => item.fiscalCode),
        );
      }
      if (!mounted) {
        return;
      }
      final String message = result.deletedFamily
          ? 'Famiglia eliminata: nessun membro residuo.'
          : member.isCurrentPatient
              ? 'Assistito rimosso dal nucleo familiare.'
              : 'Membro rimosso dal nucleo familiare.';
      _PatientFamilyContext? nextFamilyContext;
      if (!result.deletedFamily && !member.isCurrentPatient && result.family != null && data.patient != null) {
        nextFamilyContext = await _buildFamilyContextFromFamily(
          family: result.family!,
          currentPatient: data.patient!,
        );
      }
      _replaceData(
        data.copyWith(familyContext: nextFamilyContext),
        message,
      );
    } on FamilyMutationException catch (e) {
      _showTransientError(e.message);
    } catch (e) {
      _showTransientError('Errore aggiornamento famiglia: $e');
    }
  }

  Widget _familySelectionChip({
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _openFamilyMemberDetail(String fiscalCode) async {
    if (PatientInputNormalizer.normalizeFiscalCode(fiscalCode) ==
        PatientInputNormalizer.normalizeFiscalCode(_currentFiscalCode)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailPage(fiscalCode: fiscalCode),
      ),
    );
  }


  Widget _buildFamilySection(_PatientDetailData data) {
    final _PatientFamilyContext? familyContext = data.familyContext;
    if (familyContext == null) {
      return _section(
        title: 'Nucleo familiare',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nessuna famiglia associata.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _familyActionButton(
                  icon: Icons.group_work_outlined,
                  label: 'Nuova famiglia',
                  onPressed: () => _openCreateFamilyFromPatientDialog(data),
                ),
                _familyActionButton(
                  icon: Icons.group_add_outlined,
                  label: 'Aggiungi a famiglia',
                  onPressed: () => _openJoinExistingFamilyDialog(data),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final Color familyColor = familyContext.color;
    final String familyLabel = familyContext.displayLabel;
    return _section(
      title: 'Nucleo familiare',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: familyColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Family ID: ${familyContext.family.id}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _familyActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Aggiungi membro',
                onPressed: () => _openAddFamilyMembersDialog(
                  data: data,
                  familyContext: familyContext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...familyContext.members.map(
            (_PatientFamilyMember member) => _buildFamilyMemberCard(
              data: data,
              familyContext: familyContext,
              member: member,
              familyColor: familyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMemberCard({
    required _PatientDetailData data,
    required _PatientFamilyContext familyContext,
    required _PatientFamilyMember member,
    required Color familyColor,
  }) {
    final Patient? relatedPatient = member.patient;
    final String fullName = relatedPatient?.fullName ?? '';
    final String title = visiblePatientTitle(
      fullName: fullName,
      patientKey: member.fiscalCode,
    );
    final List<Widget> statusPills = <Widget>[
      if (member.isCurrentPatient) _pill('ASSISTITO CORRENTE', familyColor),
      ..._familyMemberStatusPills(relatedPatient),
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: member.isCurrentPatient
          ? null
          : () => _openFamilyMemberDetail(member.fiscalCode),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panelSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: member.isCurrentPatient ? familyColor : Colors.white10,
            width: member.isCurrentPatient ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visiblePatientFiscalCode(member.fiscalCode),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (statusPills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusPills,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Tooltip(
                  message: member.isCurrentPatient
                      ? 'Rimuovi assistito dal nucleo'
                      : 'Rimuovi membro dal nucleo',
                  child: IconButton(
                    onPressed: () => _removeFamilyMember(
                      data: data,
                      familyContext: familyContext,
                      member: member,
                    ),
                    icon: const Icon(
                      Icons.person_remove_alt_1_outlined,
                      color: AppColors.red,
                    ),
                  ),
                ),
                if (!member.isCurrentPatient)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _familyActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  List<Widget> _familyMemberStatusPills(Patient? patient) {
    if (patient == null) {
      return const <Widget>[];
    }
    return <Widget>[
      if (patient.hasDpc) _pill('DPC', AppColors.coral),
      if (patient.hasDebt) _pill('DEBITI', AppColors.wine),
      if (patient.hasAdvance) _pill('ANTICIPI', AppColors.amber),
      if (patient.hasBooking) _pill('PRENOTAZIONI', AppColors.yellow),
    ];
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _managerCard({required String title, required String subtitle, required List<Widget> actions, List<Widget> extra = const []}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ...actions,
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...extra,
          ],
        ],
      ),
    );
  }

  Widget _metaBadge(
    String label,
    String value, {
    IconData? icon,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (icon != null && onTap != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: tooltip ?? '',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(icon, size: 16, color: Colors.white70),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? helperText,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }


  DrivePdfImport? _findImportForPrescription(List<DrivePdfImport> imports, String prescriptionId) {
    for (final item in imports) {
      if (item.id == prescriptionId) return item;
    }
    return null;
  }

  String _prescriptionLabel(Prescription prescription) {
    final label = prescription.items.map((item) => item.drugName.trim()).where((item) => item.isNotEmpty).join(', ');
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _localId(String prefix) => '${prefix}_${_currentFiscalCode}_${DateTime.now().microsecondsSinceEpoch}';

  double _parseEuro(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 0;
    final bool isNegative = trimmed.startsWith('-');
    final String unsigned = trimmed.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (unsigned.isEmpty) return 0;
    final int lastComma = unsigned.lastIndexOf(',');
    final int lastDot = unsigned.lastIndexOf('.');
    final int decimalSeparatorIndex = lastComma > lastDot ? lastComma : lastDot;
    String normalized;
    if (decimalSeparatorIndex >= 0) {
      final String integerPart = unsigned.substring(0, decimalSeparatorIndex).replaceAll(RegExp(r'[^0-9]'), '');
      final String decimalPart = unsigned.substring(decimalSeparatorIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
      normalized = decimalPart.isEmpty ? integerPart : '$integerPart.$decimalPart';
    } else {
      normalized = unsigned.replaceAll(RegExp(r'[^0-9]'), '');
    }
    if (normalized.isEmpty) return 0;
    return double.tryParse('${isNegative ? '-' : ''}$normalized') ?? 0;
  }

  DateTime? _parseItalianDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(int.parse(match.group(3)!), int.parse(match.group(2)!), int.parse(match.group(1)!));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _PatientDetailData {
  final Patient? patient;
  final List<Advance> advances;
  final List<Debt> debts;
  final List<Booking> bookings;
  final List<Prescription> prescriptions;
  final List<DrivePdfImport> imports;
  final List<DrivePdfImport> allImports;
  final AppSettings settings;
  final String resolvedDoctorName;
  final TherapeuticAdviceNote? therapeuticAdvice;
  final _PatientFamilyContext? familyContext;
  final _PatientIdentityResolutionContext? identityContext;

  const _PatientDetailData({
    required this.patient,
    required this.advances,
    required this.debts,
    required this.bookings,
    required this.prescriptions,
    required this.imports,
    required this.allImports,
    required this.settings,
    required this.resolvedDoctorName,
    required this.therapeuticAdvice,
    required this.familyContext,
    required this.identityContext,
  });

  static const Object _unset = Object();

  _PatientDetailData copyWith({
    Object? patient = _unset,
    List<Advance>? advances,
    List<Debt>? debts,
    List<Booking>? bookings,
    List<Prescription>? prescriptions,
    List<DrivePdfImport>? imports,
    List<DrivePdfImport>? allImports,
    AppSettings? settings,
    String? resolvedDoctorName,
    Object? therapeuticAdvice = _unset,
    Object? familyContext = _unset,
    Object? identityContext = _unset,
  }) {
    return _PatientDetailData(
      patient: identical(patient, _unset) ? this.patient : patient as Patient?,
      advances: advances ?? this.advances,
      debts: debts ?? this.debts,
      bookings: bookings ?? this.bookings,
      prescriptions: prescriptions ?? this.prescriptions,
      imports: imports ?? this.imports,
      allImports: allImports ?? this.allImports,
      settings: settings ?? this.settings,
      resolvedDoctorName: resolvedDoctorName ?? this.resolvedDoctorName,
      therapeuticAdvice: identical(therapeuticAdvice, _unset)
          ? this.therapeuticAdvice
          : therapeuticAdvice as TherapeuticAdviceNote?,
      familyContext: identical(familyContext, _unset)
          ? this.familyContext
          : familyContext as _PatientFamilyContext?,
      identityContext: identical(identityContext, _unset)
          ? this.identityContext
          : identityContext as _PatientIdentityResolutionContext?,
    );
  }

  double get totalDebt => debts.fold<double>(0, (double sum, Debt item) => sum + item.residualAmount);

  int get totalRecipeCount {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return prescriptions.fold<int>(0, (int sum, Prescription item) => sum + item.prescriptionCount);
    }
    return PhboxContractUtils.resolveRecipeCount(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  bool get hasDpc {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return imports.any((DrivePdfImport item) => item.isDpc) ||
          prescriptions.any((Prescription item) => item.dpcFlag);
    }
    return PhboxContractUtils.resolveHasDpc(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  DateTime? get lastPrescriptionDate {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return null;
    }
    return PhboxContractUtils.resolveLastPrescriptionDate(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  List<String> get therapiesSummary {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return const <String>[];
    }
    return PhboxContractUtils.resolveTherapiesSummary(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      prescriptions: prescriptions,
    );
  }

  String get primaryExemption {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return '-';
    }
    return PhboxContractUtils.resolveExemption(
      patient: currentPatient,
      visibleImports: imports,
      legacyPrescriptions: imports.isNotEmpty ? const <Prescription>[] : prescriptions,
    );
  }

  String get displayCity {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return '-';
    }
    return PhboxContractUtils.resolveCity(
      patient: currentPatient,
      visibleImports: imports,
      legacyPrescriptions: imports.isNotEmpty ? const <Prescription>[] : prescriptions,
    );
  }
}


class _PatientIdentityResolutionContext {
  final String sourceId;
  final String sourceFullName;
  final List<PatientDashboardIndex> candidates;

  const _PatientIdentityResolutionContext({
    required this.sourceId,
    required this.sourceFullName,
    required this.candidates,
  });
}

class _PatientFamilyContext {
  final FamilyGroup family;
  final List<_PatientFamilyMember> members;

  const _PatientFamilyContext({
    required this.family,
    required this.members,
  });

  Color get color => FamilyGroupColorUtils.colorForIndex(family.colorIndex);

  String get displayLabel {
    final String normalizedName = family.name.trim();
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }
    return family.id.trim();
  }
}

class _PatientFamilyMember {
  final String fiscalCode;
  final Patient? patient;
  final bool isCurrentPatient;

  const _PatientFamilyMember({
    required this.fiscalCode,
    required this.patient,
    required this.isCurrentPatient,
  });
}
