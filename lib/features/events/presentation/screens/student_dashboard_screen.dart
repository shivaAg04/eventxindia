import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../applications/presentation/screens/student_applications_screen.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../attendance/presentation/screens/attendance_history_screen.dart';
import '../../../profile/presentation/bloc/student_profile_cubit.dart';
import '../../../profile/presentation/screens/student_profile_screen.dart';
import '../bloc/event_discovery_bloc.dart';
import 'student_active_events_screen.dart';

/// Top-level student dashboard hosting the five activity views (R4.1–R4.7).
///
/// A bottom navigation bar switches between:
/// * Active events — streams the active event set (R4.1).
/// * Applied — every event the student applied to (R4.2).
/// * Approved — events whose application is Approved (R4.3).
/// * Attendance — the student's attendance history (R4.4).
/// * Profile — the student's profile data (R4.6).
///
/// Each tab owns its own BLoC/Cubit, built from the injected factories so the
/// dashboard stays backend-agnostic (presentation → domain only). Empty-state
/// and read-failure indications are rendered by the individual tab screens
/// (R4.7).
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    required this.studentId,
    required this.createEventDiscoveryBloc,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.createStudentProfileCubit,
    super.key,
  });

  /// The id of the signed-in student.
  final String studentId;

  /// Factory for the active-events tab's [EventDiscoveryBloc].
  final EventDiscoveryBloc Function() createEventDiscoveryBloc;

  /// Factory for the applied/approved tabs' [StudentApplicationsCubit].
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;

  /// Factory for the attendance tab's [AttendanceBloc].
  final AttendanceBloc Function() createAttendanceBloc;

  /// Factory for the profile tab's [StudentProfileCubit].
  final StudentProfileCubit Function() createStudentProfileCubit;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _index = 0;

  late final List<Widget> _tabs = <Widget>[
    StudentActiveEventsScreen(createBloc: widget.createEventDiscoveryBloc),
    StudentApplicationsScreen(
      studentId: widget.studentId,
      createCubit: widget.createStudentApplicationsCubit,
    ),
    StudentApplicationsScreen(
      studentId: widget.studentId,
      createCubit: widget.createStudentApplicationsCubit,
      statusFilter: ApplicationStatus.approved,
    ),
    _AttendanceHistoryTab(
      studentId: widget.studentId,
      createBloc: widget.createAttendanceBloc,
    ),
    StudentProfileScreen(
      uid: widget.studentId,
      createCubit: widget.createStudentProfileCubit,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Active',
          ),
          NavigationDestination(
            icon: Icon(Icons.outbox_outlined),
            selectedIcon: Icon(Icons.outbox),
            label: 'Applied',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Approved',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Provides an [AttendanceBloc] for the existing [AttendanceHistoryScreen] and
/// starts the history stream for [studentId] (R4.4).
class _AttendanceHistoryTab extends StatelessWidget {
  const _AttendanceHistoryTab({
    required this.studentId,
    required this.createBloc,
  });

  final String studentId;
  final AttendanceBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AttendanceBloc>(
      create: (_) => createBloc()..add(HistoryWatchStarted(studentId)),
      child: AttendanceHistoryScreen(studentId: studentId),
    );
  }
}
