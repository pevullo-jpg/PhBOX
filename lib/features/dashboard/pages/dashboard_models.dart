part of 'dashboard_page.dart';

class _DashboardData {
  final List<_PatientDashboardSummary> summaries;
  final List<FamilyGroup> families;

  const _DashboardData({
    required this.summaries,
    required this.families,
  });
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
  });

  String get displayName => patient.fullName.trim().isEmpty ? patient.fiscalCode : patient.fullName.trim();

  double get totalDebt => debts.fold<double>(0, (sum, item) => sum + item.residualAmount);

  String get doctorNameUpper => doctorName.trim().isEmpty ? '-' : doctorName.trim().toUpperCase();
  String get doctorSurnameUpper {
    final String cleaned = doctorName.trim();
    if (cleaned.isEmpty || cleaned == '-') return '-';
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return (parts.isEmpty ? cleaned : parts.first).toUpperCase();
  }

  bool get hasActiveContent => recipeCount > 0 || hasDpc || debts.isNotEmpty || advances.isNotEmpty || bookings.isNotEmpty;

  List<_FlagItem> get dpcItems {
    final fromImports = <_FlagItem>[];
    for (final importItem in imports) {
      final dpcEntries = importItem.resolvedDpcEntries;
      for (final entry in dpcEntries) {
        fromImports.add(
          _FlagItem(
            title: _dashboardDpcEntryTitle(entry, fallbackFileName: importItem.fileName),
            subtitle: _dashboardDpcEntrySubtitle(entry, fallbackDate: importItem.prescriptionDate ?? importItem.createdAt, fallbackDoctor: importItem.doctorFullName),
          ),
        );
      }
    }
    if (fromImports.isNotEmpty) {
      return fromImports;
    }
    return prescriptions.where((item) => item.dpcFlag).map((item) {
      return _FlagItem(
        title: _dashboardPrescriptionTitle(item),
        subtitle: '${_dashboardFormatDate(item.prescriptionDate)} · ${(item.doctorName ?? '-').trim().isEmpty ? '-' : item.doctorName!.trim()}',
      );
    }).toList();
  }

  static _PatientDashboardSummary build({
    required Patient patient,
    required List<Prescription> prescriptions,
    required List<DrivePdfImport> imports,
    required List<Debt> debts,
    required List<Advance> advances,
    required List<Booking> bookings,
    required List<DoctorPatientLink> doctorLinks,
    required String familyId,
  }) {
    final prescriptionDoctor = prescriptions.map((e) => e.doctorName?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final importDoctor = imports.map((e) => e.doctorFullName.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final linkDoctorFull = doctorLinks.map((e) => e.doctorFullName.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final patientDoctor = (patient.doctorName ?? '').trim();
    final doctorName = linkDoctorFull.isNotEmpty
        ? linkDoctorFull
        : (patientDoctor.isNotEmpty
            ? patientDoctor
            : (importDoctor.isNotEmpty ? importDoctor : prescriptionDoctor));
    final exemptionCode = (patient.exemptionCode ?? '').trim().isNotEmpty
        ? patient.exemptionCode!.trim()
        : (() {
            final fromPrescription = prescriptions.map((e) => e.exemptionCode?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
            if (fromPrescription.isNotEmpty) return fromPrescription;
            return imports.map((e) => e.exemptionCode.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '-');
          })();
    final city = (patient.city ?? '').trim().isNotEmpty
        ? patient.city!.trim()
        : (() {
            final fromPrescription = prescriptions.map((e) => e.city?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
            if (fromPrescription.isNotEmpty) return fromPrescription;
            return imports.map((e) => e.city.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '-');
          })();
    final int importsRecipeCount = imports.fold<int>(0, (sum, item) => sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1));
    final int prescriptionsRecipeCount = prescriptions.fold<int>(0, (sum, item) => sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1));
    final int patientRecipeCount = patient.archivedRecipeCount > 0 ? patient.archivedRecipeCount : 0;
    final recipeCount = importsRecipeCount > 0
        ? importsRecipeCount
        : (prescriptionsRecipeCount > 0 ? prescriptionsRecipeCount : (imports.isNotEmpty ? imports.length : patientRecipeCount));
    final hasDpc = prescriptions.any((item) => item.dpcFlag) || imports.any((item) => item.resolvedDpcEntries.isNotEmpty || item.isDpc);
    final hasExpiryAlert = prescriptions.any((item) {
      final info = PrescriptionExpiryUtils.evaluate(item.expiryDate);
      return info.status == PrescriptionValidityStatus.expiringSoon || info.status == PrescriptionValidityStatus.expired;
    });
    return _PatientDashboardSummary(
      patient: patient,
      doctorName: doctorName.isEmpty ? '-' : doctorName,
      exemptionCode: exemptionCode.isEmpty ? '-' : exemptionCode,
      city: city.isEmpty ? '-' : city,
      prescriptions: prescriptions,
      imports: imports,
      debts: debts,
      advances: advances,
      bookings: bookings,
      hasDpc: hasDpc,
      recipeCount: recipeCount,
      hasExpiryAlert: hasExpiryAlert,
      familyId: familyId,
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
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF65A30D),
      Color(0xFFEA580C),
    ];
    final counts = <String, int>{};
    final colors = <String, Color>{};
    for (final family in families) {
      final activeCount = summaries.where((item) => item.familyId == family.id && item.hasActiveContent).length;
      counts[family.id] = activeCount;
      colors[family.id] = palette[family.colorIndex % palette.length];
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
