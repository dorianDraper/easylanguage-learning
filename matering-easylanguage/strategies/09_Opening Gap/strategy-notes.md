## Strategy Description

The **Opening Gap** strategy pair exploits a well-known market tendency: opening gaps created between the previous day's close and the current day's open tend to be filled during the trading session. The strategy splits logic into two directional components—Opening Gap Up (short trades) and Opening Gap Down (long trades)—each betting that oversized overnight gaps will revert to the previous day's price levels.

### Core Mechanics

**Opening Gap Up (Short Direction):**

The strategy monitors for a new trading session and detects when the opening price is significantly higher than the previous day's high. The threshold for "significant" is dynamic, calculated as the median of the last 50 trading ranges. This adaptive approach ensures the strategy only trades gaps that exceed normal volatility, filtering out minor gaps that are less likely to reverse.

When a gap up is confirmed:

1. The gap size is calculated: `Gap = Open - PreviousHigh`
2. A short position enters at market on the first bar
3. A profit target is set at the previous high (where the gap is fully filled): `EntryPrice - Gap`
4. A stop loss is set at the entry point plus the gap threshold (invalidating the trade setup): `EntryPrice + GapTest`

**Opening Gap Down (Long Direction):**

The strategy mirrors the gap-up logic in the opposite direction. When the opening price is significantly lower than the previous day's low (by the same threshold), a long position enters at market.

When a gap down is confirmed:

1. The gap size is calculated: `Gap = PreviousLow - Open`
2. A long position enters at market on the first bar
3. A profit target is set at the previous low (where the gap is fully filled): `EntryPrice + Gap`
4. A stop loss is set at the entry point minus the gap threshold (invalidating the trade setup): `EntryPrice - GapTest`

**Dual Exit Framework:**

Both strategies use simultaneous limit and stop orders:

- **Profit Target (Limit):** Fills when the gap is completed, typically within hours of opening
- **Stop Loss (Stop):** Fills if the gap widens further, indicating a false setup or strong directional move

### Parameters

**Both Strategies Share:**

- **GapTest:** Threshold for detecting significant gaps (default: `Median(Range, 50)[1]`, the median range of the last 50 bars). Acts as a filter to ignore minor gaps and adapts to market volatility
- **GapPrice:** Reference price for gap detection (default: `High` for Gap Up, `Low` for Gap Down)

### Trade Scenarios

**Scenario 1: Gap Up Successfully Filled**

- Previous day: Close at 3990, High at 3995
- Current day: Opens at 4010 (15 points above high, exceeds threshold)
- Entry: Short at 4010 at market
- Profit target: 3995 (gap filled)
- Outcome: Price retraces to 3995 by mid-morning; profit target filled; trade exits at breakeven or profit

**Scenario 2: Gap Down That Holds (Stop Loss Triggered)**

- Previous day: Close at 3980, Low at 3975
- Current day: Opens at 3960 (15 points below low, exceeds threshold)
- Entry: Long at 3960 at market
- Profit target: 3975 (gap filled)
- Stop loss: 3945 (1 threshold worth of additional weakness)
- Outcome: Gap widens further; opening dip turns into a sustained selloff; stop loss fills; trade exits with a loss

**Scenario 3: Intraday Gap Fade (Quick Fill)**

- Gap down of 10 points from previous low
- Entry at market at open
- By 9:45 AM, gap has been fully retraced
- Profit target fills with quick, clean exit

### Key Features

- **Dynamic Volatility Filtering:** Uses the 50-bar median range to ensure gaps are significant relative to recent trading, not absolute points
- **Mean Reversion Foundation:** Exploits the statistical tendency for gaps to partly or fully fill intraday
- **Immediate Dual Exits:** Both profit target and stop loss are active simultaneously, allowing the market to pick the outcome
- **Directional Separation:** Gap Up and Gap Down are independent strategies, allowing usage of one, both, or selective combinations
- **Session-Aware Entry:** Specifically targets the gap between previous close and current open, not intraday patterns
- **EOD Fallback:** Uses `SetExitOnClose` for historical backtesting, ensuring unfilled positions close at session end

### Trade Psychology

The strategy embodies a "gaps tend to fill" principle—a common market saying rooted in the idea that overnight gaps often represent overreactions or panic-driven moves. By the time the regular session begins, cooler heads and daytraders step in to fade the gap. The adaptive threshold ensures the strategy only trades gaps that break the normal volatility pattern.

### Use Cases

- Intraday traders capitalizing on reversions to equilibrium
- Gap-fade traders with mechanical entry rules
- Pre-market traders monitoring overnight developments for systematic entry
- Index futures traders (ES, NQ) with reliably large opening-hour activity
- Traders seeking high-probability, quick-exit trade setups
- Portfolio of mean-reversion trades across multiple markets

### Execution Notes

- **Best Used Intraday:** Both strategies are designed for same-day reversions; holding overnight defeats the gap-fill thesis
- **High Volatility Periods:** Earnings or macroeconomic events can produce gaps that don't fill; additional filters may improve results
- **Liquidity at Open:** Entries at market on the first bar require sufficient volume; illiquid markets may cause slippage
- **Time Decay:** As hours pass, the probability of gap fill decreases; strategies perform best in first 1-2 hours

### Notes
