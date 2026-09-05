import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ipfs/flutter_ipfs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpfsBuilder & IpfsStreamBuilder', () {
    testWidgets('IpfsBuilder transitions from loading to data', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IpfsBuilder<String>(
            future: completer.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Waiting');
              }
              if (snapshot.hasData) {
                return const Text('Got Data');
              }
              return const SizedBox();
            },
          ),
        ),
      );

      expect(find.text('Waiting'), findsOneWidget);

      completer.complete('Hello IPFS');
      await tester.pumpAndSettle();

      expect(find.text('Got Data'), findsOneWidget);
    });

    testWidgets('IpfsStreamBuilder updates on new events', (tester) async {
      final controller = StreamController<int>();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IpfsStreamBuilder<int>(
            stream: controller.stream,
            initialData: 0,
            builder: (context, snapshot) {
              return Text('Count: ');
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      controller.add(42);
      await tester.pump();

      expect(find.text('Count: 42'), findsOneWidget);

      await controller.close();
    });
  });
}
