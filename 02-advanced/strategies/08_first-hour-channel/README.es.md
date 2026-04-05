# First Hour Channel — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

First Hour Channel es una estrategia de breakout intradiario que captura el máximo y mínimo del período de apertura del mercado y luego entra con órdenes limitadas cuando el precio regresa a esos límites tras el cierre de la ventana de apertura. La estrategia opera sobre el principio de que la primera hora de trading establece un envolvente de volatilidad que representa el consenso inicial del mercado — y que cuando el precio rompe esos límites más tarde en la sesión, a menudo señala un movimiento de momentum que vale la pena operar.

La estrategia permite como máximo una operación por dirección y por día, usa stops de pérdida y targets de beneficio fijos en dólares, y deja de aceptar nuevas entradas a una hora de corte configurable. Un indicador complementario visualiza los límites del canal directamente en el gráfico durante la ventana de trading activa.

---

## Mecánica Central

### 1. IntraBarOrderGeneration

```pascal
[IntraBarOrderGeneration = TRUE]
```

Requerido al inicio de ambas versiones. Esta directiva permite a la estrategia evaluar órdenes limitadas y generar ejecuciones dentro de una barra a medida que se forma, en lugar de esperar al cierre de la barra. Sin ella, una orden limitada colocada en `FirstHourLow` solo se evaluaría en la apertura de la siguiente barra — momento en el que el precio puede haber avanzado ya más allá del nivel. Con ella, el límite se activa en el momento en que el precio toca el límite del canal intrabarra.

### 2. Inicio de Sesión y Ventana de Primera Hora

```pascal
IsFirstHour =
    Time <= CalcTime(SessionStartTime(1,1), FirstHourMinutes);
```

`SessionStartTime(1,1)` devuelve el tiempo oficial de inicio de la sesión principal para la primera serie de datos del gráfico. `CalcTime` añade `FirstHourMinutes` minutos a ese tiempo de inicio, produciendo el límite de la ventana de apertura. Este cálculo hace la estrategia agnóstica al instrumento — lee la definición de sesión directamente del gráfico en lugar de depender de tiempos hardcodeados.

Durante `IsFirstHour`, el canal se construye usando `HighD(0)` y `LowD(0)` — el máximo y mínimo acumulados del día actual respectivamente. Estos valores se actualizan en cada barra durante la primera hora, de modo que `FirstHourHigh` y `FirstHourLow` siempre reflejan el verdadero máximo y mínimo del período de apertura en cualquier momento durante esa ventana.

### 3. Ventana de Trading

```pascal
TradingAllowed =
    not IsFirstHour
    and Time <= StopTradingTime;
```

La estrategia solo acepta entradas después de que la primera hora haya cerrado (`not IsFirstHour`) y antes de la hora de corte (`Time <= StopTradingTime`). Esto crea una ventana definida — típicamente desde el final del período de apertura hasta primera hora de la tarde — durante la cual las órdenes de breakout están activas. Una vez que se alcanza `StopTradingTime`, no se colocan nuevas órdenes limitadas, reduciendo el riesgo de slippage al final de la sesión.

### 4. Construcción del Canal

```pascal
If IsFirstHour Then
Begin
    FirstHourHigh = HighD(0);
    FirstHourLow  = LowD(0);
End;
```

`HighD(0)` y `LowD(0)` son funciones de EasyLanguage que devuelven el máximo y mínimo acumulados de la sesión actual. Asignarlos continuamente durante la primera hora significa que `FirstHourHigh` y `FirstHourLow` están siempre actualizados — en la barra en que `IsFirstHour` transiciona a `False`, capturan los valores finales del período de apertura y esos valores se retienen durante el resto de la sesión.

### 5. Lógica de Entrada — Órdenes Limitadas en los Límites del Canal

```pascal
If TradingAllowed and MarketPosition = 0 Then
Begin
    If CanLongToday Then
        Buy ("FHC_LE") Next Bar at FirstHourLow Limit;

    If CanShortToday Then
        SellShort ("FHC_SE") Next Bar at FirstHourHigh Limit;
End;
```

Ambas órdenes limitadas se colocan simultáneamente durante la ventana de trading. El límite largo está en `FirstHourLow` — si el precio cae hasta el límite inferior del rango de apertura, se activa una posición larga. El límite corto está en `FirstHourHigh` — si el precio sube hasta el límite superior, se activa una posición corta. Solo una puede ejecutarse a la vez ya que se requiere `MarketPosition = 0`, y una vez que cualquiera se ejecuta, el flag correspondiente se deshabilita.

Esta es una dirección de entrada contraintuitiva que merece destacarse: la entrada larga es en el *mínimo* de la primera hora (comprando en soporte), y la entrada corta es en el *máximo* (vendiendo en resistencia). La estrategia no está persiguiendo breakouts por encima del máximo o por debajo del mínimo — está fadeando de vuelta a los límites y entrando en la dirección del rebote anticipado o continuación desde esos niveles.

### 6. Reset Diario y Lógica de Una Operación Por Lado

```pascal
If Date <> LastTradeDate Then
Begin
    CanLongToday  = True;
    CanShortToday = True;
    LastTradeDate = Date;
End;
```

Al inicio de cada nuevo día de trading, ambos flags de dirección se resetean a `True` y `LastTradeDate` se actualiza a la fecha actual. Esto garantiza un estado limpio para cada sesión independientemente de lo que ocurrió el día anterior.

Una vez que una posición se ejecuta, el flag correspondiente se deshabilita:

```pascal
If MarketPosition = 1  Then CanLongToday  = False;
If MarketPosition = -1 Then CanShortToday = False;
```

Esto evita que la estrategia reingrese en la misma dirección tras el cierre de la primera operación — ya sea por stop de pérdida o por target de beneficio. Cada dirección obtiene exactamente una oportunidad por día.

### 7. Gestión del Riesgo

```pascal
SetStopLoss(StopLossAmount);
SetProfitTarget(ProfitTargetAmount);
```

Stop de pérdida y target de beneficio fijos en dólares se aplican simétricamente a todas las posiciones. La ratio 1:1 por defecto ($250 stop / $250 target) significa que la estrategia necesita una tasa de acierto superior al 50% para ser rentable. Estos valores deben calibrarse al rango diario típico del instrumento y a su valor por punto.

---

## v1 vs v2: La Diferencia

### v1 — Flags de Tres Estados y un Riesgo de Fragilidad

v1 gestiona el permiso de entrada usando variables `LongTrade` y `ShortTrade` con tres estados: `1` (permitido), `-1` (bloqueado), `0` (inicial/reseteando). El canal se establece y los flags se resetean en un único bloque durante la primera hora:

```pascal
If Time <= CalcTime(SessionStartTime(1,1), 60) Then
Begin
    HighVal    = HighD(0);
    LowVal     = LowD(0);
    LongTrade  = 1;
    ShortTrade = 1;
End Else
Begin
    If MarketPosition = 1  and LongTrade  = 1 Then LongTrade  = -1;
    If MarketPosition = -1 and ShortTrade = 1 Then ShortTrade = -1;
    ...
End;
```

La lógica de bloqueo comprueba `MarketPosition` y establece inmediatamente el flag a `-1`. Este enfoque tiene una fragilidad: con `IntraBarOrderGeneration = TRUE`, EasyLanguage evalúa la lógica de la estrategia múltiples veces por barra a medida que el precio se mueve. En la misma barra en que se ejecuta una orden limitada, `MarketPosition` puede no reflejar aún la nueva posición en el momento en que se ejecuta la comprobación de bloqueo — dependiendo del orden interno de evaluación de TradeStation. Esto crea una ventana donde el flag no ha sido deshabilitado todavía, y teóricamente podría colocarse una segunda orden en el mismo lado antes de que `LongTrade` se actualice a `-1`.

En la práctica, `Intrabarpersist` en `LongTrade` y `ShortTrade` mitiga parte de este riesgo preservando el estado de la variable entre evaluaciones intrabarra. Sin embargo, la dependencia fundamental de que `MarketPosition` esté actualizado dentro del mismo ciclo de evaluación de barra es una fragilidad que v2 resuelve de forma más robusta.

### v2 — Reset Basado en Fecha y Arquitectura Limpia

v2 reemplaza el sistema de flags de tres estados con dos booleanos `Intrabarpersist` (`CanLongToday`, `CanShortToday`) y un reset diario basado en fecha. La separación en secciones claramente etiquetadas hace cada responsabilidad independientemente legible:

- **Bloque de reset diario:** se ejecuta una vez al inicio de cada nuevo día
- **Bloque de ventanas temporales:** calcula `IsFirstHour` y `TradingAllowed`
- **Bloque de construcción del canal:** actualiza `FirstHourHigh` y `FirstHourLow`
- **Bloque de entrada:** coloca órdenes limitadas cuando se cumplen las condiciones
- **Bloque de deshabilitación de flag:** deshabilita el flag de dirección cuando hay una posición abierta
- **Bloque de gestión del riesgo:** aplica stop y target

El reset basado en fecha en v2 garantiza que los flags nunca se trasladen a la siguiente sesión independientemente de cómo se resolvieron las posiciones del día anterior.

v2 también parametriza `FirstHourMinutes` (hardcodeado a `60` en v1) y añade etiquetas de orden con nombre (`FHC_LE`, `FHC_SE`).

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Construcción del canal** | ✓ | ✓ |
| **Una operación por lado y día** | ✓ (frágil) | ✓ (robusto) |
| **Reset diario basado en fecha** | — | ✓ |
| **`FirstHourMinutes` como parámetro** | — | ✓ (hardcodeado `60` en v1) |
| **Etiquetas de orden con nombre** | — | ✓ (`FHC_LE`, `FHC_SE`) |
| **Bloques separados etiquetados** | — | ✓ |
| **Fragilidad de flag intrabarra** | Presente | Resuelta |

---

## First Hour Channel — Indicador

El indicador ejecuta la misma lógica de ventana temporal y construcción de canal que la estrategia y representa `FirstHourHigh` y `FirstHourLow` como líneas horizontales durante la ventana de trading activa. Las líneas se suprimen fuera de la ventana activa usando `NoPlot`.

```pascal
IsFirstHour = Time <= CalcTime(SessionStartTime(1,1), FirstHourMinutes);

IsChannelActive =
    Time > CalcTime(SessionStartTime(1,1), FirstHourMinutes)
    and Time <= StopPlotTime;

If IsFirstHour Then
Begin
    FirstHourHigh = HighD(0);
    FirstHourLow  = LowD(0);
End;

If IsChannelActive Then
Begin
    Plot1(FirstHourHigh, "FH High");
    Plot2(FirstHourLow,  "FH Low");
End Else
Begin
    NoPlot(1);
    NoPlot(2);
End;
```

**Comportamiento de `NoPlot`:** Cuando `IsChannelActive` es `False` — durante la primera hora y después de `StopPlotTime` — `NoPlot(1)` y `NoPlot(2)` suprimen las líneas del canal. Esto mantiene el gráfico limpio durante la ventana de apertura (antes de que el canal esté finalizado) y después de que se detenga el trading. Las líneas solo aparecen durante la ventana en que las órdenes de entrada de la estrategia están activas.

**Colores configurables:** Los inputs `HighColor` y `LowColor` (con valores por defecto Blue y Red) permiten distinguir visualmente los límites del canal y personalizarlos para adaptarse a los esquemas de color del gráfico.

**Parámetros del indicador:**

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `FirstHourMinutes` | 60 | Duración de la ventana de apertura. Igualar al ajuste de la estrategia. |
| `StopPlotTime` | 1500 | Hora a partir de la cual se suprimen las líneas del canal. Igualar a `StopTradingTime` en la estrategia. |
| `HighColor` | Blue | Color para la línea superior del canal. |
| `LowColor` | Red | Color para la línea inferior del canal. |

> **Nota de uso:** Mantener `FirstHourMinutes` y `StopPlotTime` idénticos entre el indicador y la estrategia para garantizar que las líneas del canal visual se alineen exactamente con la ventana de entrada activa de la estrategia.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `FirstHourMinutes` | 60 | Duración de la ventana de apertura usada para construir el canal. |
| `StopTradingTime` | 1500 | Hora (formato HHMM) a partir de la cual no se aceptan nuevas entradas. |
| `StopLossAmount` | $250 | Stop de pérdida fijo en dólares aplicado a todas las posiciones. |
| `ProfitTargetAmount` | $250 | Target de beneficio fijo en dólares aplicado a todas las posiciones. |

**Sobre `StopTradingTime`:** El valor `1500` representa las 15:00 (3:00 PM) en el formato entero HHMM de EasyLanguage. Para instrumentos con cierres más tempranos (p. ej. futuros de bonos a las 16:00 CT o futuros de renta variable a las 16:15 ET), debe ajustarse en consecuencia. Establecerlo demasiado cerca del fin de sesión arriesga que las posiciones no se resuelvan antes del cierre — combinar con End-of-Day Exit si las posiciones overnight son inaceptables.

**Sobre el dimensionamiento de stop y target:** Los valores simétricos por defecto de $250 implican una ratio de riesgo/beneficio 1:1 que requiere >50% de tasa de acierto para ser rentable. Deben calibrarse al `BigPointValue` del instrumento y a su rango diario típico. Para futuros ES a $50/punto, $250 equivale a 5 puntos de riesgo — apropiado para una sesión con un rango diario promedio de 30–50 puntos.

---

## Escenarios de Operación

### Escenario A — Entrada Larga en el Mínimo de la Primera Hora

- La sesión abre a las 09:30. `FirstHourMinutes = 60`.
- Durante 09:30–10:30: ES alcanza un máximo de 4.985 y un mínimo de 4.962. Canal establecido: `FirstHourHigh = 4.985`, `FirstHourLow = 4.962`.
- 10:30: `IsFirstHour` transiciona a `False`. `TradingAllowed = True`. Ambas órdenes limitadas colocadas.
- 11:15: El precio cae a 4.962. El límite largo se ejecuta. `CanLongToday = False`.
- Stop a $250 por debajo de la entrada (≈4.957 para ES a $50/pt = 5 pts).
- Target a $250 por encima de la entrada (≈4.967).
- El precio se recupera. El target de beneficio se ejecuta a 4.967. Operación cerrada.
- El límite corto sigue activo — `CanShortToday` sigue en `True`.

### Escenario B — Entrada Corta en el Máximo de la Primera Hora, Largo Bloqueado

- Mismo canal: `FirstHourHigh = 4.985`, `FirstHourLow = 4.962`.
- 10:45: El precio sube hasta 4.985. El límite corto se ejecuta. `CanShortToday = False`.
- Stop a $250 por encima de la entrada; target a $250 por debajo.
- El precio continúa subiendo, el stop de pérdida se ejecuta. Operación cerrada con pérdida.
- 12:00: El precio cae a 4.962. El límite largo podría activarse — `CanLongToday` sigue en `True`.
- La entrada larga se ejecuta. `CanLongToday = False`.
- Ambos lados operados en el día.

### Escenario C — StopTradingTime Alcanzado, Sin Entrada

- Canal: `FirstHourHigh = 4.985`, `FirstHourLow = 4.962`.
- El precio se mantiene entre los límites del canal todo el día.
- 15:00: `Time > StopTradingTime`. `TradingAllowed = False`. Las órdenes limitadas ya no se colocan.
- Sin operación tomada. La estrategia se resetea mañana.

---

## Características Clave

- **`IntraBarOrderGeneration`:** Directiva requerida que habilita las ejecuciones de órdenes limitadas dentro de una barra, garantizando ejecución precisa en los niveles de límite del canal sin esperar al cierre de la barra.
- **Universalidad de `SessionStartTime(1,1)`:** La ventana de apertura se calcula a partir de la definición de sesión del gráfico en lugar de tiempos hardcodeados, haciendo la estrategia agnóstica al instrumento.
- **Construcción de canal con `HighD(0)` / `LowD(0)`:** Máximo y mínimo diarios acumulados actualizados continuamente durante la primera hora, capturando el verdadero límite del rango de apertura en el momento en que la ventana cierra.
- **Una operación por dirección y día:** El reset basado en fecha combinado con flags `Intrabarpersist` evita la reentrada en la misma dirección tras la resolución de la primera operación.
- **Ventana de trading definida:** `TradingAllowed` combina las condiciones de post-apertura y pre-corte en un único booleano, manteniendo el bloque de entrada limpio y legible.
- **`NoPlot` en el indicador:** Las líneas del canal se suprimen fuera de la ventana activa, manteniendo el gráfico limpio durante el período de apertura y después de que el trading se detenga.
- **Ventana de apertura configurable:** `FirstHourMinutes` como parámetro permite testear con ventanas de 30, 45 minutos u otras sin cambios en el código.

---

## Psicología del Trading

First Hour Channel encarna una creencia específica sobre la estructura intradiaria del mercado: **la hora de apertura revela el rango de volatilidad del día, y revistar sus límites más tarde en la sesión representa una oportunidad de mean-reversion de alta probabilidad.**

El período de apertura es único en que concentra el flujo de órdenes overnight, los rellenos de gaps y el posicionamiento institucional inicial en una ventana comprimida. El máximo y mínimo establecidos durante este período no son aleatorios — reflejan el proceso de subasta inicial del mercado, donde compradores y vendedores establecen los puntos de referencia iniciales del día. Cuando el precio regresa a estos niveles más tarde en la sesión, está probando si el consenso inicial se mantiene.

La regla de una operación por dirección refleja una postura disciplinada sobre el comportamiento del rango: una vez que un límite ha sido probado y la operación se ha resuelto (ya sea por stop o por target), el límite ha cumplido su propósito para esa sesión. Reingresar en el mismo nivel múltiples veces aumenta la exposición a whipsaws — el mercado puede oscilar alrededor del límite en lugar de ofrecer un movimiento direccional limpio.

El stop y target simétricos de $250 codifican una visión neutral sobre qué dirección prevalecerá dentro del rango del día. La estrategia simplemente dice *"si el precio alcanza este nivel, es probable que algo ocurra"* — y acepta igual riesgo en ambas direcciones.

---

## Casos de Uso

**Instrumentos:** Adecuada para mercados intradiarios líquidos con volatilidad de apertura predecible — futuros de índices de renta variable (ES, NQ, YM), acciones individuales con sesiones de apertura activas, y futuros FX principales. La construcción del canal requiere suficiente actividad de precio durante la ventana de apertura para establecer límites significativos; los instrumentos con poco volumen pueden producir canales artificialmente estrechos.

**Marcos temporales:** Diseñada para barras intradiarias (1-min, 5-min, 15-min). La ventana de apertura y los límites del canal son específicos de la sesión — la estrategia se resetea completamente cada día. El tamaño de barra afecta a la precisión de entrada: barras más pequeñas permiten una colocación más fina de órdenes limitadas y una respuesta más rápida a los toques del canal.

**Condiciones de mercado:** Rinde mejor cuando la sesión tiene momentum direccional después de la ventana de apertura — el precio rompe hacia o desde un límite y continúa. Tiene dificultades en sesiones donde el precio oscila repetidamente alrededor de los límites del canal sin resolución, generando múltiples toques de límite sin movimientos direccionales limpios. La regla de una operación por lado limita el daño en condiciones laterales pero también limita el beneficio en días muy tendenciales.

**Combinación con otros componentes:** First Hour Channel gestiona entradas y riesgo mediante stop/target fijos pero no tiene salida temporal. Combinar con End-of-Day Exit garantiza que las posiciones no se trasladen overnight si el target de beneficio o el stop no se han alcanzado al final de la sesión. AccountRiskCore proporciona protección de pérdida diaria a nivel de cuenta independientemente de la lógica de stop por operación de la estrategia.
