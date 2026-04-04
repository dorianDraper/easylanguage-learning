# ATRDollar TrailStop — v1.0 & v2.0

## Descripción de la Estrategia

ATRDollar TrailStop es un componente de gestión dinámica de salidas que reemplaza los stops fijos en puntos o en dólares por un mecanismo de trailing adaptativo a la volatilidad. En lugar de establecer un stop a una distancia predeterminada desde la entrada, el componente recalcula continuamente la distancia del stop basándose en el Average True Range (ATR), de modo que el stop se amplía de forma natural en períodos volátiles y se estrecha en períodos tranquilos. El stop se expresa en términos de dólares usando `BigPointValue`, haciéndolo agnóstico al instrumento y directamente comparable entre diferentes contratos de futuros.

El componente opera en dos fases secuenciales: un stop fijo inicial que protege la posición inmediatamente tras la entrada, seguido de un trailing stop dinámico que solo se activa una vez que la operación ha avanzado lo suficiente como para justificarlo. Este diseño de dos fases evita que el mecanismo de trailing cierre una posición prematuramente antes de que haya establecido un colchón de beneficio significativo.

---

## Mecánica Central

### 1. Cálculo del ATR

Todas las distancias del componente se derivan de un único valor de ATR, recalculado en cada barra:

```pascal
ATRValue = AvgTrueRange(ATRLen);
```

A partir de esto, se calculan tres distancias en puntos:

```pascal
FloorDistance    = ATRValue * ATRFloor;     // Distancia requerida para activar el trailing
TrailDistance    = ATRValue * ATRTrail;     // Distancia del trailing stop una vez activo
StopLossDistance = ATRValue * ATRStopLoss; // Distancia del stop loss inicial
```

Cada una se convierte a dólares al pasarse a las funciones de salida:

```pascal
StopLossDistance * BigPointValue   // Puntos → dólares
TrailDistance    * BigPointValue   // Puntos → dólares
```

`BigPointValue` es una palabra reservada de EasyLanguage que devuelve el valor en dólares de un punto completo para el instrumento actual. Para futuros ES, `BigPointValue = 50`, por lo que un ATR de 1,25 puntos se traduce en $62,50 de riesgo por contrato. Esta conversión hace que el componente funcione correctamente en cualquier instrumento sin hardcodear importes en dólares.

### 2. Máquina de Estados

El componente rastrea el estado de posición explícitamente y resetea el flag de trailing en cada barra flat:

```pascal
IsFlat  = MarketPosition =  0;
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;

If IsFlat Then
    TrailingActive = False;   // Reset para el siguiente trade
```

El reset en `IsFlat` es esencial: garantiza que `TrailingActive` comience como `False` al inicio de cada nueva operación, independientemente de cómo terminó la anterior.

### 3. SetStopShare

```pascal
SetStopShare;
```

Esta instrucción nativa de EasyLanguage indica a la plataforma que gestione los stops por acción o por contrato en lugar de por posición completa. Debe llamarse antes de cualquier llamada a `SetStopLoss` o `SetDollarTrailing` para garantizar que los cálculos de stop se apliquen correctamente cuando se opera con múltiples contratos.

### 4. Fase 1 — Stop Loss Inicial

Inmediatamente tras la entrada, mientras `TrailingActive = False`, solo está activo el stop loss inicial:

```pascal
If not TrailingActive Then
Begin
    SetStopLoss(StopLossDistance * BigPointValue);

    // Verificar si se ha alcanzado el floor
    If (IsLong  and High >= EntryPrice + FloorDistance) or
       (IsShort and Low  <= EntryPrice - FloorDistance) Then
        TrailingActive = True;
End;
```

La comprobación del floor usa `High` para largos y `Low` para cortos — el precio más favorable intrabarra — para determinar si la operación ha avanzado lo suficiente. Usar `High`/`Low` en lugar de `Close` significa que el floor puede alcanzarse en cualquier barra donde el precio toque brevemente el umbral, aunque no cierre por encima de él.

### 5. Fase 2 — Trailing Stop Dinámico

Una vez que `TrailingActive = True`, `SetDollarTrailing` toma el control:

```pascal
If TrailingActive Then
    SetDollarTrailing(TrailDistance * BigPointValue);
```

`SetDollarTrailing` es una función nativa de EasyLanguage que coloca un trailing stop a una distancia fija en dólares por debajo del máximo más alto (para largos) o por encima del mínimo más bajo (para cortos) alcanzado desde que se activó el stop. Como el ATR cambia barra a barra, `TrailDistance * BigPointValue` se recalcula automáticamente, de modo que la distancia del trailing stop se adapta a la volatilidad actual.

**La secuencia de dos fases visualizada:**

```
Entrada             Floor alcanzado        Trailing activo
  │                       │                      │
  ▼                       ▼                      ▼
──┼───────────────────────┼──────────────────────┼────────►
  │← StopLoss (1×ATR) ──►│← TrailStop (1×ATR) ──┤
  │                       │
  │← Floor (2×ATR) ──────►│ (activa el trailing)
```

Piénsalo como un cohete de dos etapas: el stop inicial es el propulsor que mantiene la operación viva a través de la turbulencia temprana, y el trailing stop es el motor de crucero que toma el control una vez que la operación ha alcanzado altitud.

---

## v1 vs v2: La Diferencia

Las dos versiones implementan lógica idéntica. La evolución es enteramente sobre nomenclatura de variables y legibilidad.

### v1 — Funcional pero Genérico

Los nombres de variables en v1 son abreviados y algunos llevan significados ambiguos a primera vista:

```pascal
Vars:
    ATR(0),              // Puede confundirse con la función AvgTrueRange en sí
    FloorAmount(0),      // "Amount" es ambiguo — ¿puntos o dólares?
    FloorFlag(false),    // "Flag" es un término genérico común
    ATRTrailAmount(0),
    ATRStopLossAmount(0);
```

### v2 — Nombres Autodocumentados

v2 renombra cada variable para hacer su rol y unidad inmediatamente claros:

```pascal
Vars:
    ATRValue(0),           // El valor ATR calculado (distinguible del nombre de la función)
    FloorDistance(0),      // "Distance" señala puntos, no dólares
    TrailDistance(0),      // Coherente con FloorDistance
    StopLossDistance(0),   // Misma convención de unidades
    TrailingActive(false); // Describe el estado actual — el trailing está activo o no
```

El renombrado de `FloorFlag` a `TrailingActive` es especialmente significativo: `FloorFlag` describe *qué desencadenó* el cambio de estado (el floor fue alcanzado), mientras que `TrailingActive` describe *el estado actual* (el trailing está funcionando). Lo segundo es lo que el código necesita saber realmente en cada barra.

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Lógica de trading** | ✓ | ✓ |
| **Nombres de variables autodocumentados** | — | ✓ |
| **`TrailingActive` (vs `FloorFlag`)** | — | ✓ |
| **Comentarios de parámetros inline** | Breves | Descriptivos (explican el *porqué*) |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `ATRLen` | 9 | Período de lookback para el cálculo del ATR. Más corto = más reactivo a la volatilidad reciente; más largo = más suave, más lento en adaptarse. |
| `ATRStopLoss` | 1 | Distancia del stop loss inicial como múltiplo del ATR. Activo inmediatamente tras la entrada, antes de que se alcance el floor. |
| `ATRFloor` | 2 | Avance mínimo de la operación (en múltiplos de ATR) requerido antes de que se active el trailing stop. Protege contra un trailing prematuro. |
| `ATRTrail` | 1 | Distancia del trailing stop como múltiplo del ATR una vez alcanzado el floor. Controla cuán de cerca sigue el stop al precio. |

**Sobre las relaciones entre parámetros:** `ATRFloor` siempre debe ser mayor que `ATRStopLoss`. Si el floor se establece por debajo del stop loss inicial, el trailing stop podría activarse antes de que la operación haya llegado siquiera al breakeven, lo que anula el propósito protector del floor. Una configuración inicial común — `ATRStopLoss = 1`, `ATRFloor = 2`, `ATRTrail = 1` — significa que el stop inicial arriesga 1 ATR, el trailing se activa tras un avance de 2 ATR, y luego sigue a 1 ATR de distancia.

---

## Escenarios de Operación

### Escenario A — Operación Larga, Floor Alcanzado, Trailing Activa

- Entrada: ES largo a 4.990.
- `ATRValue = 4 puntos`. `ATRLen = 9` barras.
- `StopLossDistance = 4 × 1 = 4 pts` → $200 (ES: 4 × $50).
- `FloorDistance = 4 × 2 = 8 pts` → el precio debe alcanzar 4.998 para activar el trailing.
- `TrailDistance = 4 × 1 = 4 pts` → $200 de distancia de trailing.

**Barras 1–5 (floor no alcanzado):**
- Fase 1 activa. `SetStopLoss($200)`. Stop en 4.986.
- El precio avanza hasta 4.994. `High (4.994) < EntryPrice + FloorDistance (4.998)`. Floor no alcanzado. El stop permanece en 4.986.

**Barra 6 (floor alcanzado):**
- El precio avanza hasta 4.999. `High (4.999) >= 4.998`. `TrailingActive = True`.
- Fase 2 activa. `SetDollarTrailing($200)`. Trailing stop ahora en 4.995 (4.999 − 4 pts).

**Barra 7 (trailing sigue al precio):**
- El precio avanza hasta 5.005. Trailing stop sube a 5.001 (5.005 − 4 pts).
- ATR se recalcula a 3,5 pts. `TrailDistance = $175`. Trailing stop ahora en 5.001,5.

**Barra 8 (stop activado):**
- El precio retrocede a 5.000. Trailing stop en 5.001,5 → stop activado. La operación sale.

### Escenario B — Operación Larga, Stop Inicial Activado Antes del Floor

- Entrada: ES largo a 4.990. `ATRValue = 4 pts`. Stop en 4.986 ($200).
- El precio sube a 4.992, luego revierte a 4.985.
- `Low (4.985) < Stop (4.986)`. Stop inicial activado. La operación sale con −$200 de pérdida.
- `TrailingActive` nunca llegó a `True`. El floor nunca fue alcanzado.

### Escenario C — Operación Corta, Floor Alcanzado

- Entrada: ES corto a 4.990. `ATRValue = 4 pts`.
- `StopLossDistance = 4 pts` → stop en 4.994 (por encima de la entrada para cortos).
- `FloorDistance = 8 pts` → el trailing activa cuando el precio llega a 4.982 o por debajo.

**Floor alcanzado:**
- El precio cae a 4.981. `Low (4.981) <= EntryPrice − FloorDistance (4.982)`. `TrailingActive = True`.
- Trailing stop colocado $200 por encima del mínimo más bajo alcanzado: 4.981 + 4 = 4.985.
- A medida que el precio continúa bajando, el trailing stop sigue 4 puntos por encima de cada nuevo mínimo.

---

## Características Clave

- **Stops adaptativos a la volatilidad:** Las distancias basadas en ATR se amplían automáticamente en condiciones volátiles y se estrechan en condiciones tranquilas, manteniendo el stop relevante al comportamiento actual del mercado sin ajuste manual.
- **Protección de dos fases:** El stop inicial proporciona protección inmediata a la baja; el floor evita la activación prematura del trailing; el trailing dinámico bloquea entonces los beneficios a medida que la operación avanza.
- **Riesgo en dólares agnóstico al instrumento:** La conversión con `BigPointValue` significa que los mismos multiplicadores ATR producen un riesgo en dólares consistente en ES, NQ, CL o cualquier instrumento de futuros — sin necesidad de cambiar parámetros al cambiar de instrumento.
- **Cumplimiento de `SetStopShare`:** La gestión de stops por contrato garantiza el comportamiento correcto cuando se opera con múltiples contratos.
- **Floor como activación ganada:** El trailing stop no se concede en la entrada — la operación debe "ganárselo" avanzando `ATRFloor × ATR` puntos. Este diseño reconoce que la mayoría de los stops se activan en las primeras barras tras la entrada, antes de que una tendencia se haya establecido.
- **Reset sin estado residual:** `TrailingActive = False` en cada barra flat garantiza una inicialización limpia para cada nueva operación, sin estado residual de posiciones anteriores.

---

## Psicología del Trading

ATRDollar TrailStop codifica una creencia específica sobre cómo se desarrollan las tendencias: **una operación que no ha avanzado todavía no ha demostrado nada.** Muchas implementaciones de trailing stop se activan inmediatamente tras la entrada, lo que expone la posición a ser cerrada por el ruido normal que sigue a cualquier entrada antes de que se materialice un movimiento direccional. El requisito de floor cambia esto — dice: *"muéstrame 2 ATRs de movimiento en mi dirección, y entonces empezaré a proteger tus ganancias."*

Esto refleja un principio más amplio del trading sistemático: **reglas diferentes para fases diferentes de una operación.** La fase de entrada (stop inicial) es sobre supervivencia — limitar el daño si la operación simplemente está equivocada. La fase de floor es sobre cualificación — esperar a que el mercado confirme la premisa de la operación. La fase de trailing es sobre cosecha — seguir el movimiento todo lo que pueda mientras se protege el beneficio acumulado.

El escalado basado en ATR también encarna un respeto por el contexto del mercado. Un stop fijo de $200 significa algo muy diferente en una sesión de baja volatilidad versus una de alta volatilidad. Un stop basado en ATR dice: *"arriesgaré una cantidad proporcional a cuánto se está moviendo actualmente este mercado."* Esto no es solo matemáticamente más consistente — es psicológicamente más sostenible, porque el stop se siente calibrado al mercado en lugar de arbitrario.

---

## Casos de Uso

**Instrumentos:** Diseñado para contratos de futuros donde `BigPointValue` está definido — ES, NQ, YM, CL, GC y futuros FX líquidos. La conversión a dólares lo hace directamente comparable entre instrumentos con valores por punto muy diferentes.

**Marcos temporales:** El valor por defecto `ATRLen = 9` se adapta al timeframe del gráfico. En barras de 15 minutos, captura aproximadamente dos horas de historial de volatilidad; en barras diarias, captura los últimos 9 días de trading. La longitud apropiada depende del período de mantenimiento de la estrategia a la que sirve el componente.

**Como componente:** ATRDollar TrailStop está diseñado para adjuntarse a cualquier estrategia de entrada como la capa de gestión de salidas. No genera entradas — gestiona la salida de posiciones existentes. La estrategia de entrada determina cuándo y a qué precio entrar; este componente determina cuándo salir.

**Guía de ajuste de parámetros:**
- **Trailing más ajustado** (`ATRTrail` más pequeño): Bloquea los beneficios más rápido pero aumenta el riesgo de ser cerrado por retrocesos normales durante una tendencia fuerte.
- **Floor más amplio** (`ATRFloor` más grande): Permite más margen antes de que se active el trailing, reduciendo los cierres prematuros pero retrasando la protección de beneficios.
- **Período ATR más corto** (`ATRLen`): Más reactivo a los picos recientes de volatilidad; útil en mercados de movimiento rápido.
- **Período ATR más largo** (`ATRLen`): Stops más suaves y de adaptación más lenta; útil en mercados tendenciales donde la volatilidad se expande gradualmente.
