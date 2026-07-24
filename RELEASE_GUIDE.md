# OneSpace release guide

## Automated build

Open PowerShell in the project directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_release.ps1
```

The script creates:

- `release\windows\onespace.exe` and its required DLL/data files
- `release\android\OneSpace.apk`

The Windows executable is not standalone. Keep and distribute the entire
`release\windows` directory, normally as a ZIP file.

The Android release configuration suppresses references to optional ML Kit
Chinese, Devanagari, Japanese, and Korean recognizers because OneSpace uses only
the bundled Latin text recognizer.

## Install the Android APK

Copy `OneSpace.apk` to the phone, open it, and allow installation from the file
manager if Android asks. This university build uses the project's debug signing
key. A private release key is required only for store distribution.

Alternatively, with USB debugging enabled:

```powershell
adb install -r .\release\android\OneSpace.apk
```

## Manual commands

```powershell
flutter pub get
flutter build windows --release
flutter build apk --release
```

The original Flutter outputs are located at:

- `build\windows\x64\runner\Release\`
- `build\app\outputs\flutter-apk\app-release.apk`

## Final smoke test

Test registration, login, image capture/import, cloud synchronization, search,
editing, favorites, item sharing, QR generation and QR image sharing, sign out, and sign in again on both
platforms before submitting the project.
