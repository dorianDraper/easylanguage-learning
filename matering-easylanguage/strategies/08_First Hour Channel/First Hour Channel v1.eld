{Versión 1 según manual y vídeo explicativo}

[Intrabarordergeneration = TRUE] //Queremos que los límites ejecuten dentro de barra

Inputs:
	StopTradingTime(1500),
	StopLoss(250),
	ProfitTarget(250);	

Vars:
	HighVal(0),
	LowVal(0),  //Ambas para canal de la primera hora
	
	Intrabarpersist LongTrade(0),
	Intrabarpersist ShortTrade(0); //Controlamos estado real del trade y evitamos reseteo dentro misma barra

// Monitorización canal
If Time <= CalcTime(SessionStartTime(1,1), 60) Then
Begin
	HighVal = HighD(0);
	LowVal = LowD(0);
	LongTrade = 1;
	ShortTrade = 1;
End Else
// Sistema
Begin
	// Controlar posiciones abiertas
	If MarketPosition = 1 and LongTrade = 1 Then
		LongTrade = -1;
	If MarketPosition = -1 and ShortTrade = 1 Then
		ShortTrade = -1;
	// Apertura de órdenes
	If Time <= StopTradingTime Then
	Begin
		If LongTrade = 1 Then
			Buy Next Bar at LowVal Limit;
		If ShortTrade = 1 Then
			SellShort Next Bar at HighVal Limit;
	End;
End;

SetProfitTarget(ProfitTarget);
SetStopLoss(StopLoss);