# Momentum Cross — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Momentum Cross is a momentum-following strategy that enters when the Momentum indicator crosses the zero line, filtered by a recency check that ensures no opposing crossover has occurred in the recent lookback window. Exits are driven by momentum deterioration — three consecutive bars of weakening momentum — rather than fixed stops or profit targets. The system has no price-level risk management by design: it is built to study the behavior of the momentum signal itself before layering risk controls on top.

v2 refines v1 in two ways: it replaces the exact closing-price limit order with an offset-based limit that improves execution realism, and it separates every logical component into named boolean variables, making the signal architecture explicit and auditable. Both versions include `Print` and `Commentary` statements as development tools for debugging and bar-by-bar analysis.

---

## Core Mechanics

### 1. Momentum Calculation

```pascal
Mom = Momentum(Price, Length);   // v1
Mom = Momentum(Price, MomLen);   // v2
```

`Momentum` is EasyLanguage's built-in function that returns the difference between the current bar's price and the price `N` bars ago: `Momentum(Price, N) = Price - Price[N]`. It measures the net change in price over the lookback window — positive values indicate the price is higher than it was N bars ago (upward momentum), negative values indicate it is lower (downward momentum).

The zero line is the structural boundary: crossing above zero means momentum has shifted from negative to positive; crossing below means the reverse. Unlike a moving average crossover, which compares two derived values, the momentum zero crossing compares the indicator directly against a fixed structural level.

### 2. Primary Events — Zero-Line Crossovers

```pascal
// v1
BullCx = Mom Crosses Over  0;
BearCx = Mom Crosses Under 0;

// v2
BullMom = Mom Crosses Over  0;
BearMom = Mom Crosses Under 0;
```

`Crosses Over 0` and `Crosses Under 0` are discrete events — `True` only on the exact bar where the crossing occurs. The rename from `BullCx`/`BearCx` to `BullMom`/`BearMom` in v2 communicates what the variable represents (a bullish momentum event) rather than its mechanical action (a crossover event).

### 3. MRO Filter — Recency Check

```pascal
// v1 — inline
If BullCx and MRO(BearCx, BearLen, 1) = -1 Then ...

// v2 — named variables
BuyFilter  = MRO(BearMom, NumBearBars, 1) = -1;
SellFilter = MRO(BullMom, NumBullBars, 1) = -1;
```

`MRO(condition, lookback, occurrence)` scans backward through the last `lookback` bars and returns the offset of the most recent bar where `condition` was `True`, or `-1` if the condition never occurred within the window.

`MRO(BearMom, NumBearBars, 1) = -1` reads: *"there has been no bearish momentum crossover in the last `NumBearBars` bars."* This is the entry filter — a bullish crossover is only acted on if no bearish crossover has occurred recently. The logic prevents entering long immediately after a recent reversal signal, filtering out whipsaws and rapid direction changes.

Think of MRO as a lookback scanner with a specific question: *"has this event happened recently?"* When it returns `-1`, the answer is no — the condition was not found in the window. When it returns any value ≥ 0, the event did happen, and the filter rejects the entry.

In v2, these conditions are stored as named booleans (`BuyFilter`, `SellFilter`), separating the filter logic from the entry execution block. The entry block then reads as a clean composition:

```pascal
If BullMom and BuyFilter  Then Buy       ...
If BearMom and SellFilter Then SellShort ...
```

### 4. Entry Orders — Limit at Close (v1) vs Offset Limit (v2)

```pascal
// v1 — limit at the exact close of the current bar
Buy       Next Bar at Close of This Bar         Limit;
SellShort Next Bar at Close of This Bar         Limit;

// v2 — limit with configurable offset from current close
Buy       Next Bar at Close of This Bar - LimitPoints Limit;
SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

Both versions use limit orders rather than market orders — a more conservative and realistic entry approach. A limit order only executes if price reaches the specified level, rather than filling at whatever price the next bar opens at.

**v1 — Close of This Bar:** The limit is set at the exact closing price of the current bar. For a long entry, the order fills on the next bar only if price returns to or below that closing level. This is valid EasyLanguage syntax, but it has a practical limitation: in markets with gap-open behavior, the next bar may open significantly above the limit, and the order never fills. Conversely, in sideways or mean-reverting markets, the exact-close limit often fills quickly.

**v2 — Offset Limit:** `LimitPoints` is subtracted from the close for longs (placing the limit slightly below the close, requiring a minor pullback before entry) and added to the close for shorts (requiring a minor bounce). This makes entries more selective — the market must confirm the signal direction slightly before the trade executes — and separates the limit price from the exact close, giving more control over entry precision.

> **On `Close of This Bar` in a `Next Bar` order:** This syntax accesses the closing price of the bar that is being evaluated, and uses it as the limit price for an order that executes on the following bar. The limit is calculated at bar close and submitted for the next bar's trading range. This is technically correct in EasyLanguage — the evaluation and submission happen at different points — but produces fewer fills in gapping markets where the next open may skip the limit level entirely.

### 5. Momentum Deterioration Exits

```pascal
// v1 — inline
If Mom < Mom[1] and Mom[1] < Mom[2] Then Sell       Next Bar at Market;
If Mom > Mom[1] and Mom[1] > Mom[2] Then BuyToCover Next Bar at Market;

// v2 — named variables
DownMom = Mom < Mom[1] and Mom[1] < Mom[2];
UpMom   = Mom > Mom[1] and Mom[1] > Mom[2];

If DownMom Then Sell       Next Bar at Market;
If UpMom   Then BuyToCover Next Bar at Market;
```

The exit fires when momentum has been declining (or rising, for shorts) for three consecutive bars. This is a structural exit — it does not require a price level to be breached, only a pattern of weakening momentum values. The logic: *"if momentum has been deteriorating for three bars in a row, the impulse driving this trade is losing conviction. Exit before it fully reverses."*

Three bars was chosen as the minimum pattern to require sustained deterioration rather than a single-bar pullback. One bar of weaker momentum could be noise; three consecutive bars is a structural signal. This threshold is hardcoded — a natural extension for a future version would be to parametrize it.

### 6. Development Tools — Print and Commentary (v2)

```pascal
Print("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);

Commentary("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);
```

`Print` writes a formatted line to TradeStation's Print Log on every bar evaluation, logging the date, time, momentum value, and crossover signals. `Commentary` adds the same information as an annotation visible in the chart when a bar is selected.

Both are development-only tools. In production or backtesting at scale, these should be commented out — they execute on every bar and generate significant log output that degrades platform performance. They are left active in v2 to support the analysis and debugging workflow during strategy development.

---

## v1 vs v2: The Difference

| | v1.0 | v2.0 |
|---|---|---|
| **Momentum crossover entry** | ✓ | ✓ |
| **MRO recency filter** | ✓ (inline) | ✓ (named booleans) |
| **Momentum deterioration exit** | ✓ (inline) | ✓ (named booleans) |
| **Limit at exact close** | ✓ | — |
| **Offset limit (`LimitPoints`)** | — | ✓ |
| **Named signal variables** | — | ✓ (`BullMom`, `BearMom`, `BuyFilter`, `SellFilter`, `DownMom`, `UpMom`) |
| **`Print` / `Commentary`** | — | ✓ (development tools) |

The architectural shift from v1 to v2 mirrors the principle articulated in the code's own comments: separate primary events, filters, and exits into distinct named variables. v2 makes the signal chain explicit — you can read `BullMom and BuyFilter` and immediately understand both the trigger (bullish momentum crossover) and the gate (no recent bearish crossover). In v1, both are embedded in the entry condition itself.

---

## Parameters

### v1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Price` | `Close` | Price series used for momentum calculation. |
| `Length` | 10 | Momentum lookback — compares current price to price `Length` bars ago. |
| `BullLen` | 4 | Bars to scan back for a recent bullish crossover (used in short entry filter). |
| `BearLen` | 4 | Bars to scan back for a recent bearish crossover (used in long entry filter). |

### v2

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Price` | `Close` | Price series used for momentum calculation. |
| `MomLen` | 10 | Momentum lookback period. |
| `NumBullBars` | 4 | Bars to scan back for a recent bullish crossover (short entry filter). |
| `NumBearBars` | 4 | Bars to scan back for a recent bearish crossover (long entry filter). |
| `LimitPoints` | 0.05 | Offset from close used to set the limit order price. |

**On `LimitPoints`:** The default value of `0.05` is calibrated for stock prices. For futures contracts, this should be adjusted to reflect the instrument's tick size and typical intrabar range. For ES futures, a 0.05 offset is less than one tick — effectively placing the limit at the close. A more meaningful offset for ES might be 0.25 to 1.00 points.

**On `BullLen`/`BearLen` (`NumBullBars`/`NumBearBars`):** These parameters control how far back the MRO filter looks for a recent opposing crossover. Larger values mean the filter is more conservative — a bearish crossover from further back still blocks a new long entry. Smaller values make the filter more permissive, allowing re-entry sooner after a direction change.

---

## Trade Scenarios

### Scenario A — Long Entry Passes All Filters

- `Mom` crosses above 0 on bar X. `BullMom = True`.
- MRO scan: no `BearMom` event in the last 4 bars. `BuyFilter = True`.
- Both conditions met. Long limit order placed at `Close of This Bar - 0.05`.
- Next bar opens and trades down to the limit level. Long entry fills.
- `Mom` remains positive for several bars. No exit signal.
- Bar X+5: `Mom < Mom[1]`, X+4: `Mom[1] < Mom[2]`. `DownMom = True`. Exit: `Sell Next Bar at Market`.

### Scenario B — Long Entry Blocked by MRO Filter

- `Mom` crosses above 0 on bar X. `BullMom = True`.
- MRO scan: `BearMom` was `True` on bar X-2. `MRO(BearMom, 4, 1) = 2` (2 bars ago). Not `-1`.
- `BuyFilter = False`. Entry blocked. Strategy stays flat.
- The bearish crossover two bars ago is too recent to enter long.

### Scenario C — Limit Order Not Filled (Gap Open)

- Long limit placed at `Close (45.20) - 0.05 = 45.15` at bar close.
- Next bar opens at 45.40 (gap up). Price never trades down to 45.15 during the bar.
- Limit order expires unfilled. No position entered.
- On the following bar, `BullMom` is no longer `True` (crossover was only true on the signal bar). No new entry fires unless a new crossover occurs.

### Scenario D — Exit by Momentum Deterioration

- Long position open. Momentum sequence: Mom = 8.2 → 7.1 → 6.3.
- Bar 1: `Mom (7.1) < Mom[1] (8.2)`. One bar of weakness.
- Bar 2: `Mom (6.3) < Mom[1] (7.1)`. Two consecutive bars.
- `DownMom = True` (three consecutive declining values: 8.2 → 7.1 → 6.3). Exit: `Sell Next Bar at Market`.

---

## Key Features

- **Zero-line crossover as primary signal:** Momentum crossing zero is a structural shift — the net price change over `MomLen` bars has changed sign. This is a direct measure of directional bias, not a derived indicator comparison.
- **MRO recency filter:** Prevents entering in a direction immediately after an opposing crossover, reducing whipsaw exposure by requiring a clean period without conflicting signals.
- **Momentum deterioration exit:** Three consecutive bars of weakening momentum provide a structural exit signal that does not require price level targets. The trade exits when its premise (momentum) begins to erode.
- **Limit entry for realistic execution:** Both versions use limit orders rather than market orders, avoiding the fill-at-any-price behavior of market entries and requiring the market to return to a defined price before the trade opens.
- **Named boolean architecture (v2):** Separating primary events (`BullMom`, `BearMom`), filters (`BuyFilter`, `SellFilter`), and exit conditions (`DownMom`, `UpMom`) into distinct variables makes each layer independently readable and modifiable.
- **Development logging (v2):** `Print` and `Commentary` provide bar-by-bar visibility into the signal state during development. Must be deactivated before production use.

---

## Trade Psychology

Momentum Cross embodies a clear philosophical stance: **enter only when the market demonstrates clear intent, stay as long as that intent is maintained, exit the moment it begins to weaken.**

The zero-line crossover defines "clear intent" precisely: momentum has shifted from negative to positive (or vice versa) — the net price change over the lookback window has changed direction. This is not a relative comparison between two derived averages; it is a direct structural observation about whether the market is higher or lower than it was `MomLen` bars ago.

The MRO filter adds a temporal dimension to "clear intent": the signal must not be immediately preceded by its opposite. A bullish momentum crossover that follows a bearish one within four bars is not a clean directional signal — it is more likely a whipsaw in a choppy market. By requiring the absence of recent opposing signals, the strategy only acts when the momentum shift has had time to establish itself.

The deterioration exit reflects a respect for the dynamic nature of momentum. A fixed stop or profit target treats all trades as equivalent — a trade in a strong trending market and a trade in a choppy market exit at the same price levels. The momentum deterioration exit adapts: a strong trend that sustains momentum stays open; a weak entry that sees momentum falter immediately exits. The strategy listens to what the market is doing rather than enforcing a predetermined outcome.

---

## Use Cases

**Instruments:** Momentum Cross is most effective on instruments with clear directional momentum phases — equity index futures (ES, NQ) during trending sessions, individual momentum stocks, and commodity futures with sustained directional moves. It struggles in range-bound, mean-reverting markets where momentum oscillates around zero without sustained directional conviction.

**Timeframes:** The 10-bar momentum lookback is timeframe-relative. On 5-min bars it captures roughly 50 minutes of net price change; on daily bars it captures two trading weeks. The exit deterioration pattern (three consecutive bars) should also be interpreted relative to timeframe — three 5-min bars is 15 minutes of weakening momentum; three daily bars is nearly a week.

**As a research vehicle:** Both versions are explicitly designed for learning and research rather than live deployment. The absence of stops means a trade that enters on a false signal can lose without bound until the three-bar deterioration pattern appears. The intended use is to study the behavior of the momentum signal and the MRO filter in isolation before adding the risk management layer that a production system would require.

**Natural next steps:** The comments in both versions point toward future improvements: adding a configurable exit bar count (rather than hardcoded three bars), adding stop loss and profit target parameters, combining with a higher-timeframe trend filter (similar to the Multi-Data Strategy approach), and replacing `Condition1` with a semantically named variable. These extensions would move the strategy toward production readiness while preserving the clean signal architecture established here.
