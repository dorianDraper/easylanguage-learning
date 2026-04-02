{-------------------------------------------------------------------
End-of-Day Exit v1
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

