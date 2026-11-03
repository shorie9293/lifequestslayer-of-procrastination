// LifeQuest API v1 — クエスト投入の正門
//
// 配置: supabase/functions/api/index.ts
// 公開URL: https://<project-ref>.supabase.co/functions/v1/api/v1/quests
//
// 設計の要点（docs/decisions.md / SPEC.md §10 と対応）:
// - DB へは service_role で書くが、user_id は「トークン検証で確定した値」のみを使う。
//   リクエスト本文の user_id は決して信用しない。
// - 公開形式 → rpg_tasks.data（Task.toJson() 形式）への翻訳はこの関数だけが持つ。
// - Task.fromJson は status/isCompleted/rank/repeatInterval を非nullで読むため、
//   これらを欠かすとアプリ側の全件読込が壊れる。必須キーは必ず埋める。
// - deadline は「JST naive」で書く（アプリはローカル naive を前提に表示するため、
//   オフセット付きで書くと画面が9時間ズレる）。

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...CORS },
  });
}

function fail(status: number, code: string, message: string): Response {
  return json({ error: { code, message } }, status);
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** ISO 8601（オフセット可）→ JST naive `YYYY-MM-DDTHH:mm:ss`。不正なら null。 */
function toJstNaive(input: string): string | null {
  const ms = Date.parse(input);
  if (Number.isNaN(ms)) return null;
  const jst = new Date(ms + 9 * 60 * 60 * 1000);
  const p = (n: number) => n.toString().padStart(2, "0");
  return `${jst.getUTCFullYear()}-${p(jst.getUTCMonth() + 1)}-${
    p(jst.getUTCDate())
  }T${p(jst.getUTCHours())}:${p(jst.getUTCMinutes())}:${p(jst.getUTCSeconds())}`;
}

/** キー順に依存しない JSON 文字列（冪等性の比較用）。 */
function canonical(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonical(obj[k])}`).join(",")}}`;
}

interface TokenRow {
  id: string;
  user_id: string;
  scopes: string[];
}

async function authenticate(
  req: Request,
): Promise<{ token: TokenRow } | { response: Response }> {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return { response: fail(401, "unauthenticated", "missing bearer token") };

  const hash = await sha256Hex(match[1].trim());
  const { data, error } = await admin
    .from("api_tokens")
    .select("id, user_id, scopes")
    .eq("token_hash", hash)
    .is("revoked_at", null)
    .maybeSingle();

  if (error || !data) {
    return { response: fail(401, "unauthenticated", "invalid or revoked token") };
  }
  return { token: data as TokenRow };
}

const RANKS = new Set(["S", "A", "B"]);

function rankFor(minutes: number | null): string {
  if (minutes === null) return "B";
  if (minutes >= 90) return "S";
  if (minutes >= 45) return "A";
  return "B";
}

interface QuestData {
  [key: string]: unknown;
}

function buildTaskData(
  id: string,
  body: Record<string, unknown>,
  nowIso: string,
): { data: QuestData } | { error: string } {
  const rawTitle = body["title"];
  if (typeof rawTitle !== "string") return { error: "title is required" };
  const title = rawTitle.trim();
  if (title.length === 0 || title.length > 200) {
    return { error: "title must be 1-200 characters" };
  }

  let deadline: string | null = null;
  if (body["deadline"] !== undefined && body["deadline"] !== null) {
    if (typeof body["deadline"] !== "string") return { error: "deadline must be an ISO 8601 string" };
    deadline = toJstNaive(body["deadline"]);
    if (deadline === null) return { error: "deadline is not a valid date" };
  }

  let targetTimeMinutes: number | null = null;
  if (body["targetTimeMinutes"] !== undefined && body["targetTimeMinutes"] !== null) {
    const n = body["targetTimeMinutes"];
    if (typeof n !== "number" || !Number.isInteger(n) || n < 5 || n > 1440) {
      return { error: "targetTimeMinutes must be an integer between 5 and 1440" };
    }
    targetTimeMinutes = n;
  }

  let rank: string;
  if (body["rank"] !== undefined && body["rank"] !== null) {
    if (typeof body["rank"] !== "string" || !RANKS.has(body["rank"])) {
      return { error: "rank must be one of S, A, B" };
    }
    rank = body["rank"];
  } else {
    rank = rankFor(targetTimeMinutes);
  }

  const tags: string[] = [];
  if (body["tags"] !== undefined && body["tags"] !== null) {
    const raw = body["tags"];
    if (!Array.isArray(raw) || raw.length > 10) {
      return { error: "tags must be an array of at most 10 strings" };
    }
    for (const t of raw) {
      if (typeof t !== "string" || t.length === 0 || t.length > 30) {
        return { error: "each tag must be 1-30 characters" };
      }
      if (!tags.includes(t)) tags.push(t);
    }
  }
  if (!tags.includes("API")) tags.push("API");

  const subTasks: Array<{ title: string; isCompleted: boolean }> = [];
  if (body["subTasks"] !== undefined && body["subTasks"] !== null) {
    const raw = body["subTasks"];
    if (!Array.isArray(raw) || raw.length > 50) {
      return { error: "subTasks must be an array of at most 50 items" };
    }
    for (const st of raw) {
      const stTitle = (st as Record<string, unknown>)?.["title"];
      if (typeof stTitle !== "string") return { error: "subTasks[].title must be a string" };
      const trimmed = stTitle.trim();
      if (trimmed.length === 0 || trimmed.length > 200) {
        return { error: "subTasks[].title must be 1-200 characters" };
      }
      subTasks.push({ title: trimmed, isCompleted: false });
    }
  }

  // Task.fromJson が要求するキーは1つも欠かさない（欠けるとアプリの全件読込が壊れる）
  const data: QuestData = {
    id,
    title,
    status: "inGuild",
    isCompleted: false,
    rank,
    repeatInterval: "none",
    repeatWeekdays: [],
    lastCompletedAt: null,
    subTasks,
    targetTimeMinutes,
    activeAt: null,
    deadline,
    repeatAfterDays: null,
    tags,
    cancelledAt: null,
    enemyAssetPath: null,
    enemyXpMultiplier: 1.0,
    updatedAt: nowIso,
  };
  return { data };
}

function stripVolatile(data: Record<string, unknown>): Record<string, unknown> {
  const copy: Record<string, unknown> = { ...data };
  delete copy["updatedAt"];
  return copy;
}

async function handleCreateQuest(req: Request, body: Record<string, unknown>, token: TokenRow): Promise<Response> {
  if (!token.scopes.includes("quests:write")) {
    return fail(403, "insufficient_scope", "token lacks quests:write");
  }

  let id: string;
  const rawId = body["id"];
  if (rawId === undefined || rawId === null) {
    id = crypto.randomUUID();
  } else if (typeof rawId === "string" && /^[0-9a-zA-Z-]{8,64}$/.test(rawId)) {
    id = rawId;
  } else {
    return fail(422, "validation_failed", "id must be a uuid-like string");
  }

  const nowIso = new Date().toISOString();
  const built = buildTaskData(id, body, nowIso);
  if ("error" in built) return fail(422, "validation_failed", built.error);
  const data = built.data;

  const { data: existing, error: readError } = await admin
    .from("rpg_tasks")
    .select("id, user_id, data")
    .eq("id", id)
    .maybeSingle();

  if (readError) return fail(500, "internal_error", "could not read existing quest");

  if (existing) {
    if (existing.user_id !== token.user_id) {
      return fail(409, "id_conflict", "id is already used by another user");
    }
    const same = canonical(stripVolatile(existing.data as Record<string, unknown>)) ===
      canonical(stripVolatile(data));
    if (!same) return fail(409, "id_conflict", "id exists with different content");
    return json({ id, status: "inGuild", createdAt: existing.data?.["updatedAt"] ?? nowIso }, 200);
  }

  const { error: insertError } = await admin.from("rpg_tasks").insert({
    id,
    user_id: token.user_id,
    data,
    updated_at: nowIso,
  });

  if (insertError) {
    // 同時投入の競合（unique violation）は「既にある」として扱う
    if (insertError.code === "23505") {
      return fail(409, "id_conflict", "id already exists");
    }
    return fail(500, "internal_error", `insert failed: ${insertError.message}`);
  }

  return json({ id, status: "inGuild", createdAt: nowIso }, 201);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  const auth = await authenticate(req);
  if ("response" in auth) return auth.response;
  const token = auth.token;

  // 最終使用時刻の記録（失敗しても本処理は止めない）
  admin.rpc("touch_api_token", { p_token_id: token.id }).then(() => {}, () => {});

  if (req.method === "POST" && url.pathname.endsWith("/v1/quests")) {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return fail(422, "validation_failed", "body must be JSON");
    }
    if (body === null || typeof body !== "object" || Array.isArray(body)) {
      return fail(422, "validation_failed", "body must be a JSON object");
    }
    return await handleCreateQuest(req, body, token);
  }

  return fail(404, "not_found", "unknown endpoint");
});
