import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../engine/call_rule_simulator.dart';
import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';

class SimulateCallDialog extends StatefulWidget {
  const SimulateCallDialog({
    required this.strings,
    required this.database,
    required this.settingsOverrides,
  });

  final AppStrings strings;
  final DatabaseHelper database;
  final Map<String, String> settingsOverrides;

  @override
  State<SimulateCallDialog> createState() => SimulateCallDialogState();
}

class SimulateCallDialogState extends State<SimulateCallDialog> {
  final _phoneController = TextEditingController();
  final _channel = CallScreeningChannel();
  CallSimulationVerdict? _verdict;
  bool _loading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return;
    setState(() {
      _loading = true;
      _hasError = false;
      _verdict = null;
    });
    try {
      bool? isInContacts;
      final shouldCheckContacts =
          widget.settingsOverrides['block_non_contacts'] == 'true' ||
          widget.settingsOverrides[DatabaseHelper.settingBlockShortNumbers] ==
              'true';
      if (shouldCheckContacts) {
        try {
          final permissions = await _channel.checkPermissions();
          if (permissions.readContacts) {
            isInContacts =
                await _channel.lookupContactName(phoneNumber) != null;
          }
        } on PlatformException {
          // Contact filtering is optional when the Android contact provider
          // cannot be reached from a simulator/test environment.
        } on MissingPluginException {
          // Pure Dart simulation remains available off Android.
        }
      }
      final verdict = await CallRuleSimulator(widget.database).evaluate(
        phoneNumber,
        isInContacts: isInContacts,
        settingsOverrides: widget.settingsOverrides,
      );
      if (!mounted) return;
      setState(() => _verdict = verdict);
    } on PlatformException {
      if (mounted) setState(() => _hasError = true);
    } on MissingPluginException {
      if (mounted) setState(() => _hasError = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _reasonLabel(String reason) =>
      AppStrings.keys.contains(reason) ? widget.strings.call(reason) : reason;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(
      Icons.science_outlined,
      color: AppPalette.accent(AppPalette.blue),
    ),
    title: Text(widget.strings.call('testTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.strings.call('testBody')),
          const SizedBox(height: 13),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: widget.strings.call('phoneNumber'),
              hintText: widget.strings.call('phoneNumberHint'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            onSubmitted: (_) => _simulate(),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_hasError) ...[
            const SizedBox(height: 13),
            Text(
              widget.strings.call('simulationUnavailable'),
              style: TextStyle(
                color: AppPalette.accent(AppPalette.red),
                fontSize: 12,
              ),
            ),
          ],
          if (_verdict case final verdict?) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.accentSurface(
                  verdict.allowed ? AppPalette.green : AppPalette.red,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.strings.call(
                      verdict.allowed ? 'verdictAllowed' : 'verdictRejected',
                    ),
                    style: TextStyle(
                      color: AppPalette.accent(
                        verdict.allowed ? AppPalette.green : AppPalette.red,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.strings.call(
                      verdict.allowed
                          ? 'verdictAllowedExplanation'
                          : 'verdictRejectedExplanation',
                    ),
                    style: TextStyle(color: AppPalette.ink, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.strings.call('ruleReason')}: ${_reasonLabel(verdict.reason)}',
                    style: TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.strings.call('closeLabel')),
      ),
      FilledButton(
        onPressed: _loading ? null : _simulate,
        child: Text(
          _loading
              ? widget.strings.call('checkingCallRules')
              : widget.strings.call('runSimulation'),
        ),
      ),
    ],
  );
}
