import 'package:flutter/widgets.dart';

/// A reactive widget that evaluates an IPFS asynchronous operation (e.g. content fetch,
/// DAG node resolution, IPNS name lookup) and rebuilds on state changes.
class IpfsBuilder<T> extends StatelessWidget {
  const IpfsBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.initialData,
  });

  /// The asynchronous IPFS operation to await.
  final Future<T> future;

  /// Builder callback invoked on every lifecycle stage of the future.
  final AsyncWidgetBuilder<T> builder;

  /// Optional initial data before the future completes.
  final T? initialData;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: builder,
    );
  }
}

/// A reactive widget that listens to an IPFS [Stream] (e.g. PubSub topic messages,
/// bandwidth metrics, peer events) and rebuilds whenever a new item is emitted.
class IpfsStreamBuilder<T> extends StatelessWidget {
  const IpfsStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
  });

  /// The IPFS stream to observe.
  final Stream<T> stream;

  /// Builder callback invoked on every stream emission.
  final AsyncWidgetBuilder<T> builder;

  /// Optional initial data before the first event is emitted.
  final T? initialData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: builder,
    );
  }
}
