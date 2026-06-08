import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('アプリのコンセプト',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              icon: Icons.lightbulb,
              title: 'RPG風クエスト管理',
              content: 'いきなり全てを管理するのではなく、RPGのように少ないクエストから徐々に慣れていくコンセプトです。',
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.trending_up,
              title: 'レベルアップとクエスト枠',
              content:
                  'まずは少しのクエストから！クエストを仕留めてレベルが上がると、同時に受注できるクエストの数が増えていきます。',
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.switch_account,
              title: '転職と新機能の解放',
              content:
                  '最初は「修行者」ですが、レベルが上がると「転職の神殿」で他の職業に転職できます。侍、法師、陰陽師など、職業を変えることで新しい機能（繰り返しクエストやサブクエストなど）が解放されます。',
            ),
          ],
        ),
      ),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'close_help_dialog'),
          label: '理解した',
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('理解した！',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
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

Future<void> showHelpDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const HelpDialog(),
  );
}
