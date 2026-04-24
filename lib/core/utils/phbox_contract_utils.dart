import '../../data/models/doctor_patient_link.dart';
import '../../data/models/drive_pdf_import.dart';
import '../../data/models/patient.dart';
import '../../data/models/prescription.dart';
import '../../data/models/prescription_item.dart';

class PhboxContractUtils {
  const PhboxContractUtils._();

  static List<DrivePdfImport> allImportsForPatient({
    required Patient patient,
    required List<DrivePdfImport> imports,
  }) {
    final String normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
    final String normalizedFullName = patient.fullName.trim().toUpperCase();
    final List<DrivePdfImport> matches = imports.where((DrivePdfImport item) {
      final String importFiscalCode = item.patientFiscalCode.trim().toUpperCase();
      final String importFullName = item.patientFullName.trim().toUpperCase();
      if (importFiscalCode.isNotEmpty) {
        return importFiscalCode == normalizedFiscalCode;
      }
      return normalizedFullName.isNotEmpty && importFullName == normalizedFullName;
    }).toList();
    matches.sort((DrivePdfImport a, DrivePdfImport b) {
      return b.chronologyDate.compareTo(a.chronologyDate);
    });
    return matches;
  }

  static List<DrivePdfImport> visibleImportsForPatient({
    required Patient patient,
    required List<DrivePdfImport> imports,
  }) {
    final List<DrivePdfImport> matches = allImportsForPatient(
      patient: patient,
      imports: imports,
    ).where((DrivePdfImport item) {
      return !item.isHiddenFromFrontend;
    }).toList();
    matches.sort((DrivePdfImport a, DrivePdfImport b) {
      return b.chronologyDate.compareTo(a.chronologyDate);
    });
    return matches;
  }

  static String resolveDoctor({
    required String fiscalCode,
    required List<DoctorPatientLink> doctorLinks,
    required String? patientDoctorFullName,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
    final List<DoctorPatientLink> matchingLinks = doctorLinks.where((DoctorPatientLink link) {
      return link.patientFiscalCode == normalizedFiscalCode;
    }).toList();
    matchingLinks.sort((DoctorPatientLink a, DoctorPatientLink b) {
      final int typeOrder = _linkPriority(a.linkType).compareTo(_linkPriority(b.linkType));
      if (typeOrder != 0) {
        return typeOrder;
      }
      final DateTime aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    for (final DoctorPatientLinkType type in const <DoctorPatientLinkType>[
      DoctorPatientLinkType.manual,
      DoctorPatientLinkType.primary,
    ]) {
      for (final DoctorPatientLink link in matchingLinks) {
        if (link.linkType != type) {
          continue;
        }
        final String doctor = link.doctorFullName.trim();
        if (doctor.isNotEmpty) {
          return doctor;
        }
      }
    }

    final String patientDoctor = (patientDoctorFullName ?? '').trim();
    if (patientDoctor.isNotEmpty) {
      return patientDoctor;
    }

    for (final DrivePdfImport item in visibleImports) {
      final String doctor = item.doctorFullName.trim();
      if (doctor.isNotEmpty) {
        return doctor;
      }
    }

    final List<Prescription> sortedLegacy = [...legacyPrescriptions]
      ..sort((Prescription a, Prescription b) {
        return b.prescriptionDate.compareTo(a.prescriptionDate);
      });
    for (final Prescription prescription in sortedLegacy) {
      final String doctor = (prescription.doctorName ?? '').trim();
      if (doctor.isNotEmpty) {
        return doctor;
      }
    }

    return '-';
  }

  static String resolveExemption({
    required Patient patient,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    if (patient.exemptions.isNotEmpty) {
      final String canonical = patient.exemptions.firstWhere(
        (String item) => item.trim().isNotEmpty,
        orElse: () => '',
      );
      if (canonical.isNotEmpty) {
        return canonical;
      }
    }

    final String legacyAlias = (patient.exemptionCode ?? '').trim();
    if (legacyAlias.isNotEmpty) {
      return legacyAlias;
    }

    for (final DrivePdfImport item in visibleImports) {
      final String code = item.exemptionCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }

    final List<Prescription> sortedLegacy = [...legacyPrescriptions]
      ..sort((Prescription a, Prescription b) {
        return b.prescriptionDate.compareTo(a.prescriptionDate);
      });
    for (final Prescription prescription in sortedLegacy) {
      final String code = (prescription.exemptionCode ?? '').trim();
      if (code.isNotEmpty) {
        return code;
      }
    }

    return '-';
  }

  static String resolveCity({
    required Patient patient,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    final String patientCity = (patient.city ?? '').trim();
    if (patientCity.isNotEmpty) {
      return patientCity;
    }

    for (final DrivePdfImport item in visibleImports) {
      final String city = item.city.trim();
      if (city.isNotEmpty) {
        return city;
      }
    }

    final List<Prescription> sortedLegacy = [...legacyPrescriptions]
      ..sort((Prescription a, Prescription b) {
        return b.prescriptionDate.compareTo(a.prescriptionDate);
      });
    for (final Prescription prescription in sortedLegacy) {
      final String city = (prescription.city ?? '').trim();
      if (city.isNotEmpty) {
        return city;
      }
    }

    return '-';
  }

  static int resolveRecipeCount({
    required Patient patient,
    required List<DrivePdfImport> allImports,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    if (allImports.isNotEmpty) {
      return visibleImports.fold<int>(0, (int sum, DrivePdfImport item) {
        return sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1);
      });
    }

    if (patient.hasArchivedRecipeCountAggregate) {
      return patient.archivedRecipeCount;
    }

    return legacyPrescriptions.fold<int>(0, (int sum, Prescription item) {
      return sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1);
    });
  }

  static bool resolveHasDpc({
    required Patient patient,
    required List<DrivePdfImport> allImports,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    if (allImports.isNotEmpty) {
      return visibleImports.any((DrivePdfImport item) => item.isDpc);
    }
    if (patient.hasHasDpcAggregate) {
      return patient.hasDpc;
    }
    return legacyPrescriptions.any((Prescription item) => item.dpcFlag);
  }

  static DateTime? resolveLastPrescriptionDate({
    required Patient patient,
    required List<DrivePdfImport> allImports,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> legacyPrescriptions,
  }) {
    if (allImports.isNotEmpty) {
      DateTime? value;
      for (final DrivePdfImport item in visibleImports) {
        final DateTime candidate = item.prescriptionDate ?? item.createdAt;
        if (value == null || candidate.isAfter(value)) {
          value = candidate;
        }
      }
      return value;
    }

    if (patient.hasLastPrescriptionDateAggregate) {
      return patient.lastPrescriptionDate;
    }

    DateTime? value;
    for (final Prescription item in legacyPrescriptions) {
      if (value == null || item.prescriptionDate.isAfter(value)) {
        value = item.prescriptionDate;
      }
    }
    return value;
  }

  static List<String> resolveTherapiesSummary({
    required Patient patient,
    required List<DrivePdfImport> allImports,
    required List<DrivePdfImport> visibleImports,
    required List<Prescription> prescriptions,
  }) {
    if (allImports.isNotEmpty) {
      final Set<String> importValues = <String>{};
      for (final DrivePdfImport item in visibleImports) {
        for (final String therapy in item.therapy) {
          final String normalized = therapy.trim();
          if (normalized.isNotEmpty) {
            importValues.add(normalized);
          }
        }
      }
      final List<String> result = importValues.toList()..sort();
      return result;
    }

    if (patient.hasTherapiesSummaryAggregate) {
      final Set<String> patientValues = patient.therapiesSummary
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toSet();
      final List<String> result = patientValues.toList()..sort();
      return result;
    }

    final Set<String> values = <String>{};
    for (final Prescription prescription in prescriptions) {
      for (final PrescriptionItem item in prescription.items) {
        final String normalized = item.drugName.trim();
        if (normalized.isNotEmpty) {
          values.add(normalized);
        }
      }
    }
    final List<String> result = values.toList()..sort();
    return result;
  }

  static int _linkPriority(DoctorPatientLinkType type) {
    switch (type) {
      case DoctorPatientLinkType.manual:
        return 0;
      case DoctorPatientLinkType.primary:
        return 1;
      case DoctorPatientLinkType.other:
        return 2;
    }
  }
}
