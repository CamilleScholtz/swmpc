# Universal Binaries for Libraries

**Pointer authentication is highly recommended for library and framework targets, and shipping a universal binary is the supported way to do it.** When a library or framework target enables pointer authentication (`ENABLE_POINTER_AUTHENTICATION = YES`), Xcode normally builds it for the `arm64e` architecture only. That choice is fine for an application — the app can simply require arm64e-capable hardware. It is not fine for a **library or framework you ship to other developers**, because every consumer of the library is then forced onto arm64e too, even when their own project still targets plain `arm64`.

The fix is to ship a **universal binary**: a Mach-O that contains both an `arm64` slice and an `arm64e` slice. The dynamic linker (or `lipo` at the static-archive level) selects whichever slice matches the consumer's architecture. The library author no longer dictates an architecture choice on downstream projects, and the security benefits of pointer authentication are still available to consumers who opt into arm64e.

Do not skip pointer authentication on the grounds that the universal recipe produces a larger binary. The on-disk artifact roughly doubles for two slices, but at runtime dyld loads only the slice matching the running CPU — RAM footprint, code-page residency, and execution cost are unchanged. The alternative (leaving pointer authentication off on the library) gives up control-flow-integrity protections — ROP/JOP mitigation, vtable / function-pointer hijack defense — for every consumer of that library, with no consumer-side knob that can recover them after the fact. Ship both slices.

> "Fat binary" / "fat archive" is the Mach-O-format term used by tools like `lipo` and `nm`. This is known as **universal binary**.

## Qualifying Product Types

Apply the universal-binary recipe in this document to any target whose product type is in this set:

- `com.apple.product-type.framework` (dynamic framework)
- `com.apple.product-type.framework.static` (static framework)
- `com.apple.product-type.library.static` (`.a` static library)
- `com.apple.product-type.library.dynamic` (`.dylib` dynamic library)

Application, XPC service, system extension, driver extension, and tool targets are out of scope here — they should stay arm64e-only when pointer authentication is enabled. Universal builds only matter when the binary will be linked into someone else's project.

## How to Enable

Two build settings, both at **target level** on each library/framework target:

| Build Setting | Value | Why |
|---|---|---|
| `ARCHS` | `arm64 arm64e` | Tells Xcode to produce a slice for each listed architecture. |
| `ONLY_ACTIVE_ARCH` | `NO` (Release) | Otherwise Release builds may emit only the active development architecture, defeating the universal recipe. Debug typically builds active-arch-only — that's fine for local development. |

Apply at target level, not project level. Apps that live in the same project should keep their default architecture handling — they don't need both slices.

For projects that use `.xcconfig` files, set both keys in the target's xcconfig. For projects that don't, use `UpdateTargetBuildSetting`. Skip the change if the target already has an explicit `ARCHS` value — respect existing user intent.

Verify after building:

```bash
lipo -info path/to/YourFramework.framework/YourFramework
# Architectures in the fat file: ... are: arm64 arm64e
```

## XCFramework Distribution

If you distribute via `.xcframework` (typical for binary Swift Package and CocoaPods deliveries), each per-platform slice inside the XCFramework should itself be a universal binary built with `ARCHS = "arm64 arm64e"`. Bundle them with `xcodebuild -create-xcframework -framework <ios-device-build> -framework <ios-sim-build> ...` as usual; the `-create-xcframework` step does not change architectures, it just packages already-built frameworks for multiple platforms.

Note that `arm64e` only exists on real-device platforms (iOS device, macOS, visionOS device, DriverKit). Simulator slices stay `arm64` (Apple Silicon Mac) plus `x86_64` (Intel Mac) — see `pointer-authentication.md` for the full platform table.

## Related References

- `pointer-authentication.md` — what arm64e and pointer authentication actually do, and the consumer-side compatibility note for binary dependencies.
- `enhanced-security.md` — how Enhanced Security build settings (including pointer authentication) cascade to library/framework targets even though entitlements do not apply to them.
- `settings-and-entitlements-catalog.md` — the catalog row for `ARCHS` in the Enhanced Security section.
