import '../domain/quiet_hours_service.dart';
import '../domain/quiet_hours_settings.dart';

/// 静穏時間設定の永続化インターフェース。
abstract class QuietHoursRepository {
  Future<QuietHoursSettings> load();
  Future<void> save(QuietHoursSettings settings);
}

/// 試練用のメモリ内リポジトリ。初期値を注入でき、呼び出し回数を観測できる。
class InMemoryQuietHoursRepository implements QuietHoursRepository {
  InMemoryQuietHoursRepository([QuietHoursSettings? initial])
      : _settings = initial ?? QuietHoursSettings.defaults();

  QuietHoursSettings _settings;

  int loadCount = 0;
  int saveCount = 0;

  QuietHoursSettings get current => _settings;

  @override
  Future<QuietHoursSettings> load() async {
    loadCount++;
    return _settings;
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    saveCount++;
    _settings = settings;
  }
}

/// 何も永続化しない実装。常に defaults を返し、保存は捨てる。
class NoopQuietHoursRepository implements QuietHoursRepository {
  @override
  Future<QuietHoursSettings> load() async => QuietHoursSettings.defaults();

  @override
  Future<void> save(QuietHoursSettings settings) async {}
}

/// リポジトリの設定を [QuietHoursGuard] として使う実装。
class QuietHoursRepositoryGuard implements QuietHoursGuard {
  QuietHoursRepositoryGuard(this._repository);

  final QuietHoursRepository _repository;

  @override
  Future<DateTime?> adjust(DateTime scheduled) async {
    final settings = await _repository.load();
    return QuietHoursService.resolveDelivery(settings, scheduled);
  }
}
