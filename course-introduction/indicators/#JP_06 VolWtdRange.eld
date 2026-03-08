{	Este indicador calcula el rango de cada barra multiplicado por su volumen,
	dando como resultado un indicador de rango ponderado por volumen.
}

Vars: VolumeWtdRange(0);

VolumeWtdRange = (High - Low) * Ticks;

Plot1(VolumeWtdRange, "VWR");