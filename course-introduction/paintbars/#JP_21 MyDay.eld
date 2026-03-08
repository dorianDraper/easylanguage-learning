// Este PaintBar marca cada barra que ocurre en el mismo día de la semana especificado con un input.

Input:
	DoW(Wednesday);

If DayOfWeek(Date) = DoW Then
	PlotPB(High, Low, "DoW");
Else
    NoPlot(1);

{	🧠 Este PaintBar colorea toda la barra cuando se cumple una condición. Identifica condiciones que se repiten en una serie de barras.
    🧩 Se usa para:
        > detectar patrones
        > señalar eventos puntuales
        > resaltar velas especiales
    👉 Marca las barras que ocurren en el mismo día de la semana especificado por el input DoW.
    👉 Si el día de la semana de la barra actual coincide con DoW, se pinta la barra. Si no, se usa NoPlot para no pintar nada.
    ❓ La barra actual ocurre en el día de la semana especificado? 
    Si la respuesta es sí, tenemos una barra del mismo día de la semana.
    👉 Este PaintBar identifica velas que:
        - Ocurren en un día específico de la semana
        - Pueden ser útiles para analizar patrones semanales
        - Ayudan a detectar eventos recurrentes relacionados con días específicos
}