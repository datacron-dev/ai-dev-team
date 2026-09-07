---
name: backtesting
description: Design, implement, and evaluate backtests for trading strategies — including vectorbt, Backtrader, and pandas-native approaches. Use this skill whenever the user mentions backtesting, strategy testing, historical simulation, walk-forward analysis, Monte Carlo on returns, transaction-cost modeling, slippage, out-of-sample testing, look-ahead bias, survivorship bias, or wants to evaluate whether a trading rule would have worked. Also use for building strategy templates, signal generation frameworks, and comparing strategies against benchmarks.
---

# Backtesting

## When to use this skill

You are working on the Financial Terminal project. A backtest is any historical simulation of a trading rule. Reach for this skill when the user asks to test a strategy, run a walk-forward, check if a rule would have made money, evaluate signal quality, or compare a strategy to buy-and-hold.

## The three-tier framework

Pick the tool that matches the question, not habit.

**Tier 1 — pandas-native (1 file, <100 lines).** Use for a single-asset rule, a one-shot answer, or when the mechanics matter more than the framework. Signals as boolean series, positions from `signal.shift(1)` (critical: `shift(1)` to avoid look-ahead), returns as `position * asset_returns`.

**Tier 2 — vectorbt.** Use for parameter sweeps, multi-asset universes, or when the user wants to compare hundreds of variants. Vectorbt shines at broadcasting — a single `Portfolio.from_signals` call across a grid of (fast, slow) MA parameters gives you a heatmap in seconds.

**Tier 3 — Backtrader.** Use for event-driven realism: order types (stop, limit, bracket), partial fills, cash management, multi-timeframe strategies, or when the user wants a stepping-stone toward a live-trading harness. Backtrader is slower but its `next()` loop mirrors how brokers actually work.

## Non-negotiable correctness rules

Every backtest must handle these — flag it in comments if you can't:

1. **No look-ahead.** Signals computed at close of bar `t` execute at open of bar `t+1` (or use `shift(1)` on positions). Never let today's signal decide today's fill.
2. **Transaction costs.** Include commission (per-share or bps) AND slippage (bps of trade value, or half-spread for wide-spread names). Default: 5 bps round-trip for liquid US equities; 20+ bps for small caps.
3. **Survivorship-free universe.** If backtesting a stock universe (e.g. "S&P 500 members"), use point-in-time membership. Backtesting today's members backward is the single most common source of fake alpha.
4. **Realistic fills.** Assume MOO/MOC fills at the opening/closing print, not at prior close. For intraday, use next-bar-open at minimum.
5. **Out-of-sample.** Split time-wise: train on early period, hold out the last 20–30%. Report both in-sample and OOS separately. If OOS is materially worse, the strategy is likely overfit.

## Standard output — every backtest returns this

```
Strategy: <name>
Period: YYYY-MM-DD to YYYY-MM-DD (X years)
Universe: <tickers>
--- Returns ---
Total return:      X.X%
CAGR:              X.X%
Volatility (ann):  X.X%
Sharpe (rf=0):     X.XX
Sortino:           X.XX
Max drawdown:      X.X%
Calmar:            X.XX
--- Trades ---
# trades:          N
Win rate:          X.X%
Avg win / avg loss: X.X% / X.X%
Profit factor:     X.XX
Avg holding period: X days
--- Costs ---
Gross return:      X.X%
Costs paid:        X.X%
Net return:        X.X%
--- Benchmark (SPY buy-hold) ---
Benchmark CAGR:    X.X%
Alpha (ann):       X.X%
Beta:              X.XX
Information ratio: X.XX
```

If any number is worse than the benchmark, say so explicitly. Do not bury it.

## Common pitfalls to explicitly check for

- **In-sample overfitting.** Sharpe > 3 on in-sample is a red flag, not a win. Always demand OOS validation.
- **Parameter sensitivity.** If Sharpe drops from 2.0 → 0.5 when the MA window changes from 20 → 21, the strategy is fitted to noise.
- **Regime dependence.** Split the backtest into 2–3 sub-periods (e.g. pre-2010, 2010–2020, post-2020) and report metrics separately. A strategy that works only in one regime should be labeled as such.
- **Fill assumptions.** Backtesting at close is a lie for anyone who can't submit MOC orders. Default to next-bar open.
- **Zero-cost fantasy.** Any backtest with commission=0 and slippage=0 is invalid until proven otherwise.

## Walk-forward pattern

For any strategy that has parameters, present walk-forward results:

```
Window: 3-year train / 1-year test, roll forward 1 year at a time
For each window:
  1. Fit parameters on train
  2. Freeze parameters
  3. Evaluate on test
  4. Report test-window metrics
Aggregate all test windows → this is the honest OOS performance
```

## Multi-strategy portfolios

When the user has multiple signals, don't just average them. Options in order of sophistication:
- Equal-weight — dumb, honest baseline
- Risk-parity — weight by inverse volatility
- Kelly-fractional — sized by edge/variance (see the `risk-portfolio-math` skill)
- Cross-sectional rank — decile portfolios (long top decile, short bottom)

## Where to save results

Save every backtest result under `reports/backtests/<strategy-name>/<YYYY-MM-DD>/` in the project. Include the config that produced it (params, universe, dates) as `config.yaml` — future you needs to reproduce this.

## Data sources

- Use the `finance` connector for US equities (OHLCV, fundamentals, earnings) — it's already wired up.
- Use Polygon.io (via the MCP server or direct API) for intraday and options data.
- Use Alpaca (via MCP or connector) for both historical data and live-trading handoff.
