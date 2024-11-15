// src/core/ipld/selectors/ipld_selector.dart

enum SelectorType {
  all,
  none,
  matcher,
  explore,
  recursive,
  union,
  intersection,
  condition
}

class IPLDSelector {
  final SelectorType type;
  final Map<String, dynamic> criteria;
  final int? maxDepth;
  final List<IPLDSelector>? subSelectors;
  final String? fieldPath;
  final bool? stopAtLink;

  IPLDSelector({
    required this.type,
    this.criteria = const {},
    this.maxDepth,
    this.subSelectors,
    this.fieldPath,
    this.stopAtLink,
  });

  factory IPLDSelector.all() => IPLDSelector(type: SelectorType.all);

  factory IPLDSelector.none() => IPLDSelector(type: SelectorType.none);

  factory IPLDSelector.matcher({
    required Map<String, dynamic> criteria,
    String? fieldPath,
  }) =>
      IPLDSelector(
        type: SelectorType.matcher,
        criteria: criteria,
        fieldPath: fieldPath,
      );

  factory IPLDSelector.recursive({
    required IPLDSelector selector,
    int? maxDepth,
    bool stopAtLink = false,
  }) =>
      IPLDSelector(
        type: SelectorType.recursive,
        subSelectors: [selector],
        maxDepth: maxDepth,
        stopAtLink: stopAtLink,
      );
}
