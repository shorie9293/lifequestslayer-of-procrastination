import 'package:flutter/material.dart';

/// 職業説明チュートリアルダイアログ。
/// 冒険者Lv10到達時に表示され、全16スキル（4職業×4）の解説と
/// スキルスロットシステムの説明を行う（7ページ構成）。
class JobTutorialDialog extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onSkip;

  const JobTutorialDialog({
    super.key,
    required this.onClose,
    this.onSkip,
  });

  @override
  State<JobTutorialDialog> createState() => _JobTutorialDialogState();
}

class _JobTutorialDialogState extends State<JobTutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 7;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: Column(
          children: [
            // ページインジケーター
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 12, left: 12),
              child: Row(
                children: [
                  for (int i = 0; i < _totalPages; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Colors.amber
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ページ本体
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPage1(context), // 祝福
                  _buildPage2(context), // 浪人スキル
                  _buildPage3(context), // 侍スキル
                  _buildPage4(context), // 法師スキル
                  _buildPage5(context), // 陰陽師スキル
                  _buildPage6(context), // スキルスロット
                  _buildPage7(context), // 寺院ナビ
                ],
              ),
            ),
            // ナビゲーションボタン
            _buildNavigation(context),
          ],
        ),
      ),
    );
  }

  // ─── 1ページ目: 祝福 ───
  Widget _buildPage1(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌸 祝福',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text(
            '修行、お疲れ様でありんす！\n浪人Lv.10到達、誠におめでとうございます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            '4つの職業×4スキル＝全16スキルを\n習得・装備して、さらなる高みを目指せ！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  // ─── 2ページ目: 浪人スキル ───
  Widget _buildPage2(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🗡️ 浪人のスキル',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSkillRow('冒険者の勘', 'Lv.1', 'クエストランク・枠数の解放。常時発動。'),
          const SizedBox(height: 12),
          _buildSkillRow('果てなき挑戦', 'Lv.10', '繰り返しタスク登録。浪人Lv10でスロット+1。'),
        ],
      ),
    );
  }

  // ─── 3ページ目: 侍スキル ───
  Widget _buildPage3(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚔️ 侍のスキル',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSkillRow('連撃の構え', 'Lv.1', 'コンボボーナス：連続達成でEXP増加。'),
          const SizedBox(height: 12),
          _buildSkillRow('逆転の気魄', 'Lv.5', '疲労ゲージ逆転：タスク消化で回復。'),
          const SizedBox(height: 12),
          _buildSkillRow('集中の型', 'Lv.10', '25分集中タイマー。完了時EXP+50%。'),
          const SizedBox(height: 12),
          _buildSkillRow('武士道の極意', 'Lv.15', '日課完了で永続EXP倍率+0.01（全職対象）。'),
        ],
      ),
    );
  }

  // ─── 4ページ目: 法師スキル ───
  Widget _buildPage4(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛡️ 法師のスキル',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSkillRow('後追いの祈り', 'Lv.1', '毎日同じ時刻に繰り返しタスクを再生成。'),
          const SizedBox(height: 12),
          _buildSkillRow('微睡みの加護', 'Lv.5', '期限切れ間近のタスクを1日延期。'),
          const SizedBox(height: 12),
          _buildSkillRow('連続の誓い', 'Lv.10', 'タスク連続完了記録。7日継続でXP1.2倍。'),
          const SizedBox(height: 12),
          _buildSkillRow('悟りの境地', 'Lv.15', 'ストリーク維持1日猶予（週1回）。'),
        ],
      ),
    );
  }

  // ─── 5ページ目: 陰陽師スキル ───
  Widget _buildPage5(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔮 陰陽師のスキル',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSkillRow('分割の理', 'Lv.1', 'サブタスク作成。サブタスク完了でXP+30%。'),
          const SizedBox(height: 12),
          _buildSkillRow('札の掌握', 'Lv.5', 'タグによるタスク分類・フィルタリング。'),
          const SizedBox(height: 12),
          _buildSkillRow('計画の陣', 'Lv.10', 'プロジェクト管理：複数タスクをグループ化。'),
          const SizedBox(height: 12),
          _buildSkillRow('俯瞰の魔眼', 'Lv.15', 'カレンダー/カンバン一覧表示。'),
        ],
      ),
    );
  }

  // ─── 6ページ目: スキルスロットシステム ───
  Widget _buildPage6(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔧 スキルスロットシステム',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('• 基本1枠 + 浪人Lv10 + 各職Lv15で追加'),
          SizedBox(height: 8),
          Text('• 他職のスキルをスロットに装備可能'),
          SizedBox(height: 8),
          Text('• 寺院画面で装備・解除'),
          SizedBox(height: 8),
          Text('• MASTERスキル（Lv15）は常時発動'),
          SizedBox(height: 8),
          Text('• 現在の職業スキルは常時使用可能'),
        ],
      ),
    );
  }

  // ─── 7ページ目: 寺院ナビ ───
  Widget _buildPage7(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏛️ 寺院へ',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text(
            '「社」タブから寺院にアクセスし、\n'
            '転職・スキル装備を行おう。\n\n'
            '寺院では以下の操作が可能：\n'
            '・職業の変更（転職）\n'
            '・スキルスロットの装備/解除\n'
            '・現在の職業スキルの確認\n'
            '・各職業の習熟度確認',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillRow(String name, String level, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(level,
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(desc,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 戻るボタン
          if (_currentPage > 0 && _currentPage < _totalPages - 1)
            TextButton(
              onPressed: _previousPage,
              child: const Text('← 戻る'),
            )
          else
            const SizedBox.shrink(),
          // スキップ
          if (_currentPage < _totalPages - 1 && widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text('スキップ'),
            ),
          // 次へ / 閉じる
          if (_currentPage < _totalPages - 1)
            ElevatedButton(
              onPressed: _nextPage,
              child: const Text('次へ →'),
            )
          else
            ElevatedButton(
              onPressed: widget.onClose,
              child: const Text('閉じる'),
            ),
        ],
      ),
    );
  }
}

void showJobTutorialDialog(
  BuildContext context, {
  required VoidCallback onClose,
  VoidCallback? onSkip,
  bool jobTutorialCompleted = false,
}) {
  if (jobTutorialCompleted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => JobTutorialDialog(
      onClose: onClose,
      onSkip: onSkip,
    ),
  );
}
