import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/widgets/logout_button.dart';
import '../../domain/entities/student.dart';
import '../bloc/student_profile_cubit.dart';

/// Student dashboard profile view (R4.6, R4.7).
///
/// Owns its [StudentProfileCubit] (built from the injected [createCubit]
/// factory and started with [StudentProfileCubit.load] for [uid]). It renders
/// the student's full name, phone number, gender, date of birth, city, height,
/// and profile photo (R4.6). When the read fails it shows a read-failure
/// indication that the data could not be loaded (R4.7).
///
/// The screen never talks to a use case or repository directly.
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({
    required this.uid,
    required this.createCubit,
    super.key,
  });

  /// The id of the student whose profile is shown.
  final String uid;

  /// Factory for the screen's [StudentProfileCubit] (resolved from DI).
  final StudentProfileCubit Function() createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StudentProfileCubit>(
      create: (_) => createCubit()..load(uid),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: const <Widget>[LogoutButton()],
        ),
        body: BlocBuilder<StudentProfileCubit, StudentProfileState>(
          builder: (BuildContext context, StudentProfileState state) {
            return switch (state) {
              StudentProfileLoaded(:final Student student) =>
                _ProfileView(student: student),
              StudentProfileFailure(:final String message) => _ProfileMessage(
                  key: const ValueKey<String>('student-profile-error'),
                  icon: Icons.error_outline,
                  message: 'Your profile could not be loaded.\n$message',
                ),
              StudentProfileLoading() =>
                const Center(child: CircularProgressIndicator()),
            };
          },
        ),
      ),
    );
  }
}

/// Renders the student's profile fields (R4.6).
class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: student.profilePhotoPath.isEmpty
                ? null
                : NetworkImage(student.profilePhotoPath),
            child: student.profilePhotoPath.isEmpty
                ? const Icon(Icons.person, size: 48)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        _ProfileField(label: 'Full name', value: student.fullName),
        _ProfileField(label: 'Phone number', value: student.phone.e164),
        _ProfileField(label: 'Gender', value: student.gender.wireName),
        _ProfileField(
          label: 'Date of birth',
          value: _formatDate(student.dateOfBirth),
        ),
        _ProfileField(label: 'City', value: student.city),
        _ProfileField(label: 'Height', value: '${student.heightCm} cm'),
      ],
    );
  }

  /// Formats a [date] as `YYYY-MM-DD`.
  static String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}

/// A single labelled profile field row.
class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// A centered icon + message for the profile read-failure indication (R4.7).
class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
