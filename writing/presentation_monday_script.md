
## Slide 1, Title, about 45 seconds

Good morning. This presentation gives a progress update on the thesis.

The thesis studies the Global Minimum Tax, also known as Pillar Two, using Country-by-Country Reporting data. The central question is simple: why do revenue estimates for the Global Minimum Tax differ so much?

That question matters because the policy is often discussed as one international reform with one fiscal effect. In practice, the estimate depends on three objects: which profit is low-taxed, how much remains after substance relief and behaviour, and which jurisdiction can collect the top-up tax.

So the presentation is an empirical economics presentation about measurement, estimation and decomposition.

## Slide 2, Core Claim, about 1 minute and 20 seconds

The core claim is that Global Minimum Tax revenue uncertainty cannot be understood as a behavioural elasticity problem alone.

Behaviour is part of the story. If multinationals shift less profit into low-tax jurisdictions after the reform, the base changes. That is the standard profit-shifting channel, and it is estimated in the thesis.

But there is a prior measurement problem. Before behaviour can be modelled, the analysis must decide what the low-taxed base is, which taxes count, how much is shielded by payroll and tangible assets, and which tax jurisdiction has the legal right to collect.

Those questions define the empirical object.

That is why the thesis is split into two layers. The measurement framework translates Pillar Two into variables. The methodology estimates behaviour, compares modelling choices and decomposes the scenario spread.

The working rule is that tax law enters the presentation only where it changes a measurable object or a scenario factor.

## Slide 3, Two Layers, about 1 minute and 15 seconds

This slide gives the map of the argument.

The measurement framework answers the question: what is counted? It defines corrected profit, the low-taxed share, the top-up gap, the substance shield and the collector-country channel.

The methodology answers a different question: how are unknowns estimated and varied? This is where the panel profit-shifting model, the 32 scenarios and the variance decomposition enter.

If the Substance-Based Income Exclusion reduces the tax base, that belongs to the measurement framework. It changes the measured amount of taxable excess profit.

If the behavioural response is estimated with parent-affiliate fixed effects, that belongs to the methodology. It is an econometric choice about one parameter in the revenue pipeline.

So the project is an empirical framework with tax rules as the accounting architecture.

## Slide 4, Data, about 1 minute and 25 seconds

The data structure follows the same discipline. Each source has one job.

The main source is anonymised and aggregated Country-by-Country Reporting data. These data observe profit, tax, payroll, tangible assets and revenue by parent and affiliate jurisdiction.

Table I provides the bilateral panel. It is used for the econometric part because it gives repeated parent-affiliate observations over 2017 to 2022.

Table IV reports profit by effective-tax-rate bracket. It measures the low-taxed base directly where the bracket data are observed.

Foreign Affiliates Statistics and EU KLEMS enter only for the sectoral bridge. They are not tax datasets. Their role is to split aggregate exposure across sectors when the thesis studies the substance and tax-incentive channels.

Finally, implementation sources are used for allocation. They tell the model whether the domestic minimum tax, the Income Inclusion Rule, the Undertaxed Profits Rule and the Side-by-Side regime apply.

The point is source discipline: tax and profit come from CbCR, sectoral structure from FATS and EU KLEMS, and collection rules from implementation data.

## Slide 5, Measurement Framework, about 1 minute and 30 seconds

This slide is the bridge between the tax system and the empirical model.

The pipeline starts with corrected profit. Reported CbCR profit cannot simply be treated as Pillar Two income.

The second step is effective tax rate measurement. If the rate is below the minimum threshold, there is potential top-up tax. Its size depends on the low-taxed share and the top-up gap.

The third step is the substance shield. The Substance-Based Income Exclusion protects a return on payroll and tangible assets. These variables determine how much low-taxed profit remains taxable.

The fourth step is the behavioural filter. The observed pre-reform base is adjusted because the reform changes the incentive to report profit in very low-tax jurisdictions.

The final step is allocation. A dollar of top-up tax can be collected domestically through a Qualified Domestic Minimum Top-up Tax, by the parent jurisdiction through the Income Inclusion Rule, or residually through the Undertaxed Profits Rule.

The value of the framework is that it makes the analysis auditable. Each empirical choice is attached to one place in the pipeline.

## Slide 6, Stage 1, about 1 minute and 15 seconds

Stage 1 measures the low-taxed profit mass.

The key issue is that a jurisdiction average can hide the relevant base. If one part of profit is taxed at 5 percent and another part at 25 percent, the average may look acceptable. Pillar Two is concerned with the part below the threshold.

For that reason, the thesis uses a hierarchy of evidence.

Where Table IV directly observes effective-tax-rate brackets, that information is used first. It is closest to the object that has to be measured.

Where direct brackets are not available, a distribution is fitted within the country-pair cell. This estimates the mass below the threshold instead of treating the whole jurisdiction as one average.

Only where the data do not support the distributional approach does the model fall back on a jurisdiction-average method.

The logic is therefore direct bracket evidence first, modelled distributions second, averages only as a final fallback.

## Slide 7, Stage 2, about 1 minute and 15 seconds

Stage 2 adds substance and sectoral exposure.

The 15 percent minimum tax is not a simple tax on all low-taxed profit. The Substance-Based Income Exclusion shields part of the base through payroll and tangible assets. The headline floor becomes a lower effective floor when there is substantial real activity.

That is where sectors become relevant. Manufacturing, finance, digital services and capital-intensive activities do not have the same payroll and asset structure.

CbCR does not provide the sectoral detail needed for this question. The choice made in the thesis is to use FATS and EU KLEMS as a bridge, while CbCR remains the tax and profit source.

The Substance-Based Tax Incentive layer is interpreted carefully. Public data do not observe actual claims or elections. What can be measured is exposure capacity.

This stage therefore gives the thesis an economic interpretation beyond a global revenue number.

## Slide 8, Econometric Method, about 1 minute and 45 seconds

The econometric part estimates the behavioural filter in the pipeline.

The model follows the Hines-Rice profit-shifting tradition. The dependent variable is reported profit in a CbCR parent-affiliate cell. The key tax variable captures the incentive to report profit in the affiliate jurisdiction.

Three functional forms are estimated: linear, quadratic and logarithmic. The initial expectation was that profit shifting might be sharply nonlinear at very low effective tax rates. The Bayesian Information Criterion tests whether that flexibility is supported by the panel.

Parent-affiliate pair fixed effects absorb persistent bilateral differences, such as commercial ties, treaty networks or stable reporting patterns. Year fixed effects absorb common shocks over time.

The standard errors are clustered by parent jurisdiction and affiliate jurisdiction. That reflects the fact that observations are not independent within reporting countries or host countries.

The interpretation is deliberately modest. The estimate is not a firm-level causal effect. It is a CbCR-cell semi-elasticity of reported profit, conditional on pair fixed effects, year fixed effects and controls.

That is the right object for this thesis because the revenue model itself is built at the aggregated CbCR-cell level.

## Slide 9, Simulation Method, about 1 minute and 20 seconds

The simulation uses a full factorial design. The thesis defines five binary modelling choices and runs all combinations. With five binary factors, that gives 32 scenarios.

The level labels are important. Level 0 and Level 1 are coding labels. They do not mean bad and good, or lower and higher revenue.

The five factors map directly onto the pipeline: effective tax rate measurement, substance specification, the Substance-Based Income Exclusion rate schedule, the implementation regime and the behavioural filter.

The benefit is statistical clarity. Once the 32 scenarios are calculated, the revenue spread can be decomposed into main effects and interactions.

That is the methodological contribution of the simulation layer.

## Slide 10, Result 1, about 1 minute and 20 seconds

The first result concerns behaviour.

The tax-profit relationship is statistically significant. The preferred linear coefficient is negative and precisely estimated, consistent with profit shifting.

However, the model comparison does not support the strongest version of the behavioural hypothesis. The linear specification is preferred over the logarithmic and quadratic alternatives.

This result disciplines the thesis. The panel does not support the stronger claim that the very low-tax tail dominates the revenue answer.

Behaviour still lowers revenue in economically meaningful dollar terms. The narrower implication is that behaviour is not the main explanation for why revenue estimates differ across scenarios.

For a statistician, this is the key point. The econometric layer tests whether the behavioural channel is large enough to dominate the revenue spread. In the current results, it is not.

## Slide 11, Result 2, about 1 minute and 20 seconds

The second result is the variance decomposition, and this is the central result of the presentation.

Across the 32 scenarios, effective tax rate measurement explains 62.2 percent of the variation in revenue estimates. The Side-by-Side regime explains 25.4 percent. The substance specification explains 3.7 percent. The behavioural response explains 3.4 percent. All interactions together explain 5.3 percent.

The spread in credible revenue estimates is driven mainly by two questions.

First, does the data strategy identify the low-taxed base, or does it hide low-taxed profit inside jurisdiction averages?

Second, which jurisdiction has the legal right to collect once the base has been measured?

The behavioural coefficient matters, but it does not explain most scenario variance. A behavioural adjustment can be economically meaningful in levels and still explain only a small share of the cross-scenario spread.

That is the main answer emerging from the thesis at this stage.

## Slide 12, Result 3, about 1 minute and 10 seconds

The third result translates the decomposition into revenue magnitudes. Across the scenario space, cumulative EU collector-country revenue over 2017 to 2022 ranges from about 125.8 billion to 553.9 billion US dollars.

The main positive contribution comes from effective tax rate measurement. Moving from the jurisdiction-average benchmark to the direct or distribution-sensitive approach raises the average estimate by about 205.6 billion dollars.

The Side-by-Side regime reduces the estimate by about 117.3 billion dollars. The behavioural response reduces it by about 47.1 billion dollars. The sectoral substance specification reduces it by about 42.6 billion dollars. The SBIE rate endpoint adds about 9.0 billion dollars.

These are scenario main effects, not separate forecasts. Their function is to show scale and ordering.

The ordering is clear: measurement and allocation move the estimate more than the behavioural main effect.

## Slide 13, Result 4, about 1 minute and 15 seconds

The fourth result concerns the Side-by-Side regime.

This is an allocation result, not mainly a behavioural result. Under the Side-by-Side treatment, certain US-parented groups are treated differently for residual collection. Residual Income Inclusion Rule and Undertaxed Profits Rule collection is set to zero for those groups. Domestic minimum taxes remain where they apply.

In the preferred mechanical core, the universal regime gives total revenue of about 531.6 billion dollars. Under Side-by-Side treatment, this falls to about 362.1 billion dollars.

The Undertaxed Profits Rule is the channel that changes most. It falls from about 237.2 billion dollars to about 67.8 billion dollars.

The same low-taxed base can therefore produce a different revenue number depending on who may collect. That is why implementation belongs inside the empirical framework.

## Slide 14, Result 5, about 1 minute and 20 seconds

The fifth result is the sectoral Substance-Based Tax Incentive exposure.

The SBTI layer lowers the effective floor more where foreign-controlled sectors are more capital-intensive. At the EU aggregate level, the effective floor falls from 14.2 percent to 11.9 percent.

The reduction is larger in Germany and France than in the Netherlands, Ireland and Luxembourg. The reason is sectoral structure: more payroll and tangible assets in exposed sectors.

This result adds an economic incidence layer. The substance-based design creates different exposure across sectors and countries.

The caveat must be stated clearly. Public data measure exposure capacity. They do not observe actual safe-harbour elections, qualifying claims or the legal details of each credit.

That caveat defines what the result is.

## Slide 15, Current Thesis Position, about 1 minute and 25 seconds

The thesis position is now more precise than in the proposal.

Hypothesis 1, about a sharply nonlinear behavioural response, is weakened. The tax-profit relationship is significant, but the linear model is selected by the data.

Hypothesis 2, about effective tax rate measurement, is strongly supported. This is the dominant driver of scenario variance.

Hypothesis 3, about interactions in the factorial design, is not supported at the threshold set in the thesis. Interactions exist, but all interactions together explain 5.3 percent of the variation.

Hypothesis 4 is supported. The Side-by-Side regime substantially reduces residual EU collection.

Hypothesis 5 is supported with a caveat. Sectoral SBTI exposure is stronger in capital-intensive cells, but the public data measure exposure capacity rather than actual elections or claims.

The contribution is therefore not one preferred revenue number. It is the explanation of why numbers differ: base measurement, allocation of taxing rights and, to a smaller but still relevant extent, behavioural adjustment.

## Slide 16, Thank You, about 40 seconds

Let me close with the main message.

Global Minimum Tax revenue estimation is not only a question of how firms respond. It is also a question of what is counted, how low-taxed profit is measured, and which jurisdiction can collect.

That is why the thesis separates the measurement framework from the methodology.

The framework defines the tax base and the collection channels. The methodology estimates the behavioural filter and decomposes scenario variance. Together, they show that measurement and implementation choices explain more of the current revenue spread than the behavioural elasticity alone.

The most useful comments at this stage are about the clarity of the empirical structure, the ordering of the results, and whether the methodology is transparent for a reader who is not specialised in international taxation.
