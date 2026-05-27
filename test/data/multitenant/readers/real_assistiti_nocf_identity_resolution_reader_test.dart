import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_nocf_identity_resolution_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfIdentityResolutionReader', () {
    test('uses bounded default max pending items', () {
      expect(RealAssistitiNoCfIdentityResolutionReader.defaultMaxPendingItems, 20);
      expect(RealAssistitiNoCfIdentityResolutionReader.pendingStatus, 'pending_manual');
    });

    test('sanitizes candidate splits without leaking malformed entries', () {
      final List<Map<String, String>> splits =
          RealAssistitiNoCfIdentityResolutionReader.sanitizeCandidateSplits(<Object?>[
        <String, dynamic>{'nome': 'Sofia', 'cognome': 'Castelli'},
        <String, dynamic>{'nome': 'Andrea', 'cognome': ''},
        'invalid',
        <String, dynamic>{'nome': 'Franco', 'cognome': 'Andrea'},
      ]);

      expect(splits, <Map<String, String>>[
        <String, String>{'nome': 'Sofia', 'cognome': 'Castelli'},
        <String, String>{'nome': 'Franco', 'cognome': 'Andrea'},
      ]);
    });

    test('uses queried document id as operational write id', () {
      final RealAssistitiNoCfIdentityResolutionPendingItem item =
          RealAssistitiNoCfIdentityResolutionReader.fromRawData(
        tenantId: 'tenant_a',
        documentId: 'real-document-id',
        rawData: const <String, dynamic>{
          'assistitoId': 'stale-payload-id',
          'identityAnchor': 'NOCF_0123456789ABCDEF',
          'fullName': 'Andrea Franco',
          'identityResolutionStatus': 'pending_manual',
        },
      );

      expect(item.assistitoId, 'real-document-id');
      expect(item.payloadAssistitoId, 'stale-payload-id');
      expect(item.documentPath, 'tenants/tenant_a/assistiti/real-document-id');

      final Map<String, dynamic> mapped = item.toMap();
      expect(mapped['assistitoId'], 'real-document-id');
      expect(mapped['payloadAssistitoId'], 'stale-payload-id');
    });

    test('pending item map is redacted to root keys and candidate splits', () {
      const RealAssistitiNoCfIdentityResolutionPendingItem item =
          RealAssistitiNoCfIdentityResolutionPendingItem(
        assistitoId: 'assistito-1',
        payloadAssistitoId: 'payload-assistito-1',
        documentPath: 'tenants/tenant_a/assistiti/assistito-1',
        identityAnchor: 'NOCF_0123456789ABCDEF',
        fullName: 'Andrea Franco',
        nome: '',
        cognome: '',
        candidateSplits: <Map<String, String>>[
          <String, String>{'nome': 'Andrea', 'cognome': 'Franco'},
        ],
        rawDataRootKeys: <String>[
          'assistitoId',
          'identityAnchor',
          'identityResolutionStatus',
        ],
      );

      final Map<String, dynamic> mapped = item.toMap();

      expect(mapped['assistitoId'], 'assistito-1');
      expect(mapped['payloadAssistitoId'], 'payload-assistito-1');
      expect(mapped['identityAnchor'], 'NOCF_0123456789ABCDEF');
      expect(mapped.toString().contains('rawData'), isFalse);
      expect(mapped.toString().contains('targetPayload'), isFalse);
    });
  });
}
