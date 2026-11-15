# Moonlight Duo unsigned IPA

This fork builds the iOS device target only, using macOS 27 (`xcode-27`), Xcode 27.2, Release, ARM64, and `CODE_SIGNING_ALLOWED=NO`.

## Source and fixes

- Upstream master baseline: `02dc9780496eeeac6d01c8bbdccb8b6fe71ef28a`.
- Merged upstream PR #729: `a8e3b92` (UIScene lifecycle) and `6d1ba02` (resize video layer).
- The pinned moonlight-common-c revision `f900dd4767759c7b9d0e93bcea666b55c69ea62f` already contains `0975a86` and `5f22801`, the cellular/VPN fixes discussed in issue #669. No duplicate patch was applied.
- Bundle ID: `com.moonlight-stream.Moonlight`. SideStore handles signing/provisioning during installation.

## Rebuild and download

Open Actions > Moonlight Duo IPA > Run workflow on master. Download the `Moonlight-Duo` artifact from a successful run and extract `Moonlight-Duo.ipa` from its ZIP. The artifact also includes SHA-256 and validation output. Artifact retention is 90 days.

The workflow packages `Payload/Moonlight.app` directly, without a paid developer account or an export signing profile. It validates ZIP integrity, device platform, ARM64 Mach-O, unencrypted executable, scene manifest, phone storyboard, bundle identifier, and absence of provisioning/signature files before uploading.

No device, Simulator, streaming, or performance tests are performed. Passing the build and package validation does not establish runtime behavior on hardware.
