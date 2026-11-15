# Modelled UTPR weights are keyed by parent/year/collector or year/collector.
# A parent-year with any valid weights takes precedence over year fallback.
validate_utpr_weights <- function(weights, eu27) {
  validate <- function(routes, pool_key, label) {
    route_key <- c(pool_key, "collector")
    if (!all(c(route_key, "utpr_weight", "collector_is_eu27") %in% names(routes)) ||
        anyNA(routes[route_key])) {
      stop(label, " UTPR weights require complete routing keys and weight columns", call. = FALSE)
    }
    if (anyDuplicated(routes[route_key])) {
      stop(label, " UTPR weights have duplicate collector keys", call. = FALSE)
    }
    if (!is.numeric(routes$utpr_weight) ||
        any(!is.finite(routes$utpr_weight) | routes$utpr_weight < 0)) {
      stop(label, " UTPR weights must be finite and non-negative", call. = FALSE)
    }
    if (!identical(routes$collector_is_eu27, routes$collector %in% eu27)) {
      stop(label, " UTPR weights have inconsistent EU27 geography", call. = FALSE)
    }
    totals <- routes |>
      dplyr::summarise(weight_sum = sum(utpr_weight), .by = dplyr::all_of(pool_key))
    if (any(abs(totals$weight_sum - 1) > 1e-8)) {
      stop(label, " UTPR weights do not sum to one", call. = FALSE)
    }
  }
  validate(weights$parent_year_weights, c("parent", "year"), "Parent-year")
  validate(weights$fallback_weights, "year", "Fallback")
  invisible(weights)
}

# Pools may carry scenario or source-cell keys. The left joins preserve an
# unsupported pool as one row with missing collector and weight.
expand_utpr_routes <- function(pools, weights) {
  parent_key <- c("parent", "year")
  parent_year <- weights$parent_year_weights
  covered <- dplyr::distinct(parent_year, parent, year)
  dplyr::bind_rows(
    pools |>
      dplyr::semi_join(covered, by = parent_key) |>
      dplyr::left_join(parent_year, by = parent_key, relationship = "many-to-many"),
    pools |>
      dplyr::anti_join(covered, by = parent_key) |>
      dplyr::left_join(weights$fallback_weights, by = "year", relationship = "many-to-many")
  )
}
