// 報酬イベントのファイル名 → 発生元現世（world）の対応表の試練。
//
// 対応表は送客先ディープリンク（app://<world>）の正準定義ゆえ、
// 「既知3件の対応」「未知はnull」「共有契約との一致」を固定する。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_world.dart';

void main() {
  group('CrossAppWorld.fromFileName', () {
    test('tsundoku の報酬イベントは tsundoku に対応する', () {
      final world = CrossAppWorld.fromFileName('tsundoku_reward_events.jsonl');
      expect(world, isNotNull);
      expect(world!.id, 'tsundoku');
      expect(world.displayName, 'tsundoku-quest');
    });

    test('election の報酬イベントは election に対応する', () {
      final world = CrossAppWorld.fromFileName('election_reward_events.jsonl');
      expect(world, isNotNull);
      expect(world!.id, 'election');
      expect(world.displayName, 'election-game');
    });

    test('book-review の報酬イベントは book-review に対応する', () {
      final world =
          CrossAppWorld.fromFileName('book_review_reward_events.jsonl');
      expect(world, isNotNull);
      expect(world!.id, 'book-review');
      expect(world.displayName, 'book-review-app');
    });

    test('絶対パスでもファイル名部分で判定する', () {
      final world = CrossAppWorld.fromFileName(
        '/storage/emulated/0/Download/election_reward_events.jsonl',
      );
      expect(world?.id, 'election');
    });

    test('未知のファイル名は null', () {
      expect(CrossAppWorld.fromFileName('unknown_events.jsonl'), isNull);
      expect(CrossAppWorld.fromFileName(''), isNull);
    });
  });

  group('CrossAppWorld の送客URI', () {
    test('正準ディープリンクは app://<world>', () {
      expect(CrossAppWorld.tsundoku.deepLink, 'app://tsundoku');
      expect(CrossAppWorld.election.deepLink, 'app://election');
      expect(CrossAppWorld.bookReview.deepLink, 'app://book-review');
    });

    test('fromId で引ける', () {
      expect(CrossAppWorld.fromId('election')?.displayName, 'election-game');
      expect(CrossAppWorld.fromId('nope'), isNull);
    });

    test('送客ボタンキーはハイフンをアンダースコアに潰す', () {
      expect(CrossAppWorld.bookReview.openButtonKey, 'open_book_review');
    });
  });

  group('共有契約との一致（ドリフト検知）', () {
    test('対応表のファイル名は SharedCrossAppFiles と一致する', () {
      expect(
        CrossAppWorld.tsundoku.eventsFileName,
        SharedCrossAppFiles.tsundokuRewardEvents,
      );
      expect(
        CrossAppWorld.election.eventsFileName,
        SharedCrossAppFiles.electionRewardEvents,
      );
      expect(
        CrossAppWorld.bookReview.eventsFileName,
        SharedCrossAppFiles.bookReviewRewardEvents,
      );
    });
  });
}
