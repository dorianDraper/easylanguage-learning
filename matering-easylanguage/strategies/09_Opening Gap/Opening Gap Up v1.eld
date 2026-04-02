{-------------------------------------------------------------------
Gap Up v1

Structure (symmetry with Gap Down v2):
- State machine variable (IsShort) for better readability and maintainability.
- Separated logic into clear sections (gap detection, entry setup, state machine, exit setup)
- Added comments for clarity.  

-------------------------------------------------------------------}

Inputs:
	GapTest( Median(Range, 50)[1] ),
	GapPrice(High);

Vars:
	Gap(0),
	GapExitPxPT(0),
	GapExitPxSL(0),
	IsNewSession(False),
	IsGapUp(False),
	IsShort(False);

// ─────────────────────────────────────────
// Detección del gap
// ─────────────────────────────────────────
IsNewSession = Date of Next Bar <> Date;
IsGapUp = Open of Next Bar > GapPrice + GapTest;

// ─────────────────────────────────────────
// Setup de entrada (short)
// ─────────────────────────────────────────
If IsNewSession and IsGapUp Then
Begin
	Gap = Open of Next Bar - GapPrice;
	SellShort ("GAP SE") Next Bar at Market;
End;

// ─────────────────────────────────────────
// State machine
// ─────────────────────────────────────────
IsShort = MarketPosition = -1;

// ─────────────────────────────────────────
// Setup de salida
// ─────────────────────────────────────────
If IsShort Then
Begin
	GapExitPxPT = EntryPrice - Gap;     //Gap rellenado
	GapExitPxSL = EntryPrice + GapTest; //Gap inválido
	
	BuyToCover ("Filled SX") Next Bar at GapExitPxPT Limit;
	BuyToCover ("Stop SX") Next Bar at GapExitPxSL Stop;
	
	SetExitOnClose; //Salida histórica EOD
End;