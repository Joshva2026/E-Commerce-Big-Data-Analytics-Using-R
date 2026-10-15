# association_rules.R
suppressMessages(library(arules))

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
  
  # Remove duplicate products within the same transaction to avoid arules warnings
  has_order <- "Order_ID" %in% names(dt)
  trans_data <- NULL
  valid_orders <- NULL
  rules <- list()
  
  if (has_order) {
    trans_data <- unique(dt[, .(Order_ID, Product_Name)])
    order_counts <- trans_data[, .N, by = Order_ID]
    valid_orders <- order_counts[N > 1, Order_ID]
    
    if (length(valid_orders) >= 10) {
      trans_data <- trans_data[Order_ID %in% valid_orders]
      trans_list <- split(trans_data$Product_Name, trans_data$Order_ID)
      trans <- as(trans_list, "transactions")
      rules <- apriori(trans, parameter = list(supp = 0.0001, conf = 0.01, minlen = 2, maxlen = 3, target = "rules"), 
                       control = list(verbose = FALSE))
    }
  }
  
  # Fallback to Customer-level baskets if order-level fails or isn't available
  if(length(rules) == 0 && "Customer_ID" %in% names(dt)) {
    cat("Fallback to Customer-level basket analysis...\n")
    trans_data <- unique(dt[, .(Customer_ID, Product_Name)])
    cust_counts <- trans_data[, .N, by = Customer_ID]
    valid_custs <- cust_counts[N > 1, Customer_ID]
    if (length(valid_custs) >= 10) {
      trans_data <- trans_data[Customer_ID %in% valid_custs]
      trans_list <- split(trans_data$Product_Name, trans_data$Customer_ID)
      trans <- as(trans_list, "transactions")
      
      rules <- apriori(trans, parameter = list(supp = 0.001, conf = 0.01, minlen = 2, maxlen = 3, target = "rules"), 
                       control = list(verbose = FALSE))
    }
  }
  
  if(length(rules) == 0) {
    write_json(list(available = FALSE, reason = "Insufficient valid transactions for association rules."), "output/association.json", auto_unbox = TRUE)
    return()
  }
  
  # Extract components
  rules_dt <- as(rules, "data.frame")
  setDT(rules_dt)
  rules_dt[, rules := as.character(rules)]
  
  # Sort by lift, then confidence
  rules_dt <- rules_dt[order(-lift, -confidence)]
  rules_dt <- rules_dt[1:min(20, nrow(rules_dt))]
  
  rules_summary <- list(
    available = TRUE,
    rules = rules_dt$rules,
    support = rules_dt$support,
    confidence = rules_dt$confidence,
    lift = rules_dt$lift
  )
  
  write_json(rules_summary, "output/association.json", auto_unbox = TRUE)
}
