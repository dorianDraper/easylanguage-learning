{-------------------------------------------------------------------
Key Reversal Version 1
-------------------------------------------------------------------}

Inputs:
	CarryForward(0),
	FudgeFactor(0),
	LLChannelLookupBars(21),
	ExitBars(5);

Vars:
	LowerLow(false),
	LLBar(0),
	KeyReversalClose(0),
	HigherClose(false),
	ScaleFlag(false),
	ScaleCount(0);

HigherClose = False;

LLBar = MRO(Low < Lowest(Low, LLChannelLookupBars)[1], CarryForward + 1, 1);

LowerLow = LLBar >= 0;

If LowerLow Then
Begin
	KeyReversalClose = Close[LLBar + 1];
	HigherClose = Close > KeyReversalClose * (1 - FudgeFactor * .01);
End;

//Primera entrada
If LowerLow and HigherClose and Marketposition = 0 Then
Begin
	Buy ("LE1") Next Bar at Market;
	ScaleFlag = False;
End;

//Segunda entrada
If LowerLow and HigherClose and Marketposition = 1 
	and ScaleFlag = False and OpenPositionProfit < 0 Then
Begin
	Buy ("LE2") Next Bar at Market;
	ScaleFlag = True;
	ScaleCount = -2;
End;

//Contador
If ScaleFlag Then
	ScaleCount = ScaleCount + 1;

If Marketposition = 1 Then
Begin
	If BarsSinceEntry = ExitBars Then
		Sell ("Ex1") Next Bar 100 Shares from Entry ("LE1") at Market;
	
	If ScaleCount = ExitBars Then
		Sell ("Ex2") Next Bar 100 Shares from Entry ("LE2") at  Market;
End;	

