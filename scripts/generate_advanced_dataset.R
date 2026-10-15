# scripts/generate_advanced_dataset.R
# Script to generate a large, highly realistic, mathematically consistent E-Commerce dataset
# Output target: datasets/advanced_ecommerce_dataset.csv (~160,000 rows)

suppressMessages(library(data.table))
suppressMessages(library(lubridate))

set.seed(42)

cat("=================================================================\n")
cat("Generating Advanced E-Commerce Dataset for Advanced Analytics\n")
cat("=================================================================\n")

# 1. Product Catalog Definition (80 SKUs across 10 Categories)
products_master <- list(
  list(Category = "Smartphones", Name = "Flagship 5G Smartphone 256GB", Price = 64999, Cost = 48500),
  list(Category = "Smartphones", Name = "Mid-Range 5G Smartphone 128GB", Price = 24999, Cost = 18200),
  list(Category = "Smartphones", Name = "Budget 4G Smartphone 64GB", Price = 9999, Cost = 7600),
  list(Category = "Smartphones", Name = "Foldable Ultra Smartphone 512GB", Price = 89999, Cost = 68000),
  list(Category = "Smartphones", Name = "Compact Pro Smartphone 128GB", Price = 38999, Cost = 29000),
  
  list(Category = "Laptops", Name = "Ultra-Thin Business Laptop 14-inch", Price = 59999, Cost = 44500),
  list(Category = "Laptops", Name = "Gaming Laptop RTX 16GB", Price = 84999, Cost = 64000),
  list(Category = "Laptops", Name = "Student Chromebook 11.6-inch", Price = 21999, Cost = 16800),
  list(Category = "Laptops", Name = "Workstation Pro Laptop 32GB", Price = 119999, Cost = 89000),
  list(Category = "Laptops", Name = "Convertible 2-in-1 Touch Laptop", Price = 49999, Cost = 37500),
  
  list(Category = "Electronics", Name = "Noise-Cancelling Over-Ear Headphones", Price = 14999, Cost = 9800),
  list(Category = "Electronics", Name = "Wireless Bluetooth Earbuds Pro", Price = 4999, Cost = 2950),
  list(Category = "Electronics", Name = "Smartwatch Fitness Tracker GPS", Price = 7999, Cost = 4900),
  list(Category = "Electronics", Name = "Portable Waterproof Bluetooth Speaker", Price = 3499, Cost = 2100),
  list(Category = "Electronics", Name = "4K Ultra-HD Action Camera", Price = 18999, Cost = 12500),
  list(Category = "Electronics", Name = "Smart Home Security Camera Wi-Fi", Price = 2999, Cost = 1750),
  
  list(Category = "Accessories", Name = "Fast Charging 65W GaN Wall Adapter", Price = 1999, Cost = 950),
  list(Category = "Accessories", Name = "Braided USB-C to USB-C Cable 2M", Price = 499, Cost = 180),
  list(Category = "Accessories", Name = "Tempered Glass Screen Protector Pack", Price = 349, Cost = 110),
  list(Category = "Accessories", Name = "Shockproof Liquid Silicone Phone Case", Price = 599, Cost = 210),
  list(Category = "Accessories", Name = "Wireless Ergonomic Laser Mouse", Price = 1299, Cost = 620),
  list(Category = "Accessories", Name = "Multiport USB-C Hub 7-in-1", Price = 2499, Cost = 1200),
  list(Category = "Accessories", Name = "Water-Resistant Laptop Sleeve 15.6 Inch", Price = 899, Cost = 390),
  list(Category = "Accessories", Name = "Mechanical Gaming Keyboard RGB", Price = 3999, Cost = 2200),
  
  list(Category = "Home Appliances", Name = "Digital Hot Air Fryer 4.5L", Price = 5999, Cost = 3700),
  list(Category = "Home Appliances", Name = "Robot Vacuum Cleaner Smart Mapping", Price = 24999, Cost = 16500),
  list(Category = "Home Appliances", Name = "Convection Microwave Oven 28L", Price = 12499, Cost = 8500),
  list(Category = "Home Appliances", Name = "RO+UV Water Purifier with Mineral Boost", Price = 14999, Cost = 9900),
  list(Category = "Home Appliances", Name = "True HEPA Air Purifier 45W", Price = 8999, Cost = 5800),
  list(Category = "Home Appliances", Name = "Electric Induction Cooktop 2000W", Price = 2899, Cost = 1750),
  list(Category = "Home Appliances", Name = "Steam Iron Ceramic Soleplate 1600W", Price = 1599, Cost = 920),
  
  list(Category = "Fashion", Name = "Men Slim Fit Cotton Casual Shirt", Price = 1299, Cost = 580),
  list(Category = "Fashion", Name = "Women Embroidered Anarkali Kurta Set", Price = 2499, Cost = 1150),
  list(Category = "Fashion", Name = "Unisex Denim Relaxed Fit Jeans", Price = 1899, Cost = 880),
  list(Category = "Fashion", Name = "Lightweight Breathable Running Shoes", Price = 2999, Cost = 1420),
  list(Category = "Fashion", Name = "Genuine Leather Formal Reversible Belt", Price = 799, Cost = 320),
  list(Category = "Fashion", Name = "Polarized UV400 Wayfarer Sunglasses", Price = 1199, Cost = 480),
  list(Category = "Fashion", Name = "Cotton Graphic Casual Printed T-Shirt", Price = 599, Cost = 230),
  list(Category = "Fashion", Name = "Women Vegan Leather Crossbody Handbag", Price = 1799, Cost = 790),
  
  list(Category = "Beauty & Personal Care", Name = "Vitamin C Glowing Face Serum 30ml", Price = 699, Cost = 240),
  list(Category = "Beauty & Personal Care", Name = "Ultralight Hydrating Gel Moisturizer 100g", Price = 499, Cost = 180),
  list(Category = "Beauty & Personal Care", Name = "Mineral Sunscreen SPF 50 PA++++", Price = 599, Cost = 220),
  list(Category = "Beauty & Personal Care", Name = "Redensyl Hair Growth Tonic Serum 50ml", Price = 999, Cost = 380),
  list(Category = "Beauty & Personal Care", Name = "Deep Cleansing Activated Charcoal Face Wash", Price = 299, Cost = 95),
  list(Category = "Beauty & Personal Care", Name = "Natural Tea Tree Anti-Dandruff Shampoo", Price = 449, Cost = 160),
  list(Category = "Beauty & Personal Care", Name = "Onion & Bhringraj Organic Hair Oil 200ml", Price = 379, Cost = 135),
  
  list(Category = "Grocery", Name = "California Roasted & Salted Almonds 500g", Price = 549, Cost = 360),
  list(Category = "Grocery", Name = "Cold-Pressed Virgin Mustard Oil 1L", Price = 249, Cost = 165),
  list(Category = "Grocery", Name = "Premium Pure Himalayan Shilajit Resin 20g", Price = 1299, Cost = 620),
  list(Category = "Grocery", Name = "Single Origin Dark Roast Arabica Coffee Beans 250g", Price = 499, Cost = 260),
  list(Category = "Grocery", Name = "Certified Organic Green Tea Leaves 250g", Price = 349, Cost = 180),
  list(Category = "Grocery", Name = "Raw Unpasteurized Forest Honey 500g", Price = 399, Cost = 220),
  list(Category = "Grocery", Name = "Gluten-Free Rolled Oats High Fiber 1kg", Price = 299, Cost = 170),
  
  list(Category = "Furniture", Name = "Ergonomic High-Back Mesh Office Chair", Price = 8499, Cost = 5400),
  list(Category = "Furniture", Name = "Solid Engineered Wood Study Table with Shelf", Price = 5499, Cost = 3400),
  list(Category = "Furniture", Name = "Orthopedic Memory Foam Mattress 6-Inch Queen", Price = 14999, Cost = 9800),
  list(Category = "Furniture", Name = "Fabric Recliner Single Seater Armchair", Price = 18999, Cost = 12800),
  list(Category = "Furniture", Name = "Modular 3-Tier Wooden Bookshelf Rack", Price = 2999, Cost = 1850),
  list(Category = "Furniture", Name = "Foldable Laptop Bed Tray Desk with Cup Holder", Price = 799, Cost = 390),
  
  list(Category = "Sports & Fitness", Name = "Hexagonal Rubber Dumbbells Set 10kg Pair", Price = 2499, Cost = 1400),
  list(Category = "Sports & Fitness", Name = "Anti-Tear Non-Slip Yoga Mat 6mm with Strap", Price = 799, Cost = 380),
  list(Category = "Sports & Fitness", Name = "100% Whey Protein Isolate Rich Chocolate 1kg", Price = 3299, Cost = 2100),
  list(Category = "Sports & Fitness", Name = "Resistance Bands Set 5 Levels with Door Anchor", Price = 699, Cost = 310),
  list(Category = "Sports & Fitness", Name = "High-Speed Ball Bearing Skipping Rope", Price = 349, Cost = 130),
  list(Category = "Sports & Fitness", Name = "BPA-Free Protein Shaker Bottle 700ml", Price = 299, Cost = 110)
)

prod_dt <- rbindlist(lapply(seq_along(products_master), function(i) {
  p <- products_master[[i]]
  data.table(
    Product_ID = sprintf("PRD-%04d", 1000 + i),
    Category = p$Category,
    Product_Name = p$Name,
    Unit_Price_INR = as.numeric(p$Price),
    Unit_Cost_INR = as.numeric(p$Cost),
    Stock_Quantity = sample(c(sample(5:9, 1), sample(15:450, 9)), 1) # small fraction <10 for low-stock alerting
  )
}))

cat("Master products created:", nrow(prod_dt), "SKUs across", uniqueN(prod_dt$Category), "categories.\n")

# Complementary affinity sets for multi-item baskets (Apriori association rules)
affinity_pairs <- list(
  c("Flagship 5G Smartphone 256GB", "Tempered Glass Screen Protector Pack", "Fast Charging 65W GaN Wall Adapter"),
  c("Mid-Range 5G Smartphone 128GB", "Shockproof Liquid Silicone Phone Case", "Wireless Bluetooth Earbuds Pro"),
  c("Budget 4G Smartphone 64GB", "Tempered Glass Screen Protector Pack", "Braided USB-C to USB-C Cable 2M"),
  c("Ultra-Thin Business Laptop 14-inch", "Wireless Ergonomic Laser Mouse", "Water-Resistant Laptop Sleeve 15.6 Inch"),
  c("Gaming Laptop RTX 16GB", "Mechanical Gaming Keyboard RGB", "Multiport USB-C Hub 7-in-1"),
  c("Student Chromebook 11.6-inch", "Water-Resistant Laptop Sleeve 15.6 Inch", "Wireless Ergonomic Laser Mouse"),
  c("Men Slim Fit Cotton Casual Shirt", "Unisex Denim Relaxed Fit Jeans", "Genuine Leather Formal Reversible Belt"),
  c("Lightweight Breathable Running Shoes", "Cotton Graphic Casual Printed T-Shirt", "Polarized UV400 Wayfarer Sunglasses"),
  c("Vitamin C Glowing Face Serum 30ml", "Mineral Sunscreen SPF 50 PA++++", "Ultralight Hydrating Gel Moisturizer 100g"),
  c("Natural Tea Tree Anti-Dandruff Shampoo", "Onion & Bhringraj Organic Hair Oil 200ml", "Redensyl Hair Growth Tonic Serum 50ml"),
  c("Hexagonal Rubber Dumbbells Set 10kg Pair", "100% Whey Protein Isolate Rich Chocolate 1kg", "BPA-Free Protein Shaker Bottle 700ml"),
  c("Anti-Tear Non-Slip Yoga Mat 6mm with Strap", "Resistance Bands Set 5 Levels with Door Anchor", "High-Speed Ball Bearing Skipping Rope"),
  c("Ergonomic High-Back Mesh Office Chair", "Solid Engineered Wood Study Table with Shelf", "Foldable Laptop Bed Tray Desk with Cup Holder"),
  c("Digital Hot Air Fryer 4.5L", "Electric Induction Cooktop 2000W"),
  c("Certified Organic Green Tea Leaves 250g", "Raw Unpasteurized Forest Honey 500g", "California Roasted & Salted Almonds 500g")
)

# 2. Regional and City Master Data
geo_hierarchy <- list(
  "North India" = list(
    "Delhi" = list(cities = c("New Delhi", "Dwarka", "Rohini"), pin_range = 110001:110085),
    "Uttar Pradesh" = list(cities = c("Noida", "Lucknow", "Kanpur", "Varanasi"), pin_range = 201301:226028),
    "Haryana" = list(cities = c("Gurugram", "Faridabad", "Panipat"), pin_range = 122001:121008),
    "Punjab" = list(cities = c("Ludhiana", "Amritsar", "Chandigarh"), pin_range = 141001:160017),
    "Rajasthan" = list(cities = c("Jaipur", "Jodhpur", "Udaipur"), pin_range = 302001:342001)
  ),
  "South India" = list(
    "Karnataka" = list(cities = c("Bengaluru", "Mysuru", "Mangaluru"), pin_range = 560001:575001),
    "Tamil Nadu" = list(cities = c("Chennai", "Coimbatore", "Madurai"), pin_range = 600001:625001),
    "Telangana" = list(cities = c("Hyderabad", "Warangal"), pin_range = 500001:506002),
    "Kerala" = list(cities = c("Kochi", "Thiruvananthapuram", "Kozhikode"), pin_range = 682001:695001),
    "Andhra Pradesh" = list(cities = c("Visakhapatnam", "Vijayawada"), pin_range = 530001:520001)
  ),
  "West India" = list(
    "Maharashtra" = list(cities = c("Mumbai", "Pune", "Nagpur", "Nashik"), pin_range = 400001:440001),
    "Gujarat" = list(cities = c("Ahmedabad", "Surat", "Vadodara"), pin_range = 380001:395001),
    "Goa" = list(cities = c("Panaji", "Margao"), pin_range = 403001:403601)
  ),
  "East India" = list(
    "West Bengal" = list(cities = c("Kolkata", "Siliguri", "Howrah"), pin_range = 700001:734001),
    "Odisha" = list(cities = c("Bhubaneswar", "Cuttack"), pin_range = 751001:753001),
    "Bihar" = list(cities = c("Patna", "Gaya"), pin_range = 800001:823001),
    "Jharkhand" = list(cities = c("Ranchi", "Jamshedpur"), pin_range = 834001:831001)
  ),
  "Central India" = list(
    "Madhya Pradesh" = list(cities = c("Indore", "Bhopal", "Gwalior"), pin_range = 452001:462001),
    "Chhattisgarh" = list(cities = c("Raipur", "Bhilai"), pin_range = 492001:490006)
  ),
  "North-East India" = list(
    "Assam" = list(cities = c("Guwahati", "Silchar"), pin_range = 781001:788001),
    "Meghalaya" = list(cities = c("Shillong"), pin_range = 793001:793014)
  )
)

first_names_male <- c("Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Ayaan", "Krishna", "Ishaan", "Shaurya", "Rahul", "Ramesh", "Suresh", "Manoj", "Raj", "Vikram", "Rohan", "Dev", "Kabir", "Karan")
first_names_female <- c("Diya", "Sanya", "Kavya", "Aanya", "Ananya", "Ishita", "Sneha", "Neha", "Pooja", "Anita", "Sunita", "Priya", "Riya", "Aditi", "Meera", "Tanvi", "Tara", "Shruti", "Ritu", "Swati")
last_names <- c("Sharma", "Verma", "Gupta", "Singh", "Kumar", "Patel", "Reddy", "Rao", "Nair", "Menon", "Iyer", "Joshi", "Das", "Bose", "Mukherjee", "Chatterjee", "Rajput", "Chauhan", "Bhat", "Mehta", "Shah", "Kulkarni", "Deshmukh", "Nambiar")

# 3. Create Unique Customer Cohort (~28,000 customers)
n_customers <- 28000
cat("Synthesizing", n_customers, "unique customer profiles...\n")

cust_regions <- sample(names(geo_hierarchy), n_customers, replace = TRUE, prob = c(0.28, 0.32, 0.22, 0.10, 0.05, 0.03))

cust_records <- vector("list", n_customers)
for (i in seq_len(n_customers)) {
  reg <- cust_regions[i]
  state_names <- names(geo_hierarchy[[reg]])
  st <- sample(state_names, 1)
  st_obj <- geo_hierarchy[[reg]][[st]]
  ct <- sample(st_obj$cities, 1)
  pin <- sample(st_obj$pin_range, 1)
  
  gender_roll <- runif(1)
  if (gender_roll < 0.52) {
    g <- "Male"
    fn <- sample(first_names_male, 1)
  } else if (gender_roll < 0.98) {
    g <- "Female"
    fn <- sample(first_names_female, 1)
  } else {
    g <- "Other"
    fn <- sample(c(first_names_male, first_names_female), 1)
  }
  
  cust_records[[i]] <- list(
    Customer_ID = sprintf("CUST-%05d", 10000 + i),
    Customer_Name = paste(fn, sample(last_names, 1)),
    Gender = g,
    Age = sample(18:72, 1, prob = c(rep(0.015, 4), rep(0.035, 12), rep(0.025, 15), rep(0.012, 24))),
    Region = reg,
    State = st,
    City = ct,
    PIN_Code = pin
  )
}
customers_dt <- rbindlist(cust_records)

# 4. Generate Order Baskets with Macro-Trends and Indian Seasonality
# Target ~115,000 Orders, yielding ~160,000 transaction line rows
n_orders_target <- 115000
cat("Synthesizing orders across 36 completed months (2023-01-01 to 2025-12-31)...\n")

all_dates <- seq(as.Date("2023-01-01"), as.Date("2025-12-31"), by = "day")

# Date Weighting for realistic e-commerce growth & Diwali peaks
date_weights <- sapply(all_dates, function(d) {
  y <- year(d)
  m <- month(d)
  w <- wday(d) # 1=Sun, 7=Sat
  
  # Base growth trend: 2023 base (1.0), 2024 (1.18), 2025 (1.38)
  y_factor <- if (y == 2023) 1.0 else if (y == 2024) 1.18 else 1.38
  
  # Monthly seasonality in India:
  # Oct (m=10) & Nov (m=11): Great Indian Festival / Diwali Shopping Peaks
  # Jan (m=1): Republic Day Sale
  # May (m=5): Great Summer Sale
  # Aug (m=8): Independence Day Sale
  m_factor <- if (m %in% c(10, 11)) 1.95 else if (m == 5) 1.30 else if (m %in% c(1, 8)) 1.25 else if (m %in% c(6, 7)) 0.88 else 1.05
  
  # Weekend shopping boost (Saturday/Sunday)
  w_factor <- if (w %in% c(1, 7)) 1.25 else 1.0
  
  return(y_factor * m_factor * w_factor)
})
date_weights <- date_weights / sum(date_weights)

# Customer frequency assignment (Pareto power-law distribution)
# 55% 1-order, 28% 2-3 orders, 12% 4-7 orders, 5% 8-16 orders (VIP / Champions)
cust_weight <- rep(1, n_customers)
# Give 5% of customers high repeat propensity
vip_cust_indices <- sample(seq_len(n_customers), n_customers * 0.05)
cust_weight[vip_cust_indices] <- 12.0
potential_loyal_indices <- sample(setdiff(seq_len(n_customers), vip_cust_indices), n_customers * 0.20)
cust_weight[potential_loyal_indices] <- 3.5
cust_weight <- cust_weight / sum(cust_weight)

order_customers <- sample(customers_dt$Customer_ID, n_orders_target, replace = TRUE, prob = cust_weight)
order_dates <- sample(all_dates, n_orders_target, replace = TRUE, prob = date_weights)

payment_methods <- c("UPI", "Credit Card", "Debit Card", "Net Banking", "Cash on Delivery", "Wallet")
payment_probs   <- c(0.44, 0.24, 0.14, 0.08, 0.07, 0.03)

order_statuses  <- c("Delivered", "Delivered", "Delivered", "Delivered", "Shipped", "Processing", "Returned", "Cancelled")
status_probs    <- c(0.45, 0.25, 0.08, 0.04, 0.07, 0.05, 0.04, 0.02)

cat("Generating transaction line items and basket affinities...\n")

# Determine basket size for each order:
# 60% 1 item, 28% 2 items, 9% 3 items, 3% 4 items
basket_sizes <- sample(1:4, n_orders_target, replace = TRUE, prob = c(0.60, 0.28, 0.09, 0.03))

# Pre-index product dt by name
setkey(prod_dt, Product_Name)
prod_names_all <- prod_dt$Product_Name

order_lines_list <- vector("list", n_orders_target)

for (ord_idx in seq_len(n_orders_target)) {
  oid <- sprintf("ORD-%06d", 200000 + ord_idx)
  odate <- order_dates[ord_idx]
  cid <- order_customers[ord_idx]
  pm <- sample(payment_methods, 1, prob = payment_probs)
  st <- sample(order_statuses, 1, prob = status_probs)
  
  bsize <- basket_sizes[ord_idx]
  
  # Select products
  chosen_prods <- character(0)
  if (bsize > 1 && runif(1) < 0.65) {
    # 65% of multi-item orders pick from affinity sets (for Apriori mining!)
    aff_set <- sample(affinity_pairs, 1)[[1]]
    num_from_aff <- min(bsize, length(aff_set))
    chosen_prods <- sample(aff_set, num_from_aff, replace = FALSE)
    if (length(chosen_prods) < bsize) {
      rem <- sample(setdiff(prod_names_all, chosen_prods), bsize - length(chosen_prods))
      chosen_prods <- c(chosen_prods, rem)
    }
  } else {
    chosen_prods <- sample(prod_names_all, bsize, replace = FALSE)
  }
  
  lines_dt <- prod_dt[chosen_prods]
  
  # Quantity: mostly 1 or 2, rarely 3 to 5
  q_vec <- sample(1:5, bsize, replace = TRUE, prob = c(0.68, 0.22, 0.06, 0.025, 0.015))
  
  # Discount: 0%, 5%, 10%, 15%, 20%, 25%, 30%
  disc_vec <- sample(c(0, 5, 10, 15, 20, 25, 30), bsize, replace = TRUE, prob = c(0.38, 0.16, 0.15, 0.13, 0.10, 0.05, 0.03))
  
  order_lines_list[[ord_idx]] <- data.table(
    Order_ID = oid,
    Order_Date = odate,
    Customer_ID = cid,
    Product_ID = lines_dt$Product_ID,
    Product_Name = lines_dt$Product_Name,
    Category = lines_dt$Category,
    Unit_Price_INR = lines_dt$Unit_Price_INR,
    Unit_Cost_INR = lines_dt$Unit_Cost_INR,
    Stock_Quantity = lines_dt$Stock_Quantity,
    Quantity = q_vec,
    Discount_Percent = disc_vec,
    Payment_Method = pm,
    Order_Status = st
  )
}

dt_all <- rbindlist(order_lines_list)
cat("Combined raw order lines:", nrow(dt_all), "records.\n")

# 5. Join Customer Demographics
cat("Joining customer demographic attributes...\n")
setkey(customers_dt, Customer_ID)
setkey(dt_all, Customer_ID)
dt_final <- customers_dt[dt_all]

# 6. Exact Mathematical Calculations
cat("Calculating mathematically consistent financial metrics...\n")
# Sales_INR = round(Quantity * Unit_Price_INR * (1 - Discount_Percent / 100), 2)
dt_final[, Sales_INR := round(Quantity * Unit_Price_INR * (1 - Discount_Percent / 100), 2)]
dt_final[, Cost_INR := round(Quantity * Unit_Cost_INR, 2)]
dt_final[, Profit_INR := round(Sales_INR - Cost_INR, 2)]
dt_final[, Profit_Margin := round((Profit_INR / Sales_INR) * 100, 2)]

# Derived Temporal Attributes
dt_final[, Order_Month := month(Order_Date)]
dt_final[, Order_Year := year(Order_Date)]
dt_final[, Order_Quarter := quarter(Order_Date)]
dt_final[, Customer_Type := ifelse(Order_Status == "Delivered", "Active", "Inactive")]

# Remove internal Unit_Cost_INR
dt_final[, Unit_Cost_INR := NULL]

# 7. Intentional Quality Micro-Telemetry
# Inject tiny intentional missing values (30 cells out of >4 million) for Data Profiling
cat("Injecting intentional data quality telemetry (30 missing cells for profiling detection)...\n")
sample_missing_pin <- sample(seq_len(nrow(dt_final)), 15)
sample_missing_age <- sample(seq_len(nrow(dt_final)), 15)
dt_final[sample_missing_pin, PIN_Code := NA_integer_]
dt_final[sample_missing_age, Age := NA_integer_]

# 8. Align column order to standard canonical order
canonical_cols <- c(
  "Order_ID", "Order_Date", "Customer_ID", "Product_ID", "Quantity",
  "Discount_Percent", "Payment_Method", "Order_Status", "Region", "State",
  "City", "Category", "Product_Name", "Unit_Price_INR", "Customer_Name",
  "Age", "Gender", "PIN_Code", "Stock_Quantity", "Sales_INR", "Cost_INR",
  "Profit_INR", "Profit_Margin", "Order_Month", "Order_Year", "Order_Quarter",
  "Customer_Type"
)

setcolorder(dt_final, canonical_cols)

# 9. Write to datasets/advanced_ecommerce_dataset.csv
out_path <- "datasets/advanced_ecommerce_dataset.csv"
cat("Writing dataset to:", out_path, "...\n")
fwrite(dt_final, out_path)

file_info <- file.info(out_path)
size_mb <- round(file_info$size / (1024 * 1024), 2)

cat("\n=================================================================\n")
cat("SUCCESSFULLY GENERATED ADVANCED E-COMMERCE DATASET\n")
cat("File Path:       ", out_path, "\n")
cat("Total Rows:      ", nrow(dt_final), "\n")
cat("Total Columns:   ", ncol(dt_final), "\n")
cat("File Size:       ", size_mb, "MB\n")
cat("Date Range:      ", as.character(min(dt_final$Order_Date)), "to", as.character(max(dt_final$Order_Date)), "\n")
cat("Total Orders:    ", uniqueN(dt_final$Order_ID), "\n")
cat("Total Customers: ", uniqueN(dt_final$Customer_ID), "\n")
cat("Multi-item Orders:", sum(dt_final[, .N, by = Order_ID]$N > 1), "\n")
cat("Total Revenue:   ₹", round(sum(dt_final$Sales_INR) / 1e7, 2), "Crores\n")
cat("Total Profit:    ₹", round(sum(dt_final$Profit_INR) / 1e7, 2), "Crores\n")
cat("Profit Margin:   ", round((sum(dt_final$Profit_INR) / sum(dt_final$Sales_INR)) * 100, 2), "%\n")
cat("Missing Cells:   ", sum(sapply(dt_final, function(x) sum(is.na(x)))), "\n")
cat("=================================================================\n")
