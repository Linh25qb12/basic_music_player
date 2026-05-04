import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/music_player_app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicPlayerApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
