import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/exam_service.dart';
import '../../utils/app_theme.dart';
import 'manage_exams.dart';
import 'reports.dart';
import 'upload_excel.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                      child: profile?.photoUrl == null
                          ? Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.name ?? 'Admin', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(profile?.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Manage', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.3,
              children: [
                _ActionCard(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Exam',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadExcelScreen())),
                ),
                _ActionCard(
                  icon: Icons.assignment_rounded,
                  label: 'Manage Exams',
                  color: AppColors.success,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageExamsScreen())),
                ),
                _ActionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  color: AppColors.warning,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
                ),
                _ActionCard(
                  icon: Icons.groups_rounded,
                  label: 'Students',
                  color: AppColors.neutral,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _StudentsListScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ??
            () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming up next'))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentsListScreen extends StatefulWidget {
  const _StudentsListScreen();

  @override
  State<_StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<_StudentsListScreen> {
  final _examService = ExamService();
  late Future<List<Map<String, dynamic>>> _future = _examService.listStudents();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => _future = _examService.listStudents()),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: [const SizedBox(height: 120), Center(child: Text('Failed to load students: ${snapshot.error}'))]);
              }
              final students = snapshot.data ?? [];
              if (students.isEmpty) {
                return ListView(children: const [SizedBox(height: 120), Center(child: Text('No students have signed up yet.'))]);
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: students.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final s = students[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: s['photoUrl'] != null ? NetworkImage(s['photoUrl'] as String) : null,
                        child: s['photoUrl'] == null ? Icon(Icons.person_rounded, color: AppColors.primary) : null,
                      ),
                      title: Text(s['name'] as String? ?? 'Unnamed'),
                      subtitle: Text(s['email'] as String? ?? ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
