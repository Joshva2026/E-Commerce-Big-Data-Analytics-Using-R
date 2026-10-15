# forecasting.R
suppressMessages(library(forecast))

run_forecasting <- function(dt) {
  cat("Running sales forecasting...\n")
  
  if (!"Order_Date" %in% names(dt) || !"Sales_INR" %in% names(dt)) {
    write_json(list(available = FALSE, reason = "Forecasting requires Date and Sales fields."), "output/forecast.json", auto_unbox = TRUE)
    return()
  }
  
  dt_copy <- copy(dt)
  dt_copy[, Month := floor_date(Order_Date, "month")]
  monthly_sales <- dt_copy[, .(Sales = sum(Sales_INR, na.rm=TRUE)), by = Month][order(Month)]
  
  # Determine if the latest month is complete
  max_date <- max(dt_copy$Order_Date, na.rm=TRUE)
  last_day_of_max_month <- ceiling_date(max_date, "month") - days(1)
  is_complete <- as.Date(max_date) == as.Date(last_day_of_max_month)
  
  if (!is_complete) {
    incomplete_month <- floor_date(max_date, "month")
    monthly_sales <- monthly_sales[Month < incomplete_month]
  }
  
  if(nrow(monthly_sales) < 12) {
    write_json(list(available = FALSE, reason = "Insufficient completed historical periods for forecasting. At least 12 months required."), "output/forecast.json", auto_unbox = TRUE)
    return()
  }
  
  start_year <- year(min(monthly_sales$Month))
  start_month <- month(min(monthly_sales$Month))
  
  ts_sales <- ts(monthly_sales$Sales, start = c(start_year, start_month), frequency = 12)
  fit <- auto.arima(ts_sales)
  fc <- forecast(fit, h = 6, level = 95)
  
  model_name <- fit$arma
  model_str <- fit$method
  if (is.null(model_str) || model_str == "") {
      model_str <- capture.output(print(fit))[2]
  }
  
  last_date <- max(monthly_sales$Month)
  fc_dates <- seq(last_date %m+% months(1), by = "month", length.out = 6)
  
  forecast_summary <- list(
    available = TRUE,
    historical = list(
      dates = as.character(monthly_sales$Month),
      sales = monthly_sales$Sales
    ),
    forecast = list(
      dates = as.character(fc_dates),
      values = as.numeric(fc$mean),
      lower = as.numeric(fc$lower[,1]),
      upper = as.numeric(fc$upper[,1])
    ),
    metadata = list(
      model = as.character(model_str),
      training_last_complete_month = as.character(last_date),
      forecast_horizon_months = 6,
      confidence_level = 0.95
    )
  )
  
  write_json(forecast_summary, "output/forecast.json", auto_unbox = TRUE)
}
