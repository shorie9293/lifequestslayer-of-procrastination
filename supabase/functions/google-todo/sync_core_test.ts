// sync_core の試練（deno test supabase/functions/google-todo/）
import { assertEquals } from 'jsr:@std/assert@1';
import {
  deadlineToGoogleDue,
  googleDueToDeadline,
  planSync,
  type GoogleTask,
  type Link,
  type LocalTask,
} from './sync_core.ts';

function local(over: Partial<LocalTask> = {}): LocalTask {
  return {
    id: 'L1',
    title: 'レポート提出',
    isCompleted: false,
    status: 'active',
    deadline: '2026-11-25T23:59:00.000+09:00',
    updatedAt: '2026-11-20T10:00:00.000Z',
    cancelledAt: null,
    tags: ['GoogleToDo'],
    repeatInterval: 'none',
    ...over,
  };
}

function google(over: Partial<GoogleTask> = {}): GoogleTask {
  return {
    id: 'G1',
    title: 'レポート提出',
    status: 'needsAction',
    due: '2026-11-25T00:00:00.000Z',
    updated: '2026-11-20T10:00:00.000Z',
    deleted: false,
    hidden: false,
    etag: '"etag-1"',
    ...over,
  };
}

const link = (over: Partial<Link> = {}): Link => ({ localId: 'L1', googleTaskId: 'G1', ...over });

Deno.test('期限と due は JST の日付で往復する', () => {
  assertEquals(deadlineToGoogleDue('2026-11-25T23:59:00.000+09:00'), '2026-11-25T00:00:00.000Z');
  assertEquals(googleDueToDeadline('2026-11-25T00:00:00.000Z'), '2026-11-25T23:59:00.000+09:00');
  // 日付をまたぐ時刻（UTC 前日）でも JST の日付で扱う
  assertEquals(deadlineToGoogleDue('2026-11-25T00:30:00.000+09:00'), '2026-11-25T00:00:00.000Z');
  assertEquals(deadlineToGoogleDue(null), null);
  assertEquals(googleDueToDeadline(null), null);
});

Deno.test('札を持つ未同期クエストは Google へ作成される', () => {
  const ops = planSync([local()], [], []);
  assertEquals(ops, [{
    type: 'create_google',
    localId: 'L1',
    title: 'レポート提出',
    due: '2026-11-25T00:00:00.000Z',
    completed: false,
    etag: null,
  }]);
});

Deno.test('札の無いクエストは同期しない', () => {
  const ops = planSync([local({ tags: [] })], [], []);
  assertEquals(ops, []);
});

Deno.test('繰り返しクエストは同期対象外', () => {
  const ops = planSync([local({ repeatInterval: 'daily' })], [], []);
  assertEquals(ops, []);
});

Deno.test('未リンクの Google タスクはローカルへ取り込む', () => {
  const ops = planSync([], [google()], []);
  assertEquals(ops, [{
    type: 'create_local',
    googleTaskId: 'G1',
    title: 'レポート提出',
    deadline: '2026-11-25T23:59:00.000+09:00',
    completed: false,
    etag: '"etag-1"',
  }]);
});

Deno.test('削除済み・非表示の Google タスクは取り込まない', () => {
  assertEquals(planSync([], [google({ deleted: true })], []), []);
  assertEquals(planSync([], [google({ hidden: true })], []), []);
});

Deno.test('無変更なら何もしない', () => {
  assertEquals(planSync([local()], [google()], [link()]), []);
});

Deno.test('Google 側の削除はローカルの取消へ写す', () => {
  const ops = planSync([local()], [google({ deleted: true })], [link()]);
  assertEquals(ops, [{ type: 'cancel_local', localId: 'L1', reason: 'google_deleted' }]);
});

Deno.test('取消済みクエストは Google 側を削除する', () => {
  const ops = planSync(
    [local({ cancelledAt: '2026-11-21T00:00:00.000Z' })],
    [google()],
    [link()],
  );
  assertEquals(ops, [{
    type: 'delete_google',
    localId: 'L1',
    googleTaskId: 'G1',
    etag: '"etag-1"',
  }]);
});

Deno.test('札を外したら Google 側を削除する', () => {
  const ops = planSync([local({ tags: [] })], [google()], [link()]);
  assertEquals(ops[0].type, 'delete_google');
});

Deno.test('完了は単調: ローカル完了なら Google 更新時刻が新しくても完了へ', () => {
  const ops = planSync(
    [local({ isCompleted: true, updatedAt: '2026-11-20T09:00:00.000Z' })],
    [google({ updated: '2026-11-20T10:00:00.000Z' })],
    [link()],
  );
  assertEquals(ops.length, 1);
  assertEquals(ops[0].type, 'update_google');
  assertEquals((ops[0] as { completed: boolean }).completed, true);
});

Deno.test('競合: ローカルの方が新しい → Google を更新', () => {
  const ops = planSync(
    [local({ title: 'レポート提出（改）', updatedAt: '2026-11-20T12:00:00.000Z' })],
    [google()],
    [link()],
  );
  assertEquals(ops[0], {
    type: 'update_google',
    localId: 'L1',
    googleTaskId: 'G1',
    title: 'レポート提出（改）',
    due: '2026-11-25T00:00:00.000Z',
    completed: false,
    etag: '"etag-1"',
  });
});

Deno.test('競合: 差が60秒以内なら Google を優先', () => {
  const ops = planSync(
    [local({ title: 'ローカル名', updatedAt: '2026-11-20T10:00:30.000Z' })],
    [google({ title: 'グーグル名', updated: '2026-11-20T10:00:00.000Z' })],
    [link()],
  );
  assertEquals(ops[0].type, 'update_local');
  assertEquals((ops[0] as { title: string }).title, 'グーグル名');
});

Deno.test('競合: Google の方が新しい → ローカルを更新（期限も JST 復元）', () => {
  const ops = planSync(
    [local({ title: 'ローカル名', updatedAt: '2026-11-20T08:00:00.000Z' })],
    [google({ title: 'グーグル名', due: '2026-12-01T00:00:00.000Z', updated: '2026-11-20T10:00:00.000Z' })],
    [link()],
  );
  assertEquals(ops[0], {
    type: 'update_local',
    localId: 'L1',
    googleTaskId: 'G1',
    title: 'グーグル名',
    deadline: '2026-12-01T23:59:00.000+09:00',
    completed: false,
    etag: '"etag-1"',
  });
});

Deno.test('完了済みクエストは新規作成しない（履歴を持ち込まない）', () => {
  assertEquals(planSync([local({ isCompleted: true })], [], []), []);
});
