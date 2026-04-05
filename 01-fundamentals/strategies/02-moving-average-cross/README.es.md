# Moving Average Crossover — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Moving Average Crossover es una estrategia de seguimiento de tendencia que entra al mercado cuando la media móvil rápida cruza la media móvil lenta, interpretando el evento de cruce como un cambio de momentum. Las entradas son eventos discretos — la estrategia solo actúa en el momento del cruce, no mientras la MA rápida simplemente está por encima o por debajo de la lenta. Las salidas combinan un período mínimo de mantenimiento con un umbral mínimo de beneficio: la estrategia permanece en una operación hasta que ha transcurrido suficiente tiempo y no se ha materializado suficiente beneficio, momento en el que sale como una operación ineficiente.

v2 extiende v1 con dos adiciones significativas: un filtro de volumen que requiere participación por encima de la media para confirmar la señal de cruce, y un stop loss configurable que puede aplicarse por posición o por contrato — haciendo la estrategia adaptable a acciones, futuros y CFDs.

---

## Mecánica Central

### 1. Cálculo de Medias Móviles

```pascal
// v1
ShortMA = Average(ShortPrice, ShortLen);
LongMA  = Average(LongPrice,  LongLen);

// v2
FastMA = AverageFC(FastPrice, FastLen);
SlowMA = AverageFC(SlowPrice, SlowLen);
```

Ambas versiones usan medias móviles simples. v2 reemplaza `Average` por `AverageFC` — la variante de "cálculo rápido" que usa un algoritmo de actualización incremental en lugar de recalcular la suma completa en cada barra. Funcionalmente idéntica; computacionalmente más eficiente, lo que importa cuando se ejecutan múltiples estrategias simultáneamente o sobre grandes conjuntos de datos.

La fuente de precio (`ShortPrice`/`FastPrice`, `LongPrice`/`SlowPrice`) por defecto es `Close` pero es configurable — permitiendo cambiar la estrategia a `Open`, `High`, `Low` o una serie personalizada sin cambios en el código.

### 2. Normalización del Volumen (Solo v2)

v2 añade un filtro de volumen que se adapta al tipo de gráfico utilizado:

```pascal
If BarType >= 2 and BarType < 5 Then
    AnyVol = Volume
Else
    AnyVol = Ticks;

AvgAnyVol = AverageFC(AnyVol, VolLen);
```

`BarType` es una palabra reservada de EasyLanguage que devuelve un entero identificando el tipo de gráfico: los valores 2–4 corresponden a barras diarias, semanales y mensuales, donde `Volume` (volumen de acciones/contratos) es la medida apropiada. Todos los demás tipos de gráfico (barras de minutos intradiarias, barras de ticks, barras de rango) usan `Ticks` en su lugar, que refleja el número de operaciones ejecutadas en lugar de acciones negociadas. Esta adaptación garantiza que el filtro de volumen sea significativo independientemente del tipo de gráfico.

`AvgAnyVol` es la media móvil simple de `AnyVol` durante `VolLen` barras — la línea de base contra la que se compara el volumen actual.

### 3. Entrada por Cruce

```pascal
// v1 — cruce sin filtro de volumen
If ShortMA Crosses Over  LongMA Then Buy       Next Bar at Market;
If ShortMA Crosses Under LongMA Then SellShort Next Bar at Market;

// v2 — cruce condicionado por confirmación de volumen
Condition1 = AnyVol > AvgAnyVol;
If Condition1 Then
Begin
    If FastMA Crosses Over  SlowMA Then Buy       Next Bar at Market;
    If FastMA Crosses Under SlowMA Then SellShort Next Bar at Market;
End;
```

`Crosses Over` y `Crosses Under` son eventos discretos en EasyLanguage — evalúan a `True` únicamente en la barra exacta donde se produce el cruce, y a `False` en cada barra siguiente independientemente de la posición relativa de las dos MAs. Esto significa:

- No se necesita ningún `If` para evitar entradas repetidas — el propio evento de cruce actúa como una puerta de una sola barra.
- No se necesita offset `[1]` — `Crosses Over/Under` internamente compara los valores de MA de la barra actual y la anterior para detectar la transición.

En v2, `Condition1 = AnyVol > AvgAnyVol` condiciona ambas direcciones de entrada a una confirmación de volumen. Un cruce que ocurre con volumen por debajo de la media se ignora — puede reflejar falta de participación real en lugar de momentum genuino. Solo los cruces acompañados de volumen por encima de la media se consideran señales de alta convicción.

> **Sobre `Condition1`:** EasyLanguage reserva `Condition1`, `Condition2`, etc. como variables booleanas predefinidas que no requieren declaración en `Vars`. Son variables globales implícitas, lo que significa que su estado puede persistir entre evaluaciones de formas no siempre obvias. El nombre `Condition1` no aporta información semántica — una mejora futura sería reemplazarla por una variable con nombre como `HasHighVolume`, coherente con las convenciones de nomenclatura usadas en todo el repositorio.

### 4. Lógica de Salida — Puerta de Tiempo y Beneficio

```pascal
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
    Sell       Next Bar at Market;
    BuyToCover Next Bar at Market;
End;
```

La condición de salida combina dos comprobaciones independientes:

- `BarsSinceEntry > MinHold`: la posición se ha mantenido durante al menos `MinHold` barras. Esto evita salidas prematuras — obliga a la estrategia a dar tiempo a la operación a desarrollarse antes de juzgar su rentabilidad.
- `OpenPositionProfit < MinProfit`: el beneficio no realizado (en moneda de la cuenta) está por debajo del umbral mínimo. `OpenPositionProfit` refleja el valor mark-to-market actual de la posición abierta.

Solo cuando *ambas* condiciones son verdaderas simultáneamente sale la estrategia. La lógica se lee: *"si he mantenido esta operación suficiente tiempo y no ha producido beneficio suficiente, la operación es ineficiente — salir."* Una operación que es suficientemente rentable después de `MinHold` barras continúa ejecutándose; una operación que sigue desarrollándose dentro del período `MinHold` recibe más tiempo independientemente del beneficio actual.

Tanto `Sell` como `BuyToCover` se colocan incondicionalmente — EasyLanguage ignora el que no es aplicable a la posición actual.

### 5. Stop Loss (Solo v2)

```pascal
If PositionBasis Then
    SetStopPosition
Else
    SetStopShare;

SetStopLoss(SLAmt);
```

v2 añade un stop loss monetario que opera independientemente de la salida por tiempo/beneficio. Dos modos están disponibles, controlados por el input booleano `PositionBasis`:

- `SetStopPosition` (cuando `PositionBasis = True`): el importe del stop loss se aplica a la *posición total*. Para una posición de 100 acciones con `SLAmt = $500`, la posición cierra si la pérdida no realizada total alcanza $500, independientemente de la pérdida por acción.
- `SetStopShare` (cuando `PositionBasis = False`): el stop loss se aplica *por acción o contrato*. Para 100 acciones con `SLAmt = $500`, la pérdida total antes de la salida sería $50.000 — el stop por acción es más apropiado para futuros donde cada contrato lleva un valor nocional significativo.

Esta distinción importa significativamente al adaptar la estrategia entre diferentes tipos de instrumentos. Para acciones, el modo por posición es típicamente más intuitivo. Para futuros, el stop por contrato garantiza que el stop loss escale correctamente con el tamaño nocional de cada contrato.

---

## v1 vs v2: La Diferencia

| | v1.0 | v2.0 |
|---|---|---|
| **Entrada por cruce de MA** | ✓ | ✓ |
| **Salida por tiempo + beneficio** | ✓ | ✓ |
| **Filtro de volumen** | — | ✓ (adaptativo al tipo de barra) |
| **`AverageFC` para eficiencia** | — | ✓ |
| **Stop loss** | — | ✓ (`SLAmt`) |
| **Base stop por posición vs acción** | — | ✓ (`PositionBasis`) |
| **Nomenclatura de inputs** | Prefijo `Short`/`Long` | Prefijo `Fast`/`Slow` |

El cambio de prefijo `Short`/`Long` a `Fast`/`Slow` en v2 es una mejora semántica: `FastLen` y `SlowLen` comunican el rol de cada MA (responsiva vs suave) en lugar de simplemente su tamaño relativo.

---

## Parámetros

### v1

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `ShortPrice` | `Close` | Serie de precio para la MA rápida. |
| `LongPrice` | `Close` | Serie de precio para la MA lenta. |
| `ShortLen` | 9 | Período para la MA rápida (corta). |
| `LongLen` | 18 | Período para la MA lenta (larga). |
| `MinHold` | 8 | Barras mínimas de mantenimiento antes de permitir una salida por tiempo/beneficio. |
| `MinProfit` | 100 | Beneficio mínimo no realizado (en moneda de la cuenta) requerido tras `MinHold` barras. |

### v2

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `FastPrice` | `Close` | Serie de precio para la MA rápida. |
| `SlowPrice` | `Close` | Serie de precio para la MA lenta. |
| `FastLen` | 9 | Período para la MA rápida. |
| `SlowLen` | 18 | Período para la MA lenta. |
| `VolLen` | 20 | Período de lookback para el cálculo del volumen medio. |
| `MinHold` | 8 | Barras mínimas de mantenimiento antes de permitir una salida por tiempo/beneficio. |
| `MinProfit` | 100 | Beneficio mínimo no realizado requerido tras `MinHold` barras. |
| `SLAmt` | 500 | Importe del stop loss en moneda de la cuenta. Se aplica por posición o por acción según `PositionBasis`. |
| `PositionBasis` | `True` | `True` = stop se aplica a la posición total; `False` = stop se aplica por acción/contrato. |

**Sobre la interacción de `MinHold` y `MinProfit`:** Estos dos parámetros funcionan como un par. Establecer `MinHold` demasiado bajo causa salidas prematuras en operaciones temporalmente no rentables. Establecer `MinProfit` demasiado alto causa salidas en operaciones que son rentables pero por debajo de un umbral poco realista. La combinación debe calibrarse conjuntamente: `MinHold` define la ventana de paciencia, `MinProfit` define el listón de rendimiento dentro de esa ventana.

---

## Escenarios de Operación

### Escenario A — Cruce Alcista, Operación Rentable (v1)

- FastMA(9) cruza sobre SlowMA(18). `Buy Next Bar at Market`. Entrada a 45,20.
- `MinHold = 8`. Durante 8 barras, la condición de salida no se comprueba.
- Barra 8: `BarsSinceEntry = 8 > MinHold (8)` → False (la condición requiere *estrictamente mayor que*). Sin salida aún.
- Barra 9: `BarsSinceEntry = 9 > 8` → True. `OpenPositionProfit = $320 > MinProfit ($100)`. La condición de beneficio no se cumple para salir — la operación continúa.
- La operación eventualmente sale cuando la MA rápida cruza bajo la lenta (nueva entrada `SellShort` por reversión cierra el largo).

### Escenario B — Cruce Alcista, Beneficio Insuficiente Tras MinHold (v1)

- Entrada a 45,20. Tras 9 barras, `OpenPositionProfit = $60 < MinProfit ($100)`.
- Ambas condiciones de salida cumplidas: `BarsSinceEntry (9) > MinHold (8)` Y `OpenPositionProfit ($60) < MinProfit ($100)`.
- `Sell Next Bar at Market`. La operación sale como ineficiente.

### Escenario C — Cruce Rechazado por Filtro de Volumen (v2)

- FastMA cruza sobre SlowMA en la barra X.
- `AnyVol = 8.500`. `AvgAnyVol = 12.000`. `Condition1 = False`.
- El cruce ocurre pero el volumen está por debajo de la media. Entrada bloqueada. La estrategia permanece flat.
- Barra X+2: el cruce persiste, pero `Crosses Over` ya no es `True` (solo lo fue en la barra X). No se activa ninguna entrada.
- El siguiente cruce calificado debe ocurrir en una barra con volumen por encima de la media.

### Escenario D — Stop Loss Antes de la Ventana MinHold (v2)

- Entrada a 45,20. `SLAmt = $500`, `PositionBasis = True`.
- La operación se mueve inmediatamente contra la posición. Tras 3 barras, la pérdida total de la posición alcanza $500.
- `SetStopLoss` se activa. La operación sale con pérdida. `BarsSinceEntry (3)` es menor que `MinHold (8)` — la salida por tiempo/beneficio no se habría activado aún, pero el stop loss sale independientemente.

---

## Características Clave

- **Cruce como evento discreto:** `Crosses Over/Under` se activa una vez por cruce, evitando entradas repetidas mientras las MAs permanecen en la misma posición relativa.
- **Salida temporal:** `MinHold` evita salidas prematuras, obligando a la estrategia a dar a cada operación suficiente tiempo para desarrollarse antes de juzgar su rentabilidad.
- **Salida cualificada por beneficio:** `MinProfit` garantiza que la estrategia solo salga voluntariamente de operaciones que están claramente por debajo del rendimiento esperado, no simplemente operaciones que están temporalmente por debajo del breakeven.
- **Confirmación de volumen (v2):** `AnyVol > AvgAnyVol` requiere participación por encima de la media en el momento del cruce, filtrando cruces que ocurren durante movimiento de precio de baja liquidez impulsado por la deriva.
- **Normalización de volumen adaptativa (v2):** La selección basada en `BarType` entre `Volume` y `Ticks` garantiza que el filtro de volumen sea significativo en gráficos diarios, intradiarios y de tipo no temporal.
- **Base de stop dual (v2):** El toggle `PositionBasis` permite aplicar el stop loss por posición o por acción/contrato, haciendo la estrategia directamente aplicable a acciones y futuros sin recalibración de parámetros.
- **Eficiencia de `AverageFC` (v2):** El cálculo más rápido de MA reduce la carga computacional en entornos multi-estrategia.

---

## Psicología del Trading

El cruce de medias móviles es una de las señales de seguimiento de tendencia más antiguas y estudiadas. Su relevancia continuada no se debe a que sea sofisticada — no lo es — sino a que captura un fenómeno genuino del mercado: cuando el momentum a corto plazo cambia en relación con el momentum a largo plazo, el mercado está cambiando de carácter. El cruce es el momento en que ese cambio se vuelve medible.

La salida por tiempo/beneficio codifica una creencia específica sobre la eficiencia de las operaciones: **no todas las operaciones que se mueven en la dirección correcta valen la pena mantener.** Una operación que ocupa capital durante 10 barras y produce $80 de beneficio no realizado es menos eficiente que una que produce los mismos $80 en 3 barras. `MinHold` y `MinProfit` juntos definen la eficiencia mínima aceptable — si una operación no ha alcanzado el umbral de rendimiento para cuando termina la ventana de paciencia, el capital se despliega mejor en la siguiente señal.

El filtro de volumen en v2 añade una capa de razonamiento de microestructura de mercado. El precio puede moverse en cualquier dirección en cualquier momento, pero los movimientos direccionales sostenidos requieren participación. Un cruce con volumen escaso puede reflejar simplemente la ausencia de vendedores (o compradores) en lugar de convicción direccional genuina. Al requerir `AnyVol > AvgAnyVol`, la estrategia solo actúa cuando el mercado está confirmando activamente la señal con flujo de órdenes real.

---

## Casos de Uso

**Instrumentos:** Ambas versiones funcionan en cualquier instrumento con comportamiento tendencial consistente — futuros de índices de renta variable (ES, NQ), acciones individuales en fases direccionales, futuros de materias primas y futuros FX. El filtro de volumen en v2 la hace especialmente adecuada para mercados de futuros donde los datos de volumen son fiables y están estrechamente correlacionados con el momentum de precio.

**Marcos temporales:** La combinación de MAs 9/18 funciona en múltiples marcos temporales. En barras de 5 minutos captura tendencias intradiarias cortas; en barras diarias captura movimientos direccionales de medio plazo. `MinHold` debe interpretarse en relación al marco temporal — 8 barras en un gráfico de 5 minutos son 40 minutos; en un gráfico diario son semana y media.

**v1 como línea de base:** v1 es un punto de partida ideal para testear el edge central del cruce antes de añadir filtros. Ejecutar v1 y v2 sobre el mismo conjunto de datos y comparar resultados aísla la contribución del filtro de volumen — una forma limpia de evaluar si la confirmación de volumen añade edge en un instrumento específico.

**Guía de `PositionBasis`:** Para acciones y ETFs, `PositionBasis = True` (stop por posición) es típicamente más intuitivo — defines el riesgo total en dólares por operación. Para futuros, `PositionBasis = False` (stop por contrato) es más apropiado — el valor nocional por contrato significa que un stop por posición requeriría recalibración constante a medida que cambian los tamaños de contrato entre instrumentos.
