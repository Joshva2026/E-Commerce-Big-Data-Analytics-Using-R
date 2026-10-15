# ============================================================
# generate_builtin_datasets.R
# Generates 4 synthetic datasets with the EXACT same 26-column
# schema as indian_ecommerce_data.csv
#
# Schema (from indian_ecommerce_data.csv):
# Order_ID, Order_Date, Customer_ID, Product_ID, Quantity,
# Discount_Percent, Payment_Method, Order_Status, Region, State,
# City, Category, Product_Name, Unit_Price_INR, Customer_Name,
# Age, Gender, PIN_Code, Sales_INR, Cost_INR, Profit_INR,
# Profit_Margin, Order_Month, Order_Year, Order_Quarter,
# Customer_Type
# ============================================================

library(lubridate)

# ── Shared helpers ──────────────────────────────────────────

REGIONS <- list(
  "North India"   = list(states = c("Delhi","Uttar Pradesh","Haryana","Punjab","Himachal Pradesh","Uttarakhand","Jammu & Kashmir"),
                          cities = c("Delhi","Noida","Gurgaon","Lucknow","Agra","Chandigarh","Amritsar","Dehradun","Shimla")),
  "South India"   = list(states = c("Tamil Nadu","Karnataka","Kerala","Andhra Pradesh","Telangana"),
                          cities = c("Chennai","Bangalore","Hyderabad","Kochi","Coimbatore","Mysore","Visakhapatnam","Tirupati")),
  "West India"    = list(states = c("Maharashtra","Gujarat","Rajasthan","Goa"),
                          cities = c("Mumbai","Pune","Ahmedabad","Surat","Jaipur","Udaipur","Goa","Nashik")),
  "East India"    = list(states = c("West Bengal","Odisha","Jharkhand","Bihar"),
                          cities = c("Kolkata","Bhubaneswar","Patna","Ranchi","Asansol","Durgapur","Guwahati")),
  "Central India" = list(states = c("Madhya Pradesh","Chhattisgarh","Telangana"),
                          cities = c("Bhopal","Indore","Raipur","Nagpur","Jabalpur","Bilaspur"))
)

PAYMENT_METHODS <- c("Credit Card","Debit Card","UPI","Net Banking","Cash on Delivery","EMI")
ORDER_STATUSES  <- c("Delivered","Returned","Cancelled","Shipped","Processing")
GENDERS         <- c("Male","Female","Other")
CUSTOMER_TYPES  <- c("Active","Inactive","New","VIP")

# Indian first/last names
FIRST_NAMES <- c("Aarav","Aditya","Amit","Ananya","Anjali","Arjun","Ayaan","Deepa","Deepak",
                  "Divya","Gaurav","Ishaan","Kiran","Lakshmi","Mahesh","Manish","Meera","Mohan",
                  "Neha","Nikhil","Pooja","Priya","Rahul","Rajesh","Ravi","Rohan","Rohit",
                  "Sanjay","Shreya","Siddharth","Sneha","Sunita","Suresh","Swati","Tanvi",
                  "Usha","Vijay","Vikram","Vinod","Yash","Zara","Kabir","Nisha","Preeti")
LAST_NAMES  <- c("Agarwal","Bose","Chakraborty","Chatterjee","Chopra","Das","Desai","Deshpande",
                  "Ghosh","Gupta","Iyer","Jain","Joshi","Kapoor","Khan","Kumar","Mehta","Mishra",
                  "Mukherjee","Nair","Patel","Pillai","Rao","Reddy","Saxena","Shah","Sharma",
                  "Singh","Sinha","Srivastava","Trivedi","Verma")

make_name <- function(n) paste(sample(FIRST_NAMES, n, TRUE), sample(LAST_NAMES, n, TRUE))

make_location <- function(n, region_weights = NULL) {
  region_names <- names(REGIONS)
  if (is.null(region_weights)) region_weights <- rep(1/length(region_names), length(region_names))
  chosen_regions <- sample(region_names, n, TRUE, prob = region_weights)
  states <- mapply(function(r) sample(REGIONS[[r]]$states, 1), chosen_regions)
  cities <- mapply(function(r) sample(REGIONS[[r]]$cities, 1), chosen_regions)
  list(region = chosen_regions, state = states, city = cities)
}

make_pin <- function(n) formatC(sample(100000:999999, n, TRUE), width=6, flag="0")

derive_date_cols <- function(dates) {
  d <- as.Date(dates)
  list(
    month   = as.integer(format(d, "%m")),
    year    = as.integer(format(d, "%Y")),
    quarter = as.integer(ceiling(as.integer(format(d, "%m")) / 3))
  )
}

build_dataset <- function(
  n_rows, n_customers, n_products,
  categories, category_weights,
  products_per_cat,
  price_range_by_cat,    # named list: cat -> c(min, max)
  cost_margin_by_cat,    # named list: cat -> c(min_pct, max_pct) cost as % of unit price
  discount_probs,        # list: prob of 0, 5, 10, 15, 20, 25%
  payment_weights,
  status_weights,
  gender_weights,
  region_weights,
  customer_type_weights,
  date_start, date_end,
  age_mean, age_sd,
  qty_probs,             # probabilities for qty 1:5
  id_prefix,
  seed
) {
  set.seed(seed)

  # Generate customer pool
  cust_ids   <- paste0("CUST-", formatC(1:n_customers, width=5, flag="0"))
  cust_names <- make_name(n_customers)
  cust_ages  <- pmax(18, pmin(70, round(rnorm(n_customers, age_mean, age_sd))))
  cust_genders <- sample(GENDERS, n_customers, TRUE, prob = gender_weights)
  loc          <- make_location(n_customers, region_weights)
  cust_pins    <- make_pin(n_customers)
  cust_types   <- sample(CUSTOMER_TYPES, n_customers, TRUE, prob = customer_type_weights)

  # Generate product pool
  all_products <- list()
  prod_counter <- 1
  for (cat in categories) {
    for (j in 1:products_per_cat) {
      pid <- paste0("PRD", formatC(prod_counter, width=4, flag="0"))
      pr  <- price_range_by_cat[[cat]]
      price <- round(runif(1, pr[1], pr[2]), 2)
      all_products[[pid]] <- list(
        id = pid, name = paste(cat, "Item", prod_counter),
        category = cat, price = price
      )
      prod_counter <- prod_counter + 1
    }
  }
  prod_ids <- names(all_products)

  # Sample rows
  cust_idx <- sample(1:n_customers, n_rows, TRUE)
  prod_idx <- sample(prod_ids, n_rows, TRUE, prob = rep(category_weights / products_per_cat, each = products_per_cat)[1:length(prod_ids)])

  # Dates
  d_start <- as.Date(date_start)
  d_end   <- as.Date(date_end)
  dates   <- as.character(d_start + sample(0:as.integer(d_end - d_start), n_rows, TRUE))

  # Quantities
  qty <- sample(1:5, n_rows, TRUE, prob = qty_probs)

  # Discounts
  disc_vals  <- c(0, 5, 10, 15, 20, 25)
  disc_probs_v <- discount_probs / sum(discount_probs)
  discount   <- sample(disc_vals, n_rows, TRUE, prob = disc_probs_v)

  # Prices & financials
  unit_prices <- sapply(prod_idx, function(pid) all_products[[pid]]$price)
  sales_inr   <- round(qty * unit_prices * (1 - discount/100), 2)

  cm <- cost_margin_by_cat
  cost_pct <- mapply(function(pid) {
    cat <- all_products[[pid]]$category
    runif(1, cm[[cat]][1], cm[[cat]][2])
  }, prod_idx)
  cost_inr   <- round(unit_prices * cost_pct * qty, 2)
  profit_inr <- round(sales_inr - cost_inr, 2)
  profit_margin <- round(ifelse(sales_inr > 0, profit_inr / sales_inr * 100, 0), 2)

  # Date derived cols
  dc <- derive_date_cols(dates)

  # Build final data frame
  df <- data.frame(
    Order_ID        = paste0(id_prefix, "-", formatC(sample(100000:999999, n_rows, FALSE), width=6, flag="0")),
    Order_Date      = dates,
    Customer_ID     = cust_ids[cust_idx],
    Product_ID      = prod_idx,
    Quantity        = qty,
    Discount_Percent = discount,
    Payment_Method  = sample(PAYMENT_METHODS, n_rows, TRUE, prob = payment_weights),
    Order_Status    = sample(ORDER_STATUSES, n_rows, TRUE, prob = status_weights),
    Region          = loc$region[cust_idx],
    State           = loc$state[cust_idx],
    City            = loc$city[cust_idx],
    Category        = sapply(prod_idx, function(pid) all_products[[pid]]$category),
    Product_Name    = sapply(prod_idx, function(pid) all_products[[pid]]$name),
    Unit_Price_INR  = unit_prices,
    Customer_Name   = cust_names[cust_idx],
    Age             = cust_ages[cust_idx],
    Gender          = cust_genders[cust_idx],
    PIN_Code        = cust_pins[cust_idx],
    Sales_INR       = sales_inr,
    Cost_INR        = cost_inr,
    Profit_INR      = profit_inr,
    Profit_Margin   = profit_margin,
    Order_Month     = dc$month,
    Order_Year      = dc$year,
    Order_Quarter   = dc$quarter,
    Customer_Type   = cust_types[cust_idx],
    stringsAsFactors = FALSE
  )
  df
}

# ═══════════════════════════════════════════════════════════
# DATASET 2 — PRODUCT INVENTORY ANALYTICS
# Heavy on Furniture, Home Appliances, Sports equipment
# Lower margins, higher quantities, slow-moving SKUs
# Different regional focus (West India dominant)
# ═══════════════════════════════════════════════════════════
cat("Generating Dataset 2: Product Inventory Analytics...\n")
cats2 <- c("Furniture","Home Appliances","Sports","Kitchen","Gardening","Tools")
df2 <- build_dataset(
  n_rows = 120000, n_customers = 30000, n_products = 6,
  categories = cats2,
  category_weights = c(0.30, 0.25, 0.18, 0.14, 0.08, 0.05),
  products_per_cat = 15,
  price_range_by_cat = list(
    Furniture       = c(3000, 50000),
    "Home Appliances" = c(2000, 40000),
    Sports          = c(500, 8000),
    Kitchen         = c(300, 6000),
    Gardening       = c(200, 4000),
    Tools           = c(150, 5000)
  ),
  cost_margin_by_cat = list(
    Furniture       = c(0.68, 0.78),
    "Home Appliances" = c(0.65, 0.75),
    Sports          = c(0.55, 0.68),
    Kitchen         = c(0.52, 0.65),
    Gardening       = c(0.50, 0.62),
    Tools           = c(0.48, 0.60)
  ),
  discount_probs   = c(0.30, 0.25, 0.20, 0.15, 0.07, 0.03),
  payment_weights  = c(0.20, 0.30, 0.22, 0.10, 0.15, 0.03),
  status_weights   = c(0.78, 0.09, 0.07, 0.05, 0.01),
  gender_weights   = c(0.48, 0.49, 0.03),
  region_weights   = c(0.18, 0.20, 0.38, 0.15, 0.09),
  customer_type_weights = c(0.45, 0.25, 0.22, 0.08),
  date_start = "2020-01-01", date_end = "2024-12-31",
  age_mean = 36, age_sd = 12,
  qty_probs = c(0.25, 0.28, 0.22, 0.15, 0.10),
  id_prefix = "INV",
  seed = 2024
)
write.csv(df2, "data/product_inventory_data.csv", row.names = FALSE)
cat(sprintf("  -> %d rows, %d cols written.\n", nrow(df2), ncol(df2)))

# ═══════════════════════════════════════════════════════════
# DATASET 3 — E-COMMERCE FINANCE & EXPENSES
# Heavy finance transactions, high-value purchases
# Electronics/Jewellery/Luxury Goods dominant
# Higher discounts, higher margins, B2B-style
# South India + East India focus
# ═══════════════════════════════════════════════════════════
cat("Generating Dataset 3: E-Commerce Finance & Expenses...\n")
cats3 <- c("Electronics","Jewellery","Luxury Goods","Watches","Perfumes","Premium Fashion")
df3 <- build_dataset(
  n_rows = 110000, n_customers = 22000, n_products = 6,
  categories = cats3,
  category_weights = c(0.32, 0.22, 0.18, 0.14, 0.08, 0.06),
  products_per_cat = 18,
  price_range_by_cat = list(
    Electronics     = c(5000, 120000),
    Jewellery       = c(8000, 200000),
    "Luxury Goods"  = c(10000, 250000),
    Watches         = c(4000, 80000),
    Perfumes        = c(1500, 15000),
    "Premium Fashion"= c(2000, 35000)
  ),
  cost_margin_by_cat = list(
    Electronics     = c(0.45, 0.60),
    Jewellery       = c(0.40, 0.55),
    "Luxury Goods"  = c(0.35, 0.50),
    Watches         = c(0.42, 0.58),
    Perfumes        = c(0.38, 0.52),
    "Premium Fashion"= c(0.40, 0.55)
  ),
  discount_probs   = c(0.20, 0.15, 0.25, 0.20, 0.12, 0.08),
  payment_weights  = c(0.40, 0.12, 0.15, 0.22, 0.05, 0.06),
  status_weights   = c(0.82, 0.07, 0.05, 0.04, 0.02),
  gender_weights   = c(0.45, 0.52, 0.03),
  region_weights   = c(0.20, 0.32, 0.22, 0.18, 0.08),
  customer_type_weights = c(0.35, 0.20, 0.15, 0.30),
  date_start = "2020-01-01", date_end = "2024-12-31",
  age_mean = 42, age_sd = 10,
  qty_probs = c(0.55, 0.28, 0.10, 0.05, 0.02),
  id_prefix = "FIN",
  seed = 3024
)
write.csv(df3, "data/ecommerce_finance_data.csv", row.names = FALSE)
cat(sprintf("  -> %d rows, %d cols written.\n", nrow(df3), ncol(df3)))

# ═══════════════════════════════════════════════════════════
# DATASET 4 — MARKETPLACE PRICING COMPARISON
# Discount-heavy competitive pricing environment
# Fashion, Beauty, Accessories dominant
# High discount frequency, thin margins
# All-India uniform distribution
# ═══════════════════════════════════════════════════════════
cat("Generating Dataset 4: Marketplace Pricing Comparison...\n")
cats4 <- c("Fashion","Beauty","Accessories","Footwear","Bags","Sunglasses")
df4 <- build_dataset(
  n_rows = 115000, n_customers = 35000, n_products = 6,
  categories = cats4,
  category_weights = c(0.32, 0.22, 0.18, 0.14, 0.08, 0.06),
  products_per_cat = 20,
  price_range_by_cat = list(
    Fashion     = c(400, 8000),
    Beauty      = c(200, 4000),
    Accessories = c(150, 5000),
    Footwear    = c(500, 10000),
    Bags        = c(600, 15000),
    Sunglasses  = c(300, 8000)
  ),
  cost_margin_by_cat = list(
    Fashion     = c(0.42, 0.58),
    Beauty      = c(0.35, 0.50),
    Accessories = c(0.38, 0.52),
    Footwear    = c(0.45, 0.60),
    Bags        = c(0.40, 0.55),
    Sunglasses  = c(0.38, 0.52)
  ),
  discount_probs   = c(0.10, 0.15, 0.20, 0.25, 0.18, 0.12),
  payment_weights  = c(0.15, 0.18, 0.42, 0.08, 0.14, 0.03),
  status_weights   = c(0.72, 0.14, 0.08, 0.05, 0.01),
  gender_weights   = c(0.38, 0.59, 0.03),
  region_weights   = c(0.22, 0.25, 0.28, 0.15, 0.10),
  customer_type_weights = c(0.50, 0.22, 0.20, 0.08),
  date_start = "2020-01-01", date_end = "2024-12-31",
  age_mean = 28, age_sd = 8,
  qty_probs = c(0.40, 0.30, 0.18, 0.08, 0.04),
  id_prefix = "MKT",
  seed = 4024
)
write.csv(df4, "data/marketplace_pricing_data.csv", row.names = FALSE)
cat(sprintf("  -> %d rows, %d cols written.\n", nrow(df4), ncol(df4)))

# ═══════════════════════════════════════════════════════════
# DATASET 5 — CUSTOMER PURCHASE ANALYTICS
# Repeat-purchase-heavy customer behaviour study
# Books, Health, Food/Grocery dominant
# High frequency, lower AOV, strong membership/loyalty
# North India dominant
# ═══════════════════════════════════════════════════════════
cat("Generating Dataset 5: Customer Purchase Analytics...\n")
cats5 <- c("Books","Health & Wellness","Grocery","Baby Products","Pet Supplies","Stationery")
df5 <- build_dataset(
  n_rows = 125000, n_customers = 18000, n_products = 6,
  categories = cats5,
  category_weights = c(0.28, 0.25, 0.22, 0.12, 0.08, 0.05),
  products_per_cat = 20,
  price_range_by_cat = list(
    Books               = c(150, 2000),
    "Health & Wellness" = c(200, 6000),
    Grocery             = c(50, 2000),
    "Baby Products"     = c(300, 5000),
    "Pet Supplies"      = c(200, 4000),
    Stationery          = c(50, 1000)
  ),
  cost_margin_by_cat = list(
    Books               = c(0.40, 0.55),
    "Health & Wellness" = c(0.38, 0.52),
    Grocery             = c(0.50, 0.65),
    "Baby Products"     = c(0.42, 0.57),
    "Pet Supplies"      = c(0.40, 0.55),
    Stationery          = c(0.35, 0.50)
  ),
  discount_probs   = c(0.35, 0.28, 0.20, 0.10, 0.05, 0.02),
  payment_weights  = c(0.10, 0.20, 0.50, 0.08, 0.10, 0.02),
  status_weights   = c(0.85, 0.06, 0.05, 0.03, 0.01),
  gender_weights   = c(0.44, 0.54, 0.02),
  region_weights   = c(0.35, 0.20, 0.22, 0.14, 0.09),
  customer_type_weights = c(0.40, 0.15, 0.12, 0.33),
  date_start = "2020-01-01", date_end = "2024-12-31",
  age_mean = 33, age_sd = 11,
  qty_probs = c(0.35, 0.30, 0.20, 0.10, 0.05),
  id_prefix = "CUS",
  seed = 5024
)
write.csv(df5, "data/customer_purchase_data.csv", row.names = FALSE)
cat(sprintf("  -> %d rows, %d cols written.\n", nrow(df5), ncol(df5)))

cat("\n=== ALL DATASETS GENERATED SUCCESSFULLY ===\n")
cat(sprintf("Schema: %d columns — same as Indian master.\n", ncol(df2)))
