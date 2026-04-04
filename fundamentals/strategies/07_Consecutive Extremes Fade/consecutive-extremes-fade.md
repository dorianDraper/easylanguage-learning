# Consecutive Extremes Fade — v1.0

## Strategy Description

Consecutive Extremes Fade is a mean-reversion strategy that enters counter to short-term momentum runs. Rather than detecting a price level breakout, it counts consecutive bars making new highs or new lows and enters a fading position once the run reaches a configurable minimum length. The premise is that sustained consecutive extremes represent short-term overextension — a price that has made new lows on multiple consecutive bars has likely pushed too far in one direction and is a candidate for a bounce.

Both entry directions are contrarian: the strategy buys during a consecutive-low run (expecting a rebound) and sells short during a consecutive-high run (expecting a pullback). Exits are managed with a fixed profit target and stop loss applied per position.

---

## Core Mechanics

### 1. Consecutive Extreme Counters

```pascal
If High > High[1] Then
    HighsCount = HighsCount + 1
Else
    HighsCount = 0;

If Low < Low[1] Then
    LowsCount = LowsCount + 1
Else
    LowsCount = 0;
```

`HighsCount` increments by one on every bar where the current high exceeds the previous bar's high — a new short-term high. It resets to zero the moment any bar fails to make a new high. `LowsCount` does the same for bars making successive new lows.

This is a **consecutive streak counter**, not a channel lookback. The distinction matters:

- `Highest(High, N)` finds the absolute maximum within N bars — it does not care whether those highs were consecutive.
- `HighsCount >= 2` requires that the last 2 bars have each made a higher high than the bar before them — a directional momentum streak.

A `HighsCount` of 3 means three consecutive bars each made a new high: bar−2 > bar−3, bar−1 > bar−2, bar−0 > bar−1. This is a tighter, more specific condition than simply finding a 3-bar highest high.

**How the counter behaves:**

```
Bar:        1     2     3     4     5     6     7
High:      45    46    47    46    48    49    48
HighsCount: 1     2     3     0     1     2     0

Bar 4: High (46) < High[1] (47) → counter resets to 0
Bar 7: High (48) < High[1] (49) → counter resets to 0
```

At bar 6, `HighsCount = 2` — two consecutive new highs. With `HighsToSell = 2`, the short entry condition is met.

### 2. Contrarian Entry Logic

```pascal
If LowsCount >= LowsToBuy Then
    Buy Next Bar at Close of This Bar - LimitPoints Limit;

If HighsCount >= HighsToSell Then
    SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

Both entries are **counter-directional** — the strategy fades the momentum run:

- **Long entry during a lows run:** When `LowsCount >= LowsToBuy`, the market has made `LowsToBuy` consecutive lower lows. The strategy buys, expecting the downward streak to exhaust itself and reverse.
- **Short entry during a highs run:** When `HighsCount >= HighsToSell`, the market has made `HighsToSell` consecutive higher highs. The strategy sells short, expecting the upward streak to fade.

This is mean-reversion logic applied to a momentum structure: consecutive extremes are treated as overextension rather than continuation signals. The strategy does not interpret a run of new lows as a trend to follow — it interprets it as a stretched condition to fade.

**Limit order with offset:** Both entries use a limit order offset from the close of the signal bar:

- Long limit: `Close of This Bar - LimitPoints` — placed slightly below the close, requiring a minor additional pullback before filling.
- Short limit: `Close of This Bar + LimitPoints` — placed slightly above the close, requiring a minor bounce before filling.

The small offset (default `0.02`) avoids chasing the close price directly and provides a marginally better entry. As noted in other strategies in this repository, `Close of This Bar` in a `Next Bar` limit order produces fewer fills in gapping markets.

### 3. Risk Management

```pascal
SetStopPosition;
SetProfitTarget(ProfTgt);
SetStopLoss(StopLoss);
```

`SetStopPosition` applies subsequent stop functions to the total position rather than per share or per contract. `SetProfitTarget` and `SetStopLoss` are symmetric at their default values ($50 each), creating a 1:1 risk/reward ratio. Both are active simultaneously — whichever is reached first closes the position.

With symmetric stop and target, the strategy needs a win rate above 50% to be profitable. The mean-reversion hypothesis provides the directional edge: if consecutive extremes are statistically more likely to reverse than continue, the win rate should support the 1:1 ratio over a sufficient sample.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LowsToBuy` | 2 | Minimum consecutive lower lows required to trigger a long entry. |
| `HighsToSell` | 2 | Minimum consecutive higher highs required to trigger a short entry. |
| `LimitPoints` | 0.02 | Offset from the signal bar's close for the limit order price. |
| `ProfTgt` | $50 | Profit target per position in account currency. |
| `StopLoss` | $50 | Stop loss per position in account currency. |

**On `LowsToBuy` and `HighsToSell`:** The default value of `2` is the minimum meaningful streak — a single bar making a new extreme is noise; two consecutive bars suggest a short-term directional run. Increasing to `3` or `4` requires a more sustained streak before entry, reducing signal frequency but potentially improving signal quality. Values above `5` will produce very few signals on most instruments.

**On symmetric stop and target:** The $50 default values are calibrated for stocks. For futures, these should be scaled to the instrument's `BigPointValue`. For ES futures at $50/point, a $50 stop and target equal 1 point each — extremely tight for any meaningful test of the mean-reversion hypothesis on an instrument with typical daily ranges of 30–60 points.

---

## Trade Scenarios

### Scenario A — Long Entry After Consecutive Lows

```
Bar:      1      2      3      4      5
Low:    44.80  44.60  44.40  44.55  44.70
LowsCount: 1      2      3      0      0
```

- Bar 3: `LowsCount = 3 >= LowsToBuy (2)`. Signal fires.
- Long limit placed at `Close (44.45) - 0.02 = 44.43`.
- Bar 4: trades down to 44.43 briefly before recovering. Long fills at 44.43.
- `ProfTgt = $50` active. `StopLoss = $50` active.
- Price rallies. Profit target hits. Trade exits with +$50.

### Scenario B — Short Entry After Consecutive Highs

```
Bar:       1      2      3
High:    46.20  46.45  46.68
HighsCount: 1      2      3
```

- Bar 3: `HighsCount = 3 >= HighsToSell (2)`. Signal fires.
- Short limit placed at `Close (46.60) + 0.02 = 46.62`.
- Next bar bounces to 46.62. Short fills.
- Price fades. Profit target hits. Trade exits with +$50.

### Scenario C — Counter Resets, No Entry

```
Bar:       1      2      3
Low:     44.80  44.60  44.65
LowsCount:  1      2      0
```

- Bar 3: `Low (44.65) > Low[1] (44.60)` → `LowsCount` resets to 0.
- Streak broken. No entry fires even though `LowsCount` reached 2 on bar 2.
- The counter must be at or above `LowsToBuy` on the current bar for the entry to trigger.

### Scenario D — Limit Not Filled

- `LowsCount >= LowsToBuy` on bar X. Long limit at `44.43`.
- Next bar opens at 44.60 and trades up immediately. Never touches 44.43.
- Limit expires unfilled. No position entered.
- On bar X+1, `LowsCount` may no longer be `>= LowsToBuy` depending on whether another lower low was made.

---

## Key Features

- **Consecutive streak detection:** The counter mechanism identifies directional momentum runs bar by bar, resetting immediately on any bar that breaks the streak. This is more specific than a channel-based lookback.
- **Contrarian entry logic:** Both directions fade the momentum run — buying into consecutive lows, selling into consecutive highs. The strategy treats sustained extremes as overextension rather than trend signals.
- **Minimal parameter surface:** Two streak thresholds, one limit offset, and two risk levels. The strategy is easy to test and iterate on.
- **Symmetric risk/reward:** Equal stop and target at default values creates a balanced risk structure where edge must come entirely from the directional bias of the signal.
- **Limit entry with offset:** Both entries require a small price concession after the signal bar, avoiding direct market-order chasing of the already-extended close.
- **`SetStopPosition`:** Stop and target applied to the total position, not per share — appropriate for fixed-size stock trading where position-level dollar risk is the natural unit.

---

## Trade Psychology

Consecutive Extremes Fade encodes a specific market belief: **momentum runs at the bar level tend to exhaust themselves after a short streak.** A market that has made lower lows for two or three consecutive bars has been pushed in one direction by persistent sellers. The strategy bets that the selling pressure is temporary — that buyers will step in once the short-term streak reaches a threshold.

This is not a macro mean-reversion thesis (the instrument will return to its long-term average) but a micro mean-reversion thesis (the short-term directional push will lose steam within a few bars). The distinction matters for parameter calibration: the `LowsToBuy` threshold of 2 is deliberately small because the hypothesis is about short-term streak exhaustion, not multi-day trend reversals.

The contrarian stance requires a different psychological relationship with the market signal than trend-following. When `LowsCount` reaches 2, the market is falling — it *feels* dangerous to buy. The strategy's edge, if any, comes from acting against that feeling systematically. The limit order offset adds a layer of patience: rather than buying at the close of the falling bar, the strategy waits for one more small concession, acknowledging that the move may still have a brief continuation before reversing.

The symmetric stop and target encode a neutral outcome expectation: the strategy does not know *how far* the reversal will go, only that it expects one. The profit target captures a defined slice of the expected bounce; the stop loss caps the loss if the streak continues instead of reversing.

---

## Use Cases

**Instruments:** Most applicable to liquid instruments that exhibit short-term mean-reverting behavior at the bar level — equity index futures (ES, NQ) in range-bound or low-volatility sessions, individual stocks with identifiable short-term oscillations, and commodity futures with regular intraday swings. Strongly trending instruments where consecutive new highs or lows are the norm rather than the exception will produce frequent losing trades.

**Timeframes:** On daily bars, two consecutive lower lows is a two-day decline — a meaningful short-term pullback in many markets. On 5-min bars, two consecutive lower lows spans 10 minutes — a very short-term move that may be noise in liquid futures. The `LowsToBuy`/`HighsToSell` thresholds should be calibrated relative to the typical streak length for the chosen timeframe and instrument.

**As a research baseline:** This version is deliberately minimal — no trend filter, no time-of-day filter, no additional confirmation. It is designed to isolate and study the raw streak-exhaustion signal before adding filters. The natural research questions are: What is the win rate on the raw signal? Does the signal perform differently in trending vs. range-bound market regimes? Does adding a minimum streak length of 3 or 4 improve or hurt results? These questions directly motivate the design of a v2.

**Relationship to other strategies:** The consecutive-extreme counter is a different signal architecture than both the Donchian-channel breakout used in Opening Gap and the MRO-based structural low detection used in Key Reversal (Advanced). All three identify price extremes, but through different lenses: absolute channel boundaries, most-recent-occurrence scanning, and consecutive-bar streaks. Comparing their signal frequencies and performance characteristics on the same instrument is a productive research exercise.
