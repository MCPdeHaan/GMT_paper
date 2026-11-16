# Dated UTPR recipient evidence and routing specification. Source IIR, QDMTT
# and SbS flags are supplied independently by the source panel.

UTPR_EVALUATION_DATE <- as.Date("2026-01-01")
UTPR_EVIDENCE_CUTOFF <- as.Date("2026-11-15")
UTPR_LEGAL_STATUSES <- c("verified_applicable", "verified_not_applicable", "deferred",
  "not_established", "legally_ambiguous")
read_utpr_evidence <- function(path) {
  date_cols <- c("enactment_date", "commencement_date", "first_applicable_fy_start",
    "source_publication_date", "source_retrieval_date", "evaluation_date", "evidence_cutoff")
  evidence <- readr::read_csv(path, show_col_types = FALSE,
    col_types = do.call(readr::cols, c(list(.default = readr::col_character()),
      setNames(rep(list(readr::col_date()), length(date_cols)), date_cols))))
  readr::stop_for_problems(evidence)
  validate_utpr_evidence(evidence)
  evidence
}

validate_utpr_evidence <- function(evidence) {
  keys <- c("iso3", "rule", "evaluation_date")
  stopifnot(!anyNA(evidence[keys]), !anyDuplicated(evidence[keys]),
    all(grepl("^[A-Z]{3}$", evidence$iso3)), all(evidence$rule == "UTPR"),
    all(evidence$evaluation_date == UTPR_EVALUATION_DATE),
    all(evidence$evidence_cutoff == UTPR_EVIDENCE_CUTOFF),
    all(evidence$status %in% UTPR_LEGAL_STATUSES),
    all(evidence$enactment_status %in% c("enacted", "not_enacted", "deferred", "not_established")),
    all(evidence$collector_scope %in% c("candidate", "parent_context")),
    all(evidence$evidence_category %in% c("national_law", "official_guidance",
      "eu_notice", "official_search", "bill")),
    all(evidence$verification_status %in% c("verified", "unresolved")),
    all(evidence$oecd_utpr_qualification %in% c("verified_qualified", "verified_not_qualified", "not_established")),
    all(evidence$article50_status %in% c("elected", "not_elected", "outside_eu")),
    all(evidence$article50_source_rule %in% c("other_member_states", "not_applicable")),
    all((evidence$article50_status == "elected") == (evidence$status == "deferred")),
    all((evidence$article50_status == "elected") == (evidence$article50_source_rule == "other_member_states")),
    all((evidence$iso3 %in% EU27_ISO3) == (evidence$article50_status != "outside_eu")),
    all(evidence$source_retrieval_date <= evidence$evidence_cutoff),
    all(evidence$source_publication_date <= evidence$source_retrieval_date, na.rm = TRUE),
    all(evidence$enactment_date <= evidence$evidence_cutoff, na.rm = TRUE),
    all(evidence$commencement_date >= evidence$enactment_date, na.rm = TRUE),
    all(grepl("^https://", evidence$source_url)),
    all((evidence$status %in% c("not_established", "legally_ambiguous")) ==
      (evidence$verification_status == "unresolved")))
  positive <- filter(evidence, status == "verified_applicable")
  stopifnot(all(positive$enactment_status == "enacted"),
    all(positive$first_applicable_fy_start <= positive$evaluation_date))
  later <- filter(evidence, status == "verified_not_applicable", !is.na(first_applicable_fy_start))
  stopifnot(all(later$first_applicable_fy_start > later$evaluation_date))
  invisible(evidence)
}

UTPR_SPECIFICATIONS <- c(
  "LEGACY_FALLBACK", "VERIFIED_FALLBACK", "LEGACY_PARENT_ONLY",
  "VERIFIED_PARENT_ONLY", "VERIFIED_PLUS_UNRESOLVED_PARENT_ONLY"
)

utpr_specification <- function(name = Sys.getenv("GMT_UTPR_SPECIFICATION", unset = "VERIFIED_PARENT_ONLY")) {
  if (length(name) != 1L || !name %in% UTPR_SPECIFICATIONS) {
    stop("Unknown UTPR specification. Choose ", paste(UTPR_SPECIFICATIONS, collapse = ", "), call. = FALSE)
  }
  name
}

utpr_collector_policy <- function(specification, activity,
                                  evidence = NULL) {
  specification <- utpr_specification(specification)
  if (startsWith(specification, "LEGACY_")) {
    return(list(specification = specification, eligible = sort(unique(
      activity$collector[activity$collector_utpr_flag]))))
  }
  if (is.null(evidence)) {
    evidence <- read_utpr_evidence(file.path(GMT_PROJECT_ROOT, "data", "legal", "utpr_eligibility_2026.csv"))
  } else {
    validate_utpr_evidence(evidence)
  }
  candidates <- dplyr::filter(evidence, collector_scope == "candidate")
  stopifnot(all(c(EU27_ISO3, activity$collector[activity$collector_utpr_flag]) %in% candidates$iso3))
  verified <- candidates$iso3[candidates$status == "verified_applicable"]
  provisional <- if (specification == "VERIFIED_PLUS_UNRESOLVED_PARENT_ONLY") {
    candidates$iso3[candidates$status %in% c("not_established", "legally_ambiguous")]
  } else character()
  list(specification = specification, eligible = sort(c(verified, provisional)),
    verified = sort(verified), provisional = sort(provisional),
    evaluation_date = UTPR_EVALUATION_DATE, evidence_cutoff = UTPR_EVIDENCE_CUTOFF)
}

apply_utpr_collector_policy <- function(activity, policy) {
  if (startsWith(policy$specification, "LEGACY_")) return(activity)
  dplyr::mutate(activity,
    collector_utpr_flag = collector %in% policy$eligible,
    collector_utpr_explicit_flag = collector %in% policy$verified,
    collector_utpr_ambiguous_flag = collector %in% policy$provisional)
}

read_stage4_utpr_weights <- function(in_dir = PROCESSED_DIR) {
  weights <- list(
    parent_year_weights = readRDS(file.path(in_dir, "stage4_5_utpr_parent_year_weights.rds")),
    fallback_weights = readRDS(file.path(in_dir, "stage4_5_utpr_fallback_weights.rds"))
  )
  policy_file <- file.path(in_dir, "stage4_5_utpr_policy.rds")
  if (file.exists(policy_file)) weights$policy <- readRDS(policy_file)
  weights
}

utpr_unsupported_contract <- function(weights) {
  if (is.null(weights$policy)) "strict" else "report"
}
