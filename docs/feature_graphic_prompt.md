# rpg_todo フィーチャーグラフィック生成指示書

**対象生成モデル**: Google Gemini NanoBanana 2（画像生成）
**用途**: Google Play Store フィーチャーグラフィック
**作成**: アメノウズメ（UXエージェント）

---

## 📐 技術要件（絶対遵守）

| 項目 | 値 |
|------|-----|
| 解像度 | **1024 × 500 px（横長）** |
| ファイル形式 | PNG（24bit、アルファ不可）または JPG |
| 文字 | **画像内に文字を入れない**（Google Playが別途重ねる／多言語展開時の差し替えを容易にするため） |
| セーフエリア | 左右96px・上下48px は重要要素を置かない（Play Store UIで切れる可能性） |
| ロゴ配置 | **入れない**（アプリアイコンは Play が自動表示） |

---

## 🎨 アートディレクション

### コアコンセプト（1行）
> **「ファンタジー世界の冒険者ギルド掲示板に、今日のタスクが"クエスト依頼書"として貼り出されている」**

### トーン & ムード
- **世界観**: 中世ファンタジー × RPG（ドラクエ／オクトパストラベラー／Octopath Traveler寄りのピクセル感はNG、油彩〜デジタルペイント寄り）
- **感情**: 冒険心・達成感・静かな高揚感
- **時間帯**: 朝の光が差し込む酒場／ギルド内部（ゲーム内の朝通知「ギルドより伝令」と世界観統一）

### カラーパレット（アプリ内準拠）

| 用途 | カラー | HEX |
|------|--------|-----|
| 深い紫（Sランク・最高位クエスト） | Royal Purple | `#4A148C` |
| くすんだ臙脂（Aランク） | Burgundy | `#8E3A3A` |
| 青灰色（Bランク・基本色） | Slate Blue | `#455A64` |
| アクセント（光・金属・装飾） | Warm Gold | `#D4AF37` |
| 背景ベース | Parchment / Aged Paper | `#F5E6C8` → `#3E2C1C` のグラデ |

**鉄則**: 彩度を抑えた重厚感のあるパレット。ネオン・パステルは使用禁止。

---

## 🖼️ 構図指示

### レイアウト（横長1024×500）

```
┌─────────────────────────────────────────────────────────┐
│ [左三分割]          [中央主役]          [右三分割]      │
│                                                         │
│  剣と盾が           木の古い                  ランプの灯 │
│  立てかけ           掲示板に               魔法陣を示す │
│  られた樽           羊皮紙の               装飾本が     │
│  ＆革袋             クエスト                 積まれた   │
│                     依頼書3枚                  机       │
│                     （S/A/B色別）                       │
│                                                         │
│  背景:ギルドの石壁・木梁・ステンドグラスから差す朝光     │
└─────────────────────────────────────────────────────────┘
```

### 主役要素（中央、最重要）
- **木製の掲示板（パブボード）**：ギルド内の壁に打ち付けられた、古びた木製ボード
- その上に貼られた **3枚のクエスト羊皮紙依頼書**：
  - 1枚目：紫の封蝋（Sランク・最高難度）
  - 2枚目：臙脂の封蝋（Aランク）
  - 3枚目：青灰の封蝋（Bランク）
- 各依頼書には**判読不能な古代文字風の筆記**（具体的な文字は書かない／多言語対応のため）
- 羊皮紙の端は燃やされたようにくすんでおり、紙のテクスチャが効いている

### 副次要素
- **左側**：樽の上に立てかけられた剣（グリップは布巻き）・革の金袋（宝石がこぼれている=アプリ内のGEM要素）
- **右側**：真鍮のオイルランプ（暖色の光を放つ）・装丁の重い魔導書・羽ペンとインク壺
- **背景**：石壁、木の梁、奥のステンドグラス窓から差し込む朝の金色の光、薄く舞う塵

### 光源
- **主光源**：画面右奥のステンドグラスから斜め45度に差す朝日（ゴールデンアワー）
- **副光源**：オイルランプの暖色灯
- **陰影**：主役の掲示板に光が当たり、左右に自然な影が落ちる

### カメラアングル
- **目線高さよりやや低め**（掲示板を仰ぎ見る冒険者の視点を想起させる）
- 被写界深度：**浅め**（主役の掲示板にピント、左右小物は軽くぼかす）

---

## 🚫 NG指示

- ❌ **文字・ロゴ・数字を画像内に描かない**（ローカライズ阻害）
- ❌ **キャラクター（人物・顔）を中央に配置しない**（掲示板こそが主役）
- ❌ **アニメ調の目・肌の表現**（世界観ずれ）
- ❌ **ネオン・サイバー要素**（中世ファンタジーと衝突）
- ❌ **現代的オブジェクト**（スマホ・PC・現代文字など）
- ❌ **背景の空白が多すぎる構図**（情報密度を保つ）
- ❌ **彩度の高いカラフル配色**（重厚感が損なわれる）

---

## ✅ 構図チェックリスト

生成後、以下を確認してください：

- [ ] 画像中央のx軸50%付近に掲示板＋3枚の依頼書が明確にある
- [ ] 3枚の羊皮紙の封蝋色が紫／臙脂／青灰で識別できる
- [ ] 文字が一切描かれていない（または判読不能な装飾文字のみ）
- [ ] 朝の暖色光が画面を支配し、全体が温かい
- [ ] 左右に小物配置があり、構図に重さのバランスがある
- [ ] 1024×500px の比率で切れる領域（左右96px）に重要要素がない

---

## 📝 プロンプト本体（Gemini/NanoBanana2 貼付用）

### 日本語版

```
横長1024x500のフィーチャーグラフィック画像を生成してください。
アスペクト比は2.048:1、横長バナー形式です。

シーン：中世ファンタジー世界の冒険者ギルドの内部。
画面中央に、古びた木製の掲示板が壁に打ち付けられている。
その掲示板には3枚の羊皮紙のクエスト依頼書が貼られており、それぞれ
- 上段：深い紫(#4A148C)の封蝋で封印された依頼書（最高難度）
- 中段：くすんだ臙脂色(#8E3A3A)の封蝋の依頼書
- 下段：青灰色(#455A64)の封蝋の依頼書
羊皮紙には判読不能な古代文字風の装飾的な筆記がされているが、具体的な文字は一切書かないこと。

左側：樽の上に布巻きの剣が立てかけられ、革袋から金色の宝石がこぼれている。
右側：机の上に真鍮のオイルランプが暖色の光を放ち、重厚な装丁の魔導書と羽ペン、インク壺が置かれている。
背景：石壁と木の梁、奥のステンドグラスから差し込む朝の金色の光線、空気中に舞う薄い塵。

スタイル：デジタルペイント、油彩風、重厚でマットな質感。
色調：ウォームゴールド(#D4AF37)をアクセントに、パーチメント色からダークブラウンへのグラデーション。
彩度は控えめ、中世ファンタジーの重厚感。
光源：画面右奥のステンドグラスからの斜め45度の朝日と、ランプの暖色灯。
被写界深度：掲示板にピントが合い、左右の小物は軽くぼける。

文字、ロゴ、数字、現代的なオブジェクト、キャラクターの顔、アニメ調の表現、ネオン色、パステル色は一切含めないこと。
画像の左右96pxと上下48pxの領域には重要な要素を置かないこと（セーフエリア）。
```

### 英語版（Gemini精度向上のため）

```
Generate a 1024x500 landscape feature graphic image, aspect ratio 2.048:1.

Scene: Interior of a medieval fantasy Adventurer's Guild.
At the center, an aged wooden bulletin board nailed to a stone wall.
Three parchment quest scrolls are pinned on the board:
- Top: sealed with deep royal purple (#4A148C) wax (highest rank)
- Middle: sealed with dusty burgundy (#8E3A3A) wax
- Bottom: sealed with slate blue (#455A64) wax
The parchments have decorative illegible ancient-script-like writing — do NOT include any readable letters or numbers.

Left side: a cloth-wrapped sword leaning against an old barrel, with a leather pouch spilling golden gems.
Right side: a brass oil lamp casting warm light on a desk, beside a heavy leather-bound spellbook, quill pen, and inkwell.
Background: stone walls, wooden beams, morning golden sunlight streaming through a stained glass window at an angle, fine dust particles floating in the air.

Style: digital painting, oil painting aesthetic, heavy matte texture, painterly.
Color palette: warm gold (#D4AF37) accents, gradient from parchment cream to dark brown, muted saturation, heavy medieval fantasy mood.
Lighting: 45-degree morning sunbeam from upper right stained glass plus warm lamp glow.
Depth of field: shallow — bulletin board in sharp focus, side objects softly blurred.

Do NOT include: any text, letters, numbers, logos, modern objects, character faces, anime style, neon colors, pastel colors.
Keep the outer 96px (left/right) and 48px (top/bottom) free of important elements (safe area for Play Store UI).
```

---

## 🔁 イテレーション指針

初回生成で以下が満たされない場合は、太字部分を強調してリトライ：

| 問題 | 追加指示 |
|------|--------|
| 文字が入ってしまう | "**Absolutely no text, no letters, no numbers anywhere in the image**" |
| キャラが中央に来る | "**The bulletin board is the main subject, no characters in the center**" |
| 彩度が高すぎる | "**Muted, desaturated medieval oil painting tone**" |
| 掲示板が小さい | "**The bulletin board occupies the central 40% of the width**" |
| アスペクト比ずれ | "**Strictly 1024x500 pixels, ratio 2.048:1, wide banner format**" |

---

## 📂 成果物保存先

- 原画：`assets/feature_graphic.png`（既存ファイルを置き換え）
- 派生（アイコン用クロップ等）は `assets/icon/` 配下

---

**アメノウズメより一言**
> 掲示板という「受動的な物体」を主役にすることで、プレイヤーは「次に自分が貼る依頼書は何か？」と想像する余白を得る。文字を入れぬは、多言語のためだけにあらず。見る者の物語を妨げぬためである。
