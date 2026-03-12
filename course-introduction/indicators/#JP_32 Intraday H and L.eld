{Este indicador traza 2 líneas: el High y el Low para el día (sesión) a lo largo de la barra actual. 
Este indicador está pensado para usarse en gráficos de 24 horas.
}

Vars:
	DHigh(0),
	DLow(0);

If Time = SessionFirstBarTime(1, 1) Then
Begin
	DHigh = High;
	DLow = Low;
End 
Else Begin
	If High > DHigh Then
		DHigh = High;
	If Low < DLow Then
		DLow = Low;
	End; 

If DLow <> 0 Then 
Begin
	Plot1(DHigh, "DayHigh");
	Plot2(DLow, "DayLow");
End;

{🧠 Qué hace este indicador (visión global)
	Este indicador calcula y dibuja en el gráfico:
	📈 El máximo del día (Day High)
	📉 El mínimo del día (Day Low)
    Se reinician en la primera barra de cada sesión y se van actualizando barra a barra durante el día.
	DHigh(0) y DLow(0) empiezan en 0 (estado inicial “vacío”). Esto es muy importante para entender el If DLow <> 0 Then.
	
	SessionFirstBarTime(1,1) devuelve la hora de la primera barra de la sesión.
	Cuando el Time de la barra actual coincide con esa hora:
		Se considera inicio de un nuevo día
		Se inicializan los niveles:
			DHigh = High
			DLow = Low
	👉 En la primera vela del día, el máximo y mínimo del día son, lógicamente,	el High y Low de esa vela.
	En todas las barras después de la primera:
		Si el High actual supera el máximo del día → se actualiza DHigh
		Si el Low actual es menor que el mínimo del día → se actualiza DLow
	👉 Así se va arrastrando (tracking) el High y Low del día en tiempo real.
	
	DLow <> 0 Then
	❓ ¿Por qué existe esta condición?
	Porque al inicio del gráfico (o antes de que empiece la primera sesión válida): 
	DHigh = 0
	DLow = 0
		Y NO queremos dibujar líneas en 0, porque:
			0 no es un precio válido
			Provocaría líneas erróneas en el gráfico
			“Ensuciaría” la visualización
	✅ ¿Qué garantiza DLow <> 0?
		Que ya ha empezado una sesión
		Que DLow ha sido correctamente inicializado con un Low real
		Que los valores de DHigh y DLow son válidos
	👉 Es un filtro de seguridad muy habitual en EasyLanguage.
	👉“No dibujes nada hasta que tengas datos reales del día”.
		Antes de la primera barra → no sabemos el High ni el Low
		Después de la primera barra → ya podemos dibujar
		Por eso se usa DLow <> 0 y no directamente el Plot.
	❓¿Por qué se comprueba solo DLow <> 0 y no también DHigh?
	Ambos se inicializan a la vez
		Si DLow ya no es 0, DHigh tampoco lo será
		Es suficiente con una sola comprobación
}