import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/user_cubit.dart';
import '../cubits/user_state.dart';
import 'ai_test_screen.dart';

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UserCubit>().state;
    final user = state is UserLoaded ? state.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Home (temporary)')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, ${user?.displayName ?? ''}!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Topics: ${user?.topics.join(', ')}'),
            Text('Difficulty: ${user?.difficulty}'),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiTestScreen()),
              ),
              child: const Text('AI test (temporary)'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<AuthCubit>().signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}