import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubits/auth_cubit.dart';
import 'cubits/auth_state.dart';
import 'cubits/user_cubit.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/user_gate.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const QuizBattleApp());
}

class QuizBattleApp extends StatelessWidget {
  const QuizBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(AuthService(), FirestoreService()),
      child: MaterialApp(
        title: 'Quiz Battle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides which screen to show based on login state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is Authenticated) {
          // The key makes a fresh UserCubit when a different user logs in.
          return BlocProvider(
            key: ValueKey(state.user.uid),
            create: (_) => UserCubit(FirestoreService(), state.user.uid),
            child: const UserGate(),
          );
        }
        return const AuthScreen(); // Unauthenticated, loading, or error
      },
    );
  }
}