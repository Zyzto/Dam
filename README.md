<!-- markdownlint-disable MD033 MD060 -->

<p align="center">
  <img src="icon.svg" alt="Janan" width="200" />
</p>

<h1 align="center">Janan - الجَنَان</h1>

<p align="center">
  <strong>Your health diary, kept on your device.</strong><br/>
  Track blood pressure and weight, automatically import readings from saved
  Bluetooth monitors and scales when you open the app, follow trends, and
  export your records. Flutter · offline-first · no account.
</p>

<p align="center">
  <a href="https://github.com/Zyzto/blood-pressure-monitor-fl/releases/latest"><img alt="release" src="https://img.shields.io/github/v/release/Zyzto/blood-pressure-monitor-fl?style=flat-square&color=3D82AF" /></a>
  <a href="https://github.com/Zyzto/blood-pressure-monitor-fl/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Zyzto/blood-pressure-monitor-fl/ci.yml?style=flat-square&label=CI" /></a>
  <a href="https://github.com/Zyzto/blood-pressure-monitor-fl"><img alt="repo" src="https://img.shields.io/badge/github-Zyzto%2Fblood--pressure--monitor--fl-C0C0C0?style=flat-square" /></a>
  <a href="https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Zyzto/blood-pressure-monitor-fl/releases"><img alt="Obtainium" src="https://img.shields.io/badge/Obtainium-add-3D82AF?style=flat-square&logo=android&logoColor=white" /></a>
  <img alt="flutter" src="https://img.shields.io/badge/Flutter-3.47-C0C0C0?style=flat-square&logo=flutter&logoColor=white" />
  <a href="LICENSE.md"><img alt="license" src="https://img.shields.io/badge/license-GPL--3.0-3D82AF?style=flat-square" /></a>
</p>

<p align="center">
  <a href="https://github.com/Zyzto/blood-pressure-monitor-fl/releases/latest"><strong>Latest release</strong></a>
  ·
  <a href="#this-is-a-fork">This is a fork</a>
  ·
  <a href="#whats-different-from-upstream">What's different</a>
  ·
  <a href="#what-you-get">What you get</a>
  ·
  <a href="#screenshots">Screenshots</a>
  ·
  <a href="#install">Install</a>
  ·
  <a href="#develop">Develop</a>
  ·
  <a href="README.ar.md">العربية</a>
</p>

<p align="center">
  The name <strong>Janan</strong> comes from Arabic
  <span dir="rtl"><strong>الجَنَان</strong></span>
  (<em>al-janān</em>): the heart.
</p>

---

## Screenshots

<div dir="ltr">
<p align="center">
  <img src="docs/screenshots/en-light-home.png" alt="Measurements" width="180" />
  <img src="docs/screenshots/en-light-weight.png" alt="Weight" width="180" />
  <img src="docs/screenshots/en-light-stats.png" alt="Statistics" width="180" />
  <img src="docs/screenshots/en-light-add.png" alt="Add a reading" width="180" />
</p>
<p align="center">
  <img src="docs/screenshots/en-light-today.png" alt="Today's medicines" width="180" />
  <img src="docs/screenshots/en-light-reminders.png" alt="Medicine reminders" width="180" />
  <img src="docs/screenshots/en-light-medications.png" alt="Medications" width="180" />
  <img src="docs/screenshots/en-light-settings.png" alt="Settings" width="180" />
</p>
</div>

<details>
<summary>More</summary>
<p align="center">
  <img src="docs/screenshots/en-light-dose.png" alt="Next dose" width="180" />
  <img src="docs/screenshots/en-light-stats-day.png" alt="Distribution and time of day" width="180" />
</p>
</details>

<details>
<summary>Dark theme</summary>
<p align="center">
  <img src="docs/screenshots/en-dark-home.png" alt="Measurements — dark" width="180" />
  <img src="docs/screenshots/en-dark-weight.png" alt="Weight — dark" width="180" />
  <img src="docs/screenshots/en-dark-stats.png" alt="Statistics — dark" width="180" />
  <img src="docs/screenshots/en-dark-add.png" alt="Add a reading — dark" width="180" />
</p>
<p align="center">
  <img src="docs/screenshots/en-dark-today.png" alt="Today's medicines — dark" width="180" />
  <img src="docs/screenshots/en-dark-reminders.png" alt="Medicine reminders — dark" width="180" />
  <img src="docs/screenshots/en-dark-medications.png" alt="Medications — dark" width="180" />
  <img src="docs/screenshots/en-dark-settings.png" alt="Settings — dark" width="180" />
</p>
<p align="center">
  <img src="docs/screenshots/en-dark-dose.png" alt="Next dose — dark" width="180" />
  <img src="docs/screenshots/en-dark-stats-day.png" alt="Distribution and time of day — dark" width="180" />
</p>
</details>
---

## Install

### Android

| Option | |
|--------|--|
| **Obtainium** (recommended) | [![Obtainium](https://img.shields.io/badge/Obtainium-add-3D82AF?style=flat-square&logo=android&logoColor=white)](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Zyzto/blood-pressure-monitor-fl/releases) — tracks [GitHub Releases](https://github.com/Zyzto/blood-pressure-monitor-fl/releases) |
| **APK** | From the [latest release](https://github.com/Zyzto/blood-pressure-monitor-fl/releases/latest) |

This fork is not on Play. Build from source if you want a copy you signed yourself.

---

## Develop

**Requirements:** Flutter `3.47.1` (pinned in `pubspec.yaml`).

```bash
git clone https://github.com/Zyzto/blood-pressure-monitor-fl.git
cd blood-pressure-monitor-fl
dart run build_runner build
flutter run
```

```bash
flutter build apk
```

Release Android builds need a [signing key](https://docs.flutter.dev/deployment/android#sign-the-app). CI and Obtainium releases are in [docs/ci.md](docs/ci.md).

---

## Architecture (short)

- **UI / state** — Flutter, generated Riverpod
- **Local DB** — PowerSync local-only tables (`health.db`)
- **Input** — Manual forms, Bluetooth LE blood-pressure service, optional Health Connect
- **Export** — CSV, PDF, SQLite

Deeper notes live in [`docs/`](docs/).

---

## Docs

| Guide | |
|-------|--|
| [Bluetooth devices](docs/bluetooth.md) | Meters, scales, and how they report readings |
| [Data package](docs/data-package.md) | How stored records are shaped |
| [Code style](docs/codestyle.md) | Conventions in this tree |
| [Testing](docs/testing.md) | How tests are organized |
| [CI and releases](docs/ci.md) | Analyze, test, signed APK, Obtainium |
| [Contributing](CONTRIBUTING.md) | Bugs, translations, PRs on **this** repo |

---

Open issues and pull requests on [Zyzto/blood-pressure-monitor-fl](https://github.com/Zyzto/blood-pressure-monitor-fl). See [CONTRIBUTING.md](CONTRIBUTING.md).

Do not send patches to the upstream derdilla repository from this fork.

---

## This is a fork

Janan is a fork of [blood-pressure-monitor-fl](https://github.com/derdilla/blood-pressure-monitor-fl) by [derdilla](https://github.com/derdilla).

This repository is [Zyzto/blood-pressure-monitor-fl](https://github.com/Zyzto/blood-pressure-monitor-fl). Issues, pull requests, and releases belong here. Work from this tree is not sent upstream.

The original app is still published by its author on [Google Play](https://play.google.com/store/apps/details?id=com.derdilla.bloodPressureApp) as *Blood pressure monitor* (`com.derdilla.bloodPressureApp`). That listing is upstream, not this fork. Janan uses `com.shenepoy.janan` and installs next to the original.

---

## What's different from upstream

Compared to [derdilla/blood-pressure-monitor-fl](https://github.com/derdilla/blood-pressure-monitor-fl) `main` (v1.8.15). This tree is not a drop-in update of a Play or F-Droid install.

| | Upstream | This fork |
|---|---|---|
| **Name** | Blood pressure monitor | Janan · الجَنَان |
| **Android id** | `com.derdilla.bloodPressureApp` | `com.shenepoy.janan` |
| **Install** | Play, F-Droid, GitHub | GitHub Releases + [Obtainium](https://github.com/ImranR98/Obtainium) |
| **Version** | Semver `1.8.15+57` | CalVer `YY.0M.MICRO` (now `26.10.5+78`) |
| **Layout** | `app/` plus workspace packages | One Flutter app at the repo root |

**Added here**

| | |
|---|---|
| **BLE profiles** | Per-device routes for standard GATT, Yonker, and Microlife meters. |
| **Saved meters** | Remember a device as an id and a name (Settings → Bluetooth devices). |
| **Automatic sync** | Import readings from saved Bluetooth monitors and supported scales when the app opens; status in the AppBar. |
| **Eufy P1** | Weight plus optional impedance. Body composition when a body profile is set. P2 is unsupported. |
| **Details** | A screen per blood-pressure or weight record (composition when ohms and a profile are present). |
| **Home** | First-run onboarding, a latest-reading dashboard, and a bottom-nav shell (measurements / weight / stats / settings). |
| **Medicine reminders** | Schedules, a countdown on the home button, and today's doses. The plan stays on the device. |

**Internals that differ**

- Local store is PowerSync `health.db` (local-only tables). A leftover upstream `bp.db` is copied in on launch.
- State is generated Riverpod. Strings are `easy_localization` JSON under `assets/translations/`, not generated ARB.
- Upstream packages `health_data_store`, `settings_annotation`, and `settings_builder` are gone from this tree.

What upstream already has and this fork still has: manual input, graphs, CSV / PDF / SQLite export, Health Connect, and the [tested devices](docs/bluetooth.md) list.

---

## What you get

| | |
|---|---|
| **Blood pressure** | Systolic, diastolic, pulse, notes, and medicine doses. |
| **Reminders** | Dose times, a home countdown, and a log of what was taken. |
| **Weight** | Optional log, BMI, and body composition from a compatible scale. |
| **Charts** | Trends, distribution, and time of day. |
| **Bluetooth** | Automatically sync saved [monitors and scales](docs/bluetooth.md) on launch, or import a reading manually. |
| **Export** | CSV, PDF, Excel, or a database backup. |
| **Health Connect** | Optional Android sync. |
| **Offline** | On the device. No account. |

---

## License

[GPL-3.0](LICENSE.md), same as the upstream project.

The name **Janan**, the Arabic wordmark <span dir="rtl">**الجَنَان**</span>, and the logo are not a grant to reuse the branding. Fork the code if you want, and ship your fork under a different name and icon.

---

<p align="center">
  Made by <a href="https://shenepoy.com"><strong>shenepoy</strong></a>
  ·
  <a href="https://github.com/Zyzto">GitHub</a>
  ·
  fork of <a href="https://github.com/derdilla/blood-pressure-monitor-fl">derdilla/blood-pressure-monitor-fl</a>
</p>
