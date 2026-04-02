{-------------------------------------------------------------------
End-of-Day Exit v2

Structure improvements:
- Renamed variables for clarity (e.g., IsEODWindow, IsRealTime)
- Added comments for better understanding of each step

-------------------------------------------------------------------}

[IntraBarOrderGeneration = TRUE]

Inputs:
	EODExitMinutes(3);

Vars:
	IsLong(false),
	IsShort(false),
	IsEODWindow(false),
	IsRealTime(false);

// State machine
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Contexto temporal
IsRealTime = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1,1), -EODExitMinutes);

// Salida End-of-Day
If EODExitMinutes > 0 Then
Begin
	If IsRealTime and IsEODWindow Then
	Begin
		If IsLong Then
			Sell ("EOD_LX") Next Bar at Market;
		If IsShort Then
			BuyToCover ("EOD_SX") Next Bar at Market;
	End
	Else
		SetExitOnClose;
End;

