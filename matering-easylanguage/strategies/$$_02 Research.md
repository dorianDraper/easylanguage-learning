# 1️⃣ Por qué los breakouts funcionan para trend following

Un breakout de un canal Donchian significa que el mercado está haciendo un nuevo máximo relativo.
Esto suele coincidir con tres fenómenos conocidos.

### 1️⃣ Momentum estructural

En mercados financieros existe el llamado momentum effect:

* activos que suben tienden a seguir subiendo

* activos que caen tienden a seguir cayendo

Este fenómeno fue documentado empíricamente en finanzas académicas por Narayan Jegadeesh y Sheridan Titman en su estudio sobre momentum en acciones. La idea central: los movimientos tienden a persistir

### 2️⃣ Stop clusters

Los máximos y mínimos recientes suelen contener órdenes stop acumuladas. Cuando el precio rompe un máximo:

* se ejecutan stops de posiciones cortas

* se activan órdenes de breakout

Esto crea flujo de órdenes adicional en la misma dirección.

### 3️⃣ Liquidez y breakout continuation

En microestructura de mercado:

* los máximos atraen liquidez agresiva

* los algoritmos detectan rupturas de rango

Esto produce continuación del movimiento.

# 2️⃣ Por qué el Donchian invertido falla como mean reversion

El sistema original aquí estudiado entra largo Buy cuando rompe mínimo y corto Short cuando rompe máximo

Esto intenta capturar exhaustion moves. El problema es que:

### 1️⃣ los extremos suelen ser el inicio del movimiento

Muchos movimientos fuertes comienzan precisamente con breakout de rango. Por tanto el sistema contrarian entra contra el inicio de la tendencia.

### 2️⃣ no hay señal de reversión

La ruptura del canal solo indica nuevo extremo, no indica reversión. Por eso los sistemas mean reversion suelen requerir confirmación de agotamiento.

# 3️⃣ Evidencia empírica

Los sistemas Donchian fueron popularizados por Richard Donchian y posteriormente por el sistema Turtle desarrollado por Richard Dennis.

Estos sistemas eran explícitamente trend following. Ejemplo clásico: Buy breakout de 20 días, Sell breakout de 20 días. Los sistemas contrarian sobre breakouts raramente funcionan sin filtros adicionales.

# 4️⃣ Qué hacen los quants para mejorar estos sistemas

Los desarrolladores cuantitativos añaden filtros para distinguir entre: breakout genuino vs exhaustion move

Los más comunes son los siguientes.

### 4️⃣1 Filtro de volatilidad

Muchos breakouts falsos ocurren cuando la volatilidad es baja. Un filtro típico:

* solo operar si ATR > media ATR

Esto evita mercados laterales.

### 4️⃣2 Filtro de régimen de tendencia

Muchos sistemas mean reversion funcionan solo en mercados laterales. Un filtro común:

* ADX < threshold

Esto evita operar contra tendencias fuertes.

### 4️⃣3 Confirmación de reversión

Los sistemas contrarian suelen requerir que el precio regrese dentro del canal. Ejemplo:

* Low < DonchianLow y Close > DonchianLow

Esto indica rechazo del nivel.

### 4️⃣4 Filtro de sobreextensión

Muchos quants usan indicadores de sobrecompra / sobreventa. Ejemplos:

* RSI
* z-score
* distance from moving average

Ejemplo: RSI < 20

### 4️⃣5 Filtro de volumen

Los extremos reales suelen ir acompañados de picos de volumen. Ejemplo:

* Volume > AvgVolume

# 5️⃣ Ejemplo de mejora simple del sistema

Una mejora típica sería exigir rechazo del extremo. En lugar de:

Low < DonchianLow

usar:

Low < DonchianLow and Close > DonchianLow

Esto significa: el mercado intentó romper pero fue rechazado, esto ya es una señal de reversión.

# 6️⃣ Otra mejora muy común: z-score del precio

Muchos sistemas mean reversion usan desviación respecto a la media.

z = Price - MA / StdDev

Operar solo si: Z < -2

Esto asegura extremo estadístico real.

# 7️⃣ Qué edge intenta capturar realmente tu sistema

El sistema original intenta capturar short term exhaustion, pero sin filtros lo que detecta es inicio de momentum. Por eso el sistema mejora al invertirlo.

# 8️⃣ Resumen conceptual
Estrategia	         señal
trend following	     breakout
mean reversion	     rejection

El sistema original usaba breakout para mean reversion, lo cual es contradictorio.

# 9️⃣ Una modificación interesante el sistema

Una versión más robusta sería:

1. detectar breakout
2. esperar rechazo
3. entrar

Esto es exactamente lo que muchos quants llaman: failed breakout strategy