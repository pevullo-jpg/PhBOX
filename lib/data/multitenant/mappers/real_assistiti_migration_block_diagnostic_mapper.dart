class RealAssistitiMigrationBlockDiagnostic {
  final String code;
  final String sourceCode;
  final String severity;
  final String title;
  final String explanation;
  final String recommendedAction;
  final bool operatorActionRequired;

  const RealAssistitiMigrationBlockDiagnostic({
    required this.code,
    required this.sourceCode,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.recommendedAction,
    required this.operatorActionRequired,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'sourceCode': sourceCode,
      'severity': severity,
      'title': title,
      'explanation': explanation,
      'recommendedAction': recommendedAction,
      'operatorActionRequired': operatorActionRequired,
    };
  }
}

class RealAssistitiMigrationBlockDiagnosticMapper {
  const RealAssistitiMigrationBlockDiagnosticMapper._();

  static List<RealAssistitiMigrationBlockDiagnostic> buildItemDiagnostics({
    required String status,
    required bool targetDuplicateFound,
    required List<String> blockingReasons,
  }) {
    if (status == 'copyable') {
      return const <RealAssistitiMigrationBlockDiagnostic>[];
    }

    if (status == 'already_target' || targetDuplicateFound) {
      return const <RealAssistitiMigrationBlockDiagnostic>[
        RealAssistitiMigrationBlockDiagnostic(
          code: 'already_target',
          sourceCode: 'target_cf_duplicate',
          severity: 'info',
          title: 'Assistito già presente nel target',
          explanation:
              'Il codice fiscale risulta già presente nella raccolta target assistiti. Non è un errore di migrazione se il record target è quello atteso.',
          recommendedAction:
              'Non copiare nuovamente. Verificare il record target solo se si sospetta una migrazione errata o un lock non coerente.',
          operatorActionRequired: false,
        ),
      ];
    }

    if (status != 'blocked') {
      return <RealAssistitiMigrationBlockDiagnostic>[
        _unknownStatus(status),
      ];
    }

    if (blockingReasons.isEmpty) {
      return const <RealAssistitiMigrationBlockDiagnostic>[
        RealAssistitiMigrationBlockDiagnostic(
          code: 'unknown_blocked_status',
          sourceCode: 'unknown_blocked_status',
          severity: 'error',
          title: 'Blocco senza motivo tecnico',
          explanation:
              'L’assistito risulta bloccato ma il dry-run non ha restituito un motivo tecnico specifico.',
          recommendedAction:
              'Non forzare la copia. Aprire verifica tecnica sul dry-run prima di procedere.',
          operatorActionRequired: true,
        ),
      ];
    }

    final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
        <RealAssistitiMigrationBlockDiagnostic>[];
    for (final String reason in blockingReasons) {
      diagnostics.add(_fromBlockingReason(reason));
    }
    return List<RealAssistitiMigrationBlockDiagnostic>.unmodifiable(diagnostics);
  }

  static RealAssistitiMigrationBlockDiagnostic _fromBlockingReason(String reason) {
    switch (reason) {
      case 'legacy_source_missing':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'legacy_source_missing',
          sourceCode: 'legacy_source_missing',
          severity: 'error',
          title: 'Sorgente legacy assente',
          explanation:
              'Il codice fiscale non è stato trovato in nessuna delle sorgenti legacy lette dal dry-run.',
          recommendedAction:
              'Verificare che il CF sia corretto. Se il dato non esiste nel legacy, escludere il CF dalla migrazione batch.',
          operatorActionRequired: true,
        );
      case 'target_identity_absent':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_identity_absent',
          sourceCode: 'target_identity_absent',
          severity: 'error',
          title: 'Identità assistito assente',
          explanation:
              'Il dry-run non ha trovato alcun anchor valido per costruire l’assistito target.',
          recommendedAction:
              'Verificare i dati legacy. Serve almeno un CF valido, oppure nome/cognome/fullName validi secondo il contratto Migration 1.',
          operatorActionRequired: true,
        );
      case 'target_duplicate_guard_missing_result':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_duplicate_guard_missing_result',
          sourceCode: 'target_duplicate_guard_missing_result',
          severity: 'error',
          title: 'Esito duplicate guard assente',
          explanation:
              'Il controllo duplicati target non ha restituito un esito per il CF richiesto.',
          recommendedAction:
              'Non procedere con la copia. Ripetere audit/dry-run; se persiste, correggere il duplicate guard.',
          operatorActionRequired: true,
        );
      case 'target_cf_duplicate':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_cf_duplicate',
          sourceCode: 'target_cf_duplicate',
          severity: 'warning',
          title: 'Duplicato target rilevato',
          explanation:
              'Il codice fiscale risulta già associato a un assistito target.',
          recommendedAction:
              'Non copiare nuovamente. Verificare il record target o il lock CF prima di qualsiasi cleanup manuale.',
          operatorActionRequired: true,
        );
      default:
        return RealAssistitiMigrationBlockDiagnostic(
          code: 'unknown_blocking_reason',
          sourceCode: reason,
          severity: 'error',
          title: 'Motivo di blocco non riconosciuto',
          explanation:
              'Il dry-run ha restituito un motivo di blocco non ancora mappato dalla diagnostica leggibile.',
          recommendedAction:
              'Non forzare la copia. Aggiungere una mappatura esplicita per questo motivo prima di procedere.',
          operatorActionRequired: true,
        );
    }
  }

  static RealAssistitiMigrationBlockDiagnostic _unknownStatus(String status) {
    return RealAssistitiMigrationBlockDiagnostic(
      code: 'unknown_status',
      sourceCode: status,
      severity: 'error',
      title: 'Stato audit non riconosciuto',
      explanation:
          'L’audit ha restituito uno stato non previsto dal contratto copyable/already_target/blocked.',
      recommendedAction:
          'Non usare questo risultato per la migrazione. Correggere il mapper audit prima di procedere.',
      operatorActionRequired: true,
    );
  }
}
