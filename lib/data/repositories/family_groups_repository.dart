import '../../core/constants/app_constants.dart';
import '../../core/utils/patient_input_normalizer.dart';
import '../datasources/firestore_datasource.dart';
import '../models/family_group.dart';

class FamilyGroupsRepository {
  final FirestoreDatasource datasource;

  const FamilyGroupsRepository({required this.datasource});

  Future<List<FamilyGroup>> getAllFamilies() async {
    final maps = await datasource.getCollection(
      collectionPath: AppCollections.families,
      orderBy: 'name',
    );
    return maps
        .map(FamilyGroup.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<FamilyGroup?> getFamilyById(String id) async {
    final String normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    final map = await datasource.getDocument(
      collectionPath: AppCollections.families,
      documentId: normalizedId,
    );
    if (map == null) {
      return null;
    }
    return FamilyGroup.fromMap(map);
  }

  Future<FamilyGroup?> findFamilyByMemberFiscalCode(String fiscalCode) async {
    final String normalizedFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(fiscalCode);
    if (normalizedFiscalCode.isEmpty) {
      return null;
    }
    final List<FamilyGroup> families = await getAllFamilies();
    for (final FamilyGroup family in families) {
      final bool containsPatient = family.memberFiscalCodes.any(
        (String item) =>
            PatientInputNormalizer.normalizeFiscalCode(item) ==
            normalizedFiscalCode,
      );
      if (containsPatient) {
        return family;
      }
    }
    return null;
  }

  Future<void> saveFamily(FamilyGroup family) {
    return datasource.setDocument(
      collectionPath: AppCollections.families,
      documentId: family.id,
      data: family.toMap(),
    );
  }

  Future<FamilyGroup> createFamily({
    required String name,
    required Iterable<String> memberFiscalCodes,
  }) async {
    final String normalizedName = name.trim();
    final List<String> normalizedMembers =
        _normalizeMemberCodes(memberFiscalCodes);
    if (normalizedName.isEmpty) {
      throw const FamilyMutationException('Inserisci il nome del nucleo.');
    }
    if (normalizedMembers.isEmpty) {
      throw const FamilyMutationException(
        'Inserisci almeno un assistito nel nucleo.',
      );
    }

    await _ensureMembersAreNotAlreadyBound(
      candidateMemberFiscalCodes: normalizedMembers,
      targetFamilyId: null,
    );

    final DateTime now = DateTime.now();
    final FamilyGroup family = FamilyGroup(
      id: 'family_${now.millisecondsSinceEpoch}',
      name: normalizedName,
      memberFiscalCodes: normalizedMembers,
      colorIndex:
          ((now.millisecondsSinceEpoch ~/ 1000) % _paletteLengthForRotation),
      createdAt: now,
      updatedAt: now,
    );
    await saveFamily(family);
    return family;
  }

  Future<FamilyGroup> addMembersToFamily({
    required String familyId,
    required Iterable<String> memberFiscalCodes,
  }) async {
    final FamilyGroup? currentFamily = await getFamilyById(familyId);
    if (currentFamily == null) {
      throw const FamilyMutationException('Famiglia non trovata.');
    }
    final List<String> normalizedIncoming =
        _normalizeMemberCodes(memberFiscalCodes);
    if (normalizedIncoming.isEmpty) {
      throw const FamilyMutationException(
        'Seleziona almeno un assistito da aggiungere.',
      );
    }

    await _ensureMembersAreNotAlreadyBound(
      candidateMemberFiscalCodes: normalizedIncoming,
      targetFamilyId: currentFamily.id,
    );

    final Set<String> nextMembers = currentFamily.memberFiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toSet()
      ..addAll(normalizedIncoming);

    final FamilyGroup nextFamily = currentFamily.copyWith(
      memberFiscalCodes: nextMembers.toList()..sort(),
      updatedAt: DateTime.now(),
    );
    await saveFamily(nextFamily);
    return nextFamily;
  }

  Future<FamilyRemovalResult> removeMemberFromFamily({
    required String familyId,
    required String memberFiscalCode,
  }) async {
    final FamilyGroup? currentFamily = await getFamilyById(familyId);
    if (currentFamily == null) {
      throw const FamilyMutationException('Famiglia non trovata.');
    }
    final String normalizedFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(memberFiscalCode);
    if (normalizedFiscalCode.isEmpty) {
      throw const FamilyMutationException('Assistito non valido.');
    }

    final List<String> currentMembers = currentFamily.memberFiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toList();
    if (!currentMembers.contains(normalizedFiscalCode)) {
      return FamilyRemovalResult(
        family: currentFamily,
        deletedFamily: false,
      );
    }

    final List<String> nextMembers = currentMembers
        .where((String item) => item != normalizedFiscalCode)
        .toSet()
        .toList()
      ..sort();

    if (nextMembers.isEmpty) {
      await deleteFamily(currentFamily.id);
      return const FamilyRemovalResult(
        family: null,
        deletedFamily: true,
      );
    }

    final FamilyGroup nextFamily = currentFamily.copyWith(
      memberFiscalCodes: nextMembers,
      updatedAt: DateTime.now(),
    );
    await saveFamily(nextFamily);
    return FamilyRemovalResult(
      family: nextFamily,
      deletedFamily: false,
    );
  }

  Future<void> deleteFamily(String id) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.families,
      documentId: id,
    );
  }

  Future<void> _ensureMembersAreNotAlreadyBound({
    required Iterable<String> candidateMemberFiscalCodes,
    required String? targetFamilyId,
  }) async {
    final List<String> normalizedCandidates =
        _normalizeMemberCodes(candidateMemberFiscalCodes);
    if (normalizedCandidates.isEmpty) {
      return;
    }

    final List<FamilyGroup> families = await getAllFamilies();
    for (final String candidate in normalizedCandidates) {
      for (final FamilyGroup family in families) {
        if (targetFamilyId != null && family.id == targetFamilyId) {
          continue;
        }
        final bool alreadyBound = family.memberFiscalCodes.any(
          (String item) =>
              PatientInputNormalizer.normalizeFiscalCode(item) == candidate,
        );
        if (alreadyBound) {
          final String label = family.name.trim().isNotEmpty
              ? family.name.trim()
              : family.id.trim();
          throw FamilyMutationException(
            'L\'assistito $candidate appartiene già al nucleo $label.',
          );
        }
      }
    }
  }

  List<String> _normalizeMemberCodes(Iterable<String> memberFiscalCodes) {
    return memberFiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static const int _paletteLengthForRotation = 8;
}

class FamilyRemovalResult {
  final FamilyGroup? family;
  final bool deletedFamily;

  const FamilyRemovalResult({
    required this.family,
    required this.deletedFamily,
  });
}

class FamilyMutationException implements Exception {
  final String message;

  const FamilyMutationException(this.message);

  @override
  String toString() => message;
}
