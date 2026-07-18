---
name: audit-xcode-security-settings
description: |
  Audit and enable security-oriented Xcode build settings. Progressively enables compiler warnings, static analyzer checkers, and Enhanced Security features. Use when: user wants to secure their Xcode project, audit security settings, enable hardening, review security posture of build configuration, set up security-focused static analysis, enable static analysis, improve warning coverage, harden diagnostics, or catch more bugs at compile time in C/C++/Objective-C/Swift. SKIP: network security (TLS/ATS), code signing, privacy APIs.
---
# Audit Xcode Security Settings

Assess an Xcode project's security posture and progressively enable security build settings and entitlements — from broadly applicable warnings through Enhanced Security hardening.

## Tool Preferences

When XcodeGlob, XcodeGrep, XcodeRead, XcodeLS, and XcodeUpdate tools are available, ALWAYS use them. Do not fall back to Bash filesystem tools (`ls`, `find`, `cat`, `grep`) to learn about the project. They trigger extra permission prompts and bypass project scoping.

- **XcodeGlob** for file discovery — `find` is forbidden for files inside the project.
- **XcodeGrep** for content search — `grep`/`rg` is forbidden for files inside the project.
- **XcodeRead** for file contents — `cat`/`Read` is forbidden for files registered in the project.
- **XcodeLS** for directory listing — `ls` is forbidden for any path inside the project.
- **XcodeUpdate** for in-place edits of project-registered files — same `filePath` / `oldString` / `newString` (+ optional `replaceAll`) signature as the built-in `Edit` tool, but accepts project-org paths. `Edit` is forbidden for files registered in the project; use it only for on-disk files that aren't project-indexed (e.g. `.entitlements` plists translated to filesystem absolute paths per the failure-modes table below).

**Project root and name are already in the system prompt context.** Do NOT run `ls` to "verify" the project layout before starting. The system prompt already tells you the working directory and the project structure.

**Empty XcodeGlob results are not a failure.** The `.xcodeproj` and `.xcworkspace` are not indexed as files inside the Xcode project organization — `XcodeGlob "**/*.xcodeproj"` correctly returns 0 matches. Use the project name from system-prompt context instead. Do not fall back to filesystem `ls`/`find`.

**Path translation between project-org and filesystem.** XcodeGlob returns project-org-relative paths. To read or edit a file:
- Prefer `XcodeRead` / `XcodeUpdate` with the project-org path.
- If that path is rejected (some on-disk files like `.entitlements` plists may not be navigable through `XcodeRead`), translate to a filesystem absolute path by prepending the project root from system context. Do NOT use `find` to discover the on-disk path.

Fall back to Bash only for operations the Xcode tools cannot do (e.g., `plutil` for plist editing, git operations).

### Common Failure Modes

| Symptom | Cause | Correct Response |
|---|---|---|
| `XcodeGlob "**/*.xcodeproj"` returns 0 matches | The `.xcodeproj` itself isn't a project-indexed file | Use the project name from system context; do not fall back to `find` or `ls` |
| `XcodeRead <project-org-path>` fails for a config-type file (`.entitlements`, `.xcsettings`, `.xcconfig`) | Some on-disk artifacts aren't navigable via project paths | Translate to filesystem absolute path using the project root from system context, then use `Read` / `Edit` |

## Workflow

## Phase 1: Briefing

Before doing any work, tell the user — in two or three sentences — what this skill is, what it will do, and roughly how much of their time and attention to expect:

- **What it is.** An audit of the project's Xcode security build settings and entitlements (compiler warnings, hardened-process capabilities, pointer authentication, universal binaries for libraries, etc.).
- **What happens.** I analyze the project, write an editable plan file at the project root for you to review, and apply only the changes you approve. Nothing is modified until you pick Run.
- **Time commitment.** A few minutes of my time to analyze (longer on projects with many targets — I'll narrate progress). Then your review time on the plan file, which can be quick or thorough — your call. After Run, applying is fast; two things can pause for your input — the inquiry step (if there are deliberately-disabled settings whose rationale isn't documented), and a final yes/no on whether to keep the plan file in your project as a record.
This all usually takes about 15-30 minutes, depending on the number of build targets and how long it takes for you to review and approve the plan.

Keep it tight — the user already invoked the skill knowing they wanted an audit.
The briefing exists so they have realistic expectations.

## Phase 2: Discovery

Read the Environment block in the system prompt. Relevant fields:
- `Primary working directory` — the project root (the project name is the basename).
- `Is a git repository` — whether the project is git-tracked (used by Phase 4 Step 1).

## Track Progress

Every per-target / per-setting action that needs to happen must have its own task for transparency.

- Phase 3 creates one task per target (`Audit <target>`); the task closes once Phase 3 has produced both the per-target audit-table rows and (for supported product types) the Enhanced-Security bucket for that target. After all per-target tasks complete, Phase 3 writes `<project-root>/xcode-security-audit-scratchpad.md` via the `Write` tool (filesystem only — the scratchpad is agent-internal state, not user-facing, so it deliberately is **not** registered in the Xcode project). Phases 4–7 re-read it via `Read`; they never assume the data is in memory. Do not stage this file in git.
- Phase 4 (Plan & Approve) is one task that completes when the user picks Run/Cancel.
- On Run, Phase 4 step 5 parses the plan, appends a `## Plan Selection` section to the scratchpad, and creates fine-grained tasks:
  - One `Apply Enhanced Security to <target>` per target needing changes (only if "Enhanced Security" is checked).
  - `Apply Basic Clang Safety Warnings` if checked.
  - `Apply Hardware Memory Tagging` if checked.
  - `Apply Additional Diagnostic Settings` if checked.
  - `Emit Bounds Safety Adoption guidance` if checked.
  - One `Inquire about <MACRO> on <target>` per Phase-6 candidate (only if "Inquire about disabled settings" is checked).
  - `Report and update decision document`.
  - `Remove scratchpad` — always second-to-last; also fires on error paths.
  - `Prompt to remove plan file` — always last; also fires on error paths.

When entering each phase or sub-step:
- Print one line: "▶ Phase N: …" (or "▶ Phase N / Step M: …" for sub-steps).
- Update the task to `in_progress`.

When finishing each phase or sub-step:
- Print one line: "✓ Phase N: …" (with a brief outcome if applicable, e.g., "✓ Phase N: No disabled settings found.").
- Update the task to `completed`.

### Phase 3: Analyze Project and Settings

No user interaction. Gather facts in the background.

#### Step 1: Locate the existing decision document

`XcodeGlob '**/xcode-security-settings.md'`. If found, `XcodeRead` it and extract languages + prior setting decisions with their statuses and rationale. This informs subsequent phases.

#### Step 2: Detect languages

One `XcodeGlob` per language. Empty result is not a failure — record the language as absent.

- `**/*.c` → C
- `**/*.cpp`, `**/*.cxx`, `**/*.cc` → C++
- `**/*.m` → Objective-C
- `**/*.mm` → Objective-C++
- `**/*.swift` → Swift

#### Step 3: Build the audit table

See `references/reading-build-settings.md` for column definitions, the construction recipe, and the canonical predicates ("already hardened", "at default OFF", "deliberately disabled"). At a glance:

1. Enumerate the project's explicit targets. Skip implicit/aggregate targets (no real product type).
2. For each target: `TaskCreate "Audit <target>"`, set in_progress. Call `GetTargetBuildSettings`, run `scripts/filter_build_settings.py` over the resulting JSON, and record `evaluatedValue` and `setAtTargetLevel` (`yes` if `targetValue` is present in the JSON). Leave the task in_progress — Step 4 closes it.
3. One project-wide `XcodeGrep` for the catalog regex over `*.xcconfig` and `**/project.pbxproj`. Record per-macro `numMatchesInXCConfigs`, `numMatchesInPbxproj`, and the file:line citations.
4. The audit table is the joined view: one row per (target, catalog macro). Phases 4, 5, and 6 all consume this table; nothing else is re-fetched.

This step scales with target count: each `GetTargetBuildSettings` call takes several seconds, and there is one per target. On projects with roughly ten or more targets it can take a few minutes.

#### Step 4: Per-target Enhanced-Security state

Route each target into one of three buckets by product type (inferred per the table in `references/reading-build-settings.md`):

- **Entitlements-supported** — product type is in the "Supported Product Types" list of `references/enhanced-security.md` (applications, XPC services, system extensions, driver extensions [build settings only], tools). Read the resolved `CODE_SIGN_ENTITLEMENTS` plist and bucket the target as **Up-to-date**, **Partial**, **Off**, or **No-entitlements-file**.
- **Library/framework** — product type is in the qualifying set listed in `references/universal-binaries-for-libraries.md` (frameworks, static frameworks, static libraries, dynamic libraries). No entitlements read. Phase 5 will configure a universal-binary `ARCHS` recommendation for these.
- **Skipped** — anything else (test bundles, app extensions, etc.).

`TaskUpdate "Audit <target>"` to completed once the bucket is recorded (immediately for **Library/framework** and **Skipped** — they need no entitlements read). Phases 4 and 5 consume these buckets — neither re-reads entitlements.

On large projects this iterates over many `.entitlements` plists — if Step 3 took noticeable time, this one will too.

#### Step 5: Persist the analysis

Write `<project-root>/xcode-security-audit-scratchpad.md` via the **`Write` tool** (not `XcodeWrite` — the scratchpad is agent-internal state and intentionally is not registered in the Xcode project, so it doesn't clutter the user's Project Navigator). Resolve `<project-root>` from the Environment block's `Primary working directory`. The file has two sections:

- `## Audit Table` — the rows from Step 3.
- `## Enhanced-Security Buckets` — one line per target with its bucket and a short delta hint (e.g. `Foo: Partial — missing hardened-heap, has deprecated platform-restrictions`).

Phase 4 step 5 (on Run) will append a third section `## Plan Selection` via `Edit`. The final `Remove scratchpad` task in Phase 7 removes the scratchpad via `Bash rm`. If the file is missing at re-read time during a later phase, that phase aborts with an error — never re-derive silently.

### Phase 4: Plan & Approve

This phase produces a tailored, editable plan file that the user reviews before any changes happen. Once approved, Phases 5–7 run end-to-end with no further prompts.

#### Step 1: Check for version control

The project is **version-controlled** if either:

- The Environment block's `Is a git repository` field is `true`, or
- A single filesystem check at the project root finds any of `.git`, `.hg`, `.svn`, `.bzr`, `.fslckout`, `_FOSSIL_`, `CVS`.

Otherwise the project is **not version-controlled**.

#### Step 2: Skip if everything is already configured

Inspect the scratchpad. Early-exit if **all** default-checked plan items are already at their target state:

- Every Enhanced-Security bucket is **Up-to-date** or **Skipped**.
- Every relevant Basic-Clang-safety setting is `already hardened` on every applicable target.
- The `deliberately disabled` predicate yields no rows (after the Phase-6 exclusions below).

Optional follow-ups (Additional diagnostic settings, Bounds safety adoption) do **not** block early-exit. Report "Everything in scope is already configured" and exit; do not write a plan file.

#### Step 3: Write the plan file

Create `xcode-security-audit-plan.md` at the **root of the Xcode project organization** via `XcodeWrite` (path: `xcode-security-audit-plan.md`, no parent group). `XcodeWrite` both writes the file to disk under `<project-root>/` and registers it in the project so the user can open it directly from Xcode's Project Navigator.

Include only items that apply to the project (see omission rules below). Use this template — substitute the placeholders in `<…>`:

````markdown
# Xcode Security Audit — Plan
**Project:** <name> · <N> targets · languages: <list>
**Generated:** <YYYY-MM-DD>
> ⚠️ **No version control detected.** This skill modifies build settings and entitlements.
> Without Version Control System (e.g., Git), rollback requires manual undo. Consider running `git init` or copying the project before picking **Run**.
Edit the items below — set what steps to perform now, or leave them unchecked to defer them.
## Phases
- [x] **Enhanced Security** — apply to: <target list>. Adds hardened-process entitlements and sets `ENABLE_ENHANCED_SECURITY=YES`.
- [x] **Basic Clang safety warnings** — <N> settings, applied to all C/C++/ObjC targets.
- [x] **Inquire about disabled settings** — <M> found (e.g., `<setting>=NO` on `<target>`). May trigger follow-up questions if no rationale is documented.
- [x] **Hardware memory tagging** — applies to <target list filtered to MTE-supported platforms>. Adds soft-mode MTE entitlement.
- [ ] **Additional diagnostic settings** — extra warnings/checkers. Produces more findings to review. See `references/additional-settings.md`.
- [ ] **Bounds safety adoption** — pointer to a separate skill. No changes applied here.
## Decision document
The skill creates or updates `xcode-security-settings.md` to record every setting decision (kept, deferred, disabled, with rationale). Edit the path to relocate.
- Path: `xcode-security-settings.md`
````

Include the ⚠️ blockquote only when the project is **not version-controlled**; omit it otherwise.

The decision document should live in the same directory as the rest of the documentation, or at the project level.

##### Item omission rules

A plan item is omitted entirely when it doesn't apply:

- **Enhanced Security** — omit if every supported-product-type bucket from Phase 3 step 4 is **Up-to-date** or **Skipped**.
- **Basic Clang safety warnings** — omit if pure-Swift, or if every relevant setting is `already hardened` on every applicable target.
- **Inquire about disabled settings** — omit if the `deliberately disabled` predicate yields no rows (after excluding `ENABLE_POINTER_AUTHENTICATION = NO` on non-arm64e platforms).
- **Hardware memory tagging** — omit if no target's `SUPPORTED_PLATFORMS` / `SDKROOT` matches `macosx`, `iphoneos`, `iphonesimulator`, `xros`, or `xrsimulator`.
- **Additional diagnostic settings** — never omitted; always offered.
- **Bounds safety adoption** — omit if no C or C++ code is present.

##### Default check state

Items under **Phases** are default-checked (`[x]`); items (`[ ]`) are default-unchecked.
The user can flip either by editing the plan file before picking **Run**.

#### Step 4: Ask for approval

Tell the user:

> "Plan written to `xcode-security-audit-plan.md` and added to the Xcode project — open it to review. Edit it as needed — uncheck or delete items to skip them; edit the decision document path to relocate. When ready, pick Run. Pick Cancel to abort without changes. Nothing is modified until you pick Run."

Then ask via `AskUserQuestion` with single-select options:
- **Run** — proceed to "Phase 5"
- **Cancel** — abort

#### Step 5: Handle the response

If **Cancel**: run the two final cleanup tasks (see "Phase 7: Report and Decision Document" below — `Remove scratchpad`, then `Prompt to remove plan file`). The keep-or-remove prompt is offered on Cancel too, so the user's choice to abandon the audit doesn't silently differ from a normal completion. Report "Cancelled — no changes applied," and exit the skill.

If the plan file is missing at re-read time (the user deleted it from disk before responding), treat it as a Cancel — but skip the `Prompt to remove plan file` task (there's nothing to remove). Still run `Remove scratchpad`.

If **Run**: `XcodeRead xcode-security-audit-plan.md`. Parse:
- Each `- [x]` or `- [X]` bullet is a checked item; the item name is the bold portion (between `**…**`).
- Items written as `- [ ]` and items deleted from the file are skipped — both produce identical skip behavior.
- Under the "Decision document" heading, the value after `Path:` is the decision document location.

Append a `## Plan Selection` section to the scratchpad via `Edit` capturing the parsed checked items and the decision-document path. Then create the fine-grained tasks listed in **Track Progress**. Phase 5 onward reads the scratchpad via `Read` rather than relying on memory.

If the parsed plan has zero checked items, run the two final cleanup tasks immediately and report "Plan was empty — nothing to do."

### Phase 5: Apply Settings

Read only from the audit table for build-setting state.

**How to apply build settings:**
- **Project uses `.xcconfig` files** — edit the xcconfig directly. Supports both project-level and target-level settings.
- **Project uses `.pbxproj` only** — use `UpdateTargetBuildSetting` for target-level settings and `UpdateProjectBuildSetting` for project-level settings.
- **Mixed** — if a target has an `.xcconfig` file, edit the xcconfig. Otherwise, use the Xcode build setting tools. Never introduce a new configuration method.

Prefer project-level when possible (less duplication).
For most projects, `ENABLE_ENHANCED_SECURITY` should be set at project level such that any existing and future build targets inherit this setting.
This setting should be disabled only after serious consideration and with strong justification.

#### Step 1: Enhanced Security

The fine-grained `Apply Enhanced Security to <target>` tasks created in Phase 4 step 5 already enumerate the targets needing changes (the **Partial**, **Off**, and **No-entitlements-file** buckets — **Up-to-date** and **Skipped** are excluded). Walk those tasks.

Read `references/enhanced-security.md` for the full key list, defaults, deprecated keys, version migration, and the supported product-type list. For details on individual sub-options, see:
- `references/pointer-authentication.md` — arm64e pointer signing
- `references/typed-allocators.md` — type-aware memory allocation
- `references/stack-zero-init.md` — automatic stack variable zeroing
- `references/readonly-platform-memory.md` — dyld state protection
- `references/runtime-restrictions.md` — dylib and Mach message restrictions
- `references/security-compiler-warnings.md` — security-focused compiler warnings
- `references/cpp-hardening.md` — C++ stdlib hardening and bounds checking
- `references/hardware-memory-tagging.md` — ARM MTE

**Pointer authentication and binary dependencies.** Enhanced Security is a bundle of independent protections; only pointer authentication cascades to `arm64e`. Always recommend `ENABLE_ENHANCED_SECURITY = YES` at the project level. If the project has a binary Swift Package, xcframework, or prebuilt framework that does not ship `arm64e`, the right mitigation is to override `ENABLE_POINTER_AUTHENTICATION = NO` at the target level on every target that links the dependency — not to skip Enhanced Security. List the offending dependencies in the report so the user can ask the vendor for `arm64e` support and lift the override later.

**Producer side — universal binary on library/framework targets.** Pointer authentication is highly recommended on library and framework targets too — do not skip it on the grounds that the universal recipe produces a larger on-disk artifact (RAM footprint and execution cost are unchanged; dyld loads only one slice). For each target in the **Library/framework** bucket from Phase 3 step 4, Phase 5 below also applies a target-level `ARCHS = "arm64 arm64e"` and `ONLY_ACTIVE_ARCH = NO` (Release) so consumers can pick either slice. See `references/universal-binaries-for-libraries.md`.

For each task:

1. **Compose the change set** from the bucket delta in the scratchpad.
   - **Entitlements-supported** buckets (Partial / Off / No-entitlements-file): entitlements add/remove/update; create `.entitlements` if missing and wire `CODE_SIGN_ENTITLEMENTS`. DriverKit targets are supported for build settings only — skip entitlement changes for them.
   - **Library/framework** bucket: no entitlements work. The change set is the universal-binary recipe — see item 2 below.

2. **Build settings:** if xcconfig, set `ENABLE_ENHANCED_SECURITY = YES` at project level there; otherwise `UpdateProjectBuildSetting`. Because a project-level `ENABLE_ENHANCED_SECURITY = YES` cascades `ENABLE_POINTER_AUTHENTICATION = YES` to every target, pre-write a target-level `ENABLE_POINTER_AUTHENTICATION = NO` override on each target that either (a) has a platform that doesn't support arm64e (detect via `SDKROOT` / `SUPPORTED_PLATFORMS` from the audit table), or (b) links a binary dependency that doesn't ship `arm64e`. Skip targets that already have an explicit target-level value per the audit table.

   For each **Library/framework**-bucket target where pointer authentication will end up enabled (the target's platform supports arm64e and there is no existing target-level `ENABLE_POINTER_AUTHENTICATION = NO`), also pre-write target-level `ARCHS = "arm64 arm64e"` and `ONLY_ACTIVE_ARCH = NO` (Release configuration). Use the target's xcconfig if it has one, otherwise `UpdateTargetBuildSetting`. Skip targets that already have an explicit `ARCHS` per the audit table.

   Do not auto-enable default-OFF sub-options (MTE family); those are handled by Step 3 below if checked.

3. **Apply** entitlements edits, build-setting changes, and any new `.entitlements` files atomically per target.

After all targets are processed, report: "Enabled Enhanced Security on N target(s). Removed M deprecated entitlement(s). Upgraded version string to 2 on K target(s). Added arm64e override on T target(s). Configured universal binary on U library/framework target(s)."

The user already approved this in "Phase 4" — no further prompt is needed.

The per-target `Apply Enhanced Security` tasks dominate Phase-5 wall time on multi-target projects. Each one writes build settings and edits the target's `.entitlements` plist.

#### Step 2: Basic Clang Safety Warnings

If pure Swift, skip. Skip individual settings whose audit-table row is `already hardened` on a given target. Otherwise apply target-level (see "How to apply build settings"):

- `GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR`
- `GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE`
- `CLANG_WARN_IMPLICIT_FALLTHROUGH = YES`
- `GCC_WARN_64_TO_32_BIT_CONVERSION = YES`
- `GCC_TREAT_IMPLICIT_FUNCTION_DECLARATIONS_AS_ERRORS = YES` (C/ObjC/ObjC++ only)
- `CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER = YES`
- `CLANG_ANALYZER_SECURITY_INSECUREAPI_RAND = YES`
- `CLANG_ANALYZER_SECURITY_INSECUREAPI_STRCPY = YES`

Report briefly: "Enabled additional compiler warnings."

#### Step 3: Hardware Memory Tagging

If the **Hardware memory tagging** plan item was unchecked or deleted, skip this step.

Hardware memory tagging is supported only for targets whose `SUPPORTED_PLATFORMS` (or `SDKROOT`) is `macosx`, `iphoneos` / `iphonesimulator`, or `xros` / `xrsimulator`.
Hardware backing is M5-class Apple silicon and later.

Read `references/hardware-memory-tagging.md` and apply the soft-mode MTE entitlement to every supported target. The user already approved this in "Phase 4" — no further prompt is needed.

#### Step 4: Additional Diagnostic Settings

If the **Additional diagnostic settings** plan item was unchecked or deleted, skip this step.

Read `references/additional-settings.md` and follow it. The user already approved this in "Phase 4" — no further prompt is needed.

#### Step 5: Bounds Safety Adoption

If the **Bounds safety adoption** plan item was unchecked or deleted, skip this step.

This step does not apply changes — it emits guidance only.

For C projects, print:
> "To adopt `ENABLE_C_BOUNDS_SAFETY` (annotation-based bounds safety for C), invoke the `adopt-c-bounds-safety` skill."

For C++ projects, print:
> "To adopt `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS` (C++ bounds-safe buffer patterns), read the documentation at https://clang.llvm.org/docs/SafeBuffers.html"

### Phase 6: Inquire about Disabled Settings

If the **Inquire about disabled settings** plan item was unchecked or deleted, skip this phase.

This phase pauses for one user response per deliberately-disabled setting that lacks a documented rationale. If the candidate list is long, surface the count up front so the user knows what to expect ("I found 7 deliberately-disabled settings; let me ask about each").

A row is a candidate when the `deliberately disabled` predicate (defined in `references/reading-build-settings.md`) holds. Exclude `ENABLE_POINTER_AUTHENTICATION = NO` rows on targets whose platform doesn't support arm64e (the skill itself sets it there); flag arm64e-capable targets. Restrict to settings whose Scope (in `references/settings-and-entitlements-catalog.md`) covers a language detected in Phase 3 step 2.

For each candidate, walk the corresponding `Inquire about <MACRO> on <target>` task created in Phase 4 step 5:

- If the decision document has an entry with status `Disabled` and a rationale → note it in the report and move on.
- Otherwise → `AskUserQuestion`: "I found `<MACRO>` explicitly set to `NO` with no explanation. Is there a reason for this?" Double-check that the macro is `deliberately disabled` and not merely at Xcode's default OFF — only call out explicit overrides. Record the rationale (or recommend re-enabling if none).

Same flow applies to `ENABLE_ENHANCED_SECURITY = NO` if present in the audit table.

### Phase 7: Report and Decision Document

Produce a lean summary:

1. **Enabled** — project-wide settings that were enabled.
2. **Enhanced Security per target** — one line per target: name, final status (up-to-date / applied / skipped-by-user), terse delta (entitlements added, deprecated keys removed, version bumps, whether an entitlements file was created). Roll up Skipped targets into one line.
3. **Already active** — settings already configured correctly.
4. **Inquired** — settings found disabled and the outcome of the inquiry.

**Decision document.** Read `references/decision-document.md` and follow it to create or update the decision document.

After Phase 7 — and on any error path during Phases 5–7 — these two final tasks run in order:

1. **`Remove scratchpad`** — `Bash rm <project-root>/xcode-security-audit-scratchpad.md`. The scratchpad is agent-internal state with no value to preserve; removal is unconditional.
2. **`Prompt to remove plan file`** — ask the user via `AskUserQuestion`: "The audit is complete. Remove the plan file `xcode-security-audit-plan.md` from your project?"
   - **Yes, remove it (Recommended)** → `XcodeRM xcode-security-audit-plan.md deleteFiles:true`
   - **No, keep it** → leave it in place; it stays in the Project Navigator as a record of what was approved. The user can delete it later from Xcode or Finder.

If either removal fails, warn the user but do not block exit.

## User-Facing Interaction Guidelines

- **Keep replies lean.** Short sentences.
- **Keep user questions minimal.** Two scheduled questions: the plan approval prompt (Run / Cancel) at the end of "Phase 4", and the keep-or-remove-plan-file prompt at the end of "Phase 7". Other questions are situational: inquiries about deliberately-disabled settings during "Phase 6" (only when an explicit `= NO` lacks a documented rationale).
- **Report progress** so the user can track: "Enabling...", "Evaluating...", "Keeping/Reverting..."
- **Use `AskUserQuestion`** for the plan approval (Run / Cancel), for inquiring about disabled settings during "Phase 6", and for the keep-or-remove-plan-file prompt at the end of "Phase 7".
- **When asking a question provide context the user needs to answer the question**. For example, describe the benefit of the security protection before asking whether to enable it. Describe it in terms of the protection it provides, not how it is enabled.
- **When emitting lists of Xcode build settings, use bullet lists** Don't use comma-separated lists.