import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/world_countries.dart';
import '../l10n/app_strings.dart';
import '../models/country_models.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/tag.dart';

const _detailedCountryOrder = <String>[
  'UA',
  'PL',
  'DE',
  'GB',
  'US',
  'CA',
  'ES',
  'FR',
];

final Map<String, WorldCountry> _worldByIso = {
  for (final country in worldCountries) country.isoCode: country,
};

class _OperatorDraft {
  const _OperatorDraft({required this.countryIso, required this.operator});

  final String countryIso;
  final OperatorEntry operator;
}

sealed class _ListItem {
  const _ListItem();
}

class _SectionHeaderItem extends _ListItem {
  const _SectionHeaderItem(this.labelKey);

  final String labelKey;
}

class _CountryItem extends _ListItem {
  const _CountryItem({required this.country, required this.activeFilter});

  final CountryEntry country;
  final bool activeFilter;
}

class CountryOperatorsPage extends StatefulWidget {
  const CountryOperatorsPage({
    super.key,
    required this.database,
    required this.onCountriesUnavailable,
    required this.strings,
  });

  final DatabaseHelper database;
  final VoidCallback onCountriesUnavailable;
  final AppStrings strings;

  @override
  State<CountryOperatorsPage> createState() => CountryOperatorsPageState();
}

class CountryOperatorsPageState extends State<CountryOperatorsPage> {
  String _query = '';
  final _searchController = TextEditingController();
  List<CountryEntry> _countries = [];
  bool _loadingCountries = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final results = await Future.wait([
      widget.database.getCountries(),
      widget.database.getAllOperators(),
    ]);
    final countryRows = results[0];
    final operatorRows = results[1];
    final operatorsByCountry = <String, List<OperatorEntry>>{};
    for (final row in operatorRows) {
      final isoCode = row['country_iso'] as String;
      operatorsByCountry
          .putIfAbsent(isoCode, () => <OperatorEntry>[])
          .add(_operatorFromRow(row));
    }
    final countries = <CountryEntry>[];
    for (final row in countryRows) {
      final isoCode = row['iso_code'] as String;
      final customName = row['custom_name'] as String?;
      countries.add(
        CountryEntry(
          isoCode: isoCode,
          flag: _flagForCountry(isoCode),
          name: customName ?? '',
          nameKey: customName == null ? row['name_key'] as String : null,
          code: row['dial_code'] as String,
          areaCodes: (row['area_codes'] as String? ?? '')
              .split(',')
              .where((code) => code.isNotEmpty)
              .toList(),
          action: _ruleState(row['action'] as String),
          operators: operatorsByCountry[isoCode] ?? const <OperatorEntry>[],
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _loadingCountries = false;
    });
  }

  Future<void> refresh() => _loadCountries();

  String _flagForCountry(String isoCode) {
    final world = _worldByIso[isoCode];
    if (world != null) return world.flag;
    if (isoCode.length == 2) {
      return String.fromCharCodes(
        isoCode.codeUnits.map((unit) => unit + 127397),
      );
    }
    return '🌐';
  }

  RuleState _ruleState(String value) => switch (value) {
    'allow' => RuleState.allowed,
    'block' => RuleState.blocked,
    _ => RuleState.neutral,
  };

  String _storedRule(RuleState value) => switch (value) {
    RuleState.allowed => 'allow',
    RuleState.blocked => 'block',
    RuleState.neutral => 'neutral',
  };

  OperatorEntry _operatorFromRow(Map<String, Object?> row) {
    final storedName = row['operator_name'] as String;
    final isLocalized = storedName.startsWith('@');
    return OperatorEntry(
      id: row['id'] as int,
      name: isLocalized ? '' : storedName,
      nameKey: isLocalized ? storedName.substring(1) : null,
      prefixes: (row['prefixes'] as String)
          .split(',')
          .where((prefix) => prefix.isNotEmpty)
          .toList(),
      action: _ruleState(row['action'] as String),
    );
  }

  String _countryName(CountryEntry country) {
    final world = _worldByIso[country.isoCode];
    if (world != null) return world.nameFor(widget.strings.language);
    if (country.nameKey == null) return country.name;
    return widget.strings.call(country.nameKey!);
  }

  String _operatorName(OperatorEntry operator) => operator.nameKey == null
      ? operator.name
      : widget.strings.call(operator.nameKey!);

  void _setCountryAction(CountryEntry country, RuleState value) {
    setState(() => country.action = value);
    unawaited(
      widget.database.updateCountryAction(country.isoCode, _storedRule(value)),
    );
  }

  void _setOperatorAction(OperatorEntry operator, RuleState value) {
    setState(() => operator.action = value);
    final id = operator.id;
    if (id != null) {
      unawaited(widget.database.updateOperatorAction(id, _storedRule(value)));
    }
  }

  String _countryAction(RuleState state) => widget.strings.call(switch (state) {
    RuleState.neutral => 'countryDefault',
    RuleState.allowed => 'countryAllowAll',
    RuleState.blocked => 'countryBlockAll',
  });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _countryActionShort(RuleState state) =>
      widget.strings.call(switch (state) {
        RuleState.neutral => 'countryDefaultShort',
        RuleState.allowed => 'countryAllowedShort',
        RuleState.blocked => 'countryBlockedShort',
      });

  String _operatorAction(RuleState state) =>
      widget.strings.call(switch (state) {
        RuleState.neutral => 'neutral',
        RuleState.allowed => 'allowed',
        RuleState.blocked => 'blocked',
      });

  Color _ruleColor(RuleState state) => switch (state) {
    RuleState.neutral => AppPalette.muted,
    RuleState.allowed => AppPalette.green,
    RuleState.blocked => AppPalette.red,
  };

  Widget _ruleMenu({
    required RuleState state,
    required bool country,
    required ValueChanged<RuleState> onSelected,
  }) {
    final color = _ruleColor(state);
    return PopupMenuButton<RuleState>(
      tooltip: widget.strings.call(
        country ? 'countryActionTooltip' : 'operatorActionTooltip',
      ),
      onSelected: onSelected,
      itemBuilder: (context) => RuleState.values
          .map(
            (value) => PopupMenuItem(
              value: value,
              child: Text(
                country ? _countryAction(value) : _operatorAction(value),
              ),
            ),
          )
          .toList(),
      child: Tag(
        label: country ? _countryActionShort(state) : _operatorAction(state),
        color: color,
        background: AppPalette.accentSurface(color),
      ),
    );
  }

  Future<void> showAddOperatorDialog() async {
    if (_countries.isEmpty) {
      widget.onCountriesUnavailable();
      return;
    }
    final nameController = TextEditingController();
    final prefixesController = TextEditingController();
    var countryIso = _countries.first.isoCode;
    var action = RuleState.neutral;

    final draft = await showDialog<_OperatorDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.cell_tower_rounded,
            color: AppPalette.accent(AppPalette.blue),
          ),
          title: Text(widget.strings.call('addOperator')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: countryIso,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorCountryField'),
                  ),
                  items: _countries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country.isoCode,
                          child: Text(
                            '${country.flag} ${_countryName(country)} ${country.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => countryIso = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorNameField'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prefixesController,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('prefixesField'),
                    hintText: widget.strings.call('prefixesHint'),
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RuleState>(
                  isExpanded: true,
                  initialValue: action,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorActionField'),
                  ),
                  items: RuleState.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_operatorAction(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => action = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(widget.strings.call('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final prefixes = prefixesController.text
                    .split(',')
                    .map((prefix) => prefix.trim())
                    .where((prefix) => prefix.isNotEmpty)
                    .toList();
                if (name.isEmpty || prefixes.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _OperatorDraft(
                    countryIso: countryIso,
                    operator: OperatorEntry(
                      name: name,
                      prefixes: prefixes,
                      action: action,
                    ),
                  ),
                );
              },
              child: Text(widget.strings.call('add')),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    prefixesController.dispose();
    if (draft != null && mounted) {
      await widget.database.insertOperator(
        countryIso: draft.countryIso,
        name: draft.operator.nameKey == null
            ? draft.operator.name
            : '@${draft.operator.nameKey}',
        prefixes: draft.operator.prefixes,
        action: _storedRule(draft.operator.action),
      );
      await _loadCountries();
    }
  }

  bool _isDetailed(CountryEntry country) =>
      _detailedCountryOrder.contains(country.isoCode) ||
      !_worldByIso.containsKey(country.isoCode);

  bool _matchesCountry(CountryEntry country, String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    final world = _worldByIso[country.isoCode];
    if (world != null && world.matches(query)) return true;
    if (_countryName(country).toLowerCase().contains(needle)) return true;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final dialDigits = country.code.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty &&
        (dialDigits == digits || dialDigits.contains(digits))) {
      return true;
    }
    if (RegExp(r'^[+\d\s()\-]+$').hasMatch(query)) return false;
    return country.operators.any(
      (operator) =>
          _operatorName(operator).toLowerCase().contains(needle) ||
          operator.prefixes.any(
            (prefix) => prefix.toLowerCase().contains(needle),
          ),
    );
  }

  int _compareNames(CountryEntry a, CountryEntry b) =>
      _countryName(a).toLowerCase().compareTo(_countryName(b).toLowerCase());

  List<CountryEntry> _sortedDetailed(String query) {
    final detailed = _countries
        .where(_isDetailed)
        .where((country) => _matchesCountry(country, query))
        .toList();
    detailed.sort((a, b) {
      final aIndex = _detailedCountryOrder.indexOf(a.isoCode);
      final bIndex = _detailedCountryOrder.indexOf(b.isoCode);
      if (aIndex != -1 || bIndex != -1) {
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;
        return aIndex.compareTo(bIndex);
      }
      return _compareNames(a, b);
    });
    return detailed;
  }

  List<CountryEntry> _sortedWorld(String query) {
    final world = _countries
        .where((country) => !_isDetailed(country))
        .where((country) => _matchesCountry(country, query))
        .toList();
    world.sort(_compareNames);
    return world;
  }

  Widget _sectionHeader(String labelKey) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Text(
      widget.strings.call(labelKey).toUpperCase(),
      style: TextStyle(
        color: AppPalette.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    ),
  );

  Widget _countryCard(CountryEntry country, String query) {
    final world = _worldByIso[country.isoCode];
    final countryMatches =
        query.isEmpty ||
        (world?.matches(query) ?? false) ||
        _countryName(country).toLowerCase().contains(query.toLowerCase()) ||
        country.code.toLowerCase().contains(query.toLowerCase());
    final operators = countryMatches
        ? country.operators
        : country.operators
              .where(
                (operator) =>
                    _operatorName(operator)
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    operator.prefixes.any(
                      (prefix) =>
                          prefix.toLowerCase().contains(query.toLowerCase()),
                    ),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppPanel(
        child: ExpansionTile(
          key: PageStorageKey('country-${country.isoCode}'),
          leading: Text(country.flag, style: const TextStyle(fontSize: 23)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _countryName(country),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              _ruleMenu(
                state: country.action,
                country: true,
                onSelected: (value) => _setCountryAction(country, value),
              ),
            ],
          ),
          subtitle: Text(
            '${country.code} · ${widget.strings.call('operatorCount').replaceAll('{count}', country.operators.length.toString())}',
            style: TextStyle(color: AppPalette.muted, fontSize: 10),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
          children: operators.isEmpty
              ? [
                  if (country.operators.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.strings.call('operatorsEmpty'),
                        style: TextStyle(color: AppPalette.muted, fontSize: 11),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.strings.call('operatorsSearchEmpty'),
                        style: TextStyle(color: AppPalette.muted, fontSize: 11),
                      ),
                    ),
                ]
              : operators
                    .map((operator) => _operatorRow(country, operator))
                    .toList(),
        ),
      ),
    );
  }

  Widget _worldCountryRow(CountryEntry country, {required bool activeFilter}) {
    final blocked = country.action == RuleState.blocked;
    return Padding(
      key: Key(
        'world-country-${country.isoCode}-${activeFilter ? 'active' : 'all'}',
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 21)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _countryName(country),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      country.code,
                      style: TextStyle(color: AppPalette.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tag(
                label: _countryActionShort(country.action),
                color: _ruleColor(country.action),
                background: AppPalette.accentSurface(
                  _ruleColor(country.action),
                ),
              ),
              Switch(
                value: blocked,
                onChanged: (value) => _setCountryAction(
                  country,
                  value ? RuleState.blocked : RuleState.neutral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _operatorRow(CountryEntry country, OperatorEntry operator) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 7, 9),
        decoration: BoxDecoration(
          color: AppPalette.isDark
              ? const Color(0xFF202C3E)
              : const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppPalette.line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cell_tower_rounded,
              color: AppPalette.accent(AppPalette.blue),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _operatorName(operator),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: operator.prefixes
                        .map(
                          (prefix) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.bluePale,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${country.code} $prefix',
                              style: TextStyle(
                                color: AppPalette.accent(AppPalette.blue),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            _ruleMenu(
              state: operator.action,
              country: false,
              onSelected: (value) => _setOperatorAction(operator, value),
            ),
          ],
        ),
      ),
    );
  }

  List<_ListItem> _buildItems(String query) {
    final detailed = _sortedDetailed(query);
    final world = _sortedWorld(query);
    final activeFilters = world
        .where((country) => country.action == RuleState.blocked)
        .toList();
    final availableWorld = world
        .where((country) => country.action != RuleState.blocked)
        .toList();
    final items = <_ListItem>[];
    if (detailed.isNotEmpty) {
      items.add(const _SectionHeaderItem('detailedCountriesHeader'));
      items.addAll(
        detailed.map(
          (country) => _CountryItem(country: country, activeFilter: false),
        ),
      );
    }
    if (activeFilters.isNotEmpty) {
      items.add(const _SectionHeaderItem('activeCountryFilters'));
      items.addAll(
        activeFilters.map(
          (country) => _CountryItem(country: country, activeFilter: true),
        ),
      );
    }
    if (availableWorld.isNotEmpty) {
      items.add(const _SectionHeaderItem('allWorldCountriesHeader'));
      items.addAll(
        availableWorld.map(
          (country) => _CountryItem(country: country, activeFilter: false),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final items = _loadingCountries ? const <_ListItem>[] : _buildItems(query);
    return ListView.builder(
      key: const PageStorageKey('countryOperatorsList'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 88),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: widget.strings.call('countrySearchHint'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: widget.strings.call('clearSearch'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
        }
        if (index == 1) {
          if (_loadingCountries) {
            return const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppPanel(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    widget.strings.call('searchEmpty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final item = items[index - 2];
        return switch (item) {
          _SectionHeaderItem(:final labelKey) => _sectionHeader(labelKey),
          _CountryItem(:final country, :final activeFilter) =>
            _isDetailed(country)
                ? _countryCard(country, query)
                : _worldCountryRow(country, activeFilter: activeFilter),
        };
      },
    );
  }
}
