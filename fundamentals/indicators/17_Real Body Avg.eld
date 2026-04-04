{	Este indicador para el RadarScreen coloca la palabra Bullish o Bearish
	en una celda basado en el valor del promedio del Real Body. El fondo (BG)
	de las celdas se colorea con un degradado basado en el valor promedio RBody.
}

Input:
	Length(10);

Vars:
	RealBody(0),
	AvgRealBody(0),
	Direction("");

RealBody = Close - Open;
AvgRealBody = Average(RealBody, Length);
Condition1 = AvgRealBody > 0;

If Condition1 Then
	Direction = "Bullish"
Else
	Direction = "Bearish";
	
Plot1(Direction, "RealBodyDir");
Plot2(AvgRealBody, "AvgRB");

SetPlotBGColor(1, GradientColor(AvgRealBody, -.015, .015, red, green));
SetPlotBGColor(2, GradientColor(AvgRealBody, -.015, .015, red, green));
