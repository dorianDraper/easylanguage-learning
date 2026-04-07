# Password Protection — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## System Description

Password Protection is a developer infrastructure component that demonstrates how to implement multi-layer license protection in EasyLanguage indicators and strategies. It is not a trading indicator — it is a template for protecting intellectual property when distributing EasyLanguage code commercially. The component restricts execution to a specific trading environment (symbol and bar type), validates a password-based license key, and supports time-windowed license expiration with an overlap period for seamless license renewal.

The three protection layers operate in sequence: environment validation runs once at initialization, license validation runs on every bar but only if the environment is valid, and the actual indicator logic runs only if the license is also valid. A failure at any layer silently prevents the indicator from functioning — no error messages are displayed, which is intentional for commercial distribution.

---

## Core Mechanics

### Layer 1 — Environment Validation

```pascal
Once Begin
    AppSymbol    = GetSymbolName;
    CurrentBarType = BarType;

    If AppSymbol = "MSFT" and CurrentBarType = 2 Then
        IsEnvironmentValid = True;
End;
```

`Once` is an EasyLanguage keyword that restricts the enclosed block to execute **exactly once** — on the first bar of the indicator's calculation, during initialization. This is the correct pattern for environment checks because `GetSymbolName` and `BarType` are constants throughout the indicator's lifetime: they cannot change while the indicator is running. Evaluating them on every bar would be computationally redundant.

`GetSymbolName` returns the ticker symbol of the chart the indicator is applied to. `BarType` returns an integer identifying the chart interval type — value `2` corresponds to daily bars. Together, the condition `AppSymbol = "MSFT" and CurrentBarType = 2` restricts the indicator to exactly one configuration: daily bars of Microsoft stock. Any other symbol or bar type leaves `IsEnvironmentValid = False` and the indicator produces no output.

**Available `BarType` values for reference:**

| Value | Bar Type |
|---|---|
| 0 | Tick bars |
| 1 | Minute bars |
| 2 | Daily bars |
| 3 | Weekly bars |
| 4 | Monthly bars |

### Layer 2 — License Validation

```pascal
If IsEnvironmentValid Then
Begin
    If Date < 1200601 and LicensePassword = "A123456789" Then
        IsLicenseValid = True;

    If Date > 1200401 and LicensePassword = "B123456789" Then
        IsLicenseValid = True;
End;
```

License validation only runs when the environment check passed. Two license versions are defined by date ranges and corresponding passwords:

- **License A:** Valid when `Date < 1200601` (before June 1, 2020) and `LicensePassword = "A123456789"`.
- **License B:** Valid when `Date > 1200401` (after April 1, 2020) and `LicensePassword = "B123456789"`.

**EasyLanguage date format:** Dates are expressed as integers in `YYYMMDD` format where `YYY` is the year minus 1900. So `1200601` = year 2020 (1900+120), month 06, day 01 = June 1, 2020.

**The overlap window — intentional license transition design:**

The two date ranges overlap between April 1 and June 1, 2020. During this two-month window, **both passwords are valid simultaneously**. This is a deliberate design decision:

```
        Apr 1, 2020    Jun 1, 2020
             │               │
License A:  ─────────────────┤  (expires Jun 1)
License B:              ├────────────────────
             │               │
             └───Overlap──────┘
             (both passwords valid)
```

The overlap window allows the vendor to distribute the new License B password to clients before License A expires. The client can enter the new password at their convenience during the transition period without losing access. If the overlap window did not exist, any client who did not update their password before License A expired would lose access immediately — a poor user experience for a commercial product.

### Layer 3 — Indicator Logic

```pascal
If IsLicenseValid Then
Begin
    Plot1(Average(Close, 20), "MA");
End;
```

The actual indicator logic — in this template, a simple 20-period moving average — only executes when both environment and license validations have passed. In a real commercial indicator, this block would contain the proprietary calculation being protected.

The logic is entirely agnostic to the protection layers above it. Adding or modifying the protection does not require touching the indicator logic, and vice versa. This separation of concerns makes the template easy to adapt: replace the `Plot1` line with any indicator logic, and the three-layer protection works unchanged.

---

## Architecture

The three layers execute in a strict cascade:

```
Initialization (Once)
    └─ GetSymbolName + BarType check
           │
           ├─ FAIL → IsEnvironmentValid = False → indicator silent forever
           │
           └─ PASS → IsEnvironmentValid = True
                          │
                    Every bar:
                    License date + password check
                          │
                          ├─ FAIL → IsLicenseValid = False → indicator silent this bar
                          │
                          └─ PASS → IsLicenseValid = True
                                         │
                                   Indicator logic executes
                                   Plot1(...) shown on chart
```

**Why the cascade matters:** Environment validation uses `Once` because the environment never changes. License validation runs every bar because `Date` changes every bar — the license expiration check must be re-evaluated continuously. The indicator logic runs every bar because the plot must update continuously.

---

## v1 vs v2: The Difference

v1 and v2 implement identical protection logic. The evolution is entirely structural:

```pascal
// v1 — all logic inline
If OK and
((Date < 1200601 and Password = "A123456789") or
 (Date > 1200401 and Password = "B123456789"))
Then Begin
    Plot1(Average(Close, 20), "MA");
End;

// v2 — separated into named boolean states
If IsEnvironmentValid Then
Begin
    If Date < 1200601 and LicensePassword = "A123456789" Then IsLicenseValid = True;
    If Date > 1200401 and LicensePassword = "B123456789" Then IsLicenseValid = True;
End;

If IsLicenseValid Then
Begin
    Plot1(Average(Close, 20), "MA");
End;
```

v2 makes each protection layer independently readable and auditable. In v1, all three layers are compressed into a single compound condition — understanding the logic requires parsing nested boolean operators. v2 assigns a named state variable to each layer (`IsEnvironmentValid`, `IsLicenseValid`), making the cascade explicit and each condition independently testable.

v2 also stores `GetSymbolName` and `BarType` in named variables (`AppSymbol`, `CurrentBarType`) before comparing them, making the environment check self-documenting.

**Summary:**

| | v1.0 | v2.0 |
|---|---|---|
| **Three-layer protection** | ✓ | ✓ |
| **`Once` for environment check** | ✓ | ✓ |
| **Overlap transition window** | ✓ | ✓ |
| **Named state variables** | — | ✓ (`IsEnvironmentValid`, `IsLicenseValid`) |
| **Named environment variables** | — | ✓ (`AppSymbol`, `CurrentBarType`) |
| **Separated labeled blocks** | — | ✓ |
| **`LicensePassword` (vs `Password`)** | — | ✓ (more descriptive input name) |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LicensePassword` (`Password` in v1) | `"A123456789"` | The license key entered by the end user. Must match the currently valid password for the active date range. |

**On the default value:** The default `"A123456789"` is the License A password — the initial license. A user who receives the indicator will enter this as their license key. When License B becomes active, the vendor distributes `"B123456789"` and the user updates their input.

**On password design for commercial use:** The passwords in this template are illustrative. In production, passwords should be more complex (mixed case, symbols, longer length) and ideally unique per client — a per-client password allows the vendor to revoke a specific license without affecting other customers.

---

## Implementation Scenarios

### Scenario A — Valid Environment, Valid License A

- Chart: MSFT daily bars. `IsEnvironmentValid = True`.
- Date: March 15, 2020 (`1200315`). `Date < 1200601` ✓.
- User entered `LicensePassword = "A123456789"`. Match ✓.
- `IsLicenseValid = True`. **Moving average plots on chart.**

### Scenario B — Valid Environment, License A Expired, License B Not Entered

- Chart: MSFT daily bars. `IsEnvironmentValid = True`.
- Date: July 1, 2020 (`1200701`). `Date < 1200601` ✗ (License A expired).
- User still has `LicensePassword = "A123456789"`. `Date > 1200401` ✓ but password mismatch for B ✗.
- `IsLicenseValid = False`. **Indicator silent. No plot.**

### Scenario C — Overlap Window, Both Passwords Valid

- Date: May 1, 2020 (`1200501`). Between April 1 and June 1.
- `Date < 1200601` ✓ → License A valid if password matches.
- `Date > 1200401` ✓ → License B valid if password matches.
- User with `"A123456789"` → `IsLicenseValid = True`. User with `"B123456789"` → also `IsLicenseValid = True`.
- **Both passwords work during the transition window.**

### Scenario D — Wrong Symbol

- Chart: AAPL daily bars. `GetSymbolName = "AAPL"` ≠ `"MSFT"`.
- `Once` block: `IsEnvironmentValid = False`.
- License check never runs. **Indicator silent regardless of password.**

### Scenario E — Wrong Bar Type

- Chart: MSFT 5-minute bars. `BarType = 1` ≠ `2`.
- `Once` block: `IsEnvironmentValid = False`.
- **Indicator silent. No error message.**

---

## Key Features

- **Silent failure:** No error messages are displayed when protection layers fail — the indicator simply produces no output. This prevents end users from knowing which specific condition failed, making the protection harder to reverse-engineer.
- **`Once` initialization:** Environment validation runs exactly once, at initialization, using EasyLanguage's `Once` keyword. This is both computationally efficient and semantically correct — the environment cannot change while the indicator is running.
- **Overlap transition window:** The two-month overlap between License A expiration and License B activation allows vendors to distribute renewal passwords before the existing license expires, ensuring uninterrupted service for paying customers.
- **Date-based expiration:** License validity is tied to EasyLanguage's `Date` variable (chart bar date), not to the computer's system clock. This means the expiration applies to the data being analyzed, not to calendar time — useful for strategy testing on historical data where the system date would not trigger expiration.
- **Separation of concerns (v2):** Each protection layer is an independent named boolean. Adding a fourth layer (e.g. a machine ID check) requires adding one variable and one `If` block, without touching existing logic.
- **Template design:** The indicator logic (`Plot1`) is entirely isolated from the protection layers. Any indicator or strategy logic can replace the `Plot1` block while the three-layer protection remains unchanged.

---

## Use Cases

**Commercial EasyLanguage distribution:** The primary use case is protecting proprietary indicators or strategies before selling or licensing them to clients. EasyLanguage code is distributed as compiled `.eld` or `.elx` files, but determined reverse engineering is possible. Password protection adds a behavioral layer — even if the code structure is exposed, the indicator will not function without the correct password in the correct environment.

**Symbol-locked licensing:** Restricting the indicator to a specific symbol (e.g. `"MSFT"`) creates a symbol-specific license — a client who purchases a license for Microsoft analysis cannot use the same password to apply the indicator to Apple or ES futures. Each symbol-specific deployment requires its own license.

**Bar-type enforcement:** Requiring `BarType = 2` (daily) ensures the indicator is used in the context it was designed and tested for. A client applying a daily-bar indicator to 1-minute data and then complaining about unexpected behavior is a common support issue — the bar type check prevents this class of misuse.

**Subscription-based licensing:** The date-windowed license model supports subscription products: a client receives License A for a six-month period, then receives License B upon renewal. The overlap window ensures the transition is seamless. Adding more license versions (C, D, etc.) with successive date windows extends the model indefinitely.

**Internal code protection:** Beyond commercial use, the same pattern can protect proprietary in-house strategies from being copied or modified by unauthorized team members — restricting to specific internal account symbols or environments ensures the strategy only runs in approved configurations.

**Extension points for v3:** Natural improvements for a production-ready version include: per-client unique passwords (each client receives a different key, allowing individual license revocation), machine ID validation using `GetLoginName` or equivalent for hardware binding, encrypted password comparison rather than plain-text string matching, and a grace period counter that limits the number of bars the indicator runs without a valid license before permanently disabling.
