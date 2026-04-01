{ Segunda versión con ajustes, mantenemos lógica intaca pero separamos semántica 
(riesgo vs sizing) y hacemos explícito el estado. Esto prepara el sistema para 
futuras mejoras como trailing stops o filtros adicionales sin complicar la lógica actual. }

Inputs:
	BaseTradeSize(1000),
	SizeStep(100),
	MaxTradeSize(2000),
	MinTradeSize(100),
	RiskUnit(500),
	DonchianLen(21);

Vars:
	TradeSize(0),
	TradeSizeAdjust(0),
	LongSetup(false),
	ShortSetup(false),
	IsFlat(false);

// State
IsFlat = MarketPosition = 0;

// Ajuste por equity
If AbsValue(NetProfit) >= RiskUnit Then
	TradeSizeAdjust = Round((NetProfit / RiskUnit), 0) * SizeStep
Else
	TradeSizeAdjust = 0;

// Límites de tamaño
TradeSize = BaseTradeSize + TradeSizeAdjust;

If TradeSize > MaxTradeSize Then
	TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
	TradeSize = MinTradeSize;
	
// Señales Donchian
LongSetup = Low < Lowest(Low, DonchianLen)[1];
ShortSetup = High > Highest(High, DonchianLen)[1];

// Setup de entrada
If IsFlat and LongSetup Then
	Buy Next Bar TradeSize Shares at Market;

If IsFlat and ShortSetup Then
	SellShort Next Bar TradeSize Shares at Market;

// Gestión del riesgo
SetStopLoss(RiskUnit);
SetProfitTarget(RiskUnit);