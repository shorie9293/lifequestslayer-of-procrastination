import 'package:flutter/widgets.dart';

import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/infrastructure/auth_service.dart';
import 'package:rpg_todo/features/account_deletion/data/hive_account_deletion_data_eraser.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_service.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_screen.dart';

/// 本番結線: 設定ハブから開く実画面。[SettingsHubScreen] の
/// `accountDeletionScreenBuilder` に渡す唯一の導線。
Widget buildProductionAccountDeletionScreen(BuildContext context) {
  AuthService? auth;
  if (getIt.isRegistered<AuthService>()) {
    try {
      auth = getIt<AuthService>();
    } catch (_) {
      auth = null;
    }
  }

  return AccountDeletionScreen(
    hasActiveSession: auth?.currentUser != null,
    service: AccountDeletionService(
      signOut: () async {
        final service = auth;
        if (service == null) return;
        await service.signOut();
      },
      clearLocalData: const HiveAccountDeletionDataEraser().erase,
    ),
  );
}
