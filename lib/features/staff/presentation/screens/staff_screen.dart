import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/entities/staff_role.dart';
import '../../domain/usecases/add_staff.dart';
import '../bloc/staff_cubit.dart';

/// The vendor's staff-management screen: view, add, and remove staff members,
/// each with a predefined [StaffRole] scoping their access.
class StaffScreen extends StatelessWidget {
  const StaffScreen({
    required this.vendorId,
    required this.createCubit,
    super.key,
  });

  final String vendorId;
  final StaffCubit Function() createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StaffCubit>(
      create: (_) => createCubit()..watch(vendorId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        floatingActionButton: Builder(
          builder: (BuildContext inner) => FloatingActionButton.extended(
            key: const ValueKey<String>('staff-add-fab'),
            onPressed: () => _openAddDialog(inner),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add staff'),
          ),
        ),
        body: BlocBuilder<StaffCubit, StaffState>(
          builder: (BuildContext context, StaffState state) {
            return switch (state) {
              StaffLoading() =>
                const Center(child: CircularProgressIndicator()),
              StaffFailure(:final String message) => _Message(
                  icon: Icons.error_outline,
                  text: 'Could not load staff.\n$message',
                ),
              StaffLoaded(:final List<StaffMember> staff) => staff.isEmpty
                  ? const _Message(
                      icon: Icons.groups_2_outlined,
                      text: 'No staff yet.\nTap "Add staff" to invite someone '
                          'to help manage your events.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: staff.length,
                      itemBuilder: (_, int i) => _StaffTile(staff: staff[i]),
                    ),
            };
          },
        ),
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final StaffCubit cubit = context.read<StaffCubit>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final _AddResult? result = await showDialog<_AddResult>(
      context: context,
      builder: (_) => BlocProvider<StaffCubit>.value(
        value: cubit,
        child: const _AddStaffDialog(),
      ),
    );
    if (result == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }
}

/// One staff member row: name, phone, role, and status, with a remove action.
class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.staff});

  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: ValueKey<String>('staff-${staff.staffId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                staff.name.isEmpty ? '?' : staff.name.characters.first,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    staff.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(staff.phone, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _Pill(
                        text: staff.role.label,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      _Pill(
                        text: staff.active ? 'Active' : 'Invited',
                        color: staff.active
                            ? AppColors.success
                            : AppColors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey<String>('staff-remove-${staff.staffId}'),
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _confirmRemove(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final StaffCubit cubit = context.read<StaffCubit>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove staff?'),
        content: Text(
          '${staff.name} will lose access to your events.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final Result<Unit, Failure> result = await cubit.remove(staff.staffId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result.isOk
            ? '${staff.name} removed.'
            : 'Could not remove staff. Please try again.'),
      ));
  }
}

/// The outcome of the add-staff dialog, passed back to show a snackbar.
class _AddResult {
  const _AddResult(this.message);
  final String message;
}

/// The "add staff" dialog: name, 10-digit phone, and a role picker.
class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  StaffRole _role = StaffRole.manager;
  String? _nameError;
  String? _phoneError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _phoneError = null;
      _busy = true;
    });
    final Result<StaffMember, Failure> result =
        await context.read<StaffCubit>().add(StaffInput(
              name: _name.text,
              rawPhone: _phone.text,
              role: _role,
            ));
    if (!mounted) {
      return;
    }
    result.fold<void>(
      (StaffMember s) =>
          Navigator.of(context).pop(_AddResult('${s.name} added as staff.')),
      (Failure f) {
        if (f is ValidationFailure) {
          setState(() {
            _busy = false;
            _nameError = _errorFor(f, 'name');
            _phoneError = _errorFor(f, 'phone');
          });
        } else {
          // Duplicate / persistence — report and close.
          Navigator.of(context).pop(_AddResult(f.message));
        }
      },
    );
  }

  String? _errorFor(ValidationFailure f, String field) {
    for (final FieldError e in f.fieldErrors) {
      if (e.field == field) {
        return e.message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('staff-name-field'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('staff-phone-field'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91 ',
                counterText: '',
                errorText: _phoneError,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StaffRole>(
              key: const ValueKey<String>('staff-role-field'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: <DropdownMenuItem<StaffRole>>[
                for (final StaffRole r in StaffRole.values)
                  DropdownMenuItem<StaffRole>(
                    value: r,
                    child: Text(r.label),
                  ),
              ],
              onChanged: (StaffRole? r) =>
                  setState(() => _role = r ?? _role),
            ),
            const SizedBox(height: 6),
            Text(
              _roleHint(_role),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('staff-add-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  static String _roleHint(StaffRole role) {
    final List<String> can = <String>[
      if (role.canManageApplicants) 'manage applicants',
      if (role.canManageAttendance) 'manage attendance',
    ];
    return 'Can ${can.join(' & ')}.';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
