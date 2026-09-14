# PENTAPHOR approved icon — 2026-09-14

User selected the SHIFT study and requested a rigid 180-degree rotation of the entire ivory/teal emblem. The ivory pentagon points down-left; the teal rear band frames exactly two upper-right edges. `approved-icon-study.png` preserves the approved presentation.

Production assets:

- `Pentaphor/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: opaque RGB 1024×1024, full-bleed dark background, system-applied corner mask.
- `Pentaphor/Assets.xcassets/BrandIcon.imageset/BrandIcon.png`: identical image, used by the shared native BrandBar in home and achievement screens.

Generated with the built-in image generation tool. The production-format edit extended the dark background over the presentation margin/corners; the approved emblem's orientation and geometry were retained. `sips` resized the production output to Apple's 1024×1024 asset size. No new logo design was requested or introduced during integration.

Production edit prompt:

> Prepare this approved app icon image for an actual iOS AppIcon asset. It is a production-format background edit, NOT a redesign. Preserve the entire ivory pentagon and upper-right teal two-arm mark pixel-faithfully: same shape, same rotation, same proportions, same gap, same exact position and scale within the full square canvas as this reference. The ivory pentagon points downward-left; teal hugs just two edges on its upper-right. Change ONLY THE BACKGROUND: replace all cream/ivory outer margin and rounded tile corners with the same deep green-black color as the existing tile, extending the dark background to all four square edges and all four corners. The result is a fully opaque full-bleed SQUARE dark canvas, with NO rounded corners baked in, NO light-colored outer border, NO outside margin, NO transparency. Do not crop or rescale the central symbol. Do not shift, recolor, redraw, distort or rotate it. Keep the exact approved symbol and its generous padding. No typography, no mockup, no shadow. Output the single square production icon, ready for iOS to apply its own corner mask.

The existing user-selected development Team is persisted in `project.yml`, so regenerating the Xcode project preserves device signing configuration.

## Verification

- Simulator build succeeded; compiled Info.plist declares `AppIcon` and icon renditions are present.
- Physical iOS development build succeeded with the user's existing signing identity/profile. `codesign --verify --deep --strict` and device-bundle inspection passed. The updated build has not been installed on the physical phone in this change.
- Existing UI acceptance: 2 tests, 0 failures (46.295s), `/tmp/pentaphor-icon-ui.xcresult`.
- Home and achievement captures were visually inspected: `home-preview.png`, `achievement-preview.png`.
- Both image sets use identical SHA-256 content. App icon is 1024×1024 without alpha.
- Bundle inspection confirms all 60 existing quest PNGs plus declared app icon renditions and compiled brand assets; no source/generation metadata is bundled.
