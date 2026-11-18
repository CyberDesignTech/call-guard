import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../models/list_entry.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import '../widgets/common/contact_picker.dart';
import '../widgets/common/call_log_picker_sheet.dart';
import '../widgets/common/entry_card.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/protection_warning.dart';
import 'country_operators_page.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({
    required this.database,
    required this.onStub,
    required this.strings,
    required this.isActive,
    required this.protectionEnabled,
    this.onEdgeSwipe,
  });

  final DatabaseHelper database;
  final VoidCallback onStub;
  final AppStrings strings;
  final bool isActive;
  final bool protectionEnabled;
  final ValueChanged<int>? onEdgeSwipe;

  @override
  State<ListsPage> createState() => ListsPageState();
}

class ListsPageState extends State<ListsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _tab = 0;
  bool _loadingRules = true;
  double _edgeOverscroll = 0;
  late final TabController _tabController;
  final _countryPageKey = GlobalKey<CountryOperatorsPageState>();
  List<ListEntry> _whitelist = [];
  List<ListEntry> _blacklist = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _reloadRules();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_reloadRules());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ListsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_reloadRules());
      unawaited(
        _countryPageKey.currentState?.refresh() ?? Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_reloadRules());
      unawaited(
        _countryPageKey.currentState?.refresh() ?? Future<void>.value(),
      );
    }
  }

  void _handleTabChanged() {
    if (_tab != _tabController.index) {
      setState(() => _tab = _tabController.index);
    }
  }

  bool _handleTabScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _edgeOverscroll = 0;
    } else if (notification is OverscrollNotification &&
        notification.metrics.axis == Axis.horizontal &&
        widget.onEdgeSwipe != null) {
      final direction = notification.overscroll > 0 ? 1 : -1;
      final atFirstTab = notification.metrics.extentBefore <= 0.5;
      final atLastTab = notification.metrics.extentAfter <= 0.5;
      final isOutwardSwipe =
          (direction < 0 && _tab == 0 && atFirstTab) ||
          (direction > 0 && _tab == 2 && atLastTab);
      if (isOutwardSwipe) {
        _edgeOverscroll += notification.overscroll.abs();
        if (_edgeOverscroll >= 24) {
          _edgeOverscroll = 0;
          widget.onEdgeSwipe!(direction);
        }
      } else {
        _edgeOverscroll = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _edgeOverscroll = 0;
    }
    return false;
  }

  Future<void> _reloadRules() async {
    final whiteRows = await widget.database.getPhoneRules('white');
    final blackRows = await widget.database.getPhoneRules('black');
    if (!mounted) return;
    setState(() {
      _whitelist = whiteRows.map(_entryFromRow).toList();
      _blacklist = blackRows.map(_entryFromRow).toList();
      _loadingRules = false;
    });
  }

  ListEntry _entryFromRow(Map<String, Object?> row) {
    final rawLabel = row['label'] as String? ?? '';
    final isLocalizedKey = rawLabel.startsWith('@');
    final listType = row['list_type'] as String;
    final isWhite = listType == 'white';
    return ListEntry(
      id: row['id'] as int,
      title: isLocalizedKey ? '' : rawLabel,
      titleKey: isLocalizedKey ? rawLabel.substring(1) : null,
      subtitle: row['phone'] as String,
      badge: '',
      badgeKey: isWhite ? 'allowed' : 'blocked',
      listType: listType,
      expiresAt: row['expires_at'] as int?,
      icon: isWhite ? Icons.person_outline : Icons.block_rounded,
      tint: isWhite ? AppPalette.green : AppPalette.red,
      pale: isWhite ? AppPalette.greenPale : AppPalette.redPale,
    );
  }

  Future<void> _addEntry() async {
    if (_tab == 2) {
      await _countryPageKey.currentState?.showAddChoiceDialog();
      return;
    }

    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<ListEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          _tab == 0
              ? Icons.person_add_alt_1_rounded
              : Icons.person_off_outlined,
          color: AppPalette.blue,
        ),
        title: Text(
          _tab == 0 ? widget.strings.whiteListTab : widget.strings.blackListTab,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: widget.strings.call('phoneNumber'),
                hintText: widget.strings.call('phoneNumberHint'),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: widget.strings.call('optionalName'),
                hintText: widget.strings.call('nameExample'),
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final contact = await pickContactFromPhoneBook(
                        context: dialogContext,
                        strings: widget.strings,
                        channel: CallScreeningChannel(),
                      );
                      if (contact == null || !dialogContext.mounted) return;
                      phoneController.text = contact.phone ?? '';
                      nameController.text = contact.name ?? '';
                    },
                    icon: const Icon(Icons.contacts_outlined, size: 16),
                    label: Text(
                      widget.strings.call('pickFromContacts'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selection = await showCallLogPickerSheet(
                        context: dialogContext,
                        strings: widget.strings,
                        channel: CallScreeningChannel(),
                      );
                      if (selection == null || !dialogContext.mounted) return;
                      phoneController.text = selection.number;
                      nameController.text = selection.name;
                    },
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: Text(
                      widget.strings.call('callHistoryPicker'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) return;
              final isWhite = _tab == 0;
              Navigator.pop(
                dialogContext,
                ListEntry(
                  title: nameController.text.trim(),
                  titleKey: nameController.text.trim().isEmpty
                      ? 'newNumber'
                      : null,
                  subtitle: phone,
                  badge: '',
                  badgeKey: isWhite ? 'allowed' : 'blocked',
                  listType: isWhite ? 'white' : 'black',
                  icon: isWhite ? Icons.person_outline : Icons.block_rounded,
                  tint: isWhite ? AppPalette.green : AppPalette.red,
                  pale: isWhite ? AppPalette.greenPale : AppPalette.redPale,
                ),
              );
            },
            child: Text(widget.strings.call('save')),
          ),
        ],
      ),
    );
    phoneController.dispose();
    nameController.dispose();
    if (result != null && mounted) {
      await widget.database.insertPhoneRule(
        phone: result.subtitle,
        label: result.titleKey == null ? result.title : '@${result.titleKey}',
        listType: result.listType,
      );
      await _reloadRules();
    }
  }

  Future<void> _deleteEntry(ListEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    await widget.database.deletePhoneRule(id);
    await _reloadRules();
  }

  Future<void> _makePermanent(ListEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    await widget.database.makePhoneRulePermanent(id);
    await _reloadRules();
  }

  String _expiryLabel(int expiresAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    final time =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${TimeOfDay.fromDateTime(date).format(context)}';
    return widget.strings.call('temporaryExpiresAt').replaceAll('{time}', time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        tooltip: widget.strings.call(
          _tab == 2 ? 'addCountryTooltip' : 'addNumberTooltip',
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.strings.call('add')),
      ),
      body: Column(
        children: [
          if (!widget.protectionEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: ProtectionWarning(
                message: widget.strings.call('listsProtectionDisabledWarning'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: SizedBox(
              width: double.infinity,
              child: PageIntro(
                eyebrow: widget.strings.call('listsEyebrow'),
                title: widget.strings.listsScreenTitle,
                subtitle: widget.strings.call('listsSubtitle'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppPalette.line),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppPalette.bluePale,
                  borderRadius: BorderRadius.circular(13),
                ),
                labelColor: AppPalette.accent(AppPalette.blue),
                unselectedLabelColor: AppPalette.muted,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                tabs: [
                  Tab(
                    height: 50,
                    child: Text(
                      widget.strings.whiteListTab,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Tab(
                    height: 50,
                    child: Text(
                      widget.strings.blackListTab,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Tab(
                    height: 50,
                    child: Text(
                      widget.strings.countryOperatorsTab,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleTabScroll,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _entryList(_whitelist, widget.strings.call('whiteListHint')),
                  _entryList(_blacklist, widget.strings.call('blackListHint')),
                  CountryOperatorsPage(
                    key: _countryPageKey,
                    database: widget.database,
                    onStub: widget.onStub,
                    strings: widget.strings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryList(List<ListEntry> entries, String note) {
    if (_loadingRules) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 88),
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              note,
              style: TextStyle(color: AppPalette.muted, fontSize: 11),
            ),
          );
        }
        final entry = entries[index - 1];
        return EntryCard(
          entry: entry,
          strings: widget.strings,
          onDelete: () => _deleteEntry(entry),
          expiryLabel: entry.expiresAt == null
              ? null
              : _expiryLabel(entry.expiresAt!),
          onMakePermanent: entry.expiresAt == null
              ? null
              : () => _makePermanent(entry),
        );
      },
    );
  }
}
