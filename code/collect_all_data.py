import pandas as pd
import argparse
import csv
import gzip
import os
import sys
import time
import json
import logging
from pathlib import Path
from typing import Optional
import requests

# run script in terminal with: `cd code`` and then `python collect_all_data.py``
BASE_DIR = Path(__file__).parent  
PROJECT_DIR = BASE_DIR.parent
RAW_DIR = PROJECT_DIR / "data" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(BASE_DIR / "collection_log.txt"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger(__name__)

SESSION = requests.Session() 
SESSION.headers.update({"User-Agent": "GMT-Thesis-DataCollector (academic research)"})
TIMEOUT = 180
RETRY_WAIT = 5
MAX_RETRIES = 3

OECD_SDMX = "https://sdmx.oecd.org/public/rest/data"
EUROSTAT_SDMX = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data"
SDMX_CSV_HEADERS = {"Accept": "application/vnd.sdmx.data+csv;file=true"}

COLLECTORS = {}

def register(key: str, name: str):
    def decorator(func):
        COLLECTORS[key] = (name, func)
        return func
    return decorator

OECD_CBCR_CONFIG = [
    ("cbcr_table1_aggregate_totals.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRI,1.1", "Table I – Aggregate totals by jurisdiction"),
    ("cbcr_table2_interquartile_means.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRII,1.1", "Table II – Interquartile means by jurisdiction"),
    ("cbcr_table3_etr_aggregates.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRIII,1.1", "Table III – Aggregate totals by ETR bracket"),
    ("cbcr_table4_etr_aggregates_alt.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRIV,1.1", "Table IV – Aggregate totals by ETR bracket (alt)"),
    ("cbcr_table5_mne_size_distribution.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRV,1.1", "Table V – Distribution of MNE group size"),
    ("cbcr_table6_mne_size_aggregates.csv", "OECD.CTP.TPS,DSD_CBCR@DF_CBCRVI,1.1", "Table VI – Aggregates by MNE group size"),
]

OECD_CIT_RATES_CONFIG = [
    ("oecd_statutory_cit_rates.csv", "OECD.CTP.TPS,DSD_TAX_CIT@DF_CIT,2.0", "Statutory CIT rates"),
    ("oecd_combined_dividend_rates.csv", "OECD.CTP.TPS,DSD_TAX_CIT@DF_CIT_DIVD_INCOME,1.0", "Combined statutory tax rates on dividend income"),
]

OECD_ETR_CONFIG = [
    ("oecd_etr_baseline.csv", "OECD.CTP.TPS,DSD_ETR@DF_ETR_BASELINE,2.0", "ETR baseline"),
    ("oecd_etr_income_incentives.csv", "OECD.CTP.TPS,DSD_ETR@DF_ETR_IBRD,2.0", "ETR with income-based incentives"),
    ("oecd_etr_expenditure_incentives.csv", "OECD.CTP.TPS,DSD_ETR@DF_ETR_XBRD,2.0", "ETR with expenditure-based incentives"),
]

OECD_WAGES_CONFIG = [
    ("oecd_avg_annual_wages.csv", "OECD.ELS.SAE,DSD_EARNINGS@AV_AN_WAGE,1.0", "Average annual wages"),
    ("oecd_hourly_earnings.csv", "OECD.SDD.TPS,DSD_EAR@DF_HOU_EAR,1.0", "Hourly earnings (supplementary)"),
]

EUROSTAT_FATS_CONFIG = [
    ("fats_g1b_08", "Legacy inward FATS by controlling country (2008-2020)", "indic_sb"),
    ("fats_activ", "Current inward FATS by activity and country of control (2021 onward)", "indic_sbs"),
]

BEA_MNE_CONFIG = [
    ("bea_mofa_selected_by_country.xls", "https://www.bea.gov/sites/default/files/2025-08/selected-mofas-cntry.xls", "MOFA Selected Data by Country"),
    ("bea_mofa_employment.xls", "https://www.bea.gov/sites/default/files/2025-08/mofas-employment.xls", "MOFA Employment by Country & Industry"),
    ("bea_mofa_assets.xls", "https://www.bea.gov/sites/default/files/2025-08/mofas-assets.xls", "MOFA Assets by Country & Industry"),
    ("bea_mofa_value_added.xls", "https://www.bea.gov/sites/default/files/2025-08/mofas-value-added.xls", "MOFA Value Added by Country & Industry"),
    ("bea_usdia2023p_mofa_selected_a1_a2.xls", "https://www.bea.gov/sites/default/files/2025-08/usdia2023p-Part-II-A1-A2.xls", "Preliminary 2023 MOFA selected data, tables A1-A2"),
    ("bea_usdia2023p_mofa_ppe_c4_c6.xls", "https://www.bea.gov/sites/default/files/2025-08/usdia2023p-Part-II-C4-C6.xls", "Preliminary 2023 MOFA property, plant, and equipment, tables C4-C6"),
    ("bea_usdia2023p_mofa_value_added_f1_f9.xls", "https://www.bea.gov/sites/default/files/2025-08/usdia2023p-Part-II-F1-F9.xls", "Preliminary 2023 MOFA value added, tables F1-F9"),
    ("bea_usdia2023p_mofa_employment_compensation_g1_g5.xls", "https://www.bea.gov/sites/default/files/2025-08/usdia2023p-Part-II-G1-G5.xls", "Preliminary 2023 MOFA employment and compensation, tables G1-G5"),
    ("bea_usdia2023p_combined.zip", "https://www.bea.gov/sites/default/files/2025-08/usdia2023p-CombinedP.zip", "Preliminary 2023 complete US direct investment abroad table set"),
]

ILO_WAGES_CONFIG = [
    ("ilo_monthly_earnings.csv", "ILO,DF_EAR_EMTA_SEX_ECO_CUR_NB,1.0", "Mean nominal monthly earnings"),
    ("ilo_hourly_earnings.csv", "ILO,DF_EAR_EHRA_SEX_ECO_CUR_NB,1.0", "Mean nominal hourly earnings"),
]

EUKLEMS_INTANPROD_CONFIG = [
    ("variable_description.xlsx", "https://www.dropbox.com/s/srsn4zdb1wta27t/Variable-List-2023.xlsx?dl=1", "EUKLEMS & INTANProd variable description"),
    ("national_accounts.csv", "https://www.dropbox.com/s/nkz7mdp0onken1j/national%20accounts.csv?dl=1", "EUKLEMS & INTANProd all-country national accounts"),
    ("labour_accounts.csv", "https://www.dropbox.com/s/vgtzptui1m1tj9l/labour%20accounts.csv?dl=1", "EUKLEMS & INTANProd all-country labour accounts"),
    ("capital_accounts.csv", "https://www.dropbox.com/s/sp2p4m86et66nfg/capital%20accounts.csv?dl=1", "EUKLEMS & INTANProd all-country capital accounts"),
    ("intangibles_analytical.csv", "https://www.dropbox.com/s/jcg52sfygjnbbts/intangibles%20analytical.csv?dl=1", "EUKLEMS & INTANProd all-country analytical intangibles"),
]

GLOBAL_INTAN_INVEST_CONFIG = [
    ("annual_extrapolated_estimates.csv", "https://global-intaninvest.luiss.it/wp-content/themes/wp-bootstrap-starter-child/download-2025/Annual/annual_extrapolated_estimates.csv", "Global INTAN-Invest annual extrapolated estimates"),
    ("quarterly_estimates.csv", "https://global-intaninvest.luiss.it/wp-content/themes/wp-bootstrap-starter-child/download-2025/Quarterly/quarterly_estimates.csv", "Global INTAN-Invest quarterly estimates"),
    ("annual_all_countries.xlsx", "https://global-intaninvest.luiss.it/wp-content/themes/wp-bootstrap-starter-child/download-2025/Annual/AEX_formatted.xlsx", "Global INTAN-Invest annual all-country workbook"),
    ("quarterly_all_countries.xlsx", "https://global-intaninvest.luiss.it/wp-content/themes/wp-bootstrap-starter-child/download-2025/Quarterly/QNA_formatted.xlsx", "Global INTAN-Invest quarterly all-country workbook"),
]

PILLAR2_BEPS_CONFIG = [
    ("oecd_cbcr_requirements.csv", "OECD.CTP.TPS,DSD_QDD_CBCREQ@DF_QDD_CBCREQ,1.0", "CbCR implementation requirements"),
    ("oecd_cfc_rules.csv", "OECD.CTP.TPS,DSD_QDD_CFC@DF_QDD_CFC,2.0", "Controlled foreign company rules"),
    ("oecd_interest_limitation.csv", "OECD.CTP.TPS,DSD_QDD_ILR@DF_QDD_ILR,2.0", "Interest limitation rules"),
    ("oecd_ip_regimes.csv", "OECD.CTP.TPS,DSD_QDD_IPR@DF_QDD_IPR,2.1", "Intellectual property regimes"),
    ("oecd_hybrid_mismatch.csv", "OECD.CTP.TPS,DSD_QDD_ACT2@DF_QDD_ACT2,1.0", "Hybrid mismatch arrangements"),
    ("oecd_mandatory_disclosure.csv", "OECD.CTP.TPS,DSD_QDD_ACT12@DF_QDD_ACT12,1.0", "Mandatory disclosure rules"),
]

def download_file(url: str, dest: Path, description: str, headers: Optional[dict] = None) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return True

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req_headers = headers or {}
            resp = SESSION.get(url, timeout=TIMEOUT, headers=req_headers, stream=True)
            resp.raise_for_status()

            with open(dest, "wb") as f:
                for chunk in resp.iter_content(chunk_size=65536):
                    f.write(chunk)
            return True

        except requests.exceptions.RequestException as e:
            if dest.exists():
                dest.unlink()
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_WAIT)
            else:
                log.error(f"FAILED: {description} - {e}")
                return False
    return False

def download_oecd(dataflow: str, dest: Path, description: str) -> bool:
    url = f"{OECD_SDMX}/{dataflow}/all?format=csv"
    return download_file(url, dest, description, headers=SDMX_CSV_HEADERS)

def download_eurostat(dataset: str, dest: Path, description: str) -> bool:
    url = f"{EUROSTAT_SDMX}/{dataset}/?format=SDMX-CSV&compressed=true"
    return download_file(url, dest, description)

def build_eurostat_fats_combined(sources: list, dest: Path) -> None:
    fieldnames = [
        "source_dataset", "dataflow", "last_update", "freq", "nace_r2",
        "indicator_scheme", "indicator_code", "c_ctrl", "geo",
        "time_period", "obs_value", "obs_flag", "conf_status",
    ]

    if dest.exists():
        dest.unlink()

    total_rows = 0
    all_years = set()

    with gzip.open(dest, "wt", newline="") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=fieldnames)
        writer.writeheader()

        for dataset, path, indicator_column in sources:
            with gzip.open(path, "rt", newline="") as in_f:
                reader = csv.DictReader(in_f)
                required = {
                    "DATAFLOW", "LAST UPDATE", "freq", "nace_r2",
                    indicator_column, "c_ctrl", "geo", "TIME_PERIOD",
                    "OBS_VALUE", "OBS_FLAG", "CONF_STATUS",
                }
                missing = required - set(reader.fieldnames or [])
                if missing:
                    raise ValueError(f"{path.name} is missing required columns: {sorted(missing)}")

                for row in reader:
                    time_period = row["TIME_PERIOD"]
                    writer.writerow({
                        "source_dataset": dataset,
                        "dataflow": row["DATAFLOW"],
                        "last_update": row["LAST UPDATE"],
                        "freq": row["freq"],
                        "nace_r2": row["nace_r2"],
                        "indicator_scheme": indicator_column,
                        "indicator_code": row[indicator_column],
                        "c_ctrl": row["c_ctrl"],
                        "geo": row["geo"],
                        "time_period": time_period,
                        "obs_value": row["OBS_VALUE"],
                        "obs_flag": row["OBS_FLAG"],
                        "conf_status": row["CONF_STATUS"],
                    })
                    total_rows += 1
                    if time_period:
                        all_years.add(int(time_period))

    if not all_years:
        raise RuntimeError("Combined Eurostat FATS file is empty")

def verify_eurostat_fats_coverage(dest: Path, minimum_year: int = 2022) -> None:
    expected_sources = {"fats_g1b_08", "fats_activ"}
    seen_sources = set()
    years = set()

    with gzip.open(dest, "rt", newline="") as f:
        reader = csv.DictReader(f)
        required = {"source_dataset", "time_period"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"{dest.name} is missing required columns: {sorted(missing)}")

        for row in reader:
            seen_sources.add(row["source_dataset"])
            if row["time_period"]:
                years.add(int(row["time_period"]))

    if not years:
        raise RuntimeError(f"{dest.name} contains no year values")

    latest_year = max(years)
    if latest_year < minimum_year:
        raise RuntimeError(f"{dest.name} ends in {latest_year}, below required minimum {minimum_year}")
    
    if not expected_sources.issubset(seen_sources):
        missing_sources = sorted(expected_sources - seen_sources)
        raise RuntimeError(f"{dest.name} is missing expected source datasets: {missing_sources}")

@register("oecd_cbcr", "OECD CbCR Data")
def collect_oecd_cbcr():
    d = RAW_DIR / "oecd_cbcr"
    d.mkdir(exist_ok=True)
    for fname, flow, desc in OECD_CBCR_CONFIG:
        download_oecd(flow, d / fname, desc)

@register("oecd_cit_rates", "OECD Statutory CIT Rates")
def collect_oecd_cit_rates():
    d = RAW_DIR / "oecd_tax_rates"
    d.mkdir(exist_ok=True)
    for fname, flow, desc in OECD_CIT_RATES_CONFIG:
        download_oecd(flow, d / fname, desc)

@register("oecd_etr", "OECD Forward-Looking ETRs")
def collect_oecd_etr():
    d = RAW_DIR / "oecd_etr"
    d.mkdir(exist_ok=True)
    for fname, flow, desc in OECD_ETR_CONFIG:
        download_oecd(flow, d / fname, desc)

@register("oecd_wages", "OECD Average Annual Wages")
def collect_oecd_wages():
    d = RAW_DIR / "oecd_wages"
    d.mkdir(exist_ok=True)
    for fname, flow, desc in OECD_WAGES_CONFIG:
        download_oecd(flow, d / fname, desc)

@register("world_bank", "World Bank Classifications & GDP")
def collect_world_bank():
    d = RAW_DIR / "world_bank"
    d.mkdir(exist_ok=True)

    csv_dest = d / "wb_income_classifications.csv"
    if not csv_dest.exists():
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
            pd.DataFrame(all_c).to_csv(csv_dest, index=False)
        except requests.exceptions.RequestException as e:
            log.error(f"Income Classification API error: {e}")

    download_file(
        "https://databankfiles.worldbank.org/public/ddpext_download/site-content/OGHIST.xlsx",
        d / "wb_historical_income_groups.xlsx",
        "Historical income group classifications",
    )

    gdp_dest = d / "wb_gdp_per_capita.csv"
    if not gdp_dest.exists():
        try:
            all_obs = []
            page = 1
            while True:
                r = SESSION.get(
                    "https://api.worldbank.org/v2/country/all/indicator/NY.GDP.PCAP.CD",
                    params={"per_page": 10000, "page": page, "format": "json", "date": "2015:2024"},
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
            pd.DataFrame(all_obs).to_csv(gdp_dest, index=False)
        except requests.exceptions.RequestException as e:
            log.error(f"GDP API error: {e}")

    pop_dest = d / "wb_population.csv"
    if not pop_dest.exists():
        try:
            all_obs = []
            page = 1
            while True:
                r = SESSION.get(
                    "https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL",
                    params={"per_page": 10000, "page": page, "format": "json", "date": "2015:2024"},
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
            pd.DataFrame(all_obs).to_csv(pop_dest, index=False)
        except requests.exceptions.RequestException as e:
            log.error(f"Population API error: {e}")

@register("eurostat_fats", "Eurostat Inward FATS")
def collect_eurostat_fats():
    d = RAW_DIR / "eurostat_fats"
    d.mkdir(exist_ok=True)

    sources = []
    for dataset, desc, indicator_column in EUROSTAT_FATS_CONFIG:
        dest = d / f"{dataset}.csv.gz"
        if not download_eurostat(dataset, dest, desc):
            raise RuntimeError(f"Failed to download Eurostat dataset {dataset}")
        sources.append((dataset, dest, indicator_column))

    combined_dest = d / "fats_inward_eu_full.csv.gz"
    build_eurostat_fats_combined(sources, combined_dest)
    verify_eurostat_fats_coverage(combined_dest, minimum_year=2022)

@register("bea_mne", "BEA US MNE Data")
def collect_bea_mne():
    d = RAW_DIR / "bea_mne"
    d.mkdir(exist_ok=True)

    for fname, url, desc in BEA_MNE_CONFIG:
        download_file(url, d / fname, desc)

    api_key = os.environ.get("BEA_API_KEY")
    if api_key:
        try:
            r = SESSION.get("https://apps.bea.gov/api/data", params={
                "UserID": api_key, "method": "GetData",
                "DatasetName": "MNE", "DirectionOfInvestment": "outward",
                "Classification": "Country", "Year": "ALL",
                "State": "0", "Industry": "0000", "SeriesID": "5,6,8,22,25",
                "GetFootnotes": "no", "ResultFormat": "json",
            }, timeout=TIMEOUT)
            r.raise_for_status()
            with open(d / "bea_api_outward.json", "w") as f:
                json.dump(r.json(), f, indent=2)
        except requests.exceptions.RequestException as e:
            log.warning(f"BEA API error: {e}")

@register("euklems_intanprod", "EUKLEMS & INTANProd Data")
def collect_euklems_intanprod():
    d = RAW_DIR / "euklems_intanprod"
    d.mkdir(exist_ok=True)

    for fname, url, desc in EUKLEMS_INTANPROD_CONFIG:
        if not download_file(url, d / fname, desc):
            raise RuntimeError(f"Failed to download EUKLEMS & INTANProd file {fname}")

@register("global_intan_invest", "Global INTAN-Invest Data")
def collect_global_intan_invest():
    d = RAW_DIR / "global_intan_invest"
    d.mkdir(exist_ok=True)

    for fname, url, desc in GLOBAL_INTAN_INVEST_CONFIG:
        if not download_file(url, d / fname, desc):
            raise RuntimeError(f"Failed to download Global INTAN-Invest file {fname}")

@register("ilo_wages", "ILO Global Wage Data")
def collect_ilo_wages():
    d = RAW_DIR / "ilo_wages"
    d.mkdir(exist_ok=True)

    ilo_sdmx = "https://sdmx.ilo.org/rest/data"
    for fname, flow, desc in ILO_WAGES_CONFIG:
        url = f"{ilo_sdmx}/{flow}/all?format=csv"
        download_file(url, d / fname, desc, headers=SDMX_CSV_HEADERS)

@register("pillar2_tracker", "OECD BEPS / Pillar Two")
def collect_pillar2_tracker():
    d = RAW_DIR / "pillar2_beps"
    d.mkdir(exist_ok=True)

    for fname, flow, desc in PILLAR2_BEPS_CONFIG:
        download_oecd(flow, d / fname, desc)

@register("oecd_cts_additional", "OECD Additional CTS")
def collect_oecd_cts_additional():
    d = RAW_DIR / "oecd_cts_additional"
    d.mkdir(exist_ok=True)
    download_oecd(
        "OECD.CTP.TPS,DSD_REV_COMP_GLOBAL@DF_RSGLOBAL,2.1",
        d / "oecd_cit_revenue_gdp.csv",
        "Comparative tax revenue statistics"
    )

@register("pillar2_qdmtt", "Pillar Two QDMTT / IIR Status")
def collect_pillar2_qdmtt():
    d = RAW_DIR / "pillar2_qdmtt"
    d.mkdir(exist_ok=True)

    download_file(
        "https://www.pwc.com/content/pwc/script/gx/en/pillar-two/registration-tracker.csv",
        d / "pwc_pillar2_tracker.csv",
        "PwC Pillar Two Country Tracker"
    )
    download_file(
        "https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/administrative-guidance-globe-rules-pillar-two-central-record-legislation-transitional-qualified-status.pdf",
        d / "oecd_pillar2_central_record.pdf",
        "OECD Central Record of Qualified Pillar Two Legislation"
    )

def execute_collection(name: str, func) -> str:
    log.info("\n" + "=" * 70)
    log.info(f"Collecting: {name}")
    log.info("=" * 70)
    try:
        func()
        return "✓"
    except Exception as e:
        log.error(f"Error during collection of {name}: {e}")
        return "✗"

def collect_all():
    results = {}
    for key, (name, func) in COLLECTORS.items():
        results[key] = execute_collection(name, func)

    log.info("\n" + "=" * 60)
    log.info("SUMMARY")
    log.info("=" * 60)
    for key, (name, _) in COLLECTORS.items():
        log.info(f"  {results.get(key, '?'):2s} {name}")

    total_mb = sum(
        p.stat().st_size / 1e6 
        for p in RAW_DIR.rglob('*') 
        if p.is_file()
    )
    log.info(f"\nTotal Data Collected: {total_mb:.1f} MB")

def main():
    parser = argparse.ArgumentParser(description="GMT Thesis Data Collection")
    parser.add_argument("--source", action="append", choices=list(COLLECTORS.keys()))
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for key, (name, _) in COLLECTORS.items():
            print(f"  {key:25s} {name}")
        return

    if args.source:
        for s in args.source:
            name, func = COLLECTORS[s]
            execute_collection(name, func)
    else:
        collect_all()

if __name__ == "__main__":
    main()
