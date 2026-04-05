# Moving Average Crossover — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Moving Average Crossover is a trend-following strategy that enters the market when the fast moving average crosses the slow moving average, interpreting the crossing event as a momentum shift. Entries are discrete events — the strategy only acts at the moment of the crossover, not while the fast MA is simply above or below the slow MA. Exits combine a minimum holding period with a minimum profit threshold: the strategy stays in a trade until enough time has elapsed and enough profit has not materialized, at which point it exits as an inefficient trade.

v2 extends v1 with two meaningful additions: a volume filter that requires above-average participation to confirm the crossover signal, and a configurable stop loss that can be applied either per position or per contract — making the strategy adaptable to stocks, futures, and CFDs.

---

## Core Mechanics

### 1. Moving Average Calculation

```pascal
// v1
ShortMA = Average(ShortPrice, ShortLen);
LongMA  = Average(LongPrice,  LongLen);

// v2
FastMA = AverageFC(FastPrice, FastLen);
SlowMA = AverageFC(SlowPrice, SlowLen);
```

Both versions use simple moving averages. v2 replaces `Average` with `AverageFC` — the "fast calculation" variant that uses an incremental update algorithm rather than recalculating the full sum on every bar. Functionally identical; computationally more efficient, which matters when running multiple strategies simultaneously or on large datasets.

The price source (`ShortPrice`/`FastPrice`, `LongPrice`/`SlowPrice`) defaults to `Close` but is configurable — allowing the strategy to be switched to `Open`, `High`, `Low`, or a custom series without code changes.

### 2. Volume Normalization (v2 Only)

v2 adds a volume filter that adapts to the chart type being used:

```pascal
If BarType >= 2 and BarType < 5 Then
    AnyVol = Volume
Else
    AnyVol = Ticks;

AvgAnyVol = AverageFC(AnyVol, VolLen);
```

`BarType` is an EasyLanguage reserved word that returns an integer identifying the chart type: values 2–4 correspond to daily, weekly, and monthly bars, where `Volume` (share/contract volume) is the appropriate measure. All other chart types (intraday minute bars, tick bars, range bars) use `Ticks` instead, which reflects the number of trades executed rather than shares traded. This adaptation ensures the volume filter is meaningful regardless of chart type.

`AvgAnyVol` is the simple moving average of `AnyVol` over `VolLen` bars — the baseline against which current volume is compared.

### 3. Crossover Entry

```pascal
// v1 — crossover without volume filter
If ShortMA Crosses Over  LongMA Then Buy       Next Bar at Market;
If ShortMA Crosses Under LongMA Then SellShort Next Bar at Market;

// v2 — crossover gated by volume confirmation
Condition1 = AnyVol > AvgAnyVol;
If Condition1 Then
Begin
    If FastMA Crosses Over  SlowMA Then Buy       Next Bar at Market;
    If FastMA Crosses Under SlowMA Then SellShort Next Bar at Market;
End;
```

`Crosses Over` and `Crosses Under` are discrete events in EasyLanguage — they evaluate to `True` only on the exact bar where the crossing occurs, and `False` on every subsequent bar regardless of the relative position of the two MAs. This means:

- No `If` wrapping is needed to prevent repeated entries — the crossing event itself acts as a one-bar gate.
- No `[1]` offset is needed — `Crosses Over/Under` internally compares the current and previous bar's MA values to detect the transition.

In v2, `Condition1 = AnyVol > AvgAnyVol` gates both entry directions behind a volume confirmation. A crossover that occurs on below-average volume is ignored — it may reflect a lack of real participation rather than genuine momentum. Only crossovers accompanied by above-average volume are considered high-conviction signals.

> **On `Condition1`:** EasyLanguage reserves `Condition1`, `Condition2`, etc. as predefined boolean variables that do not require declaration in `Vars`. They are global implicit variables, which means their state can persist across evaluations in ways that are not always obvious. The name `Condition1` carries no semantic information — a future improvement would replace it with a named variable like `HasHighVolume`, consistent with the naming conventions used across this repository.

### 4. Exit Logic — Time and Profit Gate

```pascal
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
    Sell       Next Bar at Market;
    BuyToCover Next Bar at Market;
End;
```

The exit condition combines two independent checks:

- `BarsSinceEntry > MinHold`: the position has been held for at least `MinHold` bars. This prevents premature exits — it forces the strategy to give the trade time to develop before making a judgment on its profitability.
- `OpenPositionProfit < MinProfit`: the unrealized profit (in account currency) is below the minimum threshold. `OpenPositionProfit` reflects the current mark-to-market value of the open position.

Only when *both* conditions are true simultaneously does the strategy exit. The logic reads: *"if I have held this trade long enough and it has not produced sufficient profit, the trade is inefficient — exit."* A trade that is profitable enough after `MinHold` bars continues to run; a trade that is still developing within `MinHold` bars is given more time regardless of current profit.

Both `Sell` and `BuyToCover` are placed unconditionally — EasyLanguage ignores whichever is not applicable to the current position.

### 5. Stop Loss (v2 Only)

```pascal
If PositionBasis Then
    SetStopPosition
Else
    SetStopShare;

SetStopLoss(SLAmt);
```

v2 adds a monetary stop loss that operates independently of the time/profit exit. Two modes are available, controlled by the `PositionBasis` boolean input:

- `SetStopPosition` (when `PositionBasis = True`): the stop loss amount applies to the *total* position. For a position of 100 shares with `SLAmt = $500`, the position closes if total unrealized loss reaches $500, regardless of per-share loss.
- `SetStopShare` (when `PositionBasis = False`): the stop loss applies *per share or contract*. For 100 shares with `SLAmt = $500`, the total loss before exit would be $50,000 — per-share stop is more appropriate for futures where each contract carries significant notional value.

This distinction matters significantly when adapting the strategy across different instrument types. For stocks, position-basis is typically more intuitive. For futures, per-contract stop ensures the stop loss scales correctly with the notional size of each contract.

---

## v1 vs v2: The Difference

| | v1.0 | v2.0 |
|---|---|---|
| **MA crossover entry** | ✓ | ✓ |
| **Time + profit exit** | ✓ | ✓ |
| **Volume filter** | — | ✓ (adaptive to bar type) |
| **`AverageFC` for efficiency** | — | ✓ |
| **Stop loss** | — | ✓ (`SLAmt`) |
| **Position vs share stop basis** | — | ✓ (`PositionBasis`) |
| **Named fast/slow inputs** | `Short`/`Long` prefix | `Fast`/`Slow` prefix |

The rename from `Short`/`Long` to `Fast`/`Slow` prefix in v2 is a semantic improvement: `FastLen` and `SlowLen` communicate the role of each MA (responsive vs smooth) rather than just their relative size.

---

## Parameters

### v1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ShortPrice` | `Close` | Price series for the fast MA. |
| `LongPrice` | `Close` | Price series for the slow MA. |
| `ShortLen` | 9 | Period for the fast (short) MA. |
| `LongLen` | 18 | Period for the slow (long) MA. |
| `MinHold` | 8 | Minimum bars to hold before allowing a time/profit exit. |
| `MinProfit` | 100 | Minimum unrealized profit (in account currency) required after `MinHold` bars. |

### v2

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastPrice` | `Close` | Price series for the fast MA. |
| `SlowPrice` | `Close` | Price series for the slow MA. |
| `FastLen` | 9 | Period for the fast MA. |
| `SlowLen` | 18 | Period for the slow MA. |
| `VolLen` | 20 | Lookback period for the average volume calculation. |
| `MinHold` | 8 | Minimum bars to hold before allowing a time/profit exit. |
| `MinProfit` | 100 | Minimum unrealized profit required after `MinHold` bars. |
| `SLAmt` | 500 | Stop loss amount in account currency. Applied per position or per share based on `PositionBasis`. |
| `PositionBasis` | `True` | `True` = stop applies to total position; `False` = stop applies per share/contract. |

**On `MinHold` and `MinProfit` interaction:** These two parameters work as a pair. Setting `MinHold` too low causes premature exits on temporarily unprofitable trades. Setting `MinProfit` too high causes exits on trades that are profitable but below an unrealistic threshold. The combination should be calibrated together: `MinHold` defines the patience window, `MinProfit` defines the performance hurdle within that window.

---

## Trade Scenarios

### Scenario A — Bullish Crossover, Trade Runs to Profit (v1)

- FastMA(9) crosses above SlowMA(18). `Buy Next Bar at Market`. Entry at 45.20.
- `MinHold = 8`. For 8 bars, the exit condition is not checked.
- At bar 8: `BarsSinceEntry = 8 > MinHold (8)` → False (condition requires *strictly greater than*). No exit yet.
- At bar 9: `BarsSinceEntry = 9 > 8` → True. `OpenPositionProfit = $320 > MinProfit ($100)`. Profit condition not met for exit — trade continues.
- Trade eventually exits when the fast MA crosses below the slow MA (new `SellShort` reversal entry closes the long).

### Scenario B — Bullish Crossover, Insufficient Profit After MinHold (v1)

- Entry at 45.20. After 9 bars, `OpenPositionProfit = $60 < MinProfit ($100)`.
- Both exit conditions met: `BarsSinceEntry (9) > MinHold (8)` AND `OpenPositionProfit ($60) < MinProfit ($100)`.
- `Sell Next Bar at Market`. Trade exits as inefficient.

### Scenario C — Crossover Rejected by Volume Filter (v2)

- FastMA crosses over SlowMA on bar X.
- `AnyVol = 8,500`. `AvgAnyVol = 12,000`. `Condition1 = False`.
- Crossover occurs but volume is below average. Entry blocked. Strategy stays flat.
- Bar X+2: Crossover persists, but `Crosses Over` is no longer `True` (it was only `True` on bar X). No entry fires.
- Next qualifying crossover must occur on a bar with above-average volume.

### Scenario D — Stop Loss Before MinHold Window (v2)

- Entry at 45.20. `SLAmt = $500`, `PositionBasis = True`.
- Trade moves against position immediately. After 3 bars, total position loss reaches $500.
- `SetStopLoss` fires. Trade exits at loss. `BarsSinceEntry (3)` is less than `MinHold (8)` — the time/profit exit would not have triggered yet, but the stop loss exits regardless.

---

## Key Features

- **Crossover as discrete event:** `Crosses Over/Under` fires once per crossover, preventing repeated entries while the MAs remain in the same relative position.
- **Time-gated exit:** `MinHold` prevents premature exits, forcing the strategy to give each trade sufficient time to develop before judging its profitability.
- **Profit-qualified exit:** `MinProfit` ensures the strategy only voluntarily exits trades that are demonstrably underperforming, not simply trades that are temporarily below breakeven.
- **Volume confirmation (v2):** `AnyVol > AvgAnyVol` requires above-average participation at the moment of crossing, filtering out crossovers that occur during low-liquidity, drift-driven price movement.
- **Adaptive volume normalization (v2):** `BarType`-based selection between `Volume` and `Ticks` ensures the volume filter is meaningful across daily, intraday, and non-time-based chart types.
- **Dual stop basis (v2):** `PositionBasis` toggle allows the stop loss to be applied per-position or per-share/contract, making the strategy directly applicable to stocks and futures without parameter recalibration.
- **`AverageFC` efficiency (v2):** Faster MA calculation reduces computational load in multi-strategy environments.

---

## Trade Psychology

The MA crossover is one of the oldest and most studied trend-following signals. Its continued relevance is not because it is sophisticated — it is not — but because it captures a genuine market phenomenon: when short-term momentum shifts relative to longer-term momentum, the market is changing character. The crossover is the moment that shift becomes measurable.

The time/profit exit encodes a specific belief about trade efficiency: **not all trades that move in the right direction are worth holding.** A trade that occupies capital for 10 bars and produces $80 of unrealized profit is less efficient than one that produces the same $80 in 3 bars. `MinHold` and `MinProfit` together define the minimum acceptable efficiency — if a trade has not reached the performance threshold by the patience window, the capital is better deployed in the next signal.

The volume filter in v2 adds a layer of market microstructure reasoning. Price can move in any direction at any time, but sustained directional moves require participation. A crossover on thin volume may simply reflect the absence of sellers (or buyers) rather than genuine directional conviction. By requiring `AnyVol > AvgAnyVol`, the strategy only acts when the market is actively confirming the signal with real order flow.

---

## Use Cases

**Instruments:** Both versions work on any instrument with consistent trending behavior — equity index futures (ES, NQ), individual stocks in directional phases, commodity futures, and FX futures. The volume filter in v2 makes it particularly well-suited to futures markets where volume data is reliable and closely correlated with price momentum.

**Timeframes:** The 9/18 MA combination works across timeframes. On 5-min bars it captures short intraday trends; on daily bars it captures medium-term directional moves. `MinHold` should be interpreted relative to the timeframe — 8 bars on a 5-min chart is 40 minutes; on a daily chart it is one and a half weeks.

**v1 as a baseline:** v1 is an ideal starting point for testing the core crossover edge before adding filters. Running v1 and v2 on the same dataset and comparing results isolates the contribution of the volume filter — a clean way to evaluate whether volume confirmation adds edge on a specific instrument.

**`PositionBasis` guidance:** For stocks and ETFs, `PositionBasis = True` (position-level stop) is typically more intuitive — you define total dollar risk per trade. For futures, `PositionBasis = False` (per-contract stop) is more appropriate — the notional value per contract means a per-position stop would need constant recalibration as contract sizes change across instruments.
