# Equity-Adaptive Donchian Mean Reversion — v1.0, v2.0 & v3.0

## Strategy Description

The Equity-Adaptive Donchian Mean Reversion Strategy combines two distinct ideas into a single system: a Donchian channel breakout as the entry trigger, and a profit-driven position sizing mechanism that scales exposure up during winning periods and contracts it during drawdowns. The entry logic is contrarian — it buys when price makes a new low and sells short when price makes a new high, betting on reversion to the mean rather than trend continuation. The position sizing layer introduces a compounding effect: for every fixed dollar amount of cumulative profit, position size grows by a defined step, up to a configurable maximum.

> **Important conceptual note:** Using Donchian channel breakouts as a mean reversion signal is structurally counter-intuitive. Donchian breakouts were originally designed — and empirically validated — as trend-following signals. This tension is documented in the research notes accompanying this strategy and is discussed in detail in the Trade Psychology section.

---

## Core Mechanics

### 1. Donchian Channel Calculation

The strategy calculates the highest high and lowest low over a lookback period, shifted one bar back to avoid lookahead bias:

```pascal
DonchianLow  = Lowest(Low,  DonchianLength)[1];
DonchianHigh = Highest(High, DonchianLength)[1];
```

The `[1]` offset is critical: it means the channel boundaries are calculated using *completed* bars, not the current bar in progress. This ensures the signal fires only when price has genuinely broken the prior channel extreme, not merely during an intrabar spike that may not close beyond the level.

### 2. Mean Reversion Signals

The entry signals are contrarian — the strategy enters *against* the breakout direction:

```pascal
LongSignal  = Low  < DonchianLow;   // Price breaks below the channel → buy (expect reversion up)
ShortSignal = High > DonchianHigh;  // Price breaks above the channel → sell short (expect reversion down)
```

The logic assumes that a break of the Donchian extreme represents an exhaustion move — price has overextended and is likely to revert. This is the mean reversion hypothesis. Whether this hypothesis holds in practice depends heavily on the instrument and market regime, and is the central empirical question this strategy raises.

### 3. Equity-Adaptive Position Sizing

This is the strategy's most architecturally distinctive feature. Position size is not fixed; it is recalculated on every bar based on the strategy's cumulative net profit:

```pascal
If AbsValue(NetProfit) >= RiskUnit Then
    TradeSizeAdjust = Round(NetProfit / RiskUnit, 0) * SizeStep
Else
    TradeSizeAdjust = 0;

TradeSize = BaseTradeSize + TradeSizeAdjust;
```

**Breaking down the formula:**

- `NetProfit / RiskUnit` computes how many full risk units of profit (or loss) have accumulated.
- `Round(..., 0)` converts this to an integer — only completed risk units count, not fractions.
- Multiplying by `SizeStep` converts the integer into a share increment.
- Adding `TradeSizeAdjust` to `BaseTradeSize` produces the final position size.

**The asymmetry between gains and losses:** When `NetProfit` is positive, `TradeSizeAdjust` is positive — position size grows. When `NetProfit` is negative, `TradeSizeAdjust` is negative — position size shrinks below the base. This is the self-correcting behavior: the system automatically de-risks during drawdowns without any manual intervention.

> **v1 vs v2+ difference:** In v1, the sizing adjustment is only triggered if `NetProfit >= ProfitStopLoss OR NetProfit <= -ProfitStopLoss` — using a simple threshold check. From v2 onwards, `AbsValue(NetProfit) >= RiskUnit` is used instead, which is the correct and symmetric formulation. v1's condition produces identical results in the positive case but is logically cleaner in v2+.

### 4. Position Size Limits

```pascal
If TradeSize > MaxTradeSize Then
    TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
    TradeSize = MinTradeSize;
```

Two hard limits prevent extreme sizing in either direction. The maximum cap prevents runaway position growth during extended winning streaks. The minimum floor ensures the strategy always has meaningful market exposure — and also means the strategy continues trading even during drawdowns, which has risk implications worth noting (see Trade Psychology).

### 5. Entry Execution

```pascal
If IsFlat and LongSignal  Then
    Buy ("Donchian_MR_LE") Next Bar TradeSize Shares at Market;

If IsFlat and ShortSignal Then
    SellShort ("Donchian_MR_SE") Next Bar TradeSize Shares at Market;
```

The `IsFlat` guard (`MarketPosition = 0`) prevents entries while already in a position. This was absent in v1 — see the version evolution section below.

### 6. Risk Management

```pascal
SetStopLoss(RiskUnit);
SetProfitTarget(RiskUnit);
```

`SetStopLoss` and `SetProfitTarget` are EasyLanguage built-in functions that place symmetric exits around the entry price. Both are set to `RiskUnit` (default: $500), creating a 1:1 risk/reward structure on every trade in dollar terms. Because position size varies, the per-share profit or loss changes — but the dollar amount at risk on each trade remains constant.

---

## v1 → v2 → v3: Code Architecture Evolution

As with the other strategies in this repository, the three versions implement the same trading logic. The evolution is structural.

### v1 — Minimal and Direct

v1 is compact but has two notable weaknesses. First, there is no `IsFlat` guard — the strategy could attempt to enter while already in a position (relying on platform behavior to prevent duplicate entries). Second, parameter naming is less precise: `InitialTradeSize` instead of `BaseTradeSize`, `ProfitStopLoss` serving double duty as both the sizing threshold and the stop/target level:

```pascal
// v1 — no position guard, inline sizing logic
If Low < Lowest(Low, 21)[1] Then
    Buy Next Bar TradeSize Shares at Market;
```

The Donchian length is also hardcoded to `21` rather than exposed as a parameter.

### v2 — Explicit State and Named Parameters

v2 adds `IsFlat`, separates `RiskUnit` and `DonchianLen` as proper inputs, introduces `AbsValue()` for the symmetric sizing condition, and uses named boolean variables `LongSetup` / `ShortSetup` for the signals:

```pascal
// v2 — position guard + named signals
LongSetup = Low < Lowest(Low, DonchianLen)[1];
ShortSetup = High > Highest(High, DonchianLen)[1];

If IsFlat and LongSetup Then
    Buy Next Bar TradeSize Shares at Market;
```

### v3 — Full Separation of Concerns

v3 introduces dedicated variables for `DonchianLow` and `DonchianHigh`, renames signals to `LongSignal` / `ShortSignal` (consistent with the naming convention used across this strategy repository), and organizes the code into clearly labelled blocks:

```pascal
{ CHANNEL }
DonchianLow  = Lowest(Low,  DonchianLength)[1];
DonchianHigh = Highest(High, DonchianLength)[1];

{ SIGNALS }
LongSignal  = Low  < DonchianLow;
ShortSignal = High > DonchianHigh;

{ SIZING }
If AbsValue(NetProfit) >= RiskUnit Then
    TradeSizeAdjust = Round(NetProfit / RiskUnit, 0) * SizeStep
Else
    TradeSizeAdjust = 0;
```

Storing `DonchianLow` and `DonchianHigh` as named variables rather than calling `Lowest()` and `Highest()` inline is both a readability improvement and a minor computational one — each function is called once per bar rather than potentially twice.

### Summary

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **`IsFlat` position guard** | — | ✓ | ✓ |
| **`DonchianLength` as input** | — | ✓ | ✓ |
| **`AbsValue()` symmetric condition** | — | ✓ | ✓ |
| **Named channel variables** | — | — | ✓ |
| **Signal/execution separation** | — | — | ✓ |
| **Named order labels** | — | — | ✓ |
| **Parameters** | 4 | 6 | 6 |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `BaseTradeSize` | 1,000 | Base position size in shares before any equity adjustment. |
| `SizeStep` | 100 | Share increment added (or subtracted) per completed `RiskUnit` of net profit. |
| `MaxTradeSize` | 2,000 | Hard cap on position size during winning periods. |
| `MinTradeSize` | 100 | Hard floor on position size during losing periods. |
| `RiskUnit` | 500 | Dollar amount used as both the sizing threshold and the stop/target level. |
| `DonchianLength` | 21 | Lookback period for channel high and low calculation. |

**On `RiskUnit` dual role:** A single parameter controls both when position size adjusts and how much is risked per trade. This coupling is intentional — the risk unit that defines trade sizing is the same unit used to measure whether a trade was a winner or loser. Separating them into two parameters would be a valid future extension.

---

## Trade Scenarios

### Scenario A — Position Scaling During Winning Streak

- Starting equity: `NetProfit = $0` → `TradeSizeAdjust = 0` → `TradeSize = 1,000 shares`
- ES closes below `DonchianLow` → `LongSignal = True` → entry at market, 1,000 shares
- Profit target hits (+$500). `NetProfit = $500`.
- Next bar recalculation: `Round(500/500, 0) * 100 = 100` → `TradeSize = 1,100 shares`
- Second long entry at 1,100 shares. Profit target hits again.
- `NetProfit = $1,050` (500 + 550 from larger size). `Round(1050/500, 0) * 100 = 200` → `TradeSize = 1,200 shares`
- Each winning trade funds incrementally larger positions.

### Scenario B — Automatic De-Risking During Drawdown

- After a winning streak: `NetProfit = $2,000` → `TradeSize = 1,400 shares`
- Three consecutive stop losses hit. `NetProfit` drops to $500.
- `Round(500/500, 0) * 100 = 100` → `TradeSize = 1,100 shares`
- Two more losses. `NetProfit = -$500`.
- `Round(-500/500, 0) * 100 = -100` → `TradeSize = 1,000 + (-100) = 900 shares`
- Position size contracts automatically as equity erodes — no manual adjustment needed.

### Scenario C — Minimum Floor During Deep Drawdown

- `NetProfit = -$4,500`. `TradeSizeAdjust = Round(-4500/500, 0) * 100 = -900`
- `TradeSize = 1,000 + (-900) = 100 shares`
- Floor check: `100 >= MinTradeSize (100)` → size stays at 100 shares
- Any further losses: `TradeSizeAdjust` would produce sizes below 100, but the floor prevents it
- Strategy continues trading at minimum size, still risking $500 per trade in dollar terms

---

## Key Features

- **Equity-adaptive sizing:** Position size adjusts automatically based on cumulative net profit, creating a natural compounding effect during winning periods and a built-in de-risking mechanism during drawdowns.
- **Symmetric risk per trade:** `SetStopLoss` and `SetProfitTarget` both set to `RiskUnit` — every trade risks exactly the same dollar amount regardless of share quantity.
- **Donchian channel simplicity:** The entry signal requires only two calculations (channel high, channel low) and a single comparison per side. The logic is transparent and auditable.
- **Hard size limits:** Maximum and minimum caps prevent runaway scaling in either direction, making the position sizing bounded and predictable.
- **`[1]` offset on channel:** Calculating channel levels on completed bars eliminates lookahead bias and ensures signals fire only on genuine bar closes beyond the prior extreme.
- **Self-correcting architecture:** No external intervention is needed to adjust risk exposure — the system recalibrates position size on every bar based on observable equity metrics.

---

## Trade Psychology

The adaptive sizing mechanism embodies a principle common to many professional trading approaches: **let your winners fund your risk, not your capital base.** When the strategy is performing well, it deploys more capital into the next trade — not because it is overconfident, but because it has earned the right to do so through demonstrated profitability. When it is underperforming, it automatically pulls back. The position size becomes a real-time measure of the strategy's current validity.

The 1:1 risk/reward structure ($500 stop, $500 target) is deliberately austere. It implies the strategy needs a win rate above 50% to be profitable, placing the burden of edge entirely on the quality of the entry signal — the Donchian channel breakout. This is worth examining carefully.

**The central conceptual tension:** The entry signal uses a Donchian channel breakout to enter *against* the breakout direction. This is architecturally counter-intuitive. Donchian breakout systems were empirically validated as trend-following tools — Richard Donchian's original work, and later the Turtle Trading system developed by Richard Dennis, used channel breakouts to enter *with* the breakout, not against it. A new low in a Donchian channel is more commonly the beginning of a downtrend than an exhaustion point.

This does not mean the strategy cannot work — mean reversion at channel extremes is a legitimate concept — but it does mean the entry signal alone is insufficient evidence of exhaustion. Research on this system suggests that several filters significantly improve the robustness of contrarian Donchian entries:

- **Rejection confirmation:** Instead of `Low < DonchianLow`, requiring `Low < DonchianLow AND Close > DonchianLow` — the bar tried to break but was rejected, which is an actual reversal signal rather than just a new extreme.
- **ADX regime filter:** Mean reversion logic works best in range-bound markets (`ADX < threshold`). Trading it during strong trends increases the probability of entering against sustained momentum.
- **RSI or z-score filter:** Requiring an additional overbought/oversold condition (e.g. `RSI < 20` for longs) adds a statistical confirmation that the move is genuinely overextended.
- **Volume spike confirmation:** Real exhaustion moves are often accompanied by volume expansion. An elevated volume filter can separate climactic reversals* from routine new lows.

> **note:** Climactic reversals are high-volume, rapid price spikes signaling a trend's exhaustion and a potential sharp reversal, often occurring when a trend moves "too far, too fast". These "exhaustion" moves, such as buying/selling climaxes or V-bottoms, signify the final capitulation of one side (shorts or longs) and the entry of opposing big players.

The research accompanying this strategy also raises an interesting inversion hypothesis: if the contrarian Donchian system struggles, it may be because the signal itself has edge — but in the trend-following direction. Testing the inverted version (buy new highs, sell new lows) against the same sizing mechanism is a natural next research step.

> **Open research question:** Does this strategy have positive expectancy on its current signal logic, or does the equity-adaptive sizing simply disguise weak entry logic by compounding wins and dampening losses? Separating the contribution of the entry signal from the contribution of the position sizing mechanism — by running both with fixed sizing and adaptive sizing independently — is the correct way to answer this.

---

## Use Cases

**Instruments:** Mean reversion logic is most applicable to instruments that exhibit range-bound behavior: equity indices in low-volatility regimes, mean-reverting individual stocks, or currency pairs with well-defined trading ranges. Avoid applying this strategy to strongly trending instruments without a regime filter — the contrarian entry will consistently work against sustained momentum.

**Timeframes:** The 21-bar Donchian channel scales with the timeframe. On 5-minute bars it captures the range of the last ~1.75 hours; on daily bars it captures the range of the last month. The appropriate timeframe depends on the reversion hypothesis being tested — intraday noise reversions vs. multi-day overextension reversions are fundamentally different trading ideas.

**Trader profile:** Suited to systematic traders interested in the intersection of entry signal design and position sizing mechanics. The strategy is particularly valuable as a **research vehicle**: the clean separation between signal logic (Donchian channel) and sizing logic (equity-adaptive) makes it straightforward to isolate the contribution of each component in backtesting.

**On production readiness:** The current version requires validation of several open questions — the signal inversion hypothesis, the impact of the minimum floor on drawdown behavior, and the robustness of the 1:1 risk/reward assumption across instruments — before deployment. The adaptive sizing mechanism is sophisticated and well-constructed; the entry signal logic warrants deeper investigation before treating this as a production-ready system.
