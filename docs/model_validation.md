# Forecasting and Model Validation

## Why Forecasting Was Added

Forecasting was added to estimate near-term DAU and support LiveOps planning. A forecast does not replace metric monitoring, but it helps answer:

- What DAU level should we expect over the next 30 days?
- Are current activity levels above or below a reasonable baseline?
- Which trend alerts should be treated as urgent?

## Why Simple Baselines Were Used First

The project uses explainable baseline models before complex models. This is intentional.

Simple baselines are:

- Easy to explain in interviews.
- Fast to validate.
- Hard to overfit.
- Useful as a benchmark for future advanced models.

A more complex model should only be used if it clearly beats these baselines in fair backtesting.

## Models Evaluated

### `naive_1d`

Forecasts tomorrow using the latest observed DAU.

### `moving_avg_7d`

Forecasts using the average DAU over the latest 7 training days.

### `seasonal_naive_7d`

Forecasts using the latest available same-weekday DAU from training history.

### `moving_avg_30d`

Forecasts using the average DAU over the latest 30 training days.

## Rolling-Origin Backtesting

Rolling-origin backtesting simulates how the model would perform over time:

1. Train on a historical window.
2. Forecast the next 30 days.
3. Compare forecast values with actual DAU.
4. Move the training window forward.
5. Repeat.

This project used:

- Minimum train period: 180 days
- Forecast horizon: 30 days
- Step size: 30 days
- Backtest windows: 31

## Why Random Split Is Not Used

Random train/test split is not appropriate for time series because it can leak future information into training. In forecasting, the model should only use data that would have existed before the forecast date.

## Champion Model Selection

The champion model is selected by:

1. Lowest sMAPE
2. Then lowest MAE

This keeps the selection both percentage-aware and interpretable in DAU units.

## Actual Champion Model and Metrics

Champion model: `moving_avg_30d`

Validation metrics:

- MAE: **267.29**
- RMSE: **459.09**
- MAPE: **14.43%**
- sMAPE: **17.36%**
- Bias: **-16.82**

The final forecast covers `2009-01-11` to `2009-02-09`.

## Metric Explanations

### MAE

Mean Absolute Error. Average absolute difference between forecast DAU and actual DAU.

Example: MAE 267 means the model is off by about 267 avatars on average.

### RMSE

Root Mean Squared Error. Similar to MAE but penalizes larger errors more strongly.

### MAPE

Mean Absolute Percentage Error. Shows error as a percentage of actual DAU.

Limitation: rows with actual DAU equal to zero must be excluded.

### sMAPE

Symmetric Mean Absolute Percentage Error. A more balanced percentage error metric when actual and forecast values vary.

## Forecast Limitations

The forecast is an explainable baseline, not a production ML forecast.

Known missing inputs:

- No patch calendar
- No marketing campaign data
- No game event metadata
- No expansion or content release calendar
- No revenue data
- No acquisition channel data

These missing inputs can explain sudden spikes or drops that a simple historical model cannot predict.

## How to Improve the Model in V2

Potential improvements:

- Add patch, content, and event calendar features.
- Add marketing campaign and acquisition signals.
- Compare additional models such as SARIMAX, Prophet-style additive models, gradient boosting, or hierarchical forecasts.
- Forecast segment-level DAU, not only total DAU.
- Add prediction interval calibration.
- Validate forecast performance by period, weekday, and event windows.
- Build champion/challenger model monitoring.
