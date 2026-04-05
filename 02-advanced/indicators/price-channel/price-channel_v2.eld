{---------------------------------------------------------
 Donchian-style breakout indicator v2

 Structure improvements:
    - Added execution environment detection for charts vs RadarScreen
    - Improved alert handling with environment-specific visual cues
    - Added comments for better readability
    - Maintained all previous improvements from v1

 ----------------------------------------------------------}

 Inputs:
    LookbackLength(20),
    Displace(0);

Vars:
    DonchianUpper(0),
    DonchianLower(0),
    AppType(0),
    IsChart(false),
    IsRadar(false);


{--------------------------------------------------
 Detect execution environment
--------------------------------------------------}

AppType = GetAppInfo(aiApplicationType);

IsChart = AppType = cChart;
IsRadar = AppType = cRadarScreen;


{--------------------------------------------------
 Calculate breakout levels
--------------------------------------------------}

DonchianUpper = Highest(High, LookbackLength)[1];
DonchianLower = Lowest(Low, LookbackLength)[1];


{--------------------------------------------------
 Ensure displacement does not reference
 unavailable historical bars
--------------------------------------------------}

If Displace >= 0 or CurrentBar > AbsValue(Displace) Then
Begin

    {----------------------------------------------
     Plot breakout levels
    ----------------------------------------------}

    Plot1[Displace](DonchianUpper, "UpperBreakout");
    Plot2[Displace](DonchianLower, "LowerBreakout");


    {----------------------------------------------
     Generate alerts only when the indicator
     is not projected into the future
    ----------------------------------------------}

    If Displace <= 0 Then
    Begin

        {------------------------------------------
         Breakout below channel
        ------------------------------------------}

        If Low Crosses Under DonchianLower Then
        Begin

            Alert("Price breaking below lookback range");

            If IsChart Then
            Begin
                SetPlotWidth(2, 4);
                SetPlotColor(2, Magenta);
            End;

            If IsRadar Then
            Begin
                SetPlotBGColor(2, DarkRed);
                SetPlotColor(2, White);
            End;

        End;


        {------------------------------------------
         Breakout above channel
        ------------------------------------------}

        If High Crosses Over DonchianUpper Then
        Begin

            Alert("Price breaking above lookback range");

            If IsChart Then
            Begin
                SetPlotWidth(1, 4);
                SetPlotColor(1, Cyan);
            End;

            If IsRadar Then
            Begin
                SetPlotBGColor(1, DarkGreen);
                SetPlotColor(1, White);
            End;

        End;

    End;

End;