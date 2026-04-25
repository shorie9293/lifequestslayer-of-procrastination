# rpg_todo — クローズドテスト告知 マーケティング素材集

このフォルダには、`rpg_todo` のクローズドテスト参加者を募集するための
告知素材が入っています。

## 収録ファイル

| ファイル | 用途 | そのまま使えるか |
|---|---|---|
| `x_posts.md` | X(Twitter) 投稿案6パターン + スレッド型 | `[TEST_URL]` を差し替えるだけでOK |
| `blog_post.md` | note / Qiita / Zenn / 個人ブログ用の紹介記事 | `[TEST_URL]` を差し替えるだけでOK |
| `landing.html` | クローズドテスト誘導用シングルページLP | `[TEST_URL]` を差し替えるだけでOK |

## 差し替えが必要なプレースホルダー

全ファイル共通で以下を置換してください：

```
[TEST_URL]  →  Google Play クローズドテスト申込フォームのURL
             または Google グループの招待URL
```

一括置換の例（macOS / Linux）：

```bash
cd marketing
# Google フォームURL例
sed -i '' 's|\[TEST_URL\]|https://forms.gle/XXXXXXXXXXXX|g' *.md *.html
```

## 推奨運用順序

1. **landing.html** を Netlify / Vercel / GitHub Pages にデプロイして、
   短い公開URLを取得（例: `rpg-todo.netlify.app`）
2. **x_posts.md** のパターン①またはスレッド型を最初に投稿し、
   LPへのリンクを添える
3. **blog_post.md** を note に投稿し、X投稿から記事に導線を張る
4. 反応を見ながら パターン②〜⑥ を日を空けて投稿

## LP の公開方法（最短）

既に `netlify.toml` が Flutter Web のデプロイ設定で使われているため、
LP は別サブパスで公開するか、別リポジトリを作るのが安全です。

### Netlify Drop（登録不要・最短）

1. https://app.netlify.com/drop を開く
2. `landing.html` だけを入った空のフォルダを作ってドラッグ&ドロップ
3. 発行された URL をそのまま X 投稿に貼れます

### GitHub Pages

1. 別リポジトリに `landing.html` を `index.html` として配置
2. リポジトリ設定から Pages を有効化
3. `https://<username>.github.io/<repo>/` で公開

## 撮影推奨スクリーンショット

X 投稿・note 記事の埋込用に、実機でのスクショを準備すると効果大：

- 冒険者ギルド画面（クエスト一覧）
- レベルアップ演出の瞬間
- 称号解放の画面
- ストリーク報酬ダイアログ
- 知識クエストの出題画面

スクショは 1080×1920 前後に揃えると X にきれいに表示されます。

## チェックリスト（公開前）

- [ ] `[TEST_URL]` をすべて実URLに置換した
- [ ] LP を公開し、スマホで表示崩れがないか確認した
- [ ] 最初の X 投稿に画像を1〜4枚添付した
- [ ] 固定ポスト（プロフィールのトップ）を設定した
- [ ] note / Qiita / Zenn のいずれかに記事を投稿した
- [ ] ハッシュタグを `#個人開発` `#Flutter` `#Androidアプリ` などに絞った
- [ ] 反応してくれた人への返信テンプレを自分用に用意した
