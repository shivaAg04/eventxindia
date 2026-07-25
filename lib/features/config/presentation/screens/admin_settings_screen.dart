import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../bloc/platform_config_cubit.dart';

/// Admin platform settings (R6): set the platform commission percentage.
///
/// The commission is the admin's cut of an event's earnings. It defaults to
/// 10%. Changing it here applies only to **future** events — every event
/// snapshots the rate in force when it was created, so past events and their
/// revenue are never affected.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({required this.createCubit, super.key});

  final PlatformConfigCubit Function() createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlatformConfigCubit>(
      create: (_) => createCubit()..watch(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Platform settings')),
        body: BlocBuilder<PlatformConfigCubit, PlatformConfigState>(
          builder: (BuildContext context, PlatformConfigState state) {
            return switch (state) {
              PlatformConfigLoading() =>
                const Center(child: CircularProgressIndicator()),
              PlatformConfigFailure(:final String message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Settings could not be loaded.\n$message',
                        textAlign: TextAlign.center),
                  ),
                ),
              PlatformConfigLoaded(:final int percent) =>
                _SettingsView(percent: percent),
            };
          },
        ),
      ),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.percent});

  final int percent;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.percent}');
  String? _error;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect an externally-updated value when the field is not being edited.
    if (oldWidget.percent != widget.percent && !_saving) {
      _controller.text = '${widget.percent}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final int? value = int.tryParse(_controller.text.trim());
    if (value == null) {
      setState(() => _error = 'Enter a whole number.');
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final PlatformConfigCubit cubit = context.read<PlatformConfigCubit>();
    setState(() {
      _error = null;
      _saving = true;
    });
    final Result<Unit, Failure> result = await cubit.setPercent(value);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      (Unit _) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Commission updated.')),
        ),
      (Failure f) => setState(() => _error = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Platform commission',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'The admin\'s cut of each event\'s earnings. Applies to '
                  'future events only — past events keep the rate they were '
                  'created with.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey<String>('commission-percent-field'),
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Commission (%)',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('commission-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
