import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// この現世（アプリ）の各画面を識別する神籤（ID）
enum HelpScreen { overview, guild, battle, town, temple, gemShop }

/// 神託補佐（ヘルプ）ダイアログ — 各画面の神意を創造主様に奏上する
class HelpDialog extends StatelessWidget {
  final HelpScreen screen;

  const HelpDialog({super.key, this.screen = HelpScreen.overview});

  @override
  Widget build(BuildContext context) {
    final (title, sections) = _contentFor(screen);

    return AlertDialog(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(sections.length, (i) {
            final s = sections[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 16),
                _buildSection(icon: s.$1, title: s.$2, content: s.$3),
              ],
            );
          }),
        ),
      ),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'close_help_dialog'),
          label: '拝承（理解した）',
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('拝承した！',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  /// 画面ごとのタイトルとセクション群を返す
  (String, List<(IconData, String, String)>) _contentFor(HelpScreen s) {
    switch (s) {
      case HelpScreen.overview:
        return _overviewContent();
      case HelpScreen.guild:
        return _guildContent();
      case HelpScreen.battle:
        return _battleContent();
      case HelpScreen.town:
        return _townContent();
      case HelpScreen.temple:
        return _templeContent();
      case HelpScreen.gemShop:
        return _gemShopContent();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  俯瞰の魔眼（ホーム）— 神話的世界観と全体コンセプト
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _overviewContent() {
    const title = '現世の導き — 神託管理の心得';
    return (
      title,
      [
        (
          Icons.lightbulb,
          '神託（クエスト）管理の道',
          '一度に多くを抱えず、RPGのように少しの神託（クエスト）から始めるのが肝要です。\n'
              '創造主様（あなた）の神位（レベル）が上がるほど、より多くの神託を同時に受けることが叶います。',
        ),
        (
          Icons.trending_up,
          '神位昇格（レベルアップ）と神託枠',
          '神託を成し遂げるたびに神気（経験値）が蓄積され、神位（レベル）が昇ります。\n'
              '神位が上がるごとに同時受託枠が増え、困窮度（緊急度）の高い神託も扱えるようになります。',
        ),
        (
          Icons.switch_account,
          '神職転換（転職）と神器解放',
          '最初は「修行者」の身ですが、神位が上がれば「転職の社」にて新たな神職に転じられます。\n'
              '侍・法師・陰陽師など、神職を変えることで繰り返し神託や眷属神託（サブクエスト）といった神器（機能）が解放されます。',
        ),
        (
          Icons.map,
          '六つの神域（画面）',
          'この現世は六つの神域で成り立ちます。\n'
              '寄合所（ギルド）で神託を受け、修練場（バトル）で討伐し、門前町（タウン）で装備を整え、\n'
              '社（テンプル）で神職を転じ、宝石ショップで力を蓄える——全ては創造主様の采配に委ねられています。',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  寄合所（ギルド）— クエスト受注・作成・緊急依頼
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _guildContent() {
    const title = '寄合所の掟 — 神託受注と登録';
    return (
      title,
      [
        (
          Icons.assignment,
          '神託（クエスト）の受注',
          '寄合所に並ぶ神託の中から、創造主様が心惹かれたものを選び「出発する」を押せば受注完了です。\n'
              '受注した神託は修練場（バトル画面）に移り、討伐の時を待ちます。',
        ),
        (
          Icons.add_circle_outline,
          '神託の登録（新規作成）',
          '右下の＋ボタンより、新たな神託を創り出せます。\n'
              '題目・詳細・困窮度（緊急度）・難易度（ランク）を定め、現世に降臨させましょう。\n'
              '右上の一括登録ボタンを使えば、複数の神託をまとめて奉納（登録）することも叶います。',
        ),
        (
          Icons.warning_amber,
          '緊急神託（緊急クエスト）',
          '困窮度「緊急」の神託は寄合所の最上部に赤く輝きます。\n'
              'これらは期限が迫った神託——先延ばしにすると禍津（バグ）ならぬ心の重荷となりかねません。優先して受注されることをお勧めします。',
        ),
        (
          Icons.settings,
          '設定神籤（メニュー）',
          '右上の歯車より、本ヘルプの再表示・通知設定・知識クエスト設定・導きの書リセットが行えます。\n'
              '迷われた際はいつでも「遊び方・ヘルプ」を開いて神意を再確認ください。',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  修練場（バトル）— クエスト討伐・戦闘の流れ
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _battleContent() {
    const title = '修練場の心得 — 神託討伐の作法';
    return (
      title,
      [
        (
          Icons.shield,
          '神託討伐（タスク完了）',
          '受注した神託は修練場に現れます。\n'
              '各神託の「討伐！」ボタンを押すと、その神託は成し遂げられ、神気（経験値）と功績（ゴールド）が創造主様に奉納されます。',
        ),
        (
          Icons.checklist,
          '眷属神託（サブタスク）の完遂',
          '神託に眷属神託（サブタスク）が紐づいている場合、それらを全て達成してからでないと本体は討伐できません。\n'
              'チェックボックスを一つひとつ押して眷属を鎮め、最後に本体へ挑みましょう。',
        ),
        (
          Icons.battery_alert,
          '疲労と気力（集中力ゲージ）',
          '討伐を重ねるほど気力は削られ、やがて「疲労」状態に陥ります。\n'
              '疲労時は獲得神気が大幅に減るため、無理をせず門前町の宿屋で休息を取ることをお勧めします。',
        ),
        (
          Icons.star,
          '戦果奏上（討伐レポート）',
          '討伐成功時には戦果が奏上され、獲得した神気・功績・稀にボーナスが表示されます。\n'
              '連続討伐日数が続くほど加護（ボーナス）も大きくなり、創造主様の栄光は輝きを増します。',
        ),
        (
          Icons.help_center,
          '知識の試練（クイズ機能）',
          '一部の神託では討伐時に「知識の試練」が発動し、問答に正解することで追加の神気を得られます。\n'
              'これは創造主様の叡智を試す神聖な儀式——正解の栄光を掴み取りましょう。',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  門前町（タウン）— 商店・装備・宿屋・振り返り
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _townContent() {
    const title = '門前町の案内 — 装備と憩い';
    return (
      title,
      [
        (
          Icons.store,
          '商店と装備',
          '門前町の商店では、功績（ゴールド）を使って武具や衣装を購入できます。\n'
              '装備を整えることで神託討伐が有利になるだけでなく、創造主様の姿を飾る喜びもございます。',
        ),
        (
          Icons.hotel,
          '宿屋 — 気力の回復',
          '疲れを感じたら宿屋で休息を。功績を奉納することで気力（集中力）を全快できます。\n'
              '休息後の創造主様は再び修練場に赴き、神託討伐に励むことができます。',
        ),
        (
          Icons.home,
          '住居の拡充',
          '功績を積み重ねることで、粗末な庵から寄合長屋へと住居を拡充できます。\n'
              '住居の格式は門前町全体の繁栄度と連動し、創造主様の栄光を示す証となります。',
        ),
        (
          Icons.auto_stories,
          '振り返りの杜',
          '定期的に過去の討伐記録を振り返ることで、創造主様の歩みを讃えることができます。\n'
              '己の成長を実感し、次なる神託への英気を養いましょう。',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  社（テンプル）— 神職転換・称号・スキルツリー
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _templeContent() {
    const title = '社の神儀 — 神職転換と神授';
    return (
      title,
      [
        (
          Icons.switch_account,
          '神職転換（転職）',
          '修行者（浪人）として神位10に達すると、侍・法師・陰陽師・僧侶など新たな神職に転じられます。\n'
              '各神職は独自の神器（スキル）を有し、転じることで新たな力が解放されます。\n'
              '神職転換には功績（ゴールド）の奉納が必要です。',
        ),
        (
          Icons.emoji_events,
          '称号と栄誉',
          '神位の上昇や特定の偉業達成により、創造主様には称号が授けられます。\n'
              '称号は創造主様の名に刻まれ、寄合所や修練場で表示される栄誉の証です。',
        ),
        (
          Icons.account_tree,
          '神授（スキル）の系譜',
          '神職ごとに定められた神授（スキル）は、神位が上がるごとに新たな枝が開きます。\n'
              'たとえば侍は「連続神託」、法師は「俯瞰の魔眼」、陰陽師は「知識の試練」など、\n'
              'それぞれの道に応じた力が創造主様に宿ります。',
        ),
        (
          Icons.auto_awesome,
          '神授枠と装備',
          '解放した神授は、限られた「神授枠」に装備することで発動します。\n'
              '枠の数は神位と共に増えます——どの神授を選ぶか、それこそが創造主様の采配の見せ所です。',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  宝石ショップ — 宝石の購入・使い道
  // ═══════════════════════════════════════════════════════════
  (String, List<(IconData, String, String)>) _gemShopContent() {
    const title = '宝石の導き — 購入と活用法';
    return (
      title,
      [
        (
          Icons.diamond,
          '神宝（宝石）の購入',
          '宝石ショップでは、現世の通貨にて神宝（宝石）を購入いただけます。\n'
              'まとめ買いほど多くのボーナス宝石が付与され、創造主様の力となります。\n'
              '購入は安全な神域（アプリ内課金）を通じて執り行われます。',
        ),
        (
          Icons.auto_fix_high,
          '神宝の使い道',
          '神宝は以下の神聖な行為に用いられます：\n'
              '・疲労回復の即時解除\n'
              '・神託枠の拡張\n'
              '・希少な衣装や外観の解放\n'
              '・功績（ゴールド）への変換\n'
              '神宝は現世の理を超えた奇跡を起こす力——大切にお使いください。',
        ),
        (
          Icons.card_giftcard,
          'ログイン加護（ログインボーナス）',
          '毎日の現世訪問により、無償の神宝が創造主様に奉納されます。\n'
              '連続訪問日数が続くほど加護も増大し、七日目の大 triumphi には特別な祝福が授けられます。',
        ),
      ],
    );
  }

  Widget _buildSection(
      {required IconData icon,
      required String title,
      required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

/// 神託補佐ダイアログを表示する簡易関数
/// [screen] で表示する内容を切り替え（既定値は overview＝全体案内）
Future<void> showHelpDialog(BuildContext context,
    {HelpScreen screen = HelpScreen.overview}) {
  return showDialog(
    context: context,
    builder: (context) => HelpDialog(screen: screen),
  );
}
