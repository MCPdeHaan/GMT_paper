# python collect_all_data.py
# python collect_all_data.py

import argparse
import os
import sys
import time
import json
import logging
from pathlib import Path
from datetime import datetime

import pandas as pd
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(BASE_DIR / "collection_log.txt"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger(__name__)

SESSION = requests.Session() # consistent HTTP connection
SESSION.headers.update({
    "User-Agent": "GMT-Thesis-DataCollector/1.0 (academic research)", # prevent flag
})
TIMEOUT = 180
RETRY_WAIT = 5
MAX_RETRIES = 3

#  OECD SDMX base URL 
OECD_SDMX = "https://sdmx.oecd.org/public/rest/data"
SDMX_CSV_HEADERS = {"Accept": "application/vnd.sdmx.data+csv;file=true"}


#  Helper Functions 
def download_file(url: str, dest: Path, description: str,
                  headers: dict | None = None) -> bool:
    """Download a file with retry logic."""
    if dest.exists() and dest.stat().st_size > 0:
        size_mb = dest.stat().st_size / 1e6
        log.info(f"Already exists: {dest.name} ({size_mb:.2f} MB)")
        return True

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            log.info(f"[{attempt}/{MAX_RETRIES}] {description}")
            req_headers = headers or {}
            resp = SESSION.get(url, timeout=TIMEOUT, headers=req_headers,
                               stream=True)
            resp.raise_for_status()

            with open(dest, "wb") as f:
                for chunk in resp.iter_content(chunk_size=65536):
                    f.write(chunk)

            size_mb = dest.stat().st_size / 1e6
            log.info(f"Saved: {dest.name} ({size_mb:.2f} MB)")
            return True

        except requests.exceptions.RequestException as e:
            log.warning(f"Error: {e}")
            if dest.exists():
                dest.unlink()
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_WAIT)
            else:
                log.error(f"FAILED: {description}")
                return False
    return False

def download_oecd(dataflow: str, dest: Path, description: str) -> bool:
    url = f"{OECD_SDMX}/{dataflow}/all?format=csv"
    return download_file(url, dest, description, headers=SDMX_CSV_HEADERS)

# 1. OECD Country-by-Country Reporting (CbCR)
def collect_oecd_cbcr():
    log.info("=" * 70)
    log.info("1. OECD CbCR Data")
    log.info("=" * 70)

    d = RAW_DIR / "oecd_cbcr"
    d.mkdir(exist_ok=True)

    tables = [
        ("cbcr_table1_aggregate_totals.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRI,1.1",
         "Table I – Aggregate totals by jurisdiction"),
        ("cbcr_table2_interquartile_means.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRII,1.1",
         "Table II – Interquartile means by jurisdiction"),
        ("cbcr_table3_etr_aggregates.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRIII,1.1",
         "Table III – Aggregate totals by ETR bracket"),
        ("cbcr_table4_etr_aggregates_alt.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRIV,1.1",
         "Table IV – Aggregate totals by ETR bracket (alt)"),
        ("cbcr_table5_mne_size_distribution.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRV,1.1",
         "Table V – Distribution of MNE group size"),
        ("cbcr_table6_mne_size_aggregates.csv",
         "OECD.CTP.TPS,DSD_CBCR@DF_CBCRVI,1.1",
         "Table VI – Aggregates by MNE group size"),
    ]
    for fname, flow, desc in tables:
        download_oecd(flow, d / fname, desc)
    log.info("")

# 2. OECD Statutory CIT Rates
def collect_oecd_cit_rates():
    log.info("=" * 70)
    log.info("2. OECD Statutory CIT Rates")
    log.info("=" * 70)

    d = RAW_DIR / "oecd_tax_rates"
    d.mkdir(exist_ok=True)

    download_oecd(
        "OECD.CTP.TPS,DSD_TAX_CIT@DF_CIT,2.0",
        d / "oecd_statutory_cit_rates.csv",
        "Statutory CIT rates (combined central + sub-central)",
    )
    download_oecd(
        "OECD.CTP.TPS,DSD_TAX_CIT@DF_CIT_DIVD_INCOME,1.0",
        d / "oecd_combined_dividend_rates.csv",
        "Combined statutory tax rates on dividend income",
    )
    log.info("")



# 3. OECD Forward-Looking ETRs
def collect_oecd_etr():
    log.info("=" * 70)
    log.info("3. OECD Forward-Looking ETRs")
    log.info("=" * 70)

    d = RAW_DIR / "oecd_etr"
    d.mkdir(exist_ok=True)

    for fname, flow, desc in [
        ("oecd_etr_baseline.csv",
         "OECD.CTP.TPS,DSD_ETR@DF_ETR_BASELINE,2.0",
         "ETR baseline"),
        ("oecd_etr_income_incentives.csv",
         "OECD.CTP.TPS,DSD_ETR@DF_ETR_IBRD,2.0",
         "ETR with income-based incentives"),
        ("oecd_etr_expenditure_incentives.csv",
         "OECD.CTP.TPS,DSD_ETR@DF_ETR_XBRD,2.0",
         "ETR with expenditure-based incentives"),
    ]:
        download_oecd(flow, d / fname, desc)
    log.info("")

# 4. OECD Average Annual Wages
def collect_oecd_wages():
    log.info("=" * 70)
    log.info("4. OECD Average Annual Wages")
    log.info("=" * 70)

    d = RAW_DIR / "oecd_wages"
    d.mkdir(exist_ok=True)

    download_oecd(
        "OECD.ELS.SAE,DSD_EARNINGS@AV_AN_WAGE,1.0",
        d / "oecd_avg_annual_wages.csv",
        "Average annual wages",
    )
    download_oecd(
        "OECD.SDD.TPS,DSD_EAR@DF_HOU_EAR,1.0",
        d / "oecd_hourly_earnings.csv",
        "Hourly earnings (supplementary)",
    )
    log.info("")

# World Bank for income classifications, GDP, population
def collect_world_bank():
    log.info("=" * 70)
    log.info("6. World Bank Classifications & GDP")
    log.info("=" * 70)

    d = RAW_DIR / "world_bank"
    d.mkdir(exist_ok=True)

    csv_dest = d / "wb_income_classifications.csv"
    if not csv_dest.exists():
        log.info("  Fetching income classifications via API...")
        try:
            all_c = []
            page = 1
            while True:
                r = SESSION.get(
                    "https://api.worldbank.org/v2/country",
                    params={"per_page": 300, "page": page, "format": "json"},
                    timeout=TIMEOUT,
                )
                r.raise_for_status()
                data = r.json()
                if len(data) < 2 or not data[1]:
                    break
                for c in data[1]:
                    all_c.append({
                        "iso3": c.get("id", ""),
                        "iso2": c.get("iso2Code", ""),
                        "name": c.get("name", ""),
                        "region": c.get("region", {}).get("value", ""),
                        "income_level": c.get("incomeLevel", {}).get("value", ""),
                        "income_id": c.get("incomeLevel", {}).get("id", ""),
                    })
                if page >= data[0].get("pages", 1):
                    break
                page += 1
            df = pd.DataFrame(all_c)
            df.to_csv(csv_dest, index=False)
            log.info(f"  ✓ {len(df)} entries → {csv_dest.name}")
            for lv, n in df["income_level"].value_counts().items():
                log.info(f"    {lv}: {n}")
        except Exception as e:
            log.error(f"  ✗ API error: {e}")
    else:
        log.info(f"  ✓ Already exists: {csv_dest.name}")

    download_file(
        "https://databankfiles.worldbank.org/public/ddpext_download/site-content/OGHIST.xlsx",
        d / "wb_historical_income_groups.xlsx",
        "Historical income group classifications",
    )

    #  GDP per capita 
    gdp_dest = d / "wb_gdp_per_capita.csv"
    if not gdp_dest.exists():
        log.info("  Fetching GDP per capita (2015-2024)...")
        try:
            all_obs = []
            page = 1
            while True:
                r = SESSION.get(
                    "https://api.worldbank.org/v2/country/all/indicator/NY.GDP.PCAP.CD",
                    params={"per_page": 10000, "page": page,
                            "format": "json", "date": "2015:2024"},
                    timeout=TIMEOUT,
                )
                r.raise_for_status()
                data = r.json()
                if len(data) < 2 or not data[1]:
                    break
                for o in data[1]:
                    all_obs.append({
                        "iso3": o["country"]["id"],
                        "country": o["country"]["value"],
                        "year": o["date"],
                        "gdp_pc_usd": o["value"],
                    })
                if page >= data[0].get("pages", 1):
                    break
                page += 1
            df = pd.DataFrame(all_obs)
            df.to_csv(gdp_dest, index=False)
            log.info(f"  ✓ {len(df)} obs → {gdp_dest.name}")
        except Exception as e:
            log.error(f"  ✗ GDP error: {e}")
    else:
        log.info(f"  ✓ Already exists: {gdp_dest.name}")

    #  Population (for per-capita revenue analysis) 
    pop_dest = d / "wb_population.csv"
    if not pop_dest.exists():
        log.info("  Fetching population (2015-2024)...")
        try:
            all_obs = []
            page = 1
            while True:
                r = SESSION.get(
                    "https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL",
                    params={"per_page": 10000, "page": page,
                            "format": "json", "date": "2015:2024"},
                    timeout=TIMEOUT,
                )
                r.raise_for_status()
                data = r.json()
                if len(data) < 2 or not data[1]:
                    break
                for o in data[1]:
                    all_obs.append({
                        "iso3": o["country"]["id"],
                        "country": o["country"]["value"],
                        "year": o["date"],
                        "population": o["value"],
                    })
                if page >= data[0].get("pages", 1):
                    break
                page += 1
            df = pd.DataFrame(all_obs)
            df.to_csv(pop_dest, index=False)
            log.info(f"  ✓ {len(df)} obs → {pop_dest.name}")
        except Exception as e:
            log.error(f"  ✗ Population error: {e}")
    else:
        log.info(f"  ✓ Already exists: {pop_dest.name}")

    log.info("")



# Eurostat Inward FATS

def collect_eurostat_fats():
    log.info("=" * 70)
    log.info("Eurostat Inward FATS")
    log.info("=" * 70)

    d = RAW_DIR / "eurostat_fats"
    d.mkdir(exist_ok=True)

    dataset = "fats_g1b_08"
    desc = "Inward FATS main indicators by controlling country"
    dest_csv = d / f"{dataset}.csv.gz"
    dest_tsv = d / f"{dataset}.tsv.gz"

    if dest_csv.exists() or dest_tsv.exists():
        existing = dest_csv if dest_csv.exists() else dest_tsv
        log.info(f"  ✓ Already exists: {existing.name}")
    else:
        url_csv = (f"https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/"
                   f"data/{dataset}/?format=SDMX-CSV&compressed=true")
        ok = download_file(url_csv, dest_csv, f"{desc} (CSV)")
        if not ok:
            url_tsv = (f"https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/"
                       f"data/{dataset}/?format=TSV&compressed=true")
            download_file(url_tsv, dest_tsv, f"{desc} (TSV fallback)")

    log.info("")



# BEA US MNE Data
def collect_bea_mne():
    log.info("=" * 70)
    log.info("8. BEA US Multinational Enterprise Data")
    log.info("=" * 70)

    d = RAW_DIR / "bea_mne"
    d.mkdir(exist_ok=True)

    # As of 2025-08, BEA moved files to new URL scheme (.xls, flat folder).
    base = "https://www.bea.gov/sites/default/files/2025-08"

    files = [
        ("bea_mofa_selected_by_country.xls",
         f"{base}/selected-mofas-cntry.xls",
         "MOFA Selected Data by Country"),
        ("bea_mofa_employment.xls",
         f"{base}/mofas-employment.xls",
         "MOFA Employment by Country & Industry"),
        ("bea_mofa_assets.xls",
         f"{base}/mofas-assets.xls",
         "MOFA Assets by Country & Industry"),
        ("bea_mofa_value_added.xls",
         f"{base}/mofas-value-added.xls",
         "MOFA Value Added by Country & Industry"),
    ]

    for fname, url, desc in files:
        dest = d / fname
        download_file(url, dest, desc)

    api_key = os.environ.get("BEA_API_KEY")
    if api_key:
        log.info("  BEA_API_KEY found — fetching via API...")
        try:
            r = SESSION.get("https://apps.bea.gov/api/data", params={
                "UserID": api_key, "method": "GetData",
                "DatasetName": "MNE", "DirectionOfInvestment": "outward",
                "Classification": "Country", "Year": "ALL",
                "State": "0", "Industry": "0000",
                "SeriesID": "5,6,8,22,25",
                "GetFootnotes": "no", "ResultFormat": "json",
            }, timeout=TIMEOUT)
            r.raise_for_status()
            with open(d / "bea_api_outward.json", "w") as f:
                json.dump(r.json(), f, indent=2)
            log.info("  ✓ BEA API data saved")
        except Exception as e:
            log.warning(f"  BEA API error: {e}")
    else:
        log.info("  Tip: Set BEA_API_KEY for more data (free: https://apps.bea.gov/API/signup/)")

    log.info("")

# 9. ILO Wage Data

def collect_ilo_wages():
    """ILO wage data for non-OECD countries (bulk CSV)."""
    log.info("=" * 70)
    log.info("9. ILO Global Wage Data")
    log.info("=" * 70)

    d = RAW_DIR / "ilo_wages"
    d.mkdir(exist_ok=True)

    # ILO bulk downloads moved from www.ilo.org/ilostat-files/ (defunct) to the
    # ILOSTAT SDMX REST API.  Docs: https://ilostat.ilo.org/data/sdmx/
    # Old indicator codes were renamed: EAR_4MTH → EAR_EMTA, EAR_HEES → EAR_EHRA
    # NOTE: Hourly earnings dataset often causes 524 (Cloudflare timeout) on the
    # ILO SDMX server due to dataset size.  Monthly earnings is primary; hourly
    # is supplementary.  If hourly fails, it can be downloaded manually from
    # https://ilostat.ilo.org/data/ (indicator EAR_EHRA).
    ilo_sdmx = "https://sdmx.ilo.org/rest/data"
    for fname, flow, desc in [
        ("ilo_monthly_earnings.csv",
         "ILO,DF_EAR_EMTA_SEX_ECO_CUR_NB,1.0",
         "Mean nominal monthly earnings"),
        ("ilo_hourly_earnings.csv",
         "ILO,DF_EAR_EHRA_SEX_ECO_CUR_NB,1.0",
         "Mean nominal hourly earnings"),
    ]:
        url = f"{ilo_sdmx}/{flow}/all?format=csv"
        download_file(url, d / fname, desc, headers=SDMX_CSV_HEADERS)

    log.info("")



# 10. OECD BEPS & Pillar Two
def collect_pillar2_tracker():
    """OECD BEPS implementation: CbCR requirements, CFC, interest rules, IP regimes."""
    log.info("=" * 70)
    log.info("10. OECD BEPS & Pillar Two Implementation")
    log.info("=" * 70)

    d = RAW_DIR / "pillar2_beps"
    d.mkdir(exist_ok=True)

    for fname, flow, desc in [
        ("oecd_cbcr_requirements.csv",
         "OECD.CTP.TPS,DSD_QDD_CBCREQ@DF_QDD_CBCREQ,1.0",
         "CbCR implementation requirements"),
        ("oecd_cfc_rules.csv",
         "OECD.CTP.TPS,DSD_QDD_CFC@DF_QDD_CFC,2.0",
         "Controlled foreign company rules"),
        ("oecd_interest_limitation.csv",
         "OECD.CTP.TPS,DSD_QDD_ILR@DF_QDD_ILR,2.0",
         "Interest limitation rules"),
        ("oecd_ip_regimes.csv",
         "OECD.CTP.TPS,DSD_QDD_IPR@DF_QDD_IPR,2.1",
         "Intellectual property regimes"),
        ("oecd_hybrid_mismatch.csv",
         "OECD.CTP.TPS,DSD_QDD_ACT2@DF_QDD_ACT2,1.0",
         "Hybrid mismatch arrangements"),
        ("oecd_mandatory_disclosure.csv",
         "OECD.CTP.TPS,DSD_QDD_ACT12@DF_QDD_ACT12,1.0",
         "Mandatory disclosure rules"),
    ]:
        download_oecd(flow, d / fname, desc)

    log.info("")



# 11. OECD Additional CTS
def collect_oecd_cts_additional():
    """CIT revenue as % of GDP and other supplementary data."""
    log.info("=" * 70)
    log.info("11. OECD Additional CTS")
    log.info("=" * 70)

    d = RAW_DIR / "oecd_cts_additional"
    d.mkdir(exist_ok=True)

    # Old DSD_CTS_CIT@DF_CITREV was removed; comparative global revenue
    # statistics contain CIT revenue as % of GDP (filter heading 1200).
    download_oecd(
        "OECD.CTP.TPS,DSD_REV_COMP_GLOBAL@DF_RSGLOBAL,2.1",
        d / "oecd_cit_revenue_gdp.csv",
        "Comparative tax revenue statistics (incl. CIT as % of GDP)",
    )
    log.info("")

# ORCHESTRATION
SOURCES = {
    "oecd_cbcr":          ("OECD CbCR Tables I–VI",           collect_oecd_cbcr),
    "oecd_cit_rates":     ("OECD Statutory CIT Rates",        collect_oecd_cit_rates),
    "oecd_etr":           ("OECD Forward-Looking ETRs",       collect_oecd_etr),
    "oecd_wages":         ("OECD Average Annual Wages",       collect_oecd_wages),
    "world_bank":         ("World Bank Classifications",      collect_world_bank),
    "eurostat_fats":      ("Eurostat Inward FATS",            collect_eurostat_fats),
    "bea_mne":            ("BEA US MNE Data",                 collect_bea_mne),
    "ilo_wages":          ("ILO Global Wage Data",            collect_ilo_wages),
    "pillar2_tracker":    ("OECD BEPS / Pillar Two",          collect_pillar2_tracker),
    "oecd_cts_additional":("OECD Additional CTS",             collect_oecd_cts_additional),
}


def collect_all():
    log.info("╔══════════════════════════════════════════════════════════════╗")
    log.info("║  GMT THESIS — FULL DATA COLLECTION                         ║")
    log.info(f"║  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}                                    ║")
    log.info("╚══════════════════════════════════════════════════════════════╝\n")

    results = {}
    for key, (name, func) in SOURCES.items():
        try:
            func()
            results[key] = "✓"
        except Exception as e:
            log.error(f"Error in {name}: {e}")
            results[key] = "✗"

    # Summary
    log.info("\n" + "=" * 60)
    log.info("SUMMARY")
    log.info("=" * 60)
    for key, (name, _) in SOURCES.items():
        log.info(f"  {results.get(key, '?'):2s} {name}")

    total = 0
    log.info("\nFiles:")
    for root, _, files in os.walk(RAW_DIR):
        for f in sorted(files):
            p = Path(root) / f
            mb = p.stat().st_size / 1e6
            total += mb
            log.info(f"  {mb:8.2f} MB  {p.relative_to(RAW_DIR)}")
    log.info(f"\nTotal: {total:.1f} MB")


def main():
    parser = argparse.ArgumentParser(description="GMT Thesis Data Collection")
    parser.add_argument("--source", action="append", choices=list(SOURCES.keys()))
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for key, (name, _) in SOURCES.items():
            print(f"  {key:25s} {name}")
        return

    if args.source:
        for s in args.source:
            name, func = SOURCES[s]
            log.info(f"Downloading: {name}")
            func()
    else:
        collect_all()


if __name__ == "__main__":
    main()
