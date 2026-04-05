# Multi-Data Strategy — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

The Multi-Data Strategy is a trend-following system that combines two data series from the same instrument at different timeframes: a faster **operational timeframe** (Data1) for trade execution, and a slower **higher timeframe** (Data2) for trend context. Entry signals are generated when both timeframes agree in direction, acting as a dual-filter mechanism to improve signal quality. Exits are technically driven, based on price position relative to the operational moving average.

---

## Core Mechanics

The strategy operates in three well-defined layers:

### 1. Context Confirmation (Data2 — Higher Timeframe)

A moving average is calculated on the higher timeframe (Data2). Its direction — rising or falling — determines the dominant trend context:

```pascal
MAValData2 = Average(Close, MALenData2) Data2;

// Bullish context: MA is rising
MAValData2 > MAValData2[1]

// Bearish context: MA is falling
MAValData2 < MAValData2[1]
```

> **Note on syntax:** In v1 and v2, the Data2 assignment uses the native EasyLanguage syntax `Average(Close, MALenData2) Data2`, which binds the function's data series at declaration time. This is functionally equivalent to `Average(Close of Data2, MALenData2)` used in later versions, but differs syntactically. Both approaches calculate the average on Data2's price series.

### 2. Entry Signal (Data1 — Operational Timeframe)

A moving average is calculated on Data1. The entry condition requires the **current close to be on the correct side of the MA** — above it for longs, below it for shorts — combined with the directional confirmation from Data2:

```pascal
MAValData1 = Average(Close, MALenData1);

// Long entry: higher TF is bullish AND price is above MA
If MAValData2 > MAValData2[1] and Close > MAValData1 Then
    Buy Next Bar at Market;

// Short entry: higher TF is bearish AND price is below MA
If MAValData2 < MAValData2[1] and Close < MAValData1 Then
    SellShort Next Bar at Market;
```

This is a **continuous state condition**: the signal fires on every bar where both conditions are met simultaneously. This is a key design characteristic of v1 and v2 — see the v1 vs v2 section below.

### 3. Technical Exits

The strategy exits when the **entire bar** (High or Low) is on the wrong side of the operational MA, indicating the price has clearly crossed it:

```pascal
// Exit long: entire bar closes below the MA
If MarketPosition = 1 Then
    If High < MAValData1 Then
        Sell Next Bar at Market;

// Exit short: entire bar closes above the MA
If MarketPosition = -1 Then
    If Low > MAValData1 Then
        BuyToCover Next Bar at Market;
```

Using `High < MAValData1` (instead of `Close < MAValData1`) requires the **full bar** to be below the average, making exits more robust and filtering out brief intrabar violations.

---

## v1 vs v2: The Key Difference

### v1.0 — No Position Guard

In v1, there is no check on market position before placing entry orders. This creates a **potential re-entry vulnerability**: if the strategy is already long and the conditions remain true, it could attempt to send another buy order on the next bar.

```pascal
// v1 — Entry conditions checked unconditionally
If MAValData2 > MAValData2[1] and Close > MAValData1 Then
    Buy Next Bar at Market;
```

In practice, TradeStation's position tracking prevents duplicate entries in backtesting, but this is an implicit dependency on platform behaviour rather than an explicit design decision. The code communicates ambiguous intent.

### v2.0 — Explicit Position Guard

v2 wraps both entry conditions in a `MarketPosition = 0` check. The strategy now explicitly declares: *"I only enter when I am flat."*

```pascal
// v2 — Entry only when flat
If MarketPosition = 0 Then
Begin
    If MAValData2 > MAValData2[1] and Close > MAValData1 Then
        Buy Next Bar at Market;

    If MAValData2 < MAValData2[1] and Close < MAValData1 Then
        SellShort Next Bar at Market;
End;
```

This is a small but meaningful improvement: the code now explicitly encodes the intended behavior, making it easier to reason about, audit, and extend. Think of it as the difference between a rule that says *"only one person in the booth at a time"* (v2) versus relying on the booth being physically small enough to prevent it (v1).

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MALenData1` | 12 | MA length for the operational timeframe (Data1). Controls signal sensitivity. |
| `MALenData2` | 24 | MA length for the higher timeframe (Data2). Controls trend context sensitivity. |

**Setup note:** Data1 is the faster (shorter period) chart — the execution timeframe. Data2 is the slower (longer period) chart — the trend context. A typical configuration would be Data1 = 15-minute bars, Data2 = 60-minute bars, both on the same instrument (e.g. ES futures).

---

## Trade Scenarios

### Scenario A — Long Entry (Trend Aligned)

- ES 60-min chart: MA at 4,985, previous bar MA at 4,980 → **ContextBullish = True** (MA rising)
- ES 15-min chart: MA at 4,992, current Close at 4,995 → **Close > MAValData1 = True**
- Both conditions met → **Buy next bar at market**
- Entry fills at 4,996

**Exit condition:** A 15-min bar prints with High < 4,992 (entire bar below the MA) → Sell next bar at market.

### Scenario B — Signal Rejected (Context Against Direction)

- ES 60-min chart: MA at 4,985, previous bar MA at 4,990 → **ContextBullish = False** (MA falling)
- ES 15-min chart: Close at 4,995, above MAValData1 of 4,992
- Price is above MA but context is bearish → **No entry signal generated**

This scenario illustrates the dual-filter value: a buy signal on the operational timeframe is suppressed by the higher timeframe context.

### Scenario C — Short Entry

- ES 60-min chart: MA falling from 4,990 to 4,985 → **ContextBearish = True**
- ES 15-min chart: Close at 4,978, below MAValData1 of 4,982 → **Close < MAValData1 = True**
- Both conditions met → **SellShort next bar at market**
- Entry fills at 4,977

**Exit condition:** A 15-min bar prints with Low > 4,982 (entire bar above the MA) → BuyToCover next bar at market.

---

## Key Features

- **Dual-timeframe confirmation:** Reduces false signals by requiring alignment between trend context (Data2) and execution signal (Data1). The higher timeframe acts as a gatekeeper.
- **Continuous state entry logic:** In v1/v2, entry conditions are based on price position relative to the MA, not on the crossing event itself. This means signals are active as long as conditions hold, not just at the moment of crossing.
- **Strict bar-based exits:** Exit conditions require the full bar (High or Low) to be on the wrong side of the MA, providing a buffer against brief intrabar noise.
- **Explicit position management (v2):** The `MarketPosition = 0` guard makes position state explicit, preventing ambiguous re-entry intent.
- **Minimalist design:** The system uses only two parameters and no stops or targets, keeping it robust and easy to test.

---

## Trade Psychology

This strategy embodies a core principle of trend-following: **don't fight the dominant flow.** The higher timeframe MA direction represents the market's prevailing bias — the "current of the river." Entering only when the operational timeframe aligns with that current means you are trading *with* the market's momentum, not against it.

The continuous state condition in v1/v2 reflects an assertive stance: *as long as price stays above the MA and the trend context is bullish, the market is signaling continuation.* The entry logic trusts that this alignment is meaningful and acts on it.

The exit logic is deliberately simple and price-driven: when price fails to stay above the operational MA across an entire bar, the trade's premise is invalidated. There is no target, no trailing stop, no time-based exit — just the market structure telling you the trade is no longer valid.

The evolution from v1 to v2 also reflects a software discipline that mirrors trading discipline: **be explicit about your rules.** A strategy that relies on implicit platform behavior is like a trading plan with ambiguous entries — technically executable, but fragile and hard to review under pressure.

---

## Use Cases

**Instruments:** Equity index futures (ES, NQ, YM) are natural fits. The dual-timeframe structure works well in trending markets with clear intraday structure. The strategy can also be applied to CL, GC, and FX futures in liquid sessions.

**Timeframe combinations:** Common setups include 15-min (Data1) / 60-min (Data2), or 5-min / 15-min for more active trading. The key is that Data2 should represent a meaningful higher structural context relative to Data1.

**Trader profile:** Suitable for systematic traders building a portfolio of trend-following strategies. Best used as part of a diversified system portfolio rather than as a standalone strategy, given its exposure to choppy, range-bound conditions where continuous-state entry logic generates more frequent false signals.

**Market conditions:** Performs best in trending environments with sustained directional moves. Will generate whipsaws in sideways markets — this is a known characteristic of MA-based systems and should be quantified in backtesting before deployment.
