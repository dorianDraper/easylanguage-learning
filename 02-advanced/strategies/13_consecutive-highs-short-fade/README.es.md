# Consecutive Highs Short Fade — v1.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Consecutive Highs Short Fade es una estrategia de mean-reversion solo en corto que entra en una posición corta tras un número configurable de barras consecutivas haciendo cada una un máximo más alto que la barra anterior. Es la inversa direccional de la estrategia integrada `ConsecutiveUps LE` de TradeStation — donde el original entra largo en fortaleza consecutiva, esta versión fadea esa fortaleza con una entrada corta. La estrategia introduce órdenes ECN de pegging para ejecución en vivo, usando `InsideAsk` y `SetPeg(pegbest)` para apuntar al mejor precio disponible en el libro de órdenes en lugar de un precio límite fijo. En backtesting, una orden límite basada en el cierre aproxima el comportamiento en vivo.

La estrategia no tiene reglas de salida por diseño — es un mecanismo de entrada enfocado pensado para combinarse con componentes externos de stop loss, objetivo de beneficio o trailing stop.

---

## Mecánica Central

### 1. Contador de Máximos Consecutivos

```pascal
If Price > Price[1] Then
    UpCount = UpCount + 1
Else
    UpCount = 0;
```

`Price` por defecto es `High` — la estrategia rastrea si el máximo de cada barra supera el de la barra anterior. `UpCount` incrementa en uno en cada barra que califica y se resetea a cero en el momento en que cualquier barra no logra hacer un nuevo máximo. Esto es idéntico en estructura al contador `HighsCount` en Consecutive Extremes Fade, pero aplicado únicamente al lado alcista como setup para una entrada de fade corto.

Con `ConsecutiveBarsUp = 3`, la condición de entrada `UpCount >= 3` requiere tres barras consecutivas haciendo cada una un máximo más alto. El contador no requiere que los máximos superen un nivel a más largo plazo — solo que el máximo de cada barra supere el de la barra inmediatamente anterior. Esto detecta rachas de momentum direccional a corto plazo, no rupturas de canal.

### 2. Cálculo del Tamaño de Tick

```pascal
MinMvs = Minmove / PriceScale * MinMoves;
```

`Minmove` y `PriceScale` son constantes reservadas de EasyLanguage que juntas definen el movimiento de precio mínimo (un tick) para el instrumento actual:

- `Minmove`: el numerador de la expresión del tamaño de tick (p. ej. 25 para futuros ES, donde los ticks son 0,25 puntos).
- `PriceScale`: el denominador (p. ej. 100 para ES, dando `25/100 = 0,25` puntos por tick).
- `Minmove / PriceScale`: el valor de un tick en términos de precio.

Multiplicar por `MinMoves` (por defecto: 5) da una distancia de 5 ticks. Este cálculo hace el offset agnóstico al instrumento — el mismo `MinMoves = 5` produce la distancia correcta de 5 ticks para futuros ES, NQ o cualquier otro instrumento sin hardcodear un importe en dólares o puntos.

**Ejemplo para futuros ES:**
- `Minmove = 25`, `PriceScale = 100` → un tick = 0,25 puntos.
- `MinMvs = 0,25 × 5 = 1,25 puntos` por debajo de `InsideAsk`.

### 3. Ruta de Ejecución Dual — En Vivo vs Histórico

La estrategia usa lógica de ejecución diferente dependiendo de si la barra es en vivo o histórica:

```pascal
If UpCount >= ConsecutiveBarsUp Then
Begin
    If LastBarOnChart Then
    Begin
        SetPeg(pegbest);
        SellShort ("ConsUpSE") Next Bar at InsideAsk - MinMvs Limit;
        SetPeg(pegdisable);
    End Else
    Begin
        SellShort ("ConsUpSEh") Next Bar at Close Limit;
    End;
End;
```

**Barra en vivo (`LastBarOnChart = True`):**

`SetPeg(pegbest)` activa el pegging ECN antes de colocar la orden. Con el pegging activo, el precio límite está anclado dinámicamente al mejor precio disponible en el libro de órdenes en lugar de un precio fijo calculado al cierre de la barra. `InsideAsk - MinMvs` coloca el límite corto `MinMvs` ticks por debajo del inside ask actual — el precio de venta más bajo disponible actualmente en el mercado. La orden se envía como un límite peg-best, y luego `SetPeg(pegdisable)` desactiva el pegging para las órdenes posteriores en la misma evaluación de barra.

**¿Por qué `InsideAsk - MinMvs` para un corto?** Para una entrada corta, vender al inside ask significa entrar al mejor precio disponible que puede recibir un vendedor. Restar `MinMvs` ticks coloca el límite ligeramente por debajo del ask actual — la orden solo se ejecutará si el precio cae a ese nivel, proporcionando una entrada marginalmente mejor que golpear directamente el ask actual. Esta es una entrada corta agresiva pero controlada: no persigue el mercado, pero tampoco requiere un retroceso significativo para ejecutarse.

**Barra histórica (`LastBarOnChart = False`):**

`InsideAsk` no existe en barras históricas — es un valor del libro de órdenes en tiempo real. La estrategia recurre a `Close` como precio límite para el backtesting. La etiqueta de orden `"ConsUpSEh"` (la `h` final indicando histórico) distingue las ejecuciones de backtesting de las en vivo en los informes de TradeStation, permitiendo un análisis separado de la calidad de ejecución histórica versus en vivo.

### 4. Pegging ECN — `SetPeg`

`SetPeg` es una función de EasyLanguage que controla el comportamiento de enrutamiento de órdenes para brokers compatibles con ECN:

- `SetPeg(pegbest)`: instruye al broker a pegar la orden al mejor bid o ask en el libro de órdenes. A medida que el precio interior se mueve, la orden de peg se ajusta dinámicamente — esto es diferente de una orden límite estándar, que permanece fija en el precio enviado.
- `SetPeg(pegdisable)`: desactiva el pegging, restaurando el comportamiento de orden estándar para las órdenes posteriores.

La llamada `SetPeg` envuelve únicamente la orden de entrada corta específica. Cualquier otra orden colocada después de `SetPeg(pegdisable)` se comporta como órdenes límite o a mercado estándar.

**Importante:** `SetPeg` no tiene efecto en backtesting — es una instrucción de ejecución en vivo. TradeStation la ignora durante la simulación histórica, razón por la que la estrategia usa la separación de rama `LastBarOnChart`.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `Price` | `High` | Serie de precio usada para detectar barras consecutivas más altas. |
| `ConsecutiveBarsUp` | 3 | Número mínimo de valores `Price` consecutivos más altos requeridos para activar una entrada corta. |
| `MinMoves` | 5 | Número de ticks por debajo de `InsideAsk` para el precio de la orden límite en vivo. |

**Sobre `ConsecutiveBarsUp`:** Tres máximos consecutivos más altos es la racha mínima significativa para una entrada de fade. En `= 2`, la señal se activa con mucha frecuencia y puede capturar demasiada oscilación intradiaria normal. En `= 4` o `= 5`, la señal se vuelve más rara pero potencialmente más fiable al requerir una racha de momentum más sostenida antes de fadear.

**Sobre `MinMoves`:** El offset basado en ticks proporciona una pequeña mejora de precio sobre entrar directamente en `InsideAsk`. Un valor de 5 ticks es un punto de partida práctico — suficientemente pequeño para ejecutarse con frecuencia razonable, suficientemente grande para proporcionar una mejora de entrada medible. En instrumentos de alta liquidez (ES, NQ), 5 ticks es una distancia muy pequeña y se ejecuta rápidamente. En instrumentos menos líquidos, puede requerir un movimiento intrabarra más significativo para ejecutarse.

---

## Escenarios de Operación

### Escenario A — Entrada Corta en Vivo Tras Tres Máximos Consecutivos

```
Barra:    1      2      3      4
High:   46,20  46,45  46,68  46,90
UpCount:   1      2      3      4
```

- Barra 4: `UpCount = 4 >= ConsecutiveBarsUp (3)`. Señal activada.
- `LastBarOnChart = True`. Ruta de ejecución en vivo.
- `InsideAsk = 46,92`. `MinMvs = 0,25 × 5 = 1,25` (ejemplo ES).
- `SetPeg(pegbest)` se activa.
- Límite corto colocado en `46,92 − 1,25 = 45,67`. *(Nota: en la práctica MinMvs sería mucho menor — este ejemplo usa un valor amplio para ilustración.)*
- `SetPeg(pegdisable)`.
- Siguiente barra: el precio cae hasta el nivel de ejecución. Corto ejecutado.

### Escenario B — Entrada Corta Histórica (Backtesting)

- Mismo setup. `LastBarOnChart = False`.
- `SetPeg` no se llama. Sin acceso a `InsideAsk`.
- Límite corto colocado en `Close` de la barra de señal.
- Orden etiquetada `"ConsUpSEh"` para diferenciación de ejecuciones en vivo.

### Escenario C — Racha Rota, Sin Entrada

```
Barra:    1      2      3
High:   46,20  46,45  46,38
UpCount:   1      2      0
```

- Barra 3: `High (46,38) < High[1] (46,45)`. `UpCount` se resetea a 0.
- Racha rota en la barra 3. No se activa ninguna entrada a pesar de dos máximos consecutivos más altos en las barras 1–2.

### Escenario D — Entrada Activada, Sin Salida (Diseño Solo de Entrada)

- Se abre posición corta. No hay stop loss ni objetivo de beneficio definido en esta estrategia.
- La posición permanece abierta hasta que un componente de salida externo la cierre, o se coloque una salida manual.
- Esto confirma la intención de diseño solo de entrada — esta estrategia debe combinarse con un componente de gestión del riesgo para uso en vivo.

---

## Características Clave

- **Pegging ECN para ejecución en vivo:** `SetPeg(pegbest)` + `InsideAsk` apunta al mejor precio disponible del libro de órdenes dinámicamente en lugar de un nivel fijo basado en el cierre, proporcionando una ejecución de entrada en vivo más precisa.
- **Cálculo de distancia basado en ticks:** `Minmove / PriceScale * MinMoves` hace el offset límite agnóstico al instrumento, adaptándose automáticamente a la estructura de ticks de cualquier contrato de futuros sin parámetros hardcodeados.
- **Ruta de ejecución dual:** La lógica de órdenes separada para en vivo e histórico permite un backtesting realista (usando `Close` como proxy) mientras preserva la ejecución ECN avanzada para trading en vivo.
- **Etiquetas de orden con sufijo:** `"ConsUpSE"` para ejecuciones en vivo y `"ConsUpSEh"` para históricas permite el análisis de rendimiento separado de cada ruta en los informes operación por operación de TradeStation.
- **Dirección solo en corto:** La estrategia fadea exclusivamente rachas alcistas con entradas cortas — es la inversa direccional de la estrategia integrada `ConsecutiveUps LE`.
- **Sin salidas por diseño:** La estrategia es únicamente un componente de entrada, pensado para combinarse con lógica de stop loss, objetivo de beneficio o trailing stop de otros componentes.

---

## Psicología del Trading

Consecutive Highs Short Fade codifica una creencia específica sobre el mercado: **una racha de máximos consecutivos más altos representa sobreextensión de momentum a corto plazo, no el inicio de una tendencia sostenida.** Donde una estrategia de seguimiento de tendencia ve tres máximos consecutivos más altos como confirmación de un movimiento que vale la pena unirse, esta estrategia ve el mismo patrón como una oportunidad de fadear — el movimiento ya ha ocurrido y es más probable que pause o revierta que que acelere.

Esta es una postura fundamentalmente contraria. El desafío psicológico es entrar corto precisamente cuando el mercado está haciendo nuevos máximos sucesivos — cuando cada barra parece confirmar que los compradores tienen el control. El edge de la estrategia, si existe, proviene de la tendencia estadística de las rachas de momentum a corto plazo a agotarse a nivel de barra antes de que se produzca una mean-reversion.

El mecanismo de pegging ECN añade una capa de sofisticación de ejecución que refleja la intención de diseño de la estrategia. Una orden a mercado en el pico de una racha de momentum cedería edge significativo a la selección adversa — entrando al peor precio posible en un mercado aún en movimiento. La orden límite peg-best en `InsideAsk - MinMvs` busca un precio ligeramente mejor mientras permanece lo suficientemente cerca del mercado para ejecutarse con alta probabilidad. Es una entrada agresiva que no persigue, pero tampoco requiere una reversión significativa para ejecutarse.

La ausencia de salidas es también una declaración psicológica: la estrategia no pretende saber hasta dónde llegará la reversión ni cuándo tomar beneficios. Se centra enteramente en la señal de entrada, delegando la decisión de salida en componentes separados y de propósito específico. Esta separación de responsabilidades permite que cada componente se teste y optimice independientemente.

---

## Casos de Uso

**Instrumentos:** Diseñada para contratos de futuros líquidos donde el enrutamiento de órdenes ECN y los datos de `InsideAsk` están disponibles — ES, NQ y otros futuros de índices de renta variable activamente negociados durante el horario regular de trading. El cálculo `MinMoves` basado en ticks se adapta a la estructura de ticks de cualquier instrumento. En instrumentos menos líquidos, el límite `InsideAsk - MinMvs` puede no ejecutarse de forma fiable durante el trading en vivo.

**Marcos temporales:** El patrón de máximos consecutivos más altos es relativo al marco temporal. En barras de 1 minuto, tres máximos consecutivos más altos abarca tres minutos; en barras de 15 minutos abarca 45 minutos. El marco temporal apropiado depende de la hipótesis de mean-reversion que se esté testando — agotamiento de momentum muy a corto plazo versus fades de tendencia de múltiples barras son ideas de trading diferentes que requieren calibración de marco temporal diferente.

**Integración con componentes de riesgo:** Esta estrategia debe combinarse con un componente de salida antes del despliegue en vivo. Las combinaciones naturales incluyen ATRDollar TrailStop para una salida de trailing adaptativa a la volatilidad, o stop loss fijo y objetivo de beneficio mediante `SetStopLoss` y `SetProfitTarget`. AccountRiskCore proporciona protección de pérdida diaria a nivel de cuenta independientemente de la lógica de salida por operación.

**Relación con `ConsecutiveUps LE`:** La estrategia integrada `ConsecutiveUps LE` de TradeStation entra largo en cierres consecutivos más altos. Esta estrategia entra corto en máximos consecutivos más altos — una inversión direccional con una serie de precio diferente (`High` en lugar de `Close`). Ejecutar ambas simultáneamente en el mismo instrumento crea un sistema de mean-reversion simétrico que fadea movimientos en ambas direcciones.

**Limitaciones del backtesting:** Dado que la ruta en vivo usa `InsideAsk` (no disponible en el historial) y pegging ECN (ignorado en la simulación), el backtesting usa `Close` como proxy. Las ejecuciones históricas proporcionan una aproximación aproximada del rendimiento en vivo pero no deben tratarse como una representación precisa de la calidad de ejecución en vivo. Se recomienda forward testing en vivo antes de confiar en los resultados de backtesting para esta estrategia.
