// Google ToDo 連携 Edge Function
//
// ルート（パスは /functions/v1/google-todo 以降で判定）:
//   POST /start     : 認可URLの発行（PKCE。要ログイン）
//   GET  /callback  : Google からの戻り。code→refresh_token 交換（JWT不要・state で照合）
//   GET  /status    : 連携状態と最終同期の取得（要ログイン）
//   GET  /lists     : タスクリスト一覧（要ログイン）
//   POST /unlink    : 連携解除（要ログイン）
//   POST /sync      : 双方向同期の実行（要ログイン。?dryRun=1 で計画のみ）
//
// 認証: 関数は --no-verify-jwt で配置し、ここで Authorization を検証する。
import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import {
  GOOGLE_TODO_TAG,
  type GoogleTask,
  type Link,
  type LocalTask,
  planSync,
  type SyncOp,
} from './sync_core.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};
const TASKS_SCOPE = 'https://www.googleapis.com/auth/tasks';
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env: ${name}`);
  return v;
}

function serviceClient(): SupabaseClient {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false },
  });
}

async function requireUser(req: Request): Promise<
  { ok: true; userId: string; email: string | null } | { ok: false; res: Response }
> {
  const auth = req.headers.get('Authorization') ?? '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return { ok: false, res: json({ error: 'unauthorized' }, 401) };
  const { data, error } = await serviceClient().auth.getUser(token);
  if (error || !data.user) return { ok: false, res: json({ error: 'unauthorized' }, 401) };
  return { ok: true, userId: data.user.id, email: data.user.email ?? null };
}

// ---------------------------------------------------------------- OAuth (PKCE)

function base64Url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function sha256(input: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return new Uint8Array(digest);
}

function redirectUri(req: Request): string {
  return Deno.env.get('GOOGLE_TASKS_REDIRECT_URI') ??
    `${env('SUPABASE_URL')}/functions/v1/google-todo/callback`;
}

async function handleStart(req: Request, userId: string) {
  const verifier = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const challenge = base64Url(await sha256(verifier));
  const state = base64Url(crypto.getRandomValues(new Uint8Array(24)));
  const uri = redirectUri(req);

  const { error } = await serviceClient().from('google_todo_oauth_states').insert({
    state,
    user_id: userId,
    code_verifier: verifier,
    redirect_uri: uri,
  });
  if (error) return json({ error: error.message }, 500);

  const params = new URLSearchParams({
    client_id: env('GOOGLE_TASKS_CLIENT_ID'),
    redirect_uri: uri,
    response_type: 'code',
    scope: `${TASKS_SCOPE} openid email`,
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'true',
    state,
    code_challenge: challenge,
    code_challenge_method: 'S256',
  });
  return json({
    authorizeUrl: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
  });
}

function page(title: string, body: string, deepLink: string): Response {
  const html = `<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<style>body{font-family:system-ui,sans-serif;background:#12100e;color:#f3ece1;display:grid;
place-items:center;height:100vh;margin:0;text-align:center;padding:24px}
h1{font-size:20px;font-weight:600;margin:0 0 8px}p{color:#c8bda9;font-size:14px;line-height:1.7}
a{display:inline-block;margin-top:20px;padding:12px 20px;border-radius:999px;
background:#c8a15a;color:#12100e;text-decoration:none;font-weight:600}</style></head>
<body><div><h1>${title}</h1><p>${body}</p><a href="${deepLink}">アプリに戻る</a></div>
<script>setTimeout(function(){location.href=${JSON.stringify(deepLink)}},1200)</script>
</body></html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

async function handleCallback(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const denied = url.searchParams.get('error');
  if (denied) {
    return page('連携を中止しました', 'Google 側で許可されませんでした。', 'app://google-todo?status=denied');
  }
  if (!code || !state) {
    return page('連携できませんでした', 'パラメータが不足しています。', 'app://google-todo?status=error');
  }
  const db = serviceClient();
  const { data: row, error: stateErr } = await db
    .from('google_todo_oauth_states')
    .select('*')
    .eq('state', state)
    .is('consumed_at', null)
    .maybeSingle();
  if (stateErr || !row) {
    return page('連携できませんでした', 'state が無効か期限切れです。もう一度お試しください。', 'app://google-todo?status=error');
  }
  await db.from('google_todo_oauth_states')
    .update({ consumed_at: new Date().toISOString() }).eq('state', state);

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: env('GOOGLE_TASKS_CLIENT_ID'),
      client_secret: env('GOOGLE_TASKS_CLIENT_SECRET'),
      redirect_uri: row.redirect_uri,
      grant_type: 'authorization_code',
      code_verifier: row.code_verifier,
    }),
  });
  const token = await tokenRes.json();
  if (!tokenRes.ok || !token.refresh_token) {
    console.error('token exchange failed', tokenRes.status, token);
    return page(
      '連携できませんでした',
      'トークンの取得に失敗しました（Google Cloud 側の設定をご確認ください）。',
      'app://google-todo?status=error',
    );
  }

  let sub: string | null = null;
  let email: string | null = (token.email as string | undefined) ?? null;
  if (token.id_token) {
    try {
      const payload = JSON.parse(
        atob(token.id_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')),
      );
      sub = payload.sub ?? null;
      email = email ?? (payload.email ?? null);
    } catch (_) { /* id_token は任意 */ }
  }
  // id_token が無い場合は userinfo で補う（画面にアカウントを出すため）
  if (!email || !sub) {
    try {
      const infoRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${token.access_token}` },
      });
      if (infoRes.ok) {
        const info = await infoRes.json();
        sub = sub ?? (info.sub ?? null);
        email = email ?? (info.email ?? null);
      }
    } catch (_) { /* 表示用の補完。失敗しても連携は成立する */ }
  }

  const { error: upsertErr } = await db.from('google_todo_accounts').upsert({
    user_id: row.user_id,
    google_sub: sub,
    email: token.email ?? null,
    list_id: '@default',
    refresh_token: token.refresh_token,
    access_token: token.access_token ?? null,
    access_expires_at: new Date(Date.now() + (token.expires_in ?? 3600) * 1000).toISOString(),
    scopes: String(token.scope ?? '').split(' ').filter(Boolean),
    linked_at: new Date().toISOString(),
    revoked_at: null,
  });
  if (upsertErr) {
    console.error('account upsert failed', upsertErr);
    return page('連携できませんでした', '保存に失敗しました。', 'app://google-todo?status=error');
  }
  return page('連携しました', 'LifeQuest Slayer と Google ToDo を結びました。', 'app://google-todo?status=linked');
}

// ------------------------------------------------------------ Google Tasks API

async function accessTokenFor(userId: string): Promise<{
  token: string;
  account: Record<string, unknown>;
}> {
  const db = serviceClient();
  const { data: acct, error } = await db.from('google_todo_accounts')
    .select('*').eq('user_id', userId).is('revoked_at', null).maybeSingle();
  if (error) throw new Error(error.message);
  if (!acct) throw Object.assign(new Error('not_linked'), { status: 403 });

  const expires = acct.access_expires_at ? new Date(acct.access_expires_at).getTime() : 0;
  if (acct.access_token && expires > Date.now() + 60_000) {
    return { token: acct.access_token as string, account: acct };
  }
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: env('GOOGLE_TASKS_CLIENT_ID'),
      client_secret: env('GOOGLE_TASKS_CLIENT_SECRET'),
      refresh_token: String(acct.refresh_token ?? ''),
      grant_type: 'refresh_token',
    }),
  });
  const tok = await res.json();
  if (!res.ok || !tok.access_token) {
    console.error('refresh failed', res.status, tok);
    throw Object.assign(new Error('token_refresh_failed'), { status: 403 });
  }
  await db.from('google_todo_accounts').update({
    access_token: tok.access_token,
    access_expires_at: new Date(Date.now() + (tok.expires_in ?? 3600) * 1000).toISOString(),
  }).eq('user_id', userId);
  return { token: tok.access_token as string, account: { ...acct, access_token: tok.access_token } };
}

const API = 'https://tasks.googleapis.com/tasks/v1';

async function gfetch(path: string, token: string, init: RequestInit = {}): Promise<Response> {
  const doCall = () =>
    fetch(`${API}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...(init.headers ?? {}),
      },
    });
  let res = await doCall();
  if (res.status === 429 || res.status >= 500) {
    await new Promise((r) => setTimeout(r, 800));
    res = await doCall();
  }
  return res;
}

async function listGoogleTasks(token: string, listId: string): Promise<GoogleTask[]> {
  const out: GoogleTask[] = [];
  let pageToken: string | undefined;
  for (let i = 0; i < 20; i++) {
    const params = new URLSearchParams({
      showCompleted: 'true',
      showHidden: 'true',
      maxResults: '100',
    });
    if (pageToken) params.set('pageToken', pageToken);
    const res = await gfetch(`/lists/${encodeURIComponent(listId)}/tasks?${params}`, token);
    if (!res.ok) throw new Error(`tasks.list ${res.status}: ${await res.text()}`);
    const body = await res.json();
    for (const item of body.items ?? []) {
      out.push({
        id: item.id,
        title: item.title ?? '',
        status: item.status === 'completed' ? 'completed' : 'needsAction',
        due: item.due ?? null,
        updated: item.updated ?? new Date(0).toISOString(),
        deleted: item.deleted === true,
        hidden: item.hidden === true,
        etag: item.etag ?? null,
      });
    }
    pageToken = body.nextPageToken;
    if (!pageToken) break;
  }
  return out;
}

// ---------------------------------------------------------------- local tasks

type LocalRow = { id: string; data: Record<string, unknown> };

function toLocalTask(row: LocalRow): LocalTask {
  const d = row.data ?? {};
  return {
    id: row.id,
    title: String(d.title ?? ''),
    isCompleted: d.isCompleted === true,
    status: String(d.status ?? 'inGuild'),
    deadline: (d.deadline as string | null) ?? null,
    updatedAt: (d.updatedAt as string | null) ?? null,
    cancelledAt: (d.cancelledAt as string | null) ?? null,
    tags: Array.isArray(d.tags) ? (d.tags as string[]) : [],
    repeatInterval: String(d.repeatInterval ?? 'none'),
  };
}

function newLocalData(op: Extract<SyncOp, { type: 'create_local' }>) {
  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    title: op.title,
    status: op.completed ? 'active' : 'inGuild',
    isCompleted: op.completed,
    rank: 'B',
    repeatInterval: 'none',
    repeatWeekdays: [],
    lastCompletedAt: null,
    subTasks: [],
    targetTimeMinutes: null,
    activeAt: null,
    deadline: op.deadline,
    repeatAfterDays: null,
    tags: [GOOGLE_TODO_TAG],
    cancelledAt: null,
    enemyAssetPath: null,
    enemyXpMultiplier: 1.0,
    updatedAt: new Date(op.etag ? now : now).toISOString(),
  };
}

// ---------------------------------------------------------------------- sync

async function handleSync(req: Request, userId: string, dryRun: boolean) {
  const db = serviceClient();
  const { token, account } = await accessTokenFor(userId);
  const listId = String(account.list_id ?? '@default');

  const [googleTasks, linksRes, tasksRes] = await Promise.all([
    listGoogleTasks(token, listId),
    db.from('google_todo_links').select('local_id, google_task_id, etag').eq('user_id', userId),
    db.from('rpg_tasks').select('id, data').eq('user_id', userId),
  ]);
  if (linksRes.error) throw new Error(linksRes.error.message);
  if (tasksRes.error) throw new Error(tasksRes.error.message);

  const localTasks = (tasksRes.data as LocalRow[]).map(toLocalTask);
  const links: Link[] = (linksRes.data ?? []).map((r) => ({
    localId: r.local_id as string,
    googleTaskId: r.google_task_id as string,
    etag: (r.etag as string | null) ?? null,
  }));

  const ops = planSync(localTasks, googleTasks, links);
  if (dryRun) return json({ dryRun: true, ops: ops.map((o) => o.type), count: ops.length });

  let pulled = 0;
  let pushed = 0;
  const failures: string[] = [];
  const nowIso = new Date().toISOString();

  for (const op of ops) {
    try {
      if (op.type === 'create_google') {
        const res = await gfetch(`/lists/${encodeURIComponent(listId)}/tasks`, token, {
          method: 'POST',
          body: JSON.stringify({
            title: op.title,
            ...(op.due ? { due: op.due } : {}),
          }),
        });
        if (!res.ok) throw new Error(`insert ${res.status}`);
        const created = await res.json();
        if (op.completed) {
          await gfetch(
            `/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(created.id)}`,
            token,
            { method: 'PATCH', body: JSON.stringify({ status: 'completed' }) },
          );
        }
        await db.from('google_todo_links').upsert({
          user_id: userId,
          local_id: op.localId,
          google_task_id: created.id,
          list_id: listId,
          etag: created.etag ?? null,
          last_pulled_google_updated: created.updated ?? null,
          synced_local_updated_at: nowIso,
          last_synced_at: nowIso,
        });
        pushed++;
      } else if (op.type === 'update_google') {
        const res = await gfetch(
          `/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(op.googleTaskId)}`,
          token,
          {
            method: 'PATCH',
            headers: op.etag ? { 'If-Match': op.etag } : undefined,
            body: JSON.stringify({
              title: op.title,
              ...(op.due ? { due: op.due } : {}),
              status: op.completed ? 'completed' : 'needsAction',
            }),
          },
        );
        if (!res.ok && res.status !== 412) throw new Error(`patch ${res.status}`);
        pushed++;
        if (res.ok) {
          const updated = await res.json();
          await db.from('google_todo_links').update({
            etag: updated.etag ?? null,
            last_pulled_google_updated: updated.updated ?? null,
            synced_local_updated_at: nowIso,
            last_synced_at: nowIso,
          }).eq('user_id', userId).eq('local_id', op.localId);
        }
      } else if (op.type === 'delete_google') {
        const res = await gfetch(
          `/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(op.googleTaskId)}`,
          token,
          { method: 'DELETE', headers: op.etag ? { 'If-Match': op.etag } : undefined },
        );
        if (!res.ok && res.status !== 404 && res.status !== 412) {
          throw new Error(`delete ${res.status}`);
        }
        await db.from('google_todo_links').delete()
          .eq('user_id', userId).eq('local_id', op.localId);
        pushed++;
      } else if (op.type === 'create_local') {
        const data = newLocalData(op);
        const localId = data.id;
        const { error } = await db.from('rpg_tasks').insert({
          id: localId,
          user_id: userId,
          data,
          updated_at: nowIso,
        });
        if (error) throw new Error(error.message);
        await db.from('google_todo_links').upsert({
          user_id: userId,
          local_id: localId,
          google_task_id: op.googleTaskId,
          list_id: listId,
          etag: op.etag,
          last_pulled_google_updated: null,
          synced_local_updated_at: nowIso,
          last_synced_at: nowIso,
        });
        pulled++;
      } else if (op.type === 'update_local') {
        const row = (tasksRes.data as LocalRow[]).find((r) => r.id === op.localId);
        const data = { ...(row?.data ?? {}), title: op.title, deadline: op.deadline, isCompleted: op.completed };
        const { error } = await db.from('rpg_tasks').update({ data, updated_at: nowIso })
          .eq('id', op.localId).eq('user_id', userId);
        if (error) throw new Error(error.message);
        await db.from('google_todo_links').update({
          etag: op.etag,
          synced_local_updated_at: nowIso,
          last_synced_at: nowIso,
        }).eq('user_id', userId).eq('local_id', op.localId);
        pulled++;
      } else if (op.type === 'cancel_local') {
        const row = (tasksRes.data as LocalRow[]).find((r) => r.id === op.localId);
        const data = { ...(row?.data ?? {}), cancelledAt: nowIso };
        const { error } = await db.from('rpg_tasks').update({ data, updated_at: nowIso })
          .eq('id', op.localId).eq('user_id', userId);
        if (error) throw new Error(error.message);
        pulled++;
      }
    } catch (e) {
      console.error('op failed', op.type, e);
      failures.push(`${op.type}: ${(e as Error).message}`);
    }
  }

  await db.from('google_todo_sync_state').upsert({
    user_id: userId,
    last_run_at: nowIso,
    ...(failures.length ? { last_error: failures.slice(0, 3).join(' / ') } : { last_ok_at: nowIso, last_error: null }),
    pulled,
    pushed,
  });

  return json({ ok: failures.length === 0, pulled, pushed, failures });
}

// -------------------------------------------------------------------- routes

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const url = new URL(req.url);
  const route = url.pathname.replace(/^.*\/google-todo/, '').replace(/\/$/, '') || '/';

  try {
    if (route === '/callback') return await handleCallback(req);

    const auth = await requireUser(req);
    if (!auth.ok) return auth.res;

    if (route === '/start' && req.method === 'POST') return await handleStart(req, auth.userId);

    if (route === '/status') {
      const db = serviceClient();
      const [{ data: acct }, { data: state }] = await Promise.all([
        db.from('google_todo_accounts').select('email, list_id, list_title, linked_at, revoked_at')
          .eq('user_id', auth.userId).maybeSingle(),
        db.from('google_todo_sync_state').select('*').eq('user_id', auth.userId).maybeSingle(),
      ]);
      return json({
        linked: !!acct && !acct.revoked_at,
        email: acct?.email ?? null,
        listId: acct?.list_id ?? null,
        listTitle: acct?.list_title ?? null,
        linkedAt: acct?.linked_at ?? null,
        lastRunAt: state?.last_run_at ?? null,
        lastOkAt: state?.last_ok_at ?? null,
        lastError: state?.last_error ?? null,
        pulled: state?.pulled ?? 0,
        pushed: state?.pushed ?? 0,
      });
    }

    if (route === '/lists') {
      const { token } = await accessTokenFor(auth.userId);
      const res = await gfetch('/users/@me/lists?maxResults=100', token);
      if (!res.ok) return json({ error: `lists ${res.status}` }, 502);
      const body = await res.json();
      return json({
        lists: (body.items ?? []).map((l: { id: string; title: string }) => ({
          id: l.id,
          title: l.title,
        })),
      });
    }

    if (route === '/select-list' && req.method === 'POST') {
      const body = await req.json().catch(() => ({}));
      if (!body?.listId) return json({ error: 'listId required' }, 400);
      const { error } = await serviceClient().from('google_todo_accounts')
        .update({ list_id: body.listId, list_title: body.listTitle ?? null })
        .eq('user_id', auth.userId);
      if (error) return json({ error: error.message }, 500);
      return json({ ok: true });
    }

    if (route === '/unlink' && req.method === 'POST') {
      const db = serviceClient();
      await db.from('google_todo_accounts')
        .update({ revoked_at: new Date().toISOString(), refresh_token: null, access_token: null })
        .eq('user_id', auth.userId);
      await db.from('google_todo_links').delete().eq('user_id', auth.userId);
      return json({ ok: true });
    }

    if (route === '/sync' && req.method === 'POST') {
      return await handleSync(req, auth.userId, url.searchParams.get('dryRun') === '1');
    }

    return json({ error: 'not_found', route }, 404);
  } catch (e) {
    const err = e as Error & { status?: number };
    console.error('unhandled', err);
    return json({ error: err.message }, err.status ?? 500);
  }
});
