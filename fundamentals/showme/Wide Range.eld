// Este ShowMe marca aquellas barras en las que el Range es mayor que el Range más grande de las 10 barras anteriores.

Input:
	TrlgBars(10);

If Range > Highest(Range, TrlgBars)[1] Then
Begin
	Plot1(Close, "WideRange");
	Alert;
End;

{	🧠 Un ShowMe NO dibuja líneas continuas, solo marca barras concretas cuando se cumple una condición. Se usa para:
		> detectar patrones
		> señalar eventos puntuales
		> resaltar velas especiales
	👉 Marca las velas con rango excepcionalmente grande. Range es una variable implícita que equivale a: High - Low
	
	👉 Se calcula el mayor rango de las últimas 10 barras excluyendo la barra actual [1], es CRÍTICO aquí:
		- Evita comparar la barra consigo misma
		- Evita repintado
		- Usa solo velas cerradas
	
	❓ El rango de la vela actual es mayor que cualquier rango de las últimas 10 velas anteriores? 
    Si la respuesta es sí, tenemos una Wide Range Bar.
	
	👉 Este ShowMe identifica velas que:
		- Tienen volatilidad inusualmente alta
		- Superan a todas las velas recientes
		- Suelen aparecer:
			> tras noticias
			> en rupturas
			> al inicio de tendencias
			> en capitulación o clímax
		- Es una señal contextual, no direccional.
}