# Support query ff5695a0

The action has a clear avoidable cost: it prepared Cox event dates one record at a time. I changed that step to use vector operations, preserving the event and censoring rules. On **synthetic data**, the preparation step fell from 7.804 seconds to about 0.001 seconds for 50,000 rows, and the complete action produced its 13 declared outputs. This does **not** establish why the reported production job has run for four weeks. Its logs, row count, memory use, and current stage are unavailable here. Check the live job's last log line and resource use first; a running job will need a new run to use this change.

## What the code shows

The [action](repos/opensafely__post-covid-cvd-missingness-methods/analysis/unconfoundedness_test/unconfoundedness_test.R) reads a postprocessed subsample, prepares outcome dates, then fits four logistic and four Cox models. The [action definition](repos/opensafely__post-covid-cvd-missingness-methods/project.yaml) invokes it through `r:v2`. Each Cox model uses `coxph()` with its default Efron handling for tied dates. Daily event dates can create ties, but their number and impact in the real input are unknown. The job's four week duration comes from the query; I could not observe jobs.opensafely.org or real patient data.

## Measured locally

I ran R 4.5.0 with survival 3.8.3, which may differ from `r:v2`. The [synthetic input generator](repos/opensafely__post-covid-cvd-missingness-methods/analysis/unconfoundedness_test/make_synthetic_inputs.R) created **50,000 synthetic records**, including **7,491 synthetic events**, for the full action run. It completed and wrote all 13 CSV outputs. R's sampled profiler attributed 42% of its 3.76 seconds of sampled time to `coxph()` and 30% to `glm()`; these inclusive percentages overlap with their callers and are specific to this small synthetic run.

The [benchmark](repos/opensafely__post-covid-cvd-missingness-methods/analysis/unconfoundedness_test/benchmark_ties.R) used a separate **50,000 synthetic records**, **7,619 synthetic events**, and 365 distinct synthetic event days. Its old row loop took 7.804 seconds; vector preparation took about 0.001 seconds and returned identical dates and censoring status. Efron versus Breslow Cox times were 0.969 versus 0.729 seconds for the full variable set; the three smaller sets differed by 0.006–0.015 seconds. Their maximum absolute coefficient differences were about 0.000008–0.000013. These results do not justify automatically changing the statistical method or extrapolating to the production cohort.

## Proposal and validation

| Item | Change or check |
| --- | --- |
| Required code | [Vectorise event preparation](repos/opensafely__post-covid-cvd-missingness-methods/analysis/unconfoundedness_test/fn-add_cox_outcome.R), called by the action. This removes repeated R assignments and also handles zero rows. It leaves the model and tie method unchanged. |
| Regression test | [Test event and censored dates, status, Date class, and empty input](repos/opensafely__post-covid-cvd-missingness-methods/analysis/unconfoundedness_test/test-add_cox_outcome.R). `Rscript analysis/unconfoundedness_test/test-add_cox_outcome.R` passed. |
| Optional benchmark | Run `Rscript analysis/unconfoundedness_test/benchmark_ties.R 50000` from the study root. This is synthetic and tests only preparation and Cox fitting. |
| Documentation and smoke test | [README commands](repos/opensafely__post-covid-cvd-missingness-methods/README.md) generate synthetic processed inputs and run the actual action. The 50,000 row smoke run completed. |

The ehrQL authoring workflow informed the validation boundary: this action consumes processed RDS and selection CSV files, while the [ehrQL definition](repos/opensafely__post-covid-cvd-missingness-methods/analysis/dataset_definition/dataset_definition_prevax.py) is upstream of several R transformations. I did not change that definition or claim an ehrQL assurance run. The synthetic generator exercises the changed action end to end from its actual input files to its declared outputs; it does not validate upstream cohort construction or real data behavior.

For the live job, inspect whether it is still preparing dates, fitting a named model, or stalled on infrastructure. Record input rows, event-day tie distribution, memory, and elapsed time per model inside the secure environment. If Cox fitting dominates at production scale, benchmark Efron and Breslow there and compare coefficients, p-values, and all four conclusions before considering a method change. Breslow is a statistical change, so it needs study-team review. The local synthetic difference was modest. No production speedup or resolution is verified.
