add_cox_outcome <- function(df) {
  has_outcome <- !is.na(df$out_date)
  df$cens_status <- as.integer(has_outcome)
  df$outcome_cox_dates <- df$end_date_outcome
  df$outcome_cox_dates[has_outcome] <- df$out_date[has_outcome]
  df
}
