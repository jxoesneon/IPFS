import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_budget.dart';
import 'package:test/test.dart';

void main() {
  group('SelectorBudget', () {
    test('initial state is zero', () {
      final budget = SelectorBudget(maxDepth: 5, maxBlocks: 10, maxBytes: 100);
      expect(budget.currentDepth, 0);
      expect(budget.currentBlocks, 0);
      expect(budget.currentBytes, 0);
    });

    test('tracks block and byte counts', () {
      final budget = SelectorBudget(maxDepth: 5, maxBlocks: 10, maxBytes: 100);
      budget.checkBlock(30);
      expect(budget.currentBlocks, 1);
      expect(budget.currentBytes, 30);
      budget.checkBlock(20);
      expect(budget.currentBlocks, 2);
      expect(budget.currentBytes, 50);
    });

    test('throws when block count exceeds limit', () {
      final budget = SelectorBudget(maxDepth: 5, maxBlocks: 2, maxBytes: 100);
      budget.checkBlock(1);
      budget.checkBlock(1);
      expect(() => budget.checkBlock(1), throwsA(isA<BudgetExceededError>()));
    });

    test('throws when byte count exceeds limit', () {
      final budget = SelectorBudget(maxDepth: 5, maxBlocks: 10, maxBytes: 10);
      budget.checkBlock(5);
      expect(() => budget.checkBlock(10), throwsA(isA<BudgetExceededError>()));
    });

    test('tracks depth and throws when exceeded', () {
      final budget = SelectorBudget(maxDepth: 2, maxBlocks: 10, maxBytes: 100);
      budget.enterDepth();
      expect(budget.currentDepth, 1);
      budget.enterDepth();
      expect(budget.currentDepth, 2);
      expect(() => budget.enterDepth(), throwsA(isA<BudgetExceededError>()));
    });

    test('leaveDepth decrements and never goes below zero', () {
      final budget = SelectorBudget(maxDepth: 5, maxBlocks: 10, maxBytes: 100);
      budget.leaveDepth();
      expect(budget.currentDepth, 0);
      budget.enterDepth();
      budget.enterDepth();
      budget.leaveDepth();
      expect(budget.currentDepth, 1);
      budget.leaveDepth();
      expect(budget.currentDepth, 0);
      budget.leaveDepth();
      expect(budget.currentDepth, 0);
    });
  });
}
