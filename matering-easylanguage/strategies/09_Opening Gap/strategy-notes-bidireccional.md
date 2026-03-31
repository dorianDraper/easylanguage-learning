## Strategy Description

The **Opening Gap Bidireccional** is a unified gap-fade strategy that consolidates gap-up and gap-down trading logic into a single system. Rather than maintaining separate strategies for each direction, this version uses conditional logic to dynamically trade whichever gap condition emerges at market open each day. It preserves all the mean-reversion mechanics of directional gap strategies while reducing code duplication and complexity.

### Core Mechanics

**Unified Gap Detection:** At each new session, the strategy simultaneously monitors for both:

- **Gap Down:** Opening price falls below the previous day's low by more than the volatility threshold
- **Gap Up:** Opening price rises above the previous day's high by more than the volatility threshold

**Dynamic Entry Logic:** The strategy can only hold one position at a time. When a flat market position exists:

- If a gap down is detected first, the strategy enters long at market
- If a gap up is detected first, the strategy enters short at market
- Whichever condition triggers first wins; the other direction is ignored for that session

This means the strategy trades the gap that actually occurs, making it reactive rather than predetermined. Only one gap per day can be traded.

**Adaptive Volatility Threshold:** The gap detection threshold is the median range of the last 50 bars. This ensures the strategy only trades meaningful gaps relative to recent volatility, automatically filtering noise in both directions.

**Gap Size Calculation:**

- **Gap Down:** `Gap = Low - Open` (the magnitude of the downside gap)
- **Gap Up:** `Gap = Open - High` (the magnitude of the upside gap)

**Dual Exit Framework:** Once a position is established, two simultaneous orders are activated:

- **Profit Target (Limit Order):** Targets gap fill at the reference price (`EntryPrice + Gap` for longs, `EntryPrice - Gap` for shorts)
- **Stop Loss (Stop Order):** Protects if the gap widens further (`EntryPrice - GapTest` for longs, `EntryPrice + GapTest` for shorts)

Only one of these orders will fill—either the reversion succeeds and the gap fills, or the move fails and the stop loss triggers.

### Parameters

- **GapTest:** Threshold for detecting significant gaps (default: `Median(Range, 50)[1]`). This adapts to market volatility automatically

### Trade Flow Examples

**Scenario 1: Gap Down Detected at Open**

- Previous day: Low at 3975, High at 3995
- Current day: Opens at 3960 (15 points below low, exceeds threshold of 10)
- Gap down is detected before any gap up
- Entry: Long at 3960 at market
- Profit target: 3975 (gap fill)
- Stop loss: 3950 (1 threshold below entry)
- Outcome: Reversion occurs; gap fills at 3975; profit target hits

**Scenario 2: Gap Up Detected at Open (Same Symbol, Different Day)**

- Previous day: High at 3995, Low at 3975
- Current day: Opens at 4010 (15 points above high, exceeds threshold)
- Gap up is detected
- Entry: Short at 4010 at market
- Profit target: 3995 (gap fill)
- Stop loss: 4020 (1 threshold above entry)
- Outcome: Weakness emerges; gap fills downward; profit target hits

**Scenario 3: Gap That Invalidates (Stop Loss Triggered)**

- Opens with a 12-point gap down
- Enters long at the gap-down level
- Instead of filling, the gap widens to 20 points as the move accelerates
- Stop loss triggers; exit with a loss
- No second attempt that day (flat position, signal already used)

### Key Differences from Directional Strategies

| Feature             | Opening Gap Up v2       | Opening Gap Down v2     | Opening Gap Bidireccional v1 |
| ------------------- | ----------------------- | ----------------------- | ---------------------------- |
| Can trade gap up?   | Yes                     | No                      | Yes                          |
| Can trade gap down? | No                      | Yes                     | Yes                          |
| Code duplication?   | N/A (single direction)  | N/A (single direction)  | Eliminated                   |
| Trades per day      | Up to 1 (if gap up)     | Up to 1 (if gap down)   | Up to 1 (either direction)   |
| Setup complexity    | Simple; clear direction | Simple; clear direction | Dynamic; reacts to gap type  |

### Key Features

- **Single Code Base:** Combines both directional logics into one program, reducing maintenance burden and improving consistency
- **Dynamic Directionality:** No pre-commitment to long or short; trades whichever gap actually forms
- **Automatic Volatility Adaptation:** The 50-bar median range threshold adjusts dynamically across markets and periods
- **One Trade Per Day:** Flat position requirement ensures the strategy takes at most one trade daily, regardless of gap direction
- **Parallel Exits:** Profit target and stop loss are simultaneous; market determines outcome—not trader emotion
- **Conditional Elegance:** Uses clear if/then logic to handle both directions within a unified framework
- **EOD Fallback:** `SetExitOnClose` handles unfilled positions in backtesting

### Trade Psychology

The strategy embodies a "I'll trade the gap that happens" philosophy. Rather than deciding in advance whether to trade gaps up or down, the algorithm simply observes which condition occurs and responds accordingly. This flexibility allows participation in the gap-fade theme without directional bias, trusting the mean-reversion principle to work regardless of direction.

### Use Cases

- Intraday traders wanting bidirectional gap exposure from a single system
- Traders preferring a single code base over managing multiple strategies
- Gap-fade traders seeking directional flexibility with consistent mechanics
- Index futures traders (ES, NQ) wanting to capture opening gap reversions
- System developers wanting a cleaner, more maintainable gap strategy template
- Time-constrained traders holding only one position per day maximum

### Execution Notes

- **Directive Entry:** Despite "bidireccional" in the name, only one trade per day is possible due to the `MarketPosition = 0` condition
- **Fast Fills Expected:** Both directions rely on same-day gap fills, typically occurring within 1-2 hours of open
- **Market Selection:** Works best on markets with consistent opening-hour activity and reliable gap behavior
- **No Overnight Hold:** Both positions are designed for same-day reversion; overnight holding risks negative carry

### Notes
