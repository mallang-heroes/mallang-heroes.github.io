import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/mallang_game.dart';
import 'platform/web_loader.dart';
import 'ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const MallangApp());
}

class MallangApp extends StatelessWidget {
  const MallangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '말랑영웅전',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Pretendard', useMaterial3: true),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final game = MallangGame();

  @override
  void initState() {
    super.initState();
    // 그림 받는 진행률을 웹 로딩 화면에 전달 (다 받으면 로딩 화면이 사라짐)
    game.loadProgress.addListener(() => reportWebLoader(game.loadProgress.value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E4A2E),
      body: LayoutBuilder(
        builder: (context, box) {
          final portrait = box.maxHeight > box.maxWidth;
          return Stack(
            children: [
              GameWidget<MallangGame>(
                game: game,
                overlayBuilderMap: {
                  'barracks': (context, g) => BarracksDialog(game: g),
                  'detail': (context, g) => DetailDialog(game: g),
                  'held': (context, g) => HeldBanner(game: g),
                  'palace': (context, g) => PalaceDialog(game: g),
                  'result': (context, g) => ResultDialog(game: g),
                },
              ),
              if (portrait) const RotateHint(),
            ],
          );
        },
      ),
    );
  }
}
