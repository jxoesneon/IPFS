import 'package:meta/meta.dart';

/// Mixin providing clone and copyWith functionality for blocks.
mixin BlockCloneable<T extends BlockCloneable<T>> {
  /// Creates a deep clone of this block.
  T clone();

  /// Creates a copy with modifications applied by [updates].
  T copyWith(void Function(T) updates);

  /// Creates a base clone (internal helper).
  @protected
  T baseClone() {
    return (this as T).clone();
  }

  /// Creates a copy with updates (internal helper).
  @protected
  T baseCopyWith(void Function(T) updates) {
    final clone = baseClone();
    updates(clone);
    return clone;
  }
}
