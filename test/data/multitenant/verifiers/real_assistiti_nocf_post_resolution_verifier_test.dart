import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/verifiers/real_assistiti_nocf_post_resolution_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfPostResolutionVerifier', () {
    test('verifies resolved manual NOCF target, identity lock and cf lock', () {
      final RealAssistitiNoCfPostResolutionVerificationItem item =
          RealAssistitiNoCfPostResolutionVerifier.verifyRawPayloads(
        tenantId: 'tenant_a',
        identityAnchor: _anchor,
        targetExists: true,
        targetData: _targetPayload(),
        identityLockExists: true,
        identityLockData: _lockPayload(),
        cfLockExists: true,
        cfLockData: _lockPayload(),
      );

      expect(item.verified, isTrue);
      expect(item.mismatchReasons, isEmpty);
      expect(item.assistitoId, 'assistito-1');
      expect(item.fullName, 'Fantauzzo Amedeo');
      expect(item.searchPrefixes, RealAssistitiTargetPreviewMapper.buildSearchPrefixes('Fantauzzo Amedeo'));
    });

    test('rejects CF-like contamination in resolved target identity fields', () {
      final RealAssistitiNoCfPostResolutionVerificationItem item =
          RealAssistitiNoCfPostResolutionVerifier.verifyRawPayloads(
        tenantId: 'tenant_a',
        identityAnchor: _anchor,
        targetExists: true,
        targetData: _targetPayload(
          nome: 'Amedeo RSSMRA80A01H501U',
          fullName: 'Fantauzzo Amedeo RSSMRA80A01H501U',
          searchPrefixes: const <String>['fantauzzo', 'fantauzzo amedeo rssmra80a01h501u'],
        ),
        identityLockExists: true,
        identityLockData: _lockPayload(),
        cfLockExists: true,
        cfLockData: _lockPayload(),
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_identity_contains_cf_token'));
      expect(item.mismatchReasons, contains('target_full_name_not_canonical'));
    });

    test('detects lock drift and stale searchPrefixes', () {
      final RealAssistitiNoCfPostResolutionVerificationItem item =
          RealAssistitiNoCfPostResolutionVerifier.verifyRawPayloads(
        tenantId: 'tenant_a',
        identityAnchor: _anchor,
        targetExists: true,
        targetData: _targetPayload(searchPrefixes: const <String>['stale']),
        identityLockExists: true,
        identityLockData: _lockPayload(assistitoId: 'other-assistito'),
        cfLockExists: true,
        cfLockData: _lockPayload(assistitoPath: 'tenants/tenant_a/assistiti/other-assistito'),
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_assistito_id_mismatch'));
      expect(item.mismatchReasons, contains('cf_lock_assistito_path_mismatch'));
      expect(item.mismatchReasons, contains('target_search_prefixes_mismatch'));
    });

    test('allows pending manual state without resolved split but still detects missing locks', () {
      final RealAssistitiNoCfPostResolutionVerificationItem item =
          RealAssistitiNoCfPostResolutionVerifier.verifyRawPayloads(
        tenantId: 'tenant_a',
        identityAnchor: _anchor,
        targetExists: true,
        targetData: _targetPayload(
          nome: '',
          cognome: '',
          fullName: 'Amedeo Fantauzzo',
          identityResolutionStatus: 'pending_manual',
          nameSplitConfidence: 'pending_manual_nocf_identity_resolution',
          identityResolution: const <String, dynamic>{'status': 'pending_manual'},
          searchPrefixes: RealAssistitiTargetPreviewMapper.buildSearchPrefixes('Amedeo Fantauzzo'),
        ),
        identityLockExists: false,
        identityLockData: const <String, dynamic>{},
        cfLockExists: false,
        cfLockData: const <String, dynamic>{},
        assistitoIdOverride: 'assistito-1',
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('identity_lock_missing'));
      expect(item.mismatchReasons, contains('cf_lock_missing'));
      expect(item.mismatchReasons, isNot(contains('target_identity_resolution_state_invalid')));
      expect(item.mismatchReasons, isNot(contains('target_full_name_not_canonical')));
    });

    test('deduplicates bounded canonical identity anchors', () {
      final List<String> anchors = RealAssistitiNoCfPostResolutionVerifier.normalizeIdentityAnchors(
        const <String>[_anchor, _anchor],
      );

      expect(anchors, const <String>[_anchor]);
    });
  });
}

const String _anchor = 'NOCF_1333C7A3C5B35C8B';

Map<String, dynamic> _targetPayload({
  String assistitoId = 'assistito-1',
  String nome = 'Amedeo',
  String cognome = 'Fantauzzo',
  String fullName = 'Fantauzzo Amedeo',
  String identityResolutionStatus = 'resolved_manual',
  String nameSplitConfidence = 'resolved_manual_nocf_identity',
  Map<String, dynamic> identityResolution = const <String, dynamic>{'status': 'resolved_manual'},
  List<String>? searchPrefixes,
}) {
  final List<String> safeSearchPrefixes =
      searchPrefixes ?? RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName);
  return <String, dynamic>{
    'assistitoId': assistitoId,
    'cf': _anchor,
    'identityType': 'nocf',
    'identityAnchor': _anchor,
    'legacyNoCfCode': 'TMP_AMEDEO_FANTAUZZO_1775837672370000',
    'generatedNoCf': false,
    'nome': nome,
    'cognome': cognome,
    'fullName': fullName,
    'searchPrefixes': safeSearchPrefixes,
    'identityResolutionStatus': identityResolutionStatus,
    'identityResolution': identityResolution,
    'nameSplitConfidence': nameSplitConfidence,
  };
}

Map<String, dynamic> _lockPayload({
  String assistitoId = 'assistito-1',
  String assistitoPath = 'tenants/tenant_a/assistiti/assistito-1',
}) {
  return <String, dynamic>{
    'identityAnchor': _anchor,
    'cf': _anchor,
    'identityType': 'nocf',
    'assistitoId': assistitoId,
    'assistitoPath': assistitoPath,
    'legacyNoCfCode': 'TMP_AMEDEO_FANTAUZZO_1775837672370000',
    'lockVersion': 1,
  };
}
