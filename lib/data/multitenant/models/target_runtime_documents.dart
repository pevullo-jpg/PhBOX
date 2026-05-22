class TargetPhboxRuntime {
  final String status;
  final int pendingWorkCount;
  final DateTime? lastChangedAt;
  final DateTime? lastRunAt;
  final DateTime? lastIdleExitAt;
  final int sourceVersion;

  const TargetPhboxRuntime({
    required this.status,
    required this.pendingWorkCount,
    required this.lastChangedAt,
    required this.lastRunAt,
    required this.lastIdleExitAt,
    required this.sourceVersion,
  });

  factory TargetPhboxRuntime.empty() {
    return const TargetPhboxRuntime(
      status: 'idle',
      pendingWorkCount: 0,
      lastChangedAt: null,
      lastRunAt: null,
      lastIdleExitAt: null,
      sourceVersion: 0,
    );
  }

  factory TargetPhboxRuntime.fromMap(Map<String, dynamic> map) {
    return TargetPhboxRuntime(
      status: _readString(map['status'], fallback: 'idle'),
      pendingWorkCount: _readInt(map['pendingWorkCount']),
      lastChangedAt: _readDate(map['lastChangedAt']),
      lastRunAt: _readDate(map['lastRunAt']),
      lastIdleExitAt: _readDate(map['lastIdleExitAt']),
      sourceVersion: _readInt(map['sourceVersion']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'status': status,
      'pendingWorkCount': pendingWorkCount,
      'lastChangedAt': lastChangedAt,
      'lastRunAt': lastRunAt,
      'lastIdleExitAt': lastIdleExitAt,
      'sourceVersion': sourceVersion,
    };
  }
}

class TargetPhboxSignal {
  final String signalId;
  final String kind;
  final String status;
  final DateTime? createdAt;
  final DateTime? handledAt;
  final Map<String, dynamic> payload;

  const TargetPhboxSignal({
    required this.signalId,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.handledAt,
    required this.payload,
  });

  factory TargetPhboxSignal.fromMap({
    required String signalId,
    required Map<String, dynamic> map,
  }) {
    return TargetPhboxSignal(
      signalId: signalId.trim(),
      kind: _readString(map['kind'], fallback: ''),
      status: _readString(map['status'], fallback: ''),
      createdAt: _readDate(map['createdAt']),
      handledAt: _readDate(map['handledAt']),
      payload: _readMap(map['payload']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kind': kind,
      'status': status,
      'createdAt': createdAt,
      'handledAt': handledAt,
      'payload': payload,
    };
  }
}

String _readString(Object? value, {required String fallback}) {
  final String trimmed = value?.toString().trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item)),
    );
  }
  return const <String, dynamic>{};
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value.trim());
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    final dynamic date = (value as dynamic).toDate();
    if (date is DateTime) return date;
  } catch (_) {}
  return null;
}
