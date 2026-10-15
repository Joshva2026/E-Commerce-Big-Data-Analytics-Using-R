# regional_analysis.R
run_regional_analysis <- function(dt) {
  cat("Running regional analysis...\n")
  
  if (!"Sales_INR" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Regional analysis requires Sales field."), "output/regional.json", auto_unbox = TRUE)
    return()
  }
  
  has_region <- "Region" %in% names(dt)
  has_state <- "State" %in% names(dt)
  
  if (!has_region && !has_state) {
    write_json(list(available = FALSE, reason = "Regional analysis requires Region or State field."), "output/regional.json", auto_unbox = TRUE)
    return()
  }
  
  regional_summary <- list(available = TRUE)
  
  if (has_region) {
    reg_sales <- dt[, .(Sales = sum(Sales_INR, na.rm=TRUE)), by = Region][order(-Sales)]
    regional_summary$regions <- list(
      labels = reg_sales$Region,
      sales = reg_sales$Sales
    )
  }
  
  if (has_state) {
    state_sales <- dt[, .(Sales = sum(Sales_INR, na.rm=TRUE)), by = State][order(-Sales)]
    state_sales <- head(state_sales[!is.na(State)], 10)
    regional_summary$top_states <- list(
      labels = state_sales$State,
      sales = state_sales$Sales
    )
  }
  
  write_json(regional_summary, "output/regional.json", auto_unbox = TRUE)
}
