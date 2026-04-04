# End-of-Day Exit — v1.0 & v2.0

## Descripción de la Estrategia

End-of-Day Exit es un componente exclusivo de salida que cierra automáticamente todas las posiciones abiertas un número configurable de minutos antes de que termine la sesión de mercado. No es una estrategia de trading — es un wrapper de protección que puede añadirse a cualquier estrategia intradiaria para garantizar que ninguna posición se mantenga de un día para otro. El componente gestiona tanto el trading en vivo como el backtesting, usando el tiempo real del ordenador para la ejecución en vivo y `SetExitOnClose` como aproximación histórica para la validación de estrategias.

---

## Mecánica Central

### 1. IntrabarOrderGeneration

```pascal
[IntraBarOrderGeneration = TRUE]
```

Esta directiva de compilador debe declararse al inicio del script. Instruye a TradeStation para que evalúe la lógica de la estrategia y genere órdenes *dentro* de cada barra a medida que se forma, en lugar de esperar al cierre de la barra. Sin esta directiva, la comprobación de salida EOD solo se ejecutaría al cierre de barra — momento en el que la sesión ya podría haber terminado y la posición mantenida hasta el día siguiente. Es el requisito fundamental que hace posibles las salidas intrabar basadas en tiempo.

### 2. Detección del Contexto Temporal

El componente determina qué camino de ejecución tomar evaluando dos condiciones temporales:

```pascal
IsRealTime  = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1, 1), -EODExitMinutes);
```

**`IsRealTime`** es `True` solo cuando ambas condiciones se cumplen simultáneamente: la barra actual es la última barra del gráfico (`LastBarOnChart`) *y* la fecha de la barra coincide con la fecha de hoy (`Date = CurrentDate`). Esta combinación identifica una barra viva en tiempo real — a diferencia de una barra histórica que se está reproduciendo en backtesting.

**`IsEODWindow`** es `True` cuando el tiempo actual del ordenador ha alcanzado o superado el tiempo de activación de la salida calculado. `CalcTime(SessionEndTime(1, 1), -EODExitMinutes)` calcula el tiempo de cierre de sesión menos `EODExitMinutes` minutos. `SessionEndTime(1, 1)` devuelve el tiempo oficial de fin de la sesión principal para la primera serie de datos del gráfico — esto funciona correctamente en acciones, futuros y forex sin ninguna configuración específica del instrumento.

Piensa en `IsRealTime` e `IsEODWindow` como dos relojes independientes que deben coincidir antes de que se active la salida: uno confirma *"esto está ocurriendo ahora, no en una reproducción histórica"*, el otro confirma *"el reloj indica que es hora de salir."*

### 3. Ramas de Ejecución

```pascal
If EODExitMinutes > 0 Then
Begin
    If IsRealTime and IsEODWindow Then
    Begin
        If IsLong  Then Sell       ("EOD_LX") Next Bar at Market;
        If IsShort Then BuyToCover ("EOD_SX") Next Bar at Market;
    End
    Else
        SetExitOnClose;
End;
```

La lógica tiene tres estados posibles:

**Rama A — Salida en vivo (IsRealTime = True, IsEODWindow = True):**
La ventana EOD se ha abierto en una barra viva. Las órdenes de salida se colocan para la siguiente barra a mercado. `IntraBarOrderGeneration = TRUE` garantiza que estas órdenes se envíen antes de que cierre la sesión, no después.

**Rama B — Aproximación de backtesting (IsRealTime = False):**
La barra actual es histórica. `SetExitOnClose` instruye al motor de backtesting para cerrar la posición al precio de cierre de la barra. Esta no es una simulación perfecta del comportamiento EOD en vivo — en trading en vivo, las ejecuciones de salida dependen de las condiciones del mercado en los últimos minutos — pero proporciona una aproximación razonable y consistente para la validación de estrategias.

**Rama C — Condición de desactivación (EODExitMinutes = 0):**
Establecer `EODExitMinutes = 0` desactiva todo el componente. Ni las salidas en vivo ni `SetExitOnClose` se llaman. Esto permite desactivar el componente sin eliminarlo de la estrategia.

### 4. Máquina de Estados de Posición (v2)

v2 introduce el seguimiento explícito de posición:

```pascal
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;
```

En v1, las órdenes de salida se colocan incondicionalmente — tanto `Sell` como `BuyToCover` se llaman independientemente de si hay una posición abierta. EasyLanguage ignora las órdenes de salida cuando no hay una posición coincidente, por lo que funciona en la práctica, pero genera actividad de órdenes innecesaria en el registro de órdenes de la plataforma. En v2, cada orden de salida solo se coloca cuando hay una posición real que cerrar.

---

## v1 vs v2: La Diferencia

Las dos versiones implementan un comportamiento idéntico. La evolución es estructural.

### v1 — Compacto y Directo

Toda la lógica es inline. Las órdenes de salida se colocan incondicionalmente (sin comprobación de posición), y no hay variables con nombre para las condiciones temporales:

```pascal
If LastBarOnChart and Date = CurrentDate Then
Begin
    If CurrentTime >= CalcTime(SessionEndTime(1,1), -MinstoX) Then
    Begin
        Sell ("EOD LX") Next Bar at Market;        // Sin comprobación IsLong
        BuyToCover ("EOD SX") Next Bar at Market;  // Sin comprobación IsShort
    End;
End Else
    SetExitOnClose;
```

La lógica es correcta pero requiere que el lector interprete las condiciones temporales inline e infiera la estructura de dos ramas a partir del patrón `If / Else`.

### v2 — Condiciones con Nombre y Guards de Posición

v2 extrae las condiciones temporales en booleanos con nombre y añade guards de posición antes de cada orden de salida:

```pascal
IsRealTime  = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1,1), -EODExitMinutes);

If IsRealTime and IsEODWindow Then
Begin
    If IsLong  Then Sell       ("EOD_LX") Next Bar at Market;
    If IsShort Then BuyToCover ("EOD_SX") Next Bar at Market;
End
Else
    SetExitOnClose;
```

La lógica de entrada ahora se lee como una frase: *"si estamos en tiempo real y la ventana EOD se ha abierto, cerrar posiciones."* Las condiciones están nombradas por lo que significan, no por lo que calculan.

v2 también renombra el parámetro de `MinstoX` a `EODExitMinutes` — el nombre original era una abreviación truncada (`Mins to X`, donde `X` era presumiblemente "exit") que requería adivinanza para interpretarse. El nuevo nombre es autoexplicativo.

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Comportamiento de salida** | ✓ | ✓ |
| **`SetExitOnClose` para backtesting** | ✓ | ✓ |
| **Condiciones temporales con nombre** | — | ✓ (`IsRealTime`, `IsEODWindow`) |
| **Guards de posición antes de salidas** | — | ✓ (`IsLong`, `IsShort`) |
| **Nombre de parámetro descriptivo** | `MinstoX` | `EODExitMinutes` |
| **Etiquetas de orden con nombre** | `EOD LX`, `EOD SX` (espacio) | `EOD_LX`, `EOD_SX` (guión bajo) |

> **Sobre la nomenclatura de etiquetas de orden:** v1 usa espacios en las etiquetas de orden (`"EOD LX"`). v2 usa guiones bajos (`"EOD_LX"`), coherente con la convención de nomenclatura usada en todo el repositorio y más seguro para la compatibilidad con la plataforma.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `EODExitMinutes` | 3 | Minutos antes del cierre de sesión para activar las órdenes de salida. Establecer a `0` para desactivar el componente por completo. |

**Sobre la elección del valor correcto:** El número apropiado de minutos depende de la liquidez del instrumento en los últimos minutos de la sesión y de la latencia de envío de órdenes de la plataforma. Tres minutos es un valor por defecto conservador para futuros líquidos (ES, NQ) durante el horario regular de trading. Los instrumentos con menor liquidez o un enrutamiento de órdenes más lento pueden requerir un margen mayor. Establecer este valor demasiado pequeño arriesga que la orden de salida no se ejecute antes de que cierre la sesión.

---

## Escenarios de Operación

### Escenario A — Salida en Vivo Activada (Posición Larga)

- Tiempo de fin de sesión: 16:00. `EODExitMinutes = 3`.
- Tiempo de activación de salida: `CalcTime(16:00, -3) = 15:57`.
- A las 15:57:30, `CurrentTime >= 15:57` → `IsEODWindow = True`.
- `LastBarOnChart = True`, `Date = CurrentDate` → `IsRealTime = True`.
- `IsLong = True` → `Sell ("EOD_LX") Next Bar at Market` colocada.
- La orden se ejecuta en el siguiente tick intrabarra. Posición cerrada antes de las 16:00.

### Escenario B — Salida en Vivo, Sin Posición Abierta

- Mismas condiciones que el Escenario A, pero `MarketPosition = 0`.
- `IsRealTime = True`, `IsEODWindow = True`.
- `IsLong = False`, `IsShort = False` → no se colocan órdenes de salida.
- El componente no hace nada. Sin actividad de órdenes innecesaria (comportamiento v2).

### Escenario C — Barra Histórica (Backtesting)

- Procesando una barra histórica de hace tres meses.
- `LastBarOnChart = False` → `IsRealTime = False`.
- `SetExitOnClose` llamado → la posición cierra al precio de cierre de la barra.
- Esto aplica a todas las barras históricas independientemente de la hora del día.

### Escenario D — Componente Desactivado

- `EODExitMinutes = 0`.
- El guard exterior `If EODExitMinutes > 0` evalúa a `False`.
- Ni las salidas en vivo ni `SetExitOnClose` se llaman.
- Las posiciones son gestionadas íntegramente por las reglas de salida propias de la estrategia principal.

---

## Características Clave

- **Diseño exclusivo de salida:** Sin reglas de entrada. El componente se adjunta a cualquier estrategia existente sin interferir con su lógica de entrada.
- **`IntraBarOrderGeneration`:** Directiva requerida que habilita el envío de órdenes intrabarra, haciendo posibles las salidas basadas en tiempo dentro de una barra.
- **Ejecución dual:** Tiempo real del ordenador para trading en vivo; `SetExitOnClose` para backtesting — ambos controlados por el mismo camino de código.
- **Universalidad de `SessionEndTime(1, 1)`:** El tiempo de fin de sesión se lee directamente de la definición de sesión del gráfico, haciendo el componente agnóstico al instrumento. Sin tiempos hardcodeados.
- **Desactivación mediante parámetro:** Establecer `EODExitMinutes = 0` desactiva limpiamente el componente sin cambios en el código.
- **Guards de posición (v2):** Las órdenes de salida solo se colocan cuando existe una posición coincidente, manteniendo el registro de órdenes limpio.

---

## Psicología del Trading

El componente End-of-Day Exit codifica un principio de gestión del riesgo simple pero importante: **los riesgos conocidos son preferibles a los desconocidos.** Una estrategia intradiaria que cierra a una hora definida cada día incurre en un coste de salida conocido y acotado — slippage en los últimos minutos de la sesión. La alternativa — mantener posiciones de un día para otro — expone la cuenta al riesgo de gap: movimientos de precio que ocurren entre el cierre y la apertura siguiente, durante los cuales ningún stop loss ni trailing stop puede proteger la posición.

Para los traders sistemáticos intradiarios, la salida EOD no es una concesión al miedo — es una restricción deliberada que mantiene el comportamiento de la estrategia dentro del régimen para el que fue diseñada y testeada. Una estrategia que fue optimizada sobre datos intradiarios y sale intradiario tiene un edge definido dentro de esas condiciones. Mantener posiciones de un día para otro introduce un régimen de mercado diferente (menor liquidez, distintos participantes, eventos de noticias) para el que la estrategia no tiene modelo.

El buffer de tres minutos antes del cierre refleja una realidad práctica: los mercados pierden liquidez en los últimos minutos de una sesión. Salir ligeramente antes del cierre típicamente produce mejores ejecuciones que una orden a mercado colocada en el último segundo de trading.

---

## Casos de Uso

**Estrategias intradiarias que requieren resets diarios:** Cualquier estrategia que asume posicionamiento flat al inicio de cada sesión — momentum, mean reversion, breakout — se beneficia de un cierre EOD garantizado para asegurar que las señales del día siguiente parten de un estado limpio.

**Prevención del riesgo de gap overnight:** Los contratos de futuros y las acciones individuales pueden sufrir gaps significativos entre sesiones por noticias, resultados o eventos macroeconómicos. La salida EOD elimina esta exposición por completo para estrategias que no tienen una tesis overnight.

**Límites regulatorios o de firma:** Las mesas de trading propietario y las cuentas reguladas frecuentemente imponen restricciones de solo intradiario. La salida EOD proporciona una capa de imposición mecánica que complementa la protección a nivel de cuenta de AccountRiskCore.

**Consistencia en backtesting:** `SetExitOnClose` garantiza que las simulaciones históricas reflejen una disciplina de salida EOD, evitando que el backtester mantenga posiciones entre sesiones cuando la estrategia en vivo no lo haría.

**Combinación con otros componentes:** End-of-Day Exit está diseñado para funcionar junto a estrategias de entrada y componentes de riesgo como AccountRiskCore y ATRDollar TrailStop. En una configuración típica: la estrategia de entrada abre posiciones, ATRDollar TrailStop gestiona la salida por trailing, AccountRiskCore impone el límite de P&L diario, y End-of-Day Exit garantiza que nada sobreviva a la siguiente sesión.
