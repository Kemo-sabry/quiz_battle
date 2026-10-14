import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/user_cubit.dart';
import '../cubits/user_state.dart';
import 'main_shell.dart';
import 'profile_setup_screen.dart';

/// Shows Profile Setup for first-time users, otherwise the main app.
class UserGate extends StatelessWidget {
  const UserGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        if (state is UserError) {
          return Scaffold(
            body: Center(child: Text('Error: ${state.message}')),
          );
        }
        if (state is UserLoaded) {
          return state.user.profileComplete
              ? const MainShell()
              : ProfileSetupScreen(user: state.user);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}