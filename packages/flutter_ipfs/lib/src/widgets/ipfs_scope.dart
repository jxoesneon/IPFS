import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';

/// An [InheritedWidget] providing ambient access to an [IPFSNode] instance
/// throughout the Flutter widget tree.
///
/// Descendant widgets can obtain the node via [IpfsScope.of] or [IpfsScope.maybeOf].
///
/// Example:
/// `dart
/// IpfsScope(
///   node: myNode,
///   child: MaterialApp(
///     home: MyScreen(),
///   ),
/// )
/// `
class IpfsScope extends InheritedWidget {
  /// Creates an [IpfsScope] providing [node] to descendants.
  const IpfsScope({
    super.key,
    required this.node,
    required super.child,
  });

  /// The provided [IPFSNode] instance.
  final IPFSNode node;

  /// Retrieves the ambient [IPFSNode] from the nearest [IpfsScope] ancestor.
  ///
  /// Throws a [FlutterError] if no [IpfsScope] is found in [context].
  static IPFSNode of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IpfsScope>();
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No IpfsScope found in context.'),
        ErrorDescription(
          'IpfsScope.of() was called with a context that does not contain an IpfsScope widget.',
        ),
        ErrorHint(
          'Make sure you have wrapped your widget tree or MaterialApp with an IpfsScope widget.',
        ),
      ]);
    }
    return scope.node;
  }

  /// Retrieves the ambient [IPFSNode] from the nearest [IpfsScope] ancestor,
  /// or null if none exists.
  static IPFSNode? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IpfsScope>();
    return scope?.node;
  }

  @override
  bool updateShouldNotify(IpfsScope oldWidget) => node != oldWidget.node;
}
