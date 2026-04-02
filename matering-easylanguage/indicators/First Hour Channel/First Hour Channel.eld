{-------------------------------------------------------------------
First Hour Channel indicator
-------------------------------------------------------------------}

Inputs:
	FirstHourMinutes(60),
	StopPlotTime(1500),
	HighColor(Blue),
	LowColor(Red);

Vars:
	FirstHourHigh(0),
	FirstHourLow(0),
	IsFirstHour(False),
	IsChannelActive(False);

// ─────────────────────────────
// Ventanas temporales
// ─────────────────────────────
IsFirstHour = 
	Time <= CalcTime(Sessionstarttime(1,1), FirstHourMinutes);

IsChannelActive = 
	Time > CalcTime(Sessionstarttime(1,1), FirstHourMinutes)
	and Time <= StopPlotTime;

// ─────────────────────────────
// Construcción del canal
// ─────────────────────────────
If IsFirstHour Then
Begin
	FirstHourHigh = HighD(0);
	FirstHourLow = LowD(0);	
End;

// ─────────────────────────────
// Canal fijo tras la 1ª hora
// ─────────────────────────────
If IsChannelActive Then
Begin
	SetPlotColor(1, HighColor);
	SetPlotColor(2, LowColor);
	
	Plot1(FirstHourHigh, "FH High");
	Plot2(FirstHourLow, "FH Low");
End Else
Begin
	NoPlot(1);
	NoPlot(2);
End;