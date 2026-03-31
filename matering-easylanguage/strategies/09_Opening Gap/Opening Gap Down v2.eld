{-------------------------------------------------------------------
Versión 2 - Gap Down con algunos refinamientos pero sin grandes cambios
-------------------------------------------------------------------}

Inputs:
	GapTest( Median(Range, 50)[1] ),
	GapPrice(Low);

Vars: 
	Gap(0),
	GapExitPxPT(0),
	GapExitPxSL(0),
	IsNewSession(False),
	IsGapDown(False),
	IsLong(False);

// ─────────────────────────────────────────
// Detección del gap
// ─────────────────────────────────────────
IsNewSession = Date of Next Bar <> Date;
IsGapDown = Open of Next Bar < GapPrice - GapTest;

// ─────────────────────────────────────────
// Setup de entrada (short)
// ─────────────────────────────────────────
If IsNewSession and IsGapDown Then
Begin
	Gap = GapPrice - Open of Next Bar;
	Buy ("GAP LE") Next Bar at Market;
End;

// ─────────────────────────────────────────
// State machine
// ─────────────────────────────────────────
IsLong =MarketPosition = 1;

// ─────────────────────────────────────────
// Setup de salida
// ─────────────────────────────────────────
If IsLong Then
Begin
	GapExitPxPT = EntryPrice + Gap;     //Gap rellenado
	GapExitPxSL = EntryPrice - GapTest; //Gap inválido
	
	Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
	Sell ("Stop LX") Next Bar at GapExitPxSL Stop;
	
	SetExitOnClose; //Salida histórica EOD
End;