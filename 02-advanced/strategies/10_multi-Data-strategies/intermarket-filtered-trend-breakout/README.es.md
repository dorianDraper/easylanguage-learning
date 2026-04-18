# Intermarket Filtered Trend Breakout — v1.0, v2.0 & v3.0

🇺🇸 [English](README.md) | 🇪🇸 Español

## Descripción de la estrategia

Intermarket Filtered Trend Breakout es una estrategia de seguimiento de tendencia multi-data que opera un mercado primario únicamente cuando mercados secundarios correlacionados confirman el régimen direccional esperado. La estrategia combina tres motores independientes — un filtro de tendencia por medias móviles, una entrada por ruptura de canal estilo Donchian, y un filtro de confirmación intermercado — con características de gestión de posición que incluyen un trailing stop ATR, piramidación basada en beneficio, salidas forzadas por cambio de régimen, y un mecanismo de pausa que detiene las entradas tras pérdidas consecutivas.

La estrategia requiere tres feeds de datos:

- **Data1** — Mercado primario (el instrumento que se opera, p.ej. futuros DAX, NQ)
- **Data2** — Mercado filtro de divisa (p.ej. EURUSD)
- **Data3** — Mercado filtro de bonos (p.ej. futuros Bund, US 20Y)

Los filtros intermercado pueden configurarse para correlación positiva, correlación negativa, o desactivarse completamente mediante los inputs `CurrencyCorrelation` y `BondCorrelation`. Esto hace la estrategia adaptable a diferentes relaciones intermercado sin modificar el código.

---

## Mecánica central

### 1. Motor de señal — tendencia y ruptura

El motor de señal evalúa dos condiciones sobre Data1 en cada barra:

```pascal
LongTrendSignal  = Average(Close, FastMALength) > Average(Close, SlowMALength);
ShortTrendSignal = Average(Close, FastMALength) < Average(Close, SlowMALength);

LongBreakoutLevel  = Highest(High, ChannelLength);
ShortBreakoutLevel = Lowest(Low, ChannelLength);
```

`LongTrendSignal` y `ShortTrendSignal` definen el estado de tendencia mediante un cruce de medias móviles rápida/lenta. Son estados booleanos continuos — no eventos de cruce discretos — lo que significa que permanecen en `True` mientras se mantenga la relación entre las medias, no solo en la barra donde se produce el cruce.

`LongBreakoutLevel` y `ShortBreakoutLevel` son los límites del canal Donchian: el máximo más alto y el mínimo más bajo de las últimas `ChannelLength` barras. Las órdenes de entrada se colocan como órdenes stop en estos niveles, por lo que un trade solo abre si el precio realmente rompe el canal — el filtro de tendencia confirma la dirección, la ruptura confirma el impulso.

Esta lógica de entrada de dos capas — estado de tendencia más ruptura de precio — significa que la estrategia no entra simplemente porque las medias estén alineadas. Espera a que el mercado demuestre impulso direccional superando el límite del canal.

### 2. Motor de filtro intermercado

El motor de filtro evalúa Data2 (divisa) y Data3 (bonos) de forma independiente y luego los combina:

```pascal
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

Cada filtro tiene tres estados posibles determinados por su input de correlación:

- **Correlación = 0:** Filtro desactivado. Siempre pasa. El mercado secundario se ignora para esta dirección.
- **Correlación = 1 (positiva):** El filtro pasa para entradas largas cuando Data2 está por encima de su media — ambos mercados tendiendo en la misma dirección.
- **Correlación = -1 (negativa):** El filtro pasa para entradas largas cuando Data2 está por debajo de su media — el mercado secundario tendiendo en dirección opuesta al primario, que en una relación de correlación inversa es la condición confirmadora.

El filtro corto es el espejo lógico del filtro largo. Los dos filtros se combinan con un `and` lógico — ambos mercados secundarios deben confirmar para que una operación proceda.

### 3. Seguimiento de rendimiento — contador de pérdidas consecutivas

```pascal
If TotalTrades > PreviousTotalTrades Then
Begin
    If PositionProfit(1) < 0 Then
        ConsecutiveLosses = ConsecutiveLosses + 1
    Else
    Begin
        ConsecutiveLosses = 0;
        SkippedSignals    = 0;
    End;
End;

PreviousTotalTrades = TotalTrades;
```

`TotalTrades > PreviousTotalTrades` detecta que un nuevo trade acaba de cerrarse. `PositionProfit(1)` devuelve el beneficio del trade cerrado más recientemente. En una pérdida, `ConsecutiveLosses` se incrementa. En una ganancia, tanto `ConsecutiveLosses` como `SkippedSignals` se resetean a cero — una operación ganadora limpia el estado completo de cualquier período de pausa activo.

### 4. Motor de entrada — lógica de salto de señal

```pascal
If MarketPosition = 0 Then
Begin
    If ConsecutiveLosses >= MaxConsecutiveLosses Then
    Begin
        SkippedSignals = SkippedSignals + 1;

        If SkippedSignals >= SignalsToSkip Then
        Begin
            ConsecutiveLosses = 0;
            SkippedSignals    = 0;
        End;

    End Else
    Begin
        If LongTrendSignal and LongFilterPassed Then
            Buy ("Breakout_LE") Next Bar LongBreakoutLevel Stop;

        If ShortTrendSignal and ShortFilterPassed Then
            SellShort ("Breakout_SE") Next Bar ShortBreakoutLevel Stop;
    End;
End;
```

Cuando `ConsecutiveLosses` alcanza `MaxConsecutiveLosses`, el bloque de entrada se omite y `SkippedSignals` se incrementa en su lugar. Una vez que `SkippedSignals` alcanza `SignalsToSkip`, ambos contadores se resetean y se reanuda la entrada normal. Las señales de entrada solo se disparan en la rama `Else` — están estructuralmente bloqueadas mientras la condición de pausa está activa.

Con `MaxConsecutiveLosses = 3` y `SignalsToSkip = 1`, la estrategia salta exactamente una señal válida tras tres pérdidas consecutivas y luego reanuda. Aumentar `SignalsToSkip` extiende la pausa sin cambiar el umbral de pérdidas.

### 5. Gestión de posición — piramidación

```pascal
If OpenPositionProfit > ProfitReentryThreshold
    and PyramidCount < MaxPyramidLevels Then
Begin
    If MarketPosition = 1 Then
    Begin
        Buy ("ReEntry_LE") Next Bar at Market;
        PyramidCount = PyramidCount + 1;
    End;
    ...
End;
```

Mientras se mantiene una posición, si el beneficio abierto supera `ProfitReentryThreshold` y el contador de pirámide no ha alcanzado `MaxPyramidLevels`, se añade una segunda posición a mercado. `PyramidCount` rastrea cuántas re-entradas han ocurrido y aplica el límite. Cada re-entrada añade una unidad de posición completa.

`PyramidCount` se resetea a cero en dos puntos: en una Salida por Régimen (cierre forzado explícito) y cuando `MarketPosition` vuelve a plano (stop ATR u otra salida). Este reset dual asegura que ningún estado residual de pirámide se lleve al siguiente ciclo de trade.

### 6. Motor de salida por régimen

```pascal
If MarketPosition = 1 and ShortFilterPassed Then
Begin
    Sell ("FilterExit_LX") Next Bar at Market;
    PyramidCount = 0;
End;

If MarketPosition = -1 and LongFilterPassed Then
Begin
    BuyToCover ("FilterExit_SX") Next Bar at Market;
    PyramidCount = 0;
End;
```

Si los filtros intermercado cambian para favorecer la dirección opuesta mientras una posición está abierta, la estrategia sale inmediatamente a mercado. Esto no es un stop de pérdidas — es una señal de cambio de régimen. El contexto de mercado que justificó la entrada ya no se sostiene.

La Salida por Régimen cierra la **posición completa**, incluyendo todas las unidades piramidadas. Una única orden de mercado liquida todos los contratos abiertos independientemente de cuántas re-entradas hayan ocurrido.

### 7. Motor de trailing stop ATR

```pascal
CurrentATR   = AvgTrueRange(ATRLength);
StopDistance = ATRStopMultiplier * CurrentATR;

If BarsSinceEntry = 0 Then
    TrailingStopPrice = EntryPrice - MarketPosition * StopDistance;

If MarketPosition = 1 Then
Begin
    TrailingStopPrice = MaxList(TrailingStopPrice, Close - StopDistance);
    Sell ("ATRStop_LX") Next Bar TrailingStopPrice Stop;
End;

If MarketPosition = -1 Then
Begin
    TrailingStopPrice = MinList(TrailingStopPrice, Close + StopDistance);
    BuyToCover ("ATRStop_SX") Next Bar TrailingStopPrice Stop;
End;
```

En la entrada (`BarsSinceEntry = 0`), el stop inicial se coloca `StopDistance` por debajo del precio de entrada para largos y por encima para cortos. En cada barra posterior, el stop se desplaza en la dirección del trade: para largos, `MaxList` asegura que el stop solo sube, nunca baja; para cortos, `MinList` asegura que el stop solo baja, nunca sube. El stop bloquea beneficios a medida que el trade avanza favorablemente mientras limita el riesgo a la baja si la tendencia se invierte.

`StopDistance = ATRStopMultiplier * AvgTrueRange(ATRLength)` hace el stop proporcional a la volatilidad reciente — más amplio en períodos volátiles, más ajustado en períodos tranquilos.

---

## Máquina de estados

```
┌─────────────┐
│    PLANO    │  Monitorizando condiciones de entrada
└──────┬──────┘
       │ ConsecutiveLosses >= MaxConsecutiveLosses?
       ├── SÍ → Saltar señal, incrementar SkippedSignals
       │        Si SkippedSignals >= SignalsToSkip → resetear ambos contadores
       │
       │ TrendSignal y FilterPassed y sin modo pausa
       ▼
┌─────────────────────────────────┐
│  ORDEN DE RUPTURA COLOCADA      │  Orden stop en límite del canal
└──────┬──────────────────────────┘
       │ El precio rompe el canal → orden ejecutada
       ▼
┌─────────────┐
│  LARGO /    │  Trailing stop ATR activo
│  CORTO      │  Monitorizando piramidación y condiciones de salida
└──────┬──────┘
       │
       ├── OpenPositionProfit > ProfitReentryThreshold
       │   y PyramidCount < MaxPyramidLevels
       │         → Añadir posición a mercado, PyramidCount++
       │
       ├── Cambio de régimen (FilterPassed dirección opuesta)
       │         → FilterExit a mercado, PyramidCount = 0
       │
       └── ATRStop alcanzado
                 → Salida en stop, PyramidCount = 0
┌─────────────┐
│    PLANO    │  Ciclo completo
└─────────────┘
```

---

## v1 vs v2 vs v3: Las diferencias

### v1 — Funcional pero con problemas estructurales

v1 implementa la lógica de trading completa pero con varios problemas de legibilidad y comportamiento. Los nombres de variables mezclan español e inglés (`sgLong`, `sgShort`, `flagSaltar`, `continuousLosses`). La lógica de pausa usa `flagSaltar` — un flag inicializado en `True` que alterna entre estados de pausa — más difícil de razonar que un contador. El trailing stop ATR y las salidas por régimen se ejecutan en cada barra incluyendo cuando la posición es plana. No existe límite de piramidación.

El bug de `flagSaltar`: en una ganancia, `continuousLosses` se resetea a `0` pero `flagSaltar` no se resetea explícitamente en la rama `Else` — retiene el valor que tenía del estado anterior, causando potencialmente un comportamiento de pausa incorrecto tras una secuencia pérdida-ganancia.

### v2 — Refactorización limpia, misma lógica

v2 renombra todas las variables a inglés descriptivo, separa la lógica en bloques de motor claramente etiquetados, y reemplaza `flagSaltar` por `SkipNextSignal = ConsecutiveLosses >= 3` evaluado inline. Los bloques ATR y salida por régimen se mueven fuera del bloque de gestión de posición, lo que es una inconsistencia estructural — ambos se ejecutan cuando la posición es plana, desperdiciando cómputo.

El reset de pausa en v2 es más agresivo que en v1: cuando se salta una señal, `ConsecutiveLosses` se resetea inmediatamente a `0`. Esto significa que la siguiente señal tras un salto puede entrar sin restricción, mientras que v1 requería una operación ganadora real antes de limpiar completamente el estado de pausa.

### v3 — Parametrizado y estructuralmente correcto

v3 aborda todos los problemas restantes de v2. Los cambios clave son la parametrización de la lógica de pausa con `MaxConsecutiveLosses` y `SignalsToSkip`, la separación del período ATR con `ATRLength(14)`, la separación del período de media de los filtros con `FilterMALength`, el límite de piramidación con `MaxPyramidLevels`, la encapsulación del stop ATR y las salidas por régimen dentro del bloque de posición abierta, y el reset de `SkippedSignals` en ganancia.

**Resumen:**

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Lógica de trading central** | ✓ | ✓ | ✓ |
| **Nombres de variables en inglés** | — | ✓ | ✓ |
| **Bloques de motor etiquetados** | — | ✓ | ✓ |
| **Lógica de pausa mediante flag (`flagSaltar`)** | ✓ | — | — |
| **Lógica de pausa mediante contador** | — | ✓ | ✓ |
| **Pausa parametrizada (`MaxConsecutiveLosses`, `SignalsToSkip`)** | — | — | ✓ |
| **Período ATR independiente (`ATRLength`)** | — | — | ✓ |
| **Período MA de filtros independiente (`FilterMALength`)** | — | — | ✓ |
| **Límite de piramidación (`MaxPyramidLevels`)** | — | — | ✓ |
| **ATR/salidas encapsulados en bloque de posición** | — | — | ✓ |
| **`SkippedSignals` se resetea en ganancia** | — | — | ✓ |
| **Reset dual de `PyramidCount`** | — | — | ✓ |

---

## Parámetros

| Parámetro | Por defecto | ¿Optimizar? | Descripción |
|-----------|-------------|-------------|-------------|
| `ChannelLength` | 20 | ✓ | Lookback para los niveles de ruptura del canal Donchian. Valores más grandes requieren rupturas más significativas. |
| `FastMALength` | 10 | ✓ | Período de la media rápida. Controla la sensibilidad de la señal de tendencia. |
| `SlowMALength` | 50 | ✓ | Período de la media lenta. Define la referencia de tendencia en el mercado primario. |
| `FilterMALength` | 20 | Con cautela | Período de media para filtros de mercados secundarios. Independiente de las medias del mercado primario. Usar validación walk-forward si se optimiza. |
| `ATRLength` | 14 | ✗ Fijar | Período ATR para el cálculo del trailing stop. Fijado en el estándar de Wilder — no optimizar. |
| `ATRStopMultiplier` | 2 | ✓ | Multiplicador aplicado al ATR para la distancia del stop. Valores más altos dan más margen al trade. |
| `CurrencyCorrelation` | -1 | ✗ Fijar | Dirección de correlación para Data2. `1` = positiva, `-1` = inversa, `0` = desactivada. Establecer basándose en la relación económica conocida. |
| `BondCorrelation` | -1 | ✗ Fijar | Dirección de correlación para Data3. Misma convención que `CurrencyCorrelation`. |
| `ProfitReentryThreshold` | 500 | ✓ | Beneficio abierto requerido antes de permitir una re-entrada de piramidación. |
| `MaxConsecutiveLosses` | 3 | ✗ Fijar | Número de pérdidas consecutivas antes de activar la lógica de pausa. Decisión de gestión de riesgo — no optimizar. |
| `SignalsToSkip` | 1 | ✗ Fijar | Número de señales válidas a omitir tras una racha de pérdidas. Decisión de gestión de riesgo — no optimizar. |
| `MaxPyramidLevels` | 1 | ✗ Fijar | Número máximo de re-entradas por ciclo de trade. Fijar en 1 o 2. |

**Sobre grados de libertad:** Cada parámetro optimizable añade una dimensión al espacio de búsqueda. Como regla general, se necesitan al menos 30 operaciones por parámetro optimizado para que los resultados tengan significancia estadística mínima. Con los tres parámetros primarios optimizables (`ChannelLength`, `FastMALength`, `SlowMALength`), esta estrategia requiere aproximadamente 90 trades en la muestra histórica antes de que los resultados de optimización sean significativos. Los parámetros marcados como "Fijar" deben establecerse por lógica de diseño, no buscando el mejor valor histórico — hacerlo infla el rendimiento dentro de la muestra sin mejorar la robustez fuera de ella.

**Sobre `CurrencyCorrelation` y `BondCorrelation`:** Son hipótesis económicas, no objetivos de optimización. Establecerlos basándose en la relación conocida entre el mercado primario y los secundarios (p.ej. el DAX tiende a debilitarse cuando el EURUSD sube, o los futuros de renta variable tienden a debilitarse cuando los bonos suben en regímenes risk-off) da a los filtros un significado predictivo genuino. Cambiar su signo hasta que el backtest mejore es una forma de overfitting.

---

## Escenarios de operación

### Escenario A — Ciclo completo: entrada, piramidación, salida por ATR

- `LongTrendSignal = True`. `LongFilterPassed = True`. `ConsecutiveLosses = 1`. Sin pausa activa.
- El precio rompe por encima de `LongBreakoutLevel`. **`Breakout_LE` se ejecuta.**
- Posición rentable. `OpenPositionProfit > 500`. `PyramidCount = 0 < MaxPyramidLevels = 1`.
- **`ReEntry_LE` se ejecuta a mercado.** `PyramidCount = 1`.
- La tendencia continúa. El trailing stop ATR sube con cada barra.
- El precio se revierte. `ATRStop_LX` se activa. Ambas posiciones cierran. `PyramidCount = 0`. `ConsecutiveLosses = 0`.

### Escenario B — Activación de la lógica de pausa

- Tres pérdidas consecutivas. `ConsecutiveLosses = 3`.
- Barra con `LongTrendSignal = True` y `LongFilterPassed = True`. Pausa activa.
- **Señal omitida.** `SkippedSignals = 1 >= SignalsToSkip = 1`. Ambos contadores se resetean.
- Siguiente señal válida: `ConsecutiveLosses = 0`. **La entrada se dispara normalmente.**

### Escenario C — Salida por régimen durante el trade

- Posición larga abierta. `PyramidCount = 1` (una re-entrada activa, dos unidades largas).
- Los filtros de divisa y bonos cambian. `ShortFilterPassed = True`.
- **`FilterExit_LX` se dispara a mercado.** La posición completa (ambas unidades) cierra. `PyramidCount = 0`.
- Si esta salida es una pérdida: `ConsecutiveLosses` se incrementa en la actualización de seguimiento de la siguiente barra.

### Escenario D — Filtros desactivados, operación solo por tendencia

- `CurrencyCorrelation = 0`, `BondCorrelation = 0`.
- `LongFilterPassed = True` siempre (ambos filtros desactivados).
- La estrategia opera únicamente con señales de tendencia y ruptura, sin confirmación intermercado.
- Esta configuración es útil para pruebas de línea base: comparar el rendimiento con y sin filtros activos revela el valor incremental de la capa de confirmación intermercado.

### Escenario E — Límite de piramidación alcanzado

- Posición larga abierta. `PyramidCount = 1 = MaxPyramidLevels`.
- `OpenPositionProfit > ProfitReentryThreshold` de nuevo en una barra posterior.
- **Re-entrada bloqueada** (`PyramidCount < MaxPyramidLevels` es False). No se añade posición adicional.

---

## Características clave

- **Arquitectura de tres motores:** La lógica de señal, filtro y entrada está separada en bloques independientes etiquetados, haciendo cada componente auditable y modificable sin tocar los demás.
- **Inputs de correlación intermercado:** `CurrencyCorrelation` y `BondCorrelation` aceptan `1`, `-1` o `0`, codificando la relación económica como parámetro en lugar de lógica hardcodeada. Establecer cualquiera en `0` desactiva el filtro correspondiente para pruebas de línea base.
- **Períodos de media independientes (v3):** `FilterMALength` desacopla la evaluación del filtro de mercados secundarios de la detección de tendencia del mercado primario. `ATRLength` desacopla la sensibilidad del stop del período de tendencia.
- **Lógica de pausa con doble contador (v3):** `ConsecutiveLosses` y `SkippedSignals` separan la detección de pérdidas de la gestión de la pausa, haciendo ambos umbrales configurables independientemente.
- **Límite de piramidación (v3):** `MaxPyramidLevels` previene la acumulación ilimitada de posición. `PyramidCount` se resetea tanto en salidas forzadas como en salidas naturales.
- **Salida por régimen como liquidación total:** `FilterExit` cierra la posición completa incluyendo todas las unidades piramidadas. Si el régimen ha cambiado, toda la exposición direccional se elimina simultáneamente.
- **Trailing stop ATR encapsulado (v3):** Toda la lógica del stop se ejecuta únicamente cuando hay una posición abierta, eliminando cómputo innecesario en barras planas.

---

## Psicología del trading

Intermarket Filtered Trend Breakout encarna una convicción específica: **una tendencia aislada es menos fiable que una tendencia confirmada por el régimen macro más amplio.** Una ruptura en el mercado primario que ocurre mientras los mercados secundarios correlacionados están tendiendo en su contra es una señal de menor calidad que una donde todos los mercados están alineados. Los filtros no generan trades — los filtran.

La lógica de pausa refleja una postura pragmática ante las rachas de pérdidas: en lugar de reducir el tamaño de posición o detener el trading completamente, la estrategia toma un único respiro tras tres pérdidas consecutivas. La suposición es que una pausa corta — dejar pasar una señal — puede ser suficiente para sortear un período de mal ajuste al mercado sin abandonar el sistema por completo.

La re-entrada piramidal codifica convicción en dejar correr los ganadores: cuando una posición existente ya es rentable, añadir a ella está racionalmente justificado — el mercado ya ha validado la dirección. El límite `MaxPyramidLevels` previene que esta convicción se convierta en imprudencia.

La salida por régimen es el reconocimiento de la estrategia de que ninguna tendencia dura para siempre en el mismo contexto macro. Cuando los mercados secundarios cambian, la tendencia del mercado primario pierde su apoyo intermercado — salir inmediatamente, en lugar de esperar al stop ATR, refleja una visión estructural más que una basada en precio.

---

## Casos de uso

**Instrumentos y configuraciones de datos:** La estrategia está diseñada para instrumentos con relaciones intermercado identificables — los futuros de índices de renta variable (DAX, NQ, ES) filtrados por sus mercados de divisa y bonos asociados son la aplicación natural. Las direcciones de correlación específicas deben establecerse basándose en la relación macro conocida: índice de renta variable / bonos (típicamente inversa en regímenes risk-off), índice de renta variable / divisa (la relación varía por mercado — DAX/EURUSD es un par habitual). Probar primero con `CurrencyCorrelation = 0` y `BondCorrelation = 0` establece el edge de tendencia-ruptura de línea base antes de evaluar la contribución incremental de cada filtro.

**Consideraciones de temporalidad:** La estrategia usa `SlowMALength` y `FilterMALength` como períodos separados aplicados a sus respectivos feeds de datos. Dado que Data1, Data2 y Data3 pueden operar en diferentes intervalos de barra, el mismo período numérico significa cosas distintas en cada feed — 50 barras en un gráfico de 15 minutos son aproximadamente 12 horas; 50 barras en un gráfico diario son diez semanas. Los valores de parámetros deben elegirse con conciencia de lo que cada período representa en tiempo calendario en cada feed.

**Validación walk-forward:** Dado el número de parámetros configurables, se recomienda encarecidamente el testing walk-forward frente a la optimización simple dentro de la muestra. Los parámetros más sensibles al overfitting son `ChannelLength`, `FastMALength` y `SlowMALength` sobre Data1. `FilterMALength` debe probarse para robustez a través de un rango de valores en lugar de optimizarse a un único punto.

**Rol en el portfolio:** Como estrategia de seguimiento de tendencia multi-data, este componente es más útil en un portfolio junto a estrategias de reversión a la media (que funcionan mejor en condiciones de rango sin tendencia). La capa de filtro intermercado significa que generará menos señales que una estrategia pura de ruptura de tendencia — menor frecuencia, pero entradas de mayor convicción.
