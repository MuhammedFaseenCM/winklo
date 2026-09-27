/// Payload for automatic client error telemetry (`client_errors` collection).
class ClientErrorReport {
  const ClientErrorReport({
    required this.severity,
    required this.source,
    required this.code,
    required this.message,
    this.cause,
    this.stack,
    this.screen,
    this.function,
    this.uid,
  });

  /// `error` or `fatal`.
  final String severity;

  /// `handled` | `flutter` | `platform` | `bloc`.
  final String source;

  final String code;
  final String message;
  final String? cause;
  final String? stack;
  final String? screen;
  final String? function;
  final String? uid;
}
