{-------------------------------------------------------------------
ATRDollar TrailStop v2

Structure improvements:
- Renamed variables for clarity (e.g., ATRValue, FloorDistance, TrailDistance, StopLossDistance)
- Added comments for better understanding of each step

-------------------------------------------------------------------}

Inputs:
	ATRTrail(1),  	        //Qué tan cerca sigue el trailing al precio una vez activo
	ATRFloor(2),  	        //Cuántos ATRs debe avanzar el precio para activar el trailing
	ATRStopLoss(1),         //Cuántos ATRs estamos dispuestos a perder al inicio
	ATRLen(9);  	        //Cómo medimos la volatilidad

Vars:
	ATRValue(0),            //Valor actual del ATR
	FloorDistance(0),       //Distancia en puntos para activar el trailing (ATRFloor x ATR)
	TrailDistance(0),       //Distancia en puntos para el trailing una vez activo (ATRTrail x ATR)
	StopLossDistance(0),    //Distancia en puntos para el stop inicial (ATRStopLoss x ATR)
	TrailingActive(false),  //Indica si el trailing ya está activo
	IsFlat(false),
	IsLong(false),
	IsShort(false);

// Cálculo ATR
ATRValue = AvgTrueRange(ATRLen);

FloorDistance = ATRValue * ATRFloor;
TrailDistance = ATRValue * ATRTrail;
StopLossDistance = ATRValue * ATRStopLoss;

// State machine
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Si estamos flat, reseteamos todo
If IsFlat Then
	TrailingActive = False;

SetStopShare;

// Si tenemos una posición abierta (ya sea larga o corta) 
If MarketPosition <> 0 Then
Begin
	If not TrailingActive Then
	Begin
        //Mientras el trailing no esté activo, solo tenemos el stop inicial
		SetStopLoss(StopLossDistance * BigPointValue);
		
        // Verificamos si el precio ha avanzado lo suficiente para activar el trailing (ATRFloor x ATR)
		If(IsLong and High >= EntryPrice + FloorDistance) or 	
			(IsShort and Low <= EntryPrice - FloorDistance) Then
				TrailingActive = True;
	End;
	
    // Si el trailing ya está activo, seguimos al precio con la distancia definida por ATRTrail x ATR
	If TrailingActive Then
		SetDollarTrailing(TrailDistance * BigPointValue);
End;


