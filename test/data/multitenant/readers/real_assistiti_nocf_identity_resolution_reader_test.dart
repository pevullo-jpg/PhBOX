import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_nocf_identity_resolution_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfIdentityResolutionReader', () {
    test('uses bounded default max pending items and compatible pending signals', () {
      expect(RealAssistitiNoCfIdentityResolutionReader.defaultMaxPendingItems, 20);
      expect(RealAssistitiNoCfIdentityResolutionReader.pendingStatus, 'pending_manual');
      expect(
        RealAssistitiNoCfIdentityResolutionReader.pendingStatusFields,
        const <String>[
          'identityResolutionStatus',
          'identityResolution.status',
        ],
      );
      expect(
        RealAssistitiNoCfIdentityResolutionReader.pendingConfidenceFields,
        const <String>[
          'nameSplitConfidence',
        ],
      );
      expect(
        RealAssistitiNoCfIdentityResolutionReader.pendingConfidence,
        'pending_manual_nocf_identity_resolution',
      );
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

    test('keeps nested pending status visible in root keys metadata', () {
      final RealAssistitiNoCfIdentityResolutionPendingItem item =
          RealAssistitiNoCfIdentityResolutionReader.fromRawData(
        tenantId: 'tenant_a',
        documentId: 'pending-document-id',
        rawData: const <String, dynamic>{
          'identityAnchor': 'NOCF_0123456789ABCDEF',
          'fullName': 'Andrea Franco',
          'identityResolution': <String, dynamic>{
            'status': 'pending_manual',
            'candidateSplits': <Map<String, String>>[
              <String, String>{'nome': 'Andrea', 'cognome': 'Franco'},
            ],
          },
        },
      );

      expect(item.assistitoId, 'pending-document-id');
      expect(item.candidateSplits, <Map<String, String>>[
        <String, String>{'nome': 'Andrea', 'cognome': 'Franco'},
      ]);
      expect(item.rawDataRootKeys.contains('identityResolution'), isTrue);
    });

    test('keeps confidence-only pending signal visible in root keys metadata', () {
      final RealAssistitiNoCfIdentityResolutionPendingItem item =
          RealAssistitiNoCfIdentityResolutionReader.fromRawData(
        tenantId: 'tenant_a',
        documentId: 'confidence-only-document-id',
        rawData: const <String, dynamic>{
          'identityAnchor': 'NOCF_0123456789ABCDEF',
          'fullName': 'Andrea Franco',
          'nome': '',
          'cognome': '',
          'nameSplitConfidence': 'pending_manual_nocf_identity_resolution',
        },
      );

      expect(item.assistitoId, 'confidence-only-document-id');
      expect(item.nome, '');
      expect(item.cognome, '');
      expect(item.fullName, 'Andrea Franco');
      expect(item.rawDataRootKeys.contains('nameSplitConfidence'), isTrue);
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
