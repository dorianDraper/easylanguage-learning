# Momentum Cross — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Momentum Cross es una estrategia de seguimiento de momentum que entra cuando el indicador Momentum cruza la línea cero, filtrado por una comprobación de recencia que garantiza que no se haya producido ningún cruce opuesto en la ventana de lookback reciente. Las salidas se basan en el deterioro del momentum — tres barras consecutivas de debilitamiento — en lugar de stops fijos o targets de beneficio. El sistema no tiene gestión de riesgo por niveles de precio por diseño: está construido para estudiar el comportamiento de la señal de momentum en sí antes de añadir controles de riesgo encima.

v2 refina v1 en dos aspectos: reemplaza la orden límite al precio exacto de cierre por un límite con offset configurable que mejora el realismo de ejecución, y separa cada componente lógico en variables booleanas con nombre, haciendo la arquitectura de señales explícita y auditable. Ambas versiones incluyen instrucciones `Print` y `Commentary` como herramientas de desarrollo para depuración y análisis barra a barra.

---

## Mecánica Central

### 1. Cálculo del Momentum

```pascal
Mom = Momentum(Price, Length);   // v1
Mom = Momentum(Price, MomLen);   // v2
```

`Momentum` es la función nativa de EasyLanguage que devuelve la diferencia entre el precio de la barra actual y el precio de hace `N` barras: `Momentum(Price, N) = Price - Price[N]`. Mide el cambio neto del precio durante la ventana de lookback — los valores positivos indican que el precio es más alto que hace N barras (momentum alcista), los negativos indican que es más bajo (momentum bajista).

La línea cero es el límite estructural: cruzar por encima de cero significa que el momentum ha pasado de negativo a positivo; cruzar por debajo significa lo inverso. A diferencia de un cruce de medias móviles, que compara dos valores derivados, el cruce del momentum con cero compara el indicador directamente contra un nivel estructural fijo.

### 2. Eventos Primarios — Cruces de la Línea Cero

```pascal
// v1
BullCx = Mom Crosses Over  0;
BearCx = Mom Crosses Under 0;

// v2
BullMom = Mom Crosses Over  0;
BearMom = Mom Crosses Under 0;
```

`Crosses Over 0` y `Crosses Under 0` son eventos discretos — `True` únicamente en la barra exacta donde se produce el cruce. El cambio de nombre de `BullCx`/`BearCx` a `BullMom`/`BearMom` en v2 comunica qué representa la variable (un evento de momentum alcista) en lugar de su acción mecánica (un evento de cruce).

### 3. Filtro MRO — Comprobación de Recencia

```pascal
// v1 — inline
If BullCx and MRO(BearCx, BearLen, 1) = -1 Then ...

// v2 — variables con nombre
BuyFilter  = MRO(BearMom, NumBearBars, 1) = -1;
SellFilter = MRO(BullMom, NumBullBars, 1) = -1;
```

`MRO(condición, lookback, ocurrencia)` escanea hacia atrás a través de las últimas `lookback` barras y devuelve el offset de la barra más reciente donde `condición` era `True`, o `-1` si la condición nunca ocurrió dentro de la ventana.

`MRO(BearMom, NumBearBars, 1) = -1` se lee: *"no ha habido ningún cruce bajista de momentum en las últimas `NumBearBars` barras."* Este es el filtro de entrada — un cruce alcista solo se actúa si no ha ocurrido un cruce bajista recientemente. La lógica evita entrar en largo inmediatamente después de una señal de reversión reciente, filtrando whipsaws y cambios rápidos de dirección.

Piensa en MRO como un escáner retrospectivo con una pregunta específica: *"¿ha ocurrido este evento recientemente?"* Cuando devuelve `-1`, la respuesta es no — la condición no se encontró en la ventana. Cuando devuelve cualquier valor ≥ 0, el evento sí ocurrió y el filtro rechaza la entrada.

En v2, estas condiciones se almacenan como booleanos con nombre (`BuyFilter`, `SellFilter`), separando la lógica del filtro del bloque de ejecución de entrada. El bloque de entrada se lee entonces como una composición limpia:

```pascal
If BullMom and BuyFilter  Then Buy       ...
If BearMom and SellFilter Then SellShort ...
```

### 4. Órdenes de Entrada — Límite en el Cierre (v1) vs Límite con Offset (v2)

```pascal
// v1 — límite en el cierre exacto de la barra actual
Buy       Next Bar at Close of This Bar         Limit;
SellShort Next Bar at Close of This Bar         Limit;

// v2 — límite con offset configurable desde el cierre actual
Buy       Next Bar at Close of This Bar - LimitPoints Limit;
SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

Ambas versiones usan órdenes límite en lugar de órdenes a mercado — un enfoque de entrada más conservador y realista. Una orden límite solo se ejecuta si el precio alcanza el nivel especificado, en lugar de ejecutarse al precio de apertura de la siguiente barra.

**v1 — Close of This Bar:** El límite se establece en el precio de cierre exacto de la barra actual. Para una entrada larga, la orden se ejecuta en la siguiente barra solo si el precio vuelve a ese nivel de cierre o por debajo. Es sintaxis válida de EasyLanguage, pero tiene una limitación práctica: en mercados con gaps de apertura, la siguiente barra puede abrir significativamente por encima del límite y la orden nunca se ejecuta.

**v2 — Límite con Offset:** `LimitPoints` se resta del cierre para largos (colocando el límite ligeramente por debajo del cierre, requiriendo un pequeño retroceso antes de la entrada) y se suma al cierre para cortos (requiriendo un pequeño rebote). Esto hace las entradas más selectivas — el mercado debe confirmar ligeramente la dirección de la señal antes de que se ejecute la operación.

> **Sobre `Close of This Bar` en una orden `Next Bar`:** Esta sintaxis accede al precio de cierre de la barra que está siendo evaluada y lo usa como precio límite para una orden que se ejecuta en la siguiente barra. El límite se calcula al cierre de la barra y se envía para el rango de trading de la barra siguiente. Esto es técnicamente correcto en EasyLanguage, pero produce menos ejecuciones en mercados con gaps donde la apertura siguiente puede saltarse el nivel límite por completo.

### 5. Salidas por Deterioro del Momentum

```pascal
// v1 — inline
If Mom < Mom[1] and Mom[1] < Mom[2] Then Sell       Next Bar at Market;
If Mom > Mom[1] and Mom[1] > Mom[2] Then BuyToCover Next Bar at Market;

// v2 — variables con nombre
DownMom = Mom < Mom[1] and Mom[1] < Mom[2];
UpMom   = Mom > Mom[1] and Mom[1] > Mom[2];

If DownMom Then Sell       Next Bar at Market;
If UpMom   Then BuyToCover Next Bar at Market;
```

La salida se activa cuando el momentum ha estado declinando (o subiendo, para cortos) durante tres barras consecutivas. Esta es una salida estructural — no requiere que se cruce un nivel de precio, solo un patrón de valores de momentum debilitantes. La lógica: *"si el momentum ha estado deteriorándose durante tres barras consecutivas, el impulso que impulsa esta operación está perdiendo convicción. Salir antes de que se revierta completamente."*

Se eligieron tres barras como mínimo para requerir deterioro sostenido en lugar de un retroceso de una sola barra. Una barra de momentum más débil podría ser ruido; tres barras consecutivas es una señal estructural. Este umbral está hardcodeado — una extensión natural para una versión futura sería parametrizarlo.

### 6. Herramientas de Desarrollo — Print y Commentary (v2)

```pascal
Print("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);

Commentary("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);
```

`Print` escribe una línea formateada en el Print Log de TradeStation en cada evaluación de barra, registrando la fecha, hora, valor de momentum y señales de cruce. `Commentary` añade la misma información como anotación visible en el gráfico cuando se selecciona una barra.

Ambas son herramientas exclusivas de desarrollo. En producción o backtesting a escala, deben comentarse — se ejecutan en cada barra y generan una salida de log significativa que degrada el rendimiento de la plataforma. Se dejan activas en v2 para apoyar el flujo de trabajo de análisis y depuración durante el desarrollo de la estrategia.

---

## v1 vs v2: La Diferencia

| | v1.0 | v2.0 |
|---|---|---|
| **Entrada por cruce de momentum en cero** | ✓ | ✓ |
| **Filtro MRO de recencia** | ✓ (inline) | ✓ (booleanos con nombre) |
| **Salida por deterioro de momentum** | ✓ (inline) | ✓ (booleanos con nombre) |
| **Límite en cierre exacto** | ✓ | — |
| **Límite con offset (`LimitPoints`)** | — | ✓ |
| **Variables de señal con nombre** | — | ✓ (`BullMom`, `BearMom`, `BuyFilter`, `SellFilter`, `DownMom`, `UpMom`) |
| **`Print` / `Commentary`** | — | ✓ (herramientas de desarrollo) |

El cambio arquitectónico de v1 a v2 refleja el principio articulado en los propios comentarios del código: separar eventos primarios, filtros y salidas en variables con nombre distintas. v2 hace la cadena de señales explícita — puedes leer `BullMom and BuyFilter` y entender inmediatamente tanto el disparador (cruce alcista de momentum) como la puerta (sin cruce bajista reciente). En v1, ambos están incrustados en la propia condición de entrada.

---

## Parámetros

### v1

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `Price` | `Close` | Serie de precio usada para el cálculo del momentum. |
| `Length` | 10 | Lookback del momentum — compara el precio actual con el precio de hace `Length` barras. |
| `BullLen` | 4 | Barras hacia atrás para buscar un cruce alcista reciente (usado en el filtro de entrada corta). |
| `BearLen` | 4 | Barras hacia atrás para buscar un cruce bajista reciente (usado en el filtro de entrada larga). |

### v2

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `Price` | `Close` | Serie de precio usada para el cálculo del momentum. |
| `MomLen` | 10 | Período de lookback del momentum. |
| `NumBullBars` | 4 | Barras hacia atrás para buscar un cruce alcista reciente (filtro de entrada corta). |
| `NumBearBars` | 4 | Barras hacia atrás para buscar un cruce bajista reciente (filtro de entrada larga). |
| `LimitPoints` | 0,05 | Offset desde el cierre usado para fijar el precio de la orden límite. |

**Sobre `LimitPoints`:** El valor por defecto de `0,05` está calibrado para precios de acciones. Para contratos de futuros, debe ajustarse para reflejar el tamaño de tick del instrumento y su rango intrabarra típico. Para futuros ES, un offset de 0,05 es menos de un tick — efectivamente coloca el límite en el cierre. Un offset más significativo para ES podría ser 0,25 a 1,00 puntos.

**Sobre `BullLen`/`BearLen` (`NumBullBars`/`NumBearBars`):** Estos parámetros controlan cuán lejos hacia atrás mira el filtro MRO buscando un cruce opuesto reciente. Valores más grandes hacen el filtro más conservador — un cruce bajista de más atrás sigue bloqueando una nueva entrada larga. Valores más pequeños hacen el filtro más permisivo, permitiendo la reentrada más pronto tras un cambio de dirección.

---

## Escenarios de Operación

### Escenario A — Entrada Larga Pasa Todos los Filtros

- `Mom` cruza por encima de 0 en la barra X. `BullMom = True`.
- Escaneo MRO: no hay evento `BearMom` en las últimas 4 barras. `BuyFilter = True`.
- Ambas condiciones cumplidas. Orden límite larga colocada en `Close of This Bar - 0,05`.
- La siguiente barra abre y opera bajando hasta el nivel límite. Entrada larga ejecutada.
- `Mom` permanece positivo durante varias barras. Sin señal de salida.
- Barra X+5: `Mom < Mom[1]`, X+4: `Mom[1] < Mom[2]`. `DownMom = True`. Salida: `Sell Next Bar at Market`.

### Escenario B — Entrada Larga Bloqueada por Filtro MRO

- `Mom` cruza por encima de 0 en la barra X. `BullMom = True`.
- Escaneo MRO: `BearMom` fue `True` en la barra X-2. `MRO(BearMom, 4, 1) = 2` (hace 2 barras). No es `-1`.
- `BuyFilter = False`. Entrada bloqueada. La estrategia permanece flat.
- El cruce bajista de hace dos barras es demasiado reciente para entrar largo.

### Escenario C — Orden Límite No Ejecutada (Gap de Apertura)

- Límite largo colocado en `Close (45,20) - 0,05 = 45,15` al cierre de la barra.
- La siguiente barra abre en 45,40 (gap alcista). El precio nunca opera hasta 45,15 durante la barra.
- La orden límite expira sin ejecución. Sin posición.
- En la barra siguiente, `BullMom` ya no es `True` (el cruce solo fue verdadero en la barra de señal). No se activa nueva entrada a menos que ocurra un nuevo cruce.

### Escenario D — Salida por Deterioro del Momentum

- Posición larga abierta. Secuencia de momentum: Mom = 8,2 → 7,1 → 6,3.
- Barra 1: `Mom (7,1) < Mom[1] (8,2)`. Una barra de debilidad.
- Barra 2: `Mom (6,3) < Mom[1] (7,1)`. Dos barras consecutivas.
- `DownMom = True` (tres valores consecutivamente decrecientes: 8,2 → 7,1 → 6,3). Salida: `Sell Next Bar at Market`.

---

## Características Clave

- **Cruce de la línea cero como señal primaria:** El cruce del momentum con cero es un cambio estructural — el cambio neto de precio durante `MomLen` barras ha cambiado de signo. Es una medida directa del sesgo direccional, no una comparación de indicadores derivados.
- **Filtro MRO de recencia:** Evita entrar en una dirección inmediatamente después de un cruce opuesto, reduciendo la exposición a whipsaws al requerir un período limpio sin señales conflictivas.
- **Salida por deterioro del momentum:** Tres barras consecutivas de momentum debilitante proporcionan una señal de salida estructural que no requiere niveles de precio objetivo. La operación sale cuando su premisa (el momentum) comienza a erosionarse.
- **Entrada límite para ejecución realista:** Ambas versiones usan órdenes límite en lugar de órdenes a mercado, evitando el comportamiento de ejecución al precio disponible de las entradas a mercado y requiriendo que el mercado vuelva a un precio definido antes de que se abra la operación.
- **Arquitectura de booleanos con nombre (v2):** Separar eventos primarios (`BullMom`, `BearMom`), filtros (`BuyFilter`, `SellFilter`) y condiciones de salida (`DownMom`, `UpMom`) en variables distintas hace cada capa independientemente legible y modificable.
- **Log de desarrollo (v2):** `Print` y `Commentary` proporcionan visibilidad barra a barra del estado de la señal durante el desarrollo. Deben desactivarse antes del uso en producción.

---

## Psicología del Trading

Momentum Cross encarna una postura filosófica clara: **entrar solo cuando el mercado demuestra intención clara, permanecer mientras esa intención se mantiene, salir en el momento en que comienza a debilitarse.**

El cruce de la línea cero define "intención clara" con precisión: el momentum ha pasado de negativo a positivo (o viceversa) — el cambio neto de precio durante la ventana de lookback ha cambiado de dirección. No es una comparación relativa entre dos medias derivadas; es una observación estructural directa sobre si el mercado está más alto o más bajo que hace `MomLen` barras.

El filtro MRO añade una dimensión temporal a "intención clara": la señal no debe estar inmediatamente precedida por su opuesto. Un cruce alcista de momentum que sigue a uno bajista dentro de cuatro barras no es una señal direccional limpia — es más probable que sea un whipsaw en un mercado lateral. Al requerir la ausencia de señales opuestas recientes, la estrategia solo actúa cuando el cambio de momentum ha tenido tiempo de establecerse.

La salida por deterioro refleja un respeto por la naturaleza dinámica del momentum. Un stop o target fijo trata todas las operaciones como equivalentes — una operación en un mercado fuertemente tendencial y una en un mercado lateral salen a los mismos niveles de precio. La salida por deterioro de momentum se adapta: una tendencia fuerte que sostiene el momentum permanece abierta; una entrada débil que ve el momentum flaquear inmediatamente sale. La estrategia escucha lo que el mercado está haciendo en lugar de imponer un resultado predeterminado.

---

## Casos de Uso

**Instrumentos:** Momentum Cross es más efectiva en instrumentos con fases de momentum direccional claras — futuros de índices de renta variable (ES, NQ) durante sesiones tendenciales, acciones individuales de momentum, y futuros de materias primas con movimientos direccionales sostenidos. Tiene dificultades en mercados de rango o de mean-reversion donde el momentum oscila alrededor de cero sin convicción direccional sostenida.

**Marcos temporales:** El lookback de momentum de 10 barras es relativo al marco temporal. En barras de 5 minutos captura aproximadamente 50 minutos de cambio neto de precio; en barras diarias captura dos semanas de trading. El patrón de salida por deterioro (tres barras consecutivas) también debe interpretarse en relación al marco temporal — tres barras de 5 minutos son 15 minutos de momentum debilitante; tres barras diarias son casi una semana.

**Como vehículo de investigación:** Ambas versiones están diseñadas explícitamente para aprendizaje e investigación en lugar de despliegue en vivo. La ausencia de stops significa que una operación que entra en una señal falsa puede perder sin límite hasta que aparezca el patrón de deterioro de tres barras. El uso previsto es estudiar el comportamiento de la señal de momentum y el filtro MRO de forma aislada antes de añadir la capa de gestión del riesgo que requeriría un sistema de producción.

**Próximos pasos naturales:** Los comentarios en ambas versiones apuntan hacia mejoras futuras: añadir un conteo de barras de salida configurable (en lugar de las tres barras hardcodeadas), añadir parámetros de stop loss y objetivo de beneficio, combinar con un filtro de tendencia en timeframe superior (similar al enfoque de la Multi-Data Strategy), y reemplazar `Condition1` por una variable con nombre semántico. Estas extensiones moverían la estrategia hacia la preparación para producción preservando la arquitectura de señales limpia establecida aquí.
