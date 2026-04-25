/// 知識クエストのクイズ問題モデル
class QuizQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final int expBonusPercent; // 正解時のボーナスEXP (base exp に対する %)
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.expBonusPercent,
    this.explanation,
  });
}

/// アプリ内クイズ問題集（Dart定数として管理。将来的にサーバー配信も可能）
/// correctIndex は 0始まり。
const List<QuizQuestion> kQuizQuestions = [
  // ---- 時間管理・生産性 ----
  QuizQuestion(
    id: 'q001',
    question: 'ポモドーロテクニックの1セットの作業時間は？',
    choices: ['15分', '25分', '45分', '60分'],
    correctIndex: 1,
    expBonusPercent: 30,
    explanation: '25分の集中 + 5分の休憩を1セットとするタイムマネジメント手法です。',
  ),
  QuizQuestion(
    id: 'q002',
    question: '「食べるカエル」の法則とは？',
    choices: ['朝食を必ず食べること', '最も難しいタスクを最初に片付けること', '食後30分は休憩すること', 'タスクを小さく分割すること'],
    correctIndex: 1,
    expBonusPercent: 20,
    explanation: 'Brian Tracyの著書に由来。一番やりたくないタスクを先に済ませると、その後の仕事が楽になります。',
  ),
  QuizQuestion(
    id: 'q003',
    question: 'GTD(Getting Things Done)の「Inbox」の目的は？',
    choices: ['メールの受信箱', 'すべての気になることを一旦集めておく場所', 'プロジェクト管理ツール', '完了タスクのアーカイブ'],
    correctIndex: 1,
    expBonusPercent: 25,
    explanation: 'GTDでは頭の中の気になることをすべてInboxに書き出すことで、脳のメモリを解放します。',
  ),
  QuizQuestion(
    id: 'q004',
    question: '「2分ルール」とは何ですか？',
    choices: ['2分おきに休憩をとる', '2分以内に終わるタスクはすぐにやる', 'タスクを2分で説明できるか確認する', '2分で計画を立てる'],
    correctIndex: 1,
    expBonusPercent: 20,
    explanation: 'David Allenが提唱したGTDのルール。2分以内で完了するタスクはリスト化せず即実行します。',
  ),
  // ---- 習慣形成 ----
  QuizQuestion(
    id: 'q005',
    question: '新しい習慣が定着するまでに一般的に必要な日数は？',
    choices: ['7日', '21日', '66日', '100日'],
    correctIndex: 2,
    expBonusPercent: 30,
    explanation: 'ロンドン大学の研究によると、習慣の自動化には平均66日かかるとされています（21日説は俗説）。',
  ),
  QuizQuestion(
    id: 'q006',
    question: '「スモールステップ」の原則の核心は？',
    choices: ['毎日少しずつ学ぶ', '最初の一歩を極力小さくして始める', '目標を細分化して管理する', 'ゆっくりと確実に進む'],
    correctIndex: 1,
    expBonusPercent: 20,
    explanation: '習慣を作る際は「小さすぎる」と感じるくらいのステップから始めるのが継続のコツです。',
  ),
  // ---- 集中・フロー ----
  QuizQuestion(
    id: 'q007',
    question: 'フロー状態（ゾーン）に入るための条件は？',
    choices: ['完全な静寂の中で作業する', 'スキルと難易度のバランスが取れていること', '好きな音楽を聴くこと', '長時間休まず作業すること'],
    correctIndex: 1,
    expBonusPercent: 35,
    explanation: 'Mihaly Csikszentmihalyiが提唱。挑戦レベルがスキルより少し高いとき、フロー状態に入りやすくなります。',
  ),
  QuizQuestion(
    id: 'q008',
    question: '集中力の持続を妨げる主な要因として研究で挙げられるものは？',
    choices: ['適切な照明', 'スマホの通知', '軽い運動', '水分補給'],
    correctIndex: 1,
    expBonusPercent: 20,
    explanation: 'スマホの通知は集中を乱し、元の集中状態に戻るまで平均23分かかるという研究があります。',
  ),
  // ---- プロジェクト管理 ----
  QuizQuestion(
    id: 'q009',
    question: 'アジャイル開発における「スプリント」とは？',
    choices: ['短距離走のこと', '短期間の開発サイクル（1〜4週間）', 'バグ修正のフェーズ', 'チームのミーティング'],
    correctIndex: 1,
    expBonusPercent: 25,
    explanation: 'スクラムでは1〜4週間の固定期間をスプリントと呼び、この単位で計画・実装・振り返りを行います。',
  ),
  QuizQuestion(
    id: 'q010',
    question: 'KPT法の「T」は何を意味しますか？',
    choices: ['Time（時間）', 'Try（次に試すこと）', 'Target（目標）', 'Task（タスク）'],
    correctIndex: 1,
    expBonusPercent: 20,
    explanation: 'KPT = Keep（続けること）/ Problem（問題）/ Try（次に試すこと）。振り返りの定番フレームワークです。',
  ),
];
