# Global Minimum Tax replication package

The pipeline builds the FY2017–2023 OECD CbCR panel, estimates and allocates
Pillar Two top-up taxes, and generates the paper and appendix exhibits.
[REPLICATION.md](REPLICATION.md) documents the pinned inputs, installation,
execution, hash verification and exhibit-to-data map. A [PDF copy](README.pdf)
is available for the replication deposit.

With the R dependencies restored and LibreOffice on the path, run from the
repository root.

```sh
Rscript --vanilla run_all.R
Rscript --vanilla tests/verify_golden_step15.R
Rscript -e "testthat::test_dir('tests/testthat')"
```

The live Python collector is separate from the offline replication run.
The `docs/archive/` directory contains historical writing and presentation
material.
