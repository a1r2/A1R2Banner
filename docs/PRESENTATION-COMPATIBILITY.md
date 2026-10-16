# Presentation compatibility: 0.1.1

The contract is 0.1.0 adaptive measurement plus the observable presentation
semantics of `d6807c26b335537fb2306f0d8114bbafcfad3aae`. Published 0.1.0 is
`29d68a5c40b424af0001537ed215c284c76ceecb`. This correction adds no public API,
compatibility mode, placement mode, or device-specific sizing.

## Semantic invariants

| Position | Resting host anchor | Additional rows |
| --- | --- | --- |
| topLeading | top leading | singleton replacement |
| topCenter | top center | singleton replacement |
| topTrailing | top trailing | singleton replacement |
| bottomLeading | bottom leading | upward, oldest lowest |
| bottomCenter | bottom center | upward, oldest lowest |
| bottomTrailing | bottom trailing | upward, oldest lowest |

Bottom piling requires `stacks: true`. A singleton is excluded from accumulation;
enqueuing a singleton replaces existing rows at its position. Positions otherwise
remain independent. Leading/trailing follow layout direction. Deprecated iOS
`BannerPlacement.adaptive` and `.fixed` both forward to the same initializer and
have no rendering effect, as in the reference.

`showFrom` is independent of the resting anchor:

| Edge | Insertion | Removal |
| --- | --- | --- |
| top | from above, moving down | upward |
| bottom | from below, moving up | downward |
| leading | from semantic leading, moving toward trailing | toward leading |
| trailing | from semantic trailing, moving toward leading | toward trailing |

The reference move envelope was the content size plus 40 points per axis because
20-point padding preceded `.move(edge:)`. Travel is relative to the resting
content, not across an entire screen. Caller-provided animation curves are retained;
Reduce Motion suppresses translation. Direct `stackOffset` is signed y translation
multiplied by effective explicit scale. It changes presentation, not measurement.

The intentional 0.1.0 sizing improvements remain: native `renderScale: nil`, explicit
positive finite scales, `maximumWidth`, bounded custom content, white built-in
foreground, adaptive resizing, and caller-owned usable/safe regions. Decorative
insets retain 0.1.0's `min(20, hostLength / 10)` calculation. The supplied host is
the ultimate drawing and interaction boundary, including on tvOS.

## Actual regression mechanisms

0.1.0 placed a conditional moving child inside an intrinsic clipped ZStack. The
clip stayed at its resting footprint, so a slide could become a wipe/reveal.
The padded travel envelope was also lost. Direct offsets became clamped inward
layout reservations and lost explicit-scale multiplication. Grouping rows by
anchor changed cross-anchor draw order. Measuring a conditional child let its
allocation collapse while the queue still retained the outgoing row. Finally,
all rows in a group contributed to spacing, including nonstacking singletons.

Measured-height stacking itself is an intentional 0.1.0 improvement. It is
preserved: actual measured row heights plus `stackGap` determine pile spacing,
including wrapping, Dynamic Type and resizing. Frame-height queue estimates remain
model metadata and never determine rendered stack positions. The reference's
estimated-height spacing is deliberately not restored.

## Small measurement/presentation seam

- `BannerContentLayout` retains 0.1.0 bounded content measurement unchanged.
- `BannerRegionLayout` retains measured placement and accumulates independently
  per position, while traversing rows in global enqueue/draw order. Only stacking
  bottom rows consume stack space.
- `BannerPresentation` keeps its bounded row measured until the manager removes
  it. Hiding its drawing therefore cannot collapse stack allocation prematurely.
- `BannerMotion`/`BannerTranslation` translate drawing and native interaction
  without changing the measured footprint. Progress uses the caller's animation;
  the historical padded travel vector and signed direct offset are explicit.
  Drawing ends on animation completion, not when an interpolated progress value
  first reaches 1; spring overshoot therefore remains visible until completion.
- Content is clipped before presentation to bound resistant custom content. The
  transformed result is clipped at the final host, not at its resting rectangle.
- `BannerHostHits` intersects translated content rectangles with host bounds.
  Its background GeometryReader resolves interaction anchors only. Hit rectangles
  do not feed proposals, measurements, padding, or placement. Empty gaps pass
  interaction through to the host.

There is no region subdivision policy in this patch. The previous investigation's
region subdivision code, tests, frame-hint renderer, viewport-size state and
subpixel-rounding workaround have been removed.

## Freeze investigation

The former uncommitted candidate stalled in
`HostedLayoutTests.testNarrowAndShortPresentationSurface`, which offers widths
0, 1, 12, 44 and 120 with height 40 and seven content variants. Its observed
viewport fed back into padding; a nonzero fallback at zero could repeatedly
invalidate measurement. This particular feedback mechanism was introduced during
the investigation, not established as a released 0.1.0 defect.

The simplified candidate has no measurement-driven geometry state or padding
feedback. Hit-only preference state cannot change content measurement. In addition
to rerunning the original scenario, `testLayoutSettlesAfterMotionAndZeroWidthResizing`
counts real Layout measurement calls after a transition, resizes through zero and
small/large widths, then requires the count and measured frame to stop changing
without a new geometry change. This checks the actual SwiftUI graph, not a copied
measurement formula.

## Test classification and reproduction

```sh
output_dir="$(mktemp -d)"
python3 Validation/compare-presentation.py "$output_dir"
```

The script captures a single fixture byte sequence, hashes it, copies those exact
bytes into both historical archives, and checks that source/test hashes remain
unchanged during the run. The historical reference runs the public-API presentation
fixture. Published 0.1.0 and the candidate also run their complete macOS adaptive
suites. `results.json` records each
method's actual/expected status, commands, commit IDs and hashes. Build failures,
missing tests and timeouts cannot count as expected semantic failures.

Historical presentation regressions should pass reference, fail 0.1.0, and pass
candidate: moving-body visibility/direction across all six anchors and four edges,
signed/scaled direct offsets, exit-space retention, singleton exclusion, and global
cross-anchor draw order. Representative app fixtures are a shared behavior control;
they need not fail on 0.1.0 to be useful. The intentional adaptive test with inaccurate
height hints should fail reference and pass both 0.1.0 and candidate.

Raster frames are diagnostic observations, not golden images. Direction, relative
placement, visible body, ordering and gap assertions define behavior. Wall-clock
animation phases have broad bounds because snapshots cannot control SwiftUI's
internal clock. Linear probes use 1.2-second curves; app curves run at one-quarter
speed for capture with the same time dilation on all three revisions.

## iptvFaves representative fixtures

No iptvFaves source or package configuration is changed by this SDK patch. The
fixtures retain the original 26-point error font. App styling changes are not
consumed or included here.

| Fixture | Position | Placement | Edge / curve before capture dilation | Stack offset | Original duration |
| --- | --- | --- | --- | --- | --- |
| channel title | topTrailing | default | trailing / easeInOut 0.3 s | 0 | 4 s |
| playback error | bottomTrailing | default | trailing / spring response 0.5, damping 0.6 | 0 | 7.6 s |
| metadata | bottomTrailing | default | bottom / easeInOut 0.3 s | 0 | 3 s |

All use frame.zero and do not pile. Content uses the original structure: title
font 34 with three-line limit, error font 26 with four-line limit, metadata font
26 with two-line rows; each has 20-point content padding and white foreground.
Synthetic strings avoid app/user data. Fixture logs record host size, transition,
position, placement, offset, actual content proposal, measured content and visible
resting bounds. Tests use an identical 4-second public duration override and explicit
scale 1 to isolate presentation from the intentional removal of automatic iOS
scaling. The app's nil-scale configuration is covered separately by native-scale
adaptive tests; reference automatic device scaling is not restored.

These captures establish SDK behavior for representative configurations. They do
not identify the precise original in-app instance without a correlated recording.

## Final verification (2026-10-16)

All final checks used unchanged SDK and test sources. Fixture SHA-256:
`c46c07087ead3432fe15a6915e112e33330a510628473d6c6be3d1c3ebbe556b`.
Detailed per-method expectations, actual statuses, source hashes and commands are
recorded in the validation output directory as `results.json`; raw frames are
recorded in the adjacent `comparison.html` gallery.

| Check | Final result |
| --- | --- |
| Complete candidate macOS suite | 67 tests, zero failures, one existing capture skip |
| Complete iPhone suite | 65 tests, zero failures, one existing capture skip |
| iPad hosted suite | 18 tests, zero failures, one existing capture skip |
| Duo hosted suite | 18 tests, zero failures, one existing capture skip |
| Complete tvOS suite | 64 tests, zero failures, no skips |
| iOS/tvOS Debug Starter builds for testing | both passed |
| iOS/tvOS device-SDK Release Starter builds | both passed |
| git diff --check | passed |

The shared skip is composited Liquid Glass hierarchy capture, not a skipped
presentation or measured-layout test. The tvOS foreground raster check passed.
The original 17-method adaptive hosted suite also passed on published 0.1.0
(with its existing capture skip), and remains covered by the candidate's expanded
21-method macOS hosted suite.

Six historical presentation methods pass reference, fail 0.1.0 and pass candidate:
insertion/removal movement and visible body, signed direct offsets, explicitly
scaled offsets, retained exit allocation, singleton exclusion, and cross-anchor
draw order/stack ordering. The original-size app fixture is a PASS/PASS/PASS control.
The inaccurate-height-hint measured-stack test is intentionally FAIL/PASS/PASS.
Consequently reference and published test processes exit nonzero for different,
expected assertions; the harness validates each method rather than treating a
nonzero exit by itself as proof.

One reference run overlapping simulator startup had animation-clock timing failures.
The reference was rerun alone under the same fixture/source hashes and met every
expected status. The earlier log and matrix are preserved as
`reference-concurrent.log` and `results-before-reference-recheck.json`. This remains
wall-clock rendering evidence, not frame-exact animation-clock control.

At a 240x300 host, the actual proposal/measured sizes are title 169x120, error
173x100 and metadata 194x130 on all three revisions. At 800x300 they are title
223x80, error 274.5x70 and metadata 226x100. Raster bounds can differ by half a point
at rounded edges. Representative mid-insertion observations expose the regression:
0.1.0 title height contracts to 96.5 from a 120-point resting height; metadata's
left edge drifts from x=26 at rest to x=63 while its requested movement is vertical.
Reference and candidate preserve the title height and metadata x anchor during
that movement. The broad app-fixture assertions pass on 0.1.0 too; these raw
observations supplement the discriminating all-anchor/edge regression test.

Validation logs and generated comparison artifacts are external evidence, not
repository contents. Reproduction creates fresh logs in the selected output
directory. No app integration, physical-device playback, or interactive VoiceOver
preference check is claimed. iptvFaves was left untouched.
