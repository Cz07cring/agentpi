# AgentPi Local Hot Update Release Runbook

This runbook documents the local one-command release flow for AgentPi Sparkle updates.

## Scope

- Build and package `AgentPi.app`, `AgentPi.dmg`, and Sparkle update zip.
- Sign `AgentPi.app.zip` using Sparkle EdDSA private key from macOS Keychain.
- Create or update GitHub release assets.
- Update and push `external/AgentPi/appcast.xml`.
- Verify remote `appcast.xml` includes the target version.

## Prerequisites

1. Local branch is `main` and version is already bumped in:
   - `external/AgentPi/app/AgentPi.xcodeproj/project.pbxproj` (`MARKETING_VERSION`)
2. Commands available:
   - `gh`, `xcodebuild`, `xcrun`, `ditto`, `security`, `curl`
3. `gh` authenticated with repo write access:

```bash
gh auth login
gh auth status
```

4. Sparkle private key exists in Keychain:
   - service: `Private key for signing Sparkle updates`
   - account: `ed25519`

## Initialize Sparkle private key in Keychain

```bash
security add-generic-password -U \
  -a "ed25519" \
  -s "Private key for signing Sparkle updates" \
  -w '<SPARKLE_PRIVATE_KEY>'
```

Verify:

```bash
security find-generic-password -s "Private key for signing Sparkle updates" -a "ed25519" -w
```

## One-command release

From repo root:

```bash
./external/AgentPi/scripts/release-local.sh 1.0.4
```

Skip notarization if needed:

```bash
./external/AgentPi/scripts/release-local.sh 1.0.4 --skip-notarize
```

## Generated assets

Release uploads exactly these files:

- `AgentPi.dmg`
- `AgentPi.dmg.sha256`
- `AgentPi.app.zip`
- `AgentPi.app.zip.sha256`

Sparkle consumes `AgentPi.app.zip` via `appcast.xml` enclosure URL.

## Validation checklist

1. Open release page and confirm the 4 assets exist.
2. Check raw appcast:

```text
https://raw.githubusercontent.com/Cz07cring/agentpi/main/external/AgentPi/appcast.xml
```

3. Confirm latest `<item>` includes:
   - `sparkle:shortVersionString` = released version
   - `sparkle:edSignature` non-empty
   - enclosure URL points to `AgentPi.app.zip`

## Troubleshooting

### Client says "already latest"

1. Confirm raw appcast contains the new version.
2. Confirm enclosure URL is reachable (no 404/private restriction).
3. Confirm `sparkle:edSignature` matches the uploaded zip (re-release if mismatch).

### Sparkle signing failed

1. Verify key exists in Keychain with correct service/account.
2. Verify `sign_update` exists (Xcode Sparkle package resolved).

### Release assets upload failed

1. Re-run script; it updates existing release assets with `--clobber`.
2. Ensure `gh auth status` shows proper token scope.
