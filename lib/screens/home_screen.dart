import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/rooms_cubit.dart';
import '../cubits/user_cubit.dart';
import '../cubits/user_state.dart';
import '../models/player.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../widgets/action_tile.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/room_tile.dart';
import '../widgets/stat_card.dart';
import 'ai_test_screen.dart';
import 'create_room_screen.dart';
import 'lobby_screen.dart';
import '../utils/daily.dart';
import 'solo_game_screen.dart';
import 'solo_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomsCubit(FirestoreService()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The topic changes every day (rotates through the topic list).
  String _dailyTopic() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return kTopics[dayOfYear % kTopics.length];
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Player _asPlayer(UserModel user) => Player(
    uid: user.uid,
    name: user.displayName,
    photoUrl: user.photoUrl,
  );

  void _openLobby(UserModel user, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(roomId: roomId, user: user),
      ),
    );
  }

  Future<void> _joinRoom(UserModel user, String roomId) async {
    try {
      await FirestoreService().joinRoom(roomId, _asPlayer(user));
      if (!mounted) return;
      _openLobby(user, roomId);
    } on RoomException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not join: $e');
    }
  }

  Future<String?> _askRoomCode() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join with room code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = ctrl.text.trim();
              if (code.length == 6) Navigator.pop(ctx, code);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode(UserModel user) async {
    final code = await _askRoomCode();
    if (code == null) return;
    try {
      final roomId =
      await FirestoreService().joinByCode(code, _asPlayer(user));
      if (!mounted) return;
      _openLobby(user, roomId);
    } on RoomException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not join: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserCubit>().state;
    if (userState is! UserLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = userState.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Battle'),
        actions: [
          // Temporary: delete this when the project is finished.
          IconButton(
            tooltip: 'AI test',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiTestScreen()),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Greeting
              Text('${_greeting()},', style: theme.textTheme.bodyLarge),
              Text('${user.displayName} 👋',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),

              // 2. Quick stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.sports_esports_outlined,
                      label: 'Battles',
                      value: '${user.totalBattles}',
                    ),
                  ),
                  Expanded(
                    child: StatCard(
                      icon: Icons.emoji_events_outlined,
                      label: 'Wins',
                      value: '${user.wins}',
                      color: Colors.amber.shade700,
                    ),
                  ),
                  Expanded(
                    child: StatCard(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Win streak',
                      value: '${user.streak}',
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Daily challenge
              DailyChallengeCard(
                topic: _dailyTopic(),
                bonusPoints: 100,
                onPlay: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SoloGameScreen(
                      user: user,
                      topic: _dailyTopic(),
                      difficulty: 'Medium',
                      questionCount: 5,
                      dailyKey: todayKey(),
                    ),
                  ),
                ),

              ),
              const SizedBox(height: 16),

              // 4. Quick actions
              Row(
                children: [
                  Expanded(
                    child: ActionTile(
                      icon: Icons.smart_toy_outlined,
                      label: 'Solo Practice',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SoloSetupScreen(user: user),
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionTile(
                      icon: Icons.add_circle_outline,
                      label: 'New Battle',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRoomScreen(user: user),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionTile(
                      icon: Icons.login_rounded,
                      label: 'Join Battle',
                      onTap: () => _joinByCode(user),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Active rooms
              Text('Active rooms', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              BlocBuilder<RoomsCubit, RoomsState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state.error != null) {
                    return Text('Could not load rooms: ${state.error}',
                        style: const TextStyle(color: Colors.red));
                  }
                  if (state.rooms.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No public rooms waiting.\nTap "New Battle" to create one!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: state.rooms
                        .map((room) => RoomTile(
                      room: room,
                      onJoin: () => _joinRoom(user, room.id),
                    ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}