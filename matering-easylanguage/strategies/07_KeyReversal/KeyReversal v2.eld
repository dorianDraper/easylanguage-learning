{-------------------------------------------------------------------
Key Reversal Version 2

Structure improvements:
	- Added state machine for clearer trade management
	- Separated key reversal detection from trade execution logic
	- Added comments for better readability
	- Maintained all previous improvements from v1
-------------------------------------------------------------------}

Inputs:
	DonchianLen(21),
	CarryForwardBars(0),
	ConfirmationTolerancePct(0),
	ExitAfterBars(5);
	
Vars:
	//Key Reversal detection
	LowerLowOffset(-1),  //inicializamos en -1, asumimos no hay lower low todavía
	HasStructuralLow(false),
	ReferenceClose(0),
	HasBullishClose(false),
	
	//State machine
	TradeState(0),	// 0=Flat, 1=LongBase, 2=LongScaled
	ScaleBarsCounter(0);

// Reset de eventos (higiene de estado)
HasBullishClose = False;

// Detección del Key Reversal
LowerLowOffset = 
	MRO(Low < Lowest(Low,DonchianLen)[1], CarryForwardBars + 1, 1);
	
HasStructuralLow = LowerLowOffset >= 0;

If HasStructuralLow Then
Begin
	ReferenceClose = Close[LowerLowOffset + 1];
	HasBullishClose =
		Close >ReferenceClose * (1 - ConfirmationTolerancePct * .01);
End;

// Entrada base
If TradeState = 0 and HasStructuralLow and HasBullishClose Then
Begin
	Buy ("LE1") Next Bar at Market;
	TradeState = 1;
	ScaleBarsCounter = 0;
End;

// Scale-in
If TradeState = 1 and HasStructuralLow and HasBullishClose 
	and OpenPositionProfit < 0 Then
Begin
	Buy ("LE2") Next Bar at Market;
	TradeState = 2;
	ScaleBarsCounter = 0;
End;

// Contador temporal para scale-in
If TradeState = 2 Then
	ScaleBarsCounter = ScaleBarsCounter + 1;

// Salidas temporales
If TradeState >= 1 and BarsSinceEntry >= ExitAfterBars Then
Begin
	Sell ("ExitLE1") Next Bar 100 Shares from Entry ("LE1") at Market;
	TradeState = 0;
End;

If TradeState = 2 and ScaleBarsCounter >= ExitAfterBars Then
Begin
	Sell ("ExitLE2") Next Bar 100 Shares from Entry ("LE2") at Market;
	TradeState = 1;
End;
