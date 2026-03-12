{Este indicador traza un histograma del volumen, con el histograma resaltado y en un color diferente en las barras de volumen alto.}

Input:
	HiVolume(500000),
	LineWidth(4),
	LineColor(Yellow);

If Ticks > HiVolume Then
Begin
	SetPlotColor(1, LineColor);
	SetPlotWidth(1, LineWidth);
End;

Plot1(Ticks, "Volume");

{Este indicador se puede usar para identificar barras de volumen alto, lo que puede indicar un aumento en la actividad del mercado. 
El usuario puede ajustar el umbral de volumen alto (HiVolume) y personalizar el color y el grosor de las barras de volumen alto.
El indicador se basa en el número de ticks (transacciones) en cada barra, y resalta las barras que superan el umbral de volumen alto.}