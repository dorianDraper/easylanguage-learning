# RSI Momentum Fade — v1.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

RSI Momentum Fade es una estrategia de mean-reversion que usa el RSI no como indicador de sobrecompra/sobreventa en el sentido clásico, sino como detector de agotamiento de momentum. En lugar de entrar cuando el RSI alcanza niveles extremos (70/30), la estrategia entra cuando el RSI está a un lado del nivel 50 — indicando sesgo direccional — pero ha dejado de marcar nuevos extremos en la ventana de lookback reciente. Este patrón de "enfriamiento" sugiere que el impulso direccional se está desvaneciendo, creando una oportunidad de reversión potencial antes de que el RSI cruce de nuevo a través de 50.

La estrategia usa un framework de salida de tres capas: un stop loss inicial para protección inmediata, un break even que elimina el riesgo una vez que la operación muestra beneficio inicial, y un trailing stop en dólares que captura el resto del movimiento si el momentum continúa.

---

## Mecánica Central

### 1. Cálculo del RSI

```pascal
xRSI = RSI(Price, Length);
```

`RSI` es la función nativa de EasyLanguage para el Relative Strength Index. El período por defecto de 14 barras es el ajuste RSI clásico de Wilder, midiendo la ratio de ganancias medias sobre pérdidas medias durante la ventana de lookback. El prefijo `x` en `xRSI` es una convención de nomenclatura que distingue la variable calculada del nombre de la función nativa.

### 2. El Nivel 50 como Frontera de Momentum

La estrategia usa RSI 50 como línea divisoria entre momentum alcista y bajista — un uso conceptualmente diferente a los umbrales clásicos de sobrecompra/sobreventa del 70/30:

- **RSI > 50:** Las ganancias medias recientes superan las pérdidas medias recientes — el momentum neto es alcista.
- **RSI < 50:** Las pérdidas medias recientes superan las ganancias medias recientes — el momentum neto es bajista.

El nivel 50 no es una señal por sí mismo. Establece el contexto direccional: la estrategia busca reversiones desde *dentro* de la zona bajista (RSI < 50, se esperan entradas largas) y desde *dentro* de la zona alcista (RSI > 50, se esperan entradas cortas).

### 3. Filtro de Entrada — `LowestBar` y `HighestBar`

Esta es la lógica central de la señal:

```pascal
If xRSI < 50 and LowestBar(xRSI, 7) >= 3 Then
    Buy Next Bar at Market;
If xRSI > 50 and HighestBar(xRSI, 7) >= 3 Then
    SellShort Next Bar at Market;
```

`LowestBar(series, N)` devuelve el offset (barras atrás) del valor más bajo en `series` durante las últimas `N` barras. `HighestBar(series, N)` hace lo mismo para el valor más alto.

**Para la entrada larga:** `LowestBar(xRSI, 7) >= 3` significa que la lectura más baja del RSI en las últimas 7 barras ocurrió hace al menos 3 barras — el RSI no ha marcado un nuevo mínimo en las últimas 3 barras. Combinado con `xRSI < 50`, esto significa: el RSI está en territorio bajista, pero su punto más débil fue hace varias barras. El impulso bajista se ha enfriado.

**Ejemplo concreto de los comentarios del código:**

```
Offset de barra:   6    5    4    3    2    1    0   ← barra actual
RSI:              42   38   35   30   33   37   41

LowestBar(xRSI, 7) = 3   (RSI mínimo de 30 ocurrió hace 3 barras)
Condición: LowestBar >= 3 → True ✓
Lectura: "El RSI está por debajo de 50, pero el punto más débil fue 
          hace 3 barras — el impulso bajista se ha absorbido y puede 
          estar revirtiendo."
```

**¿Por qué `>= 3`?** El umbral está calibrado para equilibrar precisión de timing y calidad de señal:
- `>= 1` o `>= 2`: demasiado cerca del extremo, el movimiento puede seguir en marcha.
- `>= 3`: un período de enfriamiento práctico — el RSI ha tenido tiempo de estabilizarse sin haberse alejado tanto de su extremo que la oportunidad de reversión haya pasado.
- `>= 5` o más: la señal puede llegar demasiado tarde, con la reversión ya parcialmente desarrollada.

Tres barras es un equilibrio deliberado — ni impulsivo, ni tardío.

**Lógica corta simétrica:** `HighestBar(xRSI, 7) >= 3` con `xRSI > 50` aplica el mismo razonamiento al lado bajista: el RSI está en territorio alcista, pero su pico fue hace al menos 3 barras — el impulso alcista se está desvaneciendo.

### 4. Framework de Salida — Gestión de Riesgo en Tres Capas

```pascal
SetStopLoss(StopAmt);
SetBreakeven(BEAmt);
SetDollarTrailing(TrlgAmt);
```

Las tres funciones de salida operan en secuencia, creando una estructura de reducción progresiva del riesgo:

**Capa 1 — Stop Loss (`SetStopLoss`):**
Activo inmediatamente desde la entrada. Si la operación se mueve contra la posición en `StopAmt` dólares, la posición se cierra. Esta es la pérdida máxima que la estrategia acepta en cualquier operación.

**Capa 2 — Break Even (`SetBreakeven`):**
Una vez que la operación alcanza una ganancia de `BEAmt` dólares, el stop loss se mueve al precio de entrada. A partir de ese momento, la operación no puede perder — el peor resultado es una salida en breakeven. Los valores por defecto (`StopAmt = $50`, `BEAmt = $50`) significan que el break even se activa al mismo importe en dólares que el stop — en el momento en que la operación ha mostrado $50 de beneficio, el riesgo se elimina completamente.

**Capa 3 — Trailing Stop en Dólares (`SetDollarTrailing`):**
Un trailing stop que sigue el precio a una distancia fija en dólares (`TrlgAmt = $100`). A medida que la operación se mueve a favor, el trailing stop sube (para largos) o baja (para cortos), bloqueando progresivamente más beneficio. El trailing stop solo se mueve en la dirección rentable — nunca se amplía.

**Interacción entre capas:** Las tres están activas simultáneamente una vez que hay posición abierta. La secuencia que gobierna el comportamiento:

1. Si el precio se mueve contra la operación inmediatamente: el **Stop Loss** se activa en `StopAmt`.
2. Si el precio primero alcanza `BEAmt` de beneficio: el **Break Even** mueve el stop al precio de entrada. El nivel de Stop Loss ya es irrelevante — el suelo es el precio de entrada.
3. Desde ese punto, el **Trailing Stop** sigue el precio a `TrlgAmt` de distancia, bloqueando beneficio por encima del suelo de break even.

Esta estructura significa que la operación tiene tres estados de salida posibles:
- **Pérdida máxima:** −`StopAmt` (si la operación nunca alcanza el break even).
- **Breakeven:** $0 (si la operación alcanza `BEAmt` y luego revierte hasta la entrada antes de que el trailing stop haya subido por encima de ella).
- **Beneficio variable:** Capturado por el trailing stop, que puede crecer teóricamente sin límite mientras el precio siga moviéndose.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `Price` | `Close` | Serie de precio usada para el cálculo del RSI. |
| `Length` | 14 | Período de lookback del RSI. |
| `StopAmt` | $50 | Stop loss inicial en dólares. Pérdida máxima por operación. |
| `BEAmt` | $50 | Ganancia en dólares a la que el stop se mueve al precio de entrada (break even). |
| `TrlgAmt` | $100 | Distancia del trailing stop en dólares una vez que la posición es rentable. |

**Sobre los parámetros de riesgo por defecto:** Los $50 de stop y los $100 de trailing están calibrados para precios de acciones. Para contratos de futuros, deben escalarse al `BigPointValue` del instrumento. Para futuros ES a $50/punto, un stop de $50 equivale a 1 punto — demasiado ajustado para cualquier stop significativo en una estrategia RSI de 14 barras. Ajustar proporcionalmente.

**Sobre `BEAmt = StopAmt`:** Establecer el break even al mismo importe en dólares que el stop crea una estructura inicial simétrica: la operación arriesga $50 antes del break even y $0 después. Este es un enfoque conservador — en el momento en que aparece cualquier beneficio igual al riesgo inicial, el riesgo se elimina completamente.

**Sobre `TrlgAmt > StopAmt`:** La distancia del trailing ($100) es más amplia que el stop inicial ($50). Esto es intencional — el trailing stop está diseñado para dar margen a la operación tras el momentum inicial, en lugar de cerrarse por fluctuaciones normales de precio durante un movimiento favorable.

---

## Escenarios de Operación

### Escenario A — Entrada Larga, Break Even, Salida por Trailing

- Secuencia de RSI en las últimas 7 barras: 48, 44, 39, 34, 37, 40, 43. `xRSI = 43 < 50` ✓
- `LowestBar(xRSI, 7) = 3` (RSI de 34 ocurrió hace 3 barras) ✓
- Entrada: **Buy Next Bar at Market**. Ejecución a 45,80.
- `SetStopLoss($50)` activo. Stop al equivalente de entrada − $50.
- La operación avanza. A +$50 de ganancia: **Break Even** activa. Stop se mueve al precio de entrada.
- La operación continúa avanzando. Trailing stop a $100 por debajo del máximo acumulado.
- El precio alcanza +$180 y luego revierte. Trailing stop en +$80 sobre la entrada se activa.
- Salida con aproximadamente +$80 de beneficio.

### Escenario B — Entrada Larga, Stop Loss Antes del Break Even

- Misma entrada a 45,80. Stop en −$50.
- La operación se mueve inmediatamente contra la posición. La pérdida alcanza $50.
- **Stop Loss** se activa. Salida con −$50.

### Escenario C — Entrada Corta, Impulso Ya en su Pico

- Secuencia de RSI: 54, 58, 63, 67, 65, 61, 57. `xRSI = 57 > 50` ✓
- `HighestBar(xRSI, 7) = 3` (RSI de 67 ocurrió hace 3 barras) ✓
- Entrada: **SellShort Next Bar at Market**.
- El RSI alcanzó su pico hace 3 barras — el impulso alcista ya se ha enfriado. Se anticipa reversión.

### Escenario D — Señal Bloqueada (RSI Aún Marcando Nuevos Extremos)

- Secuencia de RSI: 48, 44, 39, 35, 32, 30, 28. `xRSI = 28 < 50` ✓
- `LowestBar(xRSI, 7) = 0` (la barra actual es el nuevo mínimo) → `0 >= 3` es **False** ✗
- Entrada bloqueada. El RSI sigue marcando nuevos mínimos — el impulso bajista está activo, no desvanecido.
- La estrategia espera correctamente a que el impulso pause antes de entrar.

---

## Características Clave

- **RSI como detector de agotamiento de momentum:** La estrategia usa RSI 50 como frontera de momentum en lugar de 70/30 como umbrales de sobrecompra/sobreventa — un enfoque menos común pero estructuralmente sólido que se centra en la *dirección* del sesgo más que en la *extremidad*.
- **`LowestBar`/`HighestBar` como filtros temporales:** Estas funciones identifican cuándo ocurrió la lectura más extrema del RSI, filtrando entradas que llegan mientras el impulso sigue acelerando versus entradas que esperan un período de enfriamiento medido.
- **Requisito de enfriamiento de tres barras:** El umbral `>= 3` equilibra el timing de entrada — suficientemente temprano para capturar la reversión, suficientemente tarde para confirmar que el impulso ha pausado.
- **Reducción progresiva del riesgo:** Stop loss → break even → trailing stop crea una estructura donde el máximo riesgo a la baja está acotado, el riesgo inicial se elimina rápidamente y el potencial alcista es teóricamente ilimitado.
- **Órdenes a mercado para simplicidad:** Las entradas a mercado en la siguiente barra priorizan la certeza de ejecución sobre la optimización del precio de entrada — apropiado para una primera versión centrada en el estudio de la señal más que en el refinamiento de la ejecución.

---

## Psicología del Trading

Esta estrategia encarna una creencia específica sobre el momentum: **los impulsos se agotan antes de revertir.** Un RSI tendencial que sigue marcando nuevos extremos es una señal de que la convicción direccional sigue siendo fuerte. Pero un RSI que está a un lado de 50 pero ha dejado de empujar a nuevos extremos está mostrando la firma temprana del agotamiento — el movimiento direccional está presente pero decelerando.

El umbral `>= 3` codifica un principio de paciencia: *"no entro en el momento en que veo señales de agotamiento. Espero unas barras para confirmar que la desaceleración no es simplemente ruido."* Esto no es confirmación en el sentido clásico — el RSI no ha cruzado 50, la tendencia no ha revertido — pero es una pausa medida que reduce la frecuencia de entrar durante impulsos aún activos.

La salida en tres capas refleja una progresión de la filosofía de gestión de operaciones. El stop loss dice: *"podría estar equivocado — esto es cuánto acepto estar equivocado."* El break even dice: *"una vez que la operación ha demostrado ser correcta con beneficio inicial, no dejaré que se convierta en pérdida."* El trailing stop dice: *"no sé hasta dónde llegará esto — dejaré que el mercado decida y protegeré lo que me dé."* Juntos crean un sistema donde la pérdida máxima del trader es conocida y fija, pero el beneficio máximo es abierto.

La conexión con el framework TPS (Trading Pullback System) de Connors es el siguiente paso natural: TPS añade ranking del RSI durante múltiples barras, confirmación de tendencia, y una salida basada en conteo en lugar de un trailing stop en dólares — aportando más estructura al timing de entrada y la gestión de salidas mientras preserva el concepto central de agotamiento de momentum explorado aquí.

---

## Casos de Uso

**Instrumentos:** La señal de agotamiento de momentum RSI es aplicable a cualquier instrumento líquido con momentum de precio medible — futuros de índices de renta variable (ES, NQ), acciones individuales, futuros de materias primas y futuros FX. El RSI de 14 períodos requiere historial de barras suficiente; los marcos temporales más cortos pueden producir más ruido en el cálculo del RSI.

**Marcos temporales:** El RSI de 14 barras en barras diarias representa dos semanas de trading de medición de momentum; en barras de 60 minutos representa 14 horas. El enfriamiento de `>= 3` barras debe interpretarse en relación al marco temporal — 3 barras diarias es una estabilización significativa; 3 barras de un minuto pueden ser ruido.

**Como primera versión:** Esta estrategia está explícitamente etiquetada como v1 y está diseñada para estudio y backtesting en lugar de despliegue en producción. Las entradas a mercado, la ausencia de filtros de tendencia adicionales, y los umbrales hardcodeados de 7 barras y 3 barras son todos puntos de partida para iteración. Una v2 natural parametrizaría los valores de lookback y enfriamiento, añadiría un filtro de tendencia en timeframe superior, y potencialmente reemplazaría las órdenes a mercado por órdenes límite para mejor precisión de entrada.

**Conexión con TPS de Connors:** La estructura RSI-por-debajo-de-50 más agotamiento de momentum mapea directamente al concepto TPS de entrar en retrocesos dentro de una tendencia tras que el RSI haya alcanzado un nivel bajo y comience a recuperarse. El vínculo conceptual clave es el mismo: no entres mientras el momentum se acelera en tu contra; entra cuando pause. El desarrollo futuro de esta estrategia en el repositorio de investigación debería testear explícitamente la variante RSI de Connors (período 2) y la salida basada en conteo como alternativa al trailing stop en dólares.
