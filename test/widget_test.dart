import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:h_app_y/main.dart';

void main() {
  testWidgets(
    'Lights grow a flower, persist, restore; modes and settings work',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(QuietApp(prefs: prefs));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('빛 조각 1 모으기'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(prefs.getInt('gathered'), 5);
      await tester.tap(find.byTooltip('나의 정원'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('지금까지 1송이가 피었어요'), findsOneWidget);
      await tester.tap(find.text('돌아가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('물결 놀이'));
      await tester.pump();
      expect(find.text('잔잔한 물 위에 톡'), findsOneWidget);
      expect(find.bySemanticsLabel('빛 조각 1 모으기'), findsNothing);
      await tester.tapAt(const Offset(180, 280));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('그냥 쉬기'));
      await tester.pump();
      expect(find.text('아무것도 하지 않아도 괜찮아요'), findsOneWidget);
      await tester.tap(find.byTooltip('설정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('작은 진동'));
      await tester.pump();
      expect(prefs.getBool('haptics'), false);
      await tester.tap(find.text('움직임 줄이기'));
      await tester.pump();
      expect(prefs.getBool('still'), true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(QuietApp(prefs: prefs));
      await tester.tap(find.byTooltip('나의 정원'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('지금까지 1송이가 피었어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Small screen and large text remain usable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'gathered': 125});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: GardenPage(prefs: prefs),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Render phone preview', (tester) async {
    if (!File('C:/Windows/Fonts/malgun.ttf').existsSync()) return;
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('PreviewKorean')
        ..addFont(
          File(
            'C:/Windows/Fonts/malgun.ttf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    SharedPreferences.setMockInitialValues({'gathered': 40});
    final prefs = await SharedPreferences.getInstance();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF101F25),
            colorScheme: ColorScheme.fromSeed(
              seedColor: mint,
              brightness: Brightness.dark,
            ),
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'PreviewKorean',
            ),
          ),
          home: GardenPage(prefs: prefs),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs').create();
      await File('docs/preview.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
