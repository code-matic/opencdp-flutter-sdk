# Mobile SDK publishing guide

Commands and checklist for publishing **Flutter**, **Android**, **iOS**, and **React Native** OpenCDP SDKs.

Use placeholder versions below (`X.Y.Z`, `1.0.0-alpha0N`) — bump in each repo before release.

---

## Prerequisites

| SDK | Registry | Credentials |
|-----|----------|-------------|
| Flutter | [pub.dev](https://pub.dev) | `dart pub login` or `dart pub token add` (uploader on `open_cdp_flutter_sdk`) |
| Android | [Maven Central](https://central.sonatype.com) | GitHub secrets: `OSSRH_USERNAME`, `OSSRH_PASSWORD`, `GPG_SIGNING_KEY`, `GPG_SIGNING_PASSWORD` |
| iOS | [CocoaPods Trunk](https://guides.cocoapods.org/making/getting-setup-with-trunk.html) + git tags (SPM) | `pod trunk register` / trunk owner for `OpenCDP` |
| React Native | npm (`@codematic/opencdp-react-native`) | `npm login` with publish access |

**GPG key for Android:** store the full ASCII-armored private key in `GPG_SIGNING_KEY` (include `-----BEGIN PGP PRIVATE KEY BLOCK-----` lines). Passphrase in `GPG_SIGNING_PASSWORD`. Test locally:

```bash
gpg --batch --pinentry-mode loopback --passphrase "$GPG_SIGNING_PASSWORD" \
  --armor --detach-sign test.txt
```

---

## Release checklist (all SDKs)

1. Update version in the package manifest (`pubspec.yaml`, `build.gradle.kts`, `OpenCDP.podspec`, `package.json`).
2. Update `CHANGELOG.md`.
3. Run preflight tests (commands per SDK below).
4. Commit on the **release branch** (see branch notes).
5. Push branch + git tag.
6. Publish to the registry.
7. Update install docs in `openCDP-docs` if version pins changed.

---

## Flutter (`opencdp-flutter-sdk`)

**Package:** `open_cdp_flutter_sdk`  
**Branch:** `main` (protected — use a release branch + PR if direct push is blocked)

```bash
cd opencdp-flutter-sdk

# 1. Bump version in pubspec.yaml (e.g. 3.3.0)

# 2. Preflight
flutter pub get
dart analyze
flutter test
dart pub publish --dry-run

# 3. Commit & push
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release X.Y.Z"
git checkout -b release/X.Y.Z   # if main is protected
git push -u origin release/X.Y.Z  # open PR to main

# 4. Publish to pub.dev
dart pub publish --force

# 5. Tag (after merge to main, or from release branch)
git tag vX.Y.Z
git push origin vX.Y.Z
```

**Consumer install:**

```yaml
dependencies:
  open_cdp_flutter_sdk: ^X.Y.Z
```

---

## Android (`opencdp-android-sdk`)

**Coordinates:** `com.opencdp.sdk:opencdp-android`  
**Branch:** publish from your feature/release branch (e.g. `in-app-messaging`); merge to `master` separately.

```bash
cd opencdp-android-sdk

# 1. Bump version in opencdp-sdk/build.gradle.kts
#    version = "1.0.0-alpha0N"
#    Update opencdp-sdk/README.md dependency snippet too.

# 2. Preflight (requires JDK 17+)
chmod +x gradlew
./gradlew :opencdp-sdk:check
./gradlew :opencdp-sdk:publishToMavenLocal   # optional

# 3. Commit & push
git add CHANGELOG.md opencdp-sdk/build.gradle.kts opencdp-sdk/README.md
git commit -m "chore: release 1.0.0-alpha0N"
git push origin YOUR_BRANCH

# 4. Tag
git tag v1.0.0-alpha0N
git push origin v1.0.0-alpha0N

# 5. GitHub Release (triggers CI publish workflow)
gh release create v1.0.0-alpha0N \
  --target YOUR_BRANCH \
  --title "1.0.0-alpha0N" \
  --notes "Release notes here"

# Or re-run manually:
gh workflow run publish.yml --ref YOUR_BRANCH
```

**CI workflow:** `.github/workflows/publish.yml` → `./gradlew :opencdp-sdk:publishAllPublicationsToMavenCentralRepository`

**Consumer install:**

```kotlin
implementation("com.opencdp.sdk:opencdp-android:1.0.0-alpha0N")
```

Maven Central sync can take 15–30 minutes after a successful CI run.

---

## iOS (`opencdp-ios-sdk`)

**Pod:** `OpenCDP`  
**SPM:** `https://github.com/code-matic/opencdp-ios-sdk.git` (version = git tag)  
**Branch:** `main`

```bash
cd opencdp-ios-sdk

# 1. Bump spec.version in OpenCDP.podspec (must match git tag)
#    Update README.md pod line: pod 'OpenCDP', '~> X.Y.Z'

# 2. Preflight
pod spec lint OpenCDP.podspec --private --allow-warnings --quick

# 3. Commit, push, tag
git add OpenCDP.podspec README.md CHANGELOG.md
git commit -m "chore: release X.Y.Z"
git push origin main
git tag X.Y.Z
git push origin X.Y.Z

# 4. CocoaPods (tag must exist on GitHub first)
pod trunk push OpenCDP.podspec --allow-warnings
```

**Consumer install:**

```ruby
# CocoaPods
pod 'OpenCDP', '~> X.Y.Z'
```

```swift
// SPM — File → Add Packages → github.com/code-matic/opencdp-ios-sdk.git
// Version: X.Y.Z
```

Optional subspecs: `OpenCDP/PushExtension`, `OpenCDP/CustomerIO`

---

## React Native (`opencdp-react-native-sdk`)

**Package:** `@codematic/opencdp-react-native`  
Publish **after** native Android/iOS versions consumers depend on are available.

```bash
cd opencdp-react-native-sdk

# 1. Bump version in package.json

# 2. Preflight
npm install
npm run build
npm test

# 3. Commit & tag
git add package.json CHANGELOG.md
git commit -m "chore: release X.Y.Z"
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z

# 4. Publish to npm
npm publish --access public
```

**Consumer install:**

```bash
npm install @codematic/opencdp-react-native@^X.Y.Z
```

---

## Suggested release order

1. **Android** + **iOS** native SDKs (RN bridges depend on these).
2. **Flutter** (bundles its own plugin native code).
3. **React Native** (wraps native Android/iOS artifacts).
4. **Docs** — update `openCDP-docs/integrations/*/getting-started/installation.md` version pins.

---

## Verify after publish

| SDK | Verify |
|-----|--------|
| Flutter | https://pub.dev/packages/open_cdp_flutter_sdk |
| Android | https://central.sonatype.com/artifact/com.opencdp.sdk/opencdp-android |
| iOS CocoaPods | https://cocoapods.org/pods/OpenCDP |
| iOS SPM | `git ls-remote --tags https://github.com/code-matic/opencdp-ios-sdk.git` |
| React Native | `npm view @codematic/opencdp-react-native version` |

---

## Troubleshooting

### Android CI: `Could not read PGP secret key`

- Re-export the private key: `gpg --armor --export-secret-keys KEY_ID`
- Paste the **entire** block into GitHub secret `GPG_SIGNING_KEY` (no extra escaping).
- Confirm `GPG_SIGNING_PASSWORD` matches the key passphrase.
- Re-run: `gh workflow run publish.yml --ref YOUR_BRANCH`

### Flutter: protected `main`

- Push a `release/X.Y.Z` branch and open a PR; pub.dev publish can run from local checkout before merge.
- Tag can be pushed independently of `main` if the release commit is reachable.

### iOS: `pod spec lint` cannot find remote tag

- Push the git tag to GitHub **before** `pod trunk push`, or lint with `--private --quick` locally first.
