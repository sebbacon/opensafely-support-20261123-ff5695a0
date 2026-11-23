source("analysis/unconfoundedness_test/fn-add_cox_outcome.R")

# An event uses its event date; a censored record uses its follow-up end date.
input <- data.frame(
  out_date = as.Date(c("2020-04-01", NA, "2020-04-03")),
  end_date_outcome = as.Date(c("2020-06-01", "2020-06-02", "2020-06-03"))
)
result <- add_cox_outcome(input)
stopifnot(
  identical(result$cens_status, c(1L, 0L, 1L)),
  identical(result$outcome_cox_dates, as.Date(c("2020-04-01", "2020-06-02", "2020-04-03"))),
  inherits(result$outcome_cox_dates, "Date"),
  nrow(add_cox_outcome(input[FALSE, ])) == 0L
)
