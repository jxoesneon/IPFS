// src/core/ipld/selectors/ipld_selector.dart

enum SelectorType {
  all,
  none,
  explore,
  matcher,
  recursive,
  union,
  intersection,
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

  factory IPLDSelector.explore({
    required String path,
    required IPLDSelector selector,
  }) =>
      IPLDSelector(
        type: SelectorType.explore,
        fieldPath: path,
        subSelectors: [selector],
      );

  factory IPLDSelector.matcher({
    required Map<String, dynamic> criteria,
  }) =>
      IPLDSelector(
        type: SelectorType.matcher,
        criteria: criteria,
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

  factory IPLDSelector.union(List<IPLDSelector> selectors) => IPLDSelector(
        type: SelectorType.union,
        subSelectors: selectors,
      );

  factory IPLDSelector.intersection(List<IPLDSelector> selectors) =>
      IPLDSelector(
        type: SelectorType.intersection,
        subSelectors: selectors,
      );
}
