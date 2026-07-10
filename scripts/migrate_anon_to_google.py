#!/usr/bin/env python3
"""
匿名ユーザー → Googleアカウント データ移行スクリプト。

匿名認証時代の user_id（例: 27cb...673d, 76件保持）を、
Googleログイン後の新しい user_id へ付け替える。

Supabase は匿名→OAuth の linkIdentity に制約があるため、
service_role でデータの user_id を直接 UPDATE する。

使用方法:
  export SUPABASE_SERVICE_ROLE_KEY="..."   # BWS から取得
  python3 migrate_anon_to_google.py --from <匿名UUID> --to <GoogleログインUUID>
  python3 migrate_anon_to_google.py --from <匿名UUID> --to <UUID> --dry-run

環境変数:
  SUPABASE_SERVICE_ROLE_KEY — Supabaseのサービスロールキー（必須）
"""
import os
import sys
import json
import argparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError

SUPABASE_URL = "https://kxklkgxpjwddufjccvoj.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")


def _headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def _count(table: str, user_id: str) -> int:
    url = f"{SUPABASE_URL}/rest/v1/{table}?user_id=eq.{user_id}&select=user_id"
    req = Request(url, headers=_headers())
    with urlopen(req, timeout=20) as r:
        return len(json.loads(r.read().decode()))


def _update_user_id(table: str, from_id: str, to_id: str) -> int:
    url = f"{SUPABASE_URL}/rest/v1/{table}?user_id=eq.{from_id}"
    body = json.dumps({"user_id": to_id}).encode()
    req = Request(url, data=body, headers=_headers(), method="PATCH")
    with urlopen(req, timeout=30) as r:
        return len(json.loads(r.read().decode()))


def main():
    if not SUPABASE_KEY:
        sys.exit("ERROR: SUPABASE_SERVICE_ROLE_KEY 環境変数が未設定です。BWS から取得してください。")

    p = argparse.ArgumentParser(description="匿名→Googleアカウント データ移行")
    p.add_argument("--from", dest="from_id", required=True, help="移行元の匿名user_id")
    p.add_argument("--to", dest="to_id", required=True, help="移行先のGoogleログインuser_id")
    p.add_argument("--dry-run", action="store_true", help="実行せず件数だけ確認")
    args = p.parse_args()

    tasks_before = _count("rpg_tasks", args.from_id)
    players_before = _count("rpg_players", args.from_id)
    to_tasks = _count("rpg_tasks", args.to_id)
    to_players = _count("rpg_players", args.to_id)

    print(f"[移行元 {args.from_id[:8]}..] tasks={tasks_before}, players={players_before}")
    print(f"[移行先 {args.to_id[:8]}..] tasks={to_tasks}, players={to_players}")

    if to_tasks > 0 or to_players > 0:
        print("⚠️ 警告: 移行先に既存データがあります。upsert競合の可能性。続行前に確認してください。")

    if args.dry_run:
        print("(dry-run: 変更なし)")
        return

    try:
        t = _update_user_id("rpg_tasks", args.from_id, args.to_id)
        pl = _update_user_id("rpg_players", args.from_id, args.to_id)
        print(json.dumps({
            "ok": True,
            "migrated_tasks": t,
            "migrated_players": pl,
            "from": args.from_id,
            "to": args.to_id,
        }, ensure_ascii=False))
    except HTTPError as e:
        body = e.read().decode() if e.fp else str(e)
        sys.exit(f"ERROR HTTP {e.code}: {body}")


if __name__ == "__main__":
    main()
