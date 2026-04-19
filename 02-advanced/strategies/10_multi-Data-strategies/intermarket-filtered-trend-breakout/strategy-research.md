# Intermarket Filtered Trend Breakout — Strategy Research

🇺🇸 English | 🇪🇸 [Español](strategy-research.es.md)

> This document complements the technical README with the macroeconomic reasoning behind the strategy's intermarket filter design. It explains why the three data feeds are chosen, how their relationships are encoded in the strategy, what the filters actually measure, and where the current implementation falls short of true statistical correlation. It is intended as a living research document — sections on regime examples include placeholders for charts to be added as empirical research progresses.

---

## 1. The Intermarket Thesis

Financial markets do not move in isolation. Equity indices, currencies, and bonds are all expressions of the same underlying macroeconomic forces — growth expectations, inflation, risk appetite, and capital flows. When these forces shift, they shift across all markets simultaneously, though not always at the same speed or magnitude.

The core thesis of this strategy is simple: **a trend in an equity index that is confirmed by aligned moves in the associated currency and bond markets is more likely to persist than a trend that occurs in isolation.** Conversely, a breakout in the primary market that contradicts the regime signaled by secondary markets is a lower-quality signal — one where the broader macro context is working against the trade.

This is not a new idea. Intermarket analysis has been a recognized discipline since at least John Murphy's foundational work in the 1990s, and the relationships between equities, bonds, and currencies are among the most studied in macro finance. What this strategy does is encode those relationships as computable filters — transforming qualitative macro reasoning into quantitative entry conditions.

The three-market structure reflects a deliberate hierarchy:

- **Data1** is where money is made or lost. It is the execution market.
- **Data2 and Data3** are context markets. They do not generate trades — they gate them.

A trend signal on Data1 that passes both context filters enters. One that fails either filter does not. The strategy's edge, if it exists, comes from the incremental quality improvement that context confirmation provides over raw trend-breakout signals.

---

## 2. The Three Markets — Roles and Relationships

### Data1 — The Primary Market (Equity Index)

Equity index futures — DAX, NQ, ES, and similar instruments — represent the aggregate expected earnings and risk appetite of a broad market. They are the most direct expression of investor sentiment about economic growth and corporate profitability.

Equity indices are chosen as the primary market for three reasons. First, they tend to produce sustained directional trends driven by macro regime changes — the kind of moves that trend-following strategies are designed to capture. Second, they are highly liquid, ensuring that stop and limit orders fill near their quoted prices. Third, their relationship with currencies and bonds is well-documented and economically intuitive, making the intermarket filter design tractable.

The strategy operates on Data1 for entries, exits, trend detection, and breakout levels. Everything in the signal engine refers exclusively to Data1.

### Data2 — The Currency Market (EURUSD)

Currency pairs encode information about relative economic strength, capital flows, and global risk sentiment in a way that equity prices alone do not.

**Why EURUSD for DAX:** The DAX is a German equity index, and Germany is the Eurozone's largest economy. When the euro strengthens against the dollar, it typically reflects either improving Eurozone economic fundamentals or a risk-on environment where capital flows toward European assets. A weakening euro often reflects risk-off sentiment, Eurozone economic stress, or dollar strength driven by safe-haven demand. The relationship between EURUSD and DAX is not fixed — it can invert during specific macro episodes — but as a general regime filter it captures whether the currency market is telling a consistent macro story with the equity market.

**Why a currency filter for NQ:** The Nasdaq 100 has a different currency dynamic. US large-cap technology companies generate significant international revenue, so a strong dollar can weigh on earnings expectations even as domestic growth remains robust. More importantly, EURUSD serves as a proxy for global risk appetite — when the euro rallies against the dollar, it often reflects a broader risk-on environment that supports equity markets globally, including US technology.

The filter encodes this relationship through a simple comparison: is the currency above or below its moving average? This is a directional state, not a magnitude measurement. The assumption is that the direction of the currency trend — not its level or rate of change — is the relevant signal.

```pascal
// CurrencyCorrelation = -1: DAX tends to move opposite to EURUSD strength
// Filter passes for long entries when EURUSD is BELOW its MA
// (weak euro = risk-off = counterintuitively, this is the condition being filtered)
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

> **Chart placeholder:** EURUSD vs. DAX daily returns, 2018–2024. Highlight periods where the two moved in opposite directions (negative correlation regime) vs. periods where they moved together (correlation breakdown).

### Data3 — The Bond Market (Bund / US20Y)

Before discussing the bond market's role as a filter, one mechanical relationship is essential: **bond prices and yields always move in opposite directions**. A bond pays a fixed amount at maturity. If its market price rises — because many investors want to buy it — the effective return for a new buyer falls, since they are paying more for the same fixed payment. If its price falls, the effective return rises. This is not an empirical tendency; it is a mathematical identity. When market commentators say "yields fell," they mean bond prices rose, and vice versa. Throughout this document, references to bonds being "above their MA" mean bond *prices* are elevated — which corresponds to low yields, typically associated with risk-off or growth-pessimism regimes. References to bonds being "below their MA" mean prices are depressed — yields are elevated, typically reflecting growth expectations, inflation concerns, or a rate-hiking cycle.

Bond markets encode expectations about interest rates, inflation, and macroeconomic risk in a way that is often more forward-looking than equity markets. Bond prices move inversely to yields: when yields rise, bond prices fall, and vice versa.

**The equity-bond relationship:** In standard macro theory, equities and bonds tend to be negatively correlated during risk-off episodes. When investors fear a recession or a market shock, they sell equities and buy bonds (flight to safety), pushing equity prices down and bond prices up. During risk-on environments, capital flows from bonds back into equities, pushing equity prices up and bond prices down.

This is the intuition behind the default `BondCorrelation = -1`: when bond prices are below their moving average (bonds falling, yields rising), the macro environment is typically one of growth expectations or inflation concern — conditions that can be either supportive or destructive for equities depending on the rate cycle phase. When bonds are above their MA (bonds rising, yields falling), risk-off sentiment may be dominant.

**Why this relationship is not stable:** The equity-bond correlation regime has shifted significantly across market history. During the 2000–2020 period, the relationship was reliably negative — the classic 60/40 portfolio benefited from this. During 2022, when central banks aggressively raised rates to fight inflation, both equities and bonds fell simultaneously, breaking the traditional hedge. A filter based on the assumption of negative correlation would have been systematically wrong during this period. This is discussed further in Section 5.

```pascal
// BondCorrelation = -1: equity index tends to move opposite to bond prices
// Filter passes for long entries when bond market is BELOW its MA
// (falling bonds = rising yields = growth/inflation regime, not pure risk-off)
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, FilterMALength));
```

> **Chart placeholder:** Bund futures (or US20Y) vs. DAX (or NQ) daily returns, 2015–2024. Mark the 2022 period where both fell simultaneously. Overlay the 50-period MA on each to show when the bond filter would have been active vs. inactive.

---

## 3. Correlation Directions — Economic Logic

The strategy encodes each intermarket relationship as one of three states via the correlation inputs:

| Input value | Meaning | Long filter condition | Short filter condition |
|---|---|---|---|
| `1` (positive) | Secondary market trends with primary | Data2/3 above MA | Data2/3 below MA |
| `-1` (negative/inverse) | Secondary market trends against primary | Data2/3 below MA | Data2/3 above MA |
| `0` (disabled) | Filter ignored | Always passes | Always passes |

### Why `-1` is the default for both

The default configuration (`CurrencyCorrelation = -1`, `BondCorrelation = -1`) encodes the classical macro relationships for European equity indices in a normal macro environment:

- **DAX / EURUSD inverse:** When the euro weakens (EURUSD below MA), it often reflects ECB dovishness or Eurozone stress — conditions where European equities can rally on cheaper export competitiveness or monetary stimulus expectations. A stronger euro can reflect EUR strength that compresses earnings for export-heavy DAX companies.
- **DAX / Bund inverse:** When Bund prices fall (yields rise, Bund below MA), it reflects growth or inflation expectations — a macro environment where equities can trend upward. When Bund prices rise (yields fall, flight to safety), risk-off sentiment typically suppresses equity upside.

These are starting hypotheses, not universal laws. Before deploying the strategy on any specific instrument pair, the historical correlation direction should be empirically verified on the target data.

### When to use `1` (positive correlation)

Some instrument pairs move in the same direction during normal regimes. For example, commodity currencies (AUD, CAD) tend to move with commodity-linked equity indices. If the primary market is a resource-sector index, a positive correlation with its associated currency may be more appropriate than an inverse one.

### When to use `0` (filter disabled)

Disabling a filter serves two purposes. First, it is the correct setting when the economic relationship between the primary market and a secondary market is unclear, unstable, or has not been empirically validated. Second, it enables baseline testing: running the strategy with both filters disabled reveals the pure trend-breakout edge, against which the filtered version can be compared to quantify the incremental value of each filter.

---

## 4. How the Strategy Encodes This — The Filter Logic

The filter logic translates the qualitative intermarket relationships into computable boolean conditions. Understanding the translation is essential for interpreting what the strategy is actually doing on each bar.

### The full filter construction

```pascal
{--- Currency filter for long entries ---}
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));

{--- Bond filter for long entries ---}
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation =  1 and Close of Data3 > Average(Close of Data3, FilterMALength))
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, FilterMALength));

{--- Combined filter ---}
LongFilterPassed = CurrencyLongFilter and BondLongFilter;
```

### What each condition means in plain language

With the default settings (`CurrencyCorrelation = -1`, `BondCorrelation = -1`), `LongFilterPassed = True` when:

1. EURUSD is below its `FilterMALength`-period moving average **and**
2. Bund (or US20Y) is below its `FilterMALength`-period moving average

In macro terms: the currency market is signaling euro weakness (potentially risk-off or ECB dovishness) **and** the bond market is signaling falling bond prices (rising yields, growth or inflation expectations). Both secondary markets are in a state consistent with a potential equity uptrend on the primary market.

### The short filter is the logical mirror

```pascal
CurrencyShortFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 < Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 > Average(Close of Data2, FilterMALength));
```

For short entries with `CurrencyCorrelation = -1`, the short filter passes when EURUSD is **above** its MA — the mirror of the long condition. This means that when `LongFilterPassed = True`, `ShortFilterPassed = False` for the currency component, and vice versa. The filters are not just independent — they are structurally opposed. When the macro context favors longs, it simultaneously blocks shorts.

### The `FilterMALength` parameter

Both secondary market filters use `FilterMALength` as the MA period, independent of `SlowMALength` used on the primary market. This is a deliberate v3 improvement: Data2 and Data3 may operate on different bar intervals than Data1, and the same numeric period represents different calendar durations on each feed. A `FilterMALength = 20` on a daily bond chart is approximately one trading month; the same value on a 4-hour currency chart is approximately two weeks. The parameter should be set with awareness of what it represents in calendar time on each secondary feed.

---

## 5. What the Strategy Actually Measures — and What It Doesn't

This is the most important section for any researcher or practitioner working with this strategy. The intermarket filters are a useful approximation of macro regime confirmation, but they are not a measurement of statistical correlation. Understanding the gap between the two is essential for setting realistic expectations.

### What the filters measure: directional alignment

The filter condition `Close of Data2 < Average(Close of Data2, FilterMALength)` answers a single binary question: **is this market currently trending below its recent average?** It says nothing about:

- How strongly the secondary market is trending
- Whether the secondary market's moves are statistically related to the primary market's moves
- Whether the relationship between the two markets has been stable or has recently broken down
- The magnitude of the secondary market's deviation from its average

This is a directional state filter, not a correlation measurement. Two markets can both be below their moving averages while being completely uncorrelated with each other — they simply happen to be in the same directional regime.

### What the filters do not measure: statistical correlation

True intermarket correlation requires measuring the statistical relationship between the **returns** (or price changes) of two markets over a rolling window. A rolling correlation coefficient between Data1 and Data2 returns over the last N periods would answer: *how consistently have these two markets moved together (or in opposite directions) recently?*

A z-score of the rolling correlation would additionally answer: *is the current correlation significantly different from its historical average?* A correlation that is unusually high or unusually low relative to its own history is a more informative signal than a simple above/below MA comparison.

The current implementation measures none of this. The following pseudocode illustrates what a more statistically rigorous filter would require:

```
// Conceptual — not current EasyLanguage implementation
RollingCorrelation = Correlation(
    Returns(Close of Data1, 1),    // Daily returns of primary market
    Returns(Close of Data2, 1),    // Daily returns of currency
    CorrelationWindow              // Rolling window, e.g. 60 bars
);

CorrelationZScore = (RollingCorrelation - Average(RollingCorrelation, ZScoreWindow))
                   / StdDev(RollingCorrelation, ZScoreWindow);

// Filter passes only when correlation is significantly aligned with expected direction
// AND the correlation itself is statistically stable (z-score within normal range)
CurrencyLongFilter = (CurrencyCorrelation = -1 and RollingCorrelation < -CorrelationThreshold)
                     and AbsValue(CorrelationZScore) < ZScoreThreshold;
```

This would filter out periods where the expected correlation has broken down — precisely the periods where the current implementation is most likely to generate false signals.

### Practical implications of the gap

The distance between "directional alignment" and "statistical correlation" has three concrete consequences for strategy performance:

**1. Correlation regime changes are invisible to the current filter.** During 2022, the equity-bond correlation turned strongly positive — both fell together as rates rose. A `BondCorrelation = -1` filter would have continued to pass long entries when bonds were below their MA, precisely the environment where the traditional relationship was broken. The filter would not have detected the regime change.

**2. Short-term noise passes the filter.** A secondary market can spend a few bars below its MA due to random fluctuation rather than genuine directional commitment. The current filter treats both cases identically. A statistical correlation filter with a rolling window would be more resistant to short-term noise because it requires the relationship to have been consistent over the entire window.

**3. The filter provides no information about correlation strength.** Whether Data2 is 0.1% below its MA or 5% below its MA, the filter result is identical: `True`. A z-score based filter would weight significant deviations more heavily than marginal ones.

---

## 6. Regime Examples — Historical Episodes

The following episodes illustrate how the three-market relationship behaved during significant macro regimes. For each episode, a regime table shows the approximate directional state of each market and whether the default filter configuration (`CurrencyCorrelation = -1`, `BondCorrelation = -1`) would have permitted or blocked long entries.

### Episode 1 — Global Financial Crisis (2008–2009)

**Macro narrative:** The collapse of Lehman Brothers in September 2008 triggered a global risk-off episode of exceptional severity. Equity markets collapsed globally. Capital fled to safe-haven assets — US Treasuries, German Bunds, and the US dollar. EURUSD fell sharply as dollar demand surged. Bond prices rose (yields fell) as investors bought safety.

| Market | Direction | vs. MA | Long filter contribution |
|---|---|---|---|
| DAX (Data1) | Sharply down | Below | — (trend signal: short only) |
| EURUSD (Data2) | Down (dollar strength) | Below | `CurrencyLongFilter = True` (inverse corr.) |
| Bund (Data3) | Up (flight to safety) | Above | `BondLongFilter = False` (inverse corr.) |
| **LongFilterPassed** | — | — | **False** |

The bond filter correctly blocked long entries during the risk-off collapse. Even if the currency filter passed (EURUSD below MA), the bond filter failed — Bund prices rising (above MA) signaled flight to safety, not a growth regime. The combined filter would have prevented long entries during the worst of the drawdown.

**What the filter missed:** Short entries on DAX would have been consistent with the regime. `ShortFilterPassed` would have been `True` when EURUSD was above MA (dollar weakening) — but EURUSD was falling, not rising, so the short filter would also have been inconsistent with the actual macro dynamics during the acute phase.

> **Chart placeholder:** DAX, EURUSD, Bund daily prices with 50-period MA overlay, September 2008 – March 2009. Mark Lehman collapse date. Show filter state (pass/fail) for each market.

---

### Episode 2 — European Sovereign Debt Crisis (2011–2012)

**Macro narrative:** Concerns about Greek, Italian, and Spanish sovereign debt created a prolonged risk-off episode specific to the Eurozone. DAX fell significantly. EURUSD weakened as Eurozone breakup risk was priced in. Bund prices rallied strongly as Germany's bonds became the Eurozone safe haven — German yields fell to historic lows while peripheral yields surged.

| Market | Direction | vs. MA | Long filter contribution |
|---|---|---|---|
| DAX (Data1) | Down then recovery | Mixed | — |
| EURUSD (Data2) | Down (euro stress) | Below | `CurrencyLongFilter = True` |
| Bund (Data3) | Up (Eurozone safe haven) | Above | `BondLongFilter = False` |
| **LongFilterPassed** | — | — | **False during stress, True on recovery** |

This episode illustrates a specific dynamic of the DAX/Bund relationship: during Eurozone-specific stress, Bund and DAX can decorrelate from their typical relationship. Bund rallied not because of global risk-off (which would also weaken equities) but because it was the Eurozone's internal safe haven — even as DAX fell, the Bund filter blocked longs correctly.

**Draghi's "whatever it takes" (July 2012):** When ECB President Draghi committed to preserving the euro, both DAX and EURUSD rallied while Bund prices fell (yields rose slightly as safe-haven demand receded). This is the regime the default filter is designed to capture — currency and bond both aligned for equity longs.

> **Chart placeholder:** DAX, EURUSD, Bund daily prices with 50-period MA overlay, January 2011 – December 2012. Mark "whatever it takes" speech. Show filter state transition from blocked to passing.

---

### Episode 3 — COVID Crash and Recovery (February–August 2020)

**Macro narrative:** The COVID-19 pandemic triggered the fastest equity market crash in history (February–March 2020) followed by an equally rapid recovery driven by unprecedented fiscal and monetary stimulus. The crash phase was a classic risk-off episode; the recovery phase was a risk-on regime supported by central bank intervention.

| Phase | DAX | EURUSD | Bund | LongFilterPassed |
|---|---|---|---|---|
| Crash (Feb–Mar 2020) | Sharply down | Mixed (dollar spike then reversal) | Up (flight to safety) | **False** |
| Recovery (Apr–Aug 2020) | Sharply up | Up (euro strengthening) | Below then above MA | **Mixed** |

The crash phase correctly blocked long entries. The recovery phase presents a more complex picture: EURUSD strengthened significantly (euro above MA) — with `CurrencyCorrelation = -1`, this would have blocked long entries during the recovery. The strong euro reflected dollar weakness and risk-on capital flows to Europe, which was actually consistent with DAX upside — but the filter, configured for inverse correlation, would have interpreted euro strength as a negative signal.

This illustrates a key limitation: the default `-1` correlation assumption can produce false negatives during risk-on recoveries where currency and equity move in the same direction.

> **Chart placeholder:** DAX, EURUSD, Bund daily prices with 50-period MA overlay, January 2020 – September 2020. Mark crash low (March 23) and recovery. Show filter state for each phase.

---

### Episode 4 — Rate Hike Cycle (2022)

**Macro narrative:** In 2022, the Federal Reserve and ECB raised interest rates aggressively to combat post-pandemic inflation. This created an unusual macro regime: both equities and bonds fell simultaneously — the traditional negative equity-bond correlation broke down completely. DAX fell ~20%. Bund prices collapsed (yields surged). EURUSD fell sharply (euro weakness on ECB lag vs. Fed).

| Market | Direction | vs. MA | Long filter contribution |
|---|---|---|---|
| DAX (Data1) | Down | Below | — (trend signal: short only) |
| EURUSD (Data2) | Down sharply | Below | `CurrencyLongFilter = True` (inverse corr.) |
| Bund (Data3) | Down sharply | Below | `BondLongFilter = True` (inverse corr.) |
| **LongFilterPassed** | — | — | **True** |

This is the most dangerous episode for this strategy's default configuration. Both secondary markets were below their MAs — the filter passed for long entries — but the macro regime was unambiguously bearish for equities. The traditional inverse equity-bond correlation had broken: bonds and equities were falling together, not in the classic risk-off pattern.

A strategy running with `CurrencyCorrelation = -1` and `BondCorrelation = -1` during 2022 would have had its filters passing for long entries precisely when the primary market was in a sustained downtrend. The trend signal (`FastMA < SlowMA` for DAX) would have blocked long entries — but the filter would not have added the protection it was designed to provide.

**This episode is the clearest empirical argument for statistical correlation measurement over directional state filters.** A rolling correlation filter would have detected that the equity-bond relationship had shifted from negative to positive and either disabled the bond filter or inverted its signal.

> **Chart placeholder:** DAX, EURUSD, Bund daily prices with 50-period MA overlay, January 2022 – December 2022. Show both secondary markets below MA (filter passing) while DAX trends down. Overlay rolling 60-day correlation between DAX and Bund returns to illustrate the regime shift.

### A Pattern Across Episodes

Reviewing the four episodes together reveals a structural tendency of the current filter design: **when the traditional intermarket correlation breaks down, the filters tend to block both directions simultaneously**, leaving the strategy inactive during periods where clear, tradeable trends existed on the primary market. In 2008, the dollar strength that accompanied the equity collapse blocked short entries via the currency filter. In 2022, the simultaneous fall of bonds and equities passed the long filter while the trend signal blocked longs — and the mirror condition blocked shorts. This is not a failure of the filter logic itself; it is a consequence of using static correlation assumptions in a dynamic macro environment. It is the clearest argument for the statistical correlation approach outlined in Section 7.

---

## 7. Toward a More Rigorous Intermarket Filter — Considerations for a Future v4

The limitations identified in Section 5 and illustrated by the 2022 episode point toward a more statistically grounded filter design. A v4 would address three specific weaknesses of the current implementation.

### 7.1 Rolling Correlation Filter

Replace the MA comparison with a rolling correlation between returns:

```
// Conceptual design — requires custom EasyLanguage function or external data feed
RollingCorr_D2 = RollingCorrelation(
    DailyReturn(Close of Data1),
    DailyReturn(Close of Data2),
    CorrelationWindow    // e.g. 60 bars
);

// Filter passes only when correlation direction matches the expected regime
// AND the correlation is statistically meaningful (not near zero)
CurrencyLongFilter_v4 =
    (CurrencyCorrelation = -1 and RollingCorr_D2 < -CorrelationThreshold)  // e.g. < -0.3
    or (CurrencyCorrelation =  1 and RollingCorr_D2 >  CorrelationThreshold)
    or (CurrencyCorrelation =  0);
```

`CorrelationThreshold` would be a new parameter (e.g. `0.3`) requiring the correlation to be meaningfully negative or positive before the filter activates. A correlation near zero would disable the filter, equivalent to `CurrencyCorrelation = 0` — the relationship is not currently informative.

### 7.2 Correlation Z-Score for Regime Change Detection

A rolling correlation alone does not detect when the correlation has shifted from its historical norm. A z-score of the rolling correlation would:

```
// Conceptual
CorrelationZScore = (RollingCorr_D2 - Average(RollingCorr_D2, ZScoreWindow))
                   / StdDev(RollingCorr_D2, ZScoreWindow);

// Disable filter when correlation is in an abnormal regime
// (z-score beyond ±2 suggests the relationship has structurally shifted)
CorrelationStable = AbsValue(CorrelationZScore) < 2.0;

CurrencyLongFilter_v4 = CurrencyLongFilter_v4 and CorrelationStable;
```

During 2022, the equity-bond z-score would have spiked significantly as the correlation inverted — this condition would have disabled the bond filter rather than allowing it to pass in a broken regime.

### 7.3 Dynamic Correlation Direction

The most ambitious v4 improvement would eliminate the static `CurrencyCorrelation` and `BondCorrelation` inputs entirely and replace them with dynamically detected correlation direction:

```
// Conceptual
DetectedCorrelation_D2 = Sign(RollingCorr_D2);  // +1 or -1 based on current rolling correlation

CurrencyLongFilter_v4 =
    (DetectedCorrelation_D2 =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (DetectedCorrelation_D2 = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

This would make the strategy fully adaptive to changing intermarket regimes without requiring manual parameter updates. The trade-off is complexity: a dynamically detected correlation introduces its own noise and lag, and the strategy's behavior becomes harder to reason about during transitions.

### Implementation note for EasyLanguage

Native EasyLanguage does not include a built-in rolling correlation function between two data feeds. Implementing v4 would require either a custom `Function` that computes the Pearson correlation coefficient over a rolling window from two price series, or access to a pre-computed correlation series via an external data feed or indicator. This is a non-trivial but feasible extension — the mathematical foundation is straightforward, and the implementation complexity is primarily in the EasyLanguage function design rather than the strategy logic itself.

---

*This document is a living research reference. Chart placeholders should be replaced with actual price charts from TradeStation or TradingView as empirical research on specific instrument configurations progresses. The regime examples are illustrative of general macro dynamics and should be verified against actual backtest results on the target instrument before drawing trading conclusions.*
