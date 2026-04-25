import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../core/utils/patient_identity_utils.dart';
import '../../../core/utils/family_group_color_utils.dart';
import '../../../core/utils/patient_input_normalizer.dart';
import '../../../core/utils/phbox_contract_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/dashboard_totals_snapshot.dart';
import '../../../data/models/doctor_patient_link.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/dashboard_totals_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/family_groups_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../features/patients/pages/patient_detail_page.dart';
import '../../../theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  late final PatientsRepository _patientsRepository;
  late final PrescriptionsRepository _prescriptionsRepository;
  late final AdvancesRepository _advancesRepository;
  late final DebtsRepository _debtsRepository;
  late final BookingsRepository _bookingsRepository;
  late final DrivePdfImportsRepository _drivePdfImportsRepository;
  late final DoctorPatientLinksRepository _doctorPatientLinksRepository;
  late final FamilyGroupsRepository _familyGroupsRepository;
  late final SettingsRepository _settingsRepository;
  late final DashboardTotalsRepository _dashboardTotalsRepository;

  Future<_DashboardData>? _future;
  _DashboardData _dashboardCache = _DashboardData.empty();
  bool _dashboardCacheLoaded = false;
  _DashboardTotals _dashboardTotals = _DashboardTotals.empty();
  final Set<_DashboardCardFilter> _activeCardFilters = <_DashboardCardFilter>{};
  String _message = '';
  bool _searchInFlags = false;
  bool _isRouteCovered = false;
  Timer? _inactiveFilterResetTimer;
  Timer? _userRequestRefreshDebounceTimer;
  String _lastUserRequestRefreshSignature = '';
  DateTime? _lastRefreshAt;
  StreamSubscription<DashboardTotalsSnapshot?>? _dashboardTotalsSubscription;

  static const Duration _inactiveFilterResetDelay = Duration(minutes: 2);
  static const Duration _userRequestRefreshDebounceDelay = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _prescriptionsRepository = PrescriptionsRepository(datasource: datasource);
    _advancesRepository = AdvancesRepository(datasource: datasource);
    _debtsRepository = DebtsRepository(datasource: datasource);
    _bookingsRepository = BookingsRepository(datasource: datasource);
    _drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _doctorPatientLinksRepository = DoctorPatientLinksRepository(datasource: datasource);
    _familyGroupsRepository = FamilyGroupsRepository(datasource: datasource);
    _settingsRepository = SettingsRepository(datasource: datasource);
    _dashboardTotalsRepository = DashboardTotalsRepository(datasource: datasource);
    _future = Future<_DashboardData>.value(_DashboardData.empty());
    _startDashboardTotalsListener();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _inactiveFilterResetTimer?.cancel();
    _inactiveFilterResetTimer = null;
    _userRequestRefreshDebounceTimer?.cancel();
    _userRequestRefreshDebounceTimer = null;
    _dashboardTotalsSubscription?.cancel();
    _dashboardTotalsSubscription = null;
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
    _scheduleInactiveFilterResetIfNeeded();
    if (_searchController.text.trim().length >= 3) {
      _ensureDashboardCacheForActiveRequest();
    }
  }

  bool get _hasTemporaryDashboardState {
    return _activeCardFilters.isNotEmpty ||
        _searchController.text.trim().isNotEmpty ||
        _searchInFlags;
  }

  bool get _hasUserRequestedDashboardData {
    return _activeCardFilters.isNotEmpty || _searchController.text.trim().length >= 3;
  }

  void _scheduleInactiveFilterResetIfNeeded() {
    _inactiveFilterResetTimer?.cancel();
    _inactiveFilterResetTimer = null;
    if (!_hasTemporaryDashboardState) {
      return;
    }
    _inactiveFilterResetTimer = Timer(
      _inactiveFilterResetDelay,
      _resetTemporaryDashboardState,
    );
  }

  void _resetTemporaryDashboardState() {
    if (!mounted || !_hasTemporaryDashboardState) {
      return;
    }
    _inactiveFilterResetTimer?.cancel();
    _inactiveFilterResetTimer = null;
    _userRequestRefreshDebounceTimer?.cancel();
    _userRequestRefreshDebounceTimer = null;
    _lastUserRequestRefreshSignature = '';
    _activeCardFilters.clear();
    _searchInFlags = false;
    if (_searchController.text.isNotEmpty) {
      _searchController.removeListener(_handleSearchChanged);
      _searchController.clear();
      _searchController.addListener(_handleSearchChanged);
    }
    setState(() {
      _future = Future<_DashboardData>.value(_DashboardData.empty());
    });
  }


  void _startDashboardTotalsListener() {
    _dashboardTotalsSubscription?.cancel();
    _dashboardTotalsSubscription = _dashboardTotalsRepository.watchMainTotals().listen(
      (DashboardTotalsSnapshot? snapshot) async {
        if (!mounted || _isRouteCovered) {
          return;
        }
        if (snapshot == null) {
          return;
        }
        final _DashboardTotals snapshotTotals = _DashboardTotals.fromSnapshot(snapshot);
        if (!_canAcceptDashboardTotalsSnapshot(snapshotTotals)) {
          return;
        }
        setState(() {
          _dashboardTotals = snapshotTotals;
          _lastRefreshAt = snapshot.updatedAt ?? DateTime.now();
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _message = 'Errore ascolto totali dashboard: $error';
        });
      },
    );
  }

  void _stopDashboardTotalsListener() {
    _dashboardTotalsSubscription?.cancel();
    _dashboardTotalsSubscription = null;
  }

  bool _canAcceptDashboardTotalsSnapshot(_DashboardTotals snapshotTotals) {
    if (snapshotTotals.hasAnyValue) {
      return true;
    }
    return !_dashboardTotals.hasAnyValue;
  }
  void _trackRefreshCompletion(Future<_DashboardData> future) {
    future.then((data) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardCache = data;
        _dashboardCacheLoaded = true;
        _lastRefreshAt = DateTime.now();
      });
    }).catchError((_) {});
  }

  void _issueLoad({bool force = false}) {
    if (!force && _dashboardCacheLoaded) {
      setState(() {
        _future = Future<_DashboardData>.value(_dashboardCache);
      });
      return;
    }
    final Future<_DashboardData> nextFuture = _load();
    _trackRefreshCompletion(nextFuture);
    setState(() {
      _future = nextFuture;
    });
  }

  void _ensureDashboardCacheForActiveRequest() {
    if (!_hasUserRequestedDashboardData) {
      setState(() {
        _future = Future<_DashboardData>.value(_DashboardData.empty());
      });
      return;
    }
    if (_dashboardCacheLoaded) {
      setState(() {
        _future = Future<_DashboardData>.value(_dashboardCache);
      });
      return;
    }
    _scheduleUserRequestedDataRefresh();
  }

  _DashboardData _currentDashboardData() {
    return _dashboardCacheLoaded ? _dashboardCache : _DashboardData.empty();
  }

  void _replaceDashboardCache(_DashboardData data) {
    _dashboardCache = data;
    _dashboardCacheLoaded = true;
    _future = Future<_DashboardData>.value(data);
  }

  void _replaceCachedSummary(_PatientDashboardSummary nextSummary) {
    final String targetCf = _normalizeFiscalCode(nextSummary.patient.fiscalCode);
    if (targetCf.isEmpty || !_dashboardCacheLoaded) {
      return;
    }
    final List<_PatientDashboardSummary> nextSummaries = <_PatientDashboardSummary>[];
    bool replaced = false;
    for (final _PatientDashboardSummary item in _dashboardCache.summaries) {
      if (_normalizeFiscalCode(item.patient.fiscalCode) == targetCf) {
        nextSummaries.add(nextSummary);
        replaced = true;
      } else {
        nextSummaries.add(item);
      }
    }
    if (!replaced) {
      nextSummaries.add(nextSummary);
    }
    nextSummaries.sort((a, b) {
      if (a.hasExpiryAlert != b.hasExpiryAlert) {
        return a.hasExpiryAlert ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    _replaceDashboardCache(_dashboardCache.copyWith(summaries: nextSummaries));
  }

  void _removeCachedSummary(String fiscalCode) {
    final String targetCf = _normalizeFiscalCode(fiscalCode);
    if (targetCf.isEmpty || !_dashboardCacheLoaded) {
      return;
    }
    final List<_PatientDashboardSummary> nextSummaries = _dashboardCache.summaries
        .where((item) => _normalizeFiscalCode(item.patient.fiscalCode) != targetCf)
        .toList();
    _replaceDashboardCache(_dashboardCache.copyWith(summaries: nextSummaries));
  }
  void _removeRecipeFromCachedSummary(_PatientDashboardSummary summary, DrivePdfImport removedImport) {
    final List<DrivePdfImport> nextImports = summary.imports
        .where((DrivePdfImport item) => item.id != removedImport.id)
        .toList();
    final int removedCount = removedImport.prescriptionCount > 0 ? removedImport.prescriptionCount : 1;
    final bool nextHasDpc = nextImports.any((DrivePdfImport item) => item.isDpc) ||
        summary.prescriptions.any((Prescription item) => item.dpcFlag);
    final bool nextHasExpiryAlert = nextImports.any((DrivePdfImport item) {
          final DateTime baseDate = item.prescriptionDate ?? item.createdAt;
          return _DashboardTotals._isExpiryAlert(baseDate.add(const Duration(days: 30)));
        }) ||
        summary.prescriptions.any((Prescription item) {
          return _DashboardTotals._isExpiryAlert(
            item.expiryDate ?? item.prescriptionDate.add(const Duration(days: 30)),
          );
        });
    _replaceCachedSummary(
      summary.copyWith(
        imports: nextImports,
        recipeCount: math.max(0, summary.recipeCount - removedCount),
        hasDpc: nextHasDpc,
        hasExpiryAlert: nextHasExpiryAlert,
      ),
    );
  }


  void _clearDisplayedDashboardRows() {
    setState(() {
      _future = Future<_DashboardData>.value(_DashboardData.empty());
    });
  }

  void _manualRefreshRequestedData() {
    if (!_hasUserRequestedDashboardData) {
      setState(() {
        _future = Future<_DashboardData>.value(_DashboardData.empty());
        _message = 'Nessun reload dati: seleziona una card o cerca almeno 3 caratteri.';
      });
      return;
    }
    _issueLoad(force: true);
  }

  Future<void> _copyToClipboard(String value, {String? message}) async {
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
        content: Text(message ?? 'CF copiato.'),
      ),
    );
  }

  String _formatVintageClock(DateTime? value) {
    if (value == null) {
      return '--/--/---- --:--:--';
    }
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString().padLeft(4, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    final String second = value.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  Future<_DashboardData> _load() async {
    if (!_hasUserRequestedDashboardData) {
      return _DashboardData.empty();
    }

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _patientsRepository.getAllPatients(),
      _drivePdfImportsRepository.getAllImports(includeHidden: true),
      _doctorPatientLinksRepository.getAllLinks(),
      _familyGroupsRepository.getAllFamilies(),
      _settingsRepository.getSettings(),
      _prescriptionsRepository.getAllLegacyPrescriptions(),
      _debtsRepository.getAllDebts(),
      _advancesRepository.getAllAdvances(),
      _bookingsRepository.getAllBookings(),
    ]);

    final List<Patient> patients = results[0] as List<Patient>;
    final List<DrivePdfImport> imports = results[1] as List<DrivePdfImport>;
    final List<DoctorPatientLink> doctorLinks = results[2] as List<DoctorPatientLink>;
    final List<FamilyGroup> families = results[3] as List<FamilyGroup>;
    final AppSettings settings = results[4] as AppSettings;
    final List<Prescription> allPrescriptions = results[5] as List<Prescription>;
    final List<Debt> allDebts = results[6] as List<Debt>;
    final List<Advance> allAdvances = results[7] as List<Advance>;
    final List<Booking> allBookings = results[8] as List<Booking>;

    final Map<String, Patient> patientByCf = <String, Patient>{};
    for (final Patient patient in patients) {
      final String cf = _normalizeFiscalCode(patient.fiscalCode);
      if (cf.isNotEmpty) {
        patientByCf[cf] = patient;
      }
    }

    final Map<String, List<DrivePdfImport>> importsByCf = _groupImportsByFiscalCode(imports);
    final Map<String, List<Prescription>> prescriptionsByCf = _groupByFiscalCode(allPrescriptions, (Prescription item) => item.patientFiscalCode);
    final Map<String, List<Debt>> debtsByCf = _groupByFiscalCode(allDebts, (Debt item) => item.patientFiscalCode);
    final Map<String, List<Advance>> advancesByCf = _groupByFiscalCode(allAdvances, (Advance item) => item.patientFiscalCode);
    final Map<String, List<Booking>> bookingsByCf = _groupByFiscalCode(allBookings, (Booking item) => item.patientFiscalCode);
    final Map<String, List<DoctorPatientLink>> doctorLinksByCf = _groupByFiscalCode(doctorLinks, (DoctorPatientLink item) => item.patientFiscalCode);

    _sortGroupsByDate(prescriptionsByCf, (Prescription item) => item.prescriptionDate);
    _sortGroupsByDate(debtsByCf, (Debt item) => item.createdAt);
    _sortGroupsByDate(advancesByCf, (Advance item) => item.createdAt);
    _sortGroupsByDate(bookingsByCf, (Booking item) => item.createdAt);

    final Set<String> allCfs = <String>{
      ...patientByCf.keys,
      ...importsByCf.keys,
      ...prescriptionsByCf.keys,
      ...debtsByCf.keys,
      ...advancesByCf.keys,
      ...bookingsByCf.keys,
    }..removeWhere((String cf) => cf.trim().isEmpty);

    final List<_PatientDashboardSummary> summaries = <_PatientDashboardSummary>[];
    for (final String cf in allCfs) {
      final Patient patient = patientByCf[cf] ?? _syntheticPatient(
        fiscalCode: cf,
        imports: importsByCf[cf] ?? const <DrivePdfImport>[],
        prescriptions: prescriptionsByCf[cf] ?? const <Prescription>[],
        debts: debtsByCf[cf] ?? const <Debt>[],
        advances: advancesByCf[cf] ?? const <Advance>[],
        bookings: bookingsByCf[cf] ?? const <Booking>[],
      );
      summaries.add(_PatientDashboardSummary.build(
        patient: patient,
        prescriptions: prescriptionsByCf[cf] ?? const <Prescription>[],
        imports: importsByCf[cf] ?? const <DrivePdfImport>[],
        debts: debtsByCf[cf] ?? const <Debt>[],
        advances: advancesByCf[cf] ?? const <Advance>[],
        bookings: bookingsByCf[cf] ?? const <Booking>[],
        doctorLinks: doctorLinksByCf[cf] ?? const <DoctorPatientLink>[],
        families: families,
      ));
    }

    summaries.sort((a, b) {
      if (a.hasExpiryAlert != b.hasExpiryAlert) {
        return a.hasExpiryAlert ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return _DashboardData(
      summaries: summaries,
      doctorsCatalog: settings.doctorsCatalog,
      families: families,
      totals: _dashboardTotals,
    );
  }

  bool _matchesPatientSearch(Patient patient, String query) {
    return patient.fullName.toLowerCase().contains(query) ||
        patient.fiscalCode.toLowerCase().contains(query) ||
        (patient.alias ?? '').toLowerCase().contains(query) ||
        (patient.doctorName ?? '').toLowerCase().contains(query) ||
        (patient.city ?? '').toLowerCase().contains(query) ||
        patient.primaryExemption.toLowerCase().contains(query);
  }

  bool _matchesPatientFamilySearch(Patient patient, List<FamilyGroup> families, String query) {
    final String cf = _normalizeFiscalCode(patient.fiscalCode);
    if (cf.isEmpty) return false;
    for (final FamilyGroup family in families) {
      final bool isMember = family.memberFiscalCodes.map(_normalizeFiscalCode).contains(cf);
      if (!isMember) continue;
      if (family.name.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  Map<String, List<DrivePdfImport>> _groupImportsByFiscalCode(List<DrivePdfImport> imports) {
    final Map<String, List<DrivePdfImport>> grouped = <String, List<DrivePdfImport>>{};
    for (final DrivePdfImport item in imports) {
      final String cf = _normalizeFiscalCode(item.patientFiscalCode);
      if (cf.isEmpty) continue;
      grouped.putIfAbsent(cf, () => <DrivePdfImport>[]).add(item);
    }
    for (final entries in grouped.values) {
      entries.sort((a, b) => b.chronologyDate.compareTo(a.chronologyDate));
    }
    return grouped;
  }

  String _normalizeFiscalCode(String value) => value.trim().toUpperCase();

  String? _blankToNull(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Patient _syntheticPatient({
    required String fiscalCode,
    required List<DrivePdfImport> imports,
    required List<Prescription> prescriptions,
    required List<Debt> debts,
    required List<Advance> advances,
    required List<Booking> bookings,
  }) {
    final DateTime now = DateTime.now();
    String fullName = fiscalCode;
    String? city;
    String? exemption;
    String? doctor;
    if (imports.isNotEmpty) {
      final DrivePdfImport first = imports.first;
      if (first.patientFullName.trim().isNotEmpty) fullName = first.patientFullName.trim();
      city = first.city.trim().isEmpty ? null : first.city.trim();
      exemption = first.exemptionCode.trim().isEmpty ? null : first.exemptionCode.trim();
      doctor = first.doctorFullName.trim().isEmpty ? null : first.doctorFullName.trim();
    } else if (prescriptions.isNotEmpty) {
      final Prescription first = prescriptions.first;
      if (first.patientName.trim().isNotEmpty) fullName = first.patientName.trim();
      city = _blankToNull(first.city);
      exemption = _blankToNull(first.exemptionCode);
      doctor = _blankToNull(first.doctorName);
    } else if (debts.isNotEmpty && debts.first.patientName.trim().isNotEmpty) {
      fullName = debts.first.patientName.trim();
    } else if (advances.isNotEmpty && advances.first.patientName.trim().isNotEmpty) {
      fullName = advances.first.patientName.trim();
    } else if (bookings.isNotEmpty && bookings.first.patientName.trim().isNotEmpty) {
      fullName = bookings.first.patientName.trim();
    }
    return Patient(
      fiscalCode: fiscalCode,
      fullName: fullName,
      city: city,
      exemptionCode: exemption,
      doctorName: doctor,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, List<T>> _groupByFiscalCode<T>(
    List<T> items,
    String Function(T item) fiscalCodeSelector,
  ) {
    final Map<String, List<T>> grouped = <String, List<T>>{};
    for (final item in items) {
      final String normalized = fiscalCodeSelector(item).trim().toUpperCase();
      if (normalized.isEmpty) continue;
      grouped.putIfAbsent(normalized, () => <T>[]).add(item);
    }
    return grouped;
  }

  void _sortGroupsByDate<T>(
    Map<String, List<T>> groups,
    DateTime Function(T item) dateSelector,
  ) {
    for (final entries in groups.values) {
      entries.sort((a, b) => dateSelector(b).compareTo(dateSelector(a)));
    }
  }

  bool get _isCompactDashboardMode {
    final String query = _searchController.text.trim();
    return _activeCardFilters.isEmpty && query.length < 3;
  }

  bool get _showSearchThresholdHint {
    final String query = _searchController.text.trim();
    return _activeCardFilters.isEmpty && query.isNotEmpty && query.length < 3;
  }

  void _refresh() {
    if (!_hasUserRequestedDashboardData) {
      _clearDisplayedDashboardRows();
      return;
    }
    setState(() {
      _future = Future<_DashboardData>.value(_currentDashboardData());
    });
  }

  List<_PatientDashboardSummary> _applyFilters(List<_PatientDashboardSummary> input, List<FamilyGroup> families) {
    final String rawQuery = _searchController.text.trim();
    final String query = rawQuery.toLowerCase();
    final bool hasSearchThreshold = rawQuery.length >= 3;
    final bool compactMode = _activeCardFilters.isEmpty && !hasSearchThreshold;

    bool matchesCardFilters(_PatientDashboardSummary item) {
      final activeFilters = _activeCardFilters.toList();
      if (activeFilters.isEmpty) {
        return compactMode ? item.hasExpiryAlert : true;
      }
      for (final filter in activeFilters) {
        switch (filter) {
          case _DashboardCardFilter.ricette:
            if (item.recipeCount == 0) return false;
            break;
          case _DashboardCardFilter.dpc:
            if (!item.hasDpc) return false;
            break;
          case _DashboardCardFilter.debiti:
            if (item.debts.isEmpty) return false;
            break;
          case _DashboardCardFilter.anticipi:
            if (item.advances.isEmpty) return false;
            break;
          case _DashboardCardFilter.prenotazioni:
            if (item.bookings.isEmpty) return false;
            break;
          case _DashboardCardFilter.scadenze:
            if (!item.hasExpiryAlert) return false;
            break;
        }
      }
      return true;
    }

    bool matchesSearch(_PatientDashboardSummary item) {
      if (!hasSearchThreshold) return true;
      final bool baseMatch = item.displayName.toLowerCase().contains(query) ||
          item.patient.fiscalCode.toLowerCase().contains(query) ||
          item.doctorName.toLowerCase().contains(query) ||
          item.exemptionCode.toLowerCase().contains(query) ||
          item.city.toLowerCase().contains(query) ||
          item.familyName.toLowerCase().contains(query) ||
          item.patientAlias.toLowerCase().contains(query);
      if (baseMatch) {
        return true;
      }
      if (_searchInFlags) {
        return item.flagSearchIndex.contains(query);
      }
      return false;
    }

    final filtered = input.where(matchesCardFilters).toList();
    if (!hasSearchThreshold) {
      return filtered;
    }

    final Map<String, _PatientDashboardSummary> byCf = {
      for (final item in filtered) item.patient.fiscalCode.trim().toUpperCase(): item,
    };

    final Set<String> resultCfs = filtered.where(matchesSearch).map((item) => item.patient.fiscalCode.trim().toUpperCase()).toSet();

    final Set<String> matchingFamilies = <String>{};
    for (final family in families) {
      final members = family.memberFiscalCodes.map((e) => e.trim().toUpperCase()).toSet();
      final hasMemberMatch = members.any((cf) => resultCfs.contains(cf));
      if (hasMemberMatch) {
        matchingFamilies.add(family.id);
        resultCfs.addAll(members.where(byCf.containsKey));
      }
    }

    final result = filtered.where((item) => resultCfs.contains(item.patient.fiscalCode.trim().toUpperCase())).toList();
    result.sort((a, b) {
      final aInFamily = matchingFamilies.contains(a.familyId);
      final bInFamily = matchingFamilies.contains(b.familyId);
      if (aInFamily != bInFamily) return aInFamily ? -1 : 1;
      if (a.hasExpiryAlert != b.hasExpiryAlert) return a.hasExpiryAlert ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return result;
  }

  void _scheduleUserRequestedDataRefresh() {
    final List<String> activeFilters = _activeCardFilters
        .map((filter) => filter.name)
        .toList()
      ..sort();
    final String signature = <String>[
      _searchController.text.trim().toUpperCase(),
      activeFilters.join(','),
      _searchInFlags ? 'FLAGS' : 'BASE',
    ].join('|');
    if (signature == _lastUserRequestRefreshSignature && _dashboardCacheLoaded) {
      setState(() {
        _future = Future<_DashboardData>.value(_dashboardCache);
      });
      return;
    }
    _lastUserRequestRefreshSignature = signature;
    if (_dashboardCacheLoaded) {
      setState(() {
        _future = Future<_DashboardData>.value(_dashboardCache);
      });
      return;
    }
    _userRequestRefreshDebounceTimer?.cancel();
    _userRequestRefreshDebounceTimer = Timer(_userRequestRefreshDebounceDelay, () {
      if (!mounted) {
        return;
      }
      _issueLoad();
    });
  }

  void _toggleCardFilter(_DashboardCardFilter filter) {
    final bool wasSelected = _activeCardFilters.contains(filter);
    setState(() {
      if (wasSelected) {
        _activeCardFilters.remove(filter);
        return;
      }

      _activeCardFilters.add(filter);
    });
    _scheduleInactiveFilterResetIfNeeded();
    _ensureDashboardCacheForActiveRequest();
  }

  Future<void> _openPdf(DrivePdfImport item) async {
    final String directLink = item.webViewLink.trim();
    final String fallbackLink = item.driveFileId.trim().isNotEmpty
        ? 'https://drive.google.com/file/d/${item.driveFileId.trim()}/view'
        : '';
    final String url = directLink.isNotEmpty ? directLink : fallbackLink;
    if (url.isEmpty) {
      setState(() {
        _message = 'Link PDF assente nel record Firestore.';
      });
      return;
    }
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _openPdfList(_PatientDashboardSummary summary) async {
    if (summary.imports.isEmpty) return;
    if (summary.imports.length == 1) {
      await _openPdf(summary.imports.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF ${summary.displayName}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      children: summary.imports.map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf, color: AppColors.coral),
                          title: Text(item.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${_formatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Elimina ricetta',
                                onPressed: () async {
                                  final bool confirmed = await _confirmDeleteRecipe(item);
                                  if (!confirmed) return;
                                  await _drivePdfImportsRepository.requestPdfDelete(item.id);
                                  _removeRecipeFromCachedSummary(summary, item);
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    _refresh();
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                              ),
                              TextButton(
                                onPressed: () => _openPdf(item),
                                child: const Text('Apri'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<bool> _confirmDeleteRecipe(DrivePdfImport item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Elimina ricetta', style: TextStyle(color: Colors.white)),
        content: Text(
          'La ricetta ${item.fileName} verrà rimossa dalla dashboard mantenendo i dati estratti nel database. Continuare?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina')),
        ],
      ),
    );
    return confirmed == true;
  }


  Future<void> _openFlagModal({
    required String title,
    required List<_FlagItem> items,
    Widget? headerAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _buildFlagDialog(
          title: title,
          items: items,
          headerAction: headerAction,
        );
      },
    );
  }

  Future<bool> _addDebtFromDashboard(_PatientDashboardSummary summary) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool saved = false;

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
                id: 'debt_${now.microsecondsSinceEpoch}',
                patientFiscalCode: summary.patient.fiscalCode,
                patientName: summary.patient.fullName,
                description: description,
                amount: amount,
                initialPaidAmountRaw: 0,
                createdAt: now,
                dueDate: now,
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );
              await _debtsRepository.saveDebt(debt);
              await _dashboardTotalsRepository.applyFrontendManagedDelta(debtAmountDelta: amount);
              _replaceCachedSummary(summary.copyWith(debts: <Debt>[debt, ...summary.debts]));
              saved = true;
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                _refresh();
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
      return saved;
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _addAdvanceFromDashboard(_PatientDashboardSummary summary) async {
    final drugController = TextEditingController();
    final noteController = TextEditingController();
    String selectedDoctor = summary.doctorName.trim() == '-' ? '' : summary.doctorName.trim();
    final data = _currentDashboardData();
    final candidateList = <String>{
      ...data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (selectedDoctor.isNotEmpty) selectedDoctor,
    }.toList()
      ..sort();
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            final String drugName = drugController.text.trim();
            final String doctorName = selectedDoctor.trim();
            if (drugName.isEmpty || doctorName.isEmpty) {
              setLocalState(() => localError = 'Farmaco e medico sono obbligatori.');
              return;
            }
            setLocalState(() {
              busy = true;
              localError = '';
            });
            try {
              final DateTime now = DateTime.now();
              final Advance advance = Advance(
                id: 'adv_${now.microsecondsSinceEpoch}',
                patientFiscalCode: summary.patient.fiscalCode,
                patientName: summary.patient.fullName,
                drugName: drugName,
                doctorName: doctorName,
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                createdAt: now,
                updatedAt: now,
              );
              await _advancesRepository.saveAdvance(advance);
              await _dashboardTotalsRepository.applyFrontendManagedDelta(advanceCountDelta: 1);
              _replaceCachedSummary(summary.copyWith(
                advances: <Advance>[advance, ...summary.advances],
                doctorName: doctorName,
              ));
              await _doctorPatientLinksRepository.saveManualOverride(
                patientFiscalCode: summary.patient.fiscalCode,
                patientFullName: summary.patient.fullName,
                doctorFullName: doctorName,
                city: summary.city == '-' ? null : summary.city,
              );
              saved = true;
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                _refresh();
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore salvataggio anticipo: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setLocalState) => AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Nuovo anticipo', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(drugController, 'Farmaco / articolo'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDoctor.isEmpty ? null : selectedDoctor,
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
                      items: candidateList.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
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
            ),
          );
        },
      );
      return saved;
    } finally {
      drugController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _addBookingFromDashboard(_PatientDashboardSummary summary) async {
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
              _dialogField(drugController, 'Farmaco / articolo'),
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
    if (confirmed != true) return false;
    try {
      if (drugController.text.trim().isEmpty) {
        throw Exception('Farmaco obbligatorio.');
      }
      final now = DateTime.now();
      final Booking booking = Booking(
        id: 'book_${now.microsecondsSinceEpoch}',
        patientFiscalCode: summary.patient.fiscalCode,
        patientName: summary.patient.fullName,
        drugName: drugController.text.trim(),
        quantity: int.tryParse(quantityController.text.trim()) ?? 1,
        createdAt: now,
        expectedDate: now,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      await _bookingsRepository.saveBooking(booking);
      await _dashboardTotalsRepository.applyFrontendManagedDelta(bookingCountDelta: 1);
      _replaceCachedSummary(summary.copyWith(bookings: <Booking>[booking, ...summary.bookings]));
      _refresh();
      return true;
    } catch (e) {
      setState(() => _message = 'Errore salvataggio prenotazione: $e');
      return false;
    } finally {
      drugController.dispose();
      quantityController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _deleteAllDebts(_PatientDashboardSummary summary) async {
    double debtDelta = 0;
    for (final item in summary.debts) {
      debtDelta -= item.residualAmount;
      await _debtsRepository.deleteDebt(summary.patient.fiscalCode, item.id);
    }
    await _dashboardTotalsRepository.applyFrontendManagedDelta(debtAmountDelta: debtDelta);
    _replaceCachedSummary(summary.copyWith(debts: const <Debt>[]));
    _refresh();
    return true;
  }

  Future<bool> _deleteAllAdvances(_PatientDashboardSummary summary) async {
    int advanceDelta = 0;
    for (final item in summary.advances) {
      advanceDelta -= 1;
      await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, item.id);
    }
    await _dashboardTotalsRepository.applyFrontendManagedDelta(advanceCountDelta: advanceDelta);
    _replaceCachedSummary(summary.copyWith(advances: const <Advance>[]));
    _refresh();
    return true;
  }

  Future<bool> _deleteAllBookings(_PatientDashboardSummary summary) async {
    int bookingDelta = 0;
    for (final item in summary.bookings) {
      bookingDelta -= 1;
      await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, item.id);
    }
    await _dashboardTotalsRepository.applyFrontendManagedDelta(bookingCountDelta: bookingDelta);
    _replaceCachedSummary(summary.copyWith(bookings: const <Booking>[]));
    _refresh();
    return true;
  }


  Future<void> _openEditableFlagModal({
    required _PatientDashboardSummary summary,
    required String key,
  }) async {
    final data = _currentDashboardData();
    final doctorsCatalog = data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();

    final debtDescriptionController = TextEditingController();
    final debtAmountController = TextEditingController();
    final debtNoteController = TextEditingController();

    final advanceDrugController = TextEditingController();
    final advanceNoteController = TextEditingController();

    final bookingDrugController = TextEditingController();
    final bookingQuantityController = TextEditingController(text: '1');
    final bookingNoteController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          _PatientDashboardSummary currentSummary = summary;
          bool busy = false;
          bool showAddForm = false;
          String formError = '';
          String selectedDoctor = summary.doctorName.trim() == '-' ? '' : summary.doctorName.trim();

          Future<void> reload(StateSetter setLocalState) async {
            setLocalState(() {
              busy = false;
            });
          }

          Future<void> runBusyAction(StateSetter setLocalState, Future<void> Function() action) async {
            setLocalState(() => busy = true);
            try {
              await action();
            } finally {
              await reload(setLocalState);
            }
          }

          void clearInlineForm() {
            debtDescriptionController.clear();
            debtAmountController.clear();
            debtNoteController.clear();
            advanceDrugController.clear();
            advanceNoteController.clear();
            bookingDrugController.clear();
            bookingQuantityController.text = '1';
            bookingNoteController.clear();
            formError = '';
            selectedDoctor = currentSummary.doctorName.trim() == '-' ? '' : currentSummary.doctorName.trim();
          }

          Future<void> saveInlineForm(StateSetter setLocalState) async {
            final now = DateTime.now();
            final fiscalCode = currentSummary.patient.fiscalCode;
            final patientName = currentSummary.patient.fullName;

            try {
              if (key == 'debiti') {
                final String description = debtDescriptionController.text.trim();
                final double amount = _parseEuro(debtAmountController.text);
                if (description.isEmpty || amount == 0) {
                  setLocalState(() => formError = 'Inserisci causale e importo validi.');
                  return;
                }
                final Debt debt = Debt.createNew(
                  id: 'debt_${now.microsecondsSinceEpoch}',
                  patientFiscalCode: fiscalCode,
                  patientName: patientName,
                  description: description,
                  amount: amount,
                  initialPaidAmountRaw: 0,
                  createdAt: now,
                  dueDate: now,
                  note: debtNoteController.text.trim().isEmpty ? null : debtNoteController.text.trim(),
                );
                await _debtsRepository.saveDebt(debt);
                await _dashboardTotalsRepository.applyFrontendManagedDelta(debtAmountDelta: amount);
                currentSummary = currentSummary.copyWith(debts: <Debt>[debt, ...currentSummary.debts]);
                _replaceCachedSummary(currentSummary);
              } else if (key == 'anticipi') {
                final drugName = advanceDrugController.text.trim();
                final doctorName = selectedDoctor.trim();
                if (drugName.isEmpty || doctorName.isEmpty) {
                  setLocalState(() => formError = 'Inserisci farmaco e medico.');
                  return;
                }
                final Advance advance = Advance(
                  id: 'adv_${now.microsecondsSinceEpoch}',
                  patientFiscalCode: fiscalCode,
                  patientName: patientName,
                  drugName: drugName,
                  doctorName: doctorName,
                  note: advanceNoteController.text.trim().isEmpty ? null : advanceNoteController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                await _advancesRepository.saveAdvance(advance);
                await _dashboardTotalsRepository.applyFrontendManagedDelta(advanceCountDelta: 1);
                currentSummary = currentSummary.copyWith(
                  advances: <Advance>[advance, ...currentSummary.advances],
                  doctorName: doctorName,
                );
                _replaceCachedSummary(currentSummary);
              } else {
                final drugName = bookingDrugController.text.trim();
                final quantity = int.tryParse(bookingQuantityController.text.trim()) ?? 1;
                if (drugName.isEmpty || quantity <= 0) {
                  setLocalState(() => formError = 'Inserisci farmaco e quantità valide.');
                  return;
                }
                final Booking booking = Booking(
                  id: 'book_${now.microsecondsSinceEpoch}',
                  patientFiscalCode: fiscalCode,
                  patientName: patientName,
                  drugName: drugName,
                  quantity: quantity,
                  createdAt: now,
                  expectedDate: now,
                  note: bookingNoteController.text.trim().isEmpty ? null : bookingNoteController.text.trim(),
                );
                await _bookingsRepository.saveBooking(booking);
                await _dashboardTotalsRepository.applyFrontendManagedDelta(bookingCountDelta: 1);
                currentSummary = currentSummary.copyWith(bookings: <Booking>[booking, ...currentSummary.bookings]);
                _replaceCachedSummary(currentSummary);
              }

              _refresh();
              setLocalState(() {
                showAddForm = false;
                clearInlineForm();
              });
              await runBusyAction(setLocalState, () async {});
            } catch (e) {
              setLocalState(() {
                formError = 'Errore salvataggio: $e';
              });
            }
          }

          List<_FlagItem> buildItems(StateSetter setLocalState) {
            if (key == 'debiti') {
              return currentSummary.debts
                  .map((item) => _FlagItem(
                        title: '${item.description} · € ${item.residualAmount.toStringAsFixed(2)}',
                        subtitle: 'Inserito ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                        onDelete: () async {
                          await runBusyAction(setLocalState, () async {
                            await _debtsRepository.deleteDebt(currentSummary.patient.fiscalCode, item.id);
                            await _dashboardTotalsRepository.applyFrontendManagedDelta(debtAmountDelta: -item.residualAmount);
                            currentSummary = currentSummary.copyWith(
                              debts: currentSummary.debts.where((Debt debt) => debt.id != item.id).toList(),
                            );
                            _replaceCachedSummary(currentSummary);
                            _refresh();
                          });
                        },
                      ))
                  .toList();
            }
            if (key == 'anticipi') {
              return currentSummary.advances
                  .map((item) => _FlagItem(
                        title: item.drugName,
                        subtitle: '${item.doctorName.isEmpty ? '-' : item.doctorName} · ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                        onDelete: () async {
                          await runBusyAction(setLocalState, () async {
                            await _advancesRepository.deleteAdvance(currentSummary.patient.fiscalCode, item.id);
                            await _dashboardTotalsRepository.applyFrontendManagedDelta(advanceCountDelta: -1);
                            currentSummary = currentSummary.copyWith(
                              advances: currentSummary.advances.where((Advance advance) => advance.id != item.id).toList(),
                            );
                            _replaceCachedSummary(currentSummary);
                            _refresh();
                          });
                        },
                      ))
                  .toList();
            }
            return currentSummary.bookings
                .map((item) => _FlagItem(
                      title: '${item.drugName} x${item.quantity}',
                      subtitle: 'Registrata ${_formatDate(item.createdAt)} · Prevista ${_formatDate(item.expectedDate)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                      onDelete: () async {
                        await runBusyAction(setLocalState, () async {
                          await _bookingsRepository.deleteBooking(currentSummary.patient.fiscalCode, item.id);
                          await _dashboardTotalsRepository.applyFrontendManagedDelta(bookingCountDelta: -1);
                          currentSummary = currentSummary.copyWith(
                            bookings: currentSummary.bookings.where((Booking booking) => booking.id != item.id).toList(),
                          );
                          _replaceCachedSummary(currentSummary);
                          _refresh();
                        });
                      },
                    ))
                .toList();
          }

          String modalTitle() {
            if (key == 'debiti') return 'Debiti · ${currentSummary.displayName}';
            if (key == 'anticipi') return 'Anticipi · ${currentSummary.displayName}';
            return 'Prenotazioni · ${currentSummary.displayName}';
          }

          Widget buildInlineForm(StateSetter setLocalState) {
            if (!showAddForm) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key == 'debiti' ? 'Nuovo debito' : key == 'anticipi' ? 'Nuovo anticipo' : 'Nuova prenotazione',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (key == 'debiti') ...[
                    _dialogField(debtDescriptionController, 'Causale'),
                    const SizedBox(height: 12),
                    _dialogField(
                      debtAmountController,
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
                    _dialogField(debtNoteController, 'Nota', maxLines: 3),
                  ] else if (key == 'anticipi') ...[
                    _dialogField(advanceDrugController, 'Farmaco / articolo'),
                  ] else ...[
                    _dialogField(bookingDrugController, 'Farmaco / articolo'),
                    const SizedBox(height: 12),
                    _dialogField(
                      bookingQuantityController,
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
                    _dialogField(bookingNoteController, 'Nota', maxLines: 3),
                  ],
                  if (key == 'anticipi') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDoctor.isEmpty ? null : selectedDoctor,
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
                      items: ((<String>{...doctorsCatalog, if (selectedDoctor.isNotEmpty) selectedDoctor}.toList())..sort())
                          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setLocalState(() => selectedDoctor = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Data registrazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 12),
                    _dialogField(advanceNoteController, 'Nota', maxLines: 3),
                  ],
                  if (formError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(formError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setLocalState(() {
                                  showAddForm = false;
                                  clearInlineForm();
                                });
                              },
                        child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: busy ? null : () => saveInlineForm(setLocalState),
                        child: const Text('Salva'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              Widget headerAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: showAddForm
                        ? 'Chiudi inserimento'
                        : key == 'debiti'
                            ? 'Nuovo debito'
                            : key == 'anticipi'
                                ? 'Nuovo anticipo'
                                : 'Nuova prenotazione',
                    onPressed: busy
                        ? null
                        : () {
                            setLocalState(() {
                              showAddForm = !showAddForm;
                              if (!showAddForm) clearInlineForm();
                              formError = '';
                            });
                          },
                    icon: Icon(showAddForm ? Icons.remove_circle_outline : Icons.add_circle_outline, color: AppColors.green),
                  ),
                  IconButton(
                    tooltip: 'Elimina tutto',
                    onPressed: busy
                        ? null
                        : () => runBusyAction(setLocalState, () async {
                              if (key == 'debiti') {
                                double debtDelta = 0;
                                for (final item in currentSummary.debts) {
                                  debtDelta -= item.residualAmount;
                                  await _debtsRepository.deleteDebt(currentSummary.patient.fiscalCode, item.id);
                                }
                                await _dashboardTotalsRepository.applyFrontendManagedDelta(debtAmountDelta: debtDelta);
                                currentSummary = currentSummary.copyWith(debts: const <Debt>[]);
                                _replaceCachedSummary(currentSummary);
                              } else if (key == 'anticipi') {
                                int advanceDelta = 0;
                                for (final item in currentSummary.advances) {
                                  advanceDelta -= 1;
                                  await _advancesRepository.deleteAdvance(currentSummary.patient.fiscalCode, item.id);
                                }
                                await _dashboardTotalsRepository.applyFrontendManagedDelta(advanceCountDelta: advanceDelta);
                                currentSummary = currentSummary.copyWith(advances: const <Advance>[]);
                                _replaceCachedSummary(currentSummary);
                              } else {
                                int bookingDelta = 0;
                                for (final item in currentSummary.bookings) {
                                  bookingDelta -= 1;
                                  await _bookingsRepository.deleteBooking(currentSummary.patient.fiscalCode, item.id);
                                }
                                await _dashboardTotalsRepository.applyFrontendManagedDelta(bookingCountDelta: bookingDelta);
                                currentSummary = currentSummary.copyWith(bookings: const <Booking>[]);
                                _replaceCachedSummary(currentSummary);
                              }
                              _refresh();
                            }),
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
                  ),
                ],
              );
              return Stack(
                children: [
                  _buildFlagDialog(
                    title: modalTitle(),
                    items: buildItems(setLocalState),
                    headerAction: headerAction,
                    inlineTop: buildInlineForm(setLocalState),
                    dialogContext: dialogContext,
                  ),
                  if (busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
    } finally {
      debtDescriptionController.dispose();
      debtAmountController.dispose();
      debtNoteController.dispose();
      advanceDrugController.dispose();
      advanceNoteController.dispose();
      bookingDrugController.dispose();
      bookingQuantityController.dispose();
      bookingNoteController.dispose();
    }
  }

  Widget _buildFlagDialog({
    required String title,
    required List<_FlagItem> items,
    Widget? headerAction,
    Widget? inlineTop,
    BuildContext? dialogContext,
  }) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: SizedBox(
        width: 760,
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
                  if (headerAction != null) ...[
                    headerAction,
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(dialogContext ?? context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (inlineTop != null) ...[
                inlineTop,
                const SizedBox(height: 4),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: items.isEmpty
                    ? const Text('Nessuna voce.', style: TextStyle(color: Colors.white70))
                    : SingleChildScrollView(
                        child: Column(
                          children: items.map((item) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.panelSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                        if (item.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(item.subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (item.onDelete != null) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      tooltip: 'Elimina voce',
                                      onPressed: item.onDelete == null ? null : () async { await item.onDelete!.call(); },
                                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFlagTap(_PatientDashboardSummary summary, String key) async {
    if (key == 'ricette') {
      await _openPdfList(summary);
      return;
    }
    if (key == 'dpc') {
      await _openFlagModal(
        title: 'DPC · ${summary.displayName}',
        items: summary.dpcItems.map((item) {
          return _FlagItem(
            title: item.title,
            subtitle: item.subtitle,
          );
        }).toList(),
      );
      return;
    }
    if (key == 'quick-edit') {
      final selectedKey = await showDialog<String>(
        context: context,
        builder: (context) {
          Widget option({required IconData icon, required String label, required String value}) {
            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white12,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).pop(value),
            );
          }

          return AlertDialog(
            backgroundColor: AppColors.panel,
            title: Text('Apri gestione · ${summary.displayName}', style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(icon: Icons.account_balance_wallet_outlined, label: 'Debiti', value: 'debiti'),
                option(icon: Icons.payments_outlined, label: 'Anticipi', value: 'anticipi'),
                option(icon: Icons.event_note_outlined, label: 'Prenotazioni', value: 'prenotazioni'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi', style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      );
      if (selectedKey != null && mounted) {
        await _openEditableFlagModal(summary: summary, key: selectedKey);
      }
      return;
    }
    if (key == 'debiti' || key == 'anticipi' || key == 'prenotazioni') {
      await _openEditableFlagModal(summary: summary, key: key);
      return;
    }
  }

  Future<void> _openAddPatientDialog() async {
    final data = _currentDashboardData();
    final fiscalCodeController = TextEditingController();
    final fiscalCodeFocusNode = FocusNode();
    final nameController = TextEditingController();
    final surnameController = TextEditingController();
    final aliasController = TextEditingController();
    final advanceController = TextEditingController();
    final bookingController = TextEditingController();
    final debtController = TextEditingController();
    final debtDescriptionController = TextEditingController();
    String selectedDoctor = '';
    final doctorCandidates = data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();

    _PatientDashboardSummary? _findExactPatientByCf(String rawValue) {
      final String normalizedCf = PatientInputNormalizer.normalizeFiscalCode(rawValue);
      for (final summary in data.summaries) {
        final String patientKey = PatientInputNormalizer.normalizeFiscalCode(summary.patient.fiscalCode);
        if (isTemporaryPatientKey(patientKey)) continue;
        if (patientKey == normalizedCf) {
          return summary;
        }
      }
      return null;
    }

    List<_PatientDashboardSummary> _findPatientSuggestions(String rawValue) {
      final String normalizedQuery = PatientInputNormalizer.normalizeFiscalCode(rawValue);
      if (normalizedQuery.isEmpty) return const [];
      final List<_PatientDashboardSummary> startsWithMatches = <_PatientDashboardSummary>[];
      final List<_PatientDashboardSummary> containsMatches = <_PatientDashboardSummary>[];
      for (final summary in data.summaries) {
        final String patientCf = PatientInputNormalizer.normalizeFiscalCode(summary.patient.fiscalCode);
        if (patientCf.isEmpty || isTemporaryPatientKey(patientCf)) continue;
        if (patientCf.startsWith(normalizedQuery)) {
          startsWithMatches.add(summary);
        } else if (patientCf.contains(normalizedQuery)) {
          containsMatches.add(summary);
        }
      }
      final List<_PatientDashboardSummary> allMatches = <_PatientDashboardSummary>[...startsWithMatches, ...containsMatches];
      if (allMatches.length <= 6) return allMatches;
      return allMatches.take(6).toList();
    }

    void _applyPatientSuggestion(_PatientDashboardSummary summary, void Function(void Function()) setLocalState) {
      final String normalizedCf = PatientInputNormalizer.normalizeFiscalCode(summary.patient.fiscalCode);
      final List<String> nameParts = PatientInputNormalizer.splitFullName(summary.patient.fullName);
      final String doctorFromMemory = summary.doctorName.trim();
      setLocalState(() {
        fiscalCodeController.value = fiscalCodeController.value.copyWith(
          text: normalizedCf,
          selection: TextSelection.collapsed(offset: normalizedCf.length),
          composing: TextRange.empty,
        );
        if (nameParts.first.isNotEmpty) {
          nameController.text = nameParts.first;
        }
        if (nameParts.last.isNotEmpty) {
          surnameController.text = nameParts.last;
        }
        aliasController.text = summary.patient.alias?.trim() ?? '';
        if (doctorFromMemory.isNotEmpty && doctorFromMemory != '-' && doctorCandidates.contains(doctorFromMemory)) {
          selectedDoctor = doctorFromMemory;
        }
      });
    }

    void fillFromExistingPatient(String rawValue, void Function(void Function()) setLocalState) {
      final String normalizedCf = PatientInputNormalizer.normalizeFiscalCode(rawValue);
      if (fiscalCodeController.text != normalizedCf) {
        fiscalCodeController.value = fiscalCodeController.value.copyWith(
          text: normalizedCf,
          selection: TextSelection.collapsed(offset: normalizedCf.length),
          composing: TextRange.empty,
        );
      }
      final _PatientDashboardSummary? existing = _findExactPatientByCf(normalizedCf);
      if (existing != null) {
        _applyPatientSuggestion(existing, setLocalState);
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String localError = '';
          bool busy = false;

          Future<void> submit(StateSetter setLocalState) async {
            final String fiscalCode = PatientInputNormalizer.normalizeFiscalCode(fiscalCodeController.text);
            final String name = PatientInputNormalizer.normalizeNamePart(nameController.text);
            final String surname = PatientInputNormalizer.normalizeNamePart(surnameController.text);
            final String fullName = PatientInputNormalizer.buildFullName(name: name, surname: surname);
            final String alias = aliasController.text.trim();
            final String advanceText = advanceController.text.trim();
            final String bookingText = bookingController.text.trim();
            final double debtValue = _parseEuro(debtController.text);
            final String debtDescription = debtDescriptionController.text.trim();

            if (fiscalCode.isEmpty && name.isEmpty && surname.isEmpty) {
              setLocalState(() => localError = 'Inserisci almeno uno tra codice fiscale, nome e cognome.');
              return;
            }
            if (advanceText.isNotEmpty && selectedDoctor.trim().isEmpty) {
              setLocalState(() => localError = "Per l'anticipo devi selezionare il medico.");
              return;
            }
            if (debtValue != 0 && debtDescription.isEmpty) {
              setLocalState(() => localError = 'Per il debito devi indicare la causale.');
              return;
            }

            setLocalState(() {
              busy = true;
              localError = '';
            });

            try {
              final DateTime now = DateTime.now();
              final _PatientDashboardSummary? existingPatient =
                  fiscalCode.isEmpty ? null : _findExactPatientByCf(fiscalCode);
              final String patientDocumentId = existingPatient?.patient.fiscalCode ?? buildManualPatientDocumentId(
                fiscalCode: fiscalCode,
                name: name,
                surname: surname,
                now: now,
              );
              final String effectivePatientName = fullName.isNotEmpty
                  ? fullName
                  : (existingPatient?.patient.fullName.trim() ?? '');

              await _patientsRepository.createManualPatient(
                Patient(
                  fiscalCode: patientDocumentId,
                  fullName: fullName,
                  alias: alias,
                  createdAt: now,
                  updatedAt: now,
                ),
              );

              if (advanceText.isNotEmpty) {
                await _advancesRepository.saveAdvance(
                  Advance(
                    id: 'adv_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: patientDocumentId,
                    patientName: effectivePatientName,
                    drugName: advanceText,
                    doctorName: selectedDoctor.trim(),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                await _doctorPatientLinksRepository.saveManualOverride(
                  patientFiscalCode: patientDocumentId,
                  patientFullName: effectivePatientName,
                  doctorFullName: selectedDoctor.trim(),
                );
              }

              if (bookingText.isNotEmpty) {
                await _bookingsRepository.saveBooking(
                  Booking(
                    id: 'book_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: patientDocumentId,
                    patientName: effectivePatientName,
                    drugName: bookingText,
                    createdAt: now,
                    expectedDate: now,
                  ),
                );
              }

              if (debtValue != 0) {
                await _debtsRepository.saveDebt(
                  Debt.createNew(
                    id: 'debt_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: patientDocumentId,
                    patientName: effectivePatientName,
                    description: debtDescription,
                    amount: debtValue,
                    initialPaidAmountRaw: 0,
                    createdAt: now,
                    dueDate: now,
                  ),
                );
              }

              await _dashboardTotalsRepository.applyFrontendManagedDelta(
                debtAmountDelta: debtValue,
                advanceCountDelta: advanceText.isNotEmpty ? 1 : 0,
                bookingCountDelta: bookingText.isNotEmpty ? 1 : 0,
              );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                setState(() {
                  _message = 'Assistito inserito correttamente.';
                });
                _refresh();
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setLocalState(() {
                  busy = false;
                  localError = 'Errore inserimento assistito: $e';
                });
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                backgroundColor: AppColors.panel,
                title: const Text('Nuovo assistito', style: TextStyle(color: Colors.white)),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RawAutocomplete<_PatientDashboardSummary>(
                          textEditingController: fiscalCodeController,
                          focusNode: fiscalCodeFocusNode,
                          displayStringForOption: (option) => PatientInputNormalizer.normalizeFiscalCode(option.patient.fiscalCode),
                          optionsBuilder: (textEditingValue) {
                            return _findPatientSuggestions(textEditingValue.text);
                          },
                          onSelected: (selection) {
                            _applyPatientSuggestion(selection, setLocalState);
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            return _dialogField(
                              textEditingController,
                              'Codice fiscale',
                              focusNode: focusNode,
                              onChanged: (value) => fillFromExistingPatient(value, setLocalState),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final List<_PatientDashboardSummary> optionList = options.toList(growable: false);
                            if (optionList.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: 460,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.panelSoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: optionList.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                    itemBuilder: (context, index) {
                                      final option = optionList[index];
                                      final String normalizedCf = PatientInputNormalizer.normalizeFiscalCode(option.patient.fiscalCode);
                                      final String displayName = PatientInputNormalizer.normalizeFullName(option.patient.fullName).toUpperCase();
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(normalizedCf, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 2),
                                              Text(displayName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                              if ((option.patient.alias ?? '').trim().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Alias: ${(option.patient.alias ?? '').trim()}',
                                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _dialogField(nameController, 'Nome'),
                        const SizedBox(height: 12),
                        _dialogField(surnameController, 'Cognome'),
                        const SizedBox(height: 12),
                        _dialogField(aliasController, 'Alias / nomignolo'),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'È sufficiente compilare uno solo tra codice fiscale, nome e cognome.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dialogField(advanceController, 'Eventuale anticipo', onChanged: (_) => setLocalState(() {})),
                        if (advanceController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedDoctor.isEmpty ? null : selectedDoctor,
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
                            items: doctorCandidates.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                            onChanged: (value) => setLocalState(() => selectedDoctor = value ?? ''),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Data anticipo: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _dialogField(bookingController, 'Eventuale prenotazione', onChanged: (_) => setLocalState(() {})),
                        if (bookingController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Data prenotazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _dialogField(
                          debtController,
                          'Importo debito (€)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,\.]'))],
                          onChanged: (_) => setLocalState(() {}),
                        ),
                        if (_parseEuro(debtController.text) != 0) ...[
                          const SizedBox(height: 12),
                          _dialogField(debtDescriptionController, 'Causale debito'),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Data debito: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
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
      fiscalCodeController.dispose();
      fiscalCodeFocusNode.dispose();
      nameController.dispose();
      surnameController.dispose();
      aliasController.dispose();
      advanceController.dispose();
      bookingController.dispose();
      debtController.dispose();
      debtDescriptionController.dispose();
    }
  }

  Future<void> _deletePatientEverything(_PatientDashboardSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Eliminazione totale', style: TextStyle(color: Colors.white)),
          content: Text(
            'Eliminare debiti, anticipi, prenotazioni e richiedere la delete dei PDF ricetta di ${summary.displayName}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      for (final debt in summary.debts) {
        await _debtsRepository.deleteDebt(summary.patient.fiscalCode, debt.id);
      }
      for (final advance in summary.advances) {
        await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, advance.id);
      }
      for (final booking in summary.bookings) {
        await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, booking.id);
      }
      final recipeImports = summary.imports;
      for (final importItem in recipeImports) {
        await _drivePdfImportsRepository.requestPdfDelete(importItem.id);
      }
      await _dashboardTotalsRepository.applyFrontendManagedDelta(
        debtAmountDelta: -summary.totalDebt,
        advanceCountDelta: -summary.advances.length,
        bookingCountDelta: -summary.bookings.length,
      );
      _removeCachedSummary(summary.patient.fiscalCode);
      setState(() {
        _message = 'Dati operativi rimossi e delete PDF richiesta.';
      });
      _refresh();
    } catch (e) {
      setState(() {
        _message = 'Errore eliminazione totale: $e';
      });
    }
  }

  void _openPatient(_PatientDashboardSummary summary) {
    _stopDashboardTotalsListener();
    setState(() {
      _isRouteCovered = true;
    });
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailPage(fiscalCode: summary.patient.fiscalCode),
          ),
        )
        .whenComplete(() {
          if (!mounted) {
            return;
          }
          setState(() {
            _isRouteCovered = false;
          });
          _startDashboardTotalsListener();
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final allSummaries = data == null || !_hasUserRequestedDashboardData ? const <_PatientDashboardSummary>[] : data.summaries;
        final summaries = data == null || !_hasUserRequestedDashboardData ? const <_PatientDashboardSummary>[] : _applyFilters(allSummaries, data.families);
        final _DashboardTotals totals = _dashboardTotals;
        final familyState = data == null
            ? _DashboardFamilyState.empty()
            : _DashboardFamilyState.fromFamilies(data.summaries, data.families);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_message.isNotEmpty) ...[
                  Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double cardWidth = 220;
                    const double cardSpacing = 12;
                    final double cardsBlockWidth = constraints.maxWidth >= ((cardWidth * 6) + (cardSpacing * 5))
                        ? ((cardWidth * 6) + (cardSpacing * 5))
                        : constraints.maxWidth;
                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: SizedBox(
                            width: cardsBlockWidth,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: cardSpacing,
                              runSpacing: cardSpacing,
                              children: [
                                _SummaryCard(
                                  title: 'Ricette',
                                  value: totals.recipeCount.toString(),
                                  icon: Icons.receipt_long_outlined,
                                  accent: AppColors.green,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.ricette),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.ricette),
                                ),
                                _SummaryCard(
                                  title: 'Totale DPC',
                                  value: totals.dpcCount.toString(),
                                  icon: Icons.local_shipping_outlined,
                                  accent: AppColors.coral,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.dpc),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.dpc),
                                ),
                                _SummaryCard(
                                  title: 'Debiti',
                                  value: '€ ${totals.debtAmount.toStringAsFixed(2)}',
                                  icon: Icons.euro_outlined,
                                  accent: AppColors.wine,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.debiti),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.debiti),
                                ),
                                _SummaryCard(
                                  title: 'Anticipi',
                                  value: totals.advanceCount.toString(),
                                  icon: Icons.payments_outlined,
                                  accent: AppColors.amber,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.anticipi),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.anticipi),
                                ),
                                _SummaryCard(
                                  title: 'Prenotazioni',
                                  value: totals.bookingCount.toString(),
                                  icon: Icons.event_note_outlined,
                                  accent: AppColors.yellow,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.prenotazioni),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.prenotazioni),
                                ),
                                _SummaryCard(
                                  title: 'In scadenza',
                                  value: totals.expiringCount.toString(),
                                  icon: Icons.warning_amber_rounded,
                                  accent: AppColors.coral,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.scadenze),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.scadenze),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: cardsBlockWidth,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      hintText: _searchInFlags
                                          ? 'Cerca in assistiti, nuclei e flag (min 3 lettere)'
                                          : 'Cerca assistito o nucleo (min 3 lettere)',
                                      hintStyle: const TextStyle(color: Colors.white54),
                                      prefixIcon: const Icon(Icons.search, size: 20),
                                      filled: true,
                                      fillColor: AppColors.panel,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Tooltip(
                                  message: _searchInFlags
                                      ? 'Ricerca nei flag attiva'
                                      : 'Attiva ricerca nei flag',
                                  child: Material(
                                    color: _searchInFlags ? AppColors.yellow : AppColors.panel,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        setState(() {
                                          _searchInFlags = !_searchInFlags;
                                        });
                                        _scheduleInactiveFilterResetIfNeeded();
                                        if (_searchController.text.trim().length >= 3) {
                                          _ensureDashboardCacheForActiveRequest();
                                        }
                                      },
                                      child: SizedBox(
                                        width: 52,
                                        height: 48,
                                        child: Icon(
                                          Icons.outlined_flag,
                                          color: _searchInFlags ? Colors.black : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: cardsBlockWidth,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF283018),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF97A96B)),
                                ),
                                child: Text(
                                  _formatVintageClock(_lastRefreshAt),
                                  style: const TextStyle(
                                    color: Color(0xFFD7F1A2),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Tooltip(
                                message: 'Aggiorna solo la richiesta attiva',
                                child: IconButton(
                                  onPressed: _manualRefreshRequestedData,
                                  icon: const Icon(Icons.refresh, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isCompactDashboardMode)
                          SizedBox(
                            width: cardsBlockWidth,
                            child: Text(
                              _showSearchThresholdHint
                                  ? 'Dashboard a riposo: aggiorno solo le cards. La ricerca dati si attiva da 3 lettere.'
                                  : 'Dashboard a riposo: nessun reload dati. Seleziona una card o cerca almeno 3 lettere.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _openAddPatientDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuovo assistito'),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  Expanded(
                    child: Center(
                      child: Text('Errore dashboard: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                    ),
                  )
                else
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, tableConstraints) {
                        final double sideInset = math.min(220, math.max(24, tableConstraints.maxWidth * 0.12));
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: sideInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 180, child: Text('Assistito', style: _headStyle)),
                              SizedBox(width: 220, child: Text('CF', style: _headStyle)),
                              SizedBox(width: 240, child: Text('Medico', style: _headStyle)),
                              SizedBox(width: 120, child: Text('Esenzione', style: _headStyle)),
                              Expanded(child: Text('Flags', style: _headStyle)),
                              SizedBox(width: 52),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final orderedSummaries = [...summaries]..sort((a, b) {
                                if (a.hasExpiryAlert == b.hasExpiryAlert) return 0;
                                return a.hasExpiryAlert ? -1 : 1;
                              });
                              if (orderedSummaries.isEmpty) {
                                return Center(child: Text(_isCompactDashboardMode ? 'Nessun dato richiesto.' : 'Nessun assistito.', style: const TextStyle(color: Colors.white70, fontSize: 18)));
                              }
                              return ListView.separated(
                                itemCount: orderedSummaries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                    final item = orderedSummaries[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: item.hasExpiryAlert ? const Color(0x332A1B00) : AppColors.panel,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: item.hasExpiryAlert ? AppColors.amber : Colors.white10,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 180,
                                            child: TextButton(
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                              onPressed: () => _openPatient(item),
                                              child: Row(
                                                children: [
                                                  if (item.familyId.isNotEmpty && familyState.hasMultipleActive(item.familyId)) ...[
                                                    Container(
                                                      width: 14,
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        color: familyState.colorFor(item.familyId),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      item.displayName,
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white, fontSize: 18.2, fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 220,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                                    onPressed: () => _openPatient(item),
                                                    child: Text(
                                                      visiblePatientFiscalCode(item.patient.fiscalCode),
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: AppColors.yellow, fontSize: 18.2, fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Copia CF',
                                                  onPressed: () => _copyToClipboard(
                                                    visiblePatientFiscalCode(item.patient.fiscalCode),
                                                    message: 'CF copiato negli appunti.',
                                                  ),
                                                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 240,
                                            child: Text(
                                              item.doctorNameUpper,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 18.2, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(item.exemptionCode, style: const TextStyle(color: Colors.white70, fontSize: 18.2)),
                                          ),
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _buildFlagChips(item),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 52,
                                            child: IconButton(
                                              tooltip: 'Elimina tutto',
                                              onPressed: () => _deletePatientEverything(item),
                                              icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                            },
                          ),
                        ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  List<Widget> _buildFlagChips(_PatientDashboardSummary item) {
    final widgets = <Widget>[
      _QuickEditFlag(onTap: () => _handleFlagTap(item, 'quick-edit')),
    ];
    if (item.recipeCount > 0 && item.imports.isNotEmpty) {
      widgets.add(
        Container(
          padding: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FlagChip(label: 'ricette ${item.recipeCount}', color: AppColors.green, onTap: () => _handleFlagTap(item, 'ricette')),
              IconButton(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                tooltip: 'Elimina ricetta',
                onPressed: () => _deleteRecipesFromRow(item),
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      );
    }
    if (item.dpcItems.isNotEmpty) {
      widgets.add(_FlagChip(label: 'DPC ${item.dpcItems.length}', color: AppColors.coral, onTap: () => _handleFlagTap(item, 'dpc')));
    }
    if (item.totalDebt.abs() > 0.005) {
      widgets.add(_FlagChip(label: 'debiti € ${item.totalDebt.toStringAsFixed(2)}', color: AppColors.wine, onTap: () => _handleFlagTap(item, 'debiti')));
    }
    if (item.advances.isNotEmpty) {
      widgets.add(_FlagChip(label: 'anticipi ${item.advances.length}', color: AppColors.amber, onTap: () => _handleFlagTap(item, 'anticipi')));
    }
    if (item.bookings.isNotEmpty) {
      widgets.add(_FlagChip(label: 'prenotazioni ${item.bookings.length}', color: AppColors.yellow, onTap: () => _handleFlagTap(item, 'prenotazioni')));
    }
    return widgets;
  }

  Future<void> _deleteRecipesFromRow(_PatientDashboardSummary summary) async {
    if (summary.imports.isEmpty) return;
    if (summary.imports.length == 1) {
      final item = summary.imports.first;
      final confirmed = await _confirmDeleteRecipe(item);
      if (!confirmed) return;
      await _drivePdfImportsRepository.requestPdfDelete(item.id);
      _removeRecipeFromCachedSummary(summary, item);
      _refresh();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          bool busy = false;
          Future<void> handleDelete(DrivePdfImport item) async {
            final confirmed = await _confirmDeleteRecipe(item);
            if (!confirmed) return;
            setLocalState(() => busy = true);
            await _drivePdfImportsRepository.requestPdfDelete(item.id);
            _removeRecipeFromCachedSummary(summary, item);
            _refresh();
            setLocalState(() => busy = false);
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
          }
          return Stack(
            children: [
              _buildFlagDialog(
                title: 'Elimina ricette · ${summary.displayName}',
                items: summary.imports.map((item) => _FlagItem(
                  title: item.fileName,
                  subtitle: '${_formatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
                  onDelete: () => handleDelete(item),
                )).toList(),
                dialogContext: dialogContext,
              ),
              if (busy) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
            ],
          );
        },
      ),
    );
  }


  Widget _dialogField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
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


  double _parseEuro(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 0;
    final bool isNegative = trimmed.startsWith('-');
    final String unsigned = trimmed.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (unsigned.isEmpty) return 0;
    final int lastComma = unsigned.lastIndexOf(',');
    final int lastDot = unsigned.lastIndexOf('.');
    final int decimalSeparatorIndex = math.max(lastComma, lastDot);
    String normalized;
    if (decimalSeparatorIndex >= 0) {
      final String integerPart = unsigned.substring(0, decimalSeparatorIndex).replaceAll(RegExp(r'[^0-9]'), '');
      final String decimalPart = unsigned.substring(decimalSeparatorIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
      normalized = decimalPart.isEmpty ? integerPart : '$integerPart.$decimalPart';
    } else {
      normalized = unsigned.replaceAll(RegExp(r'[^0-9]'), '');
    }
    if (normalized.isEmpty) return 0;
    final double parsed = double.tryParse('${isNegative ? '-' : ''}$normalized') ?? 0;
    return parsed;
  }

  String _prescriptionTitle(Prescription prescription) {
    final label = prescription.items.map((e) => e.drugName.trim()).where((e) => e.isNotEmpty).join(', ');
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _DashboardTotals {
  final int recipeCount;
  final int dpcCount;
  final double debtAmount;
  final int advanceCount;
  final int bookingCount;
  final int expiringCount;

  const _DashboardTotals({
    required this.recipeCount,
    required this.dpcCount,
    required this.debtAmount,
    required this.advanceCount,
    required this.bookingCount,
    required this.expiringCount,
  });

  factory _DashboardTotals.empty() {
    return const _DashboardTotals(
      recipeCount: 0,
      dpcCount: 0,
      debtAmount: 0,
      advanceCount: 0,
      bookingCount: 0,
      expiringCount: 0,
    );
  }

  factory _DashboardTotals.fromSnapshot(DashboardTotalsSnapshot snapshot) {
    return _DashboardTotals(
      recipeCount: snapshot.recipeCount,
      dpcCount: snapshot.dpcCount,
      debtAmount: snapshot.debtAmount,
      advanceCount: snapshot.advanceCount,
      bookingCount: snapshot.bookingCount,
      expiringCount: snapshot.expiringCount,
    );
  }

  bool get hasAnyValue {
    return recipeCount != 0 ||
        dpcCount != 0 ||
        debtAmount != 0 ||
        advanceCount != 0 ||
        bookingCount != 0 ||
        expiringCount != 0;
  }

  factory _DashboardTotals.fromCollections({
    required List<DrivePdfImport> imports,
    required List<Prescription> legacyPrescriptions,
    required List<Debt> debts,
    required List<Advance> advances,
    required List<Booking> bookings,
  }) {
    final List<DrivePdfImport> visibleImports =
        imports.where((DrivePdfImport item) => !item.isHiddenFromFrontend).toList();
    final Set<String> importPatientKeys = visibleImports
        .map(_importPatientKey)
        .where((String item) => item.isNotEmpty)
        .toSet();

    int recipeCount = 0;
    int dpcCount = 0;
    final Set<String> expiringPatientKeys = <String>{};

    for (final DrivePdfImport item in visibleImports) {
      recipeCount += item.prescriptionCount > 0 ? item.prescriptionCount : 1;
      if (item.isDpc) {
        dpcCount += 1;
      }
      final String key = _importPatientKey(item);
      final DateTime baseDate = item.prescriptionDate ?? item.createdAt;
      if (_isExpiryAlert(baseDate.add(const Duration(days: 30)))) {
        expiringPatientKeys.add(key.isEmpty ? item.id : key);
      }
    }

    for (final Prescription item in legacyPrescriptions) {
      final String key = item.patientFiscalCode.trim().toUpperCase();
      if (key.isNotEmpty && importPatientKeys.contains(key)) {
        continue;
      }
      recipeCount += item.prescriptionCount > 0 ? item.prescriptionCount : 1;
      if (item.dpcFlag) {
        dpcCount += 1;
      }
      final DateTime expiryDate = item.expiryDate ?? item.prescriptionDate.add(const Duration(days: 30));
      if (_isExpiryAlert(expiryDate)) {
        expiringPatientKeys.add(key.isEmpty ? item.id : key);
      }
    }

    return _DashboardTotals(
      recipeCount: recipeCount,
      dpcCount: dpcCount,
      debtAmount: debts.fold<double>(0, (sum, item) => sum + item.residualAmount),
      advanceCount: advances.length,
      bookingCount: bookings.length,
      expiringCount: expiringPatientKeys.length,
    );
  }

  static String _importPatientKey(DrivePdfImport item) {
    final String fiscalCode = item.patientFiscalCode.trim().toUpperCase();
    if (fiscalCode.isNotEmpty) {
      return fiscalCode;
    }
    return item.patientFullName.trim().toUpperCase();
  }

  static bool _isExpiryAlert(DateTime? date) {
    final PrescriptionExpiryInfo info = PrescriptionExpiryUtils.evaluate(date);
    return info.status == PrescriptionValidityStatus.expiringSoon ||
        info.status == PrescriptionValidityStatus.expired;
  }
}

class _DashboardData {
  final List<_PatientDashboardSummary> summaries;
  final List<String> doctorsCatalog;
  final List<FamilyGroup> families;
  final _DashboardTotals totals;

  const _DashboardData({
    required this.summaries,
    required this.doctorsCatalog,
    required this.families,
    required this.totals,
  });

  _DashboardData copyWith({
    List<_PatientDashboardSummary>? summaries,
    List<String>? doctorsCatalog,
    List<FamilyGroup>? families,
    _DashboardTotals? totals,
  }) {
    return _DashboardData(
      summaries: summaries ?? this.summaries,
      doctorsCatalog: doctorsCatalog ?? this.doctorsCatalog,
      families: families ?? this.families,
      totals: totals ?? this.totals,
    );
  }

  factory _DashboardData.empty() {
    return _DashboardData(
      summaries: const <_PatientDashboardSummary>[],
      doctorsCatalog: const <String>[],
      families: const <FamilyGroup>[],
      totals: _DashboardTotals.empty(),
    );
  }
}

class _PatientDashboardSummary {
  final Patient patient;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final List<Prescription> prescriptions;
  final List<DrivePdfImport> imports;
  final List<Debt> debts;
  final List<Advance> advances;
  final List<Booking> bookings;
  final bool hasDpc;
  final int recipeCount;
  final bool hasExpiryAlert;
  final String familyId;
  final String familyName;

  const _PatientDashboardSummary({
    required this.patient,
    required this.doctorName,
    required this.exemptionCode,
    required this.city,
    required this.prescriptions,
    required this.imports,
    required this.debts,
    required this.advances,
    required this.bookings,
    required this.hasDpc,
    required this.recipeCount,
    required this.hasExpiryAlert,
    required this.familyId,
    required this.familyName,
  });

  _PatientDashboardSummary copyWith({
    Patient? patient,
    String? doctorName,
    String? exemptionCode,
    String? city,
    List<Prescription>? prescriptions,
    List<DrivePdfImport>? imports,
    List<Debt>? debts,
    List<Advance>? advances,
    List<Booking>? bookings,
    bool? hasDpc,
    int? recipeCount,
    bool? hasExpiryAlert,
    String? familyId,
    String? familyName,
  }) {
    return _PatientDashboardSummary(
      patient: patient ?? this.patient,
      doctorName: doctorName ?? this.doctorName,
      exemptionCode: exemptionCode ?? this.exemptionCode,
      city: city ?? this.city,
      prescriptions: prescriptions ?? this.prescriptions,
      imports: imports ?? this.imports,
      debts: debts ?? this.debts,
      advances: advances ?? this.advances,
      bookings: bookings ?? this.bookings,
      hasDpc: hasDpc ?? this.hasDpc,
      recipeCount: recipeCount ?? this.recipeCount,
      hasExpiryAlert: hasExpiryAlert ?? this.hasExpiryAlert,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
    );
  }

  String get displayName => patient.fullName.trim().isEmpty ? patient.fiscalCode : patient.fullName.trim();
  String get patientAlias => (patient.alias ?? '').trim();

  double get totalDebt => debts.fold<double>(0, (sum, item) => sum + item.residualAmount);

  String get doctorNameUpper => doctorName.trim().isEmpty ? '-' : doctorName.trim().toUpperCase();
  String get doctorSurnameUpper {
    final String cleaned = doctorName.trim();
    if (cleaned.isEmpty || cleaned == '-') return '-';
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return (parts.isEmpty ? cleaned : parts.first).toUpperCase();
  }

  bool get hasActiveContent => recipeCount > 0 || hasDpc || debts.isNotEmpty || advances.isNotEmpty || bookings.isNotEmpty;
  String get flagSearchIndex {
    final Iterable<String> tokens = <String>[
      ...prescriptions.expand((Prescription item) sync* {
        yield item.extractedText ?? '';
        yield item.doctorName ?? '';
        yield item.exemptionCode ?? '';
        yield item.city ?? '';
        for (final prescriptionItem in item.items) {
          yield prescriptionItem.drugName;
        }
      }),
      ...imports.expand((DrivePdfImport item) sync* {
        yield item.fileName;
        yield item.doctorFullName;
        yield item.city;
        for (final therapy in item.therapy) {
          yield therapy;
        }
      }),
      ...debts.expand((Debt item) => <String>[item.description, item.note ?? '']),
      ...advances.expand((Advance item) => <String>[item.drugName, item.doctorName, item.note ?? '']),
      ...bookings.expand((Booking item) => <String>[item.drugName, item.note ?? '']),
      patient.alias ?? '',
      if (hasDpc) 'dpc',
    ];
    return tokens
        .map((String item) => item.trim().toLowerCase())
        .where((String item) => item.isNotEmpty)
        .join(' ');
  }

  List<_FlagItem> get dpcItems {
    final fromPrescriptions = prescriptions.where((item) => item.dpcFlag).map((item) {
      return _FlagItem(
        title: _dashboardPrescriptionTitle(item),
        subtitle: '${_dashboardFormatDate(item.prescriptionDate)} · ${(item.doctorName ?? '-').trim().isEmpty ? '-' : item.doctorName!.trim()}',
      );
    });
    final fromImports = imports.where((item) => item.isDpc).map((item) {
      return _FlagItem(
        title: item.therapy.isEmpty ? (item.fileName.trim().isEmpty ? 'DPC' : item.fileName.trim()) : item.therapy.join(', '),
        subtitle: '${_dashboardFormatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
      );
    });
    return [...fromPrescriptions, ...fromImports];
  }

  static _PatientDashboardSummary build({
    required Patient patient,
    required List<Prescription> prescriptions,
    required List<DrivePdfImport> imports,
    required List<Debt> debts,
    required List<Advance> advances,
    required List<Booking> bookings,
    required List<DoctorPatientLink> doctorLinks,
    required List<FamilyGroup> families,
  }) {
    final String normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
    final List<DrivePdfImport> allImportsForPatient =
        PhboxContractUtils.allImportsForPatient(
      patient: patient,
      imports: imports,
    );
    final List<DrivePdfImport> visibleImportsForPatient =
        allImportsForPatient.where((DrivePdfImport item) => !item.isHiddenFromFrontend).toList();
    final String doctorName = PhboxContractUtils.resolveDoctor(
      fiscalCode: patient.fiscalCode,
      doctorLinks: doctorLinks,
      patientDoctorFullName: patient.doctorFullName,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );
    final String exemptionCode = PhboxContractUtils.resolveExemption(
      patient: patient,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );
    final String city = PhboxContractUtils.resolveCity(
      patient: patient,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );
    final int recipeCount = PhboxContractUtils.resolveRecipeCount(
      patient: patient,
      allImports: allImportsForPatient,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );
    final bool hasDpc = PhboxContractUtils.resolveHasDpc(
      patient: patient,
      allImports: allImportsForPatient,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );
    final DateTime? lastPrescriptionDate =
        PhboxContractUtils.resolveLastPrescriptionDate(
      patient: patient,
      allImports: allImportsForPatient,
      visibleImports: visibleImportsForPatient,
      legacyPrescriptions: prescriptions,
    );

    bool hasExpiringDate(DateTime? date) {
      final info = PrescriptionExpiryUtils.evaluate(date);
      return info.status == PrescriptionValidityStatus.expiringSoon ||
          info.status == PrescriptionValidityStatus.expired;
    }

    final Iterable<DateTime?> expiryCandidates = <DateTime?>[
      if (allImportsForPatient.isNotEmpty)
        ...visibleImportsForPatient.map((DrivePdfImport item) {
          final DateTime baseDate = item.prescriptionDate ?? item.createdAt;
          return baseDate.add(const Duration(days: 30));
        })
      else if (patient.hasLastPrescriptionDateAggregate)
        if (lastPrescriptionDate != null)
          lastPrescriptionDate.add(const Duration(days: 30))
      else
        ...prescriptions.map(
          (Prescription item) =>
              item.expiryDate ?? item.prescriptionDate.add(const Duration(days: 30)),
        ),
    ];

    final bool hasExpiryAlert = expiryCandidates.any(hasExpiringDate);
    String familyId = '';
    String familyName = '';
    for (final FamilyGroup family in families) {
      final bool isMember = family.memberFiscalCodes
          .map((String e) => e.trim().toUpperCase())
          .contains(normalizedFiscalCode);
      if (isMember) {
        familyId = family.id;
        familyName = family.name.trim();
        break;
      }
    }
    return _PatientDashboardSummary(
      patient: patient,
      doctorName: doctorName.isEmpty ? '-' : doctorName,
      exemptionCode: exemptionCode.isEmpty ? '-' : exemptionCode,
      city: city.isEmpty ? '-' : city,
      prescriptions: prescriptions,
      imports: visibleImportsForPatient,
      debts: debts,
      advances: advances,
      bookings: bookings,
      hasDpc: hasDpc,
      recipeCount: recipeCount,
      hasExpiryAlert: hasExpiryAlert,
      familyId: familyId,
      familyName: familyName,
    );
  }
}

class _FlagItem {
  final String title;
  final String subtitle;
  final Future<void> Function()? onDelete;

  const _FlagItem({required this.title, required this.subtitle, this.onDelete});
}

String _dashboardPrescriptionTitle(Prescription prescription) {
  final label = prescription.items.map((e) => e.drugName.trim()).where((e) => e.isNotEmpty).join(', ');
  return label.isEmpty ? 'Ricetta' : label;
}

String _dashboardFormatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}



class _DashboardFamilyState {
  final Map<String, int> activeCounts;
  final Map<String, Color> colors;

  const _DashboardFamilyState({required this.activeCounts, required this.colors});

  factory _DashboardFamilyState.empty() => const _DashboardFamilyState(activeCounts: <String, int>{}, colors: <String, Color>{});

  factory _DashboardFamilyState.fromFamilies(List<_PatientDashboardSummary> summaries, List<FamilyGroup> families) {
    final counts = <String, int>{};
    final colors = <String, Color>{};
    for (final family in families) {
      final activeCount = summaries.where((item) => item.familyId == family.id && item.hasActiveContent).length;
      counts[family.id] = activeCount;
      colors[family.id] = FamilyGroupColorUtils.colorForIndex(family.colorIndex);
    }
    return _DashboardFamilyState(activeCounts: counts, colors: colors);
  }

  bool hasMultipleActive(String familyId) => (activeCounts[familyId] ?? 0) > 1;

  Color colorFor(String familyId) => colors[familyId] ?? AppColors.yellow;
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DashboardCardFilter { ricette, dpc, debiti, anticipi, prenotazioni, scadenze }

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(label),
      labelStyle: TextStyle(color: value ? Colors.black : Colors.white),
      selectedColor: AppColors.yellow,
      backgroundColor: AppColors.panel,
      side: const BorderSide(color: Colors.white10),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FlagChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
      ),
    );
  }
}

class _QuickEditFlag extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickEditFlag({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Apri gestione',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF7A7A7A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

const TextStyle _headStyle = TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15);
