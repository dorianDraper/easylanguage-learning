{-------------------------------------------------------------------
Versión 2 con mejoras en semántica y lógica para mayor claridad, consistencia y adaptabilidad.
Añadimos Vars para mejorar la legibilidad y mantenemos la funcionalidad original.
También state machine para mayor claridad en la lógica de control de flujo. 
-------------------------------------------------------------------}

[IntraBarOrderGeneration = TRUE]

Inputs:
	EODExitMinutes(3);

Vars:
	IsLong(false),
	IsShort(false),
	IsEODWindow(false),
	IsRealTime(false);

// State machine
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Contexto temporal
IsRealTime = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1,1), -EODExitMinutes);

// Salida End-of-Day
If EODExitMinutes > 0 Then
Begin
	If IsRealTime and IsEODWindow Then
	Begin
		If IsLong Then
			Sell ("EOD_LX") Next Bar at Market;
		If IsShort Then
			BuyToCover ("EOD_SX") Next Bar at Market;
	End
	Else
		SetExitOnClose;
End;

{Esta NO es una estrategia de trading, es un:
🛑 componente de salida End-of-Day (EOD)
🛑 Exit-only strategy
⏱️ Time-based exit
📅 End-of-Day risk control
🔌 Plug-and-play con cualquier sistema

Su función es:
En real-time:
	🔹cerrar cualquier posición abierta
	🔹n minutos antes del cierre de la sesión
	🔹usando la hora del ordenador
En backtesting:
	🔹cerrar la posición al cierre del día
	🔹para poder simular el efecto EOD aunque no exista “hora viva”

Además, funciona independientemente del timeframe, solo tiene sentido en gráficos intradía
y puede coexistir con cualquier estrategia de entrada

🧠 Resumen mental / interpretación conceptual
🔑 Esta estrategia no busca trades
🔑 Busca no quedarse dentro del mercado
🔑 El tiempo manda, no el precio
🔑 En real-time actúa por reloj
🔑 En histórico simula el efecto con el cierre diario

O dicho de forma muy clara:
“No me importa cómo ni por qué entré,
no quiero dormir con posiciones abiertas.”

'IntraBarOrderGeneration' permite que cerremos según esta metodología, sin dicho
atributo no saldría antes del cierre, saldría al cierre pero no puedes salir si el
mercado ha cerrado, sería un cierre ficticio. Por eso usamos IntraBarOrderGeneration.
}