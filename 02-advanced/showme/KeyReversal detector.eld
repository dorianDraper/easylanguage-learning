{-------------------------------------------------------------------
Key Reversal Detector 

Detects key reversals based on structural lows and bullish closes. A key reversal is 
identified when a new lower low is formed, followed by a close that is above a certain 
percentage of the reference close (the close at the time of the structural low).
-------------------------------------------------------------------}

Inputs:
	CarryForwardBars(0),            //Cuántas barras después del mínimo seguimos considerándolo válido
	ConfirmationTolerancePct(0),    //Cuánto margen damos al cierre (ruido)
	DonchianLen(21);                //Define qué es un mínimo "importante"

Vars:
	LowerLowOffset(-1),             //indica cuándo ocurrió el mínimo LowerLow
	HasStructuralLow(false),
	ReferenceClose(0),              //Ancla la estructura
	HasBullishClose(false);

// Reset por barra
HasBullishClose = False;

// Detección de Lower Low estructural
LowerLowOffset = 
	MRO(Low < Lowest(Low, DonchianLen)[1], CarryForwardBars + 1, 1); 

HasStructuralLow = LowerLowOffset >= 0;

If HasStructuralLow Then
Begin
	ReferenceClose = Close[LowerLowOffset + 1];
	HasBullishClose =
		Close >ReferenceClose * (1 - ConfirmationTolerancePct * .01);
End;

// Plots
If HasStructuralLow Then
	Plot1(Low - Range * .33, "StrucLow");

If HasBullishClose Then
	Plot2(Low - Range * .66, "BullClose");

If HasStructuralLow and HasBullishClose Then
	Plot3(Low - Range * .99, "KeyReversal");