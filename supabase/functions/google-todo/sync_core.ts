// Google ToDo 同期の中核（純粋関数のみ・I/O なし）
//
// 設計の正:
//  - 同期対象は札 `GoogleToDo` を持つクエスト ⇔ 1つのGoogleタスクリスト
//  - 完了は単調（どちらかで完了 → 両方完了。巻き戻さない）
//  - 削除はローカルの cancelledAt（取消）へ写す。取消から Google 側 delete も出す
//  - 競合は last-write-wins。差が60秒以内なら Google を優先（外部編集を尊重）

export const GOOGLE_TODO_TAG = 'GoogleToDo';
export const TIE_WINDOW_MS = 60 * 1000;
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** Google のサブタスクを表す最小情報（ローカルの subTasks と同じ形） */
export type GoogleSubTask = { title: string; isCompleted: boolean };

export type LocalTask = {
  id: string;
  title: string;
  isCompleted: boolean;
  status: string;
  deadline: string | null;
  updatedAt: string | null;
  cancelledAt: string | null;
  tags: string[];
  repeatInterval: string;
  subTasks?: GoogleSubTask[];
};

export type GoogleTask = {
  id: string;
  title: string;
  status: 'needsAction' | 'completed';
  due?: string | null;
  updated: string;
  deleted?: boolean;
  hidden?: boolean;
  etag?: string | null;
  /** 親タスクの Google タスクID（サブタスクのときだけ入る） */
  parent?: string | null;
  /** 並び順（Google が発行する辞書順ソート可能な文字列） */
  position?: string | null;
};

export type Link = {
  localId: string;
  googleTaskId: string;
  etag?: string | null;
};

export type SyncOp =
  | {
    type: 'create_google';
    localId: string;
    title: string;
    due: string | null;
    completed: boolean;
    etag: null;
  }
  | {
    type: 'update_google';
    localId: string;
    googleTaskId: string;
    title: string;
    due: string | null;
    completed: boolean;
    etag: string | null;
  }
  | {
    type: 'delete_google';
    localId: string;
    googleTaskId: string;
    etag: string | null;
  }
  | {
    type: 'create_local';
    googleTaskId: string;
    title: string;
    deadline: string | null;
    completed: boolean;
    etag: string | null;
    /** 子タスクをチェックリストとして持ち込む（空なら省略） */
    subTasks?: GoogleSubTask[];
  }
  | {
    type: 'update_local';
    localId: string;
    googleTaskId: string;
    title: string;
    deadline: string | null;
    completed: boolean;
    etag: string | null;
    /** Google 由来のチェックリスト（サブタスクが1件以上あるときだけ入る） */
    subTasks?: GoogleSubTask[];
  }
  | {
    type: 'cancel_local';
    localId: string;
    reason: 'google_deleted';
  };

/** 期限（ISO）→ Google の due（JST の日付を UTC 00:00 で表す RFC3339） */
export function deadlineToGoogleDue(deadline: string | null): string | null {
  if (!deadline) return null;
  const t = new Date(deadline).getTime();
  if (Number.isNaN(t)) return null;
  const jst = new Date(t + JST_OFFSET_MS);
  const y = jst.getUTCFullYear();
  const m = String(jst.getUTCMonth() + 1).padStart(2, '0');
  const d = String(jst.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}T00:00:00.000Z`;
}

/** Google の due（RFC3339）→ 期限（JST その日 23:59） */
export function googleDueToDeadline(due: string | null | undefined): string | null {
  if (!due) return null;
  const datePart = due.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datePart)) return null;
  return `${datePart}T23:59:00.000+09:00`;
}

function toMs(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const t = new Date(iso).getTime();
  return Number.isNaN(t) ? null : t;
}

/** 指定タスクの子タスクを並び順で取り出す（削除・非表示は除く） */
export function googleSubtasksOf(
  googleTasks: GoogleTask[],
  parentGoogleId: string,
): GoogleSubTask[] {
  return googleTasks
    .filter((g) => g.parent === parentGoogleId && !g.deleted && !g.hidden)
    .sort((a, b) => (a.position ?? '').localeCompare(b.position ?? ''))
    .map((g) => ({
      title: (g.title ?? '').trim() || '（無題のタスク）',
      isCompleted: g.status === 'completed',
    }));
}

/** チェックリストが同じ内容か（毎回の push を避けるための比較） */
export function sameSubTasks(
  local: GoogleSubTask[] | undefined,
  remote: GoogleSubTask[],
): boolean {
  const a = local ?? [];
  const b = remote ?? [];
  if (a.length !== b.length) return false;
  return a.every((s, i) => s.title === b[i].title && s.isCompleted === b[i].isCompleted);
}

/** ローカルが同期対象（札あり・繰り返しなし）か */
export function isSyncTarget(t: LocalTask): boolean {
  if (!t.tags.includes(GOOGLE_TODO_TAG)) return false;
  return t.repeatInterval === 'none';
}

/**
 * 差分から実行計画を立てる。I/O を持たないため全分岐を単体で試練できる。
 * 呼び出し側は返った op を順に実行し、成功したものだけ link を更新する。
 */
export function planSync(
  localTasks: LocalTask[],
  googleTasks: GoogleTask[],
  links: Link[],
): SyncOp[] {
  const ops: SyncOp[] = [];
  const localById = new Map(localTasks.map((t) => [t.id, t]));
  const googleById = new Map(googleTasks.map((g) => [g.id, g]));
  const linkedLocal = new Set(links.map((l) => l.localId));
  const linkedGoogle = new Set(links.map((l) => l.googleTaskId));

  for (const link of links) {
    const local = localById.get(link.localId);
    const google = googleById.get(link.googleTaskId);

    // ローカルが消えている → ユーザーがローカルで削除した（＝墓標がある）。
    // 対応を捨てるだけだと Google 側にタスクが残り続けるので、Google 側も消して
    // リンクを掃除する（残すと「消したのに Google に残る」孤児リンクになる）。
    if (!local) {
      if (google && !google.deleted) {
        ops.push({
          type: 'delete_google',
          localId: link.localId,
          googleTaskId: link.googleTaskId,
          etag: google.etag ?? link.etag ?? null,
        });
      } else {
        ops.push({
          type: 'delete_google',
          localId: link.localId,
          googleTaskId: link.googleTaskId,
          etag: link.etag ?? null,
        });
      }
      continue;
    }

    // Google 側が削除/非表示 → ローカルは取消（再配備抑制の既存機構を使う）
    if (!google || google.deleted) {
      if (!local.cancelledAt) {
        ops.push({ type: 'cancel_local', localId: local.id, reason: 'google_deleted' });
      }
      continue;
    }

    // 札を外した / 取消した → Google 側を消す
    if (!local.tags.includes(GOOGLE_TODO_TAG) || local.cancelledAt) {
      ops.push({
        type: 'delete_google',
        localId: local.id,
        googleTaskId: google.id,
        etag: google.etag ?? link.etag ?? null,
      });
      continue;
    }

    // 繰り返しクエストは初版では同期しない
    if (local.repeatInterval !== 'none') continue;

    // Google 側の子タスク（＝ローカルのチェックリスト）
    const childSubs = googleSubtasksOf(googleTasks, google.id);

    const googleCompleted = google.status === 'completed';
    const localDueDate = local.deadline
      ? (deadlineToGoogleDue(local.deadline) ?? '').slice(0, 10) || null
      : null;
    const googleDueDate = google.due ? google.due.slice(0, 10) : null;
    const dueMatches = localDueDate === googleDueDate;
    const titleMatches = (google.title ?? '') === local.title;

    // 完了は単調: ローカル完了・Google未完了なら必ず Google を完了へ
    if (local.isCompleted && !googleCompleted) {
      ops.push({
        type: 'update_google',
        localId: local.id,
        googleTaskId: google.id,
        title: local.title,
        due: deadlineToGoogleDue(local.deadline),
        completed: true,
        etag: google.etag ?? link.etag ?? null,
      });
      continue;
    }

    if (titleMatches && dueMatches && local.isCompleted === googleCompleted) {
      // タイトル・期限・完了が同じでも、子タスクの構成が違えば持ち込む
      if (!sameSubTasks(local.subTasks, childSubs)) {
        ops.push({
          type: 'update_local',
          localId: local.id,
          googleTaskId: google.id,
          title: local.title,
          deadline: local.deadline,
          completed: local.isCompleted,
          etag: google.etag ?? link.etag ?? null,
          ...(childSubs.length ? { subTasks: childSubs } : {}),
        });
      }
      continue; // 無変更
    }

    const lUpd = toMs(local.updatedAt);
    const gUpd = toMs(google.updated);

    // どちらが新しいか。判定不能・60秒以内は Google 優先
    let localWins: boolean;
    if (lUpd === null || gUpd === null) {
      localWins = false;
    } else if (Math.abs(lUpd - gUpd) <= TIE_WINDOW_MS) {
      localWins = false;
    } else {
      localWins = lUpd > gUpd;
    }

    if (localWins) {
      ops.push({
        type: 'update_google',
        localId: local.id,
        googleTaskId: google.id,
        title: local.title,
        due: deadlineToGoogleDue(local.deadline),
        completed: local.isCompleted,
        etag: google.etag ?? link.etag ?? null,
      });
    } else {
      ops.push({
        type: 'update_local',
        localId: local.id,
        googleTaskId: google.id,
        title: google.title ?? local.title,
        deadline: googleDueToDeadline(google.due),
        completed: googleCompleted,
        etag: google.etag ?? link.etag ?? null,
        ...(childSubs.length ? { subTasks: childSubs } : {}),
      });
    }
  }

  // ローカル → Google（新規）
  for (const local of localTasks) {
    if (linkedLocal.has(local.id)) continue;
    if (!isSyncTarget(local)) continue;
    if (local.cancelledAt || local.isCompleted) continue;
    ops.push({
      type: 'create_google',
      localId: local.id,
      title: local.title,
      due: deadlineToGoogleDue(local.deadline),
      completed: false,
      etag: null,
    });
  }

  // Google → ローカル（新規取り込み）
  for (const google of googleTasks) {
    if (linkedGoogle.has(google.id)) continue;
    if (google.deleted || google.hidden) continue;
    // 子タスクは親クエストのチェックリストとして持ち込むため、単独クエストにしない。
    // ただし親が一覧に居ない（孤児）場合は取りこぼしを避けて単独クエストにする。
    if (google.parent && googleById.has(google.parent)) continue;
    const childSubs = googleSubtasksOf(googleTasks, google.id);
    ops.push({
      type: 'create_local',
      googleTaskId: google.id,
      title: (google.title ?? '').trim() || '（無題のタスク）',
      deadline: googleDueToDeadline(google.due),
      completed: google.status === 'completed',
      etag: google.etag ?? null,
      ...(childSubs.length ? { subTasks: childSubs } : {}),
    });
  }

  return ops;
}
