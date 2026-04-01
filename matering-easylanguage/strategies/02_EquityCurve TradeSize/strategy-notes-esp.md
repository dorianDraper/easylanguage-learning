## Descripción estrategia
Sistema anti-tendencial que opera un canal de 21 barras de máximos/mínimos y sale del mercado mediante objetivo de ganancia o stop loss utilizando funciones de stop predefinidas. El tamaño de los trades se incrementa o disminuye según el rendimiento de la estrategia.

👉 Es una estrategia que opera contra-tendencial pero ajusta agresividad según equity y usa position sizing adaptativo. Esto se basa en la hipótesis de que movimientos extremos tienden a revertir.

**🧩 Tipo de estrategia**</br>
	📉 Mean reversion / contrarian</br>
	📊 Basada en canal Donchian</br>
	🔁 Entrada en extremos</br>
	💰 Position sizing adaptativo por equity</br>
	🛑 Salidas por: stop fijo, target fijo</br>

**🧠 Resumen mental (clave)**</br>
*“Cuando el mercado hace un extremo nuevo, entro en contra esperando reversión. Si el sistema va bien, aumento tamaño. Si va mal, reduzco exposición. Cada trade arriesga siempre la misma unidad.”*

**🔑 Bloque clave: uso de NetProfit**</br>
NetProfit es una palabra reservada de EasyLanguage que representa el beneficio o pérdida acumulada  de la estrategia desde el primer trade hasta ahora. Incluye: ganancias, pérdidas, comisiones (si están activadas)
👉 No es el profit del trade actual, es el equity curve del sistema

**🧠 Qué está haciendo este bloque?**</br>
Ejemplo práctico: ProfitStopLoss = 500:

| NetProfit        | NetProfit/500     | Round             |  Ajuste        |
| ---------------- | ----------------  | ----------------  |----------------| 
|   +500           |      1            |       1           |     +100       |
|   +1000          |      2            |       2           |     +200       |
|   +1200          |      2.4          |       2           |     +200       |
|   -500           |     -1            |      -1           |     -100       |
|   -1000          |     -2            |      -2           |     -200       |
|   -1300          |     -2.6          |      -3           |     -300       |


👉 El tamaño de la posición: crece si el sistema va bien, disminuye si va mal. Esto es position sizing basado en equity, muy potente… y peligroso si no se controla.</br>

🚀 Setup de entrada</br> 
Canal Donchian clásico máximo/mínimo 21 barras anteriores, excluimos la actual [1] para evitar usar información de la barra actual.</br>
    🔹Compra cuando el mercado hace un nuevo mínimo</br>
    🔹Vende en corto cuando el mercado hace un nuevo máximo</br>
Las entradas son con tamaño dinámico pues no es fijo, esto es money management activo.</br>

🛑 Setup salida</br>  
Utilizamos gestión del riesgo mediante funciones predefinidas, se aplican automáticamente y están ligadas al EntryPrice, funcionan con MarketPosition, no hace falta escribir IsLong...el motor lo gestiona. Sale con:</br>
    🔹stop loss fijo</br>
    🔹profit target fijo</br>
    🔹Ajusta dinámicamente el tamaño de la posición según el rendimiento acumulado de la estrategia (NetProfit)</br>

## Notas 
* Si invertimos el setup (entro largo cuando hace nuevo High y corto cuando hace nuevo low, la estrategia tiene mejor equity)