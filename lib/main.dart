import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home.dart';
import 'home_viewmodel.dart';

final player = AudioPlayer();

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => HomeViewModel())],
      child: MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Consumer<HomeViewModel>(
        builder: (context, viewModel, child) {
          return Home(viewModel: viewModel);
        },
      ),
    );
  }
}
