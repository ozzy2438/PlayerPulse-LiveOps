from __future__ import annotations

from pathlib import Path

import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
SAMPLE_DIR = PROJECT_ROOT / "data" / "sample"


DATASETS = {
    "kpi": ("dashboard_kpi_summary.parquet", "dashboard_kpi_summary.csv"),
    "retention": ("dashboard_retention_summary.parquet", "dashboard_retention_summary.csv"),
    "segments": ("dashboard_segment_summary.parquet", "dashboard_segment_summary.csv"),
    "forecast_summary": ("dashboard_forecast_summary.parquet", "dashboard_forecast_summary.csv"),
    "recommendations": ("mart_liveops_recommendations.parquet", "mart_liveops_recommendations.csv"),
    "daily": ("agg_daily_metrics.parquet", "agg_daily_metrics.csv"),
    "cohorts": ("agg_cohort_retention.parquet", "agg_cohort_retention.csv"),
    "segment_monthly": ("agg_segment_monthly.parquet", "agg_segment_monthly.csv"),
    "forecast_daily": ("mart_forecast_daily.parquet", "mart_forecast_daily.csv"),
    "alerts": ("mart_trend_alerts.parquet", "mart_trend_alerts.csv"),
}


DATE_COLUMNS = {
    "activity_date",
    "cohort_date",
    "snapshot_date",
    "forecast_date",
    "forecast_created_at",
    "alert_date",
    "recommendation_date",
    "latest_activity_date",
    "latest_eligible_cohort_date",
    "final_forecast_start_date",
    "final_forecast_end_date",
}


st.set_page_config(
    page_title="PlayerPulse LiveOps",
    layout="wide",
)


def _parse_dates(df: pd.DataFrame) -> pd.DataFrame:
    for column in df.columns:
        if column in DATE_COLUMNS or column.endswith("_date"):
            df[column] = pd.to_datetime(df[column], errors="coerce")
    return df


@st.cache_data(show_spinner=False)
def load_table(name: str) -> tuple[pd.DataFrame, str]:
    parquet_name, csv_name = DATASETS[name]
    parquet_path = PROCESSED_DIR / parquet_name
    csv_path = SAMPLE_DIR / csv_name

    if parquet_path.exists():
        return _parse_dates(pd.read_parquet(parquet_path)), f"processed/{parquet_name}"
    if csv_path.exists():
        return _parse_dates(pd.read_csv(csv_path)), f"sample/{csv_name}"
    return pd.DataFrame(), f"missing: {parquet_name}"


@st.cache_data(show_spinner=False)
def load_retention_curve_summary() -> tuple[pd.DataFrame, str]:
    parquet_path = PROCESSED_DIR / "agg_retention_curve.parquet"
    sample_path = SAMPLE_DIR / "retention_curve_summary.csv"

    if parquet_path.exists():
        con = duckdb.connect()
        df = con.execute(
            f"""
            SELECT
                cohort_age_day,
                AVG(retention_rate) AS avg_retention_rate,
                SUM(retained_avatars) AS retained_avatars,
                SUM(cohort_size) AS cohort_size_base
            FROM read_parquet('{parquet_path.as_posix()}')
            WHERE cohort_age_day BETWEEN 0 AND 30
            GROUP BY 1
            ORDER BY 1
            """
        ).df()
        return df, "processed/agg_retention_curve.parquet aggregated"

    if sample_path.exists():
        return pd.read_csv(sample_path), "sample/retention_curve_summary.csv"

    return pd.DataFrame(), "missing: agg_retention_curve.parquet"


def fmt_int(value) -> str:
    if pd.isna(value):
        return "n/a"
    return f"{int(round(float(value))):,}"


def fmt_num(value, digits: int = 2) -> str:
    if pd.isna(value):
        return "n/a"
    return f"{float(value):,.{digits}f}"


def fmt_pct(value, digits: int = 1) -> str:
    if pd.isna(value):
        return "n/a"
    return f"{float(value) * 100:.{digits}f}%"


def require_data(data: dict[str, pd.DataFrame], names: list[str]) -> bool:
    missing = [name for name in names if data[name].empty]
    if missing:
        st.error(f"Missing dashboard input tables: {', '.join(missing)}")
        st.info("Run the pipeline outputs locally or use the included data/sample CSV files.")
        return False
    return True


@st.cache_data(show_spinner=False)
def load_all_data() -> tuple[dict[str, pd.DataFrame], dict[str, str]]:
    data: dict[str, pd.DataFrame] = {}
    sources: dict[str, str] = {}
    for name in DATASETS:
        data[name], sources[name] = load_table(name)
    data["retention_curve"], sources["retention_curve"] = load_retention_curve_summary()
    return data, sources


def render_header(sources: dict[str, str]) -> None:
    st.title("PlayerPulse LiveOps")
    st.caption("MMORPG Player Segmentation, Retention & Forecasting Analytics")
    with st.expander("Data sources used"):
        source_df = pd.DataFrame(
            [{"table": name, "source": source} for name, source in sources.items()]
        )
        st.dataframe(source_df, use_container_width=True, hide_index=True)


def page_executive_summary(data: dict[str, pd.DataFrame]) -> None:
    st.header("Executive Summary")
    st.write(
        "A compact operating view for player activity, alert status, and the highest-priority LiveOps actions."
    )
    if not require_data(data, ["kpi", "recommendations"]):
        return

    kpi = data["kpi"].iloc[0]
    cols = st.columns(7)
    cols[0].metric("Latest DAU", fmt_int(kpi["latest_dau"]))
    cols[1].metric("Latest WAU", fmt_int(kpi["latest_wau"]))
    cols[2].metric("Latest MAU", fmt_int(kpi["latest_mau"]))
    cols[3].metric("Stickiness", fmt_pct(kpi["latest_stickiness"]))
    cols[4].metric("30D Avg DAU", fmt_int(kpi["avg_dau_30d"]))
    cols[5].metric("Active Alerts", fmt_int(kpi["active_alert_count"]))
    cols[6].metric("High Alerts", fmt_int(kpi["high_alert_count"]))

    st.subheader("Top Recommendations")
    recs = data["recommendations"].sort_values("priority_rank").head(4)
    for _, rec in recs.iterrows():
        with st.container(border=True):
            st.markdown(
                f"**Priority {int(rec['priority_rank'])} - {rec['severity'].title()} - {rec['target_segment']}**"
            )
            st.write(rec["issue_detected"])
            st.success(rec["recommended_action"])
            st.caption(
                f"Evidence: {rec['evidence_metric']} changed by {fmt_pct(rec['pct_change'])}"
            )


def page_player_activity(data: dict[str, pd.DataFrame]) -> None:
    st.header("Player Activity")
    st.write("Daily activity, monthly reach, stickiness, and lifecycle flow counts.")
    if not require_data(data, ["daily"]):
        return

    daily = data["daily"].sort_values("activity_date")
    activity_long = daily.melt(
        id_vars="activity_date",
        value_vars=["dau", "mau"],
        var_name="metric",
        value_name="avatars",
    )
    fig = px.line(activity_long, x="activity_date", y="avatars", color="metric", title="DAU and MAU Over Time")
    st.plotly_chart(fig, use_container_width=True)

    fig = px.line(
        daily,
        x="activity_date",
        y="dau_mau_stickiness",
        title="DAU/MAU Stickiness Over Time",
    )
    st.plotly_chart(fig, use_container_width=True)

    lifecycle_long = daily.melt(
        id_vars="activity_date",
        value_vars=["new_avatars", "returning_avatars", "reactivated_avatars_30d"],
        var_name="avatar_flow",
        value_name="avatars",
    )
    fig = px.area(
        lifecycle_long,
        x="activity_date",
        y="avatars",
        color="avatar_flow",
        title="New, Returning, and Reactivated Avatars",
    )
    st.plotly_chart(fig, use_container_width=True)


def page_retention(data: dict[str, pd.DataFrame]) -> None:
    st.header("Retention & Cohorts")
    st.write(
        "Cohorts group avatars by first seen date. Retention is exact-day return activity, with early burn-in and immature cohorts handled upstream."
    )
    if not require_data(data, ["retention"]):
        return

    retention = data["retention"].sort_values("cohort_date")
    first = retention.iloc[0]
    cols = st.columns(4)
    cols[0].metric("Avg D1 Retention", fmt_pct(first["average_d1_retention"]))
    cols[1].metric("Avg D7 Retention", fmt_pct(first["average_d7_retention"]))
    cols[2].metric("Avg D14 Retention", fmt_pct(first["average_d14_retention"]))
    cols[3].metric("Avg D30 Retention", fmt_pct(first["average_d30_retention"]))

    retention_long = retention.melt(
        id_vars="cohort_date",
        value_vars=["d1_retention", "d7_retention", "d14_retention", "d30_retention"],
        var_name="retention_metric",
        value_name="retention_rate",
    )
    fig = px.line(
        retention_long,
        x="cohort_date",
        y="retention_rate",
        color="retention_metric",
        title="Retention Trend by Cohort Date",
    )
    fig.update_yaxes(tickformat=".0%")
    st.plotly_chart(fig, use_container_width=True)

    curve = data["retention_curve"]
    if not curve.empty:
        fig = px.line(
            curve,
            x="cohort_age_day",
            y="avg_retention_rate",
            markers=True,
            title="Average Retention Curve, Day 0-30",
        )
        fig.update_yaxes(tickformat=".0%")
        st.plotly_chart(fig, use_container_width=True)

    st.info(
        "Burn-in removes early dataset days that may contain already-existing avatars. Immature cohorts are excluded when they have not had enough time to reach D1/D7/D14/D30."
    )


def page_lifecycle_segments(data: dict[str, pd.DataFrame]) -> None:
    st.header("Lifecycle Segments")
    st.write("Monthly snapshot segmentation shows how player lifecycle groups change over time.")
    if not require_data(data, ["segments", "segment_monthly"]):
        return

    segments = data["segments"].sort_values("segment_size", ascending=False)
    fig = px.bar(
        segments,
        x="lifecycle_segment",
        y="segment_size",
        color="lifecycle_segment",
        title="Latest Segment Distribution",
    )
    st.plotly_chart(fig, use_container_width=True)

    addressable = segments.dropna(subset=["addressable_segment_share"]).copy()
    fig = px.pie(
        addressable,
        names="lifecycle_segment",
        values="addressable_segment_share",
        title="Addressable Distribution Excluding Lapsed Players",
    )
    st.plotly_chart(fig, use_container_width=True)

    monthly = data["segment_monthly"].sort_values("snapshot_date")
    fig = px.line(
        monthly,
        x="snapshot_date",
        y="segment_size",
        color="lifecycle_segment",
        title="Segment Size Trend Over Monthly Snapshots",
    )
    st.plotly_chart(fig, use_container_width=True)

    change = segments.sort_values("segment_size_change_3mo")
    fig = px.bar(
        change,
        x="segment_size_change_3mo",
        y="lifecycle_segment",
        orientation="h",
        color="segment_size_change_3mo",
        title="Latest 3-Month Segment Change",
    )
    st.plotly_chart(fig, use_container_width=True)


def page_forecasting(data: dict[str, pd.DataFrame]) -> None:
    st.header("Forecasting")
    st.write("Explainable baseline forecasting for DAU with rolling-origin validation.")
    if not require_data(data, ["daily", "forecast_summary", "forecast_daily"]):
        return

    forecast = data["forecast_summary"].sort_values("forecast_date")
    summary = forecast.iloc[0]
    cols = st.columns(4)
    cols[0].metric("Champion Model", summary["champion_model"])
    cols[1].metric("MAE", fmt_num(summary["champion_mae"]))
    cols[2].metric("RMSE", fmt_num(summary["champion_rmse"]))
    cols[3].metric("sMAPE", fmt_pct(summary["champion_smape"]))

    daily = data["daily"].sort_values("activity_date")
    history = daily[["activity_date", "dau"]].tail(180).rename(columns={"activity_date": "date", "dau": "value"})
    history["series"] = "Actual DAU"
    future = data["forecast_daily"][["forecast_date", "forecast_value"]].rename(
        columns={"forecast_date": "date", "forecast_value": "value"}
    )
    future["series"] = "Forecast DAU"
    plot_df = pd.concat([history, future], ignore_index=True)

    fig = px.line(plot_df, x="date", y="value", color="series", title="Actual DAU History and 30-Day Forecast")
    fig.add_trace(
        go.Scatter(
            x=forecast["forecast_date"],
            y=forecast["upper_bound_simple"],
            mode="lines",
            line=dict(width=0),
            showlegend=False,
            name="Upper bound",
        )
    )
    fig.add_trace(
        go.Scatter(
            x=forecast["forecast_date"],
            y=forecast["lower_bound_simple"],
            mode="lines",
            fill="tonexty",
            line=dict(width=0),
            fillcolor="rgba(80, 120, 200, 0.18)",
            name="Simple bounds",
        )
    )
    st.plotly_chart(fig, use_container_width=True)


def page_alerts_recommendations(data: dict[str, pd.DataFrame]) -> None:
    st.header("Trend Alerts & LiveOps Recommendations")
    st.write("Triggered alerts are translated into ranked business actions for LiveOps follow-up.")
    if not require_data(data, ["alerts", "recommendations"]):
        return

    alerts = data["alerts"].sort_values(["alert_date", "severity"], ascending=[False, True])
    recs = data["recommendations"].sort_values("priority_rank")

    st.subheader("Trend Alerts")
    st.dataframe(alerts, use_container_width=True, hide_index=True)

    st.subheader("Recommendation Priority Table")
    st.dataframe(
        recs[
            [
                "priority_rank",
                "severity",
                "target_segment",
                "issue_detected",
                "evidence_metric",
                "pct_change",
                "recommended_action",
                "business_rationale",
            ]
        ],
        use_container_width=True,
        hide_index=True,
    )


def main() -> None:
    data, sources = load_all_data()
    render_header(sources)

    page = st.sidebar.radio(
        "Dashboard pages",
        [
            "Executive Summary",
            "Player Activity",
            "Retention & Cohorts",
            "Lifecycle Segments",
            "Forecasting",
            "Trend Alerts & Recommendations",
        ],
    )

    st.sidebar.markdown("---")
    st.sidebar.caption("Uses processed summary marts first, then data/sample CSV fallbacks.")

    if page == "Executive Summary":
        page_executive_summary(data)
    elif page == "Player Activity":
        page_player_activity(data)
    elif page == "Retention & Cohorts":
        page_retention(data)
    elif page == "Lifecycle Segments":
        page_lifecycle_segments(data)
    elif page == "Forecasting":
        page_forecasting(data)
    else:
        page_alerts_recommendations(data)


if __name__ == "__main__":
    main()
