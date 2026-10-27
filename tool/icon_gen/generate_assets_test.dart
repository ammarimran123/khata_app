// Regenerates the app icon and splash-image PNGs from RuledMonogram.
// Not a real test — lives outside test/ so `flutter test` never picks it
// up by accident. Run explicitly after changing the brand mark:
//   flutter test tool/icon_gen/generate_assets_test.dart
//
// Rendering to PNG needs the Flutter engine's dart:ui (RepaintBoundary +
// Canvas), which a plain `dart run` script doesn't have access to — the
// flutter_test harness is the simplest way to get it for a one-off image
// export like this. toImage()'s callback resolves on a real engine
// thread outside flutter_test's FakeAsync zone, so it must run inside
// tester.runAsync() or the awaited Future never completes.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_app/core/theme/app_colors.dart';
import 'package:khata_app/features/splash/presentation/widgets/ruled_monogram.dart';

// flutter_test replaces every font with a glyph-less placeholder (solid
// blocks) by design, so widget-layout tests don't depend on real font
// rendering. A real font must be loaded explicitly to render actual
// letterforms for image export. Arial Black is a heavy, standalone
// system TTF — close enough to Archivo 800 for a two-letter monogram,
// and needs no network fetch the way google_fonts would.
const _fontFamily = 'IconGenFont';
const _fontPath = '/System/Library/Fonts/Supplemental/Arial Black.ttf';

Future<void> _loadIconFont() async {
  final bytes = await File(_fontPath).readAsBytes();
  final loader = FontLoader(_fontFamily)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _capture(
  WidgetTester tester,
  Widget canvasContent,
  String outputPath,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: canvasContent,
      ),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(outputPath)..createSync(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    // ignore: avoid_print
    print('Wrote $outputPath (${byteData.lengthInBytes} bytes)');
  });
}

void main() {
  testWidgets('generate icon + splash assets', (tester) async {
    // The test surface defaults to 800x600 logical px, which silently
    // clamps a 1024 SizedBox at the root — force the real canvas size.
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(_loadIconFont);

    // Full icon: opaque bg fill, full-bleed — used for iOS and Android's
    // legacy icon.
    await _capture(
      tester,
      const RuledMonogram(
        size: 1024,
        backgroundColor: AppColors.bg,
        fontFamily: _fontFamily,
      ),
      'assets/icon/icon.png',
    );

    // Adaptive-icon foreground: transparent bg, mark inset to ~62% so the
    // border survives circular/squircle mask cropping on Android.
    await _capture(
      tester,
      Center(
        child: RuledMonogram(
          size: 1024 * 0.62,
          backgroundColor: null,
          fontFamily: _fontFamily,
        ),
      ),
      'assets/icon/icon_foreground.png',
    );

    // Splash image: transparent bg, inset similarly, composited over
    // flutter_native_splash's configured background color.
    await _capture(
      tester,
      Center(
        child: RuledMonogram(
          size: 1024 * 0.45,
          backgroundColor: null,
          fontFamily: _fontFamily,
        ),
      ),
      'assets/icon/splash_logo.png',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
