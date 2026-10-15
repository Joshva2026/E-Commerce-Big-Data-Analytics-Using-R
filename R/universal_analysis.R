# R/universal_analysis.R
suppressMessages(library(data.table))
suppressMessages(library(jsonlite))
suppressMessages(library(lubridate))

run_universal_analysis <- function(dt) {
  cat("Running universal statistical analysis & data profiling...\n")
  
  num_cols  <- names(dt)[sapply(dt, is.numeric)]
  char_cols <- names(dt)[sapply(dt, function(x) is.character(x) || is.factor(x))]
  
  univ_charts  <- list()
  univ_kpis    <- list()
  key_findings <- list()
  
  # Basic Telemetry KPIs
  univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Total Records", value = nrow(dt), type = "number")
  univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Total Columns", value = ncol(dt), type = "number")
  
  total_missing <- sum(sapply(dt, function(col) sum(is.na(col))))
  univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Missing Values", value = total_missing, type = "number")
  
  dup_rows <- sum(duplicated(dt))
  univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Duplicate Rows", value = dup_rows, type = "number")
  
  # Finding: Data Quality
  if (total_missing == 0) {
    key_findings[[length(key_findings) + 1]] <- "Data Quality: Zero missing cells detected across all attributes."
  } else {
    missing_pct <- round((total_missing / (nrow(dt) * ncol(dt))) * 100, 2)
    key_findings[[length(key_findings) + 1]] <- paste0("Data Quality: Identified ", total_missing, " missing cells (", missing_pct, "% of total dataset volume).")
  }
  
  # Categorical frequency distributions
  for (col in head(char_cols, 6)) {
    vals <- na.omit(dt[[col]])
    n_unique <- length(unique(vals))
    if (n_unique < 2 || n_unique > min(100, nrow(dt) * 0.95)) next
    
    freq <- as.data.frame(table(vals), stringsAsFactors = FALSE)
    names(freq) <- c("label", "count")
    freq <- freq[order(-freq$count), ]
    top_n <- head(freq, 10)
    
    univ_charts[[length(univ_charts) + 1]] <- list(
      id            = paste0("univ_char_", gsub("[^A-Za-z0-9]", "", col)),
      section       = "Data Profiling",
      title         = paste("Frequency of", col),
      subtitle      = "Top categories by record volume",
      type          = "bar",
      labels        = as.character(top_n$label),
      values        = as.numeric(top_n$count),
      dataset_label = "Count",
      unit          = "number",
      available     = TRUE
    )
    
    if (length(key_findings) < 5 && nrow(top_n) > 0) {
      top_pct <- round((top_n$count[1] / length(vals)) * 100, 1)
      key_findings[[length(key_findings) + 1]] <- paste0("Dominant ", col, ": '", top_n$label[1], "' accounts for ", top_pct, "% of categorical entries.")
    }
  }
  
  # Numerical distribution histograms
  for (col in head(num_cols, 6)) {
    raw_vals <- na.omit(dt[[col]])
    if (length(raw_vals) < 5 || length(unique(raw_vals)) < 3) next
    
    brks <- pretty(raw_vals, n = 10)
    h    <- hist(raw_vals, breaks = brks, plot = FALSE)
    
    univ_charts[[length(univ_charts) + 1]] <- list(
      id            = paste0("univ_num_", gsub("[^A-Za-z0-9]", "", col)),
      section       = "Data Profiling",
      title         = paste("Distribution of", col),
      subtitle      = "Value distribution histogram",
      type          = "bar",
      labels        = as.character(h$mids),
      values        = as.numeric(h$counts),
      dataset_label = "Frequency",
      unit          = "number",
      available     = TRUE
    )
    
    univ_kpis[[length(univ_kpis) + 1]] <- list(
      label = paste("Avg", col),
      value = round(mean(raw_vals, na.rm = TRUE), 2),
      type  = "number"
    )
  }
  
  # Inventory Analysis if Stock_Quantity is present
  if ("Stock_Quantity" %in% names(dt)) {
    stock_vals <- na.omit(dt$Stock_Quantity)
    total_stock <- sum(stock_vals, na.rm = TRUE)
    low_stock_count <- sum(stock_vals < 10, na.rm = TRUE)
    
    univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Total Inventory Units", value = total_stock, type = "number")
    univ_kpis[[length(univ_kpis) + 1]] <- list(label = "Low-Stock SKUs (<10)", value = low_stock_count, type = "number")
    
    key_findings[[length(key_findings) + 1]] <- paste0("Inventory Status: ", low_stock_count, " SKUs flagged below replenishment threshold (<10 units).")
    
    if ("Product_Name" %in% names(dt) || "Category" %in% names(dt)) {
      grp_col <- if ("Category" %in% names(dt)) "Category" else "Product_Name"
      stock_by_grp <- dt[, .(Stock = sum(Stock_Quantity, na.rm = TRUE)), by = grp_col][order(-Stock)]
      top_stock <- head(stock_by_grp, 10)
      
      univ_charts[[length(univ_charts) + 1]] <- list(
        id            = "inventoryDistribution",
        section       = "Inventory Intelligence",
        title         = paste("Inventory Levels by", grp_col),
        subtitle      = "On-hand stock distribution across catalog",
        type          = "bar",
        labels        = as.character(top_stock[[grp_col]]),
        values        = as.numeric(top_stock$Stock),
        dataset_label = "Units on Hand",
        unit          = "number",
        available     = TRUE
      )
    }
  }
  
  # Temporal Trend if Date and numeric columns exist
  if ("Order_Date" %in% names(dt)) {
    for (col in head(num_cols, 2)) {
      if (col == "Sales_INR") next
      trend <- dt[, .(MetricSum = sum(get(col), na.rm = TRUE)), by = .(Month = floor_date(Order_Date, "month"))][order(Month)]
      if (nrow(trend) >= 2) {
        univ_charts[[length(univ_charts) + 1]] <- list(
          id            = paste0("univ_trend_", gsub("[^A-Za-z0-9]", "", col)),
          section       = "Data Profiling",
          title         = paste("Monthly Trend of", col),
          subtitle      = "Temporal aggregation by month",
          type          = "line",
          labels        = as.character(trend$Month),
          values        = as.numeric(trend$MetricSum),
          dataset_label = col,
          unit          = "number",
          available     = TRUE
        )
      }
    }
  }
  
  out <- list(
    available    = TRUE,
    charts       = univ_charts,
    kpis         = univ_kpis,
    key_findings = key_findings
  )
  
  write_json(out, "output/universal.json", auto_unbox = TRUE)
  cat("Universal data profiling completed successfully.\n")
}
