# Clutch Time

Clutch Time is a Flutter scenario generator for late-game basketball situations. The app now targets responsive web layouts as a first-class surface, while still working well on iPhone, iPad, and larger desktop displays.

## Local development

Run the app locally with:

```bash
flutter run -d chrome
```

For one-command local static preview:

```bash
make preview
```

Then open `http://localhost:8001`.

For a one-command GitHub Pages-style preview:

```bash
make preview-gh-pages
```

Then open `http://localhost:8001/nbagenerator/`.

To use a different port:

```bash
make preview PORT=8002
make preview-gh-pages PORT=8002
```

## GitHub Pages

This repository includes a GitHub Actions workflow that builds the Flutter web app and deploys `build/web` to GitHub Pages.

Required repository settings:

1. In GitHub, open `Settings` -> `Pages`.
2. Set `Source` to `GitHub Actions`.
3. Push to `main` or run the workflow manually.

The workflow automatically sets the Flutter web `base-href` to `/<repo-name>/`, which is the path GitHub Pages uses for project sites.

For this repository specifically, the published URL will be:

`https://jamesfraschilla.github.io/nbagenerator/`
