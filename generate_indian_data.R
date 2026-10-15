library(data.table)
library(lubridate)

set.seed(123)

n_rows <- 150000

# Indian Context Data
regions <- c("North India", "South India", "East India", "West India", "Central India", "North-East India")
states_by_region <- list(
  "North India" = c("Delhi", "Punjab", "Haryana", "Uttar Pradesh", "Rajasthan"),
  "South India" = c("Tamil Nadu", "Kerala", "Karnataka", "Andhra Pradesh", "Telangana"),
  "East India" = c("West Bengal", "Odisha", "Bihar", "Jharkhand"),
  "West India" = c("Maharashtra", "Gujarat", "Goa"),
  "Central India" = c("Madhya Pradesh", "Chhattisgarh"),
  "North-East India" = c("Assam", "Meghalaya")
)

cities_by_state <- list(
  "Delhi" = c("New Delhi", "Dwarka"), "Punjab" = c("Ludhiana", "Amritsar", "Chandigarh"),
  "Haryana" = c("Gurugram", "Faridabad"), "Uttar Pradesh" = c("Lucknow", "Kanpur", "Noida"),
  "Rajasthan" = c("Jaipur", "Jodhpur"),
  "Tamil Nadu" = c("Chennai", "Coimbatore", "Madurai", "Trichy"),
  "Kerala" = c("Kochi", "Thiruvananthapuram", "Kozhikode"),
  "Karnataka" = c("Bengaluru", "Mysuru", "Mangaluru"),
  "Andhra Pradesh" = c("Visakhapatnam", "Vijayawada"),
  "Telangana" = c("Hyderabad", "Warangal"),
  "West Bengal" = c("Kolkata", "Siliguri"), "Odisha" = c("Bhubaneswar", "Cuttack"),
  "Bihar" = c("Patna", "Gaya"), "Jharkhand" = c("Ranchi", "Jamshedpur"),
  "Maharashtra" = c("Mumbai", "Pune", "Nagpur"), "Gujarat" = c("Ahmedabad", "Surat"),
  "Goa" = c("Panaji", "Margao"),
  "Madhya Pradesh" = c("Indore", "Bhopal"), "Chhattisgarh" = c("Raipur", "Bhilai"),
  "Assam" = c("Guwahati", "Silchar"), "Meghalaya" = c("Shillong")
)

first_names <- c("Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Ayaan", "Krishna", "Ishaan", "Shaurya", "Diya", "Sanya", "Kavya", "Aanya", "Ananya", "Ishita", "Sneha", "Neha", "Pooja", "Rahul", "Ramesh", "Suresh", "Manoj", "Anita", "Sunita", "Raj", "Vikram")
last_names <- c("Sharma", "Verma", "Gupta", "Singh", "Kumar", "Patel", "Reddy", "Rao", "Nair", "Menon", "Iyer", "Joshi", "Das", "Bose", "Mukherjee", "Chatterjee", "Rajput", "Chauhan", "Bhat")

categories <- c("Electronics", "Smartphones", "Laptops", "Home Appliances", "Fashion", "Beauty & Personal Care", "Grocery", "Furniture", "Sports & Fitness", "Books")
payment_methods <- c("UPI", "Credit Card", "Debit Card", "Net Banking", "Cash on Delivery", "Wallet")
order_statuses <- c("Delivered", "Delivered", "Delivered", "Shipped", "Processing", "Cancelled", "Returned")

# Generate basic data
start_date <- as.Date("2023-01-01")
end_date <- as.Date("2026-09-01")
dates <- seq(start_date, end_date, by="day")

product_ids <- paste0("PRD", 1000:1100)
products <- data.table(
  Product_ID = product_ids,
  Category = sample(categories, 101, replace = TRUE)
)
products[, Product_Name := paste(Category, "Item", 1000:1100)]
products[, Base_Cost_INR := round(runif(.N, 100, 20000), 2)]
products[, Unit_Price_INR := round(Base_Cost_INR * runif(.N, 1.2, 2.5), 2)]

customer_ids <- paste0("CUST-", 10000:50000)

df <- data.table(
  Order_ID = paste0("ORD-", sample(100000:999999, n_rows, replace = TRUE)),
  Order_Date = sample(dates, n_rows, replace = TRUE),
  Customer_ID = sample(customer_ids, n_rows, replace = TRUE),
  Product_ID = sample(product_ids, n_rows, replace = TRUE),
  Quantity = sample(1:5, n_rows, replace = TRUE, prob = c(0.5, 0.25, 0.15, 0.05, 0.05)),
  Discount_Percent = sample(c(0, 5, 10, 15, 20, 25, 30), n_rows, replace = TRUE, prob = c(0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1)),
  Payment_Method = sample(payment_methods, n_rows, replace = TRUE, prob = c(0.4, 0.2, 0.15, 0.1, 0.1, 0.05)),
  Order_Status = sample(order_statuses, n_rows, replace = TRUE),
  Region = sample(regions, n_rows, replace = TRUE, prob = c(0.25, 0.3, 0.15, 0.2, 0.08, 0.02))
)

# Map states and cities based on region
df[, State := sapply(Region, function(r) sample(states_by_region[[r]], 1))]
df[, City := sapply(State, function(s) sample(cities_by_state[[s]], 1))]

# Map product details
df <- df[products, on = "Product_ID"]

# Map Customer Details (consistent for same customer ID)
unique_customers <- data.table(
  Customer_ID = unique(df$Customer_ID),
  Customer_Name = paste(sample(first_names, length(unique(df$Customer_ID)), replace = TRUE),
                        sample(last_names, length(unique(df$Customer_ID)), replace = TRUE)),
  Age = sample(18:70, length(unique(df$Customer_ID)), replace = TRUE),
  Gender = sample(c("Male", "Female", "Other"), length(unique(df$Customer_ID)), replace = TRUE, prob = c(0.5, 0.48, 0.02)),
  PIN_Code = sample(110001:800000, length(unique(df$Customer_ID)), replace = TRUE)
)

df <- df[unique_customers, on = "Customer_ID"]

# Calculate Sales and Profit
df[, Sales_INR := round(Quantity * Unit_Price_INR * (1 - Discount_Percent / 100), 2)]
df[, Cost_INR := round(Quantity * Base_Cost_INR, 2)]
df[, Profit_INR := Sales_INR - Cost_INR]
df[, Profit_Margin := round((Profit_INR / Sales_INR) * 100, 2)]

# Derived date columns
df[, Order_Month := month(Order_Date)]
df[, Order_Year := year(Order_Date)]
df[, Order_Quarter := quarter(Order_Date)]
df[, Customer_Type := ifelse(Order_Status == "Delivered", "Active", "Inactive")]

# Remove base cost col to match requested schema exactly
df[, Base_Cost_INR := NULL]

fwrite(df, "data/indian_ecommerce_data.csv")
cat("Generated indian_ecommerce_data.csv with", nrow(df), "rows.\n")
