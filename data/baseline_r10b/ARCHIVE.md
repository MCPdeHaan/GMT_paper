# R10b historical scientific reference

Unchanged output bytes and publication sources from `aee0590d5a9f5c41cf9cdb67451aea8e598f9269`, preserved when R11c became the leading reference. This snapshot uses `LEGACY_HYBRID_SBIE_SBTI`, `OBSERVED_TWO_SIDED`, `STANDARD_ROLE_SPECIFIC`, `VERIFIED_PARENT_ONLY` and `NO_NOTCH_STANDARD_RESPONSE`. Its 373 processed paths and hashes are the original `tests/golden_r10b.csv`, interpreted relative to this directory.

From the repository root:

```sh
Rscript --vanilla tests/verify_golden_step15.R "$PWD/data/baseline_r10b" r10b
```

Treat this directory as frozen. Recalculate the historical model in a fresh output root, with the explicit legacy Factor 2 switch, and compare against this snapshot. The archived paper, note and exhibits preserve their historical wording and numerical specification, including assumptions revised by R11c; they are not the current legal or scientific interpretation. The leading publication and reference remain under the canonical `writing/` and `data/processed/` paths. See `docs/refactoring/r11c_sbti_specification_revision.md` for the revision and its independently recomputed comparison.
