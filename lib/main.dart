import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xFFE5EDE8),
    mint = Color(0xFFB7DCC7),
    muted = Color(0xFF9DB4AD);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF101F25),
    ),
  );
  runApp(QuietApp(prefs: await SharedPreferences.getInstance()));
}

class QuietApp extends StatelessWidget {
  const QuietApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '작은 쉼',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF101F25),
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1C3035),
      ),
    ),
    home: GardenPage(prefs: prefs),
  );
}

enum PlayMode { light, water, rest }

class GardenPage extends StatefulWidget {
  const GardenPage({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController clock;
  late int gathered;
  late bool haptics, still;
  PlayMode mode = PlayMode.light;
  bool foreground = true, sheetOpen = false;
  double seconds = 0;
  Duration previous = Duration.zero;
  final ripples = <Ripple>[];
  final offsets = List<double>.filled(7, 0);
  String? notice;
  Timer? noticeTimer;
  Future<void> saves = Future<void>.value();
  int get flowers => gathered ~/ 5;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gathered = math.max(0, widget.prefs.getInt('gathered') ?? 0);
    haptics = widget.prefs.getBool('haptics') ?? true;
    still = widget.prefs.getBool('still') ?? false;
    clock = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(() {
        final elapsed = clock.lastElapsedDuration ?? Duration.zero;
        final delta = (elapsed - previous).inMicroseconds / 1000000;
        previous = elapsed;
        if (foreground && !sheetOpen) {
          setState(() {
            seconds += delta.clamp(0, .05);
            ripples.removeWhere((r) => seconds - r.created > 2.4);
          });
        }
      })
      ..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      previous = Duration.zero;
      clock.repeat();
    } else {
      clock.stop();
    }
  }

  void persist() {
    final value = gathered, vibration = haptics, motion = still;
    saves = saves
        .then((_) async {
          final result = await Future.wait([
            widget.prefs.setInt('gathered', value),
            widget.prefs.setBool('haptics', vibration),
            widget.prefs.setBool('still', motion),
          ]);
          if (result.contains(false)) throw StateError('Save failed');
        })
        .catchError((Object e) {
          if (mounted) message('저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
        });
  }

  void message(String value) {
    noticeTimer?.cancel();
    setState(() => notice = value);
    noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => notice = null);
    });
  }

  void collect(int index, Size size, double t) {
    final point = lightPosition(index, size, t, offsets[index]);
    setState(() {
      gathered++;
      offsets[index] += 1.9;
      if (ripples.length >= 24) ripples.removeAt(0);
      ripples.add(Ripple(point, seconds, true));
    });
    if (haptics) HapticFeedback.selectionClick();
    persist();
    if (gathered % 5 == 0) message('작은 꽃이 피었어요. 이만큼이면 충분해요.');
  }

  Future<void> showPanel(bool settings) async {
    setState(() => sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 6, 26, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings ? '편안한 쪽으로' : '나의 작은 정원',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (settings) ...[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('작은 진동'),
                      subtitle: const Text('빛을 모을 때 살짝 알려줘요'),
                      value: haptics,
                      onChanged: (v) {
                        setState(() => haptics = v);
                        update(() {});
                        persist();
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('움직임 줄이기'),
                      subtitle: const Text('빛과 풍경이 제자리에 머물러요'),
                      value: still,
                      onChanged: (v) {
                        setState(() => still = v);
                        update(() {});
                        persist();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '소리 없이 즐기는 게임이에요.\n알림도, 출석도, 끝내야 할 목표도 없어요.',
                      style: TextStyle(color: muted, height: 1.8),
                    ),
                    const Divider(height: 36),
                    const Text('작은 쉼  1.0.0', style: TextStyle(color: mint)),
                    const SizedBox(height: 8),
                    const Text(
                      '기록은 이 기기에만 저장돼요. 앱을 삭제하면 정원도 사라져요.\n\n마음을 잠시 환기하는 놀이이며, 치료를 제공하는 앱은 아니에요.',
                      style: TextStyle(color: muted, height: 1.7),
                    ),
                  ] else ...[
                    Text(
                      flowers == 0 ? '아직은 고요한 씨앗의 시간' : '지금까지 $flowers송이가 피었어요',
                      style: const TextStyle(color: mint, fontSize: 17),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 175,
                      width: double.infinity,
                      child: CustomPaint(painter: MiniGarden(flowers)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '빛 다섯 조각이 모이면 꽃 한 송이가 피어요.\n서두르지 않아도, 매일 오지 않아도 괜찮아요.\n꽃은 시들지 않고 여기서 기다릴게요.',
                      style: TextStyle(color: muted, height: 1.9),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('돌아가기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => sheetOpen = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock.dispose();
    noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = still || MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 15, 15, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A LITTLE PAUSE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: mint,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '작은 쉼',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '나의 정원',
                    onPressed: () => showPanel(false),
                    icon: const Icon(Icons.local_florist_outlined, color: mint),
                  ),
                  IconButton(
                    tooltip: '설정',
                    onPressed: () => showPanel(true),
                    icon: const Icon(Icons.tune_rounded, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    switch (mode) {
                      PlayMode.light => '생각은 잠시, 여기 두고',
                      PlayMode.water => '잔잔한 물 위에 톡',
                      PlayMode.rest => '아무것도 하지 않아도 괜찮아요',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (mode) {
                      PlayMode.light => '떠다니는 빛을 천천히 만져 보세요',
                      PlayMode.water => '손끝에서 번지는 물결을 바라보세요',
                      PlayMode.rest => '편한 속도로 숨 쉬며 잠깐 머물러요',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final t = reduced ? 0.0 : seconds;
                  return ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) {
                              if (mode != PlayMode.rest) {
                                setState(() {
                                  if (ripples.length >= 24) ripples.removeAt(0);
                                  ripples.add(
                                    Ripple(d.localPosition, seconds, false),
                                  );
                                });
                              }
                            },
                            child: CustomPaint(
                              painter: ScenePainter(
                                t,
                                seconds,
                                mode,
                                flowers,
                                ripples,
                                reduced,
                              ),
                            ),
                          ),
                        ),
                        if (mode == PlayMode.light)
                          for (var i = 0; i < 7; i++)
                            Positioned(
                              left:
                                  lightPosition(i, size, t, offsets[i]).dx - 30,
                              top:
                                  lightPosition(i, size, t, offsets[i]).dy - 30,
                              child: Semantics(
                                button: true,
                                label: '빛 조각 ${i + 1} 모으기',
                                child: GestureDetector(
                                  onTap: () => collect(i, size, t),
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CustomPaint(
                                      painter: LightPainter(t + i),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        if (mode == PlayMode.rest)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: size.height * .4 - 10,
                            child: const IgnorePointer(
                              child: Text(
                                '그저, 잠깐의 쉼',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: mint,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 6,
                          left: 24,
                          right: 24,
                          child: Text(
                            notice ??
                                switch (mode) {
                                  PlayMode.light =>
                                    flowers == 0
                                        ? '작은 빛이 모이면, 꽃이 피어날 거예요'
                                        : '정원에 $flowers송이의 꽃이 머물고 있어요',
                                  PlayMode.water => '물결은 천천히 사라져요',
                                  PlayMode.rest => '언제든 쉬어 가고, 언제든 떠나도 좋아요',
                                },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: mint,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 17, 25, 12),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2D33),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFF2D4246)),
                ),
                child: Row(
                  children: [
                    modeButton(
                      PlayMode.light,
                      Icons.auto_awesome_outlined,
                      '빛 모으기',
                    ),
                    modeButton(PlayMode.water, Icons.water_outlined, '물결 놀이'),
                    modeButton(
                      PlayMode.rest,
                      Icons.nightlight_outlined,
                      '그냥 쉬기',
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                '잘하려고 애쓰지 않아도 되는 곳',
                style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget modeButton(PlayMode target, IconData icon, String title) => Expanded(
    child: Semantics(
      selected: mode == target,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: mode == target ? const Color(0xFF173730) : muted,
          backgroundColor: mode == target ? mint : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        onPressed: () {
          noticeTimer?.cancel();
          setState(() {
            mode = target;
            ripples.clear();
            notice = null;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

Offset lightPosition(int i, Size s, double t, double phase) => Offset(
  s.width * ([.20, .50, .80, .32, .68, .20, .80][i]) +
      math.sin(t * .24 + i * 2 + phase) * 12,
  s.height * ([.22, .18, .25, .43, .46, .64, .65][i]) +
      math.cos(t * .3 + i + phase) * 12,
);

class Ripple {
  const Ripple(this.point, this.created, this.gold);
  final Offset point;
  final double created;
  final bool gold;
}

class LightPainter extends CustomPainter {
  LightPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), radius = 19 + math.sin(t * .8) * 3;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x70F9E2AA), Color(0x00F9E2AA)],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
    canvas.drawCircle(c, 4, Paint()..color = const Color(0xFFFFEDC2));
    canvas.drawLine(
      c.translate(-8, 0),
      c.translate(8, 0),
      Paint()
        ..color = const Color(0x80FFE6AE)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      c.translate(0, -8),
      c.translate(0, 8),
      Paint()
        ..color = const Color(0x80FFE6AE)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(LightPainter old) => old.t != t;
}

class ScenePainter extends CustomPainter {
  ScenePainter(
    this.t,
    this.elapsed,
    this.mode,
    this.flowers,
    this.ripples,
    this.reduced,
  );
  final double t, elapsed;
  final PlayMode mode;
  final int flowers;
  final List<Ripple> ripples;
  final bool reduced;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          colors: [
            mode == PlayMode.water
                ? const Color(0xFF244B53)
                : const Color(0xFF29483F),
            const Color(0xFF101F25),
          ],
          radius: .75,
        ).createShader(Offset.zero & s),
    );
    for (var i = 0; i < 38; i++) {
      c.drawCircle(
        Offset((i * 73.7) % w, h * .1 + ((i * 41.3) % math.max(1, h * .65))),
        i % 3 == 0 ? 1.2 : .65,
        Paint()
          ..color = mint.withValues(
            alpha: .13 + .10 * (1 + math.sin(t * .3 + i)),
          ),
      );
    }
    final moon = Offset(w * .78, h * .13);
    c.drawCircle(
      moon,
      31,
      Paint()
        ..shader = RadialGradient(
          colors: [mint.withValues(alpha: .14), mint.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: moon, radius: 31)),
    );
    c.drawCircle(moon, 13, Paint()..color = const Color(0xFFD1DFCF));
    c.drawCircle(
      moon.translate(-5, -4),
      12,
      Paint()..color = const Color(0xFF223B36),
    );
    for (var j = 0; j < 3; j++) {
      final path = Path()..moveTo(0, h * (.74 + j * .045));
      path.cubicTo(
        w * .3,
        h * (.59 + j * .05),
        w * .60,
        h * (.94 - j * .035),
        w,
        h * (.71 + j * .08),
      );
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      c.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xFF254740),
            const Color(0xFF1D3B36),
            const Color(0xFF142D2C),
          ][j],
      );
    }
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w * .5, h * .82),
        width: w * .78,
        height: h * .15,
      ),
      Paint()..color = const Color(0xFF284E4E),
    );
    for (var i = 0; i < 4; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(
            w * .50 + math.sin(t * .25 + i) * 3,
            h * (.79 + i * .021),
          ),
          width: w * (.18 + (i % 2) * .18),
          height: 2,
        ),
        Paint()..color = mint.withValues(alpha: .13),
      );
    }
    for (var i = 0; i < 24; i++) {
      if (i < 6 || i < flowers) {
        drawFlower(
          c,
          Offset(w * (.05 + (i * .163) % .9), h * (.81 + (i * .031) % .10)),
          i,
          i < flowers,
          .75 + (i % 3) * .13,
          t,
        );
      }
    }
    if (mode == PlayMode.rest) {
      final radius =
          math.min(w * .32, h * .28) * (1 + math.sin(t * math.pi / 5) * .09);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          Offset(w * .5, h * .4),
          radius + i * 13,
          Paint()
            ..color = mint.withValues(alpha: .16 - i * .04)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final r in ripples) {
      final progress = ((elapsed - r.created) / 2.4).clamp(0.0, 1.0);
      for (var i = 0; i < 3; i++) {
        final radius = reduced ? 20.0 + i * 9 : 8 + progress * (80 + i * 25);
        c.drawOval(
          Rect.fromCenter(
            center: r.point,
            width: radius * 2,
            height: radius * (mode == PlayMode.water ? .65 : 2),
          ),
          Paint()
            ..color = (r.gold ? const Color(0xFFF9DCA5) : mint).withValues(
              alpha: (1 - progress) * (.5 - i * .12),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => true;
}

void drawFlower(Canvas c, Offset p, int i, bool bloom, double scale, double t) {
  final top = p.translate(math.sin(t * .4 + i) * 2, -25 * scale);
  c.drawLine(
    p,
    top,
    Paint()
      ..color = const Color(0xFF779B81)
      ..strokeWidth = 1.6,
  );
  c.drawOval(
    Rect.fromCenter(
      center: p.translate(5, -10),
      width: 10 * scale,
      height: 4 * scale,
    ),
    Paint()..color = const Color(0xFF6D987F),
  );
  if (!bloom) {
    c.drawOval(
      Rect.fromCenter(center: top, width: 5, height: 8),
      Paint()..color = mint,
    );
    return;
  }
  final color = [
    const Color(0xFFF0D2AB),
    const Color(0xFFCCBBDF),
    const Color(0xFFAED4BF),
    const Color(0xFFE9BDB1),
  ][i % 4];
  for (var j = 0; j < 5; j++) {
    final a = j * math.pi * 2 / 5;
    c.drawCircle(
      top.translate(math.cos(a) * 5 * scale, math.sin(a) * 5 * scale),
      4.2 * scale,
      Paint()..color = color,
    );
  }
  c.drawCircle(top, 2.5 * scale, Paint()..color = const Color(0xFFFFE8B6));
}

class MiniGarden extends CustomPainter {
  MiniGarden(this.flowers);
  final int flowers;
  @override
  void paint(Canvas c, Size s) {
    c.drawOval(
      Rect.fromLTWH(0, 60, s.width, 110),
      Paint()..color = const Color(0xFF284840),
    );
    for (var i = 0; i < math.max(5, math.min(flowers, 24)); i++) {
      drawFlower(
        c,
        Offset(
          25 + (i * 47.0) % math.max(1, s.width - 50),
          105 + (i * 19.0) % 45,
        ),
        i,
        i < flowers,
        1.4,
        0,
      );
    }
  }

  @override
  bool shouldRepaint(MiniGarden old) => flowers != old.flowers;
}
