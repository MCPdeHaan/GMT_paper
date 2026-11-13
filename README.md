# GMT paper

The replication runner uses pinned local inputs. The Python collector handles
live acquisition separately. The Step 17 runtime used R 4.6.0 on arm64 macOS
under a UTF-8 locale and LibreOfficeDev 26.8.0.0.alpha0. The R dependencies are
recorded in `renv.lock`.

From the repository root, with R and LibreOffice on the path, restore the
recorded R library and check the raw and manual inputs.

```sh
Rscript --vanilla -e 'install.packages("renv", repos = "https://cloud.r-project.org"); renv::restore(prompt = FALSE)'
shasum -a 256 -c tests/step17_raw_inputs.sha256
```

Run in a fresh output directory. Set `R_LIBS_USER` to the restored library so
each stage subprocess uses the recorded versions.

```sh
export R_LIBS_USER="$(Rscript --vanilla -e 'cat(renv::paths$library())')"
out="$(mktemp -d)"
Rscript --vanilla run_all.R "--output-root=$out"
# The archived PwC tracker is the one frozen file without an active writer.
cp data/processed/pwc_pillar2_tracker.rds "$out/data/processed/"
Rscript --vanilla tests/verify_golden_step15.R "$out"
Rscript --vanilla -e "testthat::test_dir('tests/testthat')"
```

The golden manifest was introduced at `5351361bc8f06f6691aa91c1210be5ffdea3ca5e`
and covers 360 frozen processed files. A second manifest pins the SHA-256
hash of `step3_stage1_pooled_t4_completeness_sensitivity.csv` for 361 files
in total. The sensitivity reports
the effect of requiring observed low and upper Table IV profit brackets and
observed low-bracket tax when low-bracket profit is positive. It separates
screening direct estimates from also screening the anchors used to transport
bracket shapes.

The runner executes the fiscal-flow phase of module 11 before module 09.
Modules 08 and 10 then consume the budget comparisons. The remaining policy
and variance phase of module 11 consumes their outputs. Use
`--skip-measurement-error` for a replay that omits the legacy 500-draw Stage 1
simulation. This leaves 13 frozen files out of a fresh replay. To produce them
in that directory, run the following from the repository root.

```sh
GMT_OUTPUT_ROOT="$out" Rscript --vanilla code/11_policy_game_and_variance_extensions.R --phase=measurement_error
GMT_OUTPUT_ROOT="$out" Rscript --vanilla code/13_generate_exhibits.R
```
