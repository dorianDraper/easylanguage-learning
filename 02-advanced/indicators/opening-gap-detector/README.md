# Opening Gap Detector — v1.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## System Description

Opening Gap Detector is a chart indicator that provides a visual representation of the opening gap detection logic shared by the Opening Gap strategy family — Gap Down, Gap Up, and Bidirectional. Rather than inferring gap activity from trade entries and exits after the fact, the indicator draws the detection geometry directly on the price chart: threshold levels at session end, gap magnitude lines at the open, and labeled annotations identifying each qualifying gap and its direction.

The indicator mirrors the detection logic of the Bidirectional strategy exactly — `Low` and `High` as fixed reference prices, a single `GapTest` threshold — making it a faithful visual companion for all three strategies without requiring parameter synchronization beyond `GapTest`.

---

## Core Mechanics

### 1. Threshold Lines — Session End Block

```pascal
If Time = SessionEndTime(1, 1) Then
Begin
    // Lower threshold — Gap Down entry level
    Value1 = TL_New(Date[1], Time[1], Low - GapTest, Date, Time, Low - GapTest);
    TL_SetColor(Value1, Blue);
    Value2 = Text_New(Date[1], Time[1], Low - GapTest, NumToStr(Low - GapTest, 2) + " ");
    Text_SetStyle(Value2, 1, 2);
    Text_SetColor(Value2, Blue);

    // Upper threshold — Gap Up entry level
    Value3 = TL_New(Date[1], Time[1], High + GapTest, Date, Time, High + GapTest);
    TL_SetColor(Value3, Green);
    Value4 = Text_New(Date[1], Time[1], High + GapTest, NumToStr(High + GapTest, 2) + " ");
    Text_SetStyle(Value4, 1, 2);
    Text_SetColor(Value4, Green);
End;
```

This block executes on the last bar of each session — the bar whose `Time` equals `SessionEndTime(1, 1)`. At that moment, `Low` and `High` are the completed session's low and high, and `GapTest` is the current threshold value. Two horizontal lines are drawn from that bar forward into the next session:

- **Blue line at `Low - GapTest`:** The minimum level the next session's open must breach downward for a Gap Down to qualify.
- **Green line at `High + GapTest`:** The minimum level the next session's open must breach upward for a Gap Up to qualify.

Both lines are labeled with their exact price level, right-aligned to the line's starting point. This gives the trader a forward-looking visual reference before the next session opens — the two lines define the "qualification zone" boundaries for the upcoming gap detection.

`Value1`–`Value4` are EasyLanguage's general-purpose handle variables. The upper threshold uses `Value3` and `Value4` rather than reusing `Value1` and `Value2` — reusing them within the same block would overwrite the handles before `TL_SetColor` could apply the color to the first pair of objects.

### 2. Gap Down Detection — First Bar of New Session

```pascal
If Date <> Date[1] and Open < Low[1] - GapTest[1] Then
Begin
    Value1 = TL_New(Date[1], Time[1], Low[1], Date[1], Time[1], Open);
    TL_SetColor(Value1, Blue);
    Value1 = TL_New(Date[1], Time[1], Open, Date, Time, Open);
    TL_SetColor(Value1, Blue);
    Gap = Low[1] - Open;
    Value1 = Text_New(Date[1], Time[1], Open, NumToStr(Gap, 2) + " ");
    Text_SetStyle(Value1, 1, 2);
    Text_SetColor(Value1, Blue);
    Value1 = Text_New(Date, Time, High, " Gap Down ");
    Text_SetStyle(Value1, 2, 1);
    Text_SetColor(Value1, DarkCyan);
End;
```

`Date <> Date[1]` identifies the first bar of a new session — the bar where `Date` has changed from the previous bar. At this point, `Low[1]` and `GapTest[1]` are the previous session's values, and `Open` is the current bar's opening price. The condition `Open < Low[1] - GapTest[1]` is the exact Gap Down qualification test.

When a Gap Down qualifies, four drawing objects are created:

- **Vertical blue line** from `Low[1]` down to `Open` at the session boundary — the gap's vertical extent.
- **Horizontal blue line** at the `Open` level extending into the current session — the entry price reference and gap-fill target origin.
- **Blue text label** at the open level showing the gap magnitude in points (`Gap = Low[1] - Open`).
- **DarkCyan "Gap Down" label** positioned at the `High` of the first bar — above the open, providing a clear directional annotation without overlapping the gap geometry.

The label placement at `High` is intentional: since the open is below the previous low, placing the label at the bar's high ensures it appears above the open, in the visible price space above the gap, rather than inside the gap itself.

### 3. Gap Up Detection — First Bar of New Session

```pascal
If Date <> Date[1] and Open > High[1] + GapTest[1] Then
Begin
    Value1 = TL_New(Date[1], Time[1], High[1], Date[1], Time[1], Open);
    TL_SetColor(Value1, Green);
    Value1 = TL_New(Date[1], Time[1], Open, Date, Time, Open);
    TL_SetColor(Value1, Green);
    Gap = Open - High[1];
    Value1 = Text_New(Date[1], Time[1], Open, NumToStr(Gap, 2) + " ");
    Text_SetStyle(Value1, 1, 2);
    Text_SetColor(Value1, Green);
    Value1 = Text_New(Date, Time, Low, " Gap Up ");
    Text_SetStyle(Value1, 2, 1);
    Text_SetColor(Value1, DarkGreen);
End;
```

Structurally symmetric to the Gap Down block. `Open > High[1] + GapTest[1]` is the Gap Up qualification test. The drawing objects mirror the Gap Down set with two differences:

- **Color scheme is green / dark green** throughout, distinguishing Gap Up events visually from Gap Down events.
- **"Gap Up" label is positioned at `Low`** of the first bar — below the open, in the visible price space below the gap, symmetric to the Gap Down label placement at `High`.

`Gap = Open - High[1]` captures the upward gap magnitude with the correct sign convention: a positive value representing how far above the prior high the session opened.

### 4. Detection Approach — End-of-Session vs. Start-of-Session

The indicator uses a different detection moment than the strategies, and understanding the distinction is important for correct interpretation:

- **Strategies** detect the gap on the **last bar of the previous session** using `Open of Next Bar` — they read tomorrow's open before that bar begins, place the entry order, and fill at that same open.
- **Indicator** detects the gap on the **first bar of the new session** using `Date <> Date[1]` — it reads the open after the new session's first bar has arrived.

Both access the same price: the new session's opening price. The difference is the bar on which the logic executes. The strategies fire one bar earlier (last bar of old session); the indicator fires one bar later (first bar of new session). The result is identical — same gap detected, same magnitude, same qualification — but the drawing objects are anchored to the first bar of the new session rather than the last bar of the previous one.

---

## Architecture

```
Last bar of session (Time = SessionEndTime)
    └─ Draw threshold lines for next session
           Blue:  Low  - GapTest  → Gap Down qualification level
           Green: High + GapTest  → Gap Up qualification level

First bar of next session (Date <> Date[1])
    ├─ Open < Low[1]  - GapTest[1] ?
    │       └─ YES → Draw Gap Down geometry (blue)
    │                  Vertical line: Low[1] → Open
    │                  Horizontal line: Open level
    │                  Label: gap magnitude
    │                  Label: "Gap Down"
    │
    └─ Open > High[1] + GapTest[1] ?
            └─ YES → Draw Gap Up geometry (green)
                       Vertical line: High[1] → Open
                       Horizontal line: Open level
                       Label: gap magnitude
                       Label: "Gap Up"
```

Both gap conditions are independent — they execute as separate `If` blocks on the first bar of each session. In practice only one can be true at any given open (price cannot simultaneously be below `Low - GapTest` and above `High + GapTest`), but the architecture does not enforce mutual exclusion explicitly, consistent with the Bidirectional strategy's approach.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Volatility-adaptive threshold for gap qualification. Gaps must exceed this value to trigger visual detection. Matches the default used by all three Opening Gap strategies. |

**Single-parameter design:** `GapPrice` is not exposed as an input. The indicator hardcodes `Low` as the Gap Down reference and `High` as the Gap Up reference — the same approach used by the Bidirectional strategy. This keeps the parameter surface at a single input while preserving correct gap measurement for both directions. If gap-from-close detection is needed, the reference prices would need to be changed directly in the code, as in the Bidirectional strategy.

**Parameter alignment with the strategies:** For the indicator's threshold lines and gap annotations to match the strategies' entry conditions exactly, `GapTest` must be set to the same value used in the strategy. The default `Median(Range, 50)[1]` matches all three strategies' defaults. If a strategy is run with a custom `GapTest` value, the indicator should be updated to match.

---

## Interpretation Scenarios

### Scenario A — Gap Down Detected

- Previous session closes. Last bar: `Low = 3,975`, `High = 3,995`, `GapTest = 10 pts`.
- Threshold lines drawn: blue at `3,965` (Gap Down level), green at `4,005` (Gap Up level).
- Next session opens at `3,958`. `3,958 < 3,975 − 10 = 3,965`. **Gap Down qualifies.**
- Vertical blue line drawn from `3,975` down to `3,958`.
- Horizontal blue line drawn at `3,958`.
- Label: `17.00` (gap magnitude). Label: `Gap Down`.
- The Gap Down and Bidirectional strategies enter long at `3,958`. The indicator's horizontal line at `3,958` marks the entry level and gap-fill target origin.

### Scenario B — Gap Up Detected

- Previous session closes. `High = 3,995`, `Low = 3,975`, `GapTest = 10 pts`.
- Threshold lines drawn: blue at `3,965`, green at `4,005`.
- Next session opens at `4,014`. `4,014 > 3,995 + 10 = 4,005`. **Gap Up qualifies.**
- Vertical green line drawn from `3,995` up to `4,014`.
- Horizontal green line drawn at `4,014`.
- Label: `19.00`. Label: `Gap Up`.
- The Gap Up and Bidirectional strategies enter short at `4,014`.

### Scenario C — No Qualifying Gap

- Next session opens at `3,978`. `3,978 > 3,965` and `3,978 < 4,005`.
- Neither condition qualifies. No gap geometry drawn. Only the threshold lines from the previous session end are visible.
- The strategies have no entry. The indicator correctly shows a quiet open within the prior session's range.

### Scenario D — Multiple Sessions, Threshold Line Continuity

- Over three consecutive sessions, threshold lines are drawn at each session end.
- On session 2, a Gap Down is detected and annotated. On sessions 1 and 3, no gap qualifies.
- The chart shows threshold lines for all three sessions, with gap geometry only on session 2. This gives a clear historical record of which sessions produced qualifying gaps and which did not.

---

## Key Features

- **Forward-looking threshold lines:** Drawn at session end, before the next open, giving the trader advance visibility of the exact price levels that would qualify a gap in the upcoming session.
- **Symmetric color coding:** Gap Down events are blue / dark cyan throughout; Gap Up events are green / dark green. Colors are consistent across threshold lines, gap geometry, magnitude labels, and direction labels.
- **Gap magnitude annotation:** The exact gap size in points is labeled at the open level for every qualifying gap, providing immediate quantitative context without requiring manual measurement.
- **Hardcoded reference prices:** `Low` for Gap Down, `High` for Gap Up — consistent with the Bidirectional strategy's architecture and requiring no parameter synchronization beyond `GapTest`.
- **`Value3`/`Value4` for upper threshold:** Separate handle variables for the Gap Up threshold lines prevent handle overwrite within the session-end block, ensuring both threshold lines are colored correctly.
- **Label positioning by direction:** Gap Down labels at bar `High`, Gap Up labels at bar `Low` — each label appears in the price space on the opposite side of the gap, avoiding overlap with the gap geometry itself.
- **Independent detection blocks:** Gap Down and Gap Up are evaluated in separate `If` blocks. No mutual exclusion is enforced in code — the geometry of price makes simultaneous qualification impossible in practice.

---

## Limitations

### Single `GapTest` Reference Price — No Gap-from-Close Detection

The indicator hardcodes `Low` and `High` as reference prices, matching the Bidirectional strategy's design. The directional strategies (Gap Down v1/v2, Gap Up v1) expose `GapPrice` as a configurable input that can be set to `Close` for gap-from-close detection. The indicator does not support this variant — it will only detect gaps that break beyond the prior session's high or low. Users running the directional strategies with `GapPrice = Close` will find a mismatch between the indicator's threshold lines and the strategies' actual entry conditions.

### Drawing Objects on Historical Bars

Trend lines and text objects created with `TL_New` and `Text_New` are persistent drawing objects — they are added to the chart on each calculation pass and accumulate over the chart's history. On a chart with many years of data, this can generate a large number of objects, potentially affecting chart rendering performance. This is a general EasyLanguage ShowMe/indicator behavior and not specific to this indicator, but it is worth noting for users applying it to long historical data sets.

### Real-Time Recalculation Behavior

EasyLanguage indicators recalculate on every tick of the last bar. The threshold lines (session-end block) are redrawn on every tick of the last bar of each session. The gap detection blocks (first-bar-of-session) redraw on every tick of the first bar of the new session. In practice this means drawing objects may be recreated multiple times per bar on the live chart — a normal EasyLanguage behavior but one that can occasionally produce visual artifacts if the chart is updated very rapidly at session boundaries.

---

## Use Cases

**Visual validation of strategy entries:** Apply the indicator to the same chart where a Gap strategy is running. The threshold lines show in advance whether the next open is likely to qualify; the gap geometry confirms which entries the strategy will have taken. This is particularly useful during strategy review sessions to verify that detected gaps align with actual trade entries.

**Gap frequency analysis:** With the indicator applied to a historical chart, the distribution of qualifying gaps over time becomes immediately visible — how often gaps occur, in which direction, and of what magnitude. This supports the initial assessment of whether the gap-fade edge is present in a given instrument or timeframe before running a full backtest.

**Session open monitoring:** During live trading, the threshold lines drawn at the previous session's close give an immediate visual reference for the upcoming open. A trader can see at a glance how far price would need to gap to trigger a strategy entry, without recalculating manually.

**Multi-instrument deployment:** The indicator can be applied to multiple instruments simultaneously. Since the threshold adapts to each instrument's own `Median(Range, 50)[1]`, the qualification criteria are automatically scaled to each instrument's volatility — a gap that qualifies on ES may not qualify on a less volatile instrument using the same indicator instance.

---

## Relationship to the Opening Gap Strategy Family

The indicator is designed as a visual companion to three strategies that share the same core detection logic:

| Strategy | Direction | Reference prices | `GapTest` default |
|---|---|---|---|
| Opening Gap Down v1 / v2 | Long only | `GapPrice` input (default `Low`) | `Median(Range, 50)[1]` |
| Opening Gap Up v1 | Short only | `GapPrice` input (default `High`) | `Median(Range, 50)[1]` |
| Opening Gap Bidirectional v1 | Both | Hardcoded `Low` / `High` | `Median(Range, 50)[1]` |
| **Opening Gap Detector v1** | Visual only | Hardcoded `Low` / `High` | `Median(Range, 50)[1]` |

The indicator's detection logic matches the Bidirectional strategy exactly. For the directional strategies, the match holds as long as `GapPrice` is left at its default (`Low` for Gap Down, `High` for Gap Up). If `GapPrice` is changed in a directional strategy, the indicator's threshold lines and gap annotations will no longer correspond to that strategy's entry conditions.
