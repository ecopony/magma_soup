import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'widgets/chat_pane.dart';
import 'widgets/results_pane.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF268bd2),      // blue
          onPrimary: Color(0xFFfdf6e3),    // base3
          secondary: Color(0xFF2aa198),    // cyan
          onSecondary: Color(0xFFfdf6e3),  // base3
          error: Color(0xFFdc322f),        // red
          onError: Color(0xFFfdf6e3),      // base3
          surface: Color(0xFFfdf6e3),      // base3
          onSurface: Color(0xFF657b83),    // base00
        ),
        scaffoldBackgroundColor: Color(0xFFeee8d5), // base2
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFfdf6e3),       // base3
          foregroundColor: Color(0xFF657b83),       // base00
        ),
      ),
      home: BlocProvider(
        create: (context) => ChatBloc(),
        child: const MyHomePage(title: 'Command Interface'),
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
      body: Row(
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
