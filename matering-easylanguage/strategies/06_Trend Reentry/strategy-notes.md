## Strategy Description

The **Trend Reentry** is a long-only trend-following strategy that dynamically re-enters uptrends after profitable partial exits. Rather than holding a single position through an entire move, it takes tactical profits when price extends significantly from entry, then opportunistically re-enters if the underlying trend remains intact.

### Core Mechanics

**Initial Entry:** The strategy generates entry signals when the fast moving average (default: 13-period) crosses above the slow moving average (default: 21-period), indicating the birth of an uptrend. A long position is established at market on the next bar.

**Extension Exit (Profit Taking):** While holding the long position, the strategy monitors for a new highest high relative to the lookback period (default: 50 bars). When this extension occurs—signaling price has accelerated beyond typical movement—the position is sold to lock in profits. This technical exit sets a flag (`CanReEnter`) allowing subsequent re-entry.

**Trend Tracking:** Throughout the trade, the strategy maintains a running maximum (`MoveHigh`). This peak serves as the reference point for measuring if price continues its uptrend momentum.

**Re-Entry Logic:** After exiting at the extension level, the strategy can re-enter if:

1. A flat position exists (no open trade)
2. The `CanReEnter` flag is true (previous exit was technical, not due to trend failure)
3. Price exceeds the previous peak by the re-entry buffer (default: $0.10)

Multiple re-entries are allowed as long as the trend remains valid, enabling participation in multiple extensions within a single uptrend without pyramiding.

**Trend Termination:** When the fast MA crosses below the slow MA, the trend is considered broken. The position is sold immediately, and the re-entry flag is disabled, preventing further entries until a new bullish signal emerges.

### Parameters

- **FastLen:** Period for the fast moving average (default: 13 bars)
- **SlowLen:** Period for the slow moving average (default: 21 bars)
- **ExtensionLen** (v2) / **HHExitLen** (v1): Lookback period for detecting new highs (default: 50 bars)
- **ReEntryBuffer** (v2) / **ReEntryPoints** (v1): Price buffer above previous peak to trigger re-entry (default: $0.10)

### Trade Flow

1. **Flat** → Wait for bullish MA cross
2. **Initial Long** → First position enters at MA cross
3. **First SA Exit** → Price hits new high; position sold; re-entry enabled
4. **Re-Entry Long** → Price exceeds previous peak by buffer; position re-enters
5. **Extension Exit** → New high hit again; position sold; re-entry remains enabled
6. **Final Exit** → Bearish MA cross; trend breaks; re-entry disabled; position sold

### Key Features

- **Single Position**: Never more than one long trade at a time; re-entries replace old positions, they don't add to them
- **Profit Preservation**: Technical exits capture profits on price extensions rather than riding through reversals
- **Trend Resilience**: Can re-enter multiple times within one uptrend, capturing several price extensions
- **Clean Exits**: Final exit on trend death via moving average crossover prevents holding through reversals
- **State-Driven**: Clear logic flow based on market position and trend validity flags

### Use Cases

- Intraday trend-following with multiple entry opportunities per move
- Capturing stepped price extensions in strong uptrends
- Risk management through tactical profit extraction
- Trend traders seeking to maximize capture without over-exposure

### Notes
