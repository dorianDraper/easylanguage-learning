{-------------------------------------------------------------------
Versión 1, detalle y explicación original según curso
Creación de un componente de estrategia de salida trailing stop con nivel de activación
y cálculo de niveles de stop dinámicos predefinidos usando el ATR. Dicho componente
de estrategia de sólo salida cierra las posiciones, tanto largas como cortas, con un
stop trailing monetario usando el ATR pero solo después de que se haya alcanzado un nivel de 
activación del ATR. Usamos estrategias MACD predefinidas de TradeStation para las entradas.
-------------------------------------------------------------------}

Inputs:
	ATRTrail(1),  	        //trailing dinámico = 1xATR, una vez activado
	ATRFloor(2),  	        //nivel activación, trailing no activa hasta que precio avance 2xATR
	ATRStopLoss(1),         //protección inmediata tras entrada, stopInicial=1 x ATR
	ATRLen(9);		        //período del ATR

Vars:
	ATR(0), 				//volatilidad actual
	FloorAmount(0), 		//distancia activación (ATR x ATRFloor)
	FloorFlag(false), 		//state variable, indica si ya podemos activar el trailing
	ATRTrailAmount(0), 		//tamaño trailing dinámico
	ATRStopLossAmount(0),	//stop inicial de protección
	IsFlat(false),
	IsLong(false),
	IsShort(false);

ATR = AvgTrueRange(ATRLen);

ATRTrailAmount = ATR * ATRTrail;
FloorAmount = ATR * ATRFloor;
ATRStopLossAmount = ATR * ATRStopLoss;

{ Hasta aquí todo está en puntos, ATR devuelve puntos del símbolo, luego 
BigPointValue convierte puntos en dinero, ejemplo:
ATR = 1.25 puntos
BigPointValue = 50 (ES)
riesgo real = 62.5 USD
	
Esto permite al sistema adaptarse automáticamente a cualquier símbolo sin hardcodear dólares
}

{State machine básica}
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

If IsFlat Then 
	FloorFlag = False;  //cada vez que salimos de una posición el sistema se prepara para el siguiente trade

SetStopShare;

If MarketPosition <> 0 Then
Begin
	If FloorFlag = False Then 
	Begin
		//mientras posición abierta (MP <> 0) y no ha alcanzado el floor, solo existe stop inicial
		SetStopLoss(ATRStopLossAmount * BigPointValue);
		If (IsLong and High >= EntryPrice + FloorAmount) 
			or (IsShort and Low <= EntryPrice - FloorAmount) Then
				FloorFlag = True;
	End;
//LARGO = el máximo ha avanzado >= ATRFloor x ATR | CORTO = mínimo ha avanzado >=ATRFloor x ATR 	
//Solo entonces el trade se ha ganado el derecho a trailing
	If FloorFlag Then
		//A partir de aquí stop sigue al precio, adapta a volatilidad, protege beneficios
		SetDollarTrailing(ATRTrailAmount * BigPointValue);	
End;


{
🧩 Qué es realmente este ejercicio (conceptualmente)
Este NO es una estrategia completa, es un bloque con:
🔹 Componente de salida (exit-only)
🔹 Trailing stop dinámico basado en ATR
🔹 Con activación previa (“floor”)
🔹 No decide cuándo entrar, solo decide cómo salir, y lo hace de forma inteligente, 
adaptándose a la volatilidad del mercado (ATR) y protegiendo beneficios una vez que 
el precio se ha movido a nuestro favor lo suficiente (floor).
🔹 Las entradas: NO están aquí, vienen de estrategias pre-creadas (MACD LE / SE)
}