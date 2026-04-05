# Breakout — v1.0, v2.0 & v3.0

🇪🇸 Español | 🇬🇧 [English](README.md)

## Descripción de la Estrategia

Breakout es una estrategia de seguimiento de momentum que entra al mercado cuando el precio rompe más allá del máximo más alto o el mínimo más bajo de una ventana de lookback configurable. La premisa central es simple: si el mercado ha estado contenido dentro de un rango durante un número de barras y luego rompe ese rango con convicción, el breakout vale la pena operarlo. La estrategia es always-in-the-market por diseño — las órdenes stop están activas en cada barra y solo se ejecutan si el precio alcanza el nivel de breakout.

Las tres versiones comparten la misma lógica de entrada y evolucionan en dos pasos distintos: v1 a v2 mejora la legibilidad y parametrización sin cambiar el comportamiento; v2 a v3 añade una capa completa de gestión del riesgo — stop loss, objetivo de beneficio y break even — transformando un ejercicio de entrada pura en un sistema operable y autocontenido.

---

## Mecánica Central

### 1. Cálculo del Nivel de Breakout

La estrategia identifica el máximo más alto y el mínimo más bajo durante una ventana de lookback en cada barra:

```pascal
// v1
BuyPx  = Highest(High, TrlgBars) + .02;
SellPx = Lowest(Low,  TrlgBars)  - .02;

// v2
LongBreakout  = Highest(LongPrice,  LongLen)  + EntryBuffer;
ShortBreakout = Lowest(ShortPrice,  ShortLen) - EntryBuffer;

// v3
BuyBrk  = Highest(High, BuyLen)  + StopPoints;
SellBrk = Lowest(Low,  SellLen)  - StopPoints;
```

`Highest(High, N)` devuelve el máximo más alto de las últimas N barras incluyendo la barra actual. `Lowest(Low, N)` devuelve el mínimo más bajo. Se añade un pequeño buffer (`.02` por defecto) por encima del máximo y se resta por debajo del mínimo — esto evita la ejecución en un toque exacto del nivel, filtrando las aproximaciones marginales de precio que carecen de seguimiento.

**¿Por qué no se usa el offset `[1]`?** A diferencia de las estrategias de detección de patrones que usan `[1]` para evitar lookahead, las estrategias de breakout incluyen deliberadamente la barra actual en el cálculo. La lógica es: la orden se coloca para la *siguiente barra*, por lo que el cálculo debe reflejar el rango más actual disponible — incluyendo la barra que está cerrando ahora mismo. Usar `[1]` calcularía un nivel potencialmente obsoleto, haciendo que el umbral de breakout se retrase una barra detrás del mercado. En el trading de breakout, ese retraso significa perderse el nivel preciso donde comienza el movimiento de convicción.

### 2. Entradas con Órdenes Stop — Siempre Activas

```pascal
Buy      ("Brk LE") Next Bar at LongBreakout  Stop;
SellShort("Brk SE") Next Bar at ShortBreakout Stop;
```

No hay condiciones `If` alrededor de las órdenes de entrada. Ambas órdenes stop se colocan en cada barra y permanecen activas hasta que el precio alcance el nivel respectivo o la barra cierre sin ejecución. Esto es arquitectónicamente correcto — una orden stop *es* la condición. Si el precio no alcanza `LongBreakout`, la orden de compra no se ejecuta. Si lo alcanza, se ejecuta como confirmación de momentum: el precio ha roto el rango.

Esto crea un sistema always-in-the-market: una vez que una posición larga se cierra, la orden stop corta está inmediatamente activa (y viceversa), lo que significa que la estrategia siempre está posicionada para capturar el siguiente breakout en cualquier dirección.

### 3. Gestión del Riesgo (Solo v3)

v3 añade tres mecanismos de salida aplicados por acción:

```pascal
SetStopShare;

SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);
```

`SetStopShare` instruye a TradeStation para aplicar todas las funciones de stop posteriores por acción o por contrato en lugar de por posición total. Esto garantiza un riesgo en dólares consistente independientemente del tamaño de posición.

**Stop Loss (`SetStopLoss`):** Cierra la posición si alcanza una pérdida de `StopAmt` por acción. Con el valor por defecto de `$0,20`, la operación sale automáticamente si el precio se mueve `$0,20` contra la entrada.

**Objetivo de Beneficio (`SetProfitTarget`):** Cierra la posición cuando alcanza una ganancia de `TargetAmt` por acción. Con el valor por defecto de `$0,30`, la estrategia apunta a una ratio beneficio/riesgo de 1,5:1 ($0,30 target vs $0,20 stop).

**Break Even (`SetBreakeven`):** Una vez que la posición alcanza una ganancia de `BEAmt` por acción (`$0,15` por defecto), el stop loss se mueve automáticamente al precio de entrada. A partir de ese momento, la operación no puede perder — el peor resultado es una salida en breakeven. La secuencia es:

```
Entrada → avance $0,15 → stop se mueve al precio de entrada → target en $0,30
```

Piensa en el break even como una salida en dos etapas: la operación se gana el estado de riesgo-cero tras demostrar momentum inicial, y luego continúa hacia el objetivo de beneficio desde una posición protegida.

---

## v1 → v2 → v3: Evolución de la Arquitectura de Código

### v1 — Mínimo y Fundacional

v1 expresa la lógica central del breakout en su forma más compacta. Un único input (`TrlgBars`) controla tanto el lookback largo como el corto de forma idéntica, y el buffer está hardcodeado a `.02`:

```pascal
Input: TrlgBars(8);

BuyPx  = Highest(High, TrlgBars) + .02;
SellPx = Lowest(Low,  TrlgBars)  - .02;

Buy      ("BrkLE") Next Bar at BuyPx  Stop;
SellShort("BrkSE") Next Bar at SellPx Stop;
```

v1 es una base educativa limpia — toda la estrategia son cinco líneas de lógica. Su limitación es la inflexibilidad: el buffer no puede cambiarse sin editar el código, y los lookbacks largo y corto no pueden ajustarse de forma independiente.

### v2 — Parametrizada y Autodocumentada

v2 expone cada constante como un input con nombre y separa la fuente de precio del período de lookback:

```pascal
Inputs:
    LongPrice(High),   ShortPrice(Low),
    LongLen(8),        ShortLen(8),
    EntryBuffer(.02);

LongBreakout  = Highest(LongPrice,  LongLen)  + EntryBuffer;
ShortBreakout = Lowest(ShortPrice,  ShortLen) - EntryBuffer;
```

`LongPrice` y `ShortPrice` como inputs es una decisión arquitectónica significativa: al tener por defecto `High` y `Low` respectivamente pero siendo configurables, la estrategia puede cambiarse para usar `Close` como precio de referencia del breakout sin ningún cambio en el código — solo una actualización de parámetros. `LongLen` y `ShortLen` permiten ventanas de lookback asimétricas, útiles si el instrumento muestra características de momentum diferentes en el lado largo y en el corto.

Los nombres de variables `LongBreakout` y `ShortBreakout` describen *qué es el valor* (un nivel de breakout) en lugar de para qué se usa (`BuyPx`, `SellPx`), haciendo que el código se lea más como una especificación que como un conjunto de cálculos.

### v3 — Sistema Completo con Gestión del Riesgo

v3 añade la capa de salida que transforma el framework de entrada en una estrategia autocontenida. La lógica de entrada es idéntica a v1/v2 (con la convención de nomenclatura propia de v3), y tres nuevos inputs y tres nuevas funciones de salida completan el sistema:

```pascal
Input:
    BuyLen(8),    SellLen(8),
    StopPoints(.02),
    StopAmt(.2),  TargetAmt(.3),  BEAmt(.15);

SetStopShare;
SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);
```

La adición de `SetBreakeven` es la mejora clave sobre un sistema simple de stop/target. Sin break even, una operación que alcanza $0,14 de beneficio y luego revierte sale en el stop con una pérdida de $0,20 — un swing de casi $0,34 desde casi-target hasta pérdida máxima. Con break even activo, una vez que la operación toca $0,15, el peor resultado pasa de −$0,20 a $0,00. El mecanismo de break even convierte una operación con posible pérdida en una operación sin-peor-que-breakeven una vez que se confirma el momentum inicial.

**Resumen:**

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Lógica de entrada breakout** | ✓ | ✓ | ✓ |
| **Lookbacks largo/corto independientes** | — | ✓ | ✓ |
| **Fuente de precio configurable** | — | ✓ (`LongPrice`, `ShortPrice`) | — |
| **Input `EntryBuffer` con nombre** | — | ✓ | ✓ (`StopPoints`) |
| **Stop loss** | — | — | ✓ |
| **Objetivo de beneficio** | — | — | ✓ |
| **Break even** | — | — | ✓ |
| **`SetStopShare`** | — | — | ✓ |

---

## Parámetros

### v1

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `TrlgBars` | 8 | Período de lookback para los niveles de breakout largo y corto. |

### v2

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `LongPrice` | `High` | Serie de precio usada para el cálculo del breakout largo. |
| `LongLen` | 8 | Barras de lookback para el nivel de breakout largo. |
| `ShortPrice` | `Low` | Serie de precio usada para el cálculo del breakout corto. |
| `ShortLen` | 8 | Barras de lookback para el nivel de breakout corto. |
| `EntryBuffer` | 0,02 | Buffer añadido/restado al nivel de breakout para evitar ejecuciones marginales. |

### v3

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `BuyLen` | 8 | Barras de lookback para el nivel de breakout largo. |
| `SellLen` | 8 | Barras de lookback para el nivel de breakout corto. |
| `StopPoints` | 0,02 | Buffer añadido/restado al nivel de breakout. |
| `StopAmt` | $0,20 | Stop loss por acción/contrato. |
| `TargetAmt` | $0,30 | Objetivo de beneficio por acción/contrato. |
| `BEAmt` | $0,15 | Ganancia por acción a la que el stop se mueve al precio de entrada (break even). |

**Sobre los parámetros de riesgo por defecto en v3:** Los valores de $0,20 de stop, $0,30 de target y $0,15 de break even están calibrados para precios de acciones. Para contratos de futuros, estos valores deben ajustarse para reflejar el `BigPointValue` y el rango intrabarra típico del instrumento. Para futuros ES a $50/punto, $0,20 equivale a 0,004 puntos — demasiado ajustado para cualquier stop significativo. Escalar proporcionalmente al instrumento.

---

## Escenarios de Operación

### Escenario A — Breakout Largo, Break Even, Luego Target (v3)

- Máximo más alto de 8 barras: 45,80. `LongBreakout = 45,82` (+ buffer de 0,02).
- El precio sube a través de 45,82. Entrada larga ejecutada a 45,82.
- `StopLoss` activo a 45,62 (45,82 − 0,20). `ProfitTarget` en 46,12 (45,82 + 0,30).
- El precio avanza hasta 45,97 (ganancia de 0,15). `SetBreakeven` se activa. Stop se mueve a 45,82.
- La operación está ahora sin riesgo. Stop en entrada, target en 46,12.
- El precio alcanza 46,12. Objetivo de beneficio ejecutado. Operación sale con +$0,30/acción.

### Escenario B — Breakout Largo, Stop Loss Antes del Break Even (v3)

- Misma entrada a 45,82. Stop en 45,62. Target en 46,12.
- El precio avanza hasta 45,90, luego revierte. Nunca alcanza el nivel de break even de 45,97.
- El precio cae por debajo de 45,62. Stop ejecutado. Operación sale con −$0,20/acción.

### Escenario C — Breakout Largo, Salida en Break Even (v3)

- Entrada a 45,82. El precio toca 45,97. Break even activa. Stop se mueve a 45,82.
- El precio retrocede antes de alcanzar el target. Cae por debajo de 45,82. Stop de break even ejecutado.
- Operación sale al precio de entrada. Resultado neto: $0,00 (antes de comisiones).

### Escenario D — Sin Breakout, Sin Operación (v1/v2/v3)

- Máximo más alto de 8 barras: 45,80. `LongBreakout = 45,82`.
- El precio se mueve hasta 45,78 — por debajo del nivel de breakout.
- La orden stop no se activa. Sin posición. Las órdenes se actualizan en la siguiente barra con los niveles revisados.

---

## Características Clave

- **Arquitectura always-in-the-market:** Las órdenes stop se colocan en cada barra sin condiciones. Ambas direcciones están simultáneamente activas y compiten para ser el primer breakout en activarse.
- **Filtro de buffer:** El pequeño offset por encima del máximo y por debajo del mínimo evita la ejecución en toques exactos del nivel, filtrando el ruido y requiriendo una penetración genuina del rango.
- **Sin offset `[1]`:** El cálculo del breakout incluye la barra actual para mantener los niveles actualizados. Usar el cálculo de la barra anterior introduciría un retraso de una barra — indeseable en un sistema de momentum donde el nivel de entrada debe reflejar el límite del rango en vivo.
- **Fuente de precio configurable (v2):** Los inputs `LongPrice` y `ShortPrice` permiten cambiar de breakouts de High/Low a breakouts basados en Close sin modificación de código.
- **Lookback asimétrico (v2/v3):** `LongLen` y `ShortLen` independientes permiten ajustar las ventanas de breakout largo y corto por separado, útil cuando un instrumento muestra diferente duración de momentum en cada lado.
- **Protección de break even (v3):** Una vez que el momentum inicial se confirma alcanzando `BEAmt`, la operación no puede perder — convirtiendo una posición arriesgada en una operación gratuita con beneficio potencial restante.
- **Cumplimiento de `SetStopShare` (v3):** La gestión de stops por contrato garantiza el comportamiento correcto en diferentes tamaños de posición.

---

## Psicología del Trading

Breakout es una de las expresiones más puras de la lógica de seguimiento de tendencia: **el mercado te dice cuándo entrar al romper su propio rango reciente.** No hay predicción, no hay opinión sobre la dirección, no hay interpretación de patrones de velas o cruces de indicadores. La estrategia simplemente dice: *"el mercado ha pasado las últimas N barras dentro de un rango. Si sale de ese rango de forma decisiva, algo está cambiando — quiero estar en el lado correcto de ese cambio."*

El diseño always-in-the-market refleja una postura filosófica específica: la estrategia no predice qué breakout ocurrirá, solo que los breakouts vale la pena operarlos cuando ocurren. Al mantener órdenes activas en ambas direcciones simultáneamente, elimina la necesidad de pronosticar la dirección — el mercado selecciona la dirección por ti.

El mecanismo de break even en v3 codifica una progresión de confianza: el stop inicial refleja escepticismo (la operación puede estar equivocada, limitar la pérdida), y el break even refleja confianza ganada (la operación ha mostrado momentum inicial, proteger la posición). Este modelo de confianza en dos etapas — protección inicial, luego seguridad ganada — refleja la forma en que los traders experimentados piensan sobre la gestión de posiciones a medida que una operación se desarrolla.

La evolución de tres versiones de esta estrategia también captura un principio de desarrollo importante: **empezar simple, extender deliberadamente.** v1 valida el concepto de entrada. v2 lo hace mantenible y flexible. v3 lo hace operable con riesgo definido. Cada versión añade exactamente una capa de complejidad con una razón clara, evitando la trampa común de construir un sistema complejo antes de validar la premisa central.

---

## Casos de Uso

**Instrumentos:** Breakout funciona en cualquier instrumento líquido con períodos de rango identificables seguidos de movimientos direccionales — futuros de índices de renta variable (ES, NQ), acciones individuales en fases de consolidación, futuros de materias primas (CL, GC), y futuros FX con rangos de sesión regulares. La ventana de lookback y el buffer deben calibrarse al rango de barra típico del instrumento.

**Marcos temporales:** El lookback de 8 barras es independiente del timeframe. En barras de 5 minutos captura aproximadamente 40 minutos de rango; en barras diarias captura las últimas 8 sesiones de trading. Los lookbacks más cortos producen breakouts más frecuentes y pequeños; los más largos producen breakouts más raros y significativos.

**v1 como plantilla:** La compacidad de v1 la convierte en un punto de partida ideal para la experimentación. Añadir un único filtro (p. ej. `If ADX > 20 Then`) o reemplazar la salida de mercado por una salida temporal puede hacerse en una o dos líneas, preservando la lógica de entrada limpia mientras se extiende el sistema de forma incremental.

**v3 en producción:** La combinación stop/target/break even en v3 proporciona el framework de riesgo mínimo viable para el despliegue en vivo. La ratio beneficio/riesgo de 1,5:1 ($0,30/$0,20) requiere una tasa de acierto superior a aproximadamente el 40% para ser rentable — un umbral realista para un sistema de breakout de momentum en mercados líquidos.

**Como componente fundacional:** Las tres versiones sirven como implementaciones de referencia para el patrón de entrada por breakout. Las estrategias más avanzadas en este repositorio que usan entradas por breakout (p. ej. con filtros de tendencia, confirmación multi-timeframe o sizing adaptativo) se construyen sobre la misma arquitectura de `Highest`/`Lowest` + orden stop establecida aquí.
