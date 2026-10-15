# R/association_rules.R
# Association Rule Mining Engine (Dual-Mode: arules & Native Vectorized Apriori Fallback)

suppressMessages(library(data.table))
suppressMessages(library(jsonlite))

# Gracefully detect arules without crashing if package is not pre-installed
has_arules <- suppressWarnings(requireNamespace("arules", quietly = TRUE))

# High-performance native association rule mining engine using pure base R / data.table
# Guarantees association rules analytics work in any environment without external C++ package dependencies
compute_native_rules <- function(trans_dt, min_supp = 0.0001, min_conf = 0.01) {
  T_total <- uniqueN(trans_dt$basket_id)
  if (T_total < 10) return(NULL)
  
  # Single item frequency and individual support
  item_counts <- trans_dt[, .(item_n = .N), by = .(Item = Product_Name)]
  item_counts[, supp := item_n / T_total]
  
  # Pair co-occurrences (cartesian product of distinct items within the same transaction)
  pairs <- merge(
    trans_dt[, .(basket_id, Item1 = Product_Name)],
    trans_dt[, .(basket_id, Item2 = Product_Name)],
    by = "basket_id",
    allow.cartesian = TRUE
  )[Item1 != Item2]
  
  if (nrow(pairs) == 0) return(NULL)
  
  pair_counts <- pairs[, .(pair_n = .N), by = .(Item1, Item2)]
  pair_counts[, support := pair_n / T_total]
  pair_counts <- pair_counts[support >= min_supp]
  if (nrow(pair_counts) == 0) return(NULL)
  
  # Merge item supports to calculate confidence: P(Item2 | Item1) = P(Item1 & Item2) / P(Item1)
  pair_counts <- merge(pair_counts, item_counts[, .(Item, supp_1 = supp)], by.x = "Item1", by.y = "Item", all.x = TRUE)
  pair_counts <- merge(pair_counts, item_counts[, .(Item, supp_2 = supp)], by.x = "Item2", by.y = "Item", all.x = TRUE)
  
  pair_counts[, confidence := round(support / supp_1, 4)]
  pair_counts <- pair_counts[confidence >= min_conf]
  if (nrow(pair_counts) == 0) return(NULL)
  
  # Lift: P(Item1 & Item2) / (P(Item1) * P(Item2))
  pair_counts[, lift := round(confidence / supp_2, 4)]
  pair_counts <- pair_counts[order(-lift, -confidence, -support)]
  pair_counts[, rules := sprintf("{%s} => {%s}", Item1, Item2)]
  pair_counts[, support := round(support, 4)]
  
  return(pair_counts[1:min(20, .N)])
}

run_association_rules <- function(dt) {
  cat("Running association rule mining...\n")
  
  if (!"Product_Name" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Association rules require a product field."), "output/association.json", auto_unbox = TRUE)
    return()
  }
  
  if (!"Order_ID" %in% names(dt) && !"Customer_ID" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Association rules require a transaction/order ID field."), "output/association.json", auto_unbox = TRUE)
    return()
  }
  
  has_order <- "Order_ID" %in% names(dt)
  trans_data <- NULL
  rules_summary <- NULL
  
  # ── Primary Attempt: arules package (if available) ──────────────────────────
  if (has_arules) {
    tryCatch({
      suppressMessages(library(arules))
      rules <- list()
      
      if (has_order) {
        t_data <- unique(dt[!is.na(Product_Name) & Product_Name != "", .(Order_ID, Product_Name)])
        order_counts <- t_data[, .N, by = Order_ID]
        valid_orders <- order_counts[N > 1, Order_ID]
        
        if (length(valid_orders) >= 10) {
          t_data <- t_data[Order_ID %in% valid_orders]
          trans_list <- split(t_data$Product_Name, t_data$Order_ID)
          trans <- as(trans_list, "transactions")
          rules <- apriori(trans, parameter = list(supp = 0.0001, conf = 0.01, minlen = 2, maxlen = 3, target = "rules"), 
                           control = list(verbose = FALSE))
        }
      }
      
      if (length(rules) == 0 && "Customer_ID" %in% names(dt)) {
        t_data <- unique(dt[!is.na(Product_Name) & Product_Name != "", .(Customer_ID, Product_Name)])
        cust_counts <- t_data[, .N, by = Customer_ID]
        valid_custs <- cust_counts[N > 1, Customer_ID]
        if (length(valid_custs) >= 10) {
          t_data <- t_data[Customer_ID %in% valid_custs]
          trans_list <- split(t_data$Product_Name, t_data$Customer_ID)
          trans <- as(trans_list, "transactions")
          rules <- apriori(trans, parameter = list(supp = 0.001, conf = 0.01, minlen = 2, maxlen = 3, target = "rules"), 
                           control = list(verbose = FALSE))
        }
      }
      
      if (length(rules) > 0) {
        rules_dt <- as(rules, "data.frame")
        setDT(rules_dt)
        rules_dt[, rules := as.character(rules)]
        rules_dt <- rules_dt[order(-lift, -confidence)]
        rules_dt <- rules_dt[1:min(20, nrow(rules_dt))]
        
        rules_summary <- list(
          available = TRUE,
          rules = rules_dt$rules,
          support = rules_dt$support,
          confidence = rules_dt$confidence,
          lift = rules_dt$lift
        )
      }
    }, error = function(e) {
      cat("arules execution notice:", e$message, "— switching to native algorithm.\n")
    })
  }
  
  # ── Secondary Attempt: High-performance Native Apriori Engine ──────────────
  if (is.null(rules_summary)) {
    cat("Executing native association rules engine...\n")
    native_dt <- NULL
    
    if (has_order) {
      t_data <- unique(dt[!is.na(Product_Name) & Product_Name != "", .(basket_id = Order_ID, Product_Name)])
      order_counts <- t_data[, .N, by = basket_id]
      valid_orders <- order_counts[N > 1, basket_id]
      if (length(valid_orders) >= 10) {
        native_dt <- compute_native_rules(t_data[basket_id %in% valid_orders])
      }
    }
    
    if (is.null(native_dt) && "Customer_ID" %in% names(dt)) {
      cat("Native fallback to customer-level baskets...\n")
      t_data <- unique(dt[!is.na(Product_Name) & Product_Name != "", .(basket_id = Customer_ID, Product_Name)])
      cust_counts <- t_data[, .N, by = basket_id]
      valid_custs <- cust_counts[N > 1, basket_id]
      if (length(valid_custs) >= 10) {
        native_dt <- compute_native_rules(t_data[basket_id %in% valid_custs])
      }
    }
    
    if (!is.null(native_dt) && nrow(native_dt) > 0) {
      rules_summary <- list(
        available = TRUE,
        rules = native_dt$rules,
        support = native_dt$support,
        confidence = native_dt$confidence,
        lift = native_dt$lift
      )
    }
  }
  
  # ── Fallback if no valid multi-item baskets exist in the data ───────────────
  if (is.null(rules_summary)) {
    write_json(list(available = FALSE, reason = "Insufficient valid transactions for association rules."), "output/association.json", auto_unbox = TRUE)
    return()
  }
  
  write_json(rules_summary, "output/association.json", auto_unbox = TRUE)
  cat("Association rule mining complete: generated", length(rules_summary$rules), "rules.\n")
}
