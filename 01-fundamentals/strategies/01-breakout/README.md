# Breakout — v1.0, v2.0 & v3.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Breakout is a momentum-following strategy that enters the market when price breaks beyond the highest high or lowest low of a configurable lookback window. The core premise is simple: if the market has been contained within a range for a number of bars and then breaks beyond that range with conviction, the breakout is worth trading. The strategy is always-in-the-market by design — stop orders are active on every bar, and only execute if price reaches the breakout level.

The three versions share the same entry logic and evolve in two distinct steps: v1 to v2 improves legibility and parametrization without changing behavior; v2 to v3 adds a full risk management layer — stop loss, profit target, and break even — transforming a pure entry exercise into a self-contained tradeable system.

---

## Core Mechanics

### 1. Breakout Level Calculation

The strategy identifies the highest high and lowest low over a lookback window on every bar:

```pascal
// v1
BuyPx  = Highest(High, TrlgBars) + .02;
SellPx = Lowest(Low, TrlgBars)   - .02;

// v2
LongBreakout  = Highest(LongPrice,  LongLen)  + EntryBuffer;
ShortBreakout = Lowest(ShortPrice,  ShortLen) - EntryBuffer;

// v3
BuyBrk  = Highest(High, BuyLen)  + StopPoints;
SellBrk = Lowest(Low,  SellLen)  - StopPoints;
```

`Highest(High, N)` returns the highest high of the last N bars including the current bar. `Lowest(Low, N)` returns the lowest low. A small buffer (`.02` by default) is added above the high and subtracted below the low — this prevents execution on an exact touch of the level, filtering out marginal price probes that lack follow-through.

**Why no `[1]` offset?** Unlike pattern detection strategies that use `[1]` to avoid lookahead, breakout strategies deliberately include the current bar in the calculation. The logic is: the order is placed for the *next bar*, so the calculation should reflect the most current range available — including the bar that is closing right now. Using `[1]` would calculate a potentially stale level, causing the breakout threshold to lag one bar behind the market. In breakout trading, that lag means missing the precise level where the conviction move begins.

### 2. Stop Order Entries — Always Active

```pascal
Buy      ("Brk LE") Next Bar at LongBreakout  Stop;
SellShort("Brk SE") Next Bar at ShortBreakout Stop;
```

There are no `If` conditions around the entry orders. Both stop orders are placed on every bar and remain active until price reaches the respective level or the bar closes without a fill. This is architecturally correct — a stop order *is* the condition. If price does not reach `LongBreakout`, the buy order does not execute. If price reaches it, it executes as a momentum confirmation: price has broken the range.

This creates an always-in-the-market system: once a long position closes, the short stop order is immediately active (and vice versa), meaning the strategy is always positioned to catch the next breakout in either direction.

### 3. Risk Management (v3 Only)

v3 adds three exit mechanisms applied on a per-share basis:

```pascal
SetStopShare;

SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);
```

`SetStopShare` instructs TradeStation to apply all subsequent stop functions per share or per contract rather than per position total. This ensures consistent dollar risk regardless of position size.

**Stop Loss (`SetStopLoss`):** Closes the position if it reaches a loss of `StopAmt` per share. With the default value of `$0.20`, the trade exits automatically if price moves `$0.20` against the entry.

**Profit Target (`SetProfitTarget`):** Closes the position when it reaches a gain of `TargetAmt` per share. With the default of `$0.30`, the strategy targets a 1.5:1 reward-to-risk ratio ($0.30 target vs $0.20 stop).

**Break Even (`SetBreakeven`):** Once the position reaches a gain of `BEAmt` per share (`$0.15` by default), the stop loss is automatically moved to the entry price. From that point, the trade cannot lose — the worst outcome is a breakeven exit. The sequence is:

```
Entry → advance $0.15 → stop moves to entry price → target at $0.30
```

Think of break even as a two-stage exit: the trade earns the right to zero-risk status after demonstrating initial momentum, then continues toward the profit target from a protected position.

---

## v1 → v2 → v3: Code Architecture Evolution

### v1 — Minimal and Foundational

v1 expresses the core breakout logic in its most compact form. A single input (`TrlgBars`) controls both the long and short lookback identically, and the buffer is hardcoded to `.02`:

```pascal
Input: TrlgBars(8);

BuyPx  = Highest(High, TrlgBars) + .02;
SellPx = Lowest(Low,  TrlgBars)  - .02;

Buy      ("BrkLE") Next Bar at BuyPx  Stop;
SellShort("BrkSE") Next Bar at SellPx Stop;
```

v1 is a clean educational baseline — the entire strategy is five lines of logic. Its limitation is inflexibility: the buffer cannot be changed without editing code, and the long and short lookbacks cannot be tuned independently.

### v2 — Parametrized and Self-Documenting

v2 exposes every constant as a named input and separates the price source from the lookback period:

```pascal
Inputs:
    LongPrice(High),   ShortPrice(Low),
    LongLen(8),        ShortLen(8),
    EntryBuffer(.02);

LongBreakout  = Highest(LongPrice,  LongLen)  + EntryBuffer;
ShortBreakout = Lowest(ShortPrice,  ShortLen) - EntryBuffer;
```

`LongPrice` and `ShortPrice` as inputs is a meaningful architectural decision: by defaulting to `High` and `Low` respectively but making them configurable, the strategy can be switched to use `Close` as the breakout reference price without any code changes — just a parameter update. `LongLen` and `ShortLen` allow asymmetric lookback windows, useful if the instrument shows different momentum characteristics on the long and short sides.

The variable names `LongBreakout` and `ShortBreakout` describe *what the value is* (a breakout level) rather than what it is used for (`BuyPx`, `SellPx`), making the code read more like a specification than a set of calculations.

### v3 — Complete System with Risk Management

v3 adds the exit layer that transforms the entry framework into a self-contained strategy. The entry logic is identical to v1/v2 (with v3's own naming convention), and three new inputs and three new exit functions complete the system:

```pascal
Input:
    BuyLen(8),    SellLen(8),
    StopPoints(.02),
    StopAmt(.2),  TargetAmt(.3),  BEAmt(.15);

SetStopShare;
SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);
```

The addition of `SetBreakeven` is the key upgrade over a simple stop/target system. Without break even, a trade that reaches $0.14 of profit and then reverses exits at the stop for a $0.20 loss — a nearly $0.34 swing from near-target to max loss. With break even active, once the trade touches $0.15, the worst outcome shifts from −$0.20 to $0.00. The break even mechanism converts a losing-possible trade into a no-worse-than-breakeven trade once the initial momentum is confirmed.

**Summary:**

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Breakout entry logic** | ✓ | ✓ | ✓ |
| **Independent long/short lookbacks** | — | ✓ | ✓ |
| **Configurable price source** | — | ✓ (`LongPrice`, `ShortPrice`) | — |
| **Named `EntryBuffer` input** | — | ✓ | ✓ (`StopPoints`) |
| **Stop loss** | — | — | ✓ |
| **Profit target** | — | — | ✓ |
| **Break even** | — | — | ✓ |
| **`SetStopShare`** | — | — | ✓ |

---

## Parameters

### v1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TrlgBars` | 8 | Lookback period for both long and short breakout levels. |

### v2

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LongPrice` | `High` | Price series used for the long breakout calculation. |
| `LongLen` | 8 | Lookback bars for the long breakout level. |
| `ShortPrice` | `Low` | Price series used for the short breakout calculation. |
| `ShortLen` | 8 | Lookback bars for the short breakout level. |
| `EntryBuffer` | 0.02 | Buffer added/subtracted from the breakout level to avoid marginal fills. |

### v3

| Parameter | Default | Description |
|-----------|---------|-------------|
| `BuyLen` | 8 | Lookback bars for the long breakout level. |
| `SellLen` | 8 | Lookback bars for the short breakout level. |
| `StopPoints` | 0.02 | Buffer added/subtracted from the breakout level. |
| `StopAmt` | $0.20 | Stop loss per share/contract. |
| `TargetAmt` | $0.30 | Profit target per share/contract. |
| `BEAmt` | $0.15 | Gain per share at which the stop moves to entry price (break even). |

**On the default risk parameters in v3:** The $0.20 stop, $0.30 target, and $0.15 break even are calibrated for stock prices. For futures contracts, these values must be adjusted to reflect `BigPointValue` and the instrument's typical intrabar range. For ES futures at $50/point, $0.20 equals 0.004 points — far too tight for any meaningful stop. Scale proportionally to the instrument.

---

## Trade Scenarios

### Scenario A — Long Breakout, Break Even, Then Target (v3)

- 8-bar highest high: 45.80. `LongBreakout = 45.82` (+ buffer of 0.02).
- Price rallies through 45.82. Long entry fills at 45.82.
- `StopLoss` active at 45.62 (45.82 − 0.20). `ProfitTarget` at 46.12 (45.82 + 0.30).
- Price advances to 45.97 (gain of 0.15). `SetBreakeven` triggers. Stop moves to 45.82.
- Trade is now risk-free. Stop at entry, target at 46.12.
- Price reaches 46.12. Profit target fills. Trade exits +$0.30/share.

### Scenario B — Long Breakout, Stop Loss Before Break Even (v3)

- Same entry at 45.82. Stop at 45.62. Target at 46.12.
- Price advances to 45.90, then reverses. Never reaches break even level of 45.97.
- Price falls through 45.62. Stop fills. Trade exits −$0.20/share.

### Scenario C — Long Breakout, Break Even Exit (v3)

- Entry at 45.82. Price touches 45.97. Break even activates. Stop moves to 45.82.
- Price retraces before reaching target. Falls through 45.82. Break even stop fills.
- Trade exits at entry price. Net result: $0.00 (before commissions).

### Scenario D — No Breakout, No Trade (v1/v2/v3)

- 8-bar highest high: 45.80. `LongBreakout = 45.82`.
- Price moves to 45.78 — short of the breakout level.
- Stop order does not trigger. No position entered. Orders refresh next bar with updated levels.

---

## Key Features

- **Always-in-the-market architecture:** Stop orders are placed on every bar without conditions. Both directions are simultaneously active and compete to be the first breakout to trigger.
- **Buffer filter:** The small offset above the high and below the low prevents execution on exact level touches, filtering noise and requiring genuine penetration of the range.
- **No `[1]` offset:** The breakout calculation includes the current bar to keep levels current. Using the prior bar's calculation would introduce one bar of lag — undesirable in a momentum system where the entry level must reflect the live range boundary.
- **Configurable price source (v2):** `LongPrice` and `ShortPrice` inputs allow switching from High/Low breakouts to Close-based breakouts without code modification.
- **Asymmetric lookback (v2/v3):** Independent `LongLen` and `ShortLen` allow the long and short breakout windows to be tuned separately, useful when an instrument exhibits different momentum duration on each side.
- **Break even protection (v3):** Once initial momentum is confirmed by reaching `BEAmt`, the trade cannot lose — converting a risky position into a free trade with remaining upside.
- **`SetStopShare` compliance (v3):** Per-contract stop management ensures correct behavior across different position sizes.

---

## Trade Psychology

Breakout is one of the purest expressions of trend-following logic: **the market tells you when to enter by breaking its own recent range.** There is no prediction, no opinion about direction, no interpretation of candlestick patterns or indicator crossovers. The strategy simply says: *"the market has spent the last N bars within a range. If it exits that range decisively, something is changing — I want to be on the right side of that change."*

The always-in-the-market design reflects a specific philosophical stance: the strategy does not predict which breakout will happen, only that breakouts are worth trading when they occur. By maintaining active orders in both directions simultaneously, it removes the need to forecast direction — the market selects the direction for you.

The break even mechanism in v3 encodes a progression of trust: the initial stop reflects skepticism (the trade may be wrong, limit the loss), and the break even reflects earned confidence (the trade has shown initial momentum, protect the position). This two-stage trust model — initial protection, then earned safety — mirrors the way experienced traders think about position management as a trade develops.

The three-version evolution of this strategy also captures an important development principle: **start simple, extend deliberately.** v1 proves the entry concept. v2 makes it maintainable and flexible. v3 makes it tradeable with defined risk. Each version adds exactly one layer of complexity with a clear reason, avoiding the common trap of building a complex system before the core premise is validated.

---

## Use Cases

**Instruments:** Breakout works on any liquid instrument with identifiable range periods followed by directional moves — equity index futures (ES, NQ), individual stocks in consolidation phases, commodity futures (CL, GC), and FX futures with regular session ranges. The lookback window and buffer should be calibrated to the instrument's typical bar range.

**Timeframes:** The 8-bar lookback is timeframe-independent. On 5-min bars it captures roughly 40 minutes of range; on daily bars it captures the last 8 trading sessions. Shorter lookbacks produce more frequent, smaller breakouts; longer lookbacks produce rarer, more significant ones.

**v1 as a template:** v1's compactness makes it an ideal starting point for experimentation. Adding a single filter (e.g. `If ADX > 20 Then`) or replacing the market exit with a time-based exit can be done in one or two lines, preserving the clean entry logic while extending the system incrementally.

**v3 in production:** The stop/target/break even combination in v3 provides the minimum viable risk framework for live deployment. The 1.5:1 reward-to-risk ratio ($0.30/$0.20) requires a win rate above approximately 40% to be profitable — a realistic threshold for a momentum breakout system in liquid markets.

**As a foundational component:** All three versions serve as reference implementations for the breakout entry pattern. More advanced strategies in this repository that use breakout entries (e.g. with trend filters, multi-timeframe confirmation, or adaptive sizing) build on the same `Highest`/`Lowest` + stop order architecture established here.
