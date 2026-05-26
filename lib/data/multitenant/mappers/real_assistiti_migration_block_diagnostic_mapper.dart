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
  static const String statusCopyable = 'copyable';
  static const String statusAlreadyTarget = 'already_target';
  static const String statusBlocked = 'blocked';

  static const String severityInfo = 'info';
  static const String severityBlocking = 'blocking';
  static const String severityWarning = 'warning';

  const RealAssistitiMigrationBlockDiagnosticMapper._();

  static List<RealAssistitiMigrationBlockDiagnostic> buildDiagnostics({
    required String status,
    required Iterable<String> blockingReasons,
  }) {
    if (status == statusCopyable) {
      return const <RealAssistitiMigrationBlockDiagnostic>[];
    }

    if (status == statusAlreadyTarget) {
      return const <RealAssistitiMigrationBlockDiagnostic>[
        RealAssistitiMigrationBlockDiagnostic(
          code: 'already_target',
          sourceCode: 'target_cf_duplicate',
          severity: severityInfo,
          title: 'Assistito già presente nel target',
          explanation:
              'Il CF risulta già presente nella raccolta target assistiti. Non è un errore di migrazione: il record non deve essere ricopiato.',
          recommendedAction:
              'Verificare il record target esistente solo se l’operatore sospetta una copia errata o incompleta.',
          operatorActionRequired: false,
        ),
      ];
    }

    if (status != statusBlocked) {
      return <RealAssistitiMigrationBlockDiagnostic>[
        _unknownStatusDiagnostic(status),
      ];
    }

    final List<String> normalizedReasons = blockingReasons
        .map((String reason) => reason.trim())
        .where((String reason) => reason.isNotEmpty)
        .toList(growable: false);

    if (normalizedReasons.isEmpty) {
      return const <RealAssistitiMigrationBlockDiagnostic>[
        RealAssistitiMigrationBlockDiagnostic(
          code: 'blocked_without_reason',
          sourceCode: '',
          severity: severityBlocking,
          title: 'Blocco senza motivo tecnico',
          explanation:
              'Il CF risulta bloccato ma non contiene un motivo tecnico esplicito nel dry-run.',
          recommendedAction:
              'Non forzare la copia. Eseguire diagnosi tecnica sul dry-run prima di procedere.',
          operatorActionRequired: true,
        ),
      ];
    }

    final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
        <RealAssistitiMigrationBlockDiagnostic>[];
    for (final String reason in normalizedReasons) {
      diagnostics.add(_diagnosticForBlockingReason(reason));
    }
    return List<RealAssistitiMigrationBlockDiagnostic>.unmodifiable(diagnostics);
  }

  static RealAssistitiMigrationBlockDiagnostic _diagnosticForBlockingReason(String reason) {
    switch (reason) {
      case 'legacy_source_missing':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'legacy_source_missing',
          sourceCode: 'legacy_source_missing',
          severity: severityBlocking,
          title: 'Sorgente legacy mancante',
          explanation:
              'Il CF non è stato trovato in nessuna delle sorgenti legacy lette dal flusso bounded.',
          recommendedAction:
              'Verificare il CF inserito. Se corretto, l’assistito non è candidabile alla copia automatica in Migration 1.',
          operatorActionRequired: true,
        );
      case 'target_identity_absent':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_identity_absent',
          sourceCode: 'target_identity_absent',
          severity: severityBlocking,
          title: 'Identità assistito assente',
          explanation:
              'Il dry-run non ha trovato alcun anchor valido fra CF, nome, cognome o fullName normalizzato.',
          recommendedAction:
              'Non forzare la copia. Correggere o completare la sorgente legacy prima di ripetere il dry-run.',
          operatorActionRequired: true,
        );
      case 'target_duplicate_guard_missing_result':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_duplicate_guard_missing_result',
          sourceCode: 'target_duplicate_guard_missing_result',
          severity: severityBlocking,
          title: 'Esito duplicate guard mancante',
          explanation:
              'Il controllo duplicati target non ha restituito un esito per il CF richiesto.',
          recommendedAction:
              'Bloccare la copia e rieseguire l’audit. Se il problema persiste, verificare il reader target duplicate guard.',
          operatorActionRequired: true,
        );
      case 'target_cf_duplicate':
        return const RealAssistitiMigrationBlockDiagnostic(
          code: 'target_cf_duplicate_blocking',
          sourceCode: 'target_cf_duplicate',
          severity: severityBlocking,
          title: 'Duplicato target bloccante',
          explanation:
              'Il CF è già presente nel target ma non è stato classificato come already_target dal riepilogo audit.',
          recommendedAction:
              'Non ricopiare il CF. Verificare coerenza fra status audit e duplicate guard.',
          operatorActionRequired: true,
        );
      default:
        return RealAssistitiMigrationBlockDiagnostic(
          code: 'unknown_blocking_reason',
          sourceCode: reason,
          severity: severityWarning,
          title: 'Motivo di blocco non mappato',
          explanation:
              'Il dry-run ha restituito un motivo di blocco non ancora tradotto dalla diagnostica Migration 1.',
          recommendedAction:
              'Non forzare la copia. Aggiungere una mappatura diagnostica esplicita prima di procedere.',
          operatorActionRequired: true,
        );
    }
  }

  static RealAssistitiMigrationBlockDiagnostic _unknownStatusDiagnostic(String status) {
    return RealAssistitiMigrationBlockDiagnostic(
      code: 'unknown_audit_status',
      sourceCode: status,
      severity: severityWarning,
      title: 'Stato audit non mappato',
      explanation:
          'L’audit ha prodotto uno status non riconosciuto dalla diagnostica Migration 1.',
      recommendedAction:
          'Non usare questo risultato per decidere copie. Correggere lo status mapping prima di procedere.',
      operatorActionRequired: true,
    );
  }
}
