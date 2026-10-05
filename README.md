# kabaadi_wala

A new Flutter project.

## Local configuration

Copy `.env.example` to `.env`, fill in the Firebase and Gemini values, then run
or build with `flutter run --dart-define-from-file=.env` or
`flutter build web --dart-define-from-file=.env`. Pass the same flag to other
Flutter build commands. `.env` uses the JSON object format required by
`--dart-define-from-file` and is excluded from Git.

Firebase client configuration is public in a distributed app. Restrict its API
key in Google Cloud and enforce Firebase security rules. Do not ship a Gemini
key in a client build for production; use a backend proxy and rotate any key
that has already been committed or distributed.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
