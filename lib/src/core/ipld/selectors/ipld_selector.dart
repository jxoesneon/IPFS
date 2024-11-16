// src/core/ipld/selectors/ipld_selector.dart

enum SelectorType {
  all,
  none,
  matcher,
  explore,
  recursive,
  union,
  intersection,
  condition,
  exploreRecursive,
  exploreUnion,
  exploreAll,
  exploreRange,
  exploreFields,
  exploreIndex
}

class IPLDSelector {
  final SelectorType type;
  final Map<String, dynamic> criteria;
  final int? maxDepth;
  final List<IPLDSelector>? subSelectors;
  final String? fieldPath;
  final bool? stopAtLink;
  final int? startIndex;
  final int? endIndex;
  final List<String>? fields;

  IPLDSelector({
    required this.type,
    this.criteria = const {},
    this.maxDepth,
    this.subSelectors,
    this.fieldPath,
    this.stopAtLink,
    this.startIndex,
    this.endIndex,
    this.fields,
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

  factory IPLDSelector.exploreRecursive({
    required IPLDSelector selector,
    int? maxDepth,
    bool stopAtLink = false,
  }) =>
      IPLDSelector(
        type: SelectorType.exploreRecursive,
        subSelectors: [selector],
        maxDepth: maxDepth,
        stopAtLink: stopAtLink,
      );

  factory IPLDSelector.exploreUnion({
    required List<IPLDSelector> selectors,
  }) =>
      IPLDSelector(
        type: SelectorType.exploreUnion,
        subSelectors: selectors,
      );

  factory IPLDSelector.exploreAll() =>
      IPLDSelector(type: SelectorType.exploreAll);

  factory IPLDSelector.exploreRange({
    required int start,
    required int end,
    required IPLDSelector selector,
  }) =>
      IPLDSelector(
        type: SelectorType.exploreRange,
        startIndex: start,
        endIndex: end,
        subSelectors: [selector],
      );

  factory IPLDSelector.exploreFields({
    required List<String> fields,
    required IPLDSelector selector,
  }) =>
      IPLDSelector(
        type: SelectorType.exploreFields,
        fields: fields,
        subSelectors: [selector],
      );

  factory IPLDSelector.exploreIndex({
    required int index,
    required IPLDSelector selector,
  }) =>
      IPLDSelector(
        type: SelectorType.exploreIndex,
        startIndex: index,
        subSelectors: [selector],
      );
}
