# rfm_analysis.R
run_rfm_analysis <- function(dt) {
  cat("Running RFM analysis...\n")
  
  if (!"Sales_INR" %in% names(dt) || !"Order_Date" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "RFM analysis requires Sales and Date fields."), "output/rfm.json", auto_unbox = TRUE)
    return()
  }
  
  has_cust_id <- "Customer_ID" %in% names(dt)
  has_cust_name <- "Customer_Name" %in% names(dt)
  cust_col <- if (has_cust_id) "Customer_ID" else if (has_cust_name) "Customer_Name" else NULL
  
  if (is.null(cust_col)) {
    write_json(list(available = FALSE, reason = "RFM analysis requires Customer_ID or Customer_Name."), "output/rfm.json", auto_unbox = TRUE)
    return()
  }
  
  has_order <- "Order_ID" %in% names(dt)
  
  ref_date <- max(dt$Order_Date, na.rm = TRUE)
  
  rfm <- dt[, .(
    Recency = as.numeric(difftime(as.Date(ref_date), max(as.Date(Order_Date), na.rm=TRUE), units = "days")),
    Frequency = if (has_order) uniqueN(Order_ID) else .N,
    Monetary = sum(Sales_INR, na.rm = TRUE)
  ), by = c(cust_col)]
  
  r_ecdf <- ecdf(rfm$Recency)
  rfm[, R_Score := 6 - ceiling(r_ecdf(Recency) * 5)]
  rfm[R_Score == 6, R_Score := 5] 
  
  f_ecdf <- ecdf(rfm$Frequency)
  rfm[, F_Score := ceiling(f_ecdf(Frequency) * 5)]
  rfm[F_Score == 0, F_Score := 1]
  
  m_ecdf <- ecdf(rfm$Monetary)
  rfm[, M_Score := ceiling(m_ecdf(Monetary) * 5)]
  rfm[M_Score == 0, M_Score := 1]
  
  rfm[, Segment := "Other"]
  rfm[R_Score >= 4 & F_Score >= 4 & M_Score >= 4, Segment := "Champions"]
  rfm[R_Score >= 3 & F_Score >= 3 & M_Score >= 3 & Segment == "Other", Segment := "Loyal Customers"]
  rfm[R_Score >= 3 & F_Score <= 3 & Segment == "Other", Segment := "Potential Loyalists"]
  rfm[R_Score >= 4 & F_Score <= 2 & Segment == "Other", Segment := "New Customers"]
  rfm[R_Score <= 2 & F_Score >= 3 & Segment == "Other", Segment := "At Risk"]
  rfm[R_Score <= 2 & F_Score <= 2 & Segment == "Other", Segment := "Lost Customers"]
  
  seg_counts <- rfm[, .N, by = Segment][order(-N)]
  
  rfm_summary <- list(
    available = TRUE,
    segments = list(
      labels = seg_counts$Segment,
      counts = seg_counts$N
    )
  )
  
  write_json(rfm_summary, "output/rfm.json", auto_unbox = TRUE)
}
