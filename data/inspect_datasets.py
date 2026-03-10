# python3 inspect_datasets.py
# Comprehensive diagnostic analysis of OECD CbCR Tables I–VI
# Produces inspect_cbcr_results.json for use in the LaTeX annex
#
# OBS_STATUS semantics (SDMX 2.1 / OECD convention):
#   A = actual value (normal, available)
#   Q = provisional/preliminary
#   OBS_VALUE = NaN  → truly missing / confidentially suppressed

import json
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

BASE_DIR = Path(__file__).parent
RAW_DIR  = BASE_DIR / "raw" / "oecd_cbcr"
OUT_JSON = BASE_DIR / "inspect_cbcr_results.json"

# ---------------------------------------------------------------------------
# Human-readable label maps
# ---------------------------------------------------------------------------
MEASURE_LABELS = {
    "ASSETS":         "Tangible Assets (excl. cash)",
    "CBCR_COUNT":     "Number of CbCR filings",
    "EARNINGS":       "Earnings (payroll cost)",
    "EMPLOYEES":      "Number of Employees (FTE)",
    "ENTITIES_COUNT": "Number of Constituent Entities",
    "ETR":            "Effective Tax Rate",
    "PROFIT":         "Profit Before Tax",
    "PROFIT_ADJ":     "Adjusted Profit Before Tax",
    "RPR":            "Related-Party Revenue",
    "STATED_CAPITAL": "Stated Capital and Retained Earnings",
    "SUBGROUPS_COUNT":"Number of MNE Subgroups",
    "TAX_ACCRUED":    "Income Tax Accrued (current year)",
    "TAX_PAID":       "Income Tax Paid (cash basis)",
    "TOT_REV":        "Total Revenue (unrelated + related)",
    "UPR":            "Unrelated-Party Revenue",
    "ACT_ADMIN":      "Share: Administrative / Management services",
    "ACT_DOR":        "Share: Dormant",
    "ACT_FIN":        "Share: Finance / Insurance (internal)",
    "ACT_HOLDING":    "Share: Holding",
    "ACT_IGF":        "Share: Intra-group Finance",
    "ACT_INS":        "Share: Insurance",
    "ACT_IP":         "Share: Intellectual Property holding",
    "ACT_MAN":        "Share: Manufacturing / Production",
    "ACT_OTHER":      "Share: Other activities",
    "ACT_PUR":        "Share: Purchasing / Procurement",
    "ACT_RD":         "Share: Research \\& Development",
    "ACT_SALES":      "Share: Sales / Marketing / Distribution",
    "ACT_SER":        "Share: Services (excl. IP / R\\&D)",
}

UNIT_LABELS = {
    "USD":            "USD (millions, unless otherwise stated)",
    "PS":             "Number of persons",
    "EST":            "Number of entities / percentage share",
    "ENT_MULT":       "Number of entity-multiples",
    "PT_PRFT_BF_TAX": "Percentage of profit before tax",
}

STAT_OP_LABELS = {
    "_Z":     "Aggregate total (no distributional statistic)",
    "P5":     "5th percentile",
    "P10":    "10th percentile",
    "P25":    "25th percentile (lower quartile)",
    "P50":    "Median (50th percentile)",
    "P75":    "75th percentile (upper quartile)",
    "P90":    "90th percentile",
    "P95":    "95th percentile",
    "IQMEAN": "Interquartile mean (mean excluding bottom and top quartile)",
}

AGG_LABELS = {
    "TOTAL":   "Jurisdiction-level aggregate (all MNE groups combined)",
    "TRMNE":   "Aggregated by MNE group, categorised by reporting jurisdiction",
    "TRSUB":   "Aggregated by subsidiary location (affiliate jurisdiction)",
    "MNESIZE": "Disaggregated by MNE group consolidated revenue size class",
}

ETR_LABELS = {
    "_Z":                         "Not applicable (no ETR bracket)",
    "NEGATIVE_PROFIT":            "Negative profit (loss-making entities)",
    "NEGATIVE_PROFIT_TAX_ACCRUED":"Negative profit AND negative tax accrued",
    "NEGATIVE_TAX_ACCRUED":       "Negative tax accrued (tax credit / refund)",
    "RATE_0-10":                  "ETR bracket: 0--10\\%",
    "RATE_0-15":                  "ETR bracket: 0--15\\% (aggregate GMT-relevant bracket)",
    "RATE_10":                    "ETR bracket: 10--15\\% (taxed basis)",
    "RATE_10-20":                 "ETR bracket: 10--20\\%",
    "RATE_10_ACCRUED":            "ETR bracket: 10--15\\% (accrued-tax basis)",
    "RATE_15":                    "ETR bracket: 15--20\\%",
    "RATE_20":                    "ETR bracket: 20--30\\%",
    "RATE_20-30":                 "ETR bracket: 20--30\\%",
    "RATE_30":                    "ETR bracket: $>$30\\%",
}

SIZE_LABELS = {
    "_Z":              "Not applicable (no size stratification)",
    "SIZE_LESS_2_5":   "Consolidated revenue $<$ USD 2.5 billion",
    "SIZE_2_5-5":      "Consolidated revenue USD 2.5--5 billion",
    "SIZE_5-10":       "Consolidated revenue USD 5--10 billion",
    "SIZE_GREATER_10": "Consolidated revenue $>$ USD 10 billion",
    "SIZE_LESS_5":     "Consolidated revenue $<$ USD 5 billion (summary)",
    "SIZE_GREATER_5":  "Consolidated revenue $>$ USD 5 billion (summary)",
}

PANEL_LABELS = {
    "_T":       "All MNEs (Panel A-I and A-II combined)",
    "PANELAI":  "Panel A-I: profit-making MNEs only",
    "PANELAII": "Panel A-II: all MNEs including loss-making",
    "_Z":       "Not applicable (panel grouping not used)",
}

STATUS_LABELS = {
    "A": "Normal / actual value (OBS\\_STATUS: A)",
    "Q": "Provisional or preliminary value (OBS\\_STATUS: Q)",
}

TABLE_META = {
    1: {
        "file": "cbcr_table1_aggregate_totals.csv",
        "title": "Table I -- Aggregate Totals by Jurisdiction",
        "desc": (
            "The primary CbCR table. Reports jurisdiction-level aggregates and "
            "distributional percentiles (P5, P25, P50, P75, P95) for all "
            "financial and activity-share variables, cross-tabulated by parent "
            "jurisdiction (REF\\_AREA) and affiliate jurisdiction "
            "(COUNTERPART\\_AREA). Covers fiscal years 2016--2022."
        ),
    },
    2: {
        "file": "cbcr_table2_interquartile_means.csv",
        "title": "Table II -- Interquartile Means by Jurisdiction",
        "desc": (
            "Reports the interquartile mean (IQM) of financial variables -- "
            "the mean calculated after excluding the bottom and top quartile of "
            "MNE groups. Provides a robust central-tendency measure less sensitive "
            "to outlier MNEs. Activity-share measures (ACT\\_*) are excluded. "
            "Covers fiscal years 2017--2022."
        ),
    },
    3: {
        "file": "cbcr_table3_etr_aggregates.csv",
        "title": "Table III -- Entity Counts by ETR Bracket (MNE Level)",
        "desc": (
            "Reports the count of constituent entities and activity-share "
            "distributions by effective tax rate bracket, aggregated at the "
            "MNE-group level (TRMNE). This table captures how many entities "
            "are active in each ETR range, broken down by activity type. "
            "Financial totals (profit, assets, etc.) are not available in "
            "this table. Covers fiscal years 2017--2022."
        ),
    },
    4: {
        "file": "cbcr_table4_etr_aggregates_alt.csv",
        "title": "Table IV -- Aggregate Totals by ETR Bracket (Subsidiary Level)",
        "desc": (
            "The most policy-relevant ETR breakdown. Reports all financial "
            "aggregates and activity-share variables disaggregated by eleven "
            "ETR brackets, at the subsidiary (TRSUB) level. Critical for GMT "
            "revenue simulation: allows direct computation of the volume of "
            "profit, assets, payroll and tax accrued below the 15\\%\\@ threshold. "
            "Covers fiscal years 2016--2022."
        ),
    },
    5: {
        "file": "cbcr_table5_mne_size_distribution.csv",
        "title": "Table V -- MNE Group Size Distribution",
        "desc": (
            "Reports percentile distributions (P5, P10, P25, P50, P75, P90, "
            "P95) of MNE group size, measured by consolidated unrelated-party "
            "revenue (UPR), total assets and employment, by parent jurisdiction. "
            "Does not contain a COUNTERPART\\_AREA dimension. "
            "Covers fiscal years 2016--2022."
        ),
    },
    6: {
        "file": "cbcr_table6_mne_size_aggregates.csv",
        "title": "Table VI -- Aggregate Totals by MNE Group Size Class",
        "desc": (
            "Reports all financial and activity-share variables disaggregated "
            "by five consolidated revenue size classes of MNE groups. Allows "
            "analysis of how tax behaviour varies across the size spectrum -- "
            "particularly relevant for understanding the EUR~750~million revenue "
            "threshold behaviour. Currently covers fiscal year 2022 only."
        ),
    },
}

# ---------------------------------------------------------------------------
# Core analysis functions
# ---------------------------------------------------------------------------

def load_table(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, low_memory=False)
    df["OBS_VALUE"] = pd.to_numeric(df["OBS_VALUE"], errors="coerce")
    return df


def dim_summary(df: pd.DataFrame, col: str, label_map=None) -> dict:
    vals = sorted(df[col].dropna().unique().tolist(), key=str)
    out = {}
    for v in vals:
        lbl = label_map.get(str(v), str(v)) if label_map else str(v)
        n = int((df[col] == v).sum())
        out[str(v)] = {"label": lbl, "n_rows": n}
    return out


def missing_summary(df: pd.DataFrame) -> dict:
    """
    OBS_VALUE = NaN  → truly missing / confidentially suppressed
    OBS_VALUE = 0    → genuine zero (no observations for that cell)
    OBS_VALUE > 0    → actual positive observation
    OBS_STATUS = A   → actual value (normal)
    OBS_STATUS = Q   → provisional
    """
    total = len(df)
    n_nan      = int(df["OBS_VALUE"].isna().sum())
    n_zero     = int((df["OBS_VALUE"] == 0).sum())
    n_positive = int((df["OBS_VALUE"].notna() & (df["OBS_VALUE"] > 0)).sum())
    n_negative = int((df["OBS_VALUE"].notna() & (df["OBS_VALUE"] < 0)).sum())
    n_nonmiss  = int(df["OBS_VALUE"].notna().sum())  # zero + positive + negative
    n_q        = int((df.get("OBS_STATUS", pd.Series()) == "Q").sum())
    n_a        = int((df.get("OBS_STATUS", pd.Series()) == "A").sum())
    return {
        "total_rows": total,
        "n_missing_nan": n_nan,
        "pct_missing_nan": round(100 * n_nan / total, 2),
        "n_zero_obs": n_zero,
        "pct_zero_obs": round(100 * n_zero / total, 2),
        "n_positive_obs": n_positive,
        "pct_positive_obs": round(100 * n_positive / total, 2),
        "n_negative_obs": n_negative,
        "pct_negative_obs": round(100 * n_negative / total, 2),
        "n_nonmissing": n_nonmiss,
        "pct_nonmissing": round(100 * n_nonmiss / total, 2),
        "n_status_A": n_a,
        "n_status_Q": n_q,
    }


def year_coverage(df: pd.DataFrame) -> dict:
    out = {}
    for yr, g in df.groupby("TIME_PERIOD"):
        n_total     = len(g)
        n_positive  = int((g["OBS_VALUE"].notna() & (g["OBS_VALUE"] > 0)).sum())
        n_nan       = int(g["OBS_VALUE"].isna().sum())
        n_ref       = g["REF_AREA"].nunique()
        ca_col = "COUNTERPART_AREA"
        n_cpart = int(g[ca_col].apply(lambda x: x != "_Z").sum() > 0 and
                      g[g[ca_col] != "_Z"][ca_col].nunique()) if ca_col in g.columns else 0
        out[int(yr)] = {
            "total_rows": n_total,
            "n_positive_obs": n_positive,
            "pct_positive": round(100 * n_positive / n_total, 1),
            "n_missing_nan": n_nan,
            "pct_missing": round(100 * n_nan / n_total, 1),
            "n_parent_jurisdictions": n_ref,
        }
    return out


def jurisdiction_coverage(df: pd.DataFrame) -> dict:
    ref_all = sorted(df["REF_AREA"].unique().tolist())
    if "COUNTERPART_AREA" in df.columns:
        ca_vals = sorted([v for v in df["COUNTERPART_AREA"].unique().tolist()
                          if str(v) != "_Z"])
    else:
        ca_vals = []
    return {
        "n_parent_jurisdictions": len(ref_all),
        "parent_jurisdictions": ref_all,
        "n_affiliate_jurisdictions": len(ca_vals),
        "affiliate_jurisdictions": ca_vals,
    }


def measure_coverage(df: pd.DataFrame) -> dict:
    """For each MEASURE: total rows, positive obs, NaN obs, and breakdown by year."""
    out = {}
    for msr in sorted(df["MEASURE"].unique()):
        sub = df[df["MEASURE"] == msr]
        total = len(sub)
        n_pos = int((sub["OBS_VALUE"].notna() & (sub["OBS_VALUE"] > 0)).sum())
        n_nan = int(sub["OBS_VALUE"].isna().sum())
        unit  = sub["UNIT_MEASURE"].mode().iloc[0] if len(sub) > 0 else ""
        # breakdown by year
        yr_dict = {}
        for yr, g in sub.groupby("TIME_PERIOD"):
            yr_dict[int(yr)] = {
                "total_rows": len(g),
                "n_positive": int((g["OBS_VALUE"].notna() & (g["OBS_VALUE"] > 0)).sum()),
                "n_missing": int(g["OBS_VALUE"].isna().sum()),
            }
        out[msr] = {
            "label": MEASURE_LABELS.get(msr, msr),
            "unit": UNIT_LABELS.get(unit, unit),
            "total_rows": total,
            "n_positive": n_pos,
            "pct_positive": round(100 * n_pos / total, 1) if total else 0,
            "n_missing_nan": n_nan,
            "pct_missing": round(100 * n_nan / total, 1) if total else 0,
            "by_year": yr_dict,
        }
    return out


def key_measure_stats(df: pd.DataFrame, measures: list) -> dict:
    """Descriptive statistics for key financial measures (aggregate rows only)."""
    out = {}
    for m in measures:
        sub = df[(df["MEASURE"] == m)
                 & (df["STATISTICAL_OPERATION"] == "_Z")
                 & df["OBS_VALUE"].notna()
                 & (df["OBS_VALUE"] > 0)]
        if sub.empty:
            out[m] = {}
            continue
        vals = sub["OBS_VALUE"]
        unit  = sub["UNIT_MEASURE"].mode().iloc[0] if len(sub) > 0 else ""
        out[m] = {
            "label": MEASURE_LABELS.get(m, m),
            "unit": UNIT_LABELS.get(unit, unit),
            "n_obs": int(len(vals)),
            "sum": round(float(vals.sum()), 0),
            "mean": round(float(vals.mean()), 2),
            "median": round(float(vals.median()), 2),
            "p25": round(float(vals.quantile(0.25)), 2),
            "p75": round(float(vals.quantile(0.75)), 2),
            "max": round(float(vals.max()), 2),
        }
    return out


def parent_jurisdiction_completeness(df: pd.DataFrame,
                                      key_measures: list,
                                      year: int = 2022) -> dict:
    """
    For a given year, report which parent jurisdictions have positive
    observations for each key measure (STATISTICAL_OPERATION = _Z).
    """
    sub = df[(df["TIME_PERIOD"] == year)
             & (df["STATISTICAL_OPERATION"] == "_Z")]
    out = {}
    for m in key_measures:
        msub = sub[sub["MEASURE"] == m]
        has_data = msub[msub["OBS_VALUE"] > 0]["REF_AREA"].unique().tolist()
        out[m] = {"n_with_data": len(has_data), "jurisdictions": sorted(has_data)}
    return out


# ---------------------------------------------------------------------------
# Main analysis
# ---------------------------------------------------------------------------
results = {}
KEY_FIN = ["PROFIT", "TAX_ACCRUED", "TAX_PAID", "ASSETS", "EARNINGS",
           "EMPLOYEES", "TOT_REV", "UPR", "RPR", "STATED_CAPITAL"]

for tnum, meta in TABLE_META.items():
    path = RAW_DIR / meta["file"]
    print(f"Loading Table {tnum}: {meta['title']} ...", flush=True)
    df = load_table(path)

    tkey = f"table{tnum}"
    miss = missing_summary(df)
    print(f"  {len(df):,} rows | "
          f"{miss['pct_positive_obs']:.1f}% positive obs | "
          f"{miss['pct_missing_nan']:.1f}% truly missing (NaN) | "
          f"years: {sorted(df['TIME_PERIOD'].unique().tolist())}")

    # Key measures present in this table
    km = [m for m in KEY_FIN if m in df["MEASURE"].values]

    results[tkey] = {
        "title":       meta["title"],
        "description": meta["desc"],
        "file":        meta["file"],
        "shape":       {"rows": len(df), "cols": len(df.columns)},
        "columns":     list(df.columns),
        "missing":     miss,
        "years":       year_coverage(df),
        "jurisdictions": jurisdiction_coverage(df),
        "dimensions": {
            "MEASURE":               dim_summary(df, "MEASURE", MEASURE_LABELS),
            "UNIT_MEASURE":          dim_summary(df, "UNIT_MEASURE", UNIT_LABELS),
            "STATISTICAL_OPERATION": dim_summary(df, "STATISTICAL_OPERATION", STAT_OP_LABELS),
            "AGGREGATION_TYPE":      dim_summary(df, "AGGREGATION_TYPE", AGG_LABELS),
            "PROFIT_GROUPING":       dim_summary(df, "PROFIT_GROUPING", PANEL_LABELS),
            "EFFECTIVE_TAX_RATE":    dim_summary(df, "EFFECTIVE_TAX_RATE", ETR_LABELS),
            "MNE_SIZE":              dim_summary(df, "MNE_SIZE", SIZE_LABELS),
            "OBS_STATUS":            dim_summary(df, "OBS_STATUS", STATUS_LABELS),
        },
        "measure_coverage": measure_coverage(df),
    }

    if km:
        results[tkey]["key_measure_stats_2022"] = key_measure_stats(
            df[df["TIME_PERIOD"] == 2022], km
        )
        # Jurisdiction completeness for most recent year available
        latest_yr = int(df["TIME_PERIOD"].max())
        results[tkey]["parent_jurisdiction_completeness"] = {
            "year": latest_yr,
            "by_measure": parent_jurisdiction_completeness(df, km, year=latest_yr),
        }

# ---------------------------------------------------------------------------
# Cross-table summary
# ---------------------------------------------------------------------------
cross = {}
for tkey, r in results.items():
    cross[tkey] = {
        "title":                    r["title"],
        "rows":                     r["shape"]["rows"],
        "pct_positive_obs":         r["missing"]["pct_positive_obs"],
        "pct_missing_nan":          r["missing"]["pct_missing_nan"],
        "pct_zero_obs":             r["missing"]["pct_zero_obs"],
        "years_covered":            list(r["years"].keys()),
        "n_parent_jurisdictions":   r["jurisdictions"]["n_parent_jurisdictions"],
        "n_affiliate_jurisdictions": r["jurisdictions"]["n_affiliate_jurisdictions"],
        "measures":                 list(r["dimensions"]["MEASURE"].keys()),
        "n_measures":               len(r["dimensions"]["MEASURE"]),
        "aggregation_types":        list(r["dimensions"]["AGGREGATION_TYPE"].keys()),
        "etr_brackets":             list(r["dimensions"]["EFFECTIVE_TAX_RATE"].keys()),
        "mne_size_classes":         list(r["dimensions"]["MNE_SIZE"].keys()),
        "stat_operations":          list(r["dimensions"]["STATISTICAL_OPERATION"].keys()),
        "profit_groupings":         list(r["dimensions"]["PROFIT_GROUPING"].keys()),
    }

results["_cross_table_summary"] = cross

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
with open(OUT_JSON, "w") as f:
    json.dump(results, f, indent=2, default=str)

print(f"\nSaved: {OUT_JSON}")
print("\n=== CROSS-TABLE SUMMARY ===")
for tkey, c in cross.items():
    print(f"\n{tkey}: {c['title']}")
    print(f"  Rows: {c['rows']:,} | "
          f"Positive obs: {c['pct_positive_obs']}% | "
          f"Zero obs: {c['pct_zero_obs']}% | "
          f"NaN (missing): {c['pct_missing_nan']}%")
    print(f"  Years: {c['years_covered']}")
    print(f"  Parent jurisdictions: {c['n_parent_jurisdictions']} | "
          f"Affiliate: {c['n_affiliate_jurisdictions']}")
    print(f"  Measures ({c['n_measures']}): {', '.join(c['measures'])}")
    if c['etr_brackets'] != ['_Z']:
        print(f"  ETR brackets: {', '.join(c['etr_brackets'])}")
    if c['mne_size_classes'] != ['_Z']:
        print(f"  MNE size classes: {', '.join(c['mne_size_classes'])}")
