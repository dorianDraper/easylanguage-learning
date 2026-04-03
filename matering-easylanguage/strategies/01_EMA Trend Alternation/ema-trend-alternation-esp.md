# EMA Trend Alternation Strategy — v1.0, v2.0 & v3.0

## Descripción de la Estrategia

La EMA Trend Alternation Strategy es un sistema de seguimiento de tendencia construido en torno a una única restricción estructural: **la alternancia direccional es obligatoria**. Tras cerrar una operación larga, la estrategia no puede abrir otra posición larga hasta que se haya tomado una corta — y viceversa. Esta rotación forzada no es un efecto secundario de la lógica; es el rasgo arquitectónico definitorio. La dirección tendencial se determina por la relación entre una EMA rápida y una EMA lenta, y un período de cooldown configurable impide la reentrada inmediata tras una salida. Todas las posiciones se gestionan con targets de beneficio y stops de pérdida fijos.

---

## Mecánica Central

### 1. Detección de Tendencia

Dos medias móviles exponenciales definen el sesgo direccional del mercado:

```pascal
FastEMA = XAverage(FastEMAPrice, FastEMALength);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALength);

BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;
```

`XAverage` es la función nativa de media móvil exponencial en EasyLanguage. La relación entre ambas EMAs actúa como filtro de tendencia simple: cuando la EMA rápida está por encima de la lenta, la estrategia considera el mercado alcista; cuando está por debajo, bajista. Nótese que `BullTrend` y `BearTrend` solo podrían ser simultáneamente falsos si las dos EMAs fueran exactamente iguales — en la práctica, siempre hay una activa.

### 2. Máquina de Estados de Posición

La estrategia registra explícitamente el estado actual y anterior de la posición:

```pascal
IsFlat  = MarketPosition =  0;
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;

PreviousPosition = MarketPosition(1);  // Solo v2+
```

`MarketPosition(1)` devuelve la posición de mercado de la operación anterior — no de la barra anterior. Esta es la función clave que permite la lógica de alternancia: le indica a la estrategia cuál fue el *último trade cerrado*, independientemente de cuántas barras hayan transcurrido desde entonces.

> **Nota v1:** En v1, `MarketPosition(1)` se usa directamente en las condiciones de entrada en lugar de almacenarse en una variable con nombre. v2 introduce `PreviousPosition` como variable dedicada, mejorando la legibilidad sin alterar el comportamiento.

### 3. Condiciones de Cooldown y Primera Operación

```pascal
CooldownPassed = BarsSinceExit(1) >= CooldownBars;
FirstTrade     = TotalTrades = 0;
```

`BarsSinceExit(1)` devuelve el número de barras desde la última salida de una posición larga. `TotalTrades = 0` identifica la primera operación de la estrategia, cuando no existe posición anterior con la que alternar. Ambas condiciones juntas gestionan tanto el caso límite (primera operación) como el estado estacionario (todas las operaciones siguientes).

### 4. Motor de Alternancia — Lógica de Entrada

Las condiciones de entrada codifican directamente la restricción de alternancia:

```pascal
// Entrada larga: tendencia alcista + (primera operación O anterior fue corta + cooldown pasado)
If (FirstTrade or (CooldownPassed and PreviousPosition = -1))
    and BullTrend Then
    Buy ("EMA_Trend_LE") Next Bar at Market;

// Entrada corta: tendencia bajista + (primera operación O anterior fue larga + cooldown pasado)
If (FirstTrade or (CooldownPassed and PreviousPosition = 1))
    and BearTrend Then
    SellShort ("EMA_Trend_SE") Next Bar at Market;
```

La lógica se lee así: *"puedo ir largo si esta es mi primera operación, o si mi último trade fue corto, el cooldown ha pasado y la tendencia es actualmente alcista."* Tres puertas deben abrirse simultáneamente: alineación de tendencia, alternancia direccional y tiempo desde la última salida.

**¿Por qué esta combinación?** Cada puerta aborda un modo de fallo distinto:
- Sin la **puerta de tendencia**, la estrategia entra contra la dirección predominante de las EMAs.
- Sin la **puerta de alternancia**, son posibles operaciones largas o cortas consecutivas, anulando el principio de diseño central.
- Sin la **puerta de cooldown**, la estrategia reingresa inmediatamente tras la salida, aumentando la exposición a whipsaws.

### 5. Gestión de Salidas

Ambas órdenes de salida se colocan simultáneamente en cada barra que la estrategia mantiene una posición:

```pascal
// Salidas largo
Sell ("TP_LX") Next Bar at EntryPrice + ProfitTargetPoints Limit;
Sell ("SL_LX") Next Bar at EntryPrice - StopLossPoints Stop;

// Salidas corto
BuyToCover ("TP_SX") Next Bar at EntryPrice - ProfitTargetPoints Limit;
BuyToCover ("SL_SX") Next Bar at EntryPrice + StopLossPoints Stop;
```

La gestión de órdenes de EasyLanguage garantiza que solo se ejecute una — la que alcance su nivel primero. Una vez ejecutada, la otra se cancela automáticamente. Esto crea una estructura fija de riesgo/beneficio en cada operación sin necesidad de lógica de salida adicional.

---

## v1 → v2 → v3: Evolución de la Arquitectura de Código

Las tres versiones implementan lógica de trading idéntica. La evolución es enteramente de estructura y legibilidad del código.

### v1 — Funcional pero Compacto

Toda la lógica es inline. `MarketPosition(1)` se llama directamente dentro de la condición de entrada, y no hay separación entre la evaluación de señales y la ejecución de órdenes:

```pascal
If IsFlat Then
Begin
    If (FirstTrade or (CooldownPassed and MarketPosition(1) = -1))
        and BullTrend Then
        Buy ("EMA_Trend_LE") Next Bar at Market;
End;
```

Funciona, pero mezclar consultas de estado de posición, condiciones temporales y ejecución en un único bloque dificulta la auditoría, especialmente a medida que la complejidad crece.

### v2 — Variables con Nombre y Bloques Estructurados

v2 introduce `PreviousPosition` como variable dedicada y separa el código en bloques claramente etiquetados usando los delimitadores de comentario `{-- --}` de EasyLanguage:

```pascal
PreviousPosition = MarketPosition(1);

{ Entrada larga: tendencia alcista confirmada, anterior fue corta, cooldown satisfecho }
If (FirstTrade or (CooldownPassed and PreviousPosition = -1))
    and BullTrend Then
    Buy ("EMA_Trend_LE") Next Bar at Market;
```

La condición de entrada es ahora idéntica en estructura pero más clara: `PreviousPosition = -1` se entiende inmediatamente como "el último trade fue corto", mientras que `MarketPosition(1) = -1` requiere que el lector sepa qué significa el argumento `(1)`.

### v3 — Separación Señal/Ejecución

v3 es el punto final arquitectónico. Introduce `LongSignal` y `ShortSignal` como variables booleanas explícitas, separando completamente la evaluación de señales de la ejecución de órdenes:

```pascal
{ MOTOR DE SEÑALES }
LongSignal =
    IsFlat and
    BullTrend and
    (FirstTrade or (CooldownPassed and PreviousPosition = -1));

ShortSignal =
    IsFlat and
    BearTrend and
    (FirstTrade or (CooldownPassed and PreviousPosition = 1));

{ MOTOR DE EJECUCIÓN }
If LongSignal  Then Buy       ("EMA_Trend_LE") Next Bar at Market;
If ShortSignal Then SellShort ("EMA_Trend_SE") Next Bar at Market;
```

Este patrón — calcular la señal, luego actuar sobre ella — es el mismo principio arquitectónico aplicado en Multi-Data Strategy v3/v4. La ventaja es que cada motor puede leerse, modificarse y depurarse de forma independiente. Añadir un nuevo filtro a la señal es un cambio de una línea en el bloque de señales; cambiar el tipo de ejecución (limit vs. market) solo toca el bloque de ejecución.

### Resumen

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Lógica de trading** | ✓ | ✓ | ✓ |
| **`PreviousPosition` con nombre** | — | ✓ | ✓ |
| **Bloques de código estructurados** | — | ✓ | ✓ |
| **Separación Señal/Ejecución** | — | — | ✓ |
| **Parámetros** | 7 | 7 | 7 |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `FastEMAPrice` | Close | Campo de precio para calcular la EMA rápida. |
| `FastEMALength` | 9 | Período de la EMA rápida. Más corto = más sensible al precio reciente. |
| `SlowEMAPrice` | Close | Campo de precio para calcular la EMA lenta. |
| `SlowEMALength` | 18 | Período de la EMA lenta. Más largo = representación de tendencia más suave y lenta. |
| `CooldownBars` | 3 | Barras mínimas entre una salida y la siguiente entrada. Filtra whipsaws. |
| `ProfitTargetPoints` | 1 | Puntos por encima (largo) o por debajo (corto) de la entrada para el target de beneficio. |
| `StopLossPoints` | 0.5 | Puntos por debajo (largo) o por encima (corto) de la entrada para el stop de pérdida. |

**Sobre los parámetros de riesgo por defecto:** El target de 1 punto y el stop de 0.5 puntos implican una ratio beneficio/riesgo de 2:1, pero los valores absolutos son ajustados y están orientados principalmente a mercados intradiarios de alta liquidez. Estos valores por defecto deben tratarse como punto de partida para backtesting, no como valores de producción.

---

## Escenarios de Operación

### Escenario A — Primera Operación (Largo)

- Sin operaciones previas: `TotalTrades = 0` → `FirstTrade = True`
- ES 15-min: FastEMA en 4.992, SlowEMA en 4.988 → `BullTrend = True`
- Condición de alternancia omitida (primera operación) → `LongSignal = True`
- **Compra en la siguiente barra a mercado.** Entrada ejecutada a 4.993.
- Target de beneficio en 4.994 (entrada + 1 pt); stop de pérdida en 4.992,5 (entrada − 0,5 pt)
- El target de beneficio se ejecuta. La operación cierra a 4.994.

### Escenario B — Corto Obligatorio Tras Largo

- Operación anterior fue larga: `PreviousPosition = 1`
- `BarsSinceExit(1) = 4` ≥ `CooldownBars (3)` → `CooldownPassed = True`
- ES 15-min: FastEMA en 4.985, SlowEMA en 4.990 → `BearTrend = True`
- Todas las condiciones cortas cumplidas → `ShortSignal = True`
- **SellShort en la siguiente barra a mercado.** Entrada ejecutada a 4.984.
- Target de beneficio en 4.983 (entrada − 1 pt); stop de pérdida en 4.984,5 (entrada + 0,5 pt)

### Escenario C — Largo Bloqueado por Alternancia

- Operación anterior también fue larga: `PreviousPosition = 1`
- `CooldownPassed = True`
- ES 15-min: FastEMA subiendo por encima de SlowEMA → `BullTrend = True`
- Condición de alternancia: se requiere `PreviousPosition = -1`, pero `PreviousPosition = 1`
- → `LongSignal = False`
- **Sin entrada.** La estrategia permanece flat y espera a que un corto complete el ciclo de alternancia antes de que pueda volver a activarse una señal larga.

### Escenario D — Largo Bloqueado por Cooldown

- Operación anterior fue corta: `PreviousPosition = -1` ✓
- `BarsSinceExit(1) = 2` < `CooldownBars (3)` → `CooldownPassed = False`
- `BullTrend = True` ✓
- Puerta de cooldown no satisfecha → `LongSignal = False`
- **Sin entrada.** La estrategia espera una barra más para que la ventana de cooldown se complete.

---

## Características Clave

- **Alternancia direccional forzada:** La rotación obligatoria largo → corto → largo es la restricción estructural definitoria de la estrategia, no un filtro incidental.
- **Entrada de tres puertas:** Alineación de tendencia, cumplimiento de alternancia y cooldown transcurrido deben satisfacerse simultáneamente. Cada puerta aborda un modo de fallo distinto.
- **Separación señal/ejecución (v3):** La división en Motor de Señales y Motor de Ejecución hace la lógica modular y más fácil de extender sin introducir errores.
- **Riesgo/beneficio fijo por operación:** El target de beneficio y el stop de pérdida se definen en la entrada, proporcionando claridad inmediata en el sizing de la posición y eliminando las decisiones discrecionales de salida.
- **Gestión del caso límite `FirstTrade`:** La estrategia gestiona correctamente su primera operación sin requerir una posición previa con la que alternar.
- **Etiquetas de orden descriptivas:** `TP_LX`, `SL_LX`, `TP_SX`, `SL_SX` permiten desglosar el rendimiento por tipo de salida en los informes de TradeStation.

---

## Psicología del Trading

La EMA Trend Alternation Strategy se construye sobre una premisa engañosamente simple: **ningún trader — humano o algorítmico — debería poder doblar la apuesta en la misma dirección sin antes probar el lado contrario.**

La mayoría de los sistemas de seguimiento de tendencia acumulan exposición direccional añadiendo a posiciones ganadoras o reingresando en la misma dirección repetidamente. La restricción de alternancia invierte esto: tras un largo, el sistema está *obligado* a participar en un corto antes de poder volver a ir largo. Esto crea una forma mecánica de diversidad cognitiva — el sistema no puede quedarse "atascado" en modo alcista o bajista. Piénsalo como una regla que dice: *"antes de argumentar el mismo punto de nuevo, debes argumentar genuinamente el opuesto."*

El período de cooldown refuerza esto añadiendo una pausa obligatoria tras cada salida. Los mercados frecuentemente oscilan alrededor de los niveles de las medias móviles; la espera de tres barras filtra las reentradas más ruidosas y obliga a la estrategia a esperar a que las condiciones se restablezcan en lugar de perseguir cada cruce.

El target de beneficio y el stop de pérdida fijos eliminan las dos decisiones psicológicamente más dañinas en el trading discrecional — cuándo tomar beneficios y cuándo cortar pérdidas — codificándolas como reglas en el momento de la entrada. Una vez dentro de una operación, la estrategia no tiene decisiones que tomar.

> **Pregunta abierta para investigación:** ¿La alternancia forzada beneficia o perjudica el rendimiento respecto a una versión sin restricciones del mismo sistema? La hipótesis es que reduce el drawdown al prevenir la sobreexposición direccional, pero esto debe validarse en backtesting a través de múltiples instrumentos y regímenes de mercado.

---

## Casos de Uso

**Instrumentos:** Principalmente adecuada para mercados intradiarios líquidos donde los targets de beneficio en puntos fijos son ejecutables sin slippage significativo — ES, NQ y otros futuros de índices de renta variable durante el horario regular de trading. Los parámetros por defecto ajustados (1 pt de target, 0,5 pt de stop) requieren liquidez consistente.

**Marcos temporales:** Diseñada para uso intradiario. La combinación 9/18 EMA en barras de 5-min o 15-min proporciona un filtro de tendencia razonable sin excesivo lag. Marcos temporales más amplios producirán menos operaciones y pueden requerir ajustar proporcionalmente los niveles de target y stop.

**Perfil del trader:** Adecuada para traders sistemáticos que quieren una estrategia completamente mecánica sin decisiones discrecionales de salida. La restricción de alternancia la hace especialmente interesante como **herramienta de diversificación dentro de un portfolio**: si se opera junto a una estrategia convencional de seguimiento de tendencia, la rotación forzada proporciona una cobertura estructural contra la sobreexposición direccional.

**Condiciones de mercado:** Rinde mejor en mercados con oscilaciones direccionales regulares que permitan que ambas direcciones se desarrollen dentro de una sesión. Tiene dificultades en mercados fuertemente unidireccionales donde la alternancia fuerza un corto durante una tendencia alcista sostenida — o viceversa. Este es el trade-off central del diseño y debe cuantificarse en backtesting.

**Sobre los parámetros por defecto:** El target de 1 punto y el stop de 0,5 puntos son un marco de partida, no valores listos para producción. Ambos deben optimizarse por instrumento y marco temporal antes del despliegue en real.
