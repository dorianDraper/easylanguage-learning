{-------------------------------------------------------------------
Trend Reentry Version 1
-------------------------------------------------------------------}

Inputs:
	FastLen(13),
	SlowLen(21),
	HHExitLen(50),
	ReEntryPoints(.10);

Vars:
	FastAvg(0),
	SlowAvg(0),
	MoveHigh(0),
	ReEnterOK(false);
	
FastAvg = Average(Close, FastLen);
SlowAvg = Average(Close, SlowLen);

If MarketPosition <= 0 Then
Begin
	If FastAvg Crosses Over SlowAvg Then
		Buy ("InitLE") Next Bar at Market;
	// Bloque reentrada
	If MarketPosition(1) = 1 and BarsSinceExit(1) >= 1 and ReEnterOK
	and High > MoveHigh + ReEntryPoints Then
		Buy ("ReEnterLE") Next Bar at Market;
End;

If MarketPosition = 1 Then
Begin
	// Salida técnica (por extensión para asegurar profit, no por debilidad)
	If ReEnterOK = False and High > Highest(High, HHExitLen)[1] Then
	Begin
		Sell ("InitLX") Next Bar at Market;
		ReEnterOK = True;
	End;
	If High > MoveHigh Then
		MoveHigh = High;
	// Salida universal/final (tendencia rota)
	If FastAvg Crosses Under SlowAvg Then 
	Begin
		Sell ("ExitLX") Next Bar at Market;
		ReEnterOK = False;
		MoveHigh = 0;
	End;
End;
