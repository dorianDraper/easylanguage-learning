{-------------------------------------------------------------------
Trend Reentry v2

Structure improvements:
- Clearer state management with boolean flags (IsFlat, IsLong, CanReEnter)
- More descriptive variable names (FastMA, SlowMA, ExtensionLen)
- Added comments for clarity

-------------------------------------------------------------------}

Inputs:
	FastLen(13),
	SlowLen(21),
	ExtensionLen(50),
	ReEntryBuffer(.10);

Vars:
	FastMA(0),
	SlowMA(0),
	MoveHigh(0),
	CanReEnter(false),
	IsFlat(false),
	IsLong(false),
	BullCross(false),
	BearCross(false);

// Tendencia (cálculo medias móviles)
FastMA = Average(Close, FastLen);
SlowMA = Average(Close, SlowLen);

// State machine
IsFlat = MarketPosition <= 0;
IsLong = MarketPosition = 1;

// Evento primario (cruce de medias móviles)
BullCross = FastMA Crosses Over SlowMA;
BearCross = FastMA Crosses Under SlowMA;

// Entrada inicial
If IsFlat and BullCross Then
Begin
	Buy ("InitLE") Next Bar at Market;
	MoveHigh = High;
	CanReEnter = False;
End; 

// Gestión estando largos
If IsLong Then
Begin
	//Actualizar máximo del movimiento
	If High > MoveHigh Then
		MoveHigh = High;
	
	//Salida por extensión (técnica, no por debilidad de tendencia)
	If not CanReEnter and High > Highest(High, ExtensionLen)[1] Then
	Begin
		Sell ("ExtLX") Next Bar at Market;
		CanReEnter = True;
	End;
	
	//Salida final por cambio de tendencia
	If BearCross Then
		Sell ("TrendLX") Next Bar at Market;
		CanReEnter = False;
		MoveHigh = 0;
End;

// Re-entrada
If MarketPosition = 0 and CanReEnter
	and High > MoveHigh + ReEntryBuffer Then
	Buy ("ReEntryLE") Next Bar at Market;