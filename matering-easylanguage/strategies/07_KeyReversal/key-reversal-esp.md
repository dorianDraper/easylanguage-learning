# Key Reversal — v1.0 & v2.0

## Descripción de la Estrategia

Key Reversal es una estrategia de mean-reversion que identifica y opera el clásico patrón de reversión clave — un mínimo estructural seguido de un cierre alcista que confirma un potencial cambio direccional. La estrategia entra en largo en el primer patrón confirmado y puede añadir una segunda posición si la operación se mueve en su contra mientras el patrón sigue siendo estructuralmente válido. Cada entrada opera con su propio reloj de salida temporal independiente, evitando la liquidación simultánea entre la posición base y la posición de scale-in.

Un indicador complementario — **Key Reversal Detector** — visualiza la lógica de detección del patrón directamente en el gráfico, representando mínimos estructurales, cierres alcistas y reversiones clave confirmadas como señales separadas para validación visual y revisión de la estrategia.

---

## Mecánica Central

### 1. Detección del Mínimo Estructural — MRO y el Canal Donchian

La estrategia identifica mínimos estructurales usando `MRO` (Most Recent Occurrence), una de las funciones de escaneo más potentes de EasyLanguage:

```pascal
LowerLowOffset =
    MRO(Low < Lowest(Low, DonchianLen)[1], CarryForwardBars + 1, 1);
```

`MRO` escanea hacia atrás a través de las barras y devuelve el offset de la barra más reciente donde la condición era verdadera. Desglose de los argumentos:

- **Condición:** `Low < Lowest(Low, DonchianLen)[1]` — el mínimo de la barra está por debajo del mínimo más bajo de las `DonchianLen` barras anteriores. El offset `[1]` garantiza que el canal se calcule sobre barras completadas, eliminando el sesgo de lookahead.
- **Lookback:** `CarryForwardBars + 1` — cuántas barras hacia atrás buscar. En su mínimo (`CarryForwardBars = 0`), solo busca en la barra actual. Aumentar `CarryForwardBars` extiende la ventana de búsqueda, permitiendo a la estrategia encontrar un mínimo estructural que ocurrió unas pocas barras atrás y seguir considerándolo válido.
- **Ocurrencia:** `1` — encontrar la ocurrencia más reciente.

`LowerLowOffset` devuelve el número de barras atrás en que ocurrió el mínimo estructural, o `-1` si no se encontró ningún mínimo válido en la ventana de búsqueda. `HasStructuralLow = LowerLowOffset >= 0` convierte esto en un booleano limpio.

Piensa en `MRO` como un foco que apunta hacia atrás: barre las barras recientes hacia atrás y devuelve la distancia a la primera barra donde la condición se iluminó.

### 2. Confirmación de Reversión — Cierre Alcista

Una vez identificado un mínimo estructural, la estrategia verifica si ha seguido un cierre alcista:

```pascal
If HasStructuralLow Then
Begin
    ReferenceClose = Close[LowerLowOffset + 1];
    HasBullishClose =
        Close > ReferenceClose * (1 - ConfirmationTolerancePct * .01);
End;
```

`Close[LowerLowOffset + 1]` recupera el cierre de la barra *posterior* a la barra del mínimo estructural — este es el cierre de la potencial barra de reversión, que sirve como referencia. El cierre de la barra actual debe superar esta referencia (ajustada hacia abajo por el porcentaje de tolerancia) para confirmar la reversión.

**¿Por qué `LowerLowOffset + 1`?** `LowerLowOffset` apunta a la barra que hizo el nuevo mínimo. La barra inmediatamente posterior (`+ 1` en términos de offset histórico, es decir, una barra después de la barra del mínimo) es la primera barra donde un cierre más alto podría confirmar la reversión. Comprobar el cierre de esa barra específica ancla el patrón a su origen estructural.

`ConfirmationTolerancePct` permite un pequeño ajuste hacia abajo del umbral, acomodando gaps menores o slippage sin rechazar patrones otherwise válidos. Con el valor por defecto del `0%`, el cierre actual debe superar estrictamente el cierre de referencia.

### 3. Entrada Base (LE1)

```pascal
If TradeState = 0 and HasStructuralLow and HasBullishClose Then
Begin
    Buy ("LE1") Next Bar at Market;
    TradeState = 1;
    ScaleBarsCounter = 0;
End;
```

Cuando la estrategia está flat (`TradeState = 0`) y ambas condiciones del patrón están confirmadas, abre una posición larga en la siguiente barra a mercado. `TradeState` avanza a `1` y el contador de barras se resetea a `0`.

### 4. Entrada de Scale-In (LE2)

```pascal
If TradeState = 1 and HasStructuralLow and HasBullishClose
    and OpenPositionProfit < 0 Then
Begin
    Buy ("LE2") Next Bar at Market;
    TradeState = 2;
    ScaleBarsCounter = 0;
End;
```

Mientras mantiene la posición base (`TradeState = 1`), si el patrón sigue siendo estructuralmente válido — el mínimo estructural sigue calificando y el cierre alcista sigue confirmado — **y** la operación actual está en pérdida (`OpenPositionProfit < 0`), la estrategia añade una segunda posición de 100 acciones. `TradeState` avanza a `2` y `ScaleBarsCounter` se resetea a `0` para iniciar el reloj de salida independiente de LE2.

Esto no es promedio a ciegas — es un scale-in basado en convicción condicionado a que el setup original siga intacto. La distinción importa: si el mínimo estructural ya no califica o el cierre alcista falla, `HasStructuralLow` o `HasBullishClose` serán `False`, y el scale-in no se activará independientemente de cuán poco rentable sea la operación base.

### 5. Relojes de Salida Independientes

Cada entrada tiene su propia salida temporal, evitando la liquidación simultánea:

```pascal
// Salida LE1 — basada en BarsSinceEntry desde la entrada base
If TradeState >= 1 and BarsSinceEntry >= ExitAfterBars Then
Begin
    Sell ("ExitLE1") Next Bar 100 Shares from Entry ("LE1") at Market;
    If TradeState = 1 Then
        TradeState = 0;
    // Si TradeState = 2, permanece en 2 hasta que ExitLE2 lo resuelva
End;

// Salida LE2 — basada en ScaleBarsCounter desde la entrada de scale
If TradeState = 2 and ScaleBarsCounter >= ExitAfterBars Then
Begin
    Sell ("ExitLE2") Next Bar 100 Shares from Entry ("LE2") at Market;
    TradeState = 1;
End;
```

`BarsSinceEntry` es una función nativa de EasyLanguage que cuenta barras desde la entrada más reciente — en este caso LE1. `ScaleBarsCounter` es una variable incrementada manualmente que rastrea las barras transcurridas desde LE2 específicamente, ya que `BarsSinceEntry` se resetearía con la entrada de LE2 y no podría rastrear independientemente el reloj de LE1.

La sintaxis `from Entry ("LE1")` y `from Entry ("LE2")` indica a EasyLanguage que cierre solo las acciones asociadas con la entrada con nombre, en lugar de cerrar toda la posición.

### 6. Máquina de Estados

```
┌──────────────┐
│  Estado 0    │  Flat — esperando señal de Key Reversal
└──────┬───────┘
       │ HasStructuralLow and HasBullishClose
       ▼
┌──────────────┐
│  Estado 1    │  Largo Base — 100 acciones (LE1 activa)
│  (LE1 abierta)│  monitorizando oportunidad de scale-in
└──────┬───────┘
       │ Patrón sigue válido + OpenPositionProfit < 0
       ▼
┌──────────────┐
│  Estado 2    │  Largo Escalado — 200 acciones (LE1 + LE2 activas)
│(LE1 + LE2)  │  relojes de salida independientes en marcha
└──────┬───────┘
       │ BarsSinceEntry >= ExitAfterBars → ExitLE1
       ▼
┌──────────────┐
│  Estado 2→1  │  LE1 sale; LE2 sigue abierta
│  (LE2 abierta)│  ScaleBarsCounter continúa
└──────┬───────┘
       │ ScaleBarsCounter >= ExitAfterBars → ExitLE2
       ▼
┌──────────────┐
│  Estado 0    │  Flat — ciclo completo
└──────────────┘
```

---

## v1 vs v2: La Diferencia

### v1 — `ScaleCount` Inicializado en `-2`

v1 gestiona el temporizador de salida del scale-in con un contador bruto inicializado en `-2`:

```pascal
ScaleCount = -2;   // en la entrada del scale-in

If ScaleFlag Then
    ScaleCount = ScaleCount + 1;

If ScaleCount = ExitBars Then
    Sell ("Ex2") ...
```

El offset de `-2` compensa el retraso de dos barras entre cuándo se coloca la orden de scale-in y cuándo el contador se alinearía naturalmente con `BarsSinceEntry`. Es funcionalmente correcto pero requiere saber *por qué* el contador comienza en un valor negativo — sin ese contexto, la inicialización parece un error. v2 lo reemplaza con `ScaleBarsCounter` inicializado a `0` en el momento de la entrada del scale-in, haciendo la intención autoevidente.

### v2 — Máquina de Estados Explícita y Corrección de Bug

v2 introduce `TradeState` (0, 1, 2) como variable de estado central, reemplazando la combinación de comprobaciones de `MarketPosition` y el booleano `ScaleFlag` usado en v1. Cada estado mapea directamente a una configuración de posición, haciendo el flujo de ejecución legible como una secuencia de transiciones.

v2 también corrige un bug de ámbito en el bloque de salida de LE1. En v1, salir de LE1 resetea incondicionalmente el estado a flat — incluso cuando LE2 sigue abierta. v2 hace el reset de estado condicional:

```pascal
// v1 — siempre resetea a flat en la salida de LE1
Sell ("Ex1") Next Bar 100 Shares from Entry ("LE1") at Market;
// (implícito: la comprobación de MarketPosition lleva el estado)

// v2 — corregido: solo resetea a flat si LE2 nunca se entró
If TradeState = 1 Then
    TradeState = 0;
// Si TradeState = 2, permanece en 2 hasta que ExitLE2 lo resuelva
```

Sin esta corrección, cuando `TradeState = 2` y LE1 sale, `TradeState` cae a `0`, causando que el bloque de salida de LE2 (`If TradeState = 2`) nunca se evalúe — dejando 100 acciones de LE2 abiertas sin mecanismo de salida.

**Resumen:**

| | v1.0 | v2.0 (corregida) |
|---|---|---|
| **Lógica de detección del patrón** | ✓ | ✓ |
| **Scale-in en patrón válido + pérdida** | ✓ | ✓ |
| **Máquina de estados explícita** | — | ✓ (`TradeState` 0/1/2) |
| **`ScaleBarsCounter` desde 0** | — | ✓ (vs `-2` en v1) |
| **Corrección bug salida LE1** | ✗ bug | ✓ corregido |
| **Nombres de variables descriptivos** | `FudgeFactor`, `ScaleFlag` | `ConfirmationTolerancePct`, `HasBullishClose` |
| **Nombres de parámetros** | `LLChannelLookupBars`, `ExitBars` | `DonchianLen`, `ExitAfterBars` |

---

## Key Reversal Detector — Indicador

El Key Reversal Detector es un indicador ShowMe que ejecuta la misma lógica de detección de patrón que la estrategia y representa tres señales independientes en el gráfico:

```pascal
If HasStructuralLow Then
    Plot1(Low - Range * .33, "StrucLow");       // Mínimo estructural detectado

If HasBullishClose Then
    Plot2(Low - Range * .66, "BullClose");      // Cierre alcista confirmado

If HasStructuralLow and HasBullishClose Then
    Plot3(Low - Range * .99, "KeyReversal");    // Patrón completo confirmado
```

Cada plot se coloca por debajo del mínimo de la barra a una fracción fija del rango de la barra, creando una jerarquía visual apilada: mínimo estructural a un tercio por debajo, cierre alcista a dos tercios, patrón completo en la parte inferior. Esta separación permite rastrear cada condición de forma independiente — una barra puede mostrar un mínimo estructural sin un cierre alcista, haciendo fácil ver dónde el patrón se está formando pero aún no está confirmado.

**Parámetros** (idénticos a los de la estrategia):

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `DonchianLen` | 21 | Lookback para la detección del mínimo estructural. |
| `CarryForwardBars` | 0 | Cuántas barras después del mínimo seguir considerándolo válido. |
| `ConfirmationTolerancePct` | 0 | Tolerancia % para el umbral del cierre alcista. |

> **Nota de uso:** El indicador comparte los mismos inputs que la estrategia. Mantener ambos configurados de forma idéntica garantiza que las señales visuales coincidan exactamente con las condiciones de entrada reales de la estrategia.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `DonchianLen` | 21 | Período de lookback para el canal de mínimo estructural. Valores más grandes requieren mínimos más significativos antes de que el patrón califique. |
| `CarryForwardBars` | 0 | Número de barras después del mínimo estructural para seguir buscando. `0` significa que solo se comprueba la barra actual; valores más altos extienden la ventana de validez del patrón. |
| `ConfirmationTolerancePct` | 0% | Tolerancia hacia abajo en el umbral del cierre alcista. `0` requiere confirmación estricta; valores positivos pequeños aceptan slippage o gaps menores. |
| `ExitAfterBars` | 5 | Número de barras que cada entrada mantiene antes de la salida temporal automática. Se aplica independientemente a LE1 (vía `BarsSinceEntry`) y LE2 (vía `ScaleBarsCounter`). |

**Sobre `CarryForwardBars`:** Establecerlo a `0` significa que la estrategia solo reconoce un patrón en la barra exacta donde se alinean tanto la condición de mínimo estructural como el cierre alcista. Aumentarlo a `1` o `2` permite a la estrategia reconocer el patrón una o dos barras después de que se formara el mínimo estructural, capturando setups donde el cierre de reversión se desarrolla ligeramente más tarde.

---

## Escenarios de Operación

### Escenario A — Recuperación en V (Sin Scale-In)

- `DonchianLen = 21`. Se forma un nuevo mínimo más bajo. La barra siguiente cierra por encima del cierre de referencia. `HasStructuralLow = True`, `HasBullishClose = True`.
- **Entrada LE1:** Compra 100 acciones a $45,20. `TradeState = 1`.
- La operación se mueve inmediatamente a beneficio. `OpenPositionProfit > 0` en cada barra — condición de scale-in nunca cumplida.
- Barra 5: `BarsSinceEntry = 5 >= ExitAfterBars (5)`. **ExitLE1** se activa. 100 acciones vendidas. `TradeState = 1 → 0`.
- Ciclo completo. LE2 nunca se entró.

### Escenario B — Scale-In Durante Drawdown, Salida Escalonada

- **Entrada LE1** a $45,20. La operación se mueve contra la posición. `OpenPositionProfit < 0`.
- Patrón sigue válido: `HasStructuralLow = True`, `HasBullishClose = True`.
- **Scale-in LE2:** Compra 100 acciones adicionales a $44,80. `TradeState = 2`. `ScaleBarsCounter = 0`.
- Posición ahora 200 acciones. Entrada media: ~$45,00.
- Barra 5 desde LE1: `BarsSinceEntry = 5`. **ExitLE1** se activa. 100 acciones vendidas a $45,40. `TradeState` permanece en `2` (LE2 sigue abierta).
- `ScaleBarsCounter` alcanza `5`: **ExitLE2** se activa. 100 acciones vendidas a $45,60. `TradeState = 1 → 0` tras ExitLE2.

Las dos salidas son escalonadas — LE1 sale primero, LE2 sale después, cada una potencialmente a precios diferentes.

### Escenario C — Scale-In Bloqueado (Patrón Invalidado)

- **Entrada LE1** a $45,20. La operación se mueve a pérdida.
- Se forma un nuevo mínimo más bajo que ya no califica dentro de la ventana `DonchianLen` — `HasStructuralLow = False`.
- Condición de scale-in: `TradeState = 1 and HasStructuralLow and HasBullishClose and OpenPositionProfit < 0`.
- `HasStructuralLow = False` → **scale-in bloqueado**.
- LE1 sale en la barra 5 sin que se haya producido ningún scale-in.

---

## Características Clave

- **Detección de mínimo estructural con `MRO`:** Escanea hacia atrás a través de barras recientes para encontrar el mínimo válido más reciente, habilitando el reconocimiento de patrones en una ventana de lookback configurable sin bucles barra a barra.
- **Scale-in basado en convicción:** La segunda entrada solo se activa cuando el setup original sigue siendo estructuralmente válido. Las pérdidas por sí solas no activan el promediado — el patrón debe seguir vigente.
- **Relojes de salida independientes:** `BarsSinceEntry` rastrea el temporizador de LE1; `ScaleBarsCounter` rastrea el temporizador de LE2 de forma independiente. Cada entrada obtiene su propia ventana de salida sin interferir con la otra.
- **Sintaxis `from Entry`:** La sintaxis de salida por entrada con nombre de EasyLanguage (`100 Shares from Entry ("LE1")`) garantiza que cada orden de salida cierre solo las acciones de la entrada indicada, evitando la liquidación completa de la posición cuando se pretenden salidas parciales.
- **Máquina de tres estados (v2):** `TradeState` 0/1/2 mapea directamente a la configuración de posición en cada momento, haciendo el flujo de ejecución transparente y auditable.
- **Reset de `HasBullishClose` por barra:** `HasBullishClose = False` al inicio de cada barra garantiza que la condición se re-evalúe en fresco, evitando que señales de patrón obsoletas persistan entre barras.
- **Indicador complementario:** El Key Reversal Detector proporciona validación visual de la misma lógica de detección, permitiendo la revisión manual de la frecuencia, calidad y alineación del patrón con las entradas de la estrategia.

---

## Psicología del Trading

Key Reversal encarna una postura específica sobre la gestión del drawdown: **una operación perdedora en un setup válido es una entrada más barata, no una razón para salir.** La mayoría de los enfoques de mean-reversion o mantienen pasivamente a través de las pérdidas o las cortan en un stop fijo. Key Reversal toma un tercer camino — añade activamente a la posición cuando el precio es más bajo, pero solo cuando la justificación estructural de la operación sigue intacta.

Esta distinción es crítica. El scale-in no se activa por la pérdida en sí. Se activa por la combinación de pérdida *y* continuidad de la validez del patrón. Si el mínimo estructural ya no califica — porque un mínimo más profundo ha roto el canal — `HasStructuralLow` se vuelve `False` y el scale-in se bloquea. La estrategia solo añade cuando tiene razón estructural para creer que el setup sigue vivo.

La salida temporal elimina el riesgo de mantenimiento abierto que frecuentemente acompaña a las estrategias de mean-reversion. En lugar de esperar un objetivo de beneficio específico o un nivel de stop, cada entrada sale después de un número fijo de barras — aceptando lo que el mercado haya devuelto durante esa ventana. Esto mantiene el período de mantenimiento promedio predecible y evita que la estrategia se convierta en un mantenedor pasivo de movimientos de múltiples días que no fue diseñada para capturar.

Los relojes de salida independientes reflejan un respeto por la asimetría entre las dos entradas: LE1 entró a un precio más alto con una señal más limpia; LE2 entró más tarde a un precio más bajo con convicción adicional pero también riesgo adicional. Dar a cada una su propia ventana de salida reconoce que son operaciones diferentes compartiendo una tesis común, no una única posición promediada.

---

## Casos de Uso

**Instrumentos:** Más adecuada para instrumentos que exhiben comportamiento de mean-reversion en mínimos estructurales — acciones individuales con niveles de soporte identificables, futuros de índices de renta variable (ES, NQ) durante sesiones de retroceso, o futuros de materias primas donde los patrones de reversión clave se forman en rangos establecidos. Evitar instrumentos fuertemente tendenciales donde los nuevos mínimos consistentemente llevan a más mínimos en lugar de reversiones.

**Marcos temporales:** El canal Donchian de 21 barras en barras diarias identifica mínimos estructurales mensuales; en barras de 60 minutos identifica mínimos de sesión. El valor por defecto `ExitAfterBars = 5` debe interpretarse en relación al marco temporal — cinco barras diarias es una semana de trading; cinco barras de 60 minutos es media sesión.

**Guía de parámetros:**
- **`DonchianLen` más amplio:** Menos mínimos estructurales, más significativos. Mejor calidad de señal, menos operaciones.
- **`CarryForwardBars` más grande:** Reconocimiento de patrón más flexible, capturando reversiones que se desarrollan en múltiples barras. Riesgo de entrar en mínimos obsoletos.
- **`ConfirmationTolerancePct` distinto de cero:** Útil en instrumentos con gaps donde el cierre después de un mínimo estructural puede estar fracciones por debajo del cierre de referencia debido a gaps overnight.
- **`ExitAfterBars` más largo:** Da más tiempo a la reversión para desarrollarse pero aumenta la duración de la exposición.

**Combinación con componentes de riesgo:** Key Reversal no tiene stop loss — las salidas son solo temporales. En producción, combinarlo con ATRDollar TrailStop como capa de salida adicional proporciona protección a la baja si la reversión no se materializa dentro de la ventana de mantenimiento. AccountRiskCore gestiona los límites diarios a nivel de cuenta de forma independiente a la lógica de salida propia de la estrategia.
