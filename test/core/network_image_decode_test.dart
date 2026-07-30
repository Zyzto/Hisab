import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/platform/network_image_decode.dart';

void main() {
  testWidgets('cachePx scales by device pixel ratio', (tester) async {
    late int px;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Builder(
          builder: (context) {
            px = NetworkImageDecode.cachePx(context, 80);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(px, 160);
  });
}
