# RSI Momentum Fade — v1.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

RSI Momentum Fade is a mean-reversion strategy that uses the RSI not as an overbought/oversold indicator in the classical sense, but as a momentum exhaustion detector. Rather than entering when RSI reaches extreme levels (70/30), the strategy enters when RSI is on one side of the 50 level — indicating directional bias — but has stopped making new extremes in the recent lookback window. This "cool-off" pattern suggests that the directional impulse is fading, creating a potential reversal opportunity before the RSI crosses back through 50.

The strategy uses a three-layer exit framework: an initial stop loss for immediate protection, a break even trigger that eliminates risk once the trade shows initial profit, and a dollar trailing stop that captures the remainder of the move if momentum continues.

---

## Core Mechanics

### 1. RSI Calculation

```pascal
xRSI = RSI(Price, Length);
```

`RSI` is EasyLanguage's built-in Relative Strength Index function. The default period of 14 bars is the classical Wilder RSI setting, measuring the ratio of average gains to average losses over the lookback window. The `x` prefix on `xRSI` is a naming convention distinguishing the calculated variable from the built-in function name.

### 2. The 50 Level as Momentum Boundary

The strategy uses RSI 50 as the dividing line between bullish and bearish momentum — a conceptually different use than the classical 70/30 overbought/oversold thresholds:

- **RSI > 50:** Recent average gains exceed recent average losses — momentum is net bullish.
- **RSI < 50:** Recent average losses exceed recent average gains — momentum is net bearish.

The 50 level is not a signal by itself. It establishes the directional context: the strategy looks for reversals from *within* the bearish zone (RSI < 50, expect long entries) and from *within* the bullish zone (RSI > 50, expect short entries).

### 3. Entry Filter — `LowestBar` and `HighestBar`

This is the core signal logic:

```pascal
If xRSI < 50 and LowestBar(xRSI, 7) >= 3 Then
    Buy Next Bar at Market;
If xRSI > 50 and HighestBar(xRSI, 7) >= 3 Then
    SellShort Next Bar at Market;
```

`LowestBar(series, N)` returns the offset (bars ago) of the lowest value in `series` over the last `N` bars. `HighestBar(series, N)` does the same for the highest value.

**For the long entry:** `LowestBar(xRSI, 7) >= 3` means the lowest RSI reading over the last 7 bars occurred at least 3 bars ago — the RSI has not made a new low in the last 3 bars. Combined with `xRSI < 50`, this means: the RSI is in bearish territory, but its weakest point was several bars ago. The downward impulse has cooled off.

**Concrete example from the code comments:**

```
Bar offset:  6    5    4    3    2    1    0   ← current bar
RSI:        42   38   35   30   33   37   41

LowestBar(xRSI, 7) = 3   (lowest RSI of 30 occurred 3 bars ago)
Condition: LowestBar >= 3 → True ✓
Reading: "RSI is below 50, but the weakest point was 3 bars ago —
          the bearish impulse has absorbed and may be reversing."
```

**Why `>= 3`?** The threshold is calibrated to balance timing precision against signal quality:
- `>= 1` or `>= 2`: too close to the extreme, the move may still be in progress.
- `>= 3`: a practical cool-off period — the RSI has had time to stabilize without having moved so far from its extreme that the reversal opportunity has passed.
- `>= 5` or more: the signal may arrive too late, with the reversal already partially played out.

Three bars is a deliberate balance — not impulsive, not delayed.

**Symmetric short logic:** `HighestBar(xRSI, 7) >= 3` with `xRSI > 50` applies the same reasoning to the bearish side: RSI is in bullish territory, but its peak was at least 3 bars ago — the upward impulse is fading.

### 4. Exit Framework — Three-Layer Risk Management

```pascal
SetStopLoss(StopAmt);
SetBreakeven(BEAmt);
SetDollarTrailing(TrlgAmt);
```

The three exit functions operate in sequence, creating a progressive risk reduction structure:

**Layer 1 — Stop Loss (`SetStopLoss`):**
Active immediately from entry. If the trade moves against the position by `StopAmt` dollars, the position closes. This is the maximum loss the strategy accepts on any single trade.

**Layer 2 — Break Even (`SetBreakeven`):**
Once the trade reaches a gain of `BEAmt` dollars, the stop loss moves to the entry price. From that point, the trade cannot lose — the worst outcome is a breakeven exit. The default values (`StopAmt = $50`, `BEAmt = $50`) mean the break even triggers at the same dollar amount as the stop — the moment the trade has shown $50 of profit, the risk is eliminated.

**Layer 3 — Dollar Trailing Stop (`SetDollarTrailing`):**
A trailing stop that follows the price at a fixed dollar distance (`TrlgAmt = $100`). As the trade moves in favor, the trailing stop rises (for longs) or falls (for shorts), locking in progressively more profit. The trailing stop only moves in the profitable direction — it never widens.

**Interaction between layers:** All three are active simultaneously once a position is open. The sequence that governs behavior:

1. If price moves against the trade immediately: **Stop Loss** fires at `StopAmt`.
2. If price first reaches `BEAmt` in profit: **Break Even** moves the stop to entry. Stop Loss level is now irrelevant — the floor is entry price.
3. From that point, **Trailing Stop** follows the price at `TrlgAmt` distance, locking in profit above the break even floor.

This structure means the trade has three possible exit states:
- **Maximum loss:** −`StopAmt` (if the trade never reaches break even).
- **Breakeven:** $0 (if the trade reaches `BEAmt` then reverses to entry before the trailing stop has moved above it).
- **Variable profit:** Captured by the trailing stop, which can theoretically grow without limit as long as price keeps moving.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Price` | `Close` | Price series used for RSI calculation. |
| `Length` | 14 | RSI lookback period. |
| `StopAmt` | $50 | Initial stop loss in dollars. Maximum loss per trade. |
| `BEAmt` | $50 | Dollar gain at which the stop moves to entry price (break even). |
| `TrlgAmt` | $100 | Dollar trailing stop distance once the position is profitable. |

**On the default risk parameters:** The $50 stop and $100 trailing distance are calibrated for stock prices. For futures contracts, these must be scaled to the instrument's `BigPointValue`. For ES futures at $50/point, a $50 stop equals 1 point — far too tight for any meaningful stop on a 14-bar RSI strategy. Adjust proportionally.

**On `BEAmt = StopAmt`:** Setting break even at the same dollar amount as the stop creates a symmetric initial structure: the trade risks $50 before break even and then risks $0 after. This is a conservative approach — once any profit appears equal to the initial risk, the risk is fully eliminated.

**On `TrlgAmt > StopAmt`:** The trailing distance ($100) is wider than the initial stop ($50). This is intentional — the trailing stop is designed to give the trade room to breathe after the initial momentum, rather than being stopped out by normal price fluctuations in a favorable move.

---

## Trade Scenarios

### Scenario A — Long Entry, Break Even, Trailing Exit

- RSI sequence over last 7 bars: 48, 44, 39, 34, 37, 40, 43. `xRSI = 43 < 50` ✓
- `LowestBar(xRSI, 7) = 3` (RSI of 34 occurred 3 bars ago) ✓
- Entry: **Buy Next Bar at Market**. Fills at 45.80.
- `SetStopLoss($50)` active. Stop at entry equivalent − $50.
- Trade advances. At +$50 gain: **Break Even** triggers. Stop moves to entry price.
- Trade continues advancing. Trailing stop at $100 below the running high.
- Price reaches +$180 then reverses. Trailing stop at +$80 above entry fires.
- Exit with approximately +$80 profit.

### Scenario B — Long Entry, Stop Loss Before Break Even

- Same entry at 45.80. Stop at −$50.
- Trade immediately moves against position. Loss reaches $50.
- **Stop Loss** fires. Exit with −$50.

### Scenario C — Short Entry, Impulse Already Peaked

- RSI sequence: 54, 58, 63, 67, 65, 61, 57. `xRSI = 57 > 50` ✓
- `HighestBar(xRSI, 7) = 3` (RSI of 67 occurred 3 bars ago) ✓
- Entry: **SellShort Next Bar at Market**.
- RSI peaked 3 bars ago — the bullish impulse has already cooled. Reversal anticipated.

### Scenario D — Signal Blocked (RSI Still Making New Extremes)

- RSI sequence: 48, 44, 39, 35, 32, 30, 28. `xRSI = 28 < 50` ✓
- `LowestBar(xRSI, 7) = 0` (current bar is the new low) → `0 >= 3` is **False** ✗
- Entry blocked. RSI is still making new lows — the bearish impulse is active, not fading.
- The strategy correctly waits for the impulse to pause before entering.

---

## Key Features

- **RSI as momentum exhaustion detector:** The strategy uses RSI 50 as a momentum boundary rather than 70/30 as overbought/oversold thresholds — a less common but structurally sound approach that focuses on *direction* of bias rather than *extremity*.
- **`LowestBar`/`HighestBar` as temporal filters:** These functions identify when the RSI's most extreme reading occurred, filtering entries that arrive while the impulse is still accelerating versus entries that wait for a measured cool-off period.
- **Three-bar cool-off requirement:** The `>= 3` threshold balances entry timing — early enough to capture the reversal, late enough to confirm the impulse has paused.
- **Progressive risk reduction:** Stop loss → break even → trailing stop creates a structure where maximum downside is capped, initial risk is eliminated quickly, and upside is theoretically unlimited.
- **Market orders for simplicity:** Entries at market on the next bar prioritize fill certainty over entry price optimization — appropriate for a first version focused on signal study rather than execution refinement.

---

## Trade Psychology

This strategy embodies a specific belief about momentum: **impulses exhaust themselves before reversing.** A trending RSI that keeps making new extremes is a sign that directional conviction is still strong. But an RSI that is on one side of 50 yet has stopped pushing to new extremes is showing the early signature of exhaustion — the directional move is present but decelerating.

The `>= 3` threshold encodes a patience principle: *"I do not enter the moment I see signs of exhaustion. I wait a few bars to confirm that the deceleration is not just noise."* This is not confirmation in the classical sense — the RSI has not crossed 50, the trend has not reversed — but it is a measured pause that reduces the frequency of entering during still-active impulses.

The three-layer exit reflects a progression of trade management philosophy. The stop loss says: *"I could be wrong — here is how much I will accept being wrong."* The break even says: *"once the trade has proven itself with initial profit, I will not let it become a loss."* The trailing stop says: *"I don't know how far this will go — I'll let the market decide and protect what it gives me."* Together, they create a system where the trader's maximum loss is known and fixed, but the maximum profit is open-ended.

The connection to Connors' TPS (Trading Pullback System) framework is a natural next step: TPS adds RSI-ranking over multiple bars, trend confirmation, and a count-based exit rather than a dollar trailing stop — bringing more structure to the entry timing and exit management while preserving the core momentum-exhaustion concept explored here.

---

## Use Cases

**Instruments:** The RSI momentum exhaustion signal is applicable to any liquid instrument with measurable price momentum — equity index futures (ES, NQ), individual stocks, commodity futures, and FX futures. The 14-period RSI requires sufficient bar history; shorter timeframes may produce more noise in the RSI calculation.

**Timeframes:** The 14-bar RSI on daily bars represents two trading weeks of momentum measurement; on 60-min bars it represents 14 hours. The `>= 3` bar cool-off should be interpreted relative to the timeframe — 3 daily bars is meaningful stabilization; 3 one-minute bars may be noise.

**As a first version:** This strategy is explicitly labeled v1 and is designed for study and backtesting rather than production deployment. The market-order entries, the absence of additional trend filters, and the hardcoded 7-bar and 3-bar thresholds are all starting points for iteration. A natural v2 would parametrize the lookback and cool-off values, add a higher-timeframe trend filter, and potentially replace market orders with limit orders for better entry precision.

**Connors TPS connection:** The RSI-below-50 plus momentum-exhaustion structure maps directly to the TPS concept of entering pullbacks within a trend after the RSI has reached a low level and begins recovering. The key conceptual link is the same: do not enter while momentum is accelerating against you; enter when it pauses. Future development of this strategy in the investigation repository should explicitly test the Connors RSI (2-period) variant and the count-based exit as an alternative to the dollar trailing stop.
