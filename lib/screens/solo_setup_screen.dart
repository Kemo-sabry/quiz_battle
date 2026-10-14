import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'solo_game_screen.dart';

class SoloSetupScreen extends StatefulWidget {
  final UserModel user;
  const SoloSetupScreen({super.key, required this.user});

  @override
  State<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends State<SoloSetupScreen> {
  late String _topic;
  late String _difficulty;
  int _count = 5;

  @override
  void initState() {
    super.initState();
    final first =
    widget.user.topics.isNotEmpty ? widget.user.topics.first : kTopics.first;
    _topic = kTopics.contains(first) ? first : kTopics.first;
    _difficulty = kDifficulties.contains(widget.user.difficulty)
        ? widget.user.difficulty
        : 'Medium';
  }

  void _start() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SoloGameScreen(
          user: widget.user,
          topic: _topic,
          difficulty: _difficulty,
          questionCount: _count,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solo Practice')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You play against an AI bot. The higher the '
                                  'difficulty, the better the bot answers.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _topic,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      border: OutlineInputBorder(),
                    ),
                    items: kTopics
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _topic = v!),
                  ),
                  const SizedBox(height: 20),
                  Text('Difficulty', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: kDifficulties
                        .map((d) => ButtonSegment(value: d, label: Text(d)))
                        .toList(),
                    selected: {_difficulty},
                    onSelectionChanged: (s) =>
                        setState(() => _difficulty = s.first),
                  ),
                  const SizedBox(height: 20),
                  Text('Number of questions',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [5, 10, 15]
                        .map((n) => ButtonSegment(value: n, label: Text('$n')))
                        .toList(),
                    selected: {_count},
                    onSelectionChanged: (s) =>
                        setState(() => _count = s.first),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}