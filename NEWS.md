# owdata 0.0.0.9000

Initial development version.

- Harvested catalog of the openwashdata organization shipped as an internal snapshot with accessor functions `owd_packages()`, `owd_datasets()` and `owd_variables()`.
- `owd_search()` runs a case-insensitive regex over a prebuilt index of package, dataset and variable metadata.
- `owd_install()` installs packages from the openwashdata R-universe.
- `owd_refresh()` fetches the latest published catalog into a user cache without reinstalling the package; the attach message warns when the installed snapshot is more than eight weeks old.
- Version-tier inclusion policy (dev, candidate, catalogued) with a dated transitional rule for packages published with a DOI before the 2026 review standard, plus an override file as escape hatch.
- Harvest orchestrator with interchangeable local and GitHub backends, hardened parsers with a fixture suite of real pathological files, a problems table instead of hard failures, and delta checks against the previous committed run.
- Weekly harvest workflow that commits generated data to main behind a schema and content test gate, syncs the r-universe registry draft, and opens or updates a harvest-failure issue on any failure.
