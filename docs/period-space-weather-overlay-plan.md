# Space-weather overlays for Pico period plots

## Status

The production implementation is in place and remains opt-in
(`plot_period_spaceweather = false` by default). Tracked code now shares the
Kp/DONKI normalization and plot builder with the INTERMAGNET test harness,
refreshes a separate cache, and writes to the existing period archive and web
image paths. Automated tests cover the data transformations, cache recovery,
configuration migration, plot generation and output locations.

Still required on the Raspberry Pi: run `bash -n` on the modified period
pipeline, generate and inspect the 2023 Hartland test plots, then enable the
setting and verify local-web and remote publication. This Windows environment
has no Bash or gnuplot, so those runtime checks have not been performed here.
The `INTERMAGNET/` directory remains Git-ignored by design; changes to its
local wrapper scripts are not part of the tracked release.

## Goal

Add historical Kp and geomagnetic-storm context, including DONKI-linked CME
launches and Earth-arrival shocks, to the Pico's existing long-period magnetic
plots. The Pico magnetic measurements remain the primary data. Space-weather
data is a separately sourced annotation, not a replacement for magnetometer
measurements or proof that a particular CME caused a magnetic change.

The first production version should be opt-in. With it disabled, existing plot
images, layouts and processing behavior must remain unchanged.

## Existing implementation

- `ProcessDailySummary.py` builds the daily magnetic data used by all long
  periods. `GetPeriodPlotAvailability.py` decides whether each period has
  enough complete days.
- `processPeriodPlots.sh` renders enabled periods and XYZ/HDZ/BI families via
  `PlotPeriod.gp`. It continues after an individual plot failure.
- `moveGraphs.sh` publishes period images from `temp/periods/`, and
  `uploadRemote.sh` already handles period images and availability status.
  Keeping the existing image paths should avoid a new web-page or upload
  workflow.
- `INTERMAGNET/FetchSpaceWeather.py` already downloads GFZ Kp and NASA DONKI
  storm/shock data, associates linked CMEs and writes normalized CSV files.
  `INTERMAGNET/PlotSpaceWeather.py` already renders the magnetic families with
  Kp bars, storm markers, CME launch arrows and shock markers. These scripts
  are test-harness code in an ignored folder, not installed production code.
- `plot_kp` in `plot.ini` controls the existing NOAA Kp *forecast* image. It
  must not be repurposed for historical period plots.

## Proposed behavior

For each enabled period and magnetic family, retain the current magnetic
panels and add a Kp panel beneath them:

- Week and month: 3-hour Kp values, as bars coloured by NOAA G-scale.
- 3-month, 6-month and year: daily maximum Kp bars to keep the plot readable.
- Geomagnetic storm start: a G-scale-coloured dashed line through the magnetic
  panels and the Kp panel. Label storms on short views; on 6-month and year
  views label G3 and stronger to limit clutter. Derive the displayed level
  from the selected Kp data, rather than DONKI's quick-look rating, so labels
  and bars agree.
- CME and shock context: show a CME launch marker and an arrow to its linked
  storm, plus a marker at the linked shock's Earth arrival. Only show CMEs
  linked by DONKI; do not imply every CME hit Earth.
- Use UTC consistently. Request a short lead-in before each plotted window so
  a CME launched just before the first plotted day can still be associated
  with a storm inside the window.
- A weather-data gap is a gap in the Kp panel, not a missing magnetic day and
  not a reason to mark an otherwise available magnetic period unavailable.
  If no usable weather data exists, keep the magnetic plot and make the
  missing overlay clear in the panel and logs.

## Configuration and data

Add a separate setting such as `plot_period_spaceweather = false` under
`[plots]`, with a matching environment override only if consistent with the
existing configuration pattern. Add the option to `install/plot.ini.example`
and use the existing additive config migration so upgrades preserve the user's
other settings. Document that this setting is independent of `plot_kp`.

Promote the reusable fetch/parse/render logic from `INTERMAGNET/` into tracked
production code under `scripts/`. Refactor the INTERMAGNET harness to invoke
that same implementation so test and production behavior cannot drift. Keep
sensor files in `data/raw/` untouched. Store normalized Kp and event data under
a dedicated `data/spaceweather/` directory, with any raw download cache kept
separate from sensor data.

Use GFZ Potsdam Kp data (CC BY 4.0; retain attribution on the plot) and NASA
CCMC DONKI storm, interplanetary-shock and linked-CME records. Before release,
verify what dates the chosen GFZ endpoint provides as definitive. Do not
silently substitute forecast or preliminary values into a definitive series;
unavailable dates should remain gaps unless a later change explicitly adds a
second, clearly identified data source.

Fetch an initial history sufficient for the longest enabled period, plus the
CME lead-in. Thereafter refresh an overlapping recent range and merge it with
the local normalized history, rather than re-downloading a full year on every
daily run. The overlap should be chosen after checking source publication
latency and DONKI update behavior. Validate downloads and write files
atomically, preserving the last good data if an HTTP request or parse fails.
Bound retries and timeouts, keep output readable by the install owner, and log
the covered dates and source failures.

## Rendering and integration

Adapt the tested INTERMAGNET renderer to production paths and configuration.
It should read the Pico's `data/daily/summary.csv` and cached space-weather
CSVs, and write the same archive and temporary image paths used today:

- Archive: `plots/<period>/<family>/YYYY/YYYY-MM/<target-date>.png`
- Current web image: `temp/periods/<period>/<family>.png`

Keep the existing renderer as the path when the new setting is false. When it
is true, have `processPeriodPlots.sh` invoke the overlay renderer for eligible
periods, preserving per-image error handling so one family or period does not
prevent the others from being attempted. Availability continues to be based
only on magnetic daily coverage. The existing page and upload code should
continue to work because the temporary filenames and status contract remain
stable; verify that assumption in tests before changing either surface.

If the download fails, use the last validated cache and log a warning. If no
cache exists yet, still produce the magnetic plot with a clearly marked empty
Kp panel. An overlay failure must not suppress daily plots, status generation,
or unrelated period plots. When the feature is disabled, remove any stale
space-weather-overlay images from local temporary output and published
destinations so old annotated plots cannot remain visible.

## Work plan

1. **Make the prototype reusable.** Move shared normalization and event-linking
   logic into tracked scripts, keeping the INTERMAGNET commands as a safe
   isolated test harness. Add fixtures for Kp intervals, missing records,
   storm classifications, linked CME launches and shock arrivals.
2. **Add production configuration and cache refresh.** Add the opt-in setting
   through the example config and additive migration. Implement bounded,
   atomic refresh/merge behavior and diagnostics without touching
   `data/raw/`.
3. **Integrate rendering.** Adapt the tested gnuplot generation for Pico paths,
   preserve magnetic scales and labels, add the Kp panel and event marks, and
   connect it to `processPeriodPlots.sh` behind the new setting.
4. **Preserve publication behavior.** Confirm the existing local web and
   remote-upload paths publish the resulting images unchanged. Add stale-file
   removal for disabling the setting. Only modify `WWW/index.html` if real
   testing shows the existing period cards need an availability note.
5. **Validate, then enable deliberately.** Run automated tests and the
   INTERMAGNET year/series tests first. Upload the code to the Pi, check shell
   syntax, run a full year and a close-up storm plot, inspect logs/files, then
   enable the setting and verify local web and remote publication.

## Acceptance checks

- With the setting off, generated period images match the existing magnetic-
  only behavior, and no stale annotated image is published.
- With the setting on, each available period/family image includes the
  expected Kp cadence, storm markers and linked CME/shock annotations, in UTC.
- A known 2023 Hartland case still shows the April CME launch, linked storm and
  Earth shock in the expected order; Pico magnetic data is used for the
  magnetic panels, not Hartland data.
- Missing magnetic days remain governed by the existing 90% period rule;
  missing Kp/event data does not change magnetic availability.
- Simulated network errors, malformed payloads, empty intervals and unwritable
  output are reported clearly, leave last-good cache intact, and do not stop
  unrelated magnetic plots or daily processing.
- Tests cover upgrade migration, file ownership/read permissions, atomic
  writes, archive/temp paths, local web publishing, remote upload, and cleanup
  after disabling the option.
- The plot identifies GFZ and NASA data sources and includes the GFZ CC BY 4.0
  attribution. Labels communicate catalogued storm/CME association without
  claiming causation.

## Decisions to confirm during implementation

- Verify GFZ definitive-data availability for recent dates and choose the
  cache refresh overlap based on observed publication delay. The initial
  version should prefer a transparent gap over silently mixing data products.
- Keep the overlay opt-in until it has been tested on the Pi and through the
  actual local/remote publication routes.
- Do not alter the current NOAA forecast panel or its `plot_kp` setting as part
  of this work.