import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'bloc/chat_bloc.dart';
import 'bloc/map_bloc.dart';
import 'services/api_client.dart';
import 'widgets/chat/chat_pane.dart';
import 'widgets/results/results_pane.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_SERVER_URL'] ?? 'http://localhost:3001',
  );

  runApp(MyApp(apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  final ApiClient apiClient;

  const MyApp({super.key, required this.apiClient});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magma Soup',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF268bd2), // blue
          onPrimary: Color(0xFFfdf6e3), // base3
          secondary: Color(0xFF2aa198), // cyan
          onSecondary: Color(0xFFfdf6e3), // base3
          error: Color(0xFFdc322f), // red
          onError: Color(0xFFfdf6e3), // base3
          surface: Color(0xFFfdf6e3), // base3
          onSurface: Color(0xFF657b83), // base00
        ),
        scaffoldBackgroundColor: const Color(0xFFeee8d5), // base2
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFfdf6e3), // base3
          foregroundColor: Color(0xFF657b83), // base00
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<MapBloc>(
            create: (context) => MapBloc(),
          ),
          BlocProvider<ChatBloc>(
            create: (context) => ChatBloc(
              apiClient: apiClient,
              mapBloc: context.read<MapBloc>(),
            ),
          ),
        ],
        child: const MyHomePage(title: 'Magma Soup'),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: const Row(
        children: [
          Expanded(
            flex: 1,
            child: ChatPane(),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFF93a1a1), // base1
          ),
          Expanded(
            flex: 1,
            child: ResultsPane(),
          ),
        ],
      ),
    );
  }
}
