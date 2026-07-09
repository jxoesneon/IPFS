// src/protocols/graphsync/graphsync_budget.dart

import '../../core/errors/graphsync_errors.dart';

/// Budget for a single Graphsync selector traversal.
///
/// Tracks traversal depth, block count, and byte count. Any limit that is
/// exceeded throws [BudgetExceededError] from the corresponding check method.
class SelectorBudget {
  /// Creates a budget with the given limits.
  SelectorBudget({
    required this.maxDepth,
    required this.maxBlocks,
    required this.maxBytes,
  });

  /// Maximum traversal depth.
  final int maxDepth;

  /// Maximum number of blocks that may be included in the response.
  final int maxBlocks;

  /// Maximum total number of bytes that may be included in the response.
  final int maxBytes;

  int _currentDepth = 0;
  int _currentBlocks = 0;
  int _currentBytes = 0;

  /// Current traversal depth.
  int get currentDepth => _currentDepth;

  /// Current number of blocks accepted.
  int get currentBlocks => _currentBlocks;

  /// Current number of bytes accepted.
  int get currentBytes => _currentBytes;

  /// Validates that adding a block of [size] bytes stays within the budget.
  void checkBlock(int size) {
    if (++_currentBlocks > maxBlocks) {
      throw BudgetExceededError('block count');
    }
    _currentBytes += size;
    if (_currentBytes > maxBytes) {
      throw BudgetExceededError('byte count');
    }
  }

  /// Increments the traversal depth and validates it stays within the budget.
  void enterDepth() {
    if (++_currentDepth > maxDepth) {
      throw BudgetExceededError('depth');
    }
  }

  /// Decrements the traversal depth when leaving a nested DAG node.
  void leaveDepth() {
    if (_currentDepth > 0) _currentDepth--;
  }
}
