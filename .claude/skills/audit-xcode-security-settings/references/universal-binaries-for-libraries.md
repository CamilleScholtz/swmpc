# Universal Binaries for Libraries

**Pointer authentication is highly recommended for library and framework targets.** Enabling it (`ENABLE_POINTER_AUTHENTICATION = YES`, directly or via the `ENABLE_ENHANCED_SECURITY` cascade) is by itself enough to produce a **universal binary**: the build system appends `arm64e` to `ARCHS_STANDARD` whenever `arm64` is already present, so the target builds **both** an `arm64` slice and an `arm64e` slice. This happens for any target — application or library — not just libraries; there is no setting that makes pointer authentication produce an `arm64e`-only build.

For a library or framework you ship to other developers, that universal binary is exactly what you want: a Mach-O that contains both an `arm64` slice and an `arm64e` slice. The dynamic linker (or `lipo` at the static-archive level) selects whichever slice matches the consumer's architecture, so the library author does not force an architecture choice on downstream projects — plain-`arm64` consumers keep working, and consumers who opt into arm64e get the pointer-authentication protections.

The one thing to verify is that the **distributed** build actually emits both slices. `ONLY_ACTIVE_ARCH = YES` (the conventional Debug value) builds only the active development architecture; a Release/distribution configuration uses `ONLY_ACTIVE_ARCH = NO`, so the full `ARCHS` list is built. Distribute the Release artifact (or set `ONLY_ACTIVE_ARCH = NO` for whatever configuration you ship) so both slices land in the binary.

Do not skip pointer authentication on the grounds that two slices produce a larger binary. The on-disk artifact roughly doubles for two slices, but at runtime dyld loads only the slice matching the running CPU — RAM footprint, code-page residency, and execution cost are unchanged. The alternative (leaving pointer authentication off on the library) gives up control-flow-integrity protections — ROP/JOP mitigation, vtable / function-pointer hijack defense — for every consumer of that library, with no consumer-side knob that can recover them after the fact. Ship both slices.

> "Fat binary" / "fat archive" is the Mach-O-format term used by tools like `lipo` and `nm`. This is known as a **universal binary**.

## Qualifying Product Types

Apply the universal-binary recipe in this document to any target whose product type is in this set:

- `com.apple.product-type.framework` (dynamic framework)
- `com.apple.product-type.framework.static` (static framework)
- `com.apple.product-type.library.static` (`.a` static library)
- `com.apple.product-type.library.dynamic` (`.dylib` dynamic library)

Application, XPC service, system extension, driver extension, and tool targets are out of scope for this document's extra packaging guidance. They already get the universal `arm64`+`arm64e` build from pointer authentication, and because they are not linked into anyone else's project there is no consumer-compatibility concern to manage — no special handling is needed.

## How to Enable

Enabling `ENABLE_POINTER_AUTHENTICATION = YES` on the target (directly, or via the `ENABLE_ENHANCED_SECURITY` cascade) is what produces the two slices. The settings below make the universal build reliable for a *distributed* library/framework target — apply at **target level**:

| Build Setting | Value | Why |
|---|---|---|
| `ONLY_ACTIVE_ARCH` | `NO` (distribution config) | Ensures the distributed build emits every slice in `ARCHS`, not just the active development architecture. Debug typically builds active-arch-only — that's fine for local development. |
| `ARCHS` | `arm64 arm64e` *(optional)* | Belt-and-suspenders: pins both slices explicitly so the binary stays universal even if pointer authentication is later toggled off, decoupling the universal-binary decision from the `ENABLE_ENHANCED_SECURITY` / `ENABLE_POINTER_AUTHENTICATION` cascade. Not required when pointer authentication is enabled — `arm64e` is appended automatically. |

Apply at target level, not project level. Apps in the same project need no special handling — pointer authentication already gives them both slices.

For projects that use `.xcconfig` files, set the keys in the target's xcconfig. For projects that don't, use `UpdateTargetBuildSetting`. Skip the `ARCHS` change if the target already has an explicit `ARCHS` value — respect existing user intent.

Verify after building:

```bash
lipo -info path/to/YourFramework.framework/YourFramework
# Architectures in the fat file: ... are: arm64 arm64e
```

## XCFramework Distribution

If you distribute via `.xcframework` (typical for binary Swift Package and CocoaPods deliveries), each per-platform slice inside the XCFramework should itself be a universal binary built with `ARCHS = "arm64 arm64e"`. Bundle them with `xcodebuild -create-xcframework -framework <ios-device-build> -framework <ios-sim-build> ...` as usual; the `-create-xcframework` step does not change architectures, it just packages already-built frameworks for multiple platforms.

Note that `arm64e` exists on every device platform (iOS device, macOS, visionOS device, DriverKit, tvOS device, watchOS device) but on no Simulator SDK. Simulator slices stay `arm64` (Apple Silicon Mac) plus `x86_64` (Intel Mac) — see `pointer-authentication.md` for the full platform table.

## Related References

- `pointer-authentication.md` — what arm64e and pointer authentication actually do, and the consumer-side compatibility note for binary dependencies.
- `enhanced-security.md` — how Enhanced Security build settings (including pointer authentication) cascade to library/framework targets even though entitlements do not apply to them.
- `security-settings-reference.md` — the entry for `ARCHS` in the Enhanced Security section.
