{-------------------------------------------------------------------
Versión 1 siguiendo el manual de estilo original, con semántica y lógica básicas.
-------------------------------------------------------------------}

// Enable IntrabarOrderGeneration, ejecuta órdenes dentro de la barra, no espera al cierre de vela
[IntrabarOrderGeneration = TRUE]

Inputs:
	MinstoX(3);

// input switch permite activar/desactivar la lógica
If MinstoX > 0 Then
Begin
	// barra viva, día actual
	If LastBarOnChart and Date = CurrentDate Then
	Begin
		If CurrentTime >= CalcTime(SessionEndTime(1,1), -MinstoX) Then
		//hora de cierre de la sesión menos n minutos. (1,1)=sesión principal gráfico, funciona con cualquier mercado
		Begin
			Sell ("EOD LX") Next Bar at Market;
			BuyToCover ("EOD SX") Next Bar at Market;
		End;
	//La siguiente parte solo para mostrar histórico para back-testing	
	End Else
		SetExitOnClose;
End;

{
🔹Se trata de una estrategia que sale antes del final del día con independencia del
intervalo de la barra. 
🔹Referencia a la hora del ordenador. Permite backtest de la salida a fin del día.
🔹Crear un input switch y activar el atributo 'IntraBarOrderGeneration'.

Al automatizarse, esta estrategia cierra todas las posiciones, largas o cortas,
n minutos antes de la hora de cierre del día actual. Con el fin de aproximar el 
back-testing de esta salida, la estrategia cierra cada trade histórico al precio de
cierre del día. Esta estrategia es de solo salida y para gráficos intradía.

Time vs CurrenTime
Time = hora de la barra (histórica o actual)
CurrentTime = hora real del ordenador 

Date vs CurrentDate
Date = fecha de la barra
CurrentDate = fecha real actual
}