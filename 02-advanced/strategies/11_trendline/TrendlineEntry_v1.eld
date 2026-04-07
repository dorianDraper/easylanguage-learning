{-------------------------------------------------------------------
    Trendline Entry Strategy v1
    Description:
    - This strategy uses a trendline to determine entry points for long and short positions.
    - The strategy calculates the value of the trendline at the current and previous bars to determine its slope.
    - If the trendline is ascending, it will look for long entry opportunities; if descending, it will look for short entry opportunities.
    - The strategy uses limit orders for entries when the price is favorable and stop orders when it
    
-------------------------------------------------------------------}

Inputs:
	TradeSize(500), //Opera largo si es positivo, corto si es negativo
	TLID(0);        //ID interno de línea tendencia

Vars:
	TLV(0),     //Valor actual de la línea en la barra actual
	TLVPrev(0); //Valor de la línea en la barra anterior
	//Con las vars anteriores calculamos pendiente

//Solo opera si hay tamaño válido y el ID es válido
If TradeSize <> 0 and TLID >= 0 Then
Begin
	TLV = 0;
	TLVPrev = 0;
	
	//Solo actúa en la última barra visible del gráfico
	If LastBarOnChart and TL_Exist(TLID) Then
	Begin
		TLV = TL_GetValue(TLID, Date, Time);  //Cuánto vale línea en este momento
		TLVPrev = TL_GetValue(TLID, Date[1], Time[1]);  //Cuánto valía en barra anterior
		//Lo anterior permite saber si la línea era asc o desc, su pendiente
		If TLVPrev > 0 and TLV > 0 Then
		Begin
			TLV = TLV +  (TLV - TLVPrev);  //Calcula valor estimado línea en siguiente barra
			If TradeSize > 0 Then
			Begin
				//Si precio está por encima de la línea usa orden Limit (queremos retroceso)
				If Close > TLV Then
					Buy ("TLBuy LE") Next Bar TradeSize Shares at TLV Limit
			    Else
			    //Si está por debajo entonces orden Stop (queremos ruptura)
					Buy ("TL Buy LE") Next Bar TradeSize Shares at TLV Stop;
			End Else
				//Lógica invertida para cortos
				If Close < TLV Then
					SellShort ("TL Short SE") Next Bar -TradeSize Shares at TLV Limit
				Else
					SellShort ("TLShort SE") Next Bar -TradeSize Shares at TLV Stop;
		End;
	End;
End;