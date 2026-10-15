# R/generate_analytics_json.R
suppressMessages(library(jsonlite))

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

summary_file     <- "output/summary.json"
sales_file       <- "output/sales.json"
products_file    <- "output/products.json"
customers_file   <- "output/customers.json"
regional_file    <- "output/regional.json"
rfm_file         <- "output/rfm.json"
association_file <- "output/association.json"
forecast_file    <- "output/forecast.json"
universal_file   <- "output/universal.json"

if (!file.exists(summary_file)) stop("summary.json missing")

summary_data <- fromJSON(summary_file, simplifyVector = FALSE)

kpis_list            <- list()
charts_list          <- list()
available_analysis   <- character(0)
unavailable_analysis <- character(0)
limitations_list     <- list()
findings_list        <- list()

is_valid_num <- function(x) {
  if (is.null(x) || length(x) == 0) return(FALSE)
  val <- suppressWarnings(as.numeric(x[[1]]))
  return(length(val) > 0 && !is.na(val))
}

add_kpi <- function(label, value, type = "number") {
  if (!is_valid_num(value)) return()
  kpis_list[[length(kpis_list) + 1]] <<- list(label = label, value = as.numeric(value), type = type)
}

add_kpi_str <- function(label, value, type = "string") {
  if (is.null(value) || length(value) == 0 || is.na(value)) return()
  kpis_list[[length(kpis_list) + 1]] <<- list(label = label, value = as.character(value), type = type)
}

add_chart <- function(id, section, title, subtitle, type, labels, values,
                      dataset_label, unit, extra = list(), available = TRUE) {
  if (is.null(labels) || length(labels) == 0) return()
  if (is.null(values) || length(values) == 0) return()
  entry <- c(
    list(
      id            = id,
      section       = section,
      title         = title,
      subtitle      = subtitle,
      type          = type,
      labels        = as.character(labels),
      values        = as.numeric(values),
      dataset_label = dataset_label,
      unit          = unit,
      available     = available
    ),
    extra
  )
  charts_list[[length(charts_list) + 1]] <<- entry
}

# ── Sales Analysis ────────────────────────────────────────────────────────────
if (file.exists(sales_file)) {
  s_data <- fromJSON(sales_file, simplifyVector = FALSE)
  if (!isFALSE(s_data$available)) {
    available_analysis <- c(available_analysis, "Sales")
    add_kpi("Total Revenue", s_data$kpi$total_sales, "currency")
    add_kpi("Total Orders",  s_data$kpi$total_orders, "number")
    add_kpi("Total Profit",  s_data$kpi$total_profit, "currency")
    if (!is.null(s_data$kpi$aov))
      add_kpi("Avg Order Value", s_data$kpi$aov, "currency")
    if (is_valid_num(s_data$kpi$profit_margin))
      add_kpi_str("Profit Margin", paste0(round(as.numeric(s_data$kpi$profit_margin[[1]]), 1), "%"))

    add_chart("salesTrend",  "Executive Overview", "Revenue Trend",  "Monthly total sales",   "line",
              s_data$trend_monthly$dates, s_data$trend_monthly$sales,  "Revenue", "currency")
    add_chart("ordersTrend", "Executive Overview", "Orders Trend",   "Monthly order volume",  "bar",
              s_data$trend_monthly$dates, s_data$trend_monthly$orders, "Orders",  "number")
    add_chart("profitTrend", "Profitability",      "Profit Trend",   "Monthly profit analysis","line",
              s_data$trend_monthly$dates, s_data$trend_monthly$profit, "Profit",  "currency")
              
    if (is_valid_num(s_data$kpi$total_sales)) {
      orders_count <- if (is_valid_num(s_data$kpi$total_orders)) s_data$kpi$total_orders[[1]] else 0
      findings_list[[length(findings_list) + 1]] <- paste0("Financial Performance: Generated ₹", round(as.numeric(s_data$kpi$total_sales[[1]]) / 1e5, 1), " Lakhs in gross revenue across ", orders_count, " transactions.")
    }
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Sales")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Sales Analysis",
      reason = s_data$reason %||% "Requires valid Date and Sales/Revenue fields."
    )
  }
}

# ── Product Analysis ──────────────────────────────────────────────────────────
if (file.exists(products_file)) {
  p_data <- fromJSON(products_file, simplifyVector = FALSE)
  if (!isFALSE(p_data$available)) {
    available_analysis <- c(available_analysis, "Product")
    if (!is.null(p_data$category_sales)) {
      add_chart("categorySales", "Sales Analysis", "Category Sales", "Revenue by product category",
                "bar", p_data$category_sales$categories, p_data$category_sales$sales, "Revenue", "currency")
      if (length(p_data$category_sales$categories) > 0) {
        findings_list[[length(findings_list) + 1]] <- paste0("Top Category: '", p_data$category_sales$categories[1], "' generated highest sales.")
      }
    }
    if (!is.null(p_data$top_products)) {
      add_chart("topProducts", "Product Analysis", "Top Products", "Highest revenue generating products",
                "bar", p_data$top_products$names, p_data$top_products$sales, "Revenue", "currency")
    }
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Product")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Product Analysis",
      reason = p_data$reason %||% "Requires product or category attribute."
    )
  }
}

# ── Regional Analysis ─────────────────────────────────────────────────────────
if (file.exists(regional_file)) {
  r_data <- fromJSON(regional_file, simplifyVector = FALSE)
  if (!isFALSE(r_data$available)) {
    available_analysis <- c(available_analysis, "Regional")
    if (!is.null(r_data$regions))
      add_chart("regionalSales", "Geographic Analysis", "Regional Sales", "Revenue distribution across regions",
                "doughnut", r_data$regions$labels, r_data$regions$sales, "Revenue", "currency")
    if (!is.null(r_data$top_states))
      add_chart("stateSales", "Geographic Analysis", "Top States", "Highest revenue generating states",
                "bar", r_data$top_states$labels, r_data$top_states$sales, "Revenue", "currency")
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Regional")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Regional Analysis",
      reason = r_data$reason %||% "Requires Region, State, or Location field."
    )
  }
}

# ── Customer Analysis ─────────────────────────────────────────────────────────
if (file.exists(customers_file)) {
  cust_data <- fromJSON(customers_file, simplifyVector = FALSE)
  if (!isFALSE(cust_data$available)) {
    available_analysis <- c(available_analysis, "Customer")
    add_kpi("Avg Spend / Customer", cust_data$kpi$avg_spend_per_customer, "currency")
    if (is_valid_num(cust_data$kpi$repeat_rate))
      add_kpi_str("Repeat Rate", paste0(cust_data$kpi$repeat_rate[[1]], "%"))
    if (!is.null(cust_data$payment))
      add_chart("paymentMethod", "Sales Analysis", "Payment Method", "Customer payment preferences",
                "pie", cust_data$payment$methods, cust_data$payment$sales, "Revenue", "currency")
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Customer")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Customer Analysis",
      reason = cust_data$reason %||% "Requires Customer ID or Payment channel field."
    )
  }
}

# ── RFM Segmentation ──────────────────────────────────────────────────────────
if (file.exists(rfm_file)) {
  rfm_data <- fromJSON(rfm_file, simplifyVector = FALSE)
  if (!isFALSE(rfm_data$available)) {
    available_analysis <- c(available_analysis, "RFM")
    if (!is.null(rfm_data$segments)) {
      seg_counts <- as.numeric(unlist(rfm_data$segments$counts))
      add_kpi("Total Customers (RFM)", sum(seg_counts), "number")
      add_chart("rfmSegments", "Customer Analysis", "Customer Segments (RFM)",
                "Recency, Frequency, Monetary segmentation",
                "doughnut", rfm_data$segments$labels, seg_counts, "Customers", "number")
    }
  } else {
    unavailable_analysis <- c(unavailable_analysis, "RFM")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "RFM Segmentation",
      reason = rfm_data$reason %||% "Requires Customer ID, Date, and Sales fields."
    )
  }
}

# ── Forecasting ───────────────────────────────────────────────────────────────
if (file.exists(forecast_file)) {
  f_data <- fromJSON(forecast_file, simplifyVector = FALSE)
  if (!isFALSE(f_data$available) && !is.null(f_data$forecast)) {
    available_analysis <- c(available_analysis, "Forecasting")
    hist_dates <- as.character(unlist(f_data$historical$dates))
    fore_dates <- as.character(unlist(f_data$forecast$dates))
    hist_sales <- as.numeric(unlist(f_data$historical$sales))
    fore_vals  <- as.numeric(unlist(f_data$forecast$values))
    fore_lower <- as.numeric(unlist(f_data$forecast$lower))
    fore_upper <- as.numeric(unlist(f_data$forecast$upper))

    charts_list[[length(charts_list) + 1]] <- list(
      id            = "salesForecast",
      section       = "Advanced Analytics",
      title         = "Sales Forecast",
      subtitle      = "Historical and Projected Revenue",
      type          = "forecast",
      labels        = c(hist_dates, fore_dates),
      values        = c(hist_sales, fore_vals),
      historical    = hist_sales,
      forecast      = fore_vals,
      lower         = fore_lower,
      upper         = fore_upper,
      dataset_label = "Forecast",
      unit          = "currency",
      available     = TRUE
    )
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Forecasting")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Time Series Forecasting",
      reason = f_data$reason %||% "Requires at least 12 months of completed chronological observations."
    )
  }
}

# ── Association Rules (Apriori) ───────────────────────────────────────────────
if (file.exists(association_file)) {
  a_data <- fromJSON(association_file, simplifyVector = FALSE)
  if (!isFALSE(a_data$available) && !is.null(a_data$rules)) {
    available_analysis <- c(available_analysis, "Association Rules")
    add_chart("assocRules", "Advanced Analytics", "Association Rules (Lift)",
              "Top product purchase associations",
              "bar", unlist(a_data$rules), as.numeric(unlist(a_data$lift)), "Lift", "number")
  } else {
    unavailable_analysis <- c(unavailable_analysis, "Association Rules")
    limitations_list[[length(limitations_list) + 1]] <- list(
      module = "Association Rules (Apriori)",
      reason = a_data$reason %||% "Requires transaction/order baskets with multiple products."
    )
  }
}

# ── Universal Data Profiling ──────────────────────────────────────────────────
if (file.exists(universal_file)) {
  u_data <- fromJSON(universal_file, simplifyVector = FALSE)
  if (!isFALSE(u_data$available)) {
    available_analysis <- c(available_analysis, "Data Profiling")

    for (univ_kpi in u_data$kpis) {
      if (!is.null(univ_kpi$label) && !is.null(univ_kpi$value)) {
        kpis_list[[length(kpis_list) + 1]] <- list(
          label = as.character(univ_kpi$label),
          value = univ_kpi$value,
          type  = as.character(univ_kpi$type %||% "number")
        )
      }
    }

    for (univ_chart in u_data$charts) {
      if (!is.null(univ_chart$id) && !is.null(univ_chart$labels) && !is.null(univ_chart$values)) {
        charts_list[[length(charts_list) + 1]] <- list(
          id            = as.character(univ_chart$id),
          section       = as.character(univ_chart$section %||% "Data Profiling"),
          title         = as.character(univ_chart$title),
          subtitle      = as.character(univ_chart$subtitle %||% ""),
          type          = as.character(univ_chart$type %||% "bar"),
          labels        = as.character(unlist(univ_chart$labels)),
          values        = as.numeric(unlist(univ_chart$values)),
          dataset_label = as.character(univ_chart$dataset_label %||% "Count"),
          unit          = as.character(univ_chart$unit %||% "number"),
          available     = TRUE
        )
      }
    }

    if (!is.null(u_data$key_findings)) {
      for (f in u_data$key_findings) {
        findings_list[[length(findings_list) + 1]] <- as.character(f)
      }
    }
  }
}

# ── Profile Fields ────────────────────────────────────────────────────────────
detected_fields <- character(0)
q <- summary_data$quality
if (isTRUE(q$detected_date))      detected_fields <- c(detected_fields, "Date")
if (isTRUE(q$detected_sales))     detected_fields <- c(detected_fields, "Sales")
if (isTRUE(q$detected_profit))    detected_fields <- c(detected_fields, "Profit")
if (isTRUE(q$detected_customer))  detected_fields <- c(detected_fields, "Customer")
if (isTRUE(q$detected_product))   detected_fields <- c(detected_fields, "Product")
if (isTRUE(q$detected_order))     detected_fields <- c(detected_fields, "Order ID")
if (isTRUE(q$detected_region))    detected_fields <- c(detected_fields, "Region")
if (isTRUE(q$detected_inventory)) detected_fields <- c(detected_fields, "Inventory")
if (isTRUE(q$detected_payment))   detected_fields <- c(detected_fields, "Payment")

derived_fields <- character(0)
if (isTRUE(q$derived_sales))  derived_fields <- c(derived_fields, "Sales = Price x Quantity")
if (isTRUE(q$derived_profit)) derived_fields <- c(derived_fields, "Profit = Sales - Cost")

ds_identity <- list(
  name           = summary_data$dataset_name %||% "Active Dataset",
  filename       = summary_data$dataset_file %||% "dataset.csv",
  selected_sheet = summary_data$selected_sheet,
  rows           = summary_data$final_rows,
  initial_rows   = summary_data$initial_rows,
  columns_count  = summary_data$columns_count %||% 0,
  duplicate_rows = summary_data$duplicate_rows %||% 0,
  missing_cells  = summary_data$missing_cells %||% 0,
  date_range     = summary_data$date_range %||% "N/A"
)

sales_details <- if (file.exists(sales_file) && exists("s_data") && !isFALSE(s_data$available)) {
  list(
    quarterly = s_data$quarterly,
    aov_tiers = s_data$aov_tiers,
    status_distribution = s_data$status_distribution,
    monthly_velocity = s_data$kpi$monthly_velocity
  )
} else NULL

# ── Final analytics.json Construction ─────────────────────────────────────────
analytics <- list(
  status       = "success",
  dataset      = ds_identity,
  profile      = list(
    detected_fields = detected_fields,
    derived_fields  = derived_fields,
    col_mapping     = q$col_mapping
  ),
  capabilities = list(
    available_analysis   = available_analysis,
    unavailable_analysis = unavailable_analysis
  ),
  available_analysis   = available_analysis,
  unavailable_analysis = unavailable_analysis,
  findings             = findings_list,
  limitations          = limitations_list,
  kpis                 = kpis_list,
  charts               = charts_list,
  sales_details        = sales_details
)

sanitize_rec <- function(x) {
  if (is.list(x)) return(lapply(x, sanitize_rec))
  if (is.numeric(x)) {
    x[is.nan(x) | is.infinite(x)] <- 0
    return(x)
  }
  return(x)
}
analytics <- sanitize_rec(analytics)

# Atomic file write
tmp_path   <- "output/analytics.json.tmp"
final_path <- "output/analytics.json"
write_json(analytics, tmp_path, auto_unbox = TRUE, pretty = FALSE, na = "null")
if (file.exists(final_path)) file.remove(final_path)
file.rename(tmp_path, final_path)
cat("Generated dynamic analytics.json successfully (atomic write).\n")
