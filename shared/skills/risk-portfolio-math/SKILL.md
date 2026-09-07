---
name: risk-portfolio-math
description: Compute risk and portfolio math — Sharpe, Sortino, Calmar, VaR, CVaR, max drawdown, Kelly criterion, position sizing, correlation matrices, portfolio optimization (mean-variance, risk parity, min-variance), and beta/alpha decomposition. Use this skill whenever the user mentions risk metrics, portfolio construction, position sizing, drawdown analysis, VaR, expected shortfall, Kelly sizing, optimal f, risk budgeting, correlation of strategies, or wants to size a trade based on edge and volatility. Also use when reviewing whether a backtest's risk numbers are computed correctly.
---

# Risk & Portfolio Math

## Core formulas — get these right or nothing else matters

**Returns.** Log returns for compounding (`np.log(p_t / p_{t-1})`), simple returns for arithmetic aggregation (`p_t / p_{t-1} - 1`). Never mix. Use log returns when summing across time; simple returns when averaging across assets.

**Annualization.** Multiply mean by periods-per-year; multiply std by `sqrt(periods-per-year)`. Trading days = 252. Weekly = 52. Monthly = 12. Hourly (24/7 crypto) = 8760.

**Sharpe ratio.** `(mean_excess_return * periods_per_year) / (std_return * sqrt(periods_per_year))`. Excess = return − risk-free rate (use 3-month T-bill; 0 is a defensible simplification for high-Sharpe strategies but say so).

**Sortino ratio.** Same as Sharpe but denominator is downside deviation only: `std of returns where return < MAR` (MAR = minimum acceptable return, usually 0 or rf). Better than Sharpe for skewed strategies.

**Max drawdown.** `min(equity / equity.expanding().max() - 1)`. Report both the depth and the recovery time (days from peak to previous high). A -30% drawdown that recovered in 90 days is not the same as one that took 3 years.

**Calmar ratio.** `CAGR / abs(MaxDD)`. The most honest single-number risk-adjusted metric for trend-followers.

## VaR and CVaR — use both

**Historical VaR(α)** = the α-quantile of the return distribution (α = 0.05 for 95% VaR). "5% of days I expect to lose at least X."

**CVaR (Expected Shortfall)** = mean return of the worst α% of days. "When it's a bad day, this is the average pain." Always report CVaR alongside VaR — VaR alone is dangerous because it says nothing about the tail beyond the threshold.

**Parametric VaR** (`z_α × σ × sqrt(T)`) assumes normal returns. Fine for a first pass; wrong for anything with fat tails (i.e. most real strategies). Prefer historical or Monte-Carlo VaR.

## Kelly criterion — how to size positions

For a bet with win prob `p`, win amount `b` (as fraction), loss amount `a`:

```
f* = (p*b - (1-p)*a) / (a*b)
```

For continuous returns (mean μ, variance σ²):
```
f* = μ / σ²   (fraction of capital to bet each period)
```

**Never bet full Kelly in practice.** Half-Kelly or quarter-Kelly is the norm — Kelly assumes you know `μ` and `σ` exactly, and you don't. Real edge estimates are noisy. Overbetting is the fastest way to blow up a strategy that "worked" in backtest.

## Position sizing decision tree

1. **Fixed fractional** (`% of equity per trade`) — dumb, honest, hard to blow up. Default 1–2% risk per trade.
2. **Volatility-targeted** (`target_vol / realized_vol × base_size`) — sizes down in choppy markets, up in calm ones. Standard for systematic strategies.
3. **Kelly-fractional** — use when you have a well-estimated edge and are willing to accept larger drawdowns. Cap at half-Kelly.
4. **Risk parity** — for multi-strategy portfolios; weight each strategy inversely to its volatility.

## Portfolio optimization

**Mean-variance (Markowitz).** Solve for weights that maximize `w^T μ - λ w^T Σ w` subject to `sum(w)=1`. Notorious for producing extreme, unstable weights because μ estimates are noisy. Only use with:
- Strong prior on returns (e.g. Black-Litterman)
- Weight constraints (no-short, max-position)
- Shrinkage on Σ (Ledoit-Wolf)

**Minimum variance.** Same optimization with μ removed — just minimize `w^T Σ w`. More stable because you're not trying to estimate returns. Good default for multi-strategy allocation.

**Risk parity.** Weights such that each asset contributes equal marginal volatility. `w_i ∝ 1/σ_i` as a first-order approximation; solve properly with `scipy.optimize` when correlations matter.

## Correlation matters more than people think

For a portfolio of `n` uncorrelated strategies each with Sharpe `S`, the portfolio Sharpe is `S × sqrt(n)`. Reality: correlations are rarely 0 and rise in drawdowns. Rolling 90-day correlation between strategies is essential — if it spikes to 0.8 during a market event, you had 1 strategy pretending to be `n`.

## Beta and alpha decomposition

`return_i,t = α + β × return_benchmark,t + ε_t` (OLS regression).

- **Beta > 1** = leveraged exposure to the benchmark.
- **Alpha statistically significant** requires t-stat > 2 on daily data with 3+ years, and > 3 to be believable after multiple-testing adjustment.

Always report R² alongside β. A strategy with β = 0.8 and R² = 0.9 is basically the benchmark; the "alpha" is noise.

## Reporting template

```
--- Risk metrics ---
Ann. return:       X.X%
Ann. volatility:   X.X%
Sharpe:            X.XX
Sortino:           X.XX
Max drawdown:      X.X% (Y days peak-to-trough, Z days to recover)
Calmar:            X.XX
95% VaR (daily):   X.X%
95% CVaR (daily):  X.X%
Skew:              X.XX
Kurtosis (excess): X.XX
--- vs benchmark ---
Beta:              X.XX
Alpha (ann):       X.X% (t-stat: X.X)
R²:                X.XX
Info ratio:        X.XX
Tracking error:    X.X%
```

## Common mistakes to catch when reviewing others' work

- Sharpe computed on monthly data annualized with sqrt(12) — then compared to daily-Sharpe strategies. Not comparable.
- VaR without CVaR.
- Max drawdown reported without recovery time.
- Alpha with no t-stat.
- Full-Kelly sizing on an out-of-sample edge estimate.
- Portfolio Sharpe = weighted avg of individual Sharpes (wrong — ignores diversification).
