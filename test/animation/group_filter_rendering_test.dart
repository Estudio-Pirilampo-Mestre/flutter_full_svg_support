import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

Future<Uint8List> _renderSvgPixels(WidgetTester tester, String svg) async {
  final repaintBoundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: SizedBox(
            width: 32,
            height: 32,
            child: AnimatedSvgPicture.string(svg),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final pixels = await tester.runAsync<Uint8List?>(() async {
    final boundary =
        repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });

  expect(pixels, isNotNull);
  return pixels!;
}

List<int> _pixelAt(Uint8List pixels, int x, int y) {
  const width = 32;
  final offset = ((y * width) + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

int _sourceOverAlpha(int backgroundAlpha, int foregroundAlpha) {
  return (foregroundAlpha + backgroundAlpha * (1 - foregroundAlpha / 255))
      .round()
      .clamp(0, 255);
}

void main() {
  testWidgets('group filter composites every pass after a transparent flood', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="basic" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feFlood flood-color="#FF0000" flood-opacity="0" result="flood"/>
      <feBlend mode="normal" in="SourceGraphic" in2="flood" result="shape"/>
    </filter>
  </defs>
  <g filter="url(#basic)">
    <rect x="5" y="5" width="22" height="22" rx="3" fill="#E4DCEA"/>
  </g>
</svg>''';

    final repaintBoundaryKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: AnimatedSvgPicture.string(svg),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pixels = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    });

    expect(pixels, isNotNull);
    const centerPixelOffset = ((16 * 32) + 16) * 4;
    final centerPixel = pixels!.sublist(
      centerPixelOffset,
      centerPixelOffset + 4,
    );

    expect(centerPixel[0], closeTo(0xE4, 2));
    expect(centerPixel[1], closeTo(0xDC, 2));
    expect(centerPixel[2], closeTo(0xEA, 2));
    expect(centerPixel[3], 0xFF);
  });

  testWidgets('group filter executes a turbulence pass', (tester) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turbulence" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turbulence)">
    <rect x="0" y="0" width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final repaintBoundaryKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: AnimatedSvgPicture.string(svg),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pixels = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    });

    expect(pixels, isNotNull);
    const centerPixelOffset = ((16 * 32) + 16) * 4;
    final centerPixel = pixels!.sublist(
      centerPixelOffset,
      centerPixelOffset + 4,
    );

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
  });

  testWidgets('group filter bounds include transformed child geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turbulence" filterUnits="objectBoundingBox"
        x="0" y="0" width="1" height="1">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turbulence)">
    <rect width="8" height="8" transform="translate(12 12)" fill="#E4DCEA"/>
  </g>
</svg>''';

    final repaintBoundaryKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: AnimatedSvgPicture.string(svg),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pixels = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    });

    expect(pixels, isNotNull);
    const centerPixelOffset = ((16 * 32) + 16) * 4;
    final centerPixel = pixels!.sublist(
      centerPixelOffset,
      centerPixelOffset + 4,
    );

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('group filter composites repeated SourceGraphic passes', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="repeat" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <g filter="url(#repeat)">
    <rect x="4" y="4" width="24" height="24"
        fill="#204060" fill-opacity="0.5"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    // Two 50%-alpha source-over draws produce ~75% output alpha.
    expect(centerPixel[3], closeTo(191, 3));
  });

  testWidgets(
    'group filter preserves ordinary passes around a turbulence pass',
    (tester) async {
      const turbulenceOnlySvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turbulence" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turbulence)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';
      const mixedPassesSvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="mixed" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19" result="noise"/>
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="noise"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <g filter="url(#mixed)">
    <rect width="32" height="32" fill="#E4DCEA" fill-opacity="0.5"/>
  </g>
</svg>''';

      const sourceGraphicAlpha = 0x80;
      final turbulencePixel = _pixelAt(
        await _renderSvgPixels(tester, turbulenceOnlySvg),
        16,
        16,
      );
      final mixedPixel = _pixelAt(
        await _renderSvgPixels(tester, mixedPassesSvg),
        16,
        16,
      );

      // Alpha composition is independent of color-space rounding. One source
      // pass would produce a different alpha, so this proves both ordinary
      // SourceGraphic passes survive the specialized turbulence pass.
      final expectedAlpha = _sourceOverAlpha(
        _sourceOverAlpha(0, sourceGraphicAlpha),
        turbulencePixel[3],
      );
      final expectedMixedAlpha = _sourceOverAlpha(
        expectedAlpha,
        sourceGraphicAlpha,
      );
      expect(mixedPixel[3], closeTo(expectedMixedAlpha, 2));
    },
  );
}
