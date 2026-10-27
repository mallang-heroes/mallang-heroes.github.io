import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/mallang_game.dart';
import 'platform/web_loader.dart';
import 'ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      backgroundColor: const Color(0xFF1E1814),
      body: LayoutBuilder(
        builder: (context, box) {
          // 세로 화면 게임. 가로로 넓은 화면(PC·태블릿 가로)에서는 가운데에 폰 비율로 보여 준다.
          final width = math.min(box.maxWidth, box.maxHeight * 0.6);
          return Center(
            child: SizedBox(
              width: width,
              height: box.maxHeight,
              child: ClipRect(child: GameShell(game: game)),
            ),
          );
        },
      ),
    );
  }
}
