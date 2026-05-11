import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 職業説明チュートリアルダイアログ。
/// 冒険者Lv10到達時に表示され、全4職業の説明とマスタリー解説を行う。
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

  static const int _totalPages = 4;

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
        height: 460,
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
                  _buildPage1(context),
                  _buildPage2(context),
                  _buildPage3(context),
                  _buildPage4(context),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌸 祝福',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber)),
          const SizedBox(height: 20),
          const Text(
            '修行、お疲れ様でありんす！\n浪人Lv.10到達、誠におめでとうございます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          const Text(
            'この地「社（つかさ）」では、\n新たな4つの道が開かれ申す。\n\n自らの天命に従い、\nさらなる高みを目指すがよい。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ─── 2ページ目: 職業解説 ───
  Widget _buildPage2(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏯 職業解説',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _jobEntry(
                    '浪人',
                    Icons.hiking,
                    Colors.brown,
                    '基本の職業。\n依頼枠・ランク解放に優れる。',
                    '常時スキル発動: ランク・枠数解放',
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  _jobEntry(
                    '侍',
                    Icons.shield,
                    Colors.red,
                    '攻撃特化。\n連続達成でEXPボーナス増加。',
                    'コンボボーナス: Lv×10 EXP加算',
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  _jobEntry(
                    '法師',
                    Icons.health_and_safety,
                    Colors.cyan,
                    '回復・支援。\n繰り返し・曜日指定の依頼を管理。',
                    '繰り返しクエスト: 日次/週次対応',
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  _jobEntry(
                    '陰陽師',
                    Icons.auto_fix_high,
                    Colors.deepPurple,
                    '知識・管理。\nプロジェクト管理でサブタスク活用。',
                    'サブタスク管理: 全完了で討伐可能',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobEntry(
      String name, IconData icon, Color color, String desc, String perk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 2),
                Text('✨ $perk',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amberAccent,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3ページ目: マスタリー解説 ───
  Widget _buildPage3(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐ マスタリー',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber)),
          const SizedBox(height: 20),
          const Text(
            '各職業はLv.14で「マスター」となり、\nそのスキルを他職でも継承可能になる。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Text('🔄 スキル継承システム',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.amber)),
                SizedBox(height: 8),
                Text(
                  '例：侍をLv.14でマスター→法師に転職しても\nコンボボーナスをON/OFFで継承可能。\n\n最大4職業全てのスキルを\n同時に活用することもできる。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4ページ目: 寺院への導線 ───
  Widget _buildPage4(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏛️ 寺院へ',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber)),
          const SizedBox(height: 20),
          const Text(
            '下部メニューの「社」タブから\nいつでも転職・職業確認ができる。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Text(
            '転職は自由に何度でも可能。\nレベルは職業ごとに独立して蓄積される。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'まずは「社」で各職業の詳細を見てみよう！',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ナビゲーションボタン ───
  Widget _buildNavigation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // スキップボタン（常に表示）
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'skip_job_tutorial'),
            label: '職業チュートリアルをスキップ',
            child: TextButton(
              onPressed: widget.onSkip,
              child: const Text('スキップ',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          ),
          Row(
            children: [
              // 戻るボタン
              if (_currentPage > 0)
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'prev_job_page'),
                  label: '前のページ',
                  child: TextButton(
                    onPressed: _previousPage,
                    child: const Text('← 戻る',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                ),
              const SizedBox(width: 8),
              // 次へ / 閉じる
              _currentPage < _totalPages - 1
                  ? SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.button, 'next_job_page'),
                      label: '次のページ',
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('次へ →',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    )
                  : SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.button, 'close_job_tutorial'),
                      label: '職業チュートリアルを閉じる',
                      child: ElevatedButton(
                        onPressed: widget.onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('閉じる',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

/// JobTutorialDialog を表示する関数。
Future<void> showJobTutorialDialog(
  BuildContext context, {
  required VoidCallback onClose,
  required bool jobTutorialCompleted,
  VoidCallback? onSkip,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => JobTutorialDialog(
      onClose: onClose,
      onSkip: onSkip,
    ),
  );
}
