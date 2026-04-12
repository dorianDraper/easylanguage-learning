{-------------------------------------------------------------------
  Opening Gap Detector v1

  Description:
    - Visual representation of both opening gap down and up.
    - Supports the Opening Gap strategies (Gap Down, Gap Up, Bidirectional).
-------------------------------------------------------------------}

Inputs:
    GapTest(Median(Range, 50)[1]);  // Minimum gap size to qualify

Vars:
    Gap(0);                         // Gap magnitude

{--------------------------------------------------
 Draw threshold levels at end of each session
--------------------------------------------------}
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

{--------------------------------------------------
 Detect Gap Down (bullish trade setup)
--------------------------------------------------}
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

{--------------------------------------------------
 Detect Gap Up (bearish trade setup)
--------------------------------------------------}
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