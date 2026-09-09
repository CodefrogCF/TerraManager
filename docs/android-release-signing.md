# Android Release Signing

TerraManager Android Release builds use a private production key. The keystore
and passwords are release credentials and must never be committed, attached to
an issue or shared in chat.

The Gradle configuration accepts either:

- an ignored local `android/key.properties` file; or
- four `TERRAMANAGER_*` environment variables, which take precedence.

Debug builds require neither source. Release builds fail before packaging when
the configuration is incomplete or the configured keystore cannot be found.

## Validated production certificate

The production certificate established with build `0.14.3+35` uses RSA with a
4096-bit key. Its SHA-256 certificate digest is:

```text
f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748
```

Every future directly distributed Android APK must verify against this
certificate unless a separately planned and platform-compatible key-rotation
process is performed. The digest is public verification information; the
keystore and its passwords remain private.

## 1. Create the production keystore once

Open PowerShell on the release computer. Create a private directory outside the
repository and generate a long-lived RSA key:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.terramanager-signing"

keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\.terramanager-signing\terramanager-release.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -alias terramanager
```

Enter strong, unique passwords when `keytool` asks. Keep the alias
`terramanager`, or use the chosen alias consistently in the configuration.
Do not paste passwords into documentation, commits, terminal commands or issue
comments.

This key is created once, not once per build. Replacing it later breaks the
direct Android update path.

## 2. Back up the key before the first release

Before distributing an artifact:

1. Copy the `.jks` file to at least two encrypted storage locations.
2. Keep one backup physically separate from the release computer.
3. Store the keystore password, key password and alias in a trusted password
   manager, separately from the keystore backup.
4. Record the certificate's SHA-256 fingerprint and expiry date.
5. Test that one backup can be opened with `keytool -list`.

Example inspection command:

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\.terramanager-signing\terramanager-release.jks" `
  -alias terramanager
```

The private key cannot be recreated from its fingerprint. If a self-managed
app-signing key is lost, directly installed versions signed by it cannot be
updated with a newly generated key. If Google Play App Signing is adopted, keep
the Play app-signing certificate and the local upload-key certificate clearly
distinguished and follow the Play recovery process for a lost upload key.

## 3. Configure local signing

Before creating the local properties file, confirm that the Debug build remains
independent of release credentials:

```powershell
Test-Path android\key.properties
flutter build apk --debug
```

`Test-Path` should return `False`, and the Debug APK should build successfully.
Then copy the safe template:

```powershell
Copy-Item android\key.properties.example android\key.properties
```

Edit only `android/key.properties`:

```properties
storeFile=C:/Users/YOUR_NAME/.terramanager-signing/terramanager-release.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=terramanager
keyPassword=YOUR_KEY_PASSWORD
```

Use forward slashes or doubled backslashes in a Windows path. The real file is
ignored by Git. Confirm this before building:

```powershell
git check-ignore -v android/key.properties
git status --short
```

Neither the real `key.properties` file nor the `.jks` file may appear as an
untracked or staged file.

### Environment-variable alternative

For a temporary PowerShell session or a future CI secret store, omit
`android/key.properties` and set all four values:

```powershell
$env:TERRAMANAGER_KEYSTORE_FILE = "C:\Users\YOUR_NAME\.terramanager-signing\terramanager-release.jks"
$env:TERRAMANAGER_KEYSTORE_PASSWORD = Read-Host "Keystore password"
$env:TERRAMANAGER_KEY_ALIAS = "terramanager"
$env:TERRAMANAGER_KEY_PASSWORD = Read-Host "Key password"
```

Close the PowerShell window after the build to remove these session variables.

## 4. Validate development and production builds

Run the normal checks and create both production artifacts:

```powershell
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Expected output files:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

## 5. Verify signatures and checksums

Locate the newest installed Android SDK Build Tools directory and verify the
APK certificate:

```powershell
$androidBuildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1

& "$($androidBuildTools.FullName)\apksigner.bat" verify `
  --verbose `
  --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

The result must report successful verification and the certificate subject and
SHA-256 digest must match the production key recorded in step 2. It must not be
the Android Debug certificate.

Verify that the AAB carries the expected JAR signature:

```powershell
jarsigner -verify -verbose -certs `
  build\app\outputs\bundle\release\app-release.aab
```

Create checksums for the release record:

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
Get-FileHash build\app\outputs\bundle\release\app-release.aab -Algorithm SHA256
```

Store the artifact filenames, version, checksum values and verified certificate
SHA-256 digest in the private release record.

## 6. One-time transition from debug-signed builds

Build `0.14.2+34` uses the permanent ID `com.codefrog.terramanager`, but it was
still signed with a debug certificate. Android will reject the production-
signed APK as an in-place update because the certificates differ.

On every device that contains data in the debug-signed application:

1. Export a current `.tmbackup` and store it safely.
2. Verify that the backup can be selected and validated.
3. Uninstall the debug-signed TerraManager application.
4. Install the production-signed APK.
5. Restore the `.tmbackup` in Settings.
6. Verify Boxes, Animals, FeedingEvents, settings and pictures.

After this transition, every directly distributed update must retain both
`com.codefrog.terramanager` and the same production signing certificate.

## References

- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Android Developers: Sign your app](https://developer.android.com/studio/publish/app-signing)
- [Android Developers: apksigner](https://developer.android.com/tools/apksigner)
