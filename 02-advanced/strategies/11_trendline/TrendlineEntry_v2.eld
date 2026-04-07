{-------------------------------------------------------------------
    Trendline Entry strategy v2
    Description:
    - This strategy is an improved version of the Trendline Entry Strategy v1.
    - It uses a state machine to determine if the strategy is currently flat, long, or short.
    - The strategy calculates the current and previous values of the trendline to determine its slope and projects its value for the next bar.
    - It generates structural signals (CrossUp and CrossDown) based on the relationship between the
    
-------------------------------------------------------------------}

Inputs:
	TradeSize(500), //Tamaño orden y selector de dirección
	TLID(0);		//ID de la Trendline dibujada manualmente

Vars:
	TLCurrent(0),   //Valor exacto línea en barra actual
	TLPrevious(0),	//Valor exacto barra anterior
	TLProjected(0),	//Valor extrapolado next bar (dónde estará la línea en next bar)
	
	IsFlat(False),
	IsLong(False),
	IsShort(False),
	
	ValidTL(False),	//Activa la lógica 
	CrossUp(False),	//Ambos Cross son posición relativa(estado), no cruce (evento)
	CrossDown(False);

// ─────────────────────────────────────────
// State machine
// ─────────────────────────────────────────
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// ─────────────────────────────────────────
// Validación básica
// ─────────────────────────────────────────
ValidTL = TradeSize <> 0	//Hay tamaño 
		and TLID >= 0		//ID válido
		and TL_Exist(TLID)	//Línea existe
		and LastBarOnChart;	//Barra más reciente

// ─────────────────────────────────────────
// Lectura y proyección de la línea
// ─────────────────────────────────────────
If ValidTL Then
Begin
	//Calculamos si pendiente es asc o desc
	TLCurrent = TL_GetValue(TLID, Date, Time);			//Cuánto vale ahora
	TLPrevious = TL_GetValue(TLID, Date[1], Time[1]);	//Cuánto valía en barra anterior
	
	If TLCurrent > 0 and TLPrevious > 0 Then
		//Extrapolamos pendiente linealmente 
		TLProjected = TLCurrent + (TLCurrent - TLPrevious);
End;

// ─────────────────────────────────────────
// Señales estructurales
// ─────────────────────────────────────────
If ValidTL and TLProjected > 0 Then		 
Begin
	CrossUp = Close > TLProjected;		//Si estamos arriba CrossUp es true
	CrossDown = Close < TLProjected;	//Abajo CrossDown es true
End;

// ─────────────────────────────────────────
// Setup de entrada
// ─────────────────────────────────────────
If IsFlat and ValidTL Then	//Operamos si estamos fuera
Begin
	//Largos
	If TradeSize > 0 Then
	Begin
		If CrossUp Then
			//Si precio por encima usamos Limit order buscando retroceso
			Buy ("TL_LE_Limit") Next Bar TradeSize Shares at TLProjected Limit
		Else
			//Si precio por debajo usamos Stop buscando ruptura alcista
			Buy ("TL_LE_Stop") Next Bar TradeSize Shares at TLProjected Stop;
	End;
	
	//Cortos (largos reversed)
	If TradeSize < 0 Then
	Begin
		If CrossDown Then
			SellShort ("TL_SE_Limit") Next Bar -TradeSize Shares at TLProjected Limit
		Else
			SellShort  ("TL_SE_Stop") Next Bar -TradeSize Shares at TLProjected Stop;
	End;
End;