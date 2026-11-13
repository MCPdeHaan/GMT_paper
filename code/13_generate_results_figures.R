# 13_generate_results_figures.R
# Generates publication-ready R figures for thesisv4.tex.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
})

source("code/00_helpers.R", local = TRUE)

FIGURES_DIR <- file.path(GENERATED_DIR, "figures")

thesis_cols <- c(
  navy = "#1F3A5F",
  red = "#C44536",
  orange = "#D97706",
  grey = "#6B7280",
  light = "#F3F4F6",
  mid = "#D1D5DB"
)

theme_thesis <- function(base_size = 8.5) {
  theme_minimal(base_size = base_size, base_family = "serif") +
    theme(
      text = element_text(colour = thesis_cols[["navy"]]),
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.caption = element_blank(),
      axis.title = element_text(face = "bold"),
      axis.text = element_text(colour = thesis_cols[["navy"]]),
      panel.grid.major = element_line(colour = thesis_cols[["mid"]], linewidth = 0.25),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.box = "vertical",
      legend.title = element_text(face = "bold"),
      legend.text = element_text(size = base_size - 0.5),
      legend.key.width = unit(1.0, "lines"),
      strip.text = element_text(face = "bold", colour = thesis_cols[["navy"]])
    )
}

save_thesis_plot <- function(plot, filename, width, height) {
  dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)
  ggsave(
    filename = file.path(FIGURES_DIR, filename),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = grDevices::pdf,
    bg = "white"
  )
}

format_usd_short <- function(x) {
  case_when(
    is.na(x) ~ NA_character_,
    abs(x) >= 1e12 ~ paste0("US$", round(x / 1e12, 1), "tn"),
    abs(x) >= 1e9 ~ paste0("US$", round(x / 1e9, 0), "bn"),
    abs(x) >= 1e6 ~ paste0("US$", round(x / 1e6, 0), "m"),
    abs(x) >= 1e3 ~ paste0("US$", round(x / 1e3, 0), "k"),
    TRUE ~ paste0("US$", round(x, 0))
  )
}

format_signed_bn <- function(x, digits = 1) {
  case_when(
    is.na(x) ~ NA_character_,
    x >= 0 ~ paste0("+US$", round(x / 1e9, digits), "bn"),
    TRUE ~ paste0("-US$", round(abs(x) / 1e9, digits), "bn")
  )
}

label_selected_countries <- c("NLD", "IRL", "LUX", "DEU", "FRA", "HUN", "BEL", "ESP", "AUT")

make_profit_employee_etr_bubble <- function() {
  base_panel <- readRDS(file.path(PROCESSED_DIR, "base_panel.rds"))
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))

  employees_country_year <- base_panel %>%
    filter(
      is_main_estimation_year,
      affiliate_is_eu27,
      is.finite(analysis_profit_base),
      analysis_profit_base > 0,
      is.finite(employees_sbie),
      employees_sbie > 0
    ) %>%
    group_by(affiliate, year) %>%
    summarise(
      employees = sum(employees_sbie, na.rm = TRUE),
      .groups = "drop"
    )

  country_plot <- stage1_affiliate_year %>%
    filter(affiliate_is_eu27, year %in% MAIN_YEARS) %>%
    left_join(employees_country_year, by = c("affiliate", "year")) %>%
    group_by(affiliate, affiliate_name) %>%
    summarise(
      corrected_profit = sum(total_analysis_profit_positive, na.rm = TRUE),
      employees = sum(employees, na.rm = TRUE),
      average_etr = weighted.mean(avg_etr_stage1, total_analysis_profit_positive, na.rm = TRUE),
      distributional_low_share = weighted.mean(
        stage1_distributional_low_share,
        total_analysis_profit_positive,
        na.rm = TRUE
      ),
      .groups = "drop"
    ) %>%
    mutate(
      profit_per_employee = corrected_profit / employees,
      threshold_group = factor(
        case_when(
          average_etr < GMT_RATE ~ "Below 15% avg. ETR",
          distributional_low_share >= 0.25 ~ "Above 15% avg. ETR, tail at least 25%",
          TRUE ~ "Above 15% avg. ETR, smaller tail"
        ),
        levels = c(
          "Above 15% avg. ETR, smaller tail",
          "Above 15% avg. ETR, tail at least 25%",
          "Below 15% avg. ETR"
        )
      ),
      label_country = affiliate %in% label_selected_countries
    ) %>%
    filter(
      is.finite(profit_per_employee),
      profit_per_employee > 0,
      is.finite(average_etr),
      corrected_profit > 0
    )

  label_positions <- tibble::tribble(
    ~affiliate, ~label_x, ~label_y,
    "DEU", 1.75e5, 0.214,
    "FRA", 7.25e4, 0.223,
    "ESP", 7.50e4, 0.167,
    "BEL", 2.85e5, 0.174,
    "AUT", 2.65e5, 0.125,
    "HUN", 7.50e4, 0.105,
    "NLD", 5.60e5, 0.065,
    "IRL", 1.55e6, 0.122,
    "LUX", 3.25e6, 0.060
  )

  label_data <- country_plot %>%
    filter(label_country) %>%
    inner_join(label_positions, by = "affiliate")

  ggplot(
    country_plot,
    aes(
      x = profit_per_employee,
      y = average_etr,
      size = corrected_profit,
      colour = threshold_group
    )
  ) +
    geom_hline(
      yintercept = GMT_RATE,
      colour = thesis_cols[["red"]],
      linetype = "dashed",
      linewidth = 0.45
    ) +
    geom_point(alpha = 0.76) +
    geom_segment(
      data = label_data,
      aes(xend = label_x, yend = label_y),
      linewidth = 0.25,
      colour = thesis_cols[["grey"]],
      alpha = 0.55,
      show.legend = FALSE
    ) +
    geom_text(
      data = label_data,
      aes(x = label_x, y = label_y, label = affiliate),
      inherit.aes = FALSE,
      size = 2.15,
      colour = thesis_cols[["navy"]],
      fontface = "bold",
      show.legend = FALSE
    ) +
    scale_x_log10(
      labels = format_usd_short,
      breaks = c(1e4, 1e5, 1e6, 1e7, 1e8),
      expand = expansion(mult = c(0.04, 0.10))
    ) +
    scale_y_continuous(
      labels = label_percent(accuracy = 1),
      limits = c(0, 0.25),
      breaks = seq(0, 0.25, by = 0.05),
      expand = expansion(mult = c(0.02, 0.02))
    ) +
    scale_size_area(
      max_size = 10,
      breaks = c(1e11, 5e11, 1e12),
      labels = format_usd_short,
      name = "Corrected profit",
      guide = guide_legend(
        order = 2,
        nrow = 1,
        override.aes = list(size = c(2.8, 4.5, 6.2), alpha = 0.76),
        keywidth = unit(0.55, "lines")
      )
    ) +
    scale_colour_manual(
      values = c(
        "Below 15% avg. ETR" = thesis_cols[["red"]],
        "Above 15% avg. ETR, tail at least 25%" = thesis_cols[["orange"]],
        "Above 15% avg. ETR, smaller tail" = thesis_cols[["navy"]]
      ),
      name = NULL,
      guide = guide_legend(
        override.aes = list(size = 3.2, alpha = 0.76),
        nrow = 2,
        ncol = 2,
        byrow = TRUE,
        order = 1,
        keywidth = unit(0.55, "lines")
      )
    ) +
    labs(
      x = "Corrected profit per employee (USD, log scale)",
      y = "Profit-weighted bounded ETR"
    ) +
    theme_thesis() +
    theme(
      legend.box = "vertical",
      legend.box.spacing = unit(0.25, "lines"),
      legend.spacing.y = unit(0.2, "lines"),
      legend.spacing.x = unit(0.35, "lines"),
      legend.key.height = unit(0.5, "lines"),
      legend.margin = margin(t = 2, r = 0, b = 2, l = 0),
      axis.title.x = element_text(margin = margin(t = 4, b = 2)),
      plot.margin = margin(2, 4, 6, 2),
      legend.text = element_text(size = 7)
    )
}

make_semielasticity_plot <- function() {
  coef <- readRDS(file.path(PROCESSED_DIR, "stage3_model_coefficients.rds")) %>%
    filter(inference == "parent_affiliate_clustered")

  pick_coef <- function(model, term) {
    coef %>%
      filter(model_spec == model, term == !!term) %>%
      slice(1) %>%
      pull(estimate)
  }

  t0_log <- coef %>%
    filter(model_spec == "logarithmic") %>%
    slice(1) %>%
    pull(t0)

  b_linear <- pick_coef("linear", "tau")
  b_quad_1 <- pick_coef("quadratic", "tau")
  b_quad_2 <- pick_coef("quadratic", "tau_sq")
  b_log_1 <- pick_coef("logarithmic", "tau")
  b_log_2 <- pick_coef("logarithmic", "log_tau")

  tau_grid <- seq(0.005, 0.30, by = 0.001)

  curves <- bind_rows(
    tibble(
      model = "Linear, selected",
      tau = tau_grid,
      semi_elasticity = -b_linear,
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(b_linear * (GMT_RATE - tau)),
        1
      )
    ),
    tibble(
      model = "Quadratic",
      tau = tau_grid,
      semi_elasticity = -(b_quad_1 + 2 * b_quad_2 * tau),
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(b_quad_1 * (GMT_RATE - tau) + b_quad_2 * (GMT_RATE^2 - tau^2)),
        1
      )
    ),
    tibble(
      model = "Logarithmic",
      tau = tau_grid,
      semi_elasticity = -(b_log_1 + b_log_2 / (t0_log + tau)),
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(
          b_log_1 * (GMT_RATE - tau) +
            b_log_2 * (log(t0_log + GMT_RATE) - log(t0_log + tau))
        ),
        1
      )
    )
  ) %>%
    mutate(
      model = factor(model, levels = c("Linear, selected", "Quadratic", "Logarithmic"))
    )

  ggplot(curves, aes(x = tau, y = semi_elasticity, colour = model)) +
    geom_vline(
      xintercept = GMT_RATE,
      colour = thesis_cols[["grey"]],
      linetype = "dashed",
      linewidth = 0.4
    ) +
    geom_line(linewidth = 0.9) +
    annotate(
      "text",
      x = GMT_RATE + 0.006,
      y = max(curves$semi_elasticity, na.rm = TRUE) - 0.08,
      label = "15% floor",
      hjust = 0,
      size = 2.6,
      colour = thesis_cols[["grey"]]
    ) +
    scale_x_continuous(
      labels = label_percent(accuracy = 1),
      breaks = seq(0, 0.30, by = 0.05),
      limits = c(0, 0.30),
      expand = expansion(mult = c(0.01, 0.02))
    ) +
    scale_y_continuous(
      breaks = seq(1.2, 2.1, by = 0.2),
      expand = expansion(mult = c(0.03, 0.08))
    ) +
    scale_colour_manual(
      values = c(
        "Linear, selected" = thesis_cols[["navy"]],
        "Quadratic" = thesis_cols[["orange"]],
        "Logarithmic" = thesis_cols[["red"]]
      ),
      name = "Functional form"
    ) +
    labs(
      x = "Pre-reform ETR",
      y = "Semi-elasticity of reported profit"
    ) +
    theme_thesis(base_size = 8) +
    theme(
      legend.box = "horizontal",
      legend.margin = margin(t = -2, b = -2),
      plot.margin = margin(2, 4, 2, 2)
    )
}

make_decomposition_plot <- function() {
  main_effects <- readRDS(file.path(PROCESSED_DIR, "stage4_6_main_effects_pooled.rds")) %>%
    select(effect, high_minus_low)

  shapley <- readRDS(file.path(PROCESSED_DIR, "stage4_6_shapley_factor_attribution.rds")) %>%
    left_join(main_effects, by = "effect") %>%
    mutate(
      factor_label = recode(
        effect,
        "x1_etr" = "ETR measurement",
        "x4_sbs" = "SbS regime",
        "x2_substance" = "Substance specification",
        "x5_behaviour" = "Behavioural response",
        "x3_rates" = "SBIE rate endpoint",
        .default = factor_label
      ),
      factor_label = factor(factor_label, levels = factor_label[order(shapley_eta_squared)]),
      fill_group = case_when(
        effect == "x1_etr" ~ "Measurement",
        effect == "x4_sbs" ~ "Legal allocation",
        effect == "x5_behaviour" ~ "Behavioural",
        TRUE ~ "Substance and policy"
      ),
      bar_label = paste0(
        label_percent(accuracy = 0.1)(shapley_eta_squared),
        "  ",
        format_signed_bn(high_minus_low)
      )
    )

  ggplot(shapley, aes(x = shapley_eta_squared, y = factor_label, fill = fill_group)) +
    geom_col(width = 0.66, colour = "white", linewidth = 0.2) +
    geom_text(
      aes(label = bar_label),
      hjust = -0.04,
      size = 2.45,
      colour = thesis_cols[["navy"]]
    ) +
    scale_x_continuous(
      labels = label_percent(accuracy = 1),
      limits = c(0, max(shapley$shapley_eta_squared) * 1.18),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(
      values = c(
        "Measurement" = thesis_cols[["navy"]],
        "Legal allocation" = thesis_cols[["red"]],
        "Behavioural" = thesis_cols[["orange"]],
        "Substance and policy" = thesis_cols[["grey"]]
      ),
      name = NULL
    ) +
    labs(
      x = "Share of pooled EU scenario variance",
      y = NULL
    ) +
    theme_thesis(base_size = 8.2) +
    theme(
      legend.position = "none",
      plot.margin = margin(2, 8, 2, 2)
    )
}

make_country_salience_plot <- function() {
  fiscal <- readRDS(file.path(PROCESSED_DIR, "stage4_6_fiscal_salience_country.rds"))
  anova_country <- readRDS(file.path(PROCESSED_DIR, "stage4_6_anova_by_country.rds"))

  dominant <- anova_country %>%
    filter(interaction_order == 1) %>%
    group_by(country) %>%
    slice_max(eta_squared, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(country, dominant_channel = effect_label)

  plot_data <- fiscal %>%
    left_join(dominant, by = "country") %>%
    mutate(
      revenue_to_cit_1200 = if_else(
        !is.finite(revenue_to_cit_1200) & preferred_revenue == 0,
        0,
        revenue_to_cit_1200
      ),
      scenario_spread_to_cit_1200 = if_else(
        !is.finite(scenario_spread_to_cit_1200) & scenario_spread == 0,
        0,
        scenario_spread_to_cit_1200
      ),
      dominant_channel = recode(
        dominant_channel,
        "ETR measurement" = "ETR measurement",
        "SbS regime" = "SbS regime",
        "Substance specification" = "Substance",
        "Behavioural response" = "Behavioural response",
        .default = dominant_channel
      ),
      label_country = country %in% c("NLD", "IRL", "LUX", "DEU", "FRA", "HUN", "BEL", "DNK", "AUT")
    )

  label_offsets <- tibble::tribble(
    ~country, ~dx, ~dy,
    "NLD", -0.025, 0.022,
    "IRL", 0.010, 0.020,
    "HUN", -0.030, 0.010,
    "DEU", 0.024, 0.012,
    "FRA", 0.000, 0.018,
    "BEL", 0.026, -0.014,
    "DNK", 0.010, -0.020,
    "AUT", -0.016, -0.014
  )

  label_data <- plot_data %>%
    filter(label_country, country != "LUX") %>%
    inner_join(label_offsets, by = "country") %>%
    mutate(
      label_x = revenue_to_cit_1200 + dx,
      label_y = scenario_spread_to_cit_1200 + dy
    )

  ggplot(
    filter(plot_data, country != "LUX"),
    aes(
      x = revenue_to_cit_1200,
      y = scenario_spread_to_cit_1200,
      colour = dominant_channel,
      size = preferred_revenue
    )
  ) +
    geom_abline(
      slope = 1,
      intercept = 0,
      colour = thesis_cols[["mid"]],
      linetype = "dotted",
      linewidth = 0.45
    ) +
    geom_point(alpha = 0.78) +
    geom_segment(
      data = label_data,
      aes(
        x = revenue_to_cit_1200,
        y = scenario_spread_to_cit_1200,
        xend = label_x,
        yend = label_y
      ),
      inherit.aes = FALSE,
      linewidth = 0.25,
      colour = thesis_cols[["grey"]],
      alpha = 0.55,
      show.legend = FALSE
    ) +
    geom_label(
      data = label_data,
      aes(x = label_x, y = label_y, label = country),
      inherit.aes = FALSE,
      size = 2.35,
      linewidth = 0.18,
      label.padding = grid::unit(0.04, "lines"),
      label.r = grid::unit(0.02, "lines"),
      fill = "white",
      colour = thesis_cols[["navy"]],
      show.legend = FALSE
    ) +
    annotate(
      "segment",
      x = 0.405,
      xend = 0.448,
      y = 0.405,
      yend = 0.448,
      colour = thesis_cols[["red"]],
      linewidth = 0.35,
      arrow = grid::arrow(length = grid::unit(0.10, "cm"), type = "closed")
    ) +
    annotate(
      "label",
      x = 0.326,
      y = 0.445,
      label = "LUX outside scale:\n225% revenue, 182% spread",
      hjust = 0,
      size = 2.35,
      linewidth = 0.18,
      label.padding = grid::unit(0.10, "lines"),
      label.r = grid::unit(0.04, "lines"),
      fill = "white",
      colour = thesis_cols[["red"]]
    ) +
    scale_x_continuous(
      labels = label_percent(accuracy = 1),
      breaks = c(0, 0.05, 0.10, 0.25, 0.40),
      limits = c(0, 0.46),
      expand = expansion(mult = c(0.01, 0.03))
    ) +
    scale_y_continuous(
      labels = label_percent(accuracy = 1),
      breaks = c(0, 0.05, 0.10, 0.25, 0.40),
      limits = c(0, 0.46),
      expand = expansion(mult = c(0.01, 0.04))
    ) +
    scale_size_area(
      max_size = 8,
      breaks = c(5e9, 25e9, 75e9),
      labels = format_usd_short,
      name = "Preferred revenue",
      guide = guide_legend(
        order = 2,
        nrow = 1,
        override.aes = list(size = c(2.4, 4.2, 6.0), alpha = 0.78),
        keywidth = unit(0.55, "lines")
      )
    ) +
    scale_colour_manual(
      values = c(
        "ETR measurement" = thesis_cols[["navy"]],
        "SbS regime" = thesis_cols[["red"]],
        "Substance" = thesis_cols[["orange"]],
        "Behavioural response" = thesis_cols[["grey"]]
      ),
      name = "Dominant channel",
      guide = guide_legend(
        order = 1,
        nrow = 2,
        ncol = 2,
        byrow = TRUE,
        override.aes = list(size = 3.2, alpha = 0.78),
        keywidth = unit(0.55, "lines")
      )
    ) +
    labs(
      x = "Preferred revenue as share of CIT",
      y = "Scenario spread as share of CIT"
    ) +
    theme_thesis(base_size = 8.2) +
    theme(
      legend.box = "vertical",
      legend.box.spacing = unit(0.25, "lines"),
      legend.spacing.y = unit(0.2, "lines"),
      legend.spacing.x = unit(0.35, "lines"),
      legend.key.height = unit(0.5, "lines"),
      legend.margin = margin(t = 2, r = 0, b = 2, l = 0),
      axis.title.x = element_text(margin = margin(t = 4, b = 2)),
      plot.margin = margin(2, 4, 6, 2)
    )
}

make_preferred_channel_plot <- function() {
  channel <- readRDS(file.path(PROCESSED_DIR, "stage4_6_preferred_channel_summary.rds")) %>%
    mutate(
      regime = recode(
        factor4_sbs,
        "universal" = "Universal",
        "sbs" = "Side-by-Side"
      ),
      regime = factor(regime, levels = c("Universal", "Side-by-Side")),
      channel = factor(channel, levels = c("QDMTT", "IIR", "UTPR")),
      channel_label = if_else(revenue_bn >= 20, paste0(channel, "\n", round(revenue_bn, 1)), "")
    )

  totals <- channel %>%
    group_by(regime) %>%
    summarise(total_bn = sum(revenue_bn), .groups = "drop")

  utpr_loss <- channel %>%
    filter(channel == "UTPR") %>%
    summarise(loss_bn = revenue_bn[regime == "Universal"] - revenue_bn[regime == "Side-by-Side"]) %>%
    pull(loss_bn)

  ggplot(channel, aes(x = revenue_bn, y = regime, fill = channel)) +
    geom_col(width = 0.55, colour = "white", linewidth = 0.25) +
    geom_text(
      aes(label = channel_label),
      position = position_stack(vjust = 0.5),
      colour = "white",
      size = 2.35,
      lineheight = 0.92,
      show.legend = FALSE
    ) +
    geom_text(
      data = totals,
      aes(x = total_bn + 12, y = regime, label = paste0("Total US$", round(total_bn, 1), "bn")),
      inherit.aes = FALSE,
      hjust = 0,
      size = 2.45,
      colour = thesis_cols[["navy"]]
    ) +
    annotate(
      "text",
      x = 420,
      y = 1.5,
      label = paste0("UTPR loss under SbS: US$", round(utpr_loss, 1), "bn"),
      size = 2.45,
      colour = thesis_cols[["red"]]
    ) +
    scale_x_continuous(
      labels = function(x) paste0("US$", x, "bn"),
      limits = c(0, 585),
      breaks = seq(0, 500, by = 100),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(
      values = c(
        "QDMTT" = thesis_cols[["navy"]],
        "IIR" = thesis_cols[["orange"]],
        "UTPR" = thesis_cols[["red"]]
      ),
      name = "Collection channel"
    ) +
    labs(
      x = "Cumulative preferred-core revenue, 2017 to 2022",
      y = NULL
    ) +
    theme_thesis(base_size = 8.2) +
    theme(
      legend.box = "horizontal",
      plot.margin = margin(2, 4, 2, 2)
    )
}

run_generate_results_figures <- function() {
  old_options <- options(lifecycle_verbosity = "quiet")
  on.exit(options(old_options), add = TRUE)
  figures <- list(
    fig_profit_employee_etr_bubble = make_profit_employee_etr_bubble(),
    fig_stage3_semielasticity_estimated = make_semielasticity_plot(),
    fig_stage46_shapley_variance = make_decomposition_plot(),
    fig_country_salience_uncertainty = make_country_salience_plot(),
    fig_preferred_channel_composition = make_preferred_channel_plot()
  )

  figure_files <- c(
    fig_profit_employee_etr_bubble = "fig_profit_employee_etr_bubble.pdf",
    fig_stage3_semielasticity_estimated = "fig_stage3_semielasticity_estimated.pdf",
    fig_stage46_shapley_variance = "fig_stage46_shapley_variance.pdf",
    fig_country_salience_uncertainty = "fig_country_salience_uncertainty.pdf",
    fig_preferred_channel_composition = "fig_preferred_channel_composition.pdf"
  )

  save_thesis_plot(figures$fig_profit_employee_etr_bubble,
    figure_files[["fig_profit_employee_etr_bubble"]], 6.7, 5.35
  )
  save_thesis_plot(figures$fig_stage3_semielasticity_estimated,
    figure_files[["fig_stage3_semielasticity_estimated"]], 5.8, 2.85
  )
  save_thesis_plot(figures$fig_stage46_shapley_variance,
    figure_files[["fig_stage46_shapley_variance"]], 6.7, 3.45
  )
  save_thesis_plot(figures$fig_country_salience_uncertainty,
    figure_files[["fig_country_salience_uncertainty"]], 6.0, 4.25
  )
  save_thesis_plot(figures$fig_preferred_channel_composition,
    figure_files[["fig_preferred_channel_composition"]], 6.7, 2.8
  )

  message(
    paste(
      "Generated figures:",
      file.path(FIGURES_DIR, unname(figure_files)),
      collapse = "\n"
    )
  )

  invisible(figures)
}

if (is_direct_script_run("code/13_generate_results_figures.R")) {
  run_generate_results_figures()
}
