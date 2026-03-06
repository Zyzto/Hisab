import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/layout/content_aligned_app_bar.dart';

void main() {
  testWidgets(
    'ContentAlignedAppBar keeps long title clear of leading and actions',
    (tester) async {
      const titleRowKey = Key('group-title-row');
      const longGroupName =
          'This is a very long group name that should never overlap toolbar icons';

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(360, 800)),
            child: Scaffold(
              appBar: ContentAlignedAppBar(
                contentAreaWidth: 360,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: _noop,
                ),
                title: Row(
                  key: titleRowKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        longGroupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.person_add),
                    onPressed: _noop,
                  ),
                  IconButton(
                    icon: Icon(Icons.settings),
                    onPressed: _noop,
                  ),
                ],
              ),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.byKey(titleRowKey));
      final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
      final inviteButtonRect = tester.getRect(find.byIcon(Icons.person_add));

      expect(
        titleRect.left,
        greaterThanOrEqualTo(backButtonRect.right),
      );
      expect(
        titleRect.right,
        lessThanOrEqualTo(inviteButtonRect.left),
      );
    },
  );
}

void _noop() {}
