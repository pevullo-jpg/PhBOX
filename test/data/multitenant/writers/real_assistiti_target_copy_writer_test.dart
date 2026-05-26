import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_target_copy_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiTargetCopyWriter small batch gate', () {
    test('limits controlled real copy batches to five assistiti and ten writes', () {
      expect(RealAssistitiTargetCopyWriter.maxDocumentsPerRun, 5);
      expect(RealAssistitiTargetCopyWriter.writesPerDocument, 2);
      expect(RealAssistitiTargetCopyWriter.maxFirestoreWritesPerRun, 10);
    });

    test('builds manual confirmation token for a five-CF batch', () {
      final String token = RealAssistitiTargetCopyWriter.buildRequiredManualConfirmationToken(
        tenantId: 'tenant_a',
        normalizedFiscalCodes: const <String>[
          'CRPGNN48B19D514Z',
          'VLLGPP84H27A089I',
          'RSSMRA80A01H501U',
          'BNCLGU70A01H501X',
          'VRDLGI80A01H501Y',
        ],
      );

      expect(
        token,
        'COPIA_REALE_ASSISTITI_TARGET:tenant_a:'
        'CRPGNN48B19D514Z,VLLGPP84H27A089I,RSSMRA80A01H501U,'
        'BNCLGU70A01H501X,VRDLGI80A01H501Y',
      );
    });

    test('rejects manual confirmation token generation for batches above five CF', () {
      expect(
        () => RealAssistitiTargetCopyWriter.buildRequiredManualConfirmationToken(
          tenantId: 'tenant_a',
          normalizedFiscalCodes: const <String>[
            'CRPGNN48B19D514Z',
            'VLLGPP84H27A089I',
            'RSSMRA80A01H501U',
            'BNCLGU70A01H501X',
            'VRDLGI80A01H501Y',
            'RSSMRA81A01H501Z',
          ],
        ),
        throwsA(isA<RealAssistitiTargetCopyRejectedException>()),
      );
    });
  });
}
