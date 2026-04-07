# EPS Momentum Long — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

EPS Momentum Long is a long-only strategy that combines fundamental analysis with technical momentum to time entries in individual stocks. Rather than using price action alone, the strategy requires that a company's earnings per share (EPS) is improving before considering any entry — the fundamental condition acts as a primary filter that defines the universe of tradeable conditions. Within that filtered universe, a short-term price momentum signal triggers the actual entry. The strategy holds the position until either the fundamental thesis deteriorates (a new earnings report shows declining EPS) or the technical structure fails (price makes a new six-month low).

This is the first strategy in this repository to use fundamental data directly in trading logic, accessing EPS values and report dates from TradeStation's integrated data feed via EasyLanguage's `FundValue` and `FundDate` functions.

---

## Core Mechanics

### 1. Fundamental Data Access — `FundValue` and `FundDate`

```pascal
EPSCurr        = FundValue("SBBF", 0, ErrorEPS);
EPSPrev        = FundValue("SBBF", 1, ErrorEPSPrev);
EPSReleaseDate = JulianToDate(FundDate("SBBF", 0, ErrorDate));
```

**`FundValue(field, offset, errorCode)`** retrieves fundamental data values from TradeStation's integrated data source:
- `"SBBF"` is the Thomson Reuters/Refinitiv field code for *Basic EPS Before Extraordinary Items* — the earnings per share figure reported before one-time charges or gains are included.
- `offset = 0` returns the most recent available report; `offset = 1` returns the previous report.
- `errorCode` is an output parameter — it receives a non-zero value if the data is unavailable, stale, or the field is unsupported for the instrument. This is the standard EasyLanguage error-handling pattern for fundamental data calls.

**`FundDate(field, offset, errorCode)`** returns the date of the corresponding earnings report in Julian date format. `JulianToDate` converts this to EasyLanguage's standard YYYMMDD date integer, enabling direct comparison with `Date` and `Date[1]`.

**Why `"SBBF"`?** Different fundamental fields are available through different codes. `SBBF` specifically targets earnings per share before extraordinary items, which provides a more consistent comparison across reporting periods than EPS figures that include one-time events. Other available codes include revenue, book value, dividends, and many more — the same `FundValue`/`FundDate` pattern applies to all of them.

### 2. Data Validation

```pascal
// v1
DataOK     = True;   // Reset to True; set False if error
EPSVal     = FundValue("SBBF", 0, oErrorCode);
If oErrorCode > 0 Then DataOK = False;

// v2 — consolidated
FundamentalOK = ErrorEPS = 0 and ErrorEPSPrev = 0 and ErrorDate = 0;
```

Both versions validate that all three data calls succeeded before executing any logic. A non-zero error code means the data is unreliable — the instrument may not have earnings data, the field may be unsupported, or the data feed may have a gap. Trading on invalid fundamental data would produce incorrect signals, so all three conditions must be error-free.

v2 consolidates the three separate flag variables (`DataOK`, `DataOKPrev`, `DateDataOK`) into a single `FundamentalOK` boolean, following the same separation-of-concerns principle used throughout the repository.

### 3. EPS Trend Detection

```pascal
EPSImproving = EPSCurr > EPSPrev;   // v2
EPSInc       = EPSVal > EPSPrevVal;  // v1
```

The fundamental filter is straightforward: is the most recent EPS report higher than the one before it? A single comparison between the current and previous earnings report determines whether the company is on an improving earnings trend. This is deliberately simple — a more sophisticated version could compare year-over-year EPS, analyst estimates, or EPS growth rate, but the core concept of "earnings are getting better" is captured by this single condition.

### 4. New Earnings Release Detection

```pascal
// v1 — date of most recent report is more recent than yesterday's bar
EPSDateToday = EPSReportDate > Date[1];

// v2 — date of most recent report is today or later
NewEPSReleased = EPSReleaseDate >= Date;
```

This condition identifies when a fresh earnings report has become available. It is used in the exit logic — if a new report is released and EPS has deteriorated, the trade exits.

**v1 vs v2 semantic precision:** The v1 condition (`EPSReportDate > Date[1]`) precisely captures "a new report was released after yesterday's bar" — i.e., it became available today. This is the original design intent from the course material. The v2 condition (`EPSReleaseDate >= Date`) is broader: it is also `True` when the report date is in the future, which could theoretically include reports not yet published. In practice, `FundValue` does not return data for unpublished reports, so this difference rarely affects behavior. However, v1's formulation is semantically tighter and more accurately describes the intended condition. This is a case where the v2 refactoring improved code structure but introduced a subtle loosening of the original semantic precision.

### 5. Price Momentum Entry Signal

```pascal
// v1 — two-point momentum confirmation
High > High[4] and High[1] > High[5]

// v2 — single clean condition
PriceMomentum = High > Highest(High, 5)[1];
```

Both versions require short-term bullish price momentum as the execution trigger. The conditions are similar but not identical:

- **v1** requires two simultaneous conditions: today's high exceeds the high from 4 bars ago, AND yesterday's high exceeded the high from 5 bars ago. This is a two-point momentum confirmation — both the current bar and the previous bar are showing relative strength against their respective lookback points.
- **v2** requires a single condition: today's high exceeds the highest high of the previous 5 bars (excluding the current bar, due to the `[1]` offset). This is cleaner to read and reason about — it simply asks whether price is currently breaking above its recent range.

The v2 condition can be more or less restrictive than v1 depending on the specific price sequence. In most trending scenarios they produce similar signals, but v2 is the more natural expression of "price momentum breakout above recent highs."

### 6. Entry Condition

```pascal
// v2
If MarketPosition = 0 and FundamentalOK and EPSImproving and PriceMomentum Then
    Buy ("MO_EPS_Long") Next Bar at Market;
```

The entry requires all three independent conditions to be simultaneously true:
- `MarketPosition = 0`: no existing position — the strategy is not pyramiding.
- `FundamentalOK`: all fundamental data calls returned valid data.
- `EPSImproving`: the most recent EPS exceeds the previous EPS.
- `PriceMomentum`: price is breaking above its recent high range.

The fundamental condition acts as the primary filter — it defines whether the company qualifies. The momentum condition acts as the timing trigger — within qualifying companies, it identifies when to enter.

### 7. Exit Logic — Fundamental and Technical

```pascal
// Exit 1 — fundamental deterioration
If NewEPSReleased and Not EPSImproving Then
    Sell ("EPS_Down") This Bar on Close;

// Exit 2 — structural trend failure
If StructuralTrendFailure Then
    Sell ("6M_Low") This Bar on Close;
```

Two independent exit conditions, either of which closes the position on the close of the current bar:

**Fundamental exit:** When a new earnings report is released and shows declining EPS (`Not EPSImproving`), the original thesis for holding the stock — improving earnings — has been invalidated. The exit is immediate (`This Bar on Close`) rather than delayed, reflecting that fundamental deterioration is a clear reason to exit regardless of where price is intraday.

**Technical exit:** `Low < Lowest(Low, StructuralLookback)[1]` — the current bar's low is below the lowest low of the previous `StructuralLookback` bars (default 26, representing approximately six months of weekly bars). A new six-month low indicates that the technical structure supporting the uptrend has broken. The `[1]` offset excludes the current bar from the channel calculation, ensuring the exit fires only when price breaks the prior period's established low, not simply when it touches the current bar's developing range.

`This Bar on Close` executes on the same bar that triggers the condition, providing the most timely exit available within the bar without requiring intrabar order generation.

---

## v1 vs v2: The Difference

| | v1.0 | v2.0 |
|---|---|---|
| **Fundamental data access** | ✓ | ✓ |
| **Data validation** | ✓ (3 separate flags) | ✓ (`FundamentalOK` consolidated) |
| **EPS improvement detection** | ✓ | ✓ |
| **New EPS release detection** | `> Date[1]` (precise) | `>= Date` (slightly broader) |
| **Momentum condition** | Two-point (`High > High[4] and High[1] > High[5]`) | Single (`High > Highest(High, 5)[1]`) |
| **`MarketPosition = 0` entry guard** | — | ✓ |
| **`StructuralLookback` as parameter** | Hardcoded `26` | ✓ configurable |
| **Named boolean signals** | Partial | ✓ full separation |
| **Separated labeled blocks** | Partial | ✓ |

---

## Parameters

### v1
No inputs — all values are hardcoded.

### v2

| Parameter | Default | Description |
|-----------|---------|-------------|
| `StructuralLookback` | 26 | Lookback bars for the six-month low calculation. Default of 26 corresponds to approximately six months of weekly bars or one quarter of daily bars. |

**On `StructuralLookback = 26`:** The intended interpretation is 26 weekly bars — approximately six calendar months of trading history. If the strategy is applied to daily bars, 26 bars represents approximately five weeks, which is a much shorter structural reference. In that case, `StructuralLookback` should be set to approximately 130 (26 weeks × 5 trading days) to preserve the six-month intent.

---

## Trade Scenarios

### Scenario A — Full Entry: EPS Improving + Price Breaking Out

- `FundValue("SBBF", 0)` = 2.45. `FundValue("SBBF", 1)` = 2.10. All error codes = 0.
- `EPSImproving = True` (2.45 > 2.10). `FundamentalOK = True`.
- Current bar: `High = 48.20`. `Highest(High, 5)[1] = 47.80`. `PriceMomentum = True`.
- `MarketPosition = 0`. All conditions met.
- **Buy next bar at market.** Long position opens.

### Scenario B — Entry Blocked: EPS Declining

- `FundValue("SBBF", 0)` = 1.85. `FundValue("SBBF", 1)` = 2.10.
- `EPSImproving = False` (1.85 < 2.10). Entry condition fails.
- Even if price momentum is strong, no entry fires. The fundamental filter suppresses the signal.

### Scenario C — Fundamental Exit: New Report Shows EPS Decline

- Long position open. `EPSImproving` was `True` at entry.
- New earnings report released. `NewEPSReleased = True`. Latest EPS = 1.90, previous = 2.45.
- `EPSImproving = False`. Both conditions true: `NewEPSReleased and Not EPSImproving`.
- **Sell this bar on close.** Position exits on fundamental deterioration.

### Scenario D — Technical Exit: New Six-Month Low

- Long position open. Strategy has been holding for several weeks.
- Current bar low: 41.20. `Lowest(Low, 26)[1]` = 42.50.
- `Low (41.20) < 42.50`. `StructuralTrendFailure = True`.
- **Sell this bar on close.** Position exits on structural trend failure.

### Scenario E — Data Validation Failure: No Entry

- `FundValue("SBBF", 0, ErrorEPS)` call returns `ErrorEPS = 3` (data unavailable).
- `FundamentalOK = False`. All strategy logic suspended.
- No entry orders placed. Strategy waits for valid data on the next bar.

---

## Key Features

- **Fundamental-first filtering:** EPS improvement is a prerequisite for entry, not a confirmation signal. The strategy only considers stocks where the earnings trend is positive, regardless of how attractive the technical setup appears.
- **`FundValue`/`FundDate` data access:** Direct integration with TradeStation's fundamental data feed enables systematic use of earnings data within automated strategy logic — no manual data entry or separate data sources required.
- **Error-code validation:** All three fundamental data calls are validated independently. A single data retrieval failure suspends all trading activity until valid data is available, preventing entries based on incomplete or stale fundamental inputs.
- **Dual exit framework:** A fundamental exit (EPS deterioration on a new report) and a technical exit (six-month low) operate independently. The position closes on whichever signal fires first.
- **`This Bar on Close` exits:** Both exit conditions close the position on the bar that triggers them, providing the most timely available exit without requiring intrabar order generation.
- **`Commentary` for development:** Both versions include `Commentary` statements that display fundamental data values on the chart for bar-by-bar debugging and visual validation of fundamental data reads.

---

## Trade Psychology

EPS Momentum Long embodies a hybrid investment philosophy: **fundamental quality sets the playing field; technical momentum determines the timing.** Many systematic traders treat fundamental and technical analysis as separate domains — one for stock selection, one for execution. This strategy integrates both in a single rule set, requiring the company to be fundamentally improving *before* the technical entry is even considered.

The EPS filter addresses a common source of false signals in pure momentum strategies: a stock can break above a recent high for many reasons — short covering, market-wide rotation, speculative enthusiasm — without any underlying improvement in business performance. By requiring improving earnings as a precondition, the strategy only enters momentum moves that are supported by fundamental business improvement, filtering out moves driven purely by price action.

The exit logic reflects the strategy's dual nature with equal rigor. If the fundamental thesis fails — a new earnings report shows the business is deteriorating — the position exits regardless of price. And if the technical structure fails — price makes a new six-month low — the position exits regardless of what the next earnings report might say. Neither pillar alone can sustain the trade; both must remain intact.

The `StructuralLookback` exit is also a statement about time horizon. The strategy is not a swing trade targeting a specific price level — it is a position that holds as long as both the fundamental trend and the technical structure are intact. The six-month low threshold defines the outer boundary of acceptable technical deterioration: a stock that has made a new six-month low has lost the structural support that justifies holding it as a momentum position.

---

## Use Cases

**Instruments:** Individual stocks with quarterly earnings reporting — US equities are the primary target, as TradeStation's `"SBBF"` fundamental field is most reliably populated for US-listed companies. The strategy requires both price data and fundamental data to be available for the same instrument. Index futures, commodities, and FX do not have EPS data and cannot use this strategy.

**Timeframes:** Designed for weekly bars (`StructuralLookback = 26` = 26 weeks = ~6 months) or daily bars with adjusted lookback (`StructuralLookback = 130` for equivalent six-month reference). On shorter intraday timeframes, earnings reports are not meaningful signals — EPS data changes at most quarterly.

**Data dependencies:** The strategy requires:
1. TradeStation's fundamental data service to be active and properly licensed.
2. The instrument to have EPS data available under the `"SBBF"` field code.
3. Sufficient earnings history (at least two reports) for the comparison to be meaningful.

**Portfolio application:** Because the fundamental filter defines a high-quality subset of the investable universe, this strategy is well suited to running across a portfolio of individual stocks simultaneously — each instance filters independently, and only stocks with improving earnings qualify for entry at any given time.

**Research extensions:** Natural improvements for future versions include: year-over-year EPS comparison (current quarter vs same quarter last year, rather than sequential report comparison), analyst estimate beat/miss as an additional filter, and position sizing based on EPS growth rate magnitude rather than fixed share size.
