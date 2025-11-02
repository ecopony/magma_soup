// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:magma_soup/main.dart';
import 'package:magma_soup/services/api_client.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    // Create a mock API client for testing
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:3001',
      httpClient: http.Client(),
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(apiClient: apiClient));

    // Verify the app title is displayed
    expect(find.text('Magma Soup'), findsOneWidget);
  });
}
