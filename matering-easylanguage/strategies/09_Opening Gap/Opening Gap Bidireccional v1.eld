{-------------------------------------------------------------------
Unifica Opening Gap Down v2 y Opening Gap Up v2 para una semántica más clara,
menor mantenimiento y sin duplicidad de código
-------------------------------------------------------------------}

Inputs:
	GapTest( Median(Range, 50)[1] );

Vars:
	Gap(0),
	GapExitPxPT(0),
	GapExitPxSL(0),
	
	IsNewSession(False),
	IsGapDown(False),
	IsGapUp(False),
	IsLong(False),
	IsShort(False);

// ─────────────────────────────────────────
// Detección de nueva sesión
// ─────────────────────────────────────────
IsNewSession = Date of Next Bar <> Date;

// ─────────────────────────────────────────
// Detección de gaps
// ─────────────────────────────────────────
IsGapDown = IsNewSession and Open of Next Bar < Low - GapTest;
IsGapUp   = IsNewSession and Open of Next Bar > High + GapTest;

// ─────────────────────────────────────────
// Setup de entrada
// ─────────────────────────────────────────
If MarketPosition = 0 Then
Begin
	// Gap bajista → largo
	If IsGapDown Then
	Begin
		Gap = Low - Open of Next Bar;
		Buy ("GAP_LE") Next Bar at Market;
	End;

	// Gap alcista → corto
	If IsGapUp Then
	Begin
		Gap = Open of Next Bar - High;
		SellShort ("GAP_SE") Next Bar at Market;
	End;
End;

// ─────────────────────────────────────────
// State machine
// ─────────────────────────────────────────
IsLong  = MarketPosition = 1;
IsShort = MarketPosition = -1;

// ─────────────────────────────────────────
// Setup de salida
// ─────────────────────────────────────────
If IsLong Then
Begin
	GapExitPxPT = EntryPrice + Gap;
	GapExitPxSL = EntryPrice - GapTest;
	
	Sell ("GapFill_LX") Next Bar at GapExitPxPT Limit;
	Sell ("GapStop_LX") Next Bar at GapExitPxSL Stop;
	
	SetExitOnClose;
End;

If IsShort Then
Begin 
	GapExitPxPT = EntryPrice - Gap;
	GapExitPxSL = EntryPrice + GapTest;
	
	BuyToCover ("GapFill_SX") Next Bar at GapExitPxPT Limit;
	BuyToCover ("GapStop_SX") Next Bar at GapExitPxSL Stop;
	
	SetExitOnClose;
End;
