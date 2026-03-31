## Strategy Description

The **KeyReversal** is a mean-reversion strategy that identifies and trades the classic key reversal pattern—a structural low followed by a bullish close at a higher price level. It incorporates an advanced scale-in mechanism that adds to profitable positions when losing trades meet specific conditions, offering exposure management through multiple entry tiers.

### Core Mechanics

**Key Reversal Detection:** The strategy scans the last n bars (default: 21-bar Donchian channel) to find the most recent structural low—a bar that makes a new lowest low relative to previous bars. Once identified, it checks if the close of the bar following that low (the potential reversal bar) is bullish relative to the low's close. A tolerance factor (default: 0%) allows slight adjustments to account for gaps or minor slippage.

**Initial Entry:** When both conditions are met—a structural low exists AND the reversal close is confirmed—the strategy enters a long position (LE1) at market price on the next bar.

**Scale-In Logic (Advanced):** While holding the base position, if the Key Reversal pattern remains valid (structural low still detected, reversal close confirmed) AND the trade is currently at a loss (`OpenPositionProfit < 0`), the strategy doubles down with a second entry (LE2). This adds 100 additional shares at market, effectively averaging into a favorable reversal setup.

**Independent Exit Timers:** Each entry operates on its own time clock:

- **Base Entry (LE1):** Automatically exits 100 shares after n bars (default: 5 bars) from its entry date
- **Scale Entry (LE2):** Automatically exits 100 shares after n bars (default: 5 bars) from its entry date (only if scale-in occurred)

This staggered exit mechanism allows the base position to run independent of the scaling position, preventing lock-step liquidation.

**State Machine:** The strategy maintains three distinct states:

- **State 0 (Flat):** No positions; waiting for Key Reversal signal
- **State 1 (Long Base):** First entry made; monitoring for scale-in opportunity
- **State 2 (Long Scaled):** Both entries active; each with independent exit timer

### Parameters

- **DonchianLen:** Lookback period for detecting structural lows (default: 21 bars)
- **CarryForwardBars:** Additional bars to scan backward before the earliest visible low (default: 0)
- **ConfirmationTolerancePct:** Tolerance % for the reversal close to exceed the low's close (default: 0%)
- **ExitAfterBars:** Number of bars each entry holds before automatic exit (default: 5 bars)

### Trade Scenarios

**Scenario 1: V-Shaped Recovery**

1. Lower low detected, reversal close confirmed
2. Base entry triggers; trade moves to profit
3. 5 bars elapsed → base entry exits with gain
4. No scale-in (condition was never met)

**Scenario 2: Scale-In During Drawdown**

1. Lower low detected, reversal close confirmed
2. Base entry triggers; trade moves to loss
3. Key Reversal still valid; scale-in entry triggered (LE2)
4. Position now has 200 shares (100 base + 100 scale)
5. 5 bars from base entry → base position exits
6. 5 bars from scale entry → scale position exits (slightly later)

### Key Features

- **Pattern-Driven**: Uses a well-known reversal pattern with structural validation
- **Loss Protection with Conviction**: Scales down into losses only when the reversal setup remains valid—not blind averaging
- **Multi-Tier Position Management**: Independent exit clocks for each entry prevent correlated liquidation
- **Controlled Risk**: Fixed share size (100 shares per entry) and defined exit timeframes
- **State Clarity**: Explicit state tracking (0=Flat, 1=Base Long, 2=Scaled Long) ensures clean order execution

### Trade Psychology

The strategy embodies a "double-down-into-strength" mindset: if the reversal pattern is still valid when facing a loss, the lower entry price is viewed as additional conviction, not capitulation. The independent timers ensure both entries get their own chance to recover.

### Use Cases

- Counter-trend traders capturing key reversal bounces
- Volatility traders exploiting mean reversion at structure lows
- Position builders comfortable with scale-in mechanics
- Traders combining technical pattern recognition with systematic position sizing

### Notes
