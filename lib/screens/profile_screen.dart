import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/user_cubit.dart';
import '../cubits/user_state.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/player_avatar.dart';
import '../widgets/stat_card.dart';

// Same thresholds as UserModel.level.
const List<String> _levelNames = ['Bronze', 'Silver', 'Gold', 'Diamond'];
const List<int> _levelStarts = [0, 500, 2000, 5000];

int _levelIndex(int points) {
  var idx = 0;
  for (var i = 0; i < _levelStarts.length; i++) {
    if (points >= _levelStarts[i]) idx = i;
  }
  return idx;
}

Color _levelColor(int i) {
  switch (i) {
    case 0:
      return Colors.brown.shade400;
    case 1:
      return Colors.blueGrey.shade400;
    case 2:
      return Colors.amber.shade700;
    default:
      return Colors.cyan.shade600;
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------

  Future<void> _editName(BuildContext context, UserModel user) async {
    final cubit = context.read<UserCubit>();
    final ctrl = TextEditingController(text: user.displayName);
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit display name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter a display name';
              if (value.length < 2) return 'Too short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name == user.displayName) return;
    try {
      await cubit.updateName(name);
      if (context.mounted) _snack(context, 'Name updated');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not update name: $e');
    }
  }

  Future<void> _editTopics(BuildContext context, UserModel user) async {
    final cubit = context.read<UserCubit>();
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TopicsDialog(initial: user.topics),
    );
    if (picked == null) return;
    try {
      await cubit.updateTopics(picked);
      if (context.mounted) _snack(context, 'Topics updated');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not update topics: $e');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordDialog(onSubmit: authCubit.changePassword),
    );
    if (done == true && context.mounted) {
      _snack(context, 'Password updated');
    }
  }

  Future<void> _changeEmail(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => _EmailDialog(onSubmit: authCubit.requestEmailChange),
    );
    if (newEmail != null && context.mounted) {
      _snack(
        context,
        'Verification link sent to $newEmail. '
            'Your email changes after you click it.',
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) authCubit.signOut();
  }

  // ---------------------------------------------------------------
  // Screen
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UserCubit>().state;
    if (state is! UserLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = state.user;
    final theme = Theme.of(context);
    final canChange = context.read<AuthCubit>().canChangePassword;

    // Level and progress to the next level.
    final levelIdx = _levelIndex(user.totalPoints);
    final levelColor = _levelColor(levelIdx);
    final isTop = levelIdx == _levelNames.length - 1;
    double progress = 1;
    String nextText = 'Top level reached 🏆';
    if (!isTop) {
      final start = _levelStarts[levelIdx];
      final end = _levelStarts[levelIdx + 1];
      progress = (user.totalPoints - start) / (end - start);
      nextText =
      '${end - user.totalPoints} pts to ${_levelNames[levelIdx + 1]}';
    }

    final difficulty =
    kDifficulties.contains(user.difficulty) ? user.difficulty : 'Medium';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Center(
                child: PlayerAvatar(
                  name: user.displayName,
                  photoUrl: user.photoUrl,
                  radius: 48,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editName(context, user),
                  ),
                ],
              ),
              Center(
                child: Text(user.email, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 14),

              // Level badge
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium,
                              color: levelColor, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            '${_levelNames[levelIdx]} level',
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: levelColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 10,
                          color: levelColor,
                          backgroundColor: levelColor.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(nextText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.sports_esports_outlined,
                      label: 'Total battles',
                      value: '${user.totalBattles}',
                    ),
                  ),
                  Expanded(
                    child: StatCard(
                      icon: Icons.percent,
                      label: 'Win rate',
                      value: '${user.winRate.round()}%',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Current streak',
                      value: '${user.streak}',
                      color: Colors.deepOrange,
                    ),
                  ),
                  Expanded(
                    child: StatCard(
                      icon: Icons.star_rounded,
                      label: 'Total points',
                      value: '${user.totalPoints}',
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quiz settings
              Text('Quiz settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Favorite topics',
                                style: theme.textTheme.titleSmall),
                          ),
                          TextButton.icon(
                            onPressed: () => _editTopics(context, user),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: user.topics
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text('Preferred difficulty',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: kDifficulties
                            .map((d) =>
                            ButtonSegment(value: d, label: Text(d)))
                            .toList(),
                        selected: {difficulty},
                        onSelectionChanged: (s) => context
                            .read<UserCubit>()
                            .updateDifficulty(s.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Account settings
              Text('Account', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: canChange
                    ? Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changePassword(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Change email'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changeEmail(context),
                    ),
                  ],
                )
                    : const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Signed in with Google'),
                  subtitle: Text(
                    'Your password and email are managed in your '
                        'Google account.',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// Dialogs
// ===================================================================

class _TopicsDialog extends StatefulWidget {
  final List<String> initial;
  const _TopicsDialog({required this.initial});

  @override
  State<_TopicsDialog> createState() => _TopicsDialogState();
}

class _TopicsDialogState extends State<_TopicsDialog> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final valid =
        _selected.length >= kMinTopics && _selected.length <= kMaxTopics;

    return AlertDialog(
      title: Text('Favorite topics (${_selected.length}/$kMaxTopics)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick 2 or 3'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kTopics.map((topic) {
                return FilterChip(
                  label: Text(topic),
                  selected: _selected.contains(topic),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        if (_selected.length < kMaxTopics) _selected.add(topic);
                      } else {
                        _selected.remove(topic);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, _selected.toList())
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final Future<void> Function(String current, String next) onSubmit;
  const _PasswordDialog({required this.onSubmit});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_current.text, _new.text);
      if (mounted) Navigator.pop(context, true);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                v != _new.text ? 'Passwords do not match' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Update'),
        ),
      ],
    );
  }
}

class _EmailDialog extends StatefulWidget {
  final Future<void> Function(String current, String newEmail) onSubmit;
  const _EmailDialog({required this.onSubmit});

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final newEmail = _email.text.trim();
    try {
      await widget.onSubmit(_current.text, newEmail);
      if (mounted) Navigator.pop(context, newEmail);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change email'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We will send a verification link to the new address. '
                    'Your email changes after you click it.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter the new email';
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(value);
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Send link'),
        ),
      ],
    );
  }
}