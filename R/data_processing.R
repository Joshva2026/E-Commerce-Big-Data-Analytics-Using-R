# R/data_processing.R
suppressMessages(library(data.table))
suppressMessages(library(lubridate))
suppressMessages(library(jsonlite))

clean_numeric_vector <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.null(x)) return(numeric(0))
  cleaned <- gsub("[^0-9\\.-]", "", as.character(x))
  suppressWarnings(as.numeric(cleaned))
}

process_data <- function(filepath, original_name = NULL) {
  cat("Loading data from:", filepath, "\n")
  
  if (!file.exists(filepath)) {
    stop("Validation Error: File does not exist at specified path.")
  }
  
  file_size <- file.info(filepath)$size
  if (is.na(file_size) || file_size == 0) {
    stop("Validation Error: Uploaded file is 0 bytes (empty).")
  }
  
  ext <- tolower(tools::file_ext(filepath))
  selected_sheet <- NULL
  
  if (ext == "csv") {
    dt <- tryCatch({
      fread(filepath, encoding = "UTF-8", fill = TRUE, strip.white = TRUE)
    }, error = function(e) {
      tryCatch({
        as.data.table(read.csv(filepath, check.names = FALSE, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE))
      }, error = function(e2) {
        as.data.table(read.csv(filepath, check.names = FALSE, stringsAsFactors = FALSE))
      })
    })
  } else if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      cat("Installing readxl package...\n")
      install.packages("readxl", repos = "https://cloud.r-project.org")
    }
    sheets <- readxl::excel_sheets(filepath)
    if (length(sheets) == 0) {
      stop("Validation Error: Excel file contains no worksheets.")
    }
    selected_sheet <- sheets[1]
    
    # Multi-sheet detection: evaluate worksheets and select the one with maximum data cells
    if (length(sheets) > 1) {
      best_sheet <- sheets[1]
      max_cells <- -1
      for (sh in sheets) {
        sheet_df <- tryCatch(as.data.frame(readxl::read_excel(filepath, sheet = sh)), error = function(e) NULL)
        if (!is.null(sheet_df)) {
          cells <- nrow(sheet_df) * ncol(sheet_df)
          if (cells > max_cells) {
            max_cells <- cells
            best_sheet <- sh
          }
        }
      }
      selected_sheet <- best_sheet
      cat("Selected Excel worksheet with highest data volume:", selected_sheet, "\n")
    }
    dt <- as.data.table(readxl::read_excel(filepath, sheet = selected_sheet))
  } else {
    stop("Validation Error: Unsupported file format. Please upload CSV or XLSX/XLS.")
  }
  
  initial_rows <- nrow(dt)
  initial_cols <- ncol(dt)
  
  if (initial_rows == 0 || initial_cols == 0) {
    stop("Validation Error: Dataset contains 0 rows or 0 columns.")
  }
  
  # Remove trailing/completely empty columns (e.g. CSV trailing commas with 100% NAs and blank names)
  empty_col_idx <- which(sapply(dt, function(col) all(is.na(col))) & grepl("^(V\\d+|\\.\\.\\.\\d+|)$", names(dt)))
  if (length(empty_col_idx) > 0) {
    dt[, (empty_col_idx) := NULL]
  }
  
  # Calculate quality telemetry
  duplicate_rows_count <- sum(duplicated(dt))
  total_missing_cells  <- sum(sapply(dt, function(col) sum(is.na(col))))
  
  # Normalize column names for robust semantic detection
  orig_names <- names(dt)
  norm_names <- tolower(trimws(orig_names))
  norm_names <- gsub("[\\s\\.-]+", "_", norm_names, perl = TRUE)
  
  detect_col <- function(aliases) {
    m <- orig_names[norm_names %in% aliases]
    if (length(m) > 0) m[1] else NULL
  }
  
  # Semantic Detection with Priority Hierarchy
  col_order_date <- detect_col(c("order_date", "date", "orderdate", "transaction_date", "purchase_date", "invoice_date", "created_date", "timestamp", "created_at"))
  
  exact_sales_aliases <- c("sales_inr", "sales", "sales_amount", "net_sales", "total_sales", "gmv")
  fuzzy_sales_aliases <- c("revenue", "revenue_inr", "total_amount", "order_amount", "order_value", "amount")
  
  sales_exact <- orig_names[norm_names %in% exact_sales_aliases]
  sales_candidates <- if (length(sales_exact) > 0) sales_exact else orig_names[norm_names %in% fuzzy_sales_aliases]
  col_sales <- if (length(sales_candidates) > 0) sales_candidates[1] else NULL
  
  col_price     <- detect_col(c("unit_price", "price", "selling_price", "product_price", "unitprice", "mrp"))
  col_quantity  <- detect_col(c("quantity", "qty", "units_sold", "units", "items_count", "order_quantity", "num_items"))
  col_profit    <- detect_col(c("profit_inr", "profit", "net_profit", "gross_profit", "margin", "earnings"))
  col_cost      <- detect_col(c("cost", "unit_cost", "cogs", "total_cost", "expense", "expenses"))
  col_order     <- detect_col(c("order_id", "transaction_id", "invoice_id", "orderid", "trans_id", "bill_no", "invoice_no"))
  col_product   <- detect_col(c("product_name", "product", "product_id", "sku", "item", "item_name", "product_title", "title"))
  col_category  <- detect_col(c("category", "department", "product_type", "product_category", "dept"))
  col_customer  <- detect_col(c("customer_id", "customer", "buyer_id", "user_id", "client_id", "customer_name", "customerid"))
  col_region    <- detect_col(c("region", "city", "state", "country", "location", "zone"))
  col_inventory <- detect_col(c("stock", "inventory", "stock_quantity", "available_stock", "on_hand", "quantity_in_stock"))
  col_channel   <- detect_col(c("marketplace", "platform", "channel", "seller", "payment_method", "payment_mode"))
  
  # Rename canonical columns in place
  if (!is.null(col_order_date)) setnames(dt, col_order_date, "Order_Date")
  if (!is.null(col_sales))      setnames(dt, col_sales, "Sales_INR")
  if (!is.null(col_profit))     setnames(dt, col_profit, "Profit_INR")
  if (!is.null(col_product))    setnames(dt, col_product, "Product_Name")
  if (!is.null(col_category))   setnames(dt, col_category, "Category")
  if (!is.null(col_customer))   setnames(dt, col_customer, "Customer_ID")
  if (!is.null(col_region))     setnames(dt, col_region, "Region")
  if (!is.null(col_quantity))   setnames(dt, col_quantity, "Quantity")
  if (!is.null(col_inventory))  setnames(dt, col_inventory, "Stock_Quantity")
  if (!is.null(col_channel))    setnames(dt, col_channel, "Payment_Method")
  if (!is.null(col_order))      setnames(dt, col_order, "Order_ID")
  
  # Normalization helper for dates
  normalize_date_column <- function(x) {
    if (inherits(x, "Date") || inherits(x, "POSIXt")) return(as.Date(x))
    if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
    if (is.character(x)) {
      parsed <- suppressWarnings(parse_date_time(x, orders = c("Ymd", "Ymd HMS", "dmy", "mdy", "dmY", "mdY", "Y-m-d", "d/m/Y", "m/d/Y"), quiet = TRUE))
      return(as.Date(parsed))
    }
    return(as.Date(rep(NA, length(x))))
  }
  
  # Metric Derivations
  flag_derived_sales  <- FALSE
  flag_derived_profit <- FALSE
  
  # 1. Derive Sales if missing, but Unit Price & Quantity exist
  if (!"Sales_INR" %in% names(dt)) {
    price_col_name <- if (!is.null(col_price) && col_price %in% names(dt)) col_price else NULL
    if (!is.null(price_col_name) && "Quantity" %in% names(dt)) {
      dt[[price_col_name]] <- clean_numeric_vector(dt[[price_col_name]])
      dt[["Quantity"]]     <- clean_numeric_vector(dt[["Quantity"]])
      dt[, Sales_INR := get(price_col_name) * Quantity]
      col_sales <- "Sales_INR"
      flag_derived_sales <- TRUE
      cat("Derived Sales mathematically from Unit Price * Quantity\n")
    }
  }
  
  # 2. Derive Profit if missing, but Sales & Cost exist
  if (!"Profit_INR" %in% names(dt) && "Sales_INR" %in% names(dt)) {
    cost_col_name <- if (!is.null(col_cost) && col_cost %in% names(dt)) col_cost else NULL
    if (!is.null(cost_col_name)) {
      dt[[cost_col_name]] <- clean_numeric_vector(dt[[cost_col_name]])
      dt[, Sales_INR := clean_numeric_vector(Sales_INR)]
      dt[, Profit_INR := Sales_INR - get(cost_col_name)]
      col_profit <- "Profit_INR"
      flag_derived_profit <- TRUE
      cat("Derived Profit mathematically from Sales - Cost\n")
    }
  }
  
  # Normalize and validate Order_Date if present
  invalid_dates_count <- 0
  if ("Order_Date" %in% names(dt)) {
    parsed_dates <- normalize_date_column(dt$Order_Date)
    invalid_dates_count <- sum(is.na(parsed_dates) & !is.na(dt$Order_Date))
    dt$Order_Date <- parsed_dates
  }
  
  # Clean numeric formatting for Sales_INR if present
  invalid_sales_count <- 0
  if ("Sales_INR" %in% names(dt)) {
    dt$Sales_INR <- clean_numeric_vector(dt$Sales_INR)
    invalid_sales_count <- sum(is.na(dt$Sales_INR))
    # If all values failed to parse as numeric, drop false mapping
    if (invalid_sales_count == nrow(dt)) {
      cat("Warning: Detected Sales column could not be parsed as numeric. Dropping sales mapping.\n")
      dt[, Sales_INR := NULL]
      col_sales <- NULL
    }
  }
  
  if ("Profit_INR" %in% names(dt)) {
    dt$Profit_INR <- clean_numeric_vector(dt$Profit_INR)
  }
  if ("Quantity" %in% names(dt)) {
    dt$Quantity <- clean_numeric_vector(dt$Quantity)
  }
  if ("Stock_Quantity" %in% names(dt)) {
    dt$Stock_Quantity <- clean_numeric_vector(dt$Stock_Quantity)
  }
  
  final_rows <- nrow(dt)
  final_cols <- ncol(dt)
  
  date_range_str <- if ("Order_Date" %in% names(dt) && sum(!is.na(dt$Order_Date)) > 0) {
    paste(min(dt$Order_Date, na.rm = TRUE), "to", max(dt$Order_Date, na.rm = TRUE))
  } else {
    "N/A (Temporal attribute unmapped)"
  }
  
  summary <- list(
    dataset_name = if (!is.null(original_name)) original_name else basename(filepath),
    dataset_file = basename(filepath),
    selected_sheet = selected_sheet,
    initial_rows = initial_rows,
    final_rows = final_rows,
    columns_count = final_cols,
    duplicate_rows = duplicate_rows_count,
    missing_cells = total_missing_cells,
    date_range = date_range_str,
    quality = list(
      detected_date      = "Order_Date" %in% names(dt) && sum(!is.na(dt$Order_Date)) > 0,
      detected_sales     = "Sales_INR" %in% names(dt) && sum(!is.na(dt$Sales_INR)) > 0,
      detected_profit    = "Profit_INR" %in% names(dt) && sum(!is.na(dt$Profit_INR)) > 0,
      detected_customer  = "Customer_ID" %in% names(dt),
      detected_product   = "Product_Name" %in% names(dt) || "Category" %in% names(dt),
      detected_order     = "Order_ID" %in% names(dt),
      detected_region    = "Region" %in% names(dt),
      detected_inventory = "Stock_Quantity" %in% names(dt),
      detected_payment   = "Payment_Method" %in% names(dt),
      invalid_dates      = invalid_dates_count,
      missing_sales      = invalid_sales_count,
      derived_sales      = flag_derived_sales,
      derived_profit     = flag_derived_profit,
      col_mapping        = list(
        Date      = if("Order_Date" %in% names(dt)) (if(!is.null(col_order_date)) col_order_date else "Order_Date") else "Not detected",
        Sales     = if("Sales_INR" %in% names(dt)) (if(!is.null(col_sales)) col_sales else "Derived (Price * Qty)") else "Not detected",
        Profit    = if("Profit_INR" %in% names(dt)) (if(!is.null(col_profit)) col_profit else "Derived (Sales - Cost)") else "Not detected",
        Customer  = if("Customer_ID" %in% names(dt)) (if(!is.null(col_customer)) col_customer else "Customer_ID") else "Not detected",
        Product   = if("Product_Name" %in% names(dt)) (if(!is.null(col_product)) col_product else "Product_Name") else (if("Category" %in% names(dt)) (if(!is.null(col_category)) col_category else "Category") else "Not detected"),
        Order     = if("Order_ID" %in% names(dt)) (if(!is.null(col_order)) col_order else "Order_ID") else "Not detected",
        Region    = if("Region" %in% names(dt)) (if(!is.null(col_region)) col_region else "Region") else "Not detected",
        Inventory = if("Stock_Quantity" %in% names(dt)) (if(!is.null(col_inventory)) col_inventory else "Stock_Quantity") else "Not detected",
        Payment   = if("Payment_Method" %in% names(dt)) (if(!is.null(col_channel)) col_channel else "Payment_Method") else "Not detected"
      )
    )
  )
  
  write_json(summary, "output/summary.json", auto_unbox = TRUE)
  return(dt)
}
