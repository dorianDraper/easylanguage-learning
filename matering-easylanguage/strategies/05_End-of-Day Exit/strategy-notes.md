## Strategy Description

The **End-of-Day Exit** is an exit-only risk management component designed to automatically close all open positions before the market session ends. Rather than being a standalone trading strategy, it serves as a protective mechanism that ensures no positions are held overnight, eliminating overnight gap risk and time-decay exposure.

### Core Mechanics

**Real-Time Operation:** When trading live, the strategy monitors the actual computer time using `CurrentTime` and triggers market exit orders n minutes before the official session close time (default: 3 minutes). Once triggered, all long positions are sold and all short positions are bought-to-cover at market price on the next bar.

**Backtesting Approximation:** To simulate end-of-day exits during historical testing, the strategy uses `SetExitOnClose` when not in the final real-time bar. This closes positions at the daily closing price, providing a reasonable approximation of EOD behavior for strategy validation purposes.

**Intrabar Order Execution:** The strategy requires `[IntrabarOrderGeneration = TRUE]` to function correctly. This allows the system to execute exit orders within the bar before the market officially closes, rather than waiting until the next bar opens.

**Smart Temporal Logic:** The strategy distinguishes between:

- **Historical bars** (`Date ≠ CurrentDate`): Uses closing prices for EOD simulation
- **Current day bars** (`Date = CurrentDate`): Uses real computer time for live execution
- **The final bar** (`LastBarOnChart and Date = CurrentDate`): Checks actual clock time against session end time

### Parameters

- **EODExitMinutes** (v2) / **MinstoX** (v1): Number of minutes before session close to trigger exits (default: 3 minutes)

### Key Features

- **Exit-Only Logic:** No entry rules; integrates with any entry strategy
- **Timeframe Independent:** Works with any intraday chart interval
- **Market-Agnostic:** Uses `SessionEndTime(1,1)` to work across all markets (stocks, futures, forex)
- **No Price Bias:** Closes at market regardless of profit/loss status
- **Portfolio-Wide:** Simultaneously closes all long and short positions

### Use Cases

- Intraday scalping strategies requiring daily closes
- Risk management for overnight gap prevention
- Trader comfort (no overnight position exposure)
- Reducing time-decay impact on options-based strategies
- Compliance with risk limits or trading rules

### Notes
