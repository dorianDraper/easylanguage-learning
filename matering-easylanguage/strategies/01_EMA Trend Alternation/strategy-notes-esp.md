## Descripción estrategia
Esta estrategia entra en la dirección de la tendencia determinada por dos medias móviles exponenciales. El objetivo de beneficios y los niveles de stop loss están a n puntos del precio de entrada, establecidos mediante inputs. La estrategia introduce varios conceptos como cooldown tras salida, dependencia del trade previo, uso explícito de EntryPrice, y gestión simétrica long/short.


**🧩Tipo de estrategia**</br>
	📈 Trend-following</br>
	⚡ Basada en EMAs</br>
	⏱️ Con cooldown tras salida</br>
	🎯 Gestión fija por puntos</br>
	🔁 Alterna dirección (evita reentrar en la misma)</br>

👉No es un simple EMA cross, es un trend alternator con memoria del último trade.

**🧠Resumen mental**</br>
*“Sigo la tendencia marcada por las EMAs. No reentro inmediatamente tras salir. Solo vuelvo a entrar cuando el mercado ha respirado y lo hago en la dirección opuesta al último trade. Cada trade tiene un riesgo y un objetivo fijos desde el inicio.”*

**🚀Setup de entrada**</br>
	📈 Largo: EMAs alineadas al alza + último trade fue corto o es el primer trade</br>
	📉 Corto: EMAs alineadas a la baja + último trade fue largo o es el primer trade</br>

**🧩Regla de oro para salidas**</br>
	🔹Si el precio de salida está “mejor” que el precio actual → LIMIT</br>
	🔹Si el precio de salida está “peor” que el precio actual → STOP</br>

**📈Salidas de una posición LARGA**</br>
	🎯 Take Profit (TP): Orden limit es "véndeme a este precio o mejor (encima precio entrada)</br>
	🛑 Stop Loss (SL): Orden stop sería "si el mercado llega aquí, ejecútame si o sí si el precio cae" (precio está por debajo del nivel actual)</br>

**📉Salidas de una posición CORTA**</br>
	🎯 Take Profit (TP): limit es "cómprame a este precio o mejor", mercado baja y usamos orden limit, compramos más barato</br>
	🛑 Stop Loss (SL): stop está por encima precio actual "si el precio llega aquí, ejecútame ya"</br> 

Referenciamos a EntryPrice +/- X porque define el riesgo/beneficio desde la entrada.
👉“Gano si el mercado va a mi favor → espero con LIMIT. Pierdo si va en mi contra → me protejo con STOP.”
