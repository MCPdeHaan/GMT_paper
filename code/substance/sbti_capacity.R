# Mechanical SBTI capacity proxies in dollars, on already selected activity.
# Missing activity in either leg propagates through the maximum. Applications
# such as the repeal game have their own preceding missing-input convention.

sbti_payroll_capacity <- function(payroll) {
  0.055 * payroll
}

sbti_carrying_value_capacity <- function(assets) {
  0.01 * assets
}

sbti_maximum_capacity <- function(payroll, assets) {
  pmax(sbti_payroll_capacity(payroll), sbti_carrying_value_capacity(assets))
}

# Floor and capacity per unit of profit are fractions. This is a diagnostic
# floor transformation. Liability overlays are defined by their callers.
apply_sbti_capacity_overlay <- function(floor_rate, kappa) {
  dplyr::if_else(
    is.na(floor_rate) | is.na(kappa),
    NA_real_,
    pmax(0, floor_rate - pmin(pmax(kappa, 0), floor_rate))
  )
}
