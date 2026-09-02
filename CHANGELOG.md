# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses calendar versioning in the format `YYYY.MM.patch`.

## [2026.09.0] - 2026-09-02

### Added
- Calendar versioning: `VERSION` file at repo root, read at runtime via `magnetometer_common.get_version()`.
- `install.sh` now detects fresh installs vs upgrades vs re-runs of the same version, and records the installed version to `config/installed-version.txt`.
- `updateMagnetometerACM0.sh` downloads the latest GitHub release archive and updates code without replacing data, configuration, logs, temporary files or plot archives.
- Nested `plots/<Type>/YYYY/YYYY-MM/YYYY-MM-DD.png` archive layout for daily XYZ, Activity, HDZ and BI plots, replacing the flat `plots/<Type>/` folder with `_XYZ_plot`/`_HDZ_plot`/`_BI_plot` filename suffixes.
- Daily plot scripts now log `New directory created` the same way the Python processors do, only when a new year/month archive folder is created.

### Fixed
- `install.sh` can now be re-run without errors: the `logfiles` directory creation and `README.md` cleanup are now idempotent.
