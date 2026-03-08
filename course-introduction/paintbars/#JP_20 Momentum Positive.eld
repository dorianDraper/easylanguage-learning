// Este PaintBar marca aquellas barras en las cuales el Momentum es mayor que 0 y alerta si la condición da verdadero.

Input:
	Price(Close),
	Length(10);
	
Vars:
	Mom(0);

Mom = Momentum(Price, Length);

If Mom > 0 Then
Begin
	PlotPB(High, Low, "Mom Positive");
	Alert("Momentum Positive" + Description);
End
Else
	NoPlot(1);

{	🧠 Un PaintBar colorea toda la barra cuando se cumple una condición. Identifica condiciones que se repiten en una serie de barras.
    Se usa para:
        > detectar patrones
        > señalar eventos puntuales
        > resaltar velas especiales
    👉 Marca las velas con Momentum positivo. Momentum es una función que mide la velocidad del precio, 
    calculada como la diferencia entre el precio actual y el precio de hace N períodos (Length).
    👉 Si el Momentum es mayor que 0, la barra se pinta y se lanza una alerta. Si no, se usa NoPlot para no pintar nada.
    ❓ El Momentum de la barra actual es positivo? 
    Si la respuesta es sí, tenemos una barra con Momentum positivo.
    👉 Este PaintBar identifica velas que:
        - Tienen impulso alcista
        - Indican fuerza en la dirección actual
        - Suelen aparecer:
            > al inicio de tendencias alcistas
            > en rupturas al alza
            > durante rallies
        - Es una señal direccional, sugiere presión compradora.
}