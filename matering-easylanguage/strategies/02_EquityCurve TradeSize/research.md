# Why Breakouts Work for Trend Following

A breakout from a Donchian channel means the market is making a new relative maximum. This usually coincides with three known phenomena.

### 1️⃣ Structural Momentum

In financial markets, there exists the so-called momentum effect:

- Assets that rise tend to keep rising

- Assets that fall tend to keep falling

This phenomenon was empirically documented in academic finance by Narayan Jegadeesh and Sheridan Titman in their research on stock momentum. The central idea: movements tend to persist.

### 2️⃣ Stop Clusters

Recent highs and lows usually contain accumulated stop orders. When price breaks a maximum:

- Stops from short positions execute

- Breakout orders activate

This creates additional order flow in the same direction.

### 3️⃣ Liquidity and Breakout Continuation

In market microstructure:

- Highs attract aggressive liquidity

- Algorithms detect range breakouts

This produces movement continuation.

# Why Inverted Donchian Fails as Mean Reversion

The original system studied here enters long (Buy) when it breaks the minimum and short (Short) when it breaks the maximum.

This attempts to capture exhaustion moves. The problem is that:

### 1️⃣ Extremes are usually the start of the movement

Many strong moves begin precisely with range breakout. Therefore, the contrarian system enters against the start of the trend.

### 2️⃣ There is no reversal signal

Breaking the channel only indicates a new extreme, not reversal. This is why mean reversion systems usually require exhaustion confirmation.

# Empirical Evidence

Donchian systems were popularized by Richard Donchian and later by the Turtle system developed by Richard Dennis.

These systems were explicitly trend-following. Classic example: Buy 20-day breakout, Sell 20-day breakout. Contrarian systems on breakouts rarely work without additional filters.

# What Quants Do to Improve These Systems

Quantitative developers add filters to distinguish between: genuine breakout vs. exhaustion move

The most common ones are:

### 1️⃣ Volatility Filter

Many false breakouts occur when volatility is low. A typical filter:

- Only trade if `ATR > average ATR`

This avoids sideways markets.

### 2️⃣ Trend Regime Filter

Many mean reversion systems only work in sideways markets. A common filter is `ADX < threshold`. This avoids trading against strong trends.

### 3️⃣ Reversal Confirmation

Contrarian systems usually require price to return within the channel. Example:

`Low < DonchianLow and Close > DonchianLow`

This indicates rejection of the level.

### 4️⃣ Overextension Filter

Many quants use overbought/oversold indicators. Examples:

- RSI
- z-score
- Distance from moving average

Example: `RSI < 20`

### 5️⃣ Volume Filter

Real extremes are usually accompanied by volume spikes. Example: `Volume > AvgVolume`

## Examples of Simple System Improvement

A typical improvement would be to require rejection of the extreme. Instead of:

`Low < DonchianLow`

Use:

`Low < DonchianLow and Close > DonchianLow`

This means: the market tried to break but was rejected, this is already a reversal signal.

## Another Very Common Improvement: z-score of Price

Many mean reversion systems use deviation from the average.

`z = Price - MA / StdDev`

Trade only if `Z < -2`. This ensures a real statistical extreme.

# What Edge the EMA Trend Reversal-Cycle System Actually Attempts to Capture

The original system attempts to capture short-term exhaustion (we enter long with a new minimum and short when it makes a new maximum), but without filters what it detects is the beginning of momentum. This is why the system improves when inverted, meaning we enter long when it makes a new high and short when it makes a new low.

# Conceptual Summary

Strategy Signal
Trend following Breakout
Mean reversion Rejection

The original system used breakout for mean reversion, which is contradictory. A more robust version would be:

1. Detect breakout
2. Wait for rejection
3. Enter

This is exactly what many quants call: failed breakout strategy.
