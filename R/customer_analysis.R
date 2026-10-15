# customer_analysis.R
run_customer_analysis <- function(dt) {
  cat("Running customer analysis...\n")
  
  if (!"Sales_INR" %in% names(dt)) {
     write_json(list(available = FALSE, reason = "Customer analysis requires Sales field."), "output/customers.json", auto_unbox = TRUE)
     return()
  }
  
  has_cust_id <- "Customer_ID" %in% names(dt)
  has_cust_name <- "Customer_Name" %in% names(dt)
  cust_col <- if (has_cust_id) "Customer_ID" else if (has_cust_name) "Customer_Name" else NULL
  
  has_payment <- "Payment_Method" %in% names(dt)
  
  if (is.null(cust_col) && !has_payment) {
    write_json(list(available = FALSE, reason = "Customer analysis requires Customer_ID or Customer_Name."), "output/customers.json", auto_unbox = TRUE)
    return()
  }
  
  customer_summary <- list(available = TRUE)
  
  if (!is.null(cust_col)) {
    total_customers <- uniqueN(dt[[cust_col]])
    cust_agg <- dt[, .(Total_Spend = sum(Sales_INR, na.rm=TRUE), Orders = .N), by = c(cust_col)]
    avg_spend <- mean(cust_agg$Total_Spend)
    repeat_customers <- sum(cust_agg$Orders > 1)
    repeat_rate <- if (total_customers > 0) round((repeat_customers / total_customers) * 100, 1) else 0
    
    customer_summary$kpi <- list(
      total_customers = total_customers,
      avg_spend_per_customer = avg_spend,
      repeat_rate = repeat_rate
    )
  }
  
  if (has_payment) {
    payment_dist <- dt[, .(Sales = sum(Sales_INR, na.rm=TRUE)), by = Payment_Method][order(-Sales)]
    customer_summary$payment <- list(
      methods = payment_dist$Payment_Method,
      sales = payment_dist$Sales
    )
  }
  
  write_json(customer_summary, "output/customers.json", auto_unbox = TRUE)
}
