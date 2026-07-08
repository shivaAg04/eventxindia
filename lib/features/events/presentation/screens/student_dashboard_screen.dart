import 'package:flutter/material.dart';

import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../profile/presentation/bloc/student_profile_cubit.dart';
import '../../../profile/presentation/screens/student_profile_screen.dart';
import '../bloc/event_discovery_bloc.dart';
import 'student_active_events_screen.dart';
import 'student_events_screen.dart';

/// Top-level student dashboard hosting the three activity views (R4.1–R4.7).
///
/// A bottom navigation bar switches between:
/// * Active events — streams the active event set (R4.1).
/// * My events — the combined Applied + Attendance destination: an inner tab
///   switcher between the student's applications (with combinable status and
///   active/inactive event filters, R4.2, R4.3) and their per-event attendance
///   with check-in / check-out (R4.4).
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
    required this.createApplicationBloc,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.createStudentProfileCubit,
    super.key,
  });

  /// The id of the signed-in student.
  final String studentId;

  /// Factory for the active-events tab's [EventDiscoveryBloc].
  final EventDiscoveryBloc Function() createEventDiscoveryBloc;

  /// Factory for the [ApplicationBloc] backing the apply action reached from the
  /// active-events tab (R8.6).
  final ApplicationBloc Function() createApplicationBloc;

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
    StudentActiveEventsScreen(
      createBloc: widget.createEventDiscoveryBloc,
      studentId: widget.studentId,
      createApplicationBloc: widget.createApplicationBloc,
      createStudentApplicationsCubit: widget.createStudentApplicationsCubit,
    ),
    StudentEventsScreen(
      studentId: widget.studentId,
      createStudentApplicationsCubit: widget.createStudentApplicationsCubit,
      createAttendanceBloc: widget.createAttendanceBloc,
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
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My events',
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
