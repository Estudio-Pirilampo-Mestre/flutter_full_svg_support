import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

Future<Uint8List> _renderSvgPixels(WidgetTester tester, String content) async {
  final repaintBoundaryKey = GlobalKey();
  final svg =
      '''
<svg width="32" height="32" viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg">
  $content
</svg>''';

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

    final image = await boundary.toImage(pixelRatio: 1);
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

int _visiblePixelCount(Uint8List pixels) {
  var result = 0;
  for (var index = 3; index < pixels.length; index += 4) {
    if (pixels[index] > 10) result++;
  }
  return result;
}

void main() {
  const fillBoxOrigin =
      'style="transform-box:fill-box;transform-origin:50% 50%"';

  for (final shape in <String, String>{
    'path': '<path d="M8 8 H16 V16 H8 Z"',
    'polygon': '<polygon points="8,8 16,8 16,16 8,16"',
    'polyline': '<polyline points="8,8 16,8 16,16 8,16 8,8"',
  }.entries) {
    testWidgets('${shape.key} rotates around its fill-box center', (
      tester,
    ) async {
      final pixels = await _renderSvgPixels(
        tester,
        '${shape.value} fill="#ff0000" transform="rotate(180)" '
        '$fillBoxOrigin/>',
      );

      expect(_pixelAt(pixels, 12, 12)[3], greaterThan(200));
    });
  }

  testWidgets('path scales around its fill-box center', (tester) async {
    final pixels = await _renderSvgPixels(
      tester,
      '<path d="M8 8 H16 V16 H8 Z" fill="#ff0000" '
      'transform="scale(0.5)" $fillBoxOrigin/>',
    );

    expect(_pixelAt(pixels, 12, 12)[3], greaterThan(200));
    expect(_pixelAt(pixels, 8, 8)[3], lessThan(10));
  });

  testWidgets('text rotates around its measured fill bounds', (tester) async {
    final pixels = await _renderSvgPixels(
      tester,
      '<text x="8" y="18" font-size="10" fill="#ff0000" '
      'transform="rotate(180)" $fillBoxOrigin>Hi</text>',
    );

    expect(_visiblePixelCount(pixels), greaterThan(10));
  });

  testWidgets('positioned use includes x and y in its fill bounds', (
    tester,
  ) async {
    final pixels = await _renderSvgPixels(tester, '''
<defs><rect id="tile" width="8" height="8" fill="#ff0000"/></defs>
<use href="#tile" x="8" y="8" transform="rotate(180)" $fillBoxOrigin/>''');

    expect(_pixelAt(pixels, 12, 12)[3], greaterThan(200));
  });

  testWidgets('use maps symbol viewBox content into its fill bounds', (
    tester,
  ) async {
    final pixels = await _renderSvgPixels(tester, '''
<defs>
  <symbol id="tile" viewBox="0 0 10 20">
    <rect width="10" height="20" fill="#ff0000"/>
  </symbol>
</defs>
<use href="#tile" x="8" y="8" width="8" height="8"
    transform="rotate(180)" $fillBoxOrigin/>''');

    expect(_pixelAt(pixels, 12, 12)[3], greaterThan(200));
  });

  testWidgets('use maps referenced svg viewBox content into its fill bounds', (
    tester,
  ) async {
    final pixels = await _renderSvgPixels(tester, '''
<defs>
  <svg id="tile" viewBox="0 0 10 20">
    <rect width="10" height="20" fill="#ff0000"/>
  </svg>
</defs>
<use href="#tile" x="8" y="8" width="8" height="8"
    transform="rotate(180)" $fillBoxOrigin/>''');

    expect(_pixelAt(pixels, 12, 12)[3], greaterThan(200));
  });
}
