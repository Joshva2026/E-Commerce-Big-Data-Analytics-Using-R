# product_analysis.R
run_product_analysis <- function(dt) {
  cat("Running product analysis...\n")
  
  if (!"Sales_INR" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Product analysis requires Sales fields."), "output/products.json", auto_unbox = TRUE)
    return()
  }
  
  has_product <- "Product_Name" %in% names(dt)
  has_category <- "Category" %in% names(dt)
  
  if (!has_product && !has_category) {
    write_json(list(available = FALSE, reason = "Product analysis requires Product or Category fields."), "output/products.json", auto_unbox = TRUE)
    return()
  }
  
  products_summary <- list(available = TRUE)
  
  if (has_category) {
    cat_sales <- dt[, .(Sales = sum(Sales_INR, na.rm = TRUE)), by = Category][order(-Sales)]
    products_summary$category_sales <- list(
      categories = cat_sales$Category,
      sales = cat_sales$Sales
    )
  }
  
  if (has_product) {
    # If Product_ID isn't present, just group by Product_Name
    if ("Product_ID" %in% names(dt)) {
        top_prods <- dt[, .(Sales = sum(Sales_INR, na.rm = TRUE)), by = .(Product_ID, Product_Name)][order(-Sales)]
    } else {
        top_prods <- dt[, .(Sales = sum(Sales_INR, na.rm = TRUE)), by = Product_Name][order(-Sales)]
    }
    top_prods <- head(top_prods[!is.na(Product_Name)], 10)
    products_summary$top_products <- list(
      names = top_prods$Product_Name,
      sales = top_prods$Sales
    )
  }
  
  write_json(products_summary, "output/products.json", auto_unbox = TRUE)
}
