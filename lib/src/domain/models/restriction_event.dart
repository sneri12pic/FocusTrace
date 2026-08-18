enum RestrictionEventType {
  blocked('blocked'),
  unblocked('unblocked');

  const RestrictionEventType(this.wireName);

  final String wireName;

  static RestrictionEventType fromWireName(String? value) {
    return RestrictionEventType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => RestrictionEventType.blocked,
    );
  }
}

class RestrictionEvent {
  const RestrictionEvent({
    required this.id,
    required this.appKey,
    required this.appName,
    required this.type,
    required this.occurredAt,
    this.reason,
  });

  final String id;
  final String appKey;
  final String appName;
  final RestrictionEventType type;
  final DateTime occurredAt;
  final String? reason;
}
