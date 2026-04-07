{-------------------------------------------------------------------
    Password Protection v2

    Description:
    - Improved version of the password protection indicator.
    - The user must enter the correct password to access the indicator's functionality.

    Implements three levels of password protection:
        1) Environment validation (symbol / bar type)
        2) Password-based license
        3) License expiration window

-------------------------------------------------------------------}

Inputs:
    LicensePassword("A123456789");

Vars:
    IsEnvironmentValid(False),
    IsLicenseValid(False),
    AppSymbol(""),
    CurrentBarType(0);


{--------------------------------------------------
 Detect environment (executed once at initialization)
--------------------------------------------------}
Once Begin

    AppSymbol = GetSymbolName;
    CurrentBarType = BarType;

    { Restrict indicator to specific symbol and bar type }
    If AppSymbol = "MSFT" and CurrentBarType = 2 Then
        IsEnvironmentValid = True;

End;


{--------------------------------------------------
 Validate license conditions
--------------------------------------------------}
If IsEnvironmentValid Then
Begin

    { License version A (valid until specific date) }
    If Date < 1200601 and LicensePassword = "A123456789" Then
        IsLicenseValid = True;

    { License version B (new license after renewal) }
    If Date > 1200401 and LicensePassword = "B123456789" Then
        IsLicenseValid = True;

End;


{--------------------------------------------------
 Indicator logic (executed only if license valid)
--------------------------------------------------}
If IsLicenseValid Then
Begin

    { Example indicator: 20-period moving average }
    Plot1(Average(Close, 20), "MA");

End;
