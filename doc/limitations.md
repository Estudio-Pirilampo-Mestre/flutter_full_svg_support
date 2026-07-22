# Limitations

`full_svg_flutter` is a full-featured SVG renderer, but it is not a full browser engine. This document lists known limitations honestly so you can evaluate whether the package fits your use case.

---

## JavaScript

As of 1.1.0, JavaScript inside SVG files **is executed** by an embedded
QuickJS engine ([`quickjs_engine`](https://pub.dev/packages/quickjs_engine))
running against a polyfilled SVG DOM. This covers:

- inline `<script>` blocks and `<script src="...">` references
- SVGator files exported in **JavaScript** animation mode
- hand-written JS animations that walk the SVG via
  `document.getElementById` + `setAttribute`

What still won't work:

- code that depends on the **full browser DOM** (`window.location`,
  `History` API, full HTML layout, IndexedDB, WebGL, etc.) — only SVG-DOM
  surface is polyfilled
- inline HTML event handlers (`onclick="…"` on SVG elements) — use
  `addEventListener` from a `<script>` instead
- third-party JS frameworks that try to bootstrap a browser environment

If a JS-export SVGator file (or any other JS-driven SVG) renders
incorrectly, please open an issue with the offending `.svg` attached. The
SVG-DOM polyfill is still growing and missing methods get added as we
encounter real-world cases.

---

## External resources

Cross-origin external resources (images, fonts, stylesheets linked via `href` or `xlink:href` to an external domain) follow Flutter's platform security policy. On most platforms they will not load unless you configure the appropriate network permissions.

Local `file://` URIs work on all non-web platforms. On the web, browser security policy restricts `file://` access.

---

## SVG filters

All 17 filter primitives are implemented, but complex stacked filter chains may produce results that differ slightly from browser rendering. The differences are typically due to:

- floating-point precision in convolution math
- color-space handling (sRGB vs linearRGB) in edge cases
- compositing order differences in nested filter regions

---

## Text layout

Text rendering is handled by Flutter's paragraph layout engine, which differs from browsers in some edge cases:

- Mixed RTL+LTR within a single `<text>` element may differ in line-breaking
- Some OpenType features (discretionary ligatures, contextual alternates) depend on the available system fonts
- `<tref>` (referencing external text content) has partial support

---

## `<foreignObject>`

`<foreignObject>` is parsed and its bounding box is included in layout, but its content is not rendered. This is intentional — rendering arbitrary HTML inside Flutter is not possible without a WebView.

---

## Malformed SVG

Malformed SVG files may produce unexpected results or silent failures. The parser is lenient by design (browsers are too), but severely invalid SVG may need preprocessing.

---

## Performance on very complex SVGs

SVGs with hundreds of animated elements, deep filter chains, or very large path datasets may impact frame rate on lower-end devices. Use the `raster` rendering strategy for static-or-rarely-updated complex SVGs:

```dart
FSvgPicture.asset('assets/complex.svg', renderingStrategy: RenderingStrategy.raster)
```

---

## Web platform: `file://` URI images

`<image href="file://...">` is not supported on the web platform. The web stub returns `null` gracefully, so the image element is silently skipped.

---

## Reporting issues

If you encounter a rendering difference from a browser, please open an issue at the [GitHub repository](https://github.com/denisnadey/flutter_full_svg_support/issues) with:

1. The SVG file or a minimal reproduction
2. A screenshot of the expected (browser) output
3. A screenshot of the actual (Flutter) output
4. The platform and Flutter version
