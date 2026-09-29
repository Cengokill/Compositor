# Compositor — instructions for coding agents
Read this file before every code, test, documentation, or UI change. Read the current main branch and the relevant issue or PR discussion too. This is working context, not a substitute for inspecting implementation. Recheck dated status and numeric limits before relying on them.
Evidence convention: “Owner decision” means an explicit maintainer comment or an implementation the maintainer accepted and adjusted on main. “Engineering rule” is guidance inferred from those decisions and the current architecture. PR numbers provide traceability; a contributor's proposal or an open PR does not establish maintainer approval. A newer explicit user or maintainer instruction takes precedence over this snapshot.
Snapshot: 29 September 2026. Maintainer: robbietilton. This update reviews the PRs closed between 24 and 29 September 2026. Source of truth for behavior is current main, including follow-up commits after a PR merge.
## 1. Product direction
- Compositor is a free, open-source, native macOS editor for compositing, photo post-processing, visual effects, and adjustments. Preserve the familiar parts of Photoshop's workflow that help produce a pixel-perfect final image. See README.md and PR #107.
- The product is not becoming a full drawing, illustration, or painting application. The owner explicitly declined brush blend modes in PR #107 despite their presence in Photoshop.
- A feature needs a concrete compositing workflow. Check whether an existing selection, layer control, adjustment, or shortcut already solves it before adding a parallel tool or setting. PRs #95, #96, #107.
- Distinguish a useful idea from its proposed implementation: a closed PR can lead to a different solution on main. Do not restore its branch wholesale. PRs #82, #95.
- Minimize ongoing work for a solo maintainer: prefer small, complete features over new subsystems, menus, maintenance commitments, and unverified product promises. PRs #37, #39, #67, #82.
- Keep menus deliberately short and contextual. The owner declined the broad Photoshop-style Layers menu surface in PR #163, while taking only selected useful pieces onto main, including Ungroup Layers and focused mask actions.
- Only change a product default when the owner wants that change; a bug fix is not authorization for an unrelated default change. PR #59.
- Favor neutral visual defaults and remember subjective user preferences. Outer Glow was adopted with neutral white instead of a proposed cyan default; Auto Select remains off by default while the user's choice persists. PRs #55, #59.
- The current README targets macOS 26.0 or newer on Apple silicon; verify the project settings and release script before claiming Universal support. The owner declined macOS 15 support because maintaining availability checks across releases would burden every future feature. PR #72 and current main.
- Keep the scope of AI features open. MCP integrations in PRs #89 and #91 were closed; the owner would rather reconsider AI workflows as a whole than bolt MCP onto the current editor. Do not link third-party MCP tools as if they were reviewed or endorsed; agents can use docs/writing-comp-files.md directly. PRs #58, #89, #91, #128.
- Production localization is deferred because translating and reviewing every future UI string is ongoing work the owner cannot currently verify. PRs #37, #57, #94, #126, #148. The later contributor suggestions of an English String Catalog or a Chinese localization have no maintainer acceptance.
- A separate Paint Bucket was declined. For the occasional photo/compositing case, use Magic Wand, adjust the selection, then invoke the existing fill shortcut. PR #96.
- A separate Crop to Selection menu action was declined: the Crop tool now initializes from an active selection on main. PR #95.
- Do not add a large dedicated preset browser for New Canvas without a new decision. The accepted direction is a small menu with screen and resolution sizes rather than the proposed preset sheet. PR #141.
- Keep the current export scope deliberate: PNG and JPEG remain the supported user-facing export choices. Compositor's 8-bit-per-channel pipeline means higher-bit export does not add image detail; extra TIFF, AVIF, or HEIC controls were declined. PR #149.
## 2. Required workflow before editing
1. Identify the user-visible problem or requested behavior and the current branch state. Reproduce a defect when possible; record the file and steps for an import, render, or memory failure.
2. Read the latest maintainer comment and current main implementation. A proposed branch may target an obsolete ContentView, tab strip, model, or limit. PRs #39, #42, #105, #108, #116, #163.
3. Find the existing owner of the behavior: state model, undo command, renderer, import path, UI entry point, validation, format mapping, or test.
4. Trace the paths affected by the change: editing, snapshot, save/reopen, canvas preview, export, masks, clipping, folders, undo/redo, and cancellation as applicable.
5. Make one independently reviewable product change. Do not add incidental defaults, broad refactors, unrelated compiler fixes, or other features. PRs #39, #59.
6. Integrate with existing models and generic paths instead of adding duplicate state or a competing lifecycle. PRs #54, #55, #82.
- If a contribution contains independent changes, keep them separable so the maintainer can take only the accepted commits. PR #163 was closed after selected commits were applied to main.
7. Build and run focused checks. For interactions, test the actual macOS behavior manually when feasible. Report exact commands, inputs, results, and any checks that could not run.
- Treat compiler warnings as architectural signals: verify actor isolation and Sendable assumptions at the real call sites, especially for pixel/export work on workers. Use nonisolated or Sendable only when the state is actually safe to access there; do not silence warnings blindly. PRs #118, #153.
8. Rebase on current main for final review; remove workarounds or tests that a main-branch change superseded. A merge is not endorsement of every submitted detail. PRs #39, #55, #105, #108.
9. Update this file when a new explicit maintainer decision changes its guidance. Mark an undecided proposal as undecided.
- Do not commit review artifacts such as PR_REVIEW_*.md in a feature branch unless explicitly requested. The owner asked for PR_REVIEW_140.md to be removed before merging. PR #140.
## 3. Native document and compatibility
- The native editable working format is a .comp package containing manifest.json and embedded image assets. Save editable work as .comp; PSD is an import/interchange format. PR #39.
- New .comp saves use version 11. ProjectManifest.current and ProjectManifest.supported in Compositor/IO/ProjectStore.swift define the current and readable versions; current main reads versions 1–11. PRs #90, #137, #140.
- Read docs/project-format.md and the model, loader, serializer, and tests before changing a persisted field. The guide must now be checked through version 11; PR #104 covered 7–9 and PRs #137/#140 added later text-run fields.
- Add explicit version gates when an older-format declaration could otherwise claim a new semantic feature. Preserve defaults for omitted optional fields and readability of supported older documents.
- Preserve layer IDs, order, editable metadata, original image pixels, transparency, masks, transforms, effects, adjustments, text, shapes, guides, and resolution wherever the operation is meant to retain them.
- Per-letter text formatting is persisted through validated UTF-16 runs: colorRuns were added in format 10 and fontRuns in format 11. Reject overlapping, out-of-range, or version-inconsistent runs. PSD import still does not recover per-letter color or font runs. PRs #137, #140.
- Empty layers have no image asset. Exported PNG/JPEG images are flattened derivatives; exporting does not count as saving project edits.
- A text layer retains a PNG display/export fallback alongside editable text metadata. If a destructive pixel operation rasterizes it, drop the editable metadata deliberately; do not leave metadata that misdescribes the pixels.
- A shape retains editable style metadata while its pixels still represent that shape. A later destructive edit may require dropping that metadata; preserve the raster fallback for older readers.
- Version-specific structures have real validity rules: groups must form a valid acyclic hierarchy, clipping-mask references must be valid, and masks must have safe asset paths and matching layer relationships. Use the validators already in the project.
- Save through the existing coordinated atomic package replacement. Malformed metadata, missing assets, unsafe paths, unsupported versions, or encoding failures must leave the current document intact.
- An open .comp package watches external changes through file-system events rather than polling. The final main implementation fingerprints the manifest plus image names and sizes, ignores touches and the app's own saves, defers checks during edits, prompts on unsaved work, leaves the live document intact for failed or half-written loads, preserves viewport/folders/selection where possible, and resets undo history like a fresh open. PR #116.
- Exercise round trips: edit, snapshot, save, reopen, render, and export. Effects had once been stored in a record but dropped at the snapshot/install handoff; repair that handoff rather than inventing second persistence. PRs #54, #55.
- When changing the schema, update docs/project-format.md and meaningful round-trip and rejection tests. The owner prefers that guide and GitHub release notes over a repository changelog narrating each diff. PRs #54, #55.
- Documentation drift to fix when touching limits: docs/project-format.md still says 100 MP for image/mask budgets, although PR #108 changed the governing values. Consult current DocumentLimits.swift and the enforcement sites instead of propagating the obsolete text.
- Do not promise PSD export or editable Photoshop round trips. The owner deferred a PSD writer because it could imply editability the app cannot actually preserve; prove the reader first. PR #39.
## 4. PSD and other external imports
- Importing PSD should recover an editable Compositor document where possible, using the current layer, folder, mask, blend, and shape models. Some text and vector data becomes pixels; do not claim unsupported data stays editable. PR #39.
- Before any lossy conversion or omission changes the live document, show the conversion report and allow cancellation. Cancel must leave the existing document unchanged. PR #39.
- PSB is a registered/importable Photoshop large-image type on main, but remains subject to the same 8-bit RGB and conversion limits. CMYK and non-8-bit RGB need clear errors rather than silent or misleading conversion. Judge individual unsupported elements by safe, intelligible conversion, omission, or rejection. PRs #39, #120.
- A long PSD load must acknowledge the click immediately and show progress during parsing, not just after reading has completed. PR #39.
- Display the actual source filename, not the UUID name of a temporary import copy. PR #39.
- Preserve Photoshop as the Finder default editor where appropriate; the PSD declaration used an Alternate role rather than claiming ownership. PR #39.
- Validate binary identity, dimensions, layer/pixel budgets, and encoded data before expensive decoding. The PSD importer checks the 8BPS magic and budgets before raw or RLE expansion. PR #39.
- Substantial parsers need clear provenance and authoritative format references. Implement from the published specification; do not adapt GPL reader code into this MIT-licensed app. PR #39.
- Automated fixtures alone are insufficient for a complex importer. Test representative real PSD files with different layers, masks, transforms, sizes, and conversion cases before claiming merge readiness. PR #39.
- Use current capabilities during conversion: when group opacity landed on main, PSD group opacity could be imported instead of dropped or merely reported. Re-evaluate a conversion when the model improves. PR #39.
- Keep import, export, UI, and unrelated compiler repairs independently reviewable. PR #39.
## 5. Layers, masks, adjustments, and rendering
- Moving, scaling, rotating, and flipping normally retain full-resolution source pixels and store transforms separately. Rasterize only for an explicitly destructive operation.
- Painting and retouching on a transformed or scaled layer must operate in the layer's own pixel grid to preserve source resolution. Clone Stamp and Blur use that grid; Sample All Layers intentionally samples the document view. Brush tips must remain smooth even without Metal. PR #162.
- Respect bottom-to-top sibling ordering and contiguous folder subtrees. Preserve inherited visibility, pass-through folders, group opacity, clipping links, raster and folder masks, and linked or independent mask placement.
- Folder blend mode stays Normal because folder rendering is pass-through; folder opacity multiplies into its descendants. Do not silently substitute an isolated-group compositing model.
- Raster masks and linked clipping masks are different mechanisms. A disabled raster mask remains embedded and editable, while moving or deleting a clipping base must preserve or explicitly resolve its dependents.
- Adding a layer mask from a selection reveals the selection by default; Option-click adds the opposite mask. Option-clicking a mask thumbnail shows that mask alone in grayscale, and GPU and Core Graphics previews must use the mask background outside existing values. PR #163, accepted subset.
- An operation on a layer or group must preserve or intentionally change its editable properties through move, duplicate, merge, crop, resize, import, save, and undo. Test affected transitions.
- Reuse the generic Layer Effects model and renderer; do not make a text-only or feature-specific effects pipeline. PR #55.
- New live filters belong in the existing Adjustment Layers model. After evaluating PR #82, the owner adopted Gaussian Blur, Motion Blur, and Add Noise there, along with existing mask, clipping, opacity, blend, edit, and persistence behavior. The separate Filter Layers system and remaining filter types were declined.
- Interpret blur radii and distances in document pixels, independent of preview zoom. Pad partial redraws so a brush change under a blur cannot expose a tile seam. PR #82.
- Keep Add Noise stable in canvas coordinates and across sessions; a partial redraw must not reshuffle or tile its random field. PR #82.
- For blend math sensitive to working color space, set Core Image's working space explicitly. Color Dodge and Color Burn must agree with the canvas sRGB rendering. PR #34.
- Test effect extremes and fallback paths through the shared renderer; large Outer Glow radii and glyph-shaped silhouettes exposed useful cases. PR #55.
- Check that preview, export, thumbnails, and reopened content agree where a feature affects several rendering paths.
## 6. UI, preferences, and edit lifecycle
- Keep controls native, discoverable, and in the existing workflow. Photoshop familiarity helps when it clarifies an editing task; it does not override Compositor's product scope.
- Keep layer blend modes in the Layers panel as their single visible source. Do not add a hidden per-brush Mode control: the owner closed PR #107 because it makes unexpected paint results difficult to diagnose and pushes toward a painting toolset.
- Keep Layers context menus short and target-specific. A right-click selects the row under the pointer when needed, but do not add the full menu surface proposed in PR #163; only the commands explicitly accepted on main are authoritative.
- Brush Flow is declined: it overlaps with opacity and would make the simple compositing brush harder to understand. Do not add it without a new product decision. PR #106.
- Preview a temporary adjustment while its control is open; commit it once accepted, or restore the prior state on Cancel. Include the active text being edited in foreground-color previews. PR #99 merged, followed by an owner fix on main.
- Prefer coherent undo transactions to an undo step for every preview or character. Text undo granularity in PR #100 remains a proposal; check main before relying on it.
- Preserve the current Auto Select default-off behavior and persist user-selected Auto Select and relevant view/snap preferences across launches. PR #59.
- Holding Command temporarily flips Auto Select either way; holding Shift temporarily flips the transform aspect-lock state. Held modifiers must be reflected in the Move bar without affecting fields while typing. PR #163, accepted subset.
- Reuse CameraRawSlider and GradientSliderCell for filter controls that need visual value tracks. Double-clicking a label or knob resets only that setting to the filter's model default and preserves the current preview state. PR #136.
- For macOS title-bar or tab changes, test dragging, hit testing, overflow scrolling, and newly created tabs on a supported macOS build. PR #105 superseded the older PR #42 branch.
- Tabs may be dragged to reorder, and overflowed tabs move into an "N more tabs" menu. Tab order is session-only and tab movement is not an undoable document edit. PR #163, accepted subset.
- In the current tab strip, keep the right-edge fade visible until each new tab strip has measured, and do not animate its first measurement: the owner corrected a visible flicker after merging PR #105.
- Treat a UI test's failure to discover an NSSlider or another AppKit view as possibly OS-specific before assuming the app is broken. Inspect real behavior on a supported OS. PR #34.
- For AppKit lifecycle callbacks, hop to the main actor instead of asserting isolation unless the callback's executor is guaranteed. PR #147 fixed an activation crash caused by MainActor.assumeIsolated.
- View › Grid Settings belongs to user preferences (ToolDefaults), persists across projects and launches, and must not change the .comp format. Use "Restore Defaults" for the reset action. PR #154.
- View › Snap To applies to marquee, ellipse, Shape, and moving an existing selection; Control bypasses snapping. Test both snap switches and the visual guide/line feedback. PR #155.
- Numeric label scrubbing is intentionally selective: dragging adjusts existing numeric controls and snaps relevant whole-number fields, while typing still accepts decimals. New Canvas width and height are not draggable. PR #122.
- Closing a window or pressing Command-Q while text is being edited commits valid text first and continues through the normal save flow; invalid text blocks termination. Filters and adjustments remain unavailable during active text editing rather than adding a separate rasterization-confirmation workflow. PRs #129, #132, #135.
- While text is being edited, preview it with the same document-resolution pixels that will be committed, including the layer's stack position, opacity, and blend mode. PR #121.
## 7. Dimensions, memory, and validation
- DocumentLimits.swift centralizes size policy. Verify the current constants and each enforcement path before editing or quoting them.
- On this snapshot maxSide is 30,000 pixels; maxSurfacePixels is 200,000,000 for one rendered surface or allocation. PR #108.
- The documentPixelBudget formula is min(800,000,000, max(200,000,000, Int(clamping: physicalMemory / 16))). At four bytes per pixel this reserves at most a quarter of RAM for imported raster and yields roughly 537 MP on an 8 GB Mac and 800 MP on a 16 GB Mac. PR #108.
- Distinguish a single surface ceiling from the cumulative imported-document budget. PR #108 reproduced a 10,800 × 5,400 PSD with 29 layers, a 154.4 MP largest layer, and about 486.5 MP of layer pixels. A flat 100 MP budget had rejected that real document.
- The contributor's initial 512 MP single-surface proposal did not become policy: the owner adjusted the final value to 200 MP on main for memory reasons. PR #108.
- The exact mask accounting matters. ProjectStore.swift currently maintains separate image-pixel and mask-pixel counters and checks each against documentPixelBudget. Its enforcement is more precise than the broad comment in DocumentLimits.swift about layers and masks summed together. Reconcile docs, comments, tests, and behavior when changing it.
- Keep input checks at the relevant import, resize, paste, render, or export boundary; avoid scattering caps and duplicate checks that reject otherwise supported work.
- PRs #10–#17 were closed as speculative downstream limits. For a legal maximum-size document, added tile or working-buffer caps could refuse valid rendering or even clear the canvas. A static warning alone did not establish a real crash or hang.
- PR #108 shows the complementary rule: change central limits when a real file, steps to reproduce, dimensions, and memory reasoning demonstrate a genuine failure. Supply a targeted regression.
- Distinguish local robustness concerns from a claimed network security boundary: the maintainer noted Compositor is a local, single-user editor in the discussion of PRs #10–#17.
- Fail explicitly on invalid or oversized data; do not silently render an empty or incomplete result.
## 8. Tests and verification
- Test failures are evidence to classify, not an instruction to edit whichever side is easiest. First determine whether behavior changed intentionally, a test is stale, or production code regressed. PR #34.
- Rename tests whose names no longer describe their assertion. Disclose weakened or removed coverage, environmental failures, and manual checks not performed. PR #34.
- Write meaningful regressions through production paths. A persistence bug should save, reopen, and inspect visible state or exported pixels, not merely echo the implementation's assignments. PR #54.
- Use representative real files for PSD import and memory-limit changes; fixtures and unit tests cannot prove compatibility with all external files. PRs #39, #108.
- A compiling, runnable unit suite matters. The owner singled out restoring the suite as especially valuable in PR #34; later tests also exposed a version-9 loader mismatch and an inverted Camera Raw slider. PRs #10–#17, #67.
- Current .github/workflows/verify.yml supplies lean unit CI after PR #98. It runs on macOS 26 with Xcode 26.6, resolves pinned Swift packages, builds for testing once, runs ordinary unit tests in parallel, and runs FloatingPanelTests and SliderSnapTests serially.
- UI tests are deliberately excluded. The owner does not maintain them and explicitly declined an offered fix after merging PR #98. The earlier broad CI in PR #67 was reverted because stale UI tests kept it red and slowed the solo developer's local loop.
- Recent merges kept UI tests out of default CI even when contributors supplied them. A SwiftUI/AppKit accessibility test that fails only on macOS 27 may be dropped after confirming the production behavior is still covered elsewhere; record the OS-specific limitation instead of distorting production code. PRs #122, #153, #163.
- Do not put the UI target back into default local or CI runs without a new maintainer decision. Test interactive changes manually and add focused maintainable unit tests where feasible.
- State the exact build and test commands, OS/hardware, results, example files, and unverified paths in a PR. Distinguish static reasoning, compilation, an automated assertion, and an observed interaction.
- When an interactive regression depends on an OS version or hardware architecture, record the actual environment used. An arm64 build, an x86_64 build, and a macOS window interaction establish different kinds of confidence.
## 9. Pull request and documentation conventions
- Keep one coherent concern per PR. Explain the user problem, observed behavior, proposed integration into the current architecture, observable outcome, and limits.
- Describe effects on format compatibility, editability, undo, rendering, memory, and performance when relevant, with direct evidence rather than an exhaustive speculative checklist.
- For an unusual parser, identify the spec and licensing provenance. For an importer, document real files tried and what was converted, omitted, or rejected. PR #39.
- Rebase on main, remove obsolete workarounds, and recheck any current maintainer comment before asking for review. PR #39.
- Prefer docs/project-format.md for schema truth and GitHub releases for user-facing change notes. Do not add a repository changelog that narrates diffs and immediately grows stale. PRs #54, #55.
- Separate accepted functionality from the author's exact branch: the owner has merged a leaner implementation, adjusted a default, or added follow-up corrections on main in several cases. PRs #55, #82, #98, #99, #105, #108.
- A PR marked closed may still have selected commits accepted on main, and a merged PR may include maintainer follow-up changes. Check the final diff and current main before copying the branch's full scope. PRs #137, #140, #154, #155, #163.
- When intent behind a failing test or an existing behavior remains ambiguous, surface the uncertainty with evidence instead of assuming the proposed change is authoritative. PR #34.
- Avoid presenting future groundwork as an approved delivery plan: a deferred localization or AI idea has no committed timetable. PRs #37, #58, #89, #91, #94.
- The release procedure in README.md signs, notarizes, staples, and packages a Universal build via scripts/release.sh. Keep signing credentials outside the repository and do not describe an unsigned local Debug build as a verified release.
## 10. Decision register — recheck status before using
| Area | Decision on 29 September 2026 |
| --- | --- |
| Brush blend modes | PR #107 closed unmerged: one blend-mode control in Layers; painting-tool expansion declined. |
| Brush Flow | PR #106 closed unmerged; declined because it overlaps with opacity and makes the compositing brush harder to understand. |
| Filter Layers | PR #82 closed after Gaussian Blur, Motion Blur, and Add Noise were implemented as Adjustment Layers on main. |
| CI | PR #98 merged: unit tests only; PR #67's broader approach was reverted. |
| Text color | PR #137 closed after its color portion was merged; per-letter colorRuns are persisted in format 10, while PSD import still uses one color per text layer. |
| Text font | PR #140 merged; selected letters can use different fonts, persisted as fontRuns in format 11. PSD import does not recover per-letter fonts. |
| Format guide | PRs #104, #137, and #140 merged; current format is version 11. Recheck docs/project-format.md for version-11 text runs and obsolete memory-budget wording. |
| Tab bar | PR #105 merged; PR #42 closed as superseded; PR #163 added accepted tab reordering and an "N more tabs" overflow menu. Owner corrected the new-tab fade flicker on main. |
| Size budgets | PR #108 merged and adjusted on main: 200 MP surface, RAM-dependent 200–800 MP document budget. |
| External .comp changes | PR #116 merged; event-driven reload with a manifest/image-name-and-size fingerprint, safe handling of unsaved or half-written packages, no format change. |
| Scaled-layer painting | PR #162 merged; Clone Stamp and Blur use the layer's native pixels, paint failures explain themselves, and layer rows show scale. |
| Photoshop parity subset | PR #163 closed after masks, modifier behavior, tabs, and Ungroup Layers were taken onto main; the broad Layers context-menu expansion was declined. |
| Grid and snapping | PRs #154 and #155 merged; grid settings persist as ToolDefaults, and drawing/moving selections honors View › Snap To. |
| Export formats | PR #149 closed unmerged; keep PNG/JPEG and the current 8-bit pipeline, with no extra high-bit export claims. |
| Text undo | PR #100 open; do not treat its proposed implementation as shipped. |
| AI / MCP | PRs #89, #91, and #128 closed; do not add MCP integrations or endorse third-party MCP links without a broader product decision. PR #58 remains pending product direction. |
| Localization | PRs #37, #57, #94, #126, and #148 declined/deferred due to continuing review cost. |
| macOS 15 | PR #72 closed; current README targets macOS 26.0 or newer on Apple silicon. |
| Paint Bucket | PR #96 closed; existing selection and fill workflow preferred. |
| Crop to Selection | PR #95 closed; the Crop tool itself starts from the current selection. |
| PSD import / export | PR #39 established editable import with conversion disclosure; PSD export remains deferred. |
| State and effects | PRs #54 and #55 favor complete model mappings and the shared Layer Effects path. |
| Preferences | PR #59 kept Auto Select off by default and persisted the user's preference. |
| Text editing lifecycle | PR #129 merged close/quit commit behavior; PRs #132 and #135 were declined where they proposed broader action-boundary changes or rasterization confirmation. |
| Numeric controls | PR #122 merged selective label scrubbing; UI tests stayed out of default CI. |
| New Canvas presets | PR #141 closed; owner chose a small menu on New Canvas rather than a dedicated preset sheet. |
| Speculative guards | PRs #10–#17 closed; require a reproduced defect and respect valid maximum-size work. |
Before submitting a change, ask: Does it serve compositing or photo work? Does it reuse the existing owner of state and UI? Does it preserve editable data and a coherent undo/preview/save cycle? Did I verify the real failure or workflow? Do the tests and PR description honestly describe what ran? Have I checked the latest maintainer decision and final main implementation?