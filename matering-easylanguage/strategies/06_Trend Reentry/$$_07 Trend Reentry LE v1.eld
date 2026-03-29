{Versión 1 según manual}

Inputs:
	FastLen(13),
	SlowLen(21),
	HHExitLen(50),
	ReEntryPoints(.10);

Vars:
	FastAvg(0),
	SlowAvg(0),
	MoveHigh(0),
	ReEnterOK(false);
	
FastAvg = Average(Close, FastLen);
SlowAvg = Average(Close, SlowLen);

If MarketPosition <= 0 Then
Begin
	If FastAvg Crosses Over SlowAvg Then
		Buy ("InitLE") Next Bar at Market;
	// Bloque reentrada
	If MarketPosition(1) = 1 and BarsSinceExit(1) >= 1 and ReEnterOK
	and High > MoveHigh + ReEntryPoints Then
		Buy ("ReEnterLE") Next Bar at Market;
End;

If MarketPosition = 1 Then
Begin
	// Salida técnica (por extensión para asegurar profit, no por debilidad)
	If ReEnterOK = False and High > Highest(High, HHExitLen)[1] Then
	Begin
		Sell ("InitLX") Next Bar at Market;
		ReEnterOK = True;
	End;
	If High > MoveHigh Then
		MoveHigh = High;
	// Salida universal/final (tendencia rota)
	If FastAvg Crosses Under SlowAvg Then 
	Begin
		Sell ("ExitLX") Next Bar at Market;
		ReEnterOK = False;
		MoveHigh = 0;
	End;
End;


{Es una estrategia de solo largos que busca inicialmente una entrada basada en un 
cruce de dos medias móviles. Luego sale cuando el máximo de la barra actual alcanza un
máximo significativamente más alto. La estrategia puede volver a entrar una vez en la
misma dirección si la tendencia continúa hacia arriba. La posición de reentrada larga
sale cuando las medias móviles se cruzan.

Esta es una estrategia LONG-ONLY con re-entrada en tendencia, y tiene tres ideas clave:
📈 Entrada inicial por cruce de medias
🚪 Salida técnica por “extensión” del movimiento
🔁 Re-entrada larga si la tendencia continúa
❌ Salida final cuando la tendencia se invalida

Importante:
👉 NO es piramidación
👉 NO acumula posiciones
👉 Siempre hay una sola posición a la vez

La Re-Entrada se permite si:
MarketPosition(1) = 1
→ ayer estábamos largos

BarsSinceExit(1) >= 1
→ hubo al menos una barra fuera

ReEnterOK = true
→ la salida previa fue “técnica”, no por fallo de tendencia

High > MoveHigh + ReEntryPoints
→ el precio demuestra continuidad alcista
}