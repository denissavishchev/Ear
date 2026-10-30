import 'package:flutter/material.dart';

import 'audio/audio_engine.dart';
import 'model/trainer.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final trainer = Trainer(AudioEngine());
  await trainer.load();
  runApp(EarsApp(trainer: trainer));
}

class EarsApp extends StatelessWidget {
  final Trainer trainer;
  const EarsApp({super.key, required this.trainer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ears',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(trainer: trainer),
    );
  }
}
