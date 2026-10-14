import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/lobby_cubit.dart';
import '../models/battle_room.dart';
import '../models/player.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/chat_box.dart';
import '../widgets/player_tile.dart';
import 'arena_screen.dart';

class LobbyScreen extends StatelessWidget {
  final String roomId;
  final UserModel user;

  const LobbyScreen({super.key, required this.roomId, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LobbyCubit(FirestoreService(), roomId, user),
      child: _LobbyView(user: user),
    );
  }
}

class _LobbyView extends StatefulWidget {
  final UserModel user;
  const _LobbyView({required this.user});

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  bool _navigated = false; // already moved on to the arena or closed
  bool _leaving = false; // the user pressed back

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await context.read<LobbyCubit>().leave();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleReady(bool ready) async {
    try {
      await context.read<LobbyCubit>().setReady(ready);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _start() async {
    try {
      await context.read<LobbyCubit>().startBattle();
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user.uid;

    return BlocConsumer<LobbyCubit, LobbyState>(
      listener: (context, state) {
        if (_leaving || _navigated) return;

        // The room was deleted.
        if (state.closed) {
          _navigated = true;
          _snack('This room was closed.');
          Navigator.of(context).pop();
          return;
        }

        // The host started the battle: everyone moves to the arena together.
        final room = state.room;
        if (room != null && room.status == RoomStatus.active) {
          _navigated = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ArenaScreen(roomId: room.id, user: widget.user),
            ),
          );
        }
      },
      builder: (context, state) {
        final room = state.room;

        if (state.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lobby')),
            body: Center(child: Text('Error: ${state.error}')),
          );
        }
        if (state.loading || room == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isHost = room.hostId == uid;
        Player? me;
        for (final p in room.players) {
          if (p.uid == uid) me = p;
        }
        final theme = Theme.of(context);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            appBar: AppBar(title: Text(room.name)),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Room info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.topic,
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text('Host: ${room.hostName}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  avatar:
                                  const Icon(Icons.speed, size: 18),
                                  label: Text(room.difficulty),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.quiz_outlined,
                                      size: 18),
                                  label: Text(
                                      '${room.questionCount} questions'),
                                ),
                                Chip(
                                  avatar: Icon(
                                      room.isPublic
                                          ? Icons.public
                                          : Icons.lock_outline,
                                      size: 18),
                                  label: Text(
                                      room.isPublic ? 'Public' : 'Private'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Room code (private rooms)
                    if (!room.isPublic && room.roomCode != null)
                      Card(
                        color: theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text('Room code'),
                                    Text(
                                      room.roomCode!,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                          letterSpacing: 6,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Copy code',
                                icon: const Icon(Icons.copy),
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: room.roomCode!));
                                  _snack('Room code copied');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    Text(
                      'Players (${room.players.length}/${room.maxPlayers})',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...room.players.map((p) => PlayerTile(
                      player: p,
                      isHost: p.uid == room.hostId,
                      isMe: p.uid == uid,
                    )),

                    // Ready checkbox
                    Card(
                      child: CheckboxListTile(
                        value: me?.isReady ?? false,
                        onChanged: me == null
                            ? null
                            : (v) => _toggleReady(v ?? false),
                        title: const Text("I'm ready"),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Start button (host only)
                    if (isHost) ...[
                      FilledButton.icon(
                        onPressed: room.canStart ? _start : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Battle'),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(16)),
                      ),
                      if (!room.canStart)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Waiting for at least 2 ready players...',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ] else
                      const Text(
                        'Waiting for the host to start the battle...',
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 16),

                    // Chat
                    ChatBox(
                      messages: state.messages,
                      myUid: uid,
                      onSend: (text) =>
                          context.read<LobbyCubit>().sendMessage(text),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}