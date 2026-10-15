# run_analysis.R

cat("=========================================\n")
cat("E-Commerce Big Data Analytics Pipeline\n")
cat("=========================================\n")

# Ensure output directory exists
if (!dir.exists("output")) {
  dir.create("output")
}
if (!dir.exists("reports")) {
  dir.create("reports")
}

# Source all analytical modules
source("R/data_processing.R")
source("R/sales_analysis.R")
source("R/product_analysis.R")
source("R/customer_analysis.R")
source("R/regional_analysis.R")
source("R/rfm_analysis.R")
source("R/association_rules.R")
source("R/forecasting.R")
source("R/universal_analysis.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  dataset_path <- args[1]
  cat("Using dataset path:", dataset_path, "\n")
} else {
  dataset_path <- "data/indian_ecommerce_data.csv"
  cat("Using default dataset:", dataset_path, "\n")
}
dataset_name <- if (length(args) >= 2) args[2] else basename(dataset_path)
cat("Dataset identity:", dataset_name, "\n")

# Main execution block
cat("Step 1: Processing data...\n")
dt <- process_data(dataset_path, dataset_name)

cat("Step 2: Generating analytical outputs...\n")
run_sales_analysis(dt)
run_product_analysis(dt)
run_customer_analysis(dt)
run_regional_analysis(dt)
run_rfm_analysis(dt)
run_association_rules(dt)
run_forecasting(dt)
run_universal_analysis(dt)

cat("Step 3: Generating CSV Reports...\n")
fwrite(dt, "reports/full_data_cleaned.csv")
cat("Step 4: Generating consolidated analytics.json...\n")
source("R/generate_analytics_json.R")
cat("=========================================\n")
cat("=========================================\n")
