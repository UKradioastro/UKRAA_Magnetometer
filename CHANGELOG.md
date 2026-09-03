# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses calendar versioning in the format `YYYY.MM.patch`.

## [2026.09.1] - 2026-09-03

### Added
- Optional NOAA aurora forecast panel controlled by `plot_noaa`.
- Northern or southern NOAA forecast selection using `noaa_hemisphere`.
- Clean data layout using `data/minute` and `data/hour`.
- Test sandboxes under `data/tests/`.

### Changed
- Daily plotting scripts now read minute data from `data/minute`.
- Activity plotting now reads hourly data from `data/hour`.
- Fresh installs now create the new minute/hour data directories.
- Daily publish health checks now use the minute-data path.
- Documentation and installation/log examples now describe the new data layout.

### Fixed
- Test sandbox directories are assigned to `pi:pi`, including when checks are run through `sudo`.
- NOAA downloads and web publishing now respect the configuration toggle and remove stale images when the forecast is disabled.

## [2026.09.0] - 2026-09-02

### Added
- Calendar versioning: `VERSION` file at repo root, read at runtime via `magnetometer_common.get_version()`.
- `install.sh` now detects fresh installs vs upgrades vs re-runs of the same version, and records the installed version to `config/installed-version.txt`.
- `updateMagnetometerACM0.sh` downloads the latest GitHub release archive and updates code without replacing data, configuration, logs, temporary files or plot archives.
- Nested `plots/<Type>/YYYY/YYYY-MM/YYYY-MM-DD.png` archive layout for daily XYZ, Activity, HDZ and BI plots, replacing the flat `plots/<Type>/` folder with `_XYZ_plot`/`_HDZ_plot`/`_BI_plot` filename suffixes.
- Daily plot scripts now log `New directory created` the same way the Python processors do, only when a new year/month archive folder is created.

### Fixed
- `install.sh` can now be re-run without errors: the `logfiles` directory creation and `README.md` cleanup are now idempotent.
