## Strategy Description

The **First Hour Channel** is an intraday breakout strategy that establishes a trading range during the market's opening hour, then enters the market when price attempts to break beyond that range. It operates on the principle that the first hour of trading establishes volatility boundaries, and breakouts from these boundaries often signal momentum moves worth trading.

### Core Mechanics

**Opening Hour Capture:** During the first 60 minutes (default) of the trading session, the strategy builds a channel by recording the highest high and lowest low of that period using intraday data. This range, known as the "First Hour Channel," represents the market's initial consensus and volatility envelope.

**Post-Opening Window:** Once the first hour closes, the strategy enters an active trading window. It begins accepting entry signals while the time remains before the stop-trading cutoff (default: 15:00 / 3 PM). This window allows the strategy to capture the day's momentum moves outside the opening range.

**Breakout Entry Logic:**

- **Long Entry:** If no position exists and long trades are still allowed for the day, the strategy places a buy order at the First Hour Low (the lower boundary of the opening hour). This triggers when price breaks below or touches the lower support level established during opening hour.
- **Short Entry:** If no position exists and short trades are still allowed for the day, the strategy places a sell short order at the First Hour High (the upper boundary of the opening hour). This triggers when price breaks above or touches the upper resistance level.

Both limit orders remain active during the trading window, waiting for price to reach these critical levels.

**One Trade Per Side Per Day:** Once a long position is established, the `CanLongToday` flag is disabled, preventing additional long entries for the remainder of the day. Similarly, once a short position is filled, the `CanShortToday` flag disables further short entries. This ensures the strategy takes at most one trade per direction per trading day.

**Risk Management:**

- **Stop Loss:** All positions are protected with a fixed stop loss amount (default: $250)
- **Profit Target:** All positions attempt to reach a fixed profit target (default: $250)

### Parameters

- **StopTradingTime:** Time when the strategy stops accepting new entries (default: 1500, meaning 3:00 PM)
- **StopLossAmount:** Dollar amount for the stop loss protection (default: 250)
- **ProfitTargetAmount:** Dollar amount for the profit target (default: 250)
- **FirstHourMinutes:** Duration of the opening hour to establish the channel (default: 60 minutes)

### Trade Scenarios

**Scenario 1: Opening Range Breakout Long**

1. First hour: High 100.50, Low 99.80 (channel established)
2. 10:30 AM: Price drops to touch 99.80
3. Long entry triggered at 99.80; risk/reward: $250 stop / $250 target
4. If price drops further, stop loss fills at 99.30
5. If price rallies, profit target fills at 100.30

**Scenario 2: Both Sides Blocked**

1. First hour: High 100.50, Low 99.80
2. 10:15 AM: Price breaks above 100.50 toward 101.00
3. Short entry triggered at 100.50
4. Trade moves to profit, closes at $250 profit target
5. Shortly after, price drops to 99.80; long entry is blocked (no longs allowed after short filled)
6. Strategy waits until next day

### Key Features

- **Session-Based Reset**: Daily reload of entry flags ensures fresh opportunities each trading day
- **Intrabar Execution**: `[IntraBarOrderGeneration = TRUE]` allows precise entries at critical levels without waiting for bar close
- **Defined Risk-Reward**: Fixed stop loss and profit target provide immediate position management without discretion
- **Directional Exclusivity**: Only one long and one short per day prevents over-trading the same range
- **Time-Bounded**: Stops accepting entries at a predetermined time, reducing late-day slippage risk
- **Simple Setup**: Classic opening range breakout pattern requires minimal calculation

### Trade Psychology

The strategy embodies a "momentum-after-range" philosophy: the opening hour defines volatility expectations, and when price clearly breaks those boundaries shortly after, it often signals conviction move. By allowing only one trade per direction, the strategy avoids whipsaws and false breakouts that occur after multiple range touches.

### Use Cases

- Intraday traders exploiting opening range breakouts
- Mechanical traders seeking a simple, rules-based daily system
- Markets with predictable opening hour volatility (stocks, ES, NQ, etc.)
- Traders wanting defined risk with fixed stop/target mechanics
- Portfolio of daily resets for consistent entry/exit rhythm

### Notes
