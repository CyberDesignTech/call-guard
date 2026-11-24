import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/recent_call_log_entry.dart';
import '../../platform/call_screening_channel.dart';
import '../../theme/app_palette.dart';

Future<RecentCallLogEntry?> showCallLogPickerSheet({
  required BuildContext context,
  required AppStrings strings,
  required CallScreeningChannel channel,
}) => showModalBottomSheet<RecentCallLogEntry>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => CallLogPickerSheet(strings: strings, channel: channel),
);

class CallLogPickerSheet extends StatefulWidget {
  const CallLogPickerSheet({
    required this.strings,
    required this.channel,
    super.key,
  });

  final AppStrings strings;
  final CallScreeningChannel channel;

  @override
  State<CallLogPickerSheet> createState() => _CallLogPickerSheetState();
}

class _CallLogPickerSheetState extends State<CallLogPickerSheet> {
  final _searchController = TextEditingController();
  RecentCallLogResult? _result;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.channel.getRecentCallLog();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openSettings() async {
    try {
      await widget.channel.openCallLogSettings();
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.call('callHistoryLoadError'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.call('callHistoryLoadError'))),
      );
    }
  }

  List<RecentCallLogEntry> get _filteredCalls {
    final calls = _result?.calls ?? const <RecentCallLogEntry>[];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return calls;
    final digits = normalizePhoneNumber(query);
    return calls.where((call) {
      return call.name.toLowerCase().contains(query) ||
          call.number.toLowerCase().contains(query) ||
          (digits.isNotEmpty && call.number.contains(digits));
    }).toList();
  }

  String _callTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · $time';
  }

  IconData _typeIcon(String type) => switch (type) {
    'outgoing' => Icons.call_made_rounded,
    'missed' => Icons.phone_missed_rounded,
    'rejected' => Icons.call_end_rounded,
    'blocked' => Icons.block_rounded,
    _ => Icons.call_received_rounded,
  };

  String _typeLabel(String type) => switch (type) {
    'outgoing' => widget.strings.call('callTypeOutgoing'),
    'missed' => widget.strings.call('callTypeMissed'),
    'rejected' => widget.strings.call('callTypeRejected'),
    'blocked' => widget.strings.call('callTypeBlocked'),
    _ => widget.strings.call('callTypeIncoming'),
  };

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final permissionDenied = _result?.permissionGranted == false;
    return SizedBox(
      height: maxHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.strings.call('callHistoryPicker'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (_result?.permissionGranted == true)
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.strings.call('callHistorySearch'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: widget.strings.call('clearSearch'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            if (_result?.permissionGranted == true) const SizedBox(height: 8),
            Expanded(child: _buildBody(permissionDenied)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool permissionDenied) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(child: Text(widget.strings.call('callHistoryLoadError')));
    }
    if (permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: AppPalette.muted,
              ),
              const SizedBox(height: 10),
              Text(
                widget.strings.call('callHistoryPermissionExplanation'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.muted),
              ),
              const SizedBox(height: 14),
              if (_result?.permanentlyDenied == true) ...[
                FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(widget.strings.call('callHistoryOpenSettings')),
                ),
                TextButton(
                  onPressed: _load,
                  child: Text(widget.strings.call('callHistoryRetry')),
                ),
              ] else
                FilledButton.tonal(
                  onPressed: _load,
                  child: Text(widget.strings.call('callHistoryRetry')),
                ),
            ],
          ),
        ),
      );
    }
    final calls = _filteredCalls;
    if (calls.isEmpty) {
      return Center(
        child: Text(
          _result?.calls.isEmpty == true
              ? widget.strings.call('callHistoryEmpty')
              : widget.strings.call('callHistoryNoMatches'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.muted),
        ),
      );
    }
    return ListView.separated(
      itemCount: calls.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final call = calls[index];
        final color = call.type == 'missed' || call.type == 'blocked'
            ? AppPalette.red
            : call.type == 'incoming'
            ? AppPalette.green
            : AppPalette.blue;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppPalette.accentSurface(color),
            child: Icon(_typeIcon(call.type), color: AppPalette.accent(color)),
          ),
          title: Text(
            call.name.isEmpty ? call.number : call.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (call.name.isNotEmpty) Text(call.number),
              Text('${_typeLabel(call.type)} · ${_callTime(call.timestamp)}'),
            ],
          ),
          isThreeLine: call.name.isNotEmpty,
          onTap: () => Navigator.of(context).pop(
            RecentCallLogEntry(
              number: normalizePhoneNumber(call.number),
              name: call.name,
              type: call.type,
              timestamp: call.timestamp,
            ),
          ),
        );
      },
    );
  }
}
