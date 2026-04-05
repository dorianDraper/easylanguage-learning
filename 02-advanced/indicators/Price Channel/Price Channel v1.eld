{---------------------------------------------------------
 Donchian-style breakout indicator v1

 Calculates the highest high and lowest low over a lookback
 window excluding the current bar.

 Generates alerts when price breaks the channel.

 Inputs:
    Length    -> lookback window
    Displace  -> plot displacement

 Compatible with:
    - TradeStation charts
    - RadarScreen

Notes:
    The [1] offset ensures the current bar is excluded from the
    calculation to avoid look-ahead bias if used in strategies.
----------------------------------------------------------}
Inputs:
	Length(20),		// Número barras usadas para calcular el rango
	Displace(0);	// Permite desplazar indicador en el tiempo		

Vars:
	LowerBand(0), UpperBand(0);

// Cálculo de las bandas
LowerBand = Lowest(Low, Length)[1];	
UpperBand = Highest(High, Length)[1];

// Ejecución Chart
If Getappinfo(aiApplicationtype) = Cchart Then
	If Displace >= 0 or Currentbar > AbsValue(Displace) Then
	Begin
		// Plot del canal
		Plot1[Displace](UpperBand, "UpperBand");
		Plot2[Displace](LowerBand, "LowerBand");
		// Condición de alertas (esto evida
		If Displace <= 0 Then
		Begin
			If Low Crosses Under LowerBand Then
			// Precio rompe mínimo del canal entonces realiza siguientes acciones
			Begin
				Alert("Price making new low");
				SetPlotWidth(2, 4);
				SetPlotColor(2, Magenta);
			End;
			// Precio rompe máximo del canal entonces realiza siguientes acciones
			If High Crosses Over UpperBand Then
			Begin
				Alert("Price making new high");
				SetPlotWidth(1, 4);
				SetPlotColor(1, Cyan);
			End;
		End;	
	End;

// Ejecución RadarScreen
If Getappinfo(aiApplicationtype) = Cradarscreen Then
	If Displace >= 0 or Currentbar > AbsValue(Displace) Then
	Begin
		Plot1[Displace](UpperBand, "UpperBand");
		Plot2[Displace](LowerBand, "LowerBand");
		If Displace <= 0 Then
		Begin
			If Low Crosses Under LowerBand Then
			Begin
				Alert("Price making new low");
				SetPlotBGColor(2, Darkred);
				SetPlotColor(2, White);
			End;
			If High Crosses Over UpperBand Then
			Begin
				Alert("Price making new high");
				SetPlotBGColor(2, Darkgreen);
				SetPlotColor(2, White);
			End;
		End;	
	End; 