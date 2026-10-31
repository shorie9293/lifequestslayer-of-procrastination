/// 端末内クラッシュログの1件分（純粋モデル）。
///
/// 設計方針（適3: エラー境界）:
/// - 個人情報を全文書かない。message は先頭200字、stack は先頭10フレームのみ保持する。
/// - JSONL 1行1件で保存できるよう toJson / fromJson を持つ。
/// - fromJson は破損行に対して null を返す（読み飛ばしの責務はリポジトリ側）。
/// - 値等価（== / hashCode）で試練から比較できる。
class CrashLogEntry {
  /// message の最大文字数（先頭のみ保持）。
  static const int maxMessageLength = 200;

  /// stack の最大フレーム数（先頭のみ保持）。
  static const int maxStackFrames = 10;

  final DateTime timestamp;

  /// 捕捉経路。'uncaught' / 'zone' / 'flutter' / 'platform' / 'widget-build' など。
  final String kind;

  /// 例外の要約（先頭 [maxMessageLength] 字）。
  final String message;

  /// スタックの先頭 [maxStackFrames] フレーム（無ければ null）。
  final String? stackTop;

  CrashLogEntry({
    required this.timestamp,
    required this.kind,
    required String message,
    String? stackTop,
  })  : message = _clampText(message, maxMessageLength),
        stackTop = stackTop == null ? null : _clampStack(stackTop);

  factory CrashLogEntry.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['ts'];
    final rawKind = json['kind'];
    final rawMessage = json['msg'];
    if (rawTimestamp is! String ||
        rawKind is! String ||
        rawMessage is! String) {
      throw const FormatException('crash log entry is malformed');
    }
    final timestamp = DateTime.tryParse(rawTimestamp);
    if (timestamp == null) {
      throw const FormatException('crash log timestamp is malformed');
    }
    final rawStack = json['stack'];
    return CrashLogEntry(
      timestamp: timestamp,
      kind: rawKind,
      message: rawMessage,
      stackTop: rawStack is String && rawStack.isNotEmpty ? rawStack : null,
    );
  }

  /// 破損時に例外を投げず null を返す安全版。
  static CrashLogEntry? tryParse(Map<String, dynamic> json) {
    try {
      return CrashLogEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'kind': kind,
        'msg': message,
        if (stackTop != null) 'stack': stackTop,
      };

  /// 例外から生成する（stack は [StackTrace.toString] の先頭フレームのみ）。
  factory CrashLogEntry.fromError(
    Object error,
    StackTrace? stack, {
    required DateTime timestamp,
    String kind = 'uncaught',
  }) {
    return CrashLogEntry(
      timestamp: timestamp,
      kind: kind,
      message: error.toString(),
      stackTop: stack?.toString(),
    );
  }

  static String _clampText(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  /// 先頭 [maxStackFrames] 行（= フレーム）のみ残す。
  static String _clampStack(String value) {
    final lines = value.split('\n');
    if (lines.length <= maxStackFrames) return value;
    return lines.take(maxStackFrames).join('\n');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashLogEntry &&
          other.timestamp == timestamp &&
          other.kind == kind &&
          other.message == message &&
          other.stackTop == stackTop;

  @override
  int get hashCode => Object.hash(timestamp, kind, message, stackTop);

  @override
  String toString() => 'CrashLogEntry($kind, $timestamp, $message)';
}
