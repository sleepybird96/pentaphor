# PENTAPHOR — Quest flow study 03

Open `quest-flow.html` in a browser. It uses the existing 60 PNGs in `../assets/quest-art/` and can run directly from the filesystem. Google Fonts are optional; system fonts are the fallback.

The creation and completion screens appear beside each other on desktop and stack on small screens. Choose an action illustration from the searchable category library, name the quest, set a weekly/monthly frequency and allocate up to two points. The completion preview follows the draft. Art tiles have no visible names; only categories are shown on the selected card and achievement header. Descriptions remain available for screen readers and search. Choosing art preserves the quest name and rewards.

Registering a quest opens the sample quest list. Completing a quest updates the achievement screen, stats and period progress. The selected illustration enters first, then the rewarded pentagon vertices spring outward and settle. Reduced-motion preferences show the final state immediately.

The sample running quest is one completion away from a second consecutive weekly target; bathroom cleaning demonstrates the equivalent monthly bonus. Perseverance bonuses are separate from the two-point allocation, awarded once per target crossing and restored correctly by undo.

This is a design prototype with in-memory demo state, not the shipping app. Refresh resets it. Calendar rollover, persistence and native app integration are outside this study. The weekly deadline text retains the agreed Monday 09:00 rule.

Files:
- `quest-flow.html`: inspectable screens and form markup.
- `quest-flow.css`: ivory/ink/teal visual system, responsive layout and entrance animations.
- `quest-flow.js`: local interactions and the pentagon animation reused from the earlier approved prototype.
- `quest-art-data.js`: all 60 asset references, labels, categories and search aliases.
- `quest-flow-desktop.png`, `quest-create-mobile.png`, `quest-achievement-mobile.png`, `quest-art-picker-mobile.png`: browser captures for review.

Verified in headless Chrome: all 60 images decode, library search/category/pagination, maximum two-point allocation, custom-name preservation, keyboard form submission, monthly registration, completion/undo, weekly and monthly bonuses without duplication, reduced motion, and layouts at 1120/736/390/320 px. No JavaScript runtime errors were observed.
