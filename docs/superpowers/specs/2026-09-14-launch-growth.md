# Launch growth

Approved: cold launch presents [logo] PENTAPHOR, STACK YOUR PROGRESS, and a teal five-axis polygon. Every axis pops once per cycle in a randomized order and by a randomized amount. A cycle lasts 1.2 seconds including settling. Numbers and actual user scores are not shown. Pure presentation data never mutates AppState.

A successful or failed load resolves the load gate. Reveal home/onboarding or the recoverable error only at a completed cycle boundary, with at least one cycle. Slow loading continues subsequent cycles with continuous geometry. Errors must not loop forever. Retrying starts a fresh loading presentation. Ordinary background/resume does not replay a completed cold-launch sequence. If interrupted mid-cycle, resume with a whole cycle.

System Reduce Motion uses a static logo/polygon and a short 0.2-second presentation. The saved achievement simplified-effects preference must never affect launch motion (user correction, 2026-09-14). No launch haptics. Keep existing SwiftData loading, signing, and all user records intact.

Implementation: deterministic seeded pure cycle geometry and a load/cycle gate in PentaphorCore; SwiftUI loading view with TimelineView/Canvas; app root controls presentation and error retry. Local persistence uses the existing main-actor repository. Tests inject asynchronous delay/failure only in DEBUG UI-test launch paths to exercise pending/error routing.

Verify: gate ordering, no finish before a full cycle, late load waits until next boundary, deterministic bounded motion and independent axes, settled continuity across cycles; native cold launch → onboarding/home, background resume, launch still animates with stored achievement simplification enabled, failed load → error. Run full core and UI suites, signed device build, and inspect screen/video captures.

Visual polish: native iOS static launch background uses the same ink color; the animated entry hides the status bar until leaving.

Layout correction: lower the logo/name/slogan group by 32pt while keeping the polygon and footer positions.
