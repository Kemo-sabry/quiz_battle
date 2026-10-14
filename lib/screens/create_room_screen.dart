import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/create_room_cubit.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends StatelessWidget {
  final UserModel user;
  const CreateRoomScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateRoomCubit(FirestoreService(), AIService()),
      child: _CreateRoomView(user: user),
    );
  }
}

class _CreateRoomView extends StatefulWidget {
  final UserModel user;
  const _CreateRoomView({required this.user});

  @override
  State<_CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<_CreateRoomView> {
  final _nameCtrl = TextEditingController();
  bool _isPublic = true;
  late String _topic;
  late String _difficulty;
  int _questionCount = 5;
  int _maxPlayers = 4;

  @override
  void initState() {
    super.initState();
    final firstTopic =
    widget.user.topics.isNotEmpty ? widget.user.topics.first : kTopics.first;
    _topic = kTopics.contains(firstTopic) ? firstTopic : kTopics.first;
    _difficulty = kDifficulties.contains(widget.user.difficulty)
        ? widget.user.difficulty
        : 'Medium';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _create() {
    context.read<CreateRoomCubit>().createRoom(
      user: widget.user,
      name: _nameCtrl.text,
      isPublic: _isPublic,
      topic: _topic,
      difficulty: _difficulty,
      questionCount: _questionCount,
      maxPlayers: _maxPlayers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CreateRoomCubit, CreateRoomState>(
      listenWhen: (prev, curr) =>
      prev.roomId != curr.roomId || prev.error != curr.error,
      listener: (context, state) {
        if (state.roomId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LobbyScreen(roomId: state.roomId!, user: widget.user),
            ),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.error!.replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red.shade700,
            ));
        }
      },
      builder: (context, state) {
        final loading = state.loading;

        return PopScope(
          canPop: !loading, // don't leave while the room is being created
          child: Scaffold(
            appBar: AppBar(title: const Text('Create battle room')),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: IgnorePointer(
                      ignoring: loading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            maxLength: 30,
                            decoration: const InputDecoration(
                              labelText: 'Room name (optional)',
                              prefixIcon: Icon(Icons.meeting_room_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_isPublic
                                ? 'Public room'
                                : 'Private room'),
                            subtitle: Text(_isPublic
                                ? 'Anyone can see it on the Home screen'
                                : 'Players join with a 6-digit code'),
                            value: _isPublic,
                            onChanged: (v) => setState(() => _isPublic = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _topic,
                            decoration: const InputDecoration(
                              labelText: 'Topic',
                              border: OutlineInputBorder(),
                            ),
                            items: kTopics
                                .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _topic = v!),
                          ),
                          const SizedBox(height: 20),
                          Text('Difficulty',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: kDifficulties
                                .map((d) =>
                                ButtonSegment(value: d, label: Text(d)))
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
                                .map((n) =>
                                ButtonSegment(value: n, label: Text('$n')))
                                .toList(),
                            selected: {_questionCount},
                            onSelectionChanged: (s) =>
                                setState(() => _questionCount = s.first),
                          ),
                          const SizedBox(height: 20),
                          Text('Max players: $_maxPlayers',
                              style: theme.textTheme.titleSmall),
                          Slider(
                            min: 2,
                            max: 6,
                            divisions: 4,
                            value: _maxPlayers.toDouble(),
                            label: '$_maxPlayers',
                            onChanged: (v) =>
                                setState(() => _maxPlayers = v.round()),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: loading ? null : _create,
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(16)),
                            child: loading
                                ? const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Generating questions...'),
                              ],
                            )
                                : const Text('Create Room'),
                          ),
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'AI is writing your quiz. This can take up to a minute.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}