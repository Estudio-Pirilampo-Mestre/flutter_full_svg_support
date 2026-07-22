# full_svg_flutter documentation

This folder contains user-facing guides, localized documentation, feature
references, migration notes, and known limitations for `full_svg_flutter`.

The primary user guide is available in the three most widely spoken languages
by total speakers:

| Language | Guide | Audience |
|---|---|---|
| English | [doc/en/usage.md](en/usage.md) | Global Flutter developers |
| 简体中文 | [doc/zh-Hans/usage.md](zh-Hans/usage.md) | Mandarin Chinese readers |
| हिन्दी | [doc/hi/usage.md](hi/usage.md) | Hindi readers |

Each localized guide explains installation, choosing the right widget,
rendering static and animated SVGs, playback control, SVGator and JavaScript
exports, theming, accessibility, external assets, performance, limitations,
migration from `flutter_svg`, and troubleshooting.

## Quick navigation

### I want to use the package

- [English usage guide](en/usage.md)
- [简体中文使用指南](zh-Hans/usage.md)
- [हिन्दी उपयोग गाइड](hi/usage.md)
- [Migration from flutter_svg](migration_from_flutter_svg.md)
- [Supported SVG features](supported_features.md)
- [Known limitations](limitations.md)

### I want to evaluate SVG support

- [Supported SVG features](supported_features.md)
- [Limitations](limitations.md)

## Package summary

`full_svg_flutter` is a Flutter SVG renderer for static and animated SVG files.
It provides:

- a `flutter_svg`-compatible `SvgPicture` API for static SVGs
- `FSvgPicture`, a unified widget that auto-detects animations
- `AnimatedSvgPicture` for explicit animation playback and controller support
- SMIL animation, CSS `@keyframes`, path morphing, gradients, masks, filters,
  text, hit-testing, accessibility metadata, and JavaScript-driven SVG support
- embedded QuickJS runtime support for SVGator JavaScript exports and custom
  SVG scripts

Install it with:

```bash
flutter pub add full_svg_flutter
```

Then import:

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

For the complete walk-through, open one of the localized usage guides above.

## Published documents

Only public, package-user documentation is linked from this index. Internal
development notes, audit reports, release plans, marketing drafts, and archived
stage reports are intentionally not part of the published documentation set.

| File | Purpose |
|---|---|
| [supported_features.md](supported_features.md) | Detailed SVG feature matrix |
| [limitations.md](limitations.md) | Known limitations and workarounds |
| [migration_from_flutter_svg.md](migration_from_flutter_svg.md) | Step-by-step migration guide |
| [en/usage.md](en/usage.md) | Complete usage guide in English |
| [zh-Hans/usage.md](zh-Hans/usage.md) | Complete usage guide in Simplified Chinese |
| [hi/usage.md](hi/usage.md) | Complete usage guide in Hindi |
