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

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

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

  testWidgets('nested filter preserves group FillPaint restriction', (
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
    <filter id="childFilter">
      <feColorMatrix type="saturate" values="0.9"/>
    </filter>
  </defs>
  <g filter="url(#fillOnly)">
    <rect x="14" y="14" width="4" height="4"
        fill="#FF0000" stroke="#0000FF" stroke-width="20"
        filter="url(#childFilter)"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The child filter executes its own non-identity pass, but it must not
    // re-enable stroke painting that the ancestor FillPaint pass disabled.
    final strokeOnlyPixel = _pixelAt(pixels, 6, 16);
    expect(strokeOnlyPixel[3], lessThan(10));

    final fillPixel = _pixelAt(pixels, 16, 16);
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

  testWidgets('objectBoundingBox group filter resolves vertical text geometry', (
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
    <text x="18" y="4" font-size="24" font-weight="bold"
        writing-mode="vertical-rl" fill="#E4DCEA">H</text>
  </g>
</svg>''';

    final glyphPixel = _pixelAt(await _renderSvgPixels(tester, svg), 10, 10);

    // The vertical Latin glyph is rotated by the text painter. Its target
    // bounds must be recorded so the objectBoundingBox turbulence pass runs.
    expect(glyphPixel[0], isNot(closeTo(0xE4, 2)));
    expect(glyphPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter records rotated glyph bounds', (
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
    <text x="23" y="23" font-size="24" font-weight="bold" rotate="-90"
        fill="#E4DCEA">H</text>
  </g>
</svg>''';

    final rotatedGlyphPixel = _pixelAt(
      await _renderSvgPixels(tester, svg),
      15,
      22,
    );

    // This pixel is inside the rotated H but outside its pre-rotation box.
    // A recorded unrotated box clips the objectBoundingBox filter output here.
    expect(rotatedGlyphPixel[0], isNot(closeTo(0xE4, 2)));
    expect(rotatedGlyphPixel[3], greaterThan(0));
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

  testWidgets('objectBoundingBox group filter maps switch child transform', (
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
      <path d="M0 0 H8 V8 H0 Z" transform="translate(16 16)" fill="#E4DCEA"/>
    </switch>
  </g>
</svg>''';

    // The path occupies [16,24] after its transform. The filter region is
    // derived from the mapped bounds, so the turbulence pass covers the
    // translated area instead of the origin.
    final insidePixel = _pixelAt(await _renderSvgPixels(tester, svg), 20, 20);
    expect(insidePixel[0], isNot(closeTo(0xE4, 2)));
    expect(insidePixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter uses symbol content bounds', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <symbol id="quarter" viewBox="0 0 100 100">
      <rect width="50" height="50" fill="#E4DCEA"/>
    </symbol>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#quarter" width="32" height="32"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The symbol content fills only a quarter of its viewBox, mapping to
    // [0,16] in the use viewport. The filter region stays near that area.
    final contentPixel = _pixelAt(pixels, 8, 8);
    expect(contentPixel[0], isNot(closeTo(0xE4, 2)));
    expect(contentPixel[3], greaterThan(0));

    // Far outside the content-derived filter region nothing is painted.
    // A viewport-sized bound would have leaked turbulence here.
    final outsidePixel = _pixelAt(pixels, 28, 28);
    expect(outsidePixel[3], 0);
  });

  testWidgets('objectBoundingBox group filter unions repositioned tspan', (
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
    <text x="2" y="26" font-size="20" fill="#E4DCEA">i<tspan x="26" y="26">B</tspan></text>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The tspan repositions "B" to x=26. Measuring the text as one
    // continuous run from x=2 would miss this area; the real layout
    // pipeline reports both glyph boxes.
    final tspanPixel = _pixelAt(pixels, 29, 22);
    expect(tspanPixel[0], isNot(closeTo(0xE4, 2)));
    expect(tspanPixel[3], greaterThan(0));
  });

  testWidgets('group StrokePaint input excludes descendant fills', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="strokeOnly" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTile in="StrokePaint"/>
    </filter>
  </defs>
  <g filter="url(#strokeOnly)">
    <rect x="10" y="10" width="12" height="12"
        fill="#FF0000" stroke="#0000FF" stroke-width="8"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The fill-only area (beyond the stroke ring) must not reach the
    // StrokePaint output.
    final fillPixel = _pixelAt(pixels, 16, 16);
    expect(fillPixel[3], 0);

    // The stroke ring must be present where fill does not reach.
    final strokePixel = _pixelAt(pixels, 7, 16);
    expect(strokePixel[2], closeTo(0xFF, 2));
    expect(strokePixel[3], greaterThan(0));
  });

  testWidgets('nested filter preserves group StrokePaint restriction', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="strokeOnly" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTile in="StrokePaint"/>
    </filter>
    <filter id="childFilter">
      <feColorMatrix type="saturate" values="0.9"/>
    </filter>
  </defs>
  <g filter="url(#strokeOnly)">
    <rect x="10" y="10" width="12" height="12"
        fill="#FF0000" stroke="#0000FF" stroke-width="8"
        filter="url(#childFilter)"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The child filter executes its own non-identity pass, but it must not
    // re-enable fill painting that the ancestor StrokePaint pass disabled.
    final fillPixel = _pixelAt(pixels, 16, 16);
    expect(fillPixel[3], lessThan(10));

    final strokePixel = _pixelAt(pixels, 11, 16);
    expect(strokePixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter resolves duplicate sibling use', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <rect id="dupRect" width="8" height="8" fill="#E4DCEA"/>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#dupRect"/>
    <use href="#dupRect" x="20"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // Both siblings must contribute bounds; a chain-scoped guard bug would
    // drop the second use and shrink the filter region to the first rect.
    final firstPixel = _pixelAt(pixels, 4, 4);
    expect(firstPixel[0], isNot(closeTo(0xE4, 2)));
    expect(firstPixel[3], greaterThan(0));
    final secondPixel = _pixelAt(pixels, 24, 4);
    expect(secondPixel[0], isNot(closeTo(0xE4, 2)));
    expect(secondPixel[3], greaterThan(0));
  });

  testWidgets('objectBoundingBox group filter maps use target root transform', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <rect id="shiftedRect" width="8" height="8"
        transform="translate(16 16)" fill="#E4DCEA"/>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#shiftedRect"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The referenced rect carries its own transform; the filter region must
    // cover the translated position.
    final shiftedPixel = _pixelAt(pixels, 20, 20);
    expect(shiftedPixel[0], isNot(closeTo(0xE4, 2)));
    expect(shiftedPixel[3], greaterThan(0));
    final originPixel = _pixelAt(pixels, 4, 4);
    expect(originPixel[3], 0);
  });

  testWidgets('objectBoundingBox group filter maps use-svg viewport', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <svg id="inner" viewBox="0 0 100 100">
      <rect width="50" height="50" fill="#E4DCEA"/>
    </svg>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#inner" width="32" height="32"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    final contentPixel = _pixelAt(pixels, 8, 8);
    expect(contentPixel[0], isNot(closeTo(0xE4, 2)));
    expect(contentPixel[3], greaterThan(0));
    final outsidePixel = _pixelAt(pixels, 28, 28);
    expect(outsidePixel[3], 0);
  });

  testWidgets('objectBoundingBox group filter maps use-svg root transform', (
    tester,
  ) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <svg id="shiftedInner" transform="translate(37.5 37.5)"
        viewBox="0 0 100 100">
      <rect width="50" height="50" fill="#E4DCEA"/>
    </svg>
    <filter id="obbTurbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#shiftedInner" width="32" height="32"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    // The referenced svg carries translate(37.5) in viewBox units, so its
    // content lands at [12, 28] in the 32x32 viewport instead of [0, 16].
    // A bounds path that ignores the referenced root transform would put
    // the filter region at the origin.
    final shiftedPixel = _pixelAt(pixels, 20, 20);
    expect(shiftedPixel[0], isNot(closeTo(0xE4, 2)));
    expect(shiftedPixel[3], greaterThan(0));
    final originPixel = _pixelAt(pixels, 4, 4);
    expect(originPixel[3], 0);
  });

  testWidgets(
    'objectBoundingBox group filter maps a referenced svg own viewport chain',
    (tester) async {
      const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <svg id="inner" x="10" width="200" height="100"
        transform="scale(0.5)" viewBox="0 0 100 100">
      <rect width="50" height="50" fill="#E4DCEA"/>
    </svg>
    <filter id="obbTurbulence" x="0" y="0" width="1" height="1">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#obbTurbulence)">
    <use href="#inner" width="32" height="32"/>
  </g>
</svg>''';

      final pixels = await _renderSvgPixels(tester, svg);

      // Rendering applies the referenced SVG's own viewport mapping before
      // its x/y and transform, then maps it through the <use> viewport. The
      // resulting source bounds are approximately [9.6, 0]–[17.6, 8].
      final contentPixel = _pixelAt(pixels, 14, 4);
      expect(contentPixel[0], isNot(closeTo(0xE4, 2)));
      expect(contentPixel[3], greaterThan(0));
      final outsidePixel = _pixelAt(pixels, 4, 4);
      expect(outsidePixel[3], 0);
    },
  );

  testWidgets('group filter composites with a partial-alpha mask', (
    tester,
  ) async {
    const turbulenceOnlySvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turb)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';
    const maskedSvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
    <mask id="halfMask" maskUnits="userSpaceOnUse" mask-type="alpha"
        x="0" y="0" width="32" height="32">
      <rect width="32" height="32" fill="#FFFFFF" fill-opacity="0.5"/>
    </mask>
  </defs>
  <g filter="url(#turb)" mask="url(#halfMask)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final unmasked = _pixelAt(
      await _renderSvgPixels(tester, turbulenceOnlySvg),
      16,
      16,
    );
    final masked = _pixelAt(await _renderSvgPixels(tester, maskedSvg), 16, 16);

    // The filter still runs under the mask, and the mask halves the alpha.
    expect(masked[0], isNot(closeTo(0xE4, 2)));
    expect(masked[3], closeTo((unmasked[3] * 0.5).round(), 4));
  });

  testWidgets('group filter composites with a luminance mask', (tester) async {
    const turbulenceOnlySvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turb)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';
    const maskedSvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
    <mask id="grayMask" maskUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <rect width="32" height="32" fill="#808080"/>
    </mask>
  </defs>
  <g filter="url(#turb)" mask="url(#grayMask)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final unmasked = _pixelAt(
      await _renderSvgPixels(tester, turbulenceOnlySvg),
      16,
      16,
    );
    final masked = _pixelAt(await _renderSvgPixels(tester, maskedSvg), 16, 16);

    // #808080 has ~0.5 luminance, so the filtered output is half masked.
    expect(masked[0], isNot(closeTo(0xE4, 2)));
    expect(masked[3], closeTo((unmasked[3] * 0.5).round(), 8));
  });

  testWidgets('group filter composites with group opacity', (tester) async {
    const turbulenceOnlySvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turb)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';
    const opacitySvg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
  </defs>
  <g filter="url(#turb)" opacity="0.5">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final unmasked = _pixelAt(
      await _renderSvgPixels(tester, turbulenceOnlySvg),
      16,
      16,
    );
    final withOpacity = _pixelAt(
      await _renderSvgPixels(tester, opacitySvg),
      16,
      16,
    );

    expect(withOpacity[0], isNot(closeTo(0xE4, 2)));
    expect(withOpacity[3], closeTo((unmasked[3] * 0.5).round(), 4));
  });

  testWidgets('group filter output is clipped by clip-path', (tester) async {
    const svg = '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="turb" filterUnits="userSpaceOnUse"
        x="0" y="0" width="32" height="32">
      <feTurbulence type="fractalNoise" baseFrequency="0.25"
          numOctaves="1" seed="19"/>
    </filter>
    <clipPath id="leftHalf">
      <rect x="0" y="0" width="16" height="32"/>
    </clipPath>
  </defs>
  <g filter="url(#turb)" clip-path="url(#leftHalf)">
    <rect width="32" height="32" fill="#E4DCEA"/>
  </g>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg);

    final insidePixel = _pixelAt(pixels, 8, 16);
    expect(insidePixel[0], isNot(closeTo(0xE4, 2)));
    expect(insidePixel[3], greaterThan(0));
    final clippedPixel = _pixelAt(pixels, 24, 16);
    expect(clippedPixel[3], 0);
  });

  testWidgets('use with its own objectBoundingBox filter resolves bounds', (
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
  <use href="#fullRect" filter="url(#obbTurbulence)"/>
</svg>''';

    final centerPixel = _pixelAt(await _renderSvgPixels(tester, svg), 16, 16);

    // A use with its own filter previously got zero bounds and fell back to
    // the unchanged source.
    expect(centerPixel[0], isNot(closeTo(0xE4, 2)));
    expect(centerPixel[3], greaterThan(0));
  });
}
