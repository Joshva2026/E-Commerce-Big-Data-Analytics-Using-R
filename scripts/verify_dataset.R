# scripts/verify_dataset.R
suppressMessages(library(data.table))

cat("Reading datasets/advanced_ecommerce_dataset.csv...\n")
dt <- fread("datasets/advanced_ecommerce_dataset.csv")

cat("Row count:", nrow(dt), "\n")
cat("Column count:", ncol(dt), "\n")
cat("Date range:", as.character(min(dt$Order_Date)), "to", as.character(max(dt$Order_Date)), "\n")

# Check 1: Sales_INR calculation
sales_diff <- abs(dt$Sales_INR - round(dt$Quantity * dt$Unit_Price_INR * (1 - dt$Discount_Percent / 100), 2))
bad_sales <- sum(sales_diff > 0.01)
cat("Sales mismatch count:", bad_sales, "\n")

# Check 2: Profit_INR calculation
profit_diff <- abs(dt$Profit_INR - round(dt$Sales_INR - dt$Cost_INR, 2))
bad_profit <- sum(profit_diff > 0.01)
cat("Profit mismatch count:", bad_profit, "\n")

# Check 3: Profit Margin calculation
margin_diff <- abs(dt$Profit_Margin - round((dt$Profit_INR / dt$Sales_INR) * 100, 2))
bad_margin <- sum(margin_diff > 0.02)
cat("Profit margin mismatch count:", bad_margin, "\n")

# Check 4: Date completeness (months covered)
dt[, Month := format(as.Date(Order_Date), "%Y-%m")]
months_covered <- sort(unique(dt$Month))
cat("Total distinct months:", length(months_covered), "\n")
cat("Months sequence:", head(months_covered, 3), "...", tail(months_covered, 3), "\n")

# Check 5: Repeat customers and orders
order_counts <- dt[, .(Lines = .N), by = Order_ID]
multi_line_orders <- sum(order_counts$Lines > 1)
cat("Multi-line orders (for Apriori):", multi_line_orders, "(", round((multi_line_orders/nrow(order_counts))*100, 1), "%)\n")

cust_orders <- dt[, .(Orders = uniqueN(Order_ID)), by = Customer_ID]
repeat_customers <- sum(cust_orders$Orders > 1)
cat("Total customers:", nrow(cust_orders), "\n")
cat("Repeat customers:", repeat_customers, "(", round((repeat_customers/nrow(cust_orders))*100, 1), "%)\n")

# Check 6: Missing cells detection
missing_per_col <- sapply(dt, function(x) sum(is.na(x)))
cat("Missing cells breakdown:\n")
print(missing_per_col[missing_per_col > 0])

cat("All mathematical consistency checks passed:", (bad_sales == 0 && bad_profit == 0 && bad_margin == 0), "\n")
