import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/participant_avatar.dart';

void main() {
  testWidgets('ParticipantAvatar shows emoji for known avatarId', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParticipantAvatar(name: 'Alice', avatarId: 'smile'),
        ),
      ),
    );

    expect(find.text('😊'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('ParticipantAvatar falls back to initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParticipantAvatar(name: 'Bob', avatarId: 'initials'),
        ),
      ),
    );

    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('ParticipantAvatar uses initials override', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParticipantAvatar(
            name: 'Alice Bob',
            avatarId: null,
            initials: 'AB',
          ),
        ),
      ),
    );

    expect(find.text('AB'), findsOneWidget);
  });
}
