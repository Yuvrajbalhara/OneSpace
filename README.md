# OneSpace
<<<<<<< HEAD
A cross-platform productivity application for Windows and Android. One workspace for Every device.
=======

**Everything you need, in one space.**

OneSpace is a responsive Flutter productivity prototype for Windows and Android.
It combines a smart personal library, universal search, a keyboard-driven command
palette, and a QR utility in a single application.

## Current prototype

- Adaptive desktop navigation and mobile bottom navigation
- Dashboard with library statistics and recent items
- Search across titles, descriptions, categories, and tags
- Filterable library with grid and list layouts
- `Ctrl + K` command palette on Windows
- Email registration, login, personalized profile, and sign out
- Private per-user Supabase library synchronized across Windows and Android
- Working QR generator with copy and PNG sharing actions
- Native sharing for library text, tags, and images
- Light and dark Material 3 themes
- Real image selection on Windows and Android
- Android camera capture and on-device OCR
- Cloud-persistent notes, metadata, favorites, and private images

## Run

```shell
flutter pub get
flutter run -d windows
```

Create an account on the first screen. Use the same email and password on the
Android and Windows builds to access the same synchronized workspace.

For Android, connect a device with USB debugging enabled and use `flutter devices`
followed by `flutter run -d <device-id>`.

For distributable Windows and Android builds, run `build_release.ps1` and see
`RELEASE_GUIDE.md`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
>>>>>>> e2dabb9 (Initial OneSpace Flutter release)
