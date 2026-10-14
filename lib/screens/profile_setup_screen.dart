import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/user_cubit.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class ProfileSetupScreen extends StatefulWidget {
  final UserModel user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final Set<String> _topics = {};
  String _difficulty = 'Medium';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleTopic(String topic, bool selected) {
    setState(() {
      if (selected) {
        if (_topics.length >= kMaxTopics) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('You can pick up to 3 topics'),
            ));
          return;
        }
        _topics.add(topic);
      } else {
        _topics.remove(topic);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_topics.length < kMinTopics) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Pick at least 2 topics'),
        ));
      return;
    }

    setState(() => _saving = true);
    try {
      // When this succeeds, the UserGate sees profileComplete = true
      // and moves to Home on its own. No manual navigation needed.
      await context.read<UserCubit>().completeProfile(
        name: _nameCtrl.text,
        topics: _topics.toList(),
        difficulty: _difficulty,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('What should we call you?',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter a display name';
                        if (value.length < 2) return 'Too short';
                        if (value.length > 20) return 'Max 20 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Favorite topics',
                              style: theme.textTheme.titleMedium),
                        ),
                        Text('${_topics.length}/$kMaxTopics',
                            style: theme.textTheme.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Pick 2 or 3',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kTopics.map((topic) {
                        return FilterChip(
                          label: Text(topic),
                          selected: _topics.contains(topic),
                          onSelected: (sel) => _toggleTopic(topic, sel),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Text('Preferred difficulty',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: kDifficulties
                          .map((d) => ButtonSegment(value: d, label: Text(d)))
                          .toList(),
                      selected: {_difficulty},
                      onSelectionChanged: (s) =>
                          setState(() => _difficulty = s.first),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                      child: _saving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Save and continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}