# Key Reversal (Basic) — v1.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Key Reversal Basic is a pattern recognition strategy that identifies single-bar reversal signals and enters limit orders in the anticipated reversal direction. A bullish key reversal occurs when a bar makes a new low relative to the previous bar but closes higher than the previous close — indicating that a downside probe was rejected and buying pressure took over. A bearish key reversal is the mirror image. The strategy enters on a limit order slightly offset from the close, seeking a minor pullback after the signal bar rather than chasing the price at market.

This is a foundational, entry-only strategy — no exits are defined. It is designed to study the behavior of the key reversal pattern in isolation before adding stop loss, profit target, or time-based exit rules in subsequent versions.

---

## Core Mechanics

### 1. Pattern Detection

```pascal
BullKeyRev = Low < Low[1] and Close > Close[1];
BearKeyRev = High > High[1] and Close < Close[1];
```

The pattern is defined by two simultaneous conditions on a single bar:

**Bull Key Reversal:**
- `Low < Low[1]`: the bar makes a new low below the previous bar's low — an initial downside extension that appears bearish.
- `Close > Close[1]`: the bar closes above the previous bar's close — buying pressure absorbed the downside move and drove price back up.

**Bear Key Reversal:**
- `High > High[1]`: the bar makes a new high above the previous bar's high — an initial upside extension.
- `Close < Close[1]`: the bar closes below the previous bar's close — selling pressure rejected the upside move.

The combination of these two conditions on the same bar creates the reversal signal: the market *tried* to continue in one direction, *failed*, and closed with conviction in the opposite direction. The extremity (new low or new high) establishes the rejection point; the close establishes the direction of the recovered conviction.

### 2. Permissive vs Classic Definition

This implementation uses a **permissive definition** of the key reversal pattern. The classical stricter definition adds a third condition:

- **Classic Bull:** `Low < Low[1]` AND `Close > Close[1]` AND `Close > High[1]` — the close must exceed the *entire* previous bar, not just the previous close.
- **Classic Bear:** `High > High[1]` AND `Close < Close[1]` AND `Close < Low[1]` — the close must fall below the *entire* previous bar.

The stricter condition requires a more dramatic rejection — the bar not only closes higher than the previous close but engulfs the previous bar's range entirely. This produces fewer but higher-conviction signals.

The permissive version used here (`Close > Close[1]` without requiring `Close > High[1]`) generates more signals, including cases where the reversal bar closes higher than the previous close but still within the previous bar's range. This is appropriate for a learning context — more signals mean more pattern instances to study — but in live deployment, the higher signal frequency comes with a higher rate of false positives.

```
Classic Bull Key Reversal (strict):        Permissive Bull Key Reversal:
                                           
   High[1]  ──────────                        High[1]  ──────────
             │        │                                │
   Close[1] ─┤        │           Close ─────────────  │
             │        │                                │
             │        │           Close[1] ──────────  │
             │        │Close ─                         │
   Low[1]    │        │                       Low[1]   │
             ──────────                                ──────────
   Low ──                                    Low ──
   
   (Close must exceed High[1])             (Close only needs to exceed Close[1])
```

### 3. Entry Orders — Offset Limit

```pascal
If BullKeyRev Then
    Buy Next Bar at Close of This Bar - LimitPoints Limit;
If BearKeyRev Then
    SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

Rather than entering at market on the next bar, the strategy places limit orders at a slight offset from the signal bar's close:

- **Bull entry:** limit placed `LimitPoints` *below* the close. The long fills only if price pulls back to that level on the next bar, providing a marginally better entry than the signal bar's close.
- **Bear entry:** limit placed `LimitPoints` *above* the close. The short fills only if price bounces slightly to that level.

This approach reflects a deliberate patience: *"the pattern has appeared — but I am not willing to chase price. I will wait for a small concession before entering."* The offset is small by design (default `0.05`) — it is not a significant pullback requirement, just a minimal buffer against chasing an already-extended close.

If the next bar does not trade to the limit level — for example, it gaps further in the reversal direction — the order expires unfilled. This is acceptable: a gap continuation often signals a stronger reversal move that would have been better captured at the close price, but the strategy prioritizes entry discipline over fill rate.

### 4. No Exit Rules

The strategy defines entries only. There are no stop loss, profit target, or time-based exit conditions. In EasyLanguage, this means positions remain open until a reversal entry in the opposite direction closes the existing position and opens a new one — effectively creating an always-in-the-market system with entries driven by key reversal signals in either direction.

This is an intentional design choice for a learning strategy: studying the pattern's behavior without exit interference allows clean analysis of how often the reversal follow-through materializes, and for how many bars. Exit rules will be added in subsequent versions once the pattern behavior is understood.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LimitPoints` | 0.05 | Offset from the signal bar's close used to set the limit order price. |

**On `LimitPoints`:** The default value of `0.05` is calibrated for stock prices where a 5-cent offset is a meaningful but small concession. For futures contracts, this value should be scaled to the instrument's tick size — for ES futures, a meaningful offset might be 0.25 to 1.00 points depending on the typical bar range. Setting `LimitPoints` too large reduces the fill rate; setting it too small approaches market-order behavior.

---

## Trade Scenarios

### Scenario A — Bull Key Reversal, Limit Fills

- Previous bar: Low at 44.80, Close at 44.90.
- Signal bar: Low at 44.70 (`Low < Low[1]` ✓), Close at 44.95 (`Close > Close[1]` ✓). `BullKeyRev = True`.
- Limit order placed at `44.95 − 0.05 = 44.90`.
- Next bar trades down to 44.88 briefly before rallying. Limit fills at 44.90.
- Position is now long. No exit defined — position remains open until a bear key reversal entry fires.

### Scenario B — Bull Key Reversal, Limit Not Filled (Gap Continuation)

- Same signal bar close at 44.95. Limit at 44.90.
- Next bar opens at 45.20 (gap up in the reversal direction). Price never trades down to 44.90.
- Limit expires unfilled. No position entered.
- The reversal move continued strongly without concession — the strategy missed the entry by prioritizing price discipline.

### Scenario C — Bear Key Reversal

- Previous bar: High at 46.50, Close at 46.40.
- Signal bar: High at 46.60 (`High > High[1]` ✓), Close at 46.30 (`Close < Close[1]` ✓). `BearKeyRev = True`.
- Limit order placed at `46.30 + 0.05 = 46.35`.
- Next bar bounces slightly to 46.36. Short fills at 46.35.
- Position is now short. No exit defined.

### Scenario D — Pattern Detected But Not Classic Strength

- Previous bar: High at 46.50, Close at 46.40, Low at 46.20.
- Signal bar: Low at 46.15 (`Low < Low[1]` ✓), Close at 46.45 (`Close > Close[1]` ✓).
- `BullKeyRev = True` — pattern fires under the permissive definition.
- Note: Close at 46.45 is below High[1] at 46.50. Under the classic strict definition, this would *not* qualify as a key reversal — the close did not exceed the prior bar's high.
- Entry fires regardless. This illustrates the practical difference between the two definitions.

---

## Key Features

- **Single-bar pattern:** The entire signal is contained within one bar and its relationship to the previous bar. No lookback beyond `[1]` is required — the pattern is immediate and computationally minimal.
- **Rejection structure:** The combination of a new extreme and a reversal close encodes a market structure event: participants who pushed price to the new extreme were overwhelmed by the opposite side before the bar closed.
- **Permissive definition:** `Close > Close[1]` (rather than `Close > High[1]`) produces more signal instances, making it more suitable for pattern study but requiring awareness of the higher false positive rate in live use.
- **Limit entry with offset:** The `LimitPoints` offset introduces a minimum patience requirement — the strategy waits for a small price concession after the signal rather than entering immediately at the close.
- **No exits by design:** The entry-only architecture is intentional for the learning context. It allows isolated study of the pattern's directional follow-through without exit-rule interference.

---

## Trade Psychology

The key reversal pattern encodes a specific market narrative: **the attempted move failed.** When price reaches a new low but the bar closes higher, it means sellers pushed price to an extreme, then buyers stepped in with enough force to not only stop the decline but reverse it — all within a single bar. The new low is a trap; the higher close is the evidence that the trap was rejected.

Entering on a limit order below the close (for bulls) is an expression of measured patience. The signal has appeared, but the strategy does not react with urgency — it waits for the market to offer a slightly better price. This reflects the recognition that reversal bars are often followed by minor continuation in the reversal direction before the larger move begins. The offset is not trying to capture a deep pullback; it is simply avoiding the worst fill by not accepting the close price at face value.

The absence of exits is the most important design choice in this version. A strategy without exits is not a complete trading system — it is a pattern study tool. The intent is to observe: how often does the reversal follow through? For how many bars? Does the pattern perform differently on trending days versus range days? These questions can only be answered cleanly when exits are not interfering with the observation.

The permissive vs classic distinction also carries a psychological lesson: defining a pattern more strictly produces fewer but higher-quality signals. The discipline to wait for a stronger pattern — `Close > High[1]` rather than just `Close > Close[1]` — is the same discipline that separates high-conviction trades from noise. Both definitions are worth studying, but they are different hypotheses about what constitutes a meaningful reversal.

---

## Use Cases

**Instruments:** The key reversal pattern is instrument-agnostic — it requires only OHLC bar data. It is most studied on daily charts of individual stocks and equity index futures, where single-bar reversals at support/resistance levels carry structural significance. On intraday charts, the pattern fires more frequently and with lower average conviction.

**Timeframes:** On daily bars, a key reversal at a multi-week low is a meaningful event — it represents a full session's worth of price discovery ending in rejection. On 5-minute bars, the same pattern may reflect only a few minutes of trading activity. The interpretive weight of the pattern scales with timeframe.

**As a learning tool:** This version is explicitly designed as a research baseline. The recommended study approach is to run the strategy on historical data and examine each trade entry in detail — noting whether the pattern led to a sustained reversal, how many bars it took to materialize, and what market conditions (trend, volatility, volume) accompanied the strongest signals. This analysis directly informs the parameter choices and exit rules for the next version.

**Relationship to Key Reversal (Advanced):** This basic version shares the reversal concept with the more sophisticated Key Reversal strategy documented elsewhere in this repository, which uses MRO-based structural low detection, a Donchian channel for significance filtering, and an equity-adaptive scale-in mechanism. The basic version here studies the raw pattern signal; the advanced version adds the structural and statistical framework that a production system requires.
