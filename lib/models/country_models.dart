enum RuleState { neutral, allowed, blocked }

class CountryEntry {
  CountryEntry({
    required this.isoCode,
    required this.flag,
    required this.name,
    this.nameKey,
    required this.code,
    required this.operators,
    this.areaCodes = const <String>[],
    this.action = RuleState.neutral,
  });

  final String isoCode;
  final String flag;
  final String name;
  final String? nameKey;
  final String code;
  final List<String> areaCodes;
  final List<OperatorEntry> operators;
  RuleState action;
}

class OperatorEntry {
  OperatorEntry({
    this.id,
    required this.name,
    this.nameKey,
    required this.prefixes,
    this.action = RuleState.neutral,
  });

  final int? id;
  final String name;
  final String? nameKey;
  final List<String> prefixes;
  RuleState action;
}
