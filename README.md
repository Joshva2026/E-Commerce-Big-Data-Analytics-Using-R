# E-Commerce Big Data Analytics and Customer Behavior Analysis Using R

An academic, production-ready Big Data Analytics web application where **R (v4.6.1)** serves as the high-performance statistical and predictive engine, decoupled from a modern **Google Stitch UI** presentation layer and coordinated via a lightweight Python orchestrator.

---

## Key Highlights

- **Pure R Computational Core**: All descriptive, diagnostic, predictive, and prescriptive analytics are executed in R using vectorized `data.table`, `lubridate`, `arules`, `forecast`, and `jsonlite`.
- **Google Stitch Design Integration**: Seamless, responsive UI with executive KPI cards, financial ledgers, interactive multi-chart dashboards, and full-page scrolling.
- **Universal Dataset Ingestion**: Automatic semantic column detection for custom CSV/XLSX uploads, dynamically deriving Sales, Profit, RFM metrics, and inventory health.
- **Advanced Predictive Modeling**: 36-month completed longitudinal time series forecasting via `auto.arima` with 95% confidence intervals and multi-item market basket association rules via Apriori.
- **Zero Heavy Backend Dependencies**: No Node.js build steps or Shiny runtime needed; pure web standard HTML5/CSS3/Vanilla JS with Chart.js 4.4 and a native Python HTTP daemon.

---

## Datasets

1. **Master Curated Demo Dataset** ([`data/indian_ecommerce_data.csv`](data/indian_ecommerce_data.csv)):
   - **150,000 transaction records** across 26 dimensions.
   - Comprehensive Indian regional mapping (North, South, East, West, Central, North-East).

2. **Advanced Multi-Basket & Forecasting Dataset** ([`datasets/advanced_ecommerce_dataset.csv`](datasets/advanced_ecommerce_dataset.csv)):
   - **178,383 records** (37.64 MB) spanning 3 complete years (2023-01-01 to 2025-12-31).
   - **46,212 multi-item order baskets** (40.2%) engineered with real product affinities for statistical Apriori association mining.
   - **36 consecutive months** of chronological e-commerce growth and festive seasonality (Diwali Q4 peak) for ARIMA forecasting.
   - **25,150 customers** with 77% repeat customer propensity and distinct RFM behavioral segments.
   - **Inventory telemetry** with low-stock threshold monitoring on on-hand catalog units.

---

## System Architecture

```text
┌────────────────────────────────────────────────────────┐
│             Google Stitch UI (web/index.html)          │
│       HTML5 • Tailwind Tokens • Vanilla JS • Chart.js  │
└───────────────────────────▲────────────────────────────┘
                            │ REST JSON Contract / HTTP
┌───────────────────────────▼────────────────────────────┐
│      Python Orchestrator (tools/local_server.py)       │
│         Dynamic Port Binding • Streaming Uploads       │
└───────────────────────────▲────────────────────────────┘
                            │ Subprocess IPC
┌───────────────────────────▼────────────────────────────┐
│              R Analytical Pipeline Core                │
│    R/data_processing.R  •  R/sales_analysis.R          │
│    R/customer_analysis.R • R/rfm_analysis.R            │
│    R/association_rules.R • R/forecasting.R             │
│    R/product_analysis.R  • R/regional_analysis.R       │
│    R/universal_analysis.R • R/generate_analytics_json.R│
└────────────────────────────────────────────────────────┘
```

---

## Local Setup & Execution

### Prerequisites
- **R (4.0+)**: Install packages `data.table`, `lubridate`, `jsonlite`, `readxl`, `arules`, `forecast`.
- **Python (3.9+)**: Standard library only (no pip packages required).

### Quick Start
```bash
# 1. Run the local analytical server
python tools/local_server.py

# 2. Open dashboard in your browser
# URL: http://localhost:8001/
```

---

## Local Execution & Offline Operation

This application is strictly designed to execute locally on your Windows environment without external cloud dependencies:

- **Frontend**: Served locally from `web/` over `http://localhost:8001/` via the built-in HTTP daemon.
- **API Orchestrator**: Python `tools/local_server.py` handles dataset routing, streaming uploads, and subprocess execution.
- **Analytical Core**: High-performance R engine (R 4.6.1) executes data munging, RFM segmentation, Apriori association rules, and ARIMA forecasting natively on your machine.
- **Data Privacy & Isolation**: All datasets (`data/` and `datasets/`), uploads, and analytical JSON outputs remain strictly on your local disk.


