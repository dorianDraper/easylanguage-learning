{   Volver a escribir Envelope indicator incorporando condiciones para alertas cuando la barra completa esté por encima de la 
    línea superior o por debajo de la línea inferior.
}

Input:
	UpperLength(20),
	LowerLength(20);

Vars:
	UpperLine(0),
	LowerLine(0);

UpperLine = Average(High, UpperLength);
LowerLine = Average(Low, LowerLength);

Plot1(UpperLine, "Highs");
Plot2(LowerLine, "Lows");

If Low > UpperLine Then
	Alert;
If High < LowerLine Then
	Alert;