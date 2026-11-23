# Reproducible, synthetic workload for the four outcome regressions.
# Run: Rscript analysis/unconfoundedness_test/benchmark_ties.R [number_of_rows]
# No real patient data is read or written.
library(survival)
source("analysis/unconfoundedness_test/fn-add_cox_outcome.R")

args <- commandArgs(trailingOnly = TRUE)
n <- if (length(args)) as.integer(args[[1]]) else 50000L
stopifnot(!is.na(n), n >= 1000L)
set.seed(20261123)

dat <- data.frame(
  date = sample(seq.Date(as.Date("2020-03-01"), as.Date("2021-02-28"), by = "day"), n, TRUE),
  event = rbinom(n, 1, 0.15),
  cov_bin_covid = rbinom(n, 1, 0.2),
  cov_num_age = runif(n, 18, 90),
  cov_cat_sex = factor(sample(c("F", "M"), n, TRUE)),
  cov_cat_ethnicity = factor(sample(1:5, n, TRUE)),
  cov_cat_imd = factor(sample(1:5, n, TRUE))
)
for (i in 1:20) dat[[paste0("cov_bin_", i)]] <- rbinom(n, 1, 0.3)
dat$date[dat$event == 0] <- as.Date("2021-02-28")

prep <- data.frame(out_date = dat$date, end_date_outcome = as.Date("2021-02-28"))
prep$out_date[dat$event == 0] <- as.Date(NA)
old <- prep
old$outcome_cox_dates <- rep(as.Date(NA), n)
old$cens_status <- rep(NA, n)
old_time <- system.time(for (i in seq_len(n)) {
  if (is.na(old$out_date[i])) {
    old$cens_status[i] <- 0
    old$outcome_cox_dates[i] <- old$end_date_outcome[i]
  } else {
    old$cens_status[i] <- 1
    old$outcome_cox_dates[i] <- old$out_date[i]
  }
})[["elapsed"]]
new_time <- system.time(new <- add_cox_outcome(prep))[["elapsed"]]
stopifnot(identical(old$outcome_cox_dates, new$outcome_cox_dates),
          identical(as.integer(old$cens_status), new$cens_status))
cat(sprintf("Outcome preparation, row loop: %.3f seconds; vectorised: %.3f seconds\n",
            old_time, new_time))

covariates <- setdiff(names(dat), c("date", "event"))
sets <- list(
  fully_adjusted = covariates,
  lasso = covariates[c(1:3, 6:10)],
  lasso_X = covariates[c(1:3, 11:15)],
  lasso_union = covariates[c(1:3, 6:15)]
)
cat(sprintf("SYNTHETIC rows: %d; events: %d; distinct event days: %d\n",
            n, sum(dat$event), length(unique(dat$date[dat$event == 1]))))
for (name in names(sets)) {
  form <- reformulate(sets[[name]], response = "Surv(as.numeric(date), event)")
  fits <- list()
  for (method in c("efron", "breslow")) {
    elapsed <- system.time({
      fits[[method]] <- coxph(form, dat, ties = method, weights = rep(0.1, n))
    })[["elapsed"]]
    cat(sprintf("%s %s: %.3f seconds\n", name, method, elapsed))
  }
  delta <- max(abs(coef(fits$efron) - coef(fits$breslow)), na.rm = TRUE)
  cat(sprintf("%s max absolute coefficient difference: %.6g\n", name, delta))
}
