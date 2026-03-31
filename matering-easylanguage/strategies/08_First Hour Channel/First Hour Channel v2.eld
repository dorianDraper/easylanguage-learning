{Segunda versión con el código refactorizado, hay que someter a revisión.}

[IntraBarOrderGeneration = TRUE]

Inputs:
	StopTradingTime(1500),
	StopLossAmount(250),
	ProfitTargetAmount(250),
	FirstHourMinutes(60);

Vars: 
	//Canal primera hora
	FirstHourHigh(0),
	FirstHourLow(0),
	
	//Estado diario
	Intrabarpersist LastTradeDate(0),
	Intrabarpersist CanLongToday(False),
	Intrabarpersist CanShortToday(False),
	
	//Flags temporales
	IsFirstHour(False),
	TradingAllowed(False);
	
// ─────────────────────────────────────────
// Detección de nuevo día (reset diario)
// ─────────────────────────────────────────
If Date <> LastTradeDate Then
Begin
	CanLongToday = True;
	CanShortToday = True;
	LastTradeDate = Date;
End;

// ─────────────────────────────────────────
// Ventanas temporales
// ─────────────────────────────────────────
IsFirstHour =
	Time <= CalcTime(SessionStartTime(1,1), FirstHourMinutes);

TradingAllowed = 
	not IsFirstHour 
	and Time <= StopTradingTime;

// ─────────────────────────────────────────
// Construcción del canal de la primera hora
// ─────────────────────────────────────────
If IsFirstHour Then
Begin
	FirstHourHigh = HighD(0);
	FirstHourLow = LowD(0);
End;

// ─────────────────────────────────────────
// Setup de entrada (una por lado y día)
// ─────────────────────────────────────────
If TradingAllowed and MarketPosition = 0 Then
Begin
	If CanLongToday Then
		Buy ("FHC_LE") Next Bar at FirstHourLow Limit;
	
	If CanShortToday Then
		SellShort ("FHC_SE") Next Bar at FirstHourHigh Limit;
End;

// ─────────────────────────────────────────
// Bloqueo del lado operado
// ─────────────────────────────────────────
If MarketPosition = 1 Then
	CanLongToday = False;

If MarketPosition = -1 Then
	CanShortToday = False;
	
// ─────────────────────────────────────────
// Gestión del riesgo
// ─────────────────────────────────────────
SetStopLoss(StopLossAmount);
SetProfitTarget(ProfitTargetAmount);