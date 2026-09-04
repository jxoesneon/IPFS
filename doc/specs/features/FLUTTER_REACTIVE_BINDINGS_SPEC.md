# Feature Specification: Flutter Reactive UI Bindings (FLUTTER_REACTIVE_BINDINGS_SPEC)

## 1. Executive Summary

`dart_ipfs` provides low-level asynchronous primitives (`Future<List<int>>`, `Stream<Uint8List>`, `IpfsNode`). While suitable for backend or CLI environments, Flutter application developers require **idiomatic, declarative UI widgets** and state management bindings. Currently, displaying a content-addressed image or syncing a local collection requires manual block fetching, byte decoding, memory caching, and stream subscription plumbing.

This specification defines the **Flutter Reactive Bindings Layer** (designed to live in a modular companion package or dedicated export `package:dart_ipfs/flutter.dart`), providing turn-key declarative widgets such as `IpfsScope`, `IpfsImage`, `IpfsText`, and `IpfsBuilder`.

---

## 2. Architectural Principles

1. **Zero Impact on CLI / Headless Core**:  
   The core `dart_ipfs` package must remain pure Dart with zero dependency on `package:flutter/widgets.dart`. Reactive UI bindings are cleanly partitioned into a conditional layer or companion package (`flutter_ipfs`) that imports `dart_ipfs`.
2. **Declarative & Lifecycle-Safe**:  
   Widgets handle asynchronous CID resolution, caching, loading states, error fallbacks, and widget disposal without memory or socket leaks.
3. **Multi-Tier Content Cache**:  
   Content addressed by CIDs is immutable. `IpfsImage` leverages an in-memory decoded bitmap cache (LRU) on top of the IPFS local blockstore, eliminating redundant deserialization across widget rebuilds.

---

## 3. Component Architecture

```
+-------------------------------------------------------------------------+
|                        FLUTTER APPLICATION LAYER                        |
|                                                                         |
|      +-----------------------------------------------------------+      |
|      |               IpfsScope (InheritedWidget)                 |      |
|      |              Provides ambient IpfsNode                    |      |
|      +-----------------------------------------------------------+      |
|            |                                           |                |
|            v                                           v                |
|  +--------------------+                     +--------------------+      |
|  |     IpfsImage      |                     |    IpfsBuilder<T>  |      |
|  | Declarative image  |                     | Reactive stream    |      |
|  | widget with cache  |                     | & content resolver |      |
|  +--------------------+                     +--------------------+      |
+-------------------------------------------------------------------------+
                                   |
                                   v
+-------------------------------------------------------------------------+
|                    DART_IPFS CORE ENGINE (lib/src/)                     |
|         IpfsNode  *  BlockStore  *  Bitswap  *  CAR  *  PubSub         |
+-------------------------------------------------------------------------+
```

---

## 4. Widget Specification

### 4.1 `IpfsScope`
Ambient provider injecting an `IpfsNode` instance into the widget subtree:

```dart
class IpfsScope extends InheritedWidget {
  const IpfsScope({
    super.key,
    required this.node,
    required super.child,
  });

  final IpfsNode node;

  static IpfsNode of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IpfsScope>();
    assert(scope != null, 'No IpfsScope found in context');
    return scope!.node;
  }

  @override
  bool updateShouldNotify(IpfsScope oldWidget) => node != oldWidget.node;
}
```

### 4.2 `IpfsImage`
High-level content-addressed image widget with progressive loading, error states, and cached block resolution:

```dart
class IpfsImage extends StatelessWidget {
  const IpfsImage({
    super.key,
    required this.cid,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String cid;
  final WidgetBuilder? placeholder;
  final Widget Function(BuildContext, Object error)? errorWidget;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final node = IpfsScope.of(context);
    return FutureBuilder<Uint8List>(
      future: node.cat(cid),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
          );
        } else if (snapshot.hasError) {
          return errorWidget?.call(context, snapshot.error!) ??
              const Icon(Icons.broken_image);
        }
        return placeholder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      },
    );
  }
}
```

### 4.3 `IpfsBuilder<T>`
Reactive widget connecting an IPFS async operation (block get, DAG resolve, or PubSub stream) to the widget tree:

```dart
class IpfsBuilder<T> extends StatelessWidget {
  const IpfsBuilder({
    super.key,
    required this.future,
    required this.builder,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: builder,
    );
  }
}
```

---

## 5. Verification Plan

1. **Flutter Widget Unit Tests (`testWidgets`)**:
   - Verify `IpfsScope.of(context)` provides ambient node.
   - Verify `IpfsImage` renders placeholder during async retrieval.
   - Verify `IpfsImage` renders `Image.memory` when bytes are emitted.
   - Verify `IpfsImage` renders error widget on invalid CID / timeout.
2. **Memory Leak Audit**:
   - Rapidly mount/unmount `IpfsImage` widgets in scrolling `ListView.builder` to verify memory stabilization and image cache eviction.
