import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('アプリのコンセプト', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              icon: Icons.lightbulb,
              title: 'RPG風タスク管理',
              content: 'いきなり全てを管理するのではなく、RPGのように少ないタスクから徐々に慣れていくコンセプトです。',
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.trending_up,
              title: 'レベルアップとクエスト枠',
              content: 'まずは少しのタスクから！クエストを討伐（完了）してレベルが上がると、同時に受注できるタスクの数が増えていきます。',
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.switch_account,
              title: '転職と新機能の解放',
              content: '最初は「冒険者」ですが、レベルが上がると「転職の神殿」で他の職業に転職できます。戦士、僧侶、魔法使いなど、職業を変えることで新しい機能（繰り返しタスクやサブタスクなど）が解放されます。',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('理解した！'),
        ),
      ],
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
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
