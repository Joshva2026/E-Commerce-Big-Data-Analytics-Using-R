# sales_analysis.R
run_sales_analysis <- function(dt) {
  cat("Running sales analysis...\n")
  
  if (!"Order_Date" %in% names(dt) || !"Sales_INR" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Sales analysis requires Date and Sales fields."), "output/sales.json", auto_unbox = TRUE)
    return()
  }
  
  total_sales <- sum(dt$Sales_INR, na.rm = TRUE)
  has_order <- "Order_ID" %in% names(dt)
  has_profit <- "Profit_INR" %in% names(dt)
  
  total_orders <- if (has_order) uniqueN(dt$Order_ID) else nrow(dt)
  total_profit <- if (has_profit) sum(dt$Profit_INR, na.rm = TRUE) else NA
  aov <- total_sales / total_orders
  profit_margin <- if (has_profit) (total_profit / total_sales) * 100 else NA
  
  # Date span & monthly velocity
  date_span_days <- as.numeric(difftime(max(dt$Order_Date, na.rm = TRUE), min(dt$Order_Date, na.rm = TRUE), units = "days"))
  daily_velocity <- if (!is.na(date_span_days) && date_span_days > 0) total_sales / date_span_days else total_sales
  monthly_velocity <- daily_velocity * 30.416
  
  # Sales Trend
  monthly <- dt[, .(
    Sales = sum(Sales_INR, na.rm = TRUE),
    Profit = if (has_profit) sum(Profit_INR, na.rm = TRUE) else NA_real_,
    Orders = if (has_order) uniqueN(Order_ID) else .N
  ), by = .(Month = floor_date(Order_Date, "month"))][order(Month)]

  # Real Quarterly Breakdown
  quarters <- dt[, .(
    sales = sum(Sales_INR, na.rm = TRUE),
    orders = if (has_order) uniqueN(Order_ID) else .N
  ), by = .(Quarter = quarter(Order_Date))][order(Quarter)]
  
  quarter_names <- c("Q1 (Jan - Mar)", "Q2 (Apr - Jun)", "Q3 (Jul - Sep)", "Q4 Festive (Oct - Dec)")
  total_quarter_sales <- sum(quarters$sales, na.rm = TRUE)
  quarters_list <- lapply(seq_len(nrow(quarters)), function(i) {
    q_num <- as.integer(quarters$Quarter[i])
    q_sales <- as.numeric(quarters$sales[i])
    q_share <- if (total_quarter_sales > 0) round((q_sales / total_quarter_sales) * 100, 1) else 0
    list(
      name = if (!is.na(q_num) && q_num >= 1 && q_num <= 4) quarter_names[q_num] else paste0("Q", q_num),
      val = q_sales,
      share = q_share
    )
  })

  # Real AOV Distribution Tiers
  total_n <- nrow(dt)
  t_micro <- dt[Sales_INR < 500]
  t_core  <- dt[Sales_INR >= 500 & Sales_INR < 2500]
  t_mid   <- dt[Sales_INR >= 2500 & Sales_INR < 7500]
  t_prem  <- dt[Sales_INR >= 7500]
  
  aov_tiers <- list(
    list(name = "Micro (< ₹500)", orders = nrow(t_micro), total = sum(t_micro$Sales_INR, na.rm = TRUE), pct = if(total_n > 0) round((nrow(t_micro)/total_n)*100, 1) else 0),
    list(name = "Core (₹500 - ₹2.5k)", orders = nrow(t_core), total = sum(t_core$Sales_INR, na.rm = TRUE), pct = if(total_n > 0) round((nrow(t_core)/total_n)*100, 1) else 0),
    list(name = "Mid (₹2.5k - ₹7.5k)", orders = nrow(t_mid), total = sum(t_mid$Sales_INR, na.rm = TRUE), pct = if(total_n > 0) round((nrow(t_mid)/total_n)*100, 1) else 0),
    list(name = "Premium (> ₹7.5k)", orders = nrow(t_prem), total = sum(t_prem$Sales_INR, na.rm = TRUE), pct = if(total_n > 0) round((nrow(t_prem)/total_n)*100, 1) else 0)
  )

  # Real Fulfillment / Order Status if present
  status_col <- if ("Order_Status" %in% names(dt)) "Order_Status" else if ("Status" %in% names(dt)) "Status" else NULL
  status_summary <- if (!is.null(status_col)) {
    st_agg <- dt[, .(count = .N, sales = sum(Sales_INR, na.rm = TRUE)), by = status_col][order(-count)]
    lapply(seq_len(nrow(st_agg)), function(i) {
      st_name <- as.character(st_agg[[status_col]][i])
      st_count <- as.numeric(st_agg$count[i])
      st_sales <- as.numeric(st_agg$sales[i])
      st_pct <- if (total_n > 0) round((st_count / total_n) * 100, 1) else 0
      list(title = st_name, count = st_count, pct = st_pct, val = st_sales)
    })
  } else NULL
  
  sales_summary <- list(
    available = TRUE,
    kpi = list(
      total_sales = total_sales,
      total_orders = total_orders,
      has_actual_orders = has_order,
      total_profit = if (has_profit) total_profit else NULL,
      aov = aov,
      profit_margin = if (has_profit) profit_margin else NULL,
      monthly_velocity = monthly_velocity
    ),
    trend_monthly = list(
      dates = as.character(monthly$Month),
      sales = monthly$Sales,
      profit = if (has_profit) monthly$Profit else NULL,
      orders = monthly$Orders
    ),
    quarterly = quarters_list,
    aov_tiers = aov_tiers,
    status_distribution = status_summary
  )
  
  write_json(sales_summary, "output/sales.json", auto_unbox = TRUE)
}
