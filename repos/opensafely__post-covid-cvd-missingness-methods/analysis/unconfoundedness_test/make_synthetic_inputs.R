# Synthetic smoke-test inputs for unconfoundedness_test.R. Run from project root:
# Rscript analysis/unconfoundedness_test/make_synthetic_inputs.R [number_of_rows]
# Rscript analysis/unconfoundedness_test/unconfoundedness_test.R cohort_prevax-main-ami prevax '18;30;40;50;60;70;80;90'
# The generated output/ files contain no real patient data.
args <- commandArgs(trailingOnly = TRUE)
n <- if (length(args)) as.integer(args[[1]]) else 5000L
stopifnot(!is.na(n), n >= 1000L)
set.seed(20261123)

name <- "cohort_prevax-main-ami"
binary <- c(
  "cov_bin_ami", "cov_bin_sahhs", "cov_bin_covid", "cov_bin_carehome",
  "cov_bin_hcworker", "cov_bin_dementia", "cov_bin_liver_disease",
  "cov_bin_ckd", "cov_bin_cancer", "cov_bin_hypertension",
  "cov_bin_diabetes", "cov_bin_obesity", "cov_bin_copd",
  "cov_bin_depression", "cov_bin_stroke_all", "cov_bin_other_ae",
  "cov_bin_vte", "cov_bin_hf", "cov_bin_angina", "cov_bin_lipidmed",
  "cov_bin_antiplatelet", "cov_bin_anticoagulant", "cov_bin_cocp",
  "cov_bin_hrt"
)
df <- data.frame(cov_num_age = runif(n, 18, 90))
for (v in binary) df[[v]] <- factor(rbinom(n, 1, if (v == "cov_bin_covid") 0.2 else 0.15))
df$cov_cat_sex <- factor(sample(c("F", "M"), n, TRUE))
df$cov_num_bmi <- runif(n, 18, 42)
df$cov_cat_ethnicity <- factor(sample(1:5, n, TRUE))
df$cov_cat_imd <- factor(sample(1:5, n, TRUE))
df$cov_cat_smoking <- factor(sample(1:3, n, TRUE))
df$strat_cat_region <- factor(sample(1:7, n, TRUE))

model <- df
model$end_date_outcome <- as.Date("2021-02-28")
model$out_date <- as.Date(NA)
event <- runif(n) < 0.15
model$out_date[event] <- as.Date("2020-03-01") + sample(0:364, sum(event), TRUE)

dir.create("output/post_hoc_vars", recursive = TRUE, showWarnings = FALSE)
dir.create("output/model", recursive = TRUE, showWarnings = FALSE)
saveRDS(df, "output/post_hoc_vars/input_prevax_clean_subsample_ami.rds")
saveRDS(model, paste0("output/model/model_input_subsample-", name, ".rds"))

selected <- data.frame(x = c("cov_num_age", "cov_cat_sex", "cov_bin_carehome"))
for (kind in c("lasso_var_selection", "lasso_X_var_selection", "lasso_union_var_selection")) {
  dir.create(file.path("output", kind), recursive = TRUE, showWarnings = FALSE)
  write.csv(selected, file.path("output", kind, paste0(kind, "-", name, ".csv")), row.names = FALSE)
}
cat(sprintf("SYNTHETIC rows: %d; events: %d\n", n, sum(event)))
