import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

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
}
