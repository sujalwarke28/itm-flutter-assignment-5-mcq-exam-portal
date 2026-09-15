import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import 'admin/admin_dashboard.dart';
import 'auth/login_screen.dart';
import 'student/student_dashboard.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const _LoadingView();
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.authenticated:
            return auth.isAdmin ? const AdminDashboard() : const StudentDashboard();
        }
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
