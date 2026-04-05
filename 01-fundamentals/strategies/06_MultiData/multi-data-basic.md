# Multi-Data (Basic) — v1.0

## Strategy Description

Multi-Data Basic is a long-only trend-following strategy that uses two data series from the same instrument at different timeframes to confirm trade entries. The primary timeframe (Data1) provides the execution signal; the secondary timeframe (Data2) provides the trend context filter. A long position is established when price is above its moving average on both timeframes simultaneously — confirming that short-term and longer-term momentum are aligned. When either condition fails, the position is closed.

This is a foundational version designed to introduce the multi-timeframe concept in its simplest form. It shares the same core idea as the more sophisticated Multi-Data Strategy v1–v4 documented elsewhere in [mastering repository](https://github.com/dorianDraper/easylanguage-learning/tree/main/matering-easylanguage/strategies/10_Multi-Data%20strategies), but without state machines, discrete crossover events, re-entry logic, or named signal variables.

---

## Core Mechanics

### 1. Dual Moving Average Calculation

```pascal
MAD1 = Average(Close Data1, MALenD1);
MAD2 = Average(Close Data2, MALenD2);
```

Each moving average is calculated on its own data series independently:

- `Average(Close Data1, MALenD1)`: simple moving average of Data1's closing prices over `MALenD1` bars. Data1 is the primary — the operational timeframe where entries and exits execute.
- `Average(Close Data2, MALenD2)`: simple moving average of Data2's closing prices over `MALenD2` bars. Data2 is the secondary — the higher timeframe providing trend context.

The `Close Data1` and `Close Data2` syntax explicitly specifies which data series to use for the calculation. Each average lives in its own temporal universe — a 20-bar average on 5-min bars and a 50-bar average on 60-min bars are calculated independently and do not influence each other. This is genuine multi-timeframe analysis: the strategy reads two structurally different views of the same instrument simultaneously.

> **On Data1 vs Data2 setup in TradeStation:** Data1 is always the primary chart the strategy is applied to. Data2 must be added as a second data series in the chart's Format Symbols dialog, typically configured as the same instrument at a higher timeframe (e.g. Data1 = 5-min ES, Data2 = 60-min ES). Without Data2 configured, the strategy will error or produce unexpected results.

### 2. Entry and Exit Logic

```pascal
If Close > MAD1 and Close Data2 > MAD2 Then
    Buy Next Bar at Market
Else
    Sell Next Bar at Market;
```

**Entry condition:** Both conditions must be true simultaneously:
- `Close > MAD1`: the current closing price on Data1 is above its moving average — price is in a locally bullish position relative to recent history.
- `Close Data2 > MAD2`: the closing price on Data2 is above its moving average — the higher timeframe trend context is also bullish.

Both conditions enforce the dual-filter principle: *"I only go long when the short-term and the longer-term are pointing in the same direction."* If price is above MAD1 but Data2 is below MAD2 — or vice versa — neither condition alone is sufficient.

**The `Else Sell` — not a symmetric exit:**

The `Else` branch fires on every bar where the entry condition is false. `Sell Next Bar at Market` closes any existing long position. However, it does **not** open a short position — `Sell` in EasyLanguage only exits an existing long; it does not create a new short. If the strategy is flat when the condition is false, the `Sell` order is submitted but ignored by the platform because there is no long position to close.

This means the `Else` generates a sell order on every bar where conditions are not met — including bars where the strategy is already flat. This is architecturally noisy: EasyLanguage handles it correctly, but the order log shows constant sell activity even when no position is open. The cleaner formulation, used in the more advanced Multi-Data versions, makes the exit conditional:

```pascal
// Cleaner alternative — explicit position check
If MarketPosition = 1 Then
    Sell Next Bar at Market;
```

This is a design note for future versions, not a bug in the current implementation.

---

## Continuous State vs Discrete Event

A fundamental characteristic of this version is that the entry condition is a **continuous state**: `Close > MAD1` is evaluated on every bar and remains true for as long as price stays above the moving average. This means the `Buy` order is placed on every bar where both conditions hold — not just at the moment of crossing.

EasyLanguage's position management prevents duplicate entries (you cannot go long if already long), so in practice only one position is ever open. But the entry signal fires continuously while conditions are favorable, which can cause re-entries immediately after an exit if conditions are still met on the following bar.

This contrasts with the discrete crossover event approach used in Multi-Data Strategy v3/v4, where `Close Crosses Over MAData1` fires only on the exact bar of the crossing. The continuous state approach is simpler to write and understand, but generates more signal noise in sustained trends.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MALenD1` | 20 | Moving average period for the primary timeframe (Data1). Controls entry sensitivity. |
| `MALenD2` | 50 | Moving average period for the secondary timeframe (Data2). Controls trend filter sensitivity. |

**On parameter sizing:** The relationship between `MALenD1` and `MALenD2` matters more than the absolute values. `MALenD2` should represent a meaningfully longer trend context than `MALenD1`. A typical starting configuration: Data1 = 5-min bars with `MALenD1 = 20` (100 minutes of context), Data2 = 60-min bars with `MALenD2 = 50` (50 hours of context). The two averages operate on different timeframes, so their absolute periods are not directly comparable.

---

## Trade Scenarios

### Scenario A — Both Conditions Met, Long Entry

- Data1 (5-min ES): Close at 4,985. MAD1 at 4,978. `Close > MAD1` ✓
- Data2 (60-min ES): Close at 4,990. MAD2 at 4,975. `Close Data2 > MAD2` ✓
- Both conditions true → `Buy Next Bar at Market`. Long position opens.
- Position remains open as long as both conditions stay true.

### Scenario B — Data2 Filter Rejects Entry

- Data1 (5-min ES): Close at 4,985. MAD1 at 4,978. `Close > MAD1` ✓
- Data2 (60-min ES): Close at 4,960. MAD2 at 4,975. `Close Data2 > MAD2` ✗
- Data2 filter fails → `Else` branch fires. If long: `Sell Next Bar at Market`. If flat: sell order submitted but ignored.
- No long position opens despite Data1 being bullish.

### Scenario C — Long Closed by Data1 Condition Failing

- Long position open. Data2 still bullish.
- Data1: Close drops to 4,970. MAD1 at 4,978. `Close > MAD1` ✗
- Entry condition false → `Else Sell` fires. Long position closes.
- Position exits even though the higher timeframe (Data2) remains supportive.

### Scenario D — Flat with Conditions False (Noisy Sell Orders)

- Strategy is flat. Both conditions false.
- `Else Sell` fires. Order submitted to platform. Platform ignores it — no long to close.
- Same behavior repeats every bar while flat and conditions are false.
- This illustrates the architectural noise of the unconditional `Else Sell`.

---

## Key Features

- **Genuine multi-timeframe analysis:** Each moving average is calculated independently on its own data series. The two timeframes provide structurally different trend views of the same instrument — not a visual approximation.
- **Dual confirmation requirement:** Both Data1 and Data2 must be bullish simultaneously. A bullish Data1 with a bearish Data2 — or vice versa — does not trigger an entry, enforcing the dual-filter principle.
- **Long-only design:** The strategy has no short side. When conditions are not met, it exits long positions and waits flat. This limits exposure to one directional bet at a time.
- **Continuous state entry:** The entry condition is re-evaluated on every bar. The position stays open as long as conditions hold, without requiring a specific crossover event to trigger.
- **Unconditional `Else Sell`:** Generates sell orders on every bar where conditions are false, including bars where the strategy is flat. Functionally correct but architecturally noisy — a design characteristic worth refining in future versions.

---

## Trade Psychology

Multi-Data Basic encodes the simplest possible version of a principle that underlies most professional trend-following systems: **do not trade against the higher timeframe.** The Data2 moving average acts as a gatekeeper — when the larger trend context is not supportive, even a favorable local signal on Data1 is suppressed.

The logic is intuitive: if the 60-minute chart shows price below its moving average, buying every time the 5-minute chart ticks above its moving average means fighting the larger trend. The dual-confirmation requirement is a mechanical form of the discretionary rule *"don't buy in a downtrend."*

The continuous state condition reflects a beginner-friendly design choice: the strategy stays long for as long as both conditions are true, exiting only when either condition fails. This is easy to reason about — if both averages are trending the same way, stay in; if either fails, get out. The complexity of discrete events, state machines, and re-entry logic comes later. This version establishes the concept before adding architectural sophistication.

---

## Relationship to Multi-Data Strategy v1–v4

This basic version and the Multi-Data Strategy v1–v4 documented in mastering repository [here](https://github.com/dorianDraper/easylanguage-learning/tree/main/matering-easylanguage/strategies/10_Multi-Data%20strategies) share the same foundational concept — dual-timeframe moving average confirmation — but implement it at very different levels of sophistication:

| Aspect | Multi-Data Basic v1 | Multi-Data Strategy v1–v4 |
|---|---|---|
| **Entry signal** | Continuous state (`Close > MA`) | Discrete event (`Crosses Over`) from v3 |
| **Position guard** | None (v1) | Explicit `MarketPosition = 0` from v2 |
| **State machine** | None | `IsLong`, `IsShort`, `ContextBullish` |
| **Re-entry logic** | None | Added in v4 |
| **Exit condition** | Unconditional `Else Sell` | `High < MAData1` (full bar below MA) |
| **Long/short** | Long only | Both directions |

Multi-Data Basic is the conceptual starting point — a readable proof of concept for the dual-timeframe idea. The Multi-Data Strategy versions add the structural rigor, explicit state management, and refined signal logic needed for a production-quality system. Reading both together illustrates the full development journey from concept to implementation.

## Use Cases

**Instruments:** Any liquid instrument available in two timeframes simultaneously — equity index futures (ES, NQ), individual stocks, commodity futures, and FX futures. The strategy requires TradeStation's multi-data chart configuration with both Data1 and Data2 defined.

**Timeframe combinations:** Common starting configurations include Data1 = 5-min / Data2 = 60-min, or Data1 = 15-min / Data2 = daily. The key requirement is that Data2 represents a structurally higher trend context — not just a longer moving average on the same timeframe.

**As a learning tool:** This version is most valuable for understanding the multi-timeframe concept and the mechanics of EasyLanguage's `Data1`/`Data2` syntax before working with the more complex versions. Running both Multi-Data Basic and Multi-Data Strategy v3 on the same chart and comparing their entry signals directly illustrates the behavioral difference between continuous state and discrete crossover entry logic.
