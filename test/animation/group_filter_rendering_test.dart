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

  testWidgets('group FillPaint input excludes descendant strokes', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="fillOnly" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTile in="FillPaint"/>
    </filter>
  </defs>
  <g filter="url(#fillOnly)">
    <rect x="14" y="14" width="4" height="4"
        fill="#FF0000" stroke="#0000FF" stroke-width="20"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The tiny rect spans [14,18]; its 20-wide stroke covers (6,16) without
    // covering it with fill. FillPaint must not contain the stroke, so this
    // pixel stays transparent.
    final strokeOnlyPixel = _pixelAt(pixels, 6, 16);
    expect(strokeOnlyPixel[3], 0);

    // The fill itself must still reach the output.
    final fillPixel = _pixelAt(pixels, 16, 16);
    expect(fillPixel[0], closeTo(0xFF, 2));
    expect(fillPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves path geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <path d="M0 0 H32 V32 H0 Z" fill="#E4DCEA"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    // A fallback renders the unchanged lavender source; a real turbulence
    // pass replaces it with noise.
    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves use geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <rect id="fullRect" width="32" height="32" fill="#E4DCEA"/>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#fullRect"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('group filter still applies under an identity white mask', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turbulence" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
    <mask id="whiteMask" maskUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <rect width="32" height="32" fill="#FFFFFF"/>
    </mask>
  </defs>
  <g filter="url(#turbulence)" mask="url(#whiteMask)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    // The white mask is an identity operation, so the turbulence pass must
    // still run instead of painting the unchanged lavender source.
    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves polygon geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <polygon points="0,0 32,0 32,32 0,32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves polyline geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <polyline points="0,0 32,0 32,32 0,32 0,0" fill="#E4DCEA"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves transformed path', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <path d="M0 0 H8 V8 H0 Z" transform="translate(12 12)" fill="#E4DCEA"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves positioned use', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <rect id="smallRect" width="8" height="8" fill="#E4DCEA"/>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#smallRect" x="12" y="12"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves nested container path', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <g>
      <path d="M0 0 H32 V32 H0 Z" fill="#E4DCEA"/>
    </g>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves switch child geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <switch>
      <path d="M0 0 H32 V32 H0 Z" fill="#E4DCEA"/>
    </switch>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter handles empty switch', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <switch>
      <path systemLanguage="xx-nonexistent" d="M0 0 H32 V32 H0 Z"
          fill="#E4DCEA"/>
    </switch>
  </g>
</svg>''';

    // No child is selected, so nothing renders; the bounds resolution must
    // not throw and must yield an empty output.
    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[3], 0);
  });

  testWidgets('objectBoundingBox group filter resolves text geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <text x="2" y="26" font-size="24" fill="#E4DCEA">Hi</text>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves use-symbol geometry', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <symbol id="sym" viewBox="0 0 32 32">
      <rect width="32" height="32" fill="#E4DCEA"/>
    </symbol>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#sym" width="32" height="32"/>
  </g>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });
}
