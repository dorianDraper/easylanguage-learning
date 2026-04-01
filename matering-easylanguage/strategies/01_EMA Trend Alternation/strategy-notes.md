## Strategy Description

The **EMA Trend Alternation** is a trend-following strategy that forces directional alternation—the algorithm automatically switches between long and short trades, preventing consecutive trades in the same direction. This enforced alternation creates a balanced trading rhythm that **reduces directional bias and forces systematic position rotation**.

### Core Mechanics

**Trend Detection:** The strategy uses two exponential moving averages with different periods:

- **Fast EMA** (default: 9-period) – Responds quickly to recent price action
- **Slow EMA** (default: 18-period) – Represents the longer-term trend direction

The trend state is determined simply:

- **Bull Trend:** Fast EMA > Slow EMA
- **Bear Trend:** Fast EMA < Slow EMA

**Signal Generation (The Alternation Engine):** The strategy has a sophisticated entry logic that enforces directional rotation:

**Long Signal Requirements:**

1. Flat position (no open trades)
2. Bull trend is active (Fast EMA above Slow EMA)
3. AND either:
   - First trade of the strategy (no prior positions), OR
   - A cooldown period has elapsed since the last exit (default: 3 bars), AND the previous position was a short

**Short Signal Requirements:**

1. Flat position (no open trades)
2. Bear trend is active (Fast EMA below Slow EMA)
3. AND either:
   - First trade of the strategy (no prior positions), OR
   - A cooldown period has elapsed since the last exit, AND the previous position was a long

This logic creates a **mandatory alternation pattern**: after a long trade exits, the next long cannot enter until a short has been taken. Same applies in reverse.

**Entry Execution:** When either signal is true, a market order enters on the next bar:

- Long entries: `Buy ("EMA_Trend_LE") Next Bar at Market`
- Short entries: `SellShort ("EMA_Trend_SE") Next Bar at Market`

**Exit Framework:** Once in a position, two simultaneous orders manage the exit:

- **Profit Target:** Fixed number of points above (longs) or below (shorts) entry price
- **Stop Loss:** Fixed number of points below (longs) or above (shorts) entry price

Only one fills; whichever is hit first closes the position and resets the alternation clock.

### Parameters

- **FastEMAPrice:** Data field for the fast EMA (default: Close)
- **FastEMALength:** Period for the fast EMA (default: 9 bars)
- **SlowEMAPrice:** Data field for the slow EMA (default: Close)
- **SlowEMALength:** Period for the slow EMA (default: 18 bars)
- **CooldownBars:** Number of bars required after exit before the next trade of the same direction (default: 3)
- **ProfitTargetPoints:** Points above/below entry for profit target (default: 1 point)
- **StopLossPoints:** Points below/above entry for stop loss (default: 0.5 points)

### Trade Flow Example

**Day 1 - Initial Long**

- Bull trend detected (FastEMA > SlowEMA)
- First trade condition met
- Enter long at market
- Profit target or stop loss fills; position closes

**Day 2 - Forced Short**

- Bear trend detected (FastEMA < SlowEMA)
- Cooldown passed (3 bars since exit)
- Previous position was long
- Enter short at market
- Position closes (profit/loss)

**Day 3 - Cannot Immediately Re-Enter Long**

- Bull trend is back (FastEMA > SlowEMA)
- Cooldown passed (3 bars since exit)
- BUT previous position was short, not long
- **No entry** – forced to wait for another short signal first, or cooldown + previous short completes and new bull signal appears

**Day 4 - Eventually Long Again**

- Bull trend still active
- Cooldown passed
- Previous position was short
- NOW the long condition is met (bull trend + previous was short + enough bars passed)
- Enter long at market

### Key Features

- **Enforced Alternation:** The mandatory switch between directions prevents over-commitment to any single trend
- **Cooldown Mechanism:** The 3-bar waiting period prevents whipsaws and creates breathing room after exits
- **Mechanical Rhythm:** Following a fixed signal pattern reduces emotional trading and emotion-driven decisions
- **Balanced Portfolio Work:** If running multiple instruments, the alternation creates a distributional hedge
- **State Clarity:** Explicit variables track trend, position state, and timing conditions
- **Simple Setup:** Two moving averages make the strategy easy to understand and debug
- **Fixed Risk/Reward:** Defined profit target and stop loss provide immediate position sizing

### Trade Psychology

The strategy embodies a "forced balance" philosophy. Rather than chasing a single trend direction until it stops, the algorithm says: "After you exit, you must try the opposite direction before returning to your previous direction." This prevents the trap of holding through reversals waiting for a better entry and distributes risk more evenly.

### Advantages of Alternation

| Aspect                              | Continuous Trend-Following | EMA Trend Alternation                  |
| ----------------------------------- | -------------------------- | -------------------------------------- |
| Can have multiple consecutive longs | Yes                        | No                                     |
| Rotation speed                      | Depends on market          | Fixed (every exit + cooldown)          |
| Trend-following bias                | Yes                        | Balanced (forces opposite direction)   |
| Whipsaw exposure                    | Moderate                   | Lower (cooldown reduces false signals) |
| Idle periods                        | Minimal                    | None (always alternating)              |

### Use Cases

- Scalp traders seeking mechanical, rule-based entry/exit
- Traders wanting to reduce directional bias through forced alternation
- Intraday strategies with tight profit targets and defined risk
- Portfolio strategies where rotation balance is valued
- Automated trading systems requiring predictable entry patterns
- Traders testing the benefits of forced diversification between long/short

### Execution Notes

- **Intraday Focused:** With 1-point profit targets and 0.5-point stops, this is primarily an intraday strategy
- **Liquid Markets Only:** Fixed pip profit targets require reliable liquidity at entry and exit
- **Trend Filters:** The 9/18 EMA provides basic trend identification; additional filters could improve accuracy
- **Alternation as Feature:** The forced alternation is intentional, not a bug; it trades the opposite direction on purpose

### Notes
* Real hedge: Does the alternation benefit or harm? 
* Targets and stops levels: base strategy params are tight, we have to test