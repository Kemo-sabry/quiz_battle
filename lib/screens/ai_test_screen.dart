import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';

class AiTestScreen extends StatefulWidget {
  const AiTestScreen({super.key});

  @override
  State<AiTestScreen> createState() => _AiTestScreenState();
}

class _AiTestScreenState extends State<AiTestScreen> {
  final _ai = AIService();
  String _topic = kTopics.first;
  String _difficulty = 'Medium';
  int _count = 5;

  bool _loading = false;
  String? _error;
  List<Question> _questions = [];

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = [];
    });
    try {
      final result = await _ai.generateQuiz(
        topic: _topic,
        difficulty: _difficulty,
        count: _count,
      );
      setState(() => _questions = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _learnMore(Question q) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final help = await _ai.getStudyHelp(topic: _topic, questionText: q.text);
      if (!mounted) return;
      Navigator.pop(context); // close loading
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Study resources'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(help.message),
                const SizedBox(height: 12),
                ...help.resources.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.type.toUpperCase()}: ${r.title}',
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(r.url,
                          style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tool call failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI test (temporary)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _topic,
            decoration: const InputDecoration(
                labelText: 'Topic', border: OutlineInputBorder()),
            items: kTopics
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _topic = v!),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: kDifficulties
                .map((d) => ButtonSegment(value: d, label: Text(d)))
                .toList(),
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [5, 10, 15]
                .map((n) => ButtonSegment(value: n, label: Text('$n Qs')))
                .toList(),
            selected: {_count},
            onSelectionChanged: (s) => setState(() => _count = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate quiz'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(_error!,
                  style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          ..._questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Q${i + 1}. ${q.text}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...List.generate(4, (n) {
                      final correct = n == q.correctIndex;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: correct
                              ? Colors.green.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${'ABCD'[n]}. ${q.options[n]}'),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text('Why: ${q.explanation}',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _learnMore(q),
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Find study resources'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}