import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/leaderboard_cubit.dart';
import '../cubits/user_cubit.dart';
import '../cubits/user_state.dart';
import '../services/firestore_service.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserCubit>().state;
    if (userState is! UserLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = userState.user.uid;

    return BlocProvider(
      key: ValueKey(uid),
      create: (_) => LeaderboardCubit(FirestoreService(), uid),
      child: _LeaderboardView(myUid: uid),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  final String myUid;
  const _LeaderboardView({required this.myUid});

  Future<void> _addFriend(BuildContext context) async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Friend's email",
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (email == null || !context.mounted) return;

    try {
      final name = await context.read<LeaderboardCubit>().addFriend(email);
      if (!context.mounted) return;
      _snack(context, '$name added to your friends');
    } on FriendException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not add friend: $e');
    }
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.public), text: 'Global'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Friends'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _globalTab(context),
            _friendsTab(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Global tab
  // ---------------------------------------------------------------

  Widget _globalTab(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        if (state.loadingGlobal) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.top.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load the leaderboard:\n${state.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (state.top.isEmpty) {
          return const Center(child: Text('No players yet. Play a battle!'));
        }

        final ranks = computeRanks(state.top.map((u) => u.totalPoints).toList());
        final inTop = state.top.any((u) => u.uid == myUid);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.top.length,
                    itemBuilder: (context, i) {
                      final user = state.top[i];
                      return LeaderboardTile(
                        rank: ranks[i],
                        user: user,
                        isMe: user.uid == myUid,
                      );
                    },
                  ),
                ),
                // Outside the top 50: always show where I stand.
                if (!inTop && state.myRank != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_pin_circle_outlined),
                        const SizedBox(width: 8),
                        Text(
                          'Your rank: #${state.myRank}  •  ${state.myPoints} pts',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // Friends tab
  // ---------------------------------------------------------------

  Widget _friendsTab(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        if (state.loadingFriends) {
          return const Center(child: CircularProgressIndicator());
        }

        final ranks =
        computeRanks(state.friends.map((u) => u.totalPoints).toList());
        final onlyMe = state.friends.length <= 1;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => context.read<LeaderboardCubit>().refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addFriend(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add a friend by email'),
                  ),
                  const SizedBox(height: 16),
                  if (onlyMe)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'You have no friends yet.\n'
                            'Add a friend with the email they signed up with, '
                            'and you will compete on this board.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...state.friends.asMap().entries.map((entry) {
                    final i = entry.key;
                    final user = entry.value;
                    final isMe = user.uid == myUid;
                    return LeaderboardTile(
                      rank: ranks[i],
                      user: user,
                      isMe: isMe,
                      trailingAction: isMe
                          ? null
                          : IconButton(
                        tooltip: 'Remove friend',
                        icon: const Icon(Icons.close),
                        onPressed: () => context
                            .read<LeaderboardCubit>()
                            .removeFriend(user.uid),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}