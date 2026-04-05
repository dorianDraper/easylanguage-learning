# Multi-Data Strategy — v3.0 & v4.0

## Descripción de la Estrategia

v3 y v4 representan una evolución conceptual de la Multi-Data Strategy, reemplazando la condición de entrada por estado continuo de v1/v2 (`Close > MA`) por un evento discreto de cruce (`Close Crosses Over MA`). Este cambio transforma la naturaleza de la señal de entrada: de *"las condiciones están actualmente alineadas"* a *"la alineación acaba de producirse"*, reduciendo la frecuencia de señales y mejorando su precisión. v4 amplía v3 añadiendo un mecanismo de reentrada que recupera movimientos de continuación perdidos tras una salida técnica, sin necesidad de esperar a un nuevo evento de cruce.

---

## Mecánica Central

### 1. Confirmación de Contexto (Data2 — Timeframe Superior)

Idéntica en concepto a v1/v2, pero con nombres de variables más descriptivos y flags booleanos explícitos que hacen la lógica más legible y auditable:

```pascal
MAData2 = Average(Close of Data2, MALenData2);

ContextBullish = MAData2 > MAData2[1];   // Momentum TF superior alcista
ContextBearish = MAData2 < MAData2[1];   // Momentum TF superior bajista
```

La separación en booleanos con nombre (`ContextBullish`, `ContextBearish`) es una decisión deliberada de legibilidad: el bloque de entrada se lee como una frase — *"si el contexto es alcista y se activa una señal larga, compra"* — en lugar de obligar al lector a interpretar comparaciones inline.

> **Nota de sintaxis:** Desde v3 en adelante, los cálculos de Data2 utilizan `Average(Close of Data2, MALenData2)` en lugar de la sintaxis `Average(Close, MALenData2) Data2` de v1/v2. Ambas son funcionalmente equivalentes; la nueva forma es más explícita y coherente con cómo se referencia Data2 en el resto del código.

### 2. Señal de Entrada — El Cambio Clave: Eventos de Cruce (Data1)

Este es el cambio arquitectónico definitorio de v3. En lugar de comprobar si el precio *está* por encima o por debajo de la MA en cada barra, la estrategia comprueba si el precio *acaba de cruzar* la MA:

```pascal
MAData1 = Average(Close, MALenData1);

LongSignal  = Close Crosses Over MAData1;   // El precio acaba de cruzar al alza
ShortSignal = Close Crosses Under MAData1;  // El precio acaba de cruzar a la baja
```

`Crosses Over` es un evento discreto: evalúa a `True` en exactamente una barra — la barra en que se produce el cruce — y a `False` en todas las barras siguientes, independientemente de dónde esté el precio respecto a la MA.

**¿Por qué importa esto?** Piénsalo como la diferencia entre un sensor de movimiento y un interruptor de luz. En v1/v2, la condición es como un interruptor: permanece encendido mientras el precio esté por encima de la MA, generando una señal de entrada en cada barra. En v3/v4, es como un sensor de movimiento: se activa solo en el momento del movimiento — el cruce — y luego se resetea. Esto produce señales menos frecuentes y más precisas, aunque también significa que la estrategia puede perderse el movimiento inicial si no se ha producido un cruce recientemente.

### 3. Lógica de Entrada Primaria

El bloque de entrada combina la confirmación de contexto con la señal discreta de cruce:

```pascal
If MarketPosition = 0 Then
Begin
    If ContextBullish and LongSignal Then
        Buy ("MTF_LE") Next Bar at Market;

    If ContextBearish and ShortSignal Then
        SellShort ("MTF_SE") Next Bar at Market;
End;
```

La estrategia está flat (`MarketPosition = 0`), el contexto del timeframe superior está alineado y acaba de activarse un evento de cruce — las tres condiciones deben ser verdaderas simultáneamente.

### 4. Máquina de Estados

v3 y v4 introducen una máquina de estados explícita mediante variables booleanas:

```pascal
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;
```

Aunque `MarketPosition` siempre está disponible en EasyLanguage, asignarlo a booleanos con nombre hace que la lógica de salida sea autodocumentada: `If IsLong and High < MAData1` se lee inmediatamente como una afirmación lógica completa. También facilita futuras extensiones — como añadir lógica dependiente de la posición — de forma más limpia.

### 5. Salidas Técnicas

Sin cambios lógicos respecto a v1/v2, pero ahora utilizando las variables de la máquina de estados:

```pascal
// Salida largo: la barra entera queda por debajo de la MA operativa
If IsLong and High < MAData1 Then
    Sell ("MTF_LX") Next Bar at Market;

// Salida corto: la barra entera queda por encima de la MA operativa
If IsShort and Low > MAData1 Then
    BuyToCover ("MTF_SX") Next Bar at Market;
```

### 6. Lógica de Reentrada (Solo v4)

Esta es la adición definitoria de v4. Tras una salida técnica, existe con frecuencia un escenario en el que el mercado retrocedió brevemente para activar la salida, pero el contexto tendencial sigue intacto y el precio recupera rápidamente el lado correcto de la MA. En v3, la estrategia permanecería flat esperando un nuevo evento de cruce — que puede tardar muchas barras en materializarse, perdiendo así el movimiento de continuación.

v4 aborda esto con condiciones de reentrada explícitas:

```pascal
CanReEnterLong =
    ContextBullish                           // Contexto TF superior sigue alcista
    and Close > MAData1                      // Precio de nuevo por encima de la MA operativa
    and BarsSinceExit(1) <= ReEntryBars      // La salida fue reciente
    and not LongSignal;                      // Evitar duplicar la señal de entrada primaria

CanReEnterShort =
    ContextBearish
    and Close < MAData1
    and BarsSinceExit(1) <= ReEntryBars
    and not ShortSignal;

If MarketPosition = 0 Then
Begin
    If CanReEnterLong  Then Buy      ("MTF_RELE") Next Bar at Market;
    If CanReEnterShort Then SellShort("MTF_RESE") Next Bar at Market;
End;
```

**Desglose de las condiciones de reentrada:**

- `ContextBullish / ContextBearish`: La tendencia macro debe seguir intacta — la reentrada solo es válida si la premisa original de la operación se mantiene.
- `Close > MAData1 / Close < MAData1`: El precio debe haber vuelto al lado correcto de la MA. Esta es una condición de estado continuo (como en v1/v2), no un evento de cruce.
- `BarsSinceExit(1) <= ReEntryBars`: La salida debe haber sido reciente. `BarsSinceExit(1)` devuelve el número de barras desde la última salida de una posición larga (para largos) o corta (para cortos). La ventana `ReEntryBars` evita que la estrategia reingrese en una tendencia que salió hace tiempo y puede haber cambiado fundamentalmente.
- `not LongSignal / not ShortSignal`: Si ya se ha activado un nuevo cruce, el bloque de entrada primaria lo gestiona. Este guard evita que el bloque de reentrada duplique esa señal en la misma barra.

> **Analogía:** Piensa en la lógica de reentrada como una "ventana de segunda oportunidad". Si perdiste tu autobús pero el siguiente viene justo detrás, aún puedes subir — pero solo dentro de un margen de tiempo razonable, y solo si sigues yendo en la misma dirección.

---

## v3 vs v4: La Diferencia Clave

| | v3.0 | v4.0 |
|---|---|---|
| **Entrada primaria** | Evento de cruce | Evento de cruce |
| **Reentrada tras salida** | Ninguna — espera nuevo cruce | Sí — dentro de ventana `ReEntryBars` |
| **Condición de reentrada** | — | Precio en lado correcto de MA + contexto intacto |
| **Parámetros** | 2 | 3 (se añade `ReEntryBars`) |

v3 es el diseño más limpio y conservador. v4 intercambia algo de simplicidad por una mejor captura de tendencia, a costa de un parámetro adicional a optimizar y el riesgo de reingresar en un movimiento que se esté agotando.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `MALenData1` | 12 | Longitud de la MA para el timeframe operativo (Data1). Controla la sensibilidad de la señal. |
| `MALenData2` | 24 | Longitud de la MA para el timeframe superior (Data2). Controla la sensibilidad del contexto tendencial. |
| `ReEntryBars` | 5 | *(Solo v4)* Número máximo de barras tras una salida dentro del cual se permite una reentrada. |

**Sobre `ReEntryBars`:** Un valor de 5 significa que la estrategia considerará reingresar durante hasta 5 barras tras la última salida. Una ventana demasiado pequeña pierde continuaciones válidas; una demasiado grande arriesga reingresar en un movimiento que ya ha revertido. Este parámetro debe optimizarse por instrumento y combinación de timeframes.

---

## Escenarios de Operación

### Escenario A — Entrada Larga por Cruce (v3 y v4)

- Gráfico ES 60-min: MA sube de 4.980 a 4.985 → **ContextBullish = True**
- Gráfico ES 15-min: cierre barra anterior en 4.989, por debajo de MAData1 en 4.991; cierre barra actual en 4.994, por encima de MAData1 en 4.992 → **LongSignal = True** (cruce acaba de producirse)
- Ambas condiciones cumplidas → **Compra en la siguiente barra a mercado**
- Entrada ejecutada a 4.995

**Condición de salida:** Una barra de 15-min cierra con High < 4.992 → Venta en la siguiente barra a mercado. Salida ejecutada a 4.991.

### Escenario B — Señal No Generada (Sin Cruce)

- Gráfico ES 60-min: MA subiendo → **ContextBullish = True**
- Gráfico ES 15-min: cierre en 4.994, por encima de MAData1 en 4.992, *pero el precio lleva 8 barras por encima de la MA*
- `LongSignal = False` (no se ha producido ningún cruce en esta barra)
- **No se genera señal de entrada**

Esta es la diferencia de comportamiento clave respecto a v1/v2: en v1/v2 esta barra *sí* habría generado una señal de entrada. En v3/v4 no — la señal ya fue "consumida" en el momento del cruce.

### Escenario C — Reentrada Tras Salida (Solo v4)

Continuando desde el Escenario A, la estrategia salió a 4.991. Dos barras después:

- Gráfico ES 60-min: MA sigue subiendo → **ContextBullish = True**
- Gráfico ES 15-min: cierre en 4.993, por encima de MAData1 en 4.991 → **Close > MAData1 = True**
- `BarsSinceExit(1) = 2`, que es ≤ `ReEntryBars (5)` → **Dentro de la ventana de reentrada**
- No se ha producido nuevo cruce → **not LongSignal = True**
- Todas las condiciones de reentrada cumplidas → **Buy ("MTF_RELE") en la siguiente barra a mercado**

En v3, esta barra no produce ninguna señal. La estrategia permanece flat hasta el siguiente evento de cruce.

### Escenario D — Reentrada Bloqueada (Ventana Expirada)

Mismas condiciones que el Escenario C, pero `BarsSinceExit(1) = 7`, que supera `ReEntryBars (5)`:
- **CanReEnterLong = False**
- No se genera reentrada. La estrategia espera una nueva señal de cruce.

---

## Características Clave

- **Señales discretas de cruce:** Las entradas se activan solo en el momento del cruce, no continuamente mientras las condiciones se mantienen. Esto reduce el sobretrading en tendencias sostenidas, aunque exige estar bien posicionado en el momento adecuado.
- **Máquina de estados explícita:** Las variables booleanas con nombre (`IsLong`, `IsShort`, `ContextBullish`, `ContextBearish`, `LongSignal`, `ShortSignal`) hacen que la lógica sea autodocumentada y más fácil de auditar.
- **Mecanismo de reentrada (v4):** Recupera movimientos de continuación tras salidas técnicas sin requerir un nuevo cruce, acotado por una ventana de tiempo configurable.
- **Etiquetas de orden descriptivas:** Todas las órdenes usan etiquetas descriptivas (`MTF_LE`, `MTF_SE`, `MTF_LX`, `MTF_SX`, `MTF_RELE`, `MTF_RESE`) que permiten analizar el rendimiento por tipo de entrada en los informes de TradeStation.
- **Separación de responsabilidades:** La confirmación de contexto, la generación de señales, la entrada primaria, la reentrada y las salidas se gestionan en bloques de código claramente separados, facilitando la modificación y extensión de la estrategia.

---

## Psicología del Trading

El cambio de estado continuo a evento de cruce refleja un cambio filosófico más profundo: **esperar el momento del compromiso, no simplemente el estado de alineación.**

En v1/v2, que el mercado esté por encima de la MA es suficiente — la estrategia actúa sobre la *existencia* de una condición favorable. En v3/v4, la estrategia espera la *transición* — el momento en que el precio cruza la MA. Esto refleja cómo piensan los traders discrecionales experimentados sobre las entradas: no *"el precio está por encima del nivel, así que debería estar largo"*, sino *"el precio acaba de romper por encima del nivel — esa es la señal."* El evento contiene más información que el estado.

La lógica de reentrada en v4 aborda un reto psicológico real del trading sistemático: la frustración de ser sacado de una tendencia válida y ver después cómo el mercado continúa sin ti. Al definir condiciones explícitas y acotadas bajo las cuales la estrategia puede reincorporarse a una tendencia, v4 elimina la ambigüedad de *"¿debería volver a entrar?"* y la reemplaza con una regla: *"reingresa si la tendencia sigue intacta, el precio ha recuperado y la salida fue reciente."*

El parámetro `ReEntryBars` también encarna un principio importante de gestión del riesgo: **la obsolescencia destruye el edge.** Una señal de reentrada que se activa 20 barras después de una salida no es la misma operación que una que se activa 2 barras después. La ventana obliga a la estrategia a reconocer que el tiempo degrada la validez de la premisa original de la operación.

---

## Casos de Uso

**Instrumentos:** Igual que v1/v2 — futuros de índices de renta variable (ES, NQ, YM) en sesiones tendenciales, con extensión potencial a CL, GC y futuros FX líquidos. La entrada basada en cruce hace que v3/v4 sean especialmente adecuadas para instrumentos con movimientos limpios y direccionales, donde el precio tiende a romper y continuar en lugar de oscilar alrededor de la MA.

**Combinaciones de timeframes:** 15-min (Data1) / 60-min (Data2) sigue siendo el punto de partida natural. Dado el requisito de cruce, separaciones temporales más amplias entre Data1 y Data2 tienden a producir señales más limpias con menos ruido.

**v3 vs v4 — cuándo preferir cada una:**
- Usa **v3** cuando quieras un sistema más simple, completamente orientado a eventos y sin complejidad de reentrada. Más fácil de optimizar y menos propenso al overfitting.
- Usa **v4** cuando el backtesting muestre que la estrategia sale frecuentemente y luego pierde movimientos de continuación significativos. La lógica de reentrada añade un parámetro pero puede mejorar de forma relevante la captura de tendencia en instrumentos fuertemente tendenciales.

**Perfil del trader:** v3/v4 son más adecuadas para traders sistemáticos cómodos con el concepto de escasez de señales — menos entradas, pero cada una con una premisa más clara. El requisito de cruce significa que la estrategia puede permanecer flat durante períodos prolongados en mercados laterales, lo que exige disciplina para mantenerse sin anular el sistema.
