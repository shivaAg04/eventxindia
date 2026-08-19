import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dashboard_header.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/domain/rating_stats.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../../domain/entities/student.dart';
import '../bloc/student_profile_cubit.dart';

/// Student dashboard profile view (R4.6, R4.7).
///
/// Shows the student's identity + headline stats (average rating, events
/// completed, total earnings, attendance) and their personal information. The
/// stats are composed from the same wallet/applications/ratings streams the
/// other tabs use, so no new backend surface is needed.
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({
    required this.uid,
    required this.createCubit,
    required this.ratingsStream,
    required this.createWalletCubit,
    required this.createStudentApplicationsCubit,
    super.key,
  });

  final String uid;
  final StudentProfileCubit Function() createCubit;
  final Stream<List<RatingEntry>> ratingsStream;
  final WalletCubit Function() createWalletCubit;
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<StudentProfileCubit>(
          create: (_) => createCubit()..load(uid),
        ),
        BlocProvider<WalletCubit>(
          create: (_) => createWalletCubit()..watch(uid),
        ),
        BlocProvider<StudentApplicationsCubit>(
          create: (_) => createStudentApplicationsCubit()..watch(studentId: uid),
        ),
      ],
      child: Scaffold(
        body: Column(
          children: <Widget>[
            DashboardHeader(
              title: 'Profile',
              subtitle: 'Manage your personal information and preferences',
              trailing: HeaderIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Log out',
                onPressed: () =>
                    context.read<AuthBloc>().add(const SignedOut()),
              ),
              mascot: Image.asset(
                'assets/images/profile.png',
                width: 190,
                height: 150,
                fit: BoxFit.fitWidth,
              ),
            ),
            Expanded(
              child: BlocBuilder<StudentProfileCubit, StudentProfileState>(
                builder: (BuildContext context, StudentProfileState state) {
                  return switch (state) {
                    StudentProfileLoaded(:final Student student) =>
                      _ProfileView(student: student, ratingsStream: ratingsStream),
                    StudentProfileFailure(:final String message) =>
                      _ProfileMessage(
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
          ],
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.student, required this.ratingsStream});

  final Student student;
  final Stream<List<RatingEntry>> ratingsStream;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        _IdentityCard(student: student, ratingsStream: ratingsStream),
        const SizedBox(height: 20),
        Text('Personal Information',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _InfoCard(student: student),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const ValueKey<String>('profile-logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.3),
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Logout'),
          onPressed: () => context.read<AuthBloc>().add(const SignedOut()),
        ),
      ],
    );
  }
}

/// The white identity card: avatar, name, role badge, and the 4 headline stats.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.student, required this.ratingsStream});

  final Student student;
  final Stream<List<RatingEntry>> ratingsStream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  image: student.profilePhotoPath.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(student.profilePhotoPath),
                          fit: BoxFit.cover),
                ),
                child: student.profilePhotoPath.isEmpty
                    ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.verified_user_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text('Event Staff',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatsRow(ratingsStream: ratingsStream),
        ],
      ),
    );
  }
}

/// The four headline stat cards (rating, events completed, earnings, attendance).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.ratingsStream});

  final Stream<List<RatingEntry>> ratingsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RatingEntry>>(
      stream: ratingsStream,
      builder: (BuildContext context,
          AsyncSnapshot<List<RatingEntry>> ratingsSnap) {
        final List<RatingEntry> ratings =
            ratingsSnap.data ?? const <RatingEntry>[];
        final double? average = averageStars(ratings);

        final WalletState walletState = context.watch<WalletCubit>().state;
        final Wallet? wallet =
            walletState is WalletLoaded ? walletState.wallet : null;
        final int completed = wallet?.creditsPerEvent.length ?? 0;
        final String earnings = wallet == null
            ? '₹0.00'
            : '₹${wallet.credited.formatted}';

        final StudentApplicationsState appState =
            context.watch<StudentApplicationsCubit>().state;
        final int approved = appState is StudentApplicationsLoaded
            ? appState.applications
                .where((Application a) => a.status.wireName == 'Approved')
                .length
            : 0;
        final int attendancePct =
            approved == 0 ? 0 : ((completed / approved) * 100).round();

        // IntrinsicHeight bounds the row's height so `stretch` can give every
        // card the same height; without it the row sits in the unbounded
        // ListView and `stretch` forces an infinite-height constraint.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StatCard(
                icon: Icons.star_rounded,
                color: AppColors.primary,
                value: formatAverage(average),
                label: 'Average Rating',
                footer: average == null
                    ? const _NoRatings()
                    : StarRatingBar(stars: average, size: 12),
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.event_note_rounded,
                color: const Color(0xFF3B82F6),
                value: '$completed',
                label: 'Events Completed',
                footerText: 'Keep going!',
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
                value: earnings,
                label: 'Total Earnings',
                footerText: 'All time',
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.track_changes_rounded,
                color: AppColors.accent,
                value: '$attendancePct%',
                label: 'Attendance',
                footerText: 'Keep it up!',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoRatings extends StatelessWidget {
  const _NoRatings();

  @override
  Widget build(BuildContext context) => const Text(
        'No ratings yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9, color: AppColors.textMuted),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.footer,
    this.footerText,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final Widget? footer;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: <Widget>[
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            if (footer != null)
              footer!
            else if (footerText != null)
              Text(
                footerText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600, color: color),
              ),
          ],
        ),
      ),
    );
  }
}

/// The white "Personal Information" card: one icon+label+value row per field.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final List<_InfoRowData> rows = <_InfoRowData>[
      _InfoRowData(Icons.person_rounded, AppColors.primary, 'Full Name',
          student.fullName),
      _InfoRowData(Icons.phone_rounded, const Color(0xFF3B82F6),
          'Phone Number', _phone(student)),
      _InfoRowData(Icons.calendar_today_rounded, const Color(0xFF3B82F6),
          'Date of Birth', _formatDate(student.dateOfBirth)),
      _InfoRowData(Icons.person_outline_rounded, const Color(0xFF14B8A6),
          'Gender', student.gender.wireName),
      _InfoRowData(Icons.place_rounded, const Color(0xFFF97316), 'City',
          student.city),
      _InfoRowData(Icons.straighten_rounded, AppColors.accent, 'Height',
          '${student.heightCm} cm'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            _InfoRow(data: rows[i], last: i == rows.length - 1),
        ],
      ),
    );
  }

  static String _phone(Student s) {
    final String e164 = s.phone.e164;
    // Show the 10-digit national number when it's the usual +91… form.
    return e164.startsWith('+91') && e164.length == 13
        ? e164.substring(3)
        : e164;
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) {
    final DateTime l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }
}

class _InfoRowData {
  const _InfoRowData(this.icon, this.color, this.label, this.value);
  final IconData icon;
  final Color color;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data, required this.last});

  final _InfoRowData data;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(data.icon, size: 20, color: data.color),
          const SizedBox(width: 12),
          Text(data.label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

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
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
