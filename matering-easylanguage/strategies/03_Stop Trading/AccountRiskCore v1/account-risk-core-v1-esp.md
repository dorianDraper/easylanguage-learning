# AccountRiskCore — v1

## Descripción del Sistema

AccountRiskCore es un sistema de gestión del riesgo a nivel de cuenta que monitoriza el beneficio y la pérdida diarios en tiempo real y detiene automáticamente toda actividad de trading cuando se superan límites predefinidos. No es una estrategia de trading — es un wrapper de protección dentro del cual puede vivir cualquier estrategia. El sistema evalúa la equity de la cuenta de forma continua, proporciona monitorización visual y alertas sonoras, y cierra mecánicamente todas las posiciones abiertas en el momento en que se cruza un umbral de riesgo.

El sistema impone dos límites simétricos: una pérdida diaria máxima (protección a la baja) y un beneficio diario máximo (disciplina al alza). Una vez que se supera cualquiera de los dos límites, un mecanismo de latch garantiza que el trading no pueda reanudarse durante el resto de la sesión — incluso si el P&L recupera y vuelve dentro de los límites.

AccountRiskCore v1 está compuesto por cuatro componentes que funcionan juntos como un único sistema integrado:

| Componente | Tipo | Rol |
|---|---|---|
| `AccountRiskCore.Function` | Función | Lógica central de evaluación del riesgo |
| `AccountRiskCore.Strategy` | Estrategia | Impone el halt de trading y cierra posiciones |
| `AccountRiskCore.Alert` | Indicador | Notificación en tiempo real cuando se superan los límites |
| `AccountRiskCore.Monitor` | Indicador | Visualización continua del P&L diario y los límites |

---

## Visión General de la Arquitectura

Los cuatro componentes comparten un principio de diseño común: **un único cálculo, múltiples consumidores.** La lógica de P&L diario y evaluación de límites vive en `AccountRiskCore.Function`. Todos los demás componentes llaman a esta función directamente o replican el mismo cálculo de forma independiente para propósitos de visualización.

```
AccountRiskCore.Function
        │
        ├──► AccountRiskCore.Strategy  (impone el halt + kill switch)
        │
        ├──► AccountRiskCore.Alert     (activa alerta cuando se superan los límites)
        │
        └──► AccountRiskCore.Monitor   (representa P&L y bandas de límites)
```

`AccountRiskCore.Strategy` es el único componente que llama a la función directamente. Los dos indicadores replican el cálculo del P&L de forma independiente porque los indicadores de EasyLanguage no pueden llamar a funciones de estrategia — utilizan la misma lógica pero mediante llamadas directas de equity en lugar de la función compartida.

> **Nota arquitectónica v1:** En v1, los indicadores no llaman a `AccountRiskCore.Function` — duplican el cálculo del P&L internamente. Esta redundancia es la principal limitación arquitectónica que v2 aborda refactorizando la función como una utilidad compartida invocable por todos los componentes.

---

## Referencia de Componentes

### AccountRiskCore.Function

**Nombre anterior:** `AccountEquityStop_JP`

El núcleo del sistema. Una función EasyLanguage reutilizable que recupera la equity de la cuenta en tiempo real, calcula el P&L del día, lo compara con los límites configurados y devuelve un booleano indicando si el trading está permitido.

**Firma de la función:**
```pascal
Inputs:
    MaxDailyLoss(numeric),      // Pérdida diaria máxima permitida en dólares
    MaxDailyProfit(numeric),    // Beneficio diario máximo permitido en dólares
    AccountID(string),          // Identificador de cuenta para recuperar la equity
    oDailyNetPL(numericref);    // Salida: P&L diario actual pasado por referencia
```

**Lógica interna:**

```pascal
// Recuperar valores de equity
BeginDayEquity = GetBDAccountNetWorth(AccountID);   // Equity inicio de día
CurrentEquity  = GetRTAccountNetWorth(AccountID);   // Equity en tiempo real

// Calcular P&L diario
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;   // Pasar P&L al llamador por referencia

// Evaluar límites y devolver resultado
If DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit Then
    AccountEquityStop_JP = True    // Trading permitido
Else
    AccountEquityStop_JP = False;  // Trading bloqueado
```

**Decisiones de diseño clave:**
- `GetBDAccountNetWorth` recupera la equity de inicio de día — una instantánea tomada en la apertura de sesión, no en el cierre anterior. Esto garantiza que el P&L diario se resetee limpiamente cada sesión.
- `GetRTAccountNetWorth` recupera la equity en tiempo real, reflejando todo el P&L abierto y cerrado de la sesión actual.
- El parámetro de salida `oDailyNetPL` usa `numericref` — un mecanismo de paso por referencia — permitiendo al llamador recibir el valor de P&L calculado sin una segunda llamada de equity.
- El nombre de función `AccountEquityStop_JP` se preserva en el código v1 por compatibilidad con TradeStation; el cambio de nombre a `AccountRiskCore.Function` aplica a la documentación y nomenclatura del repositorio.

**Function v1 vs Function v2 — la diferencia:**

Ambas versiones implementan lógica idéntica. La evolución es estructural:

| | Function v1 | Function v2 |
|---|---|---|
| Nomenclatura de variable interna | `DailyNetPL` (solapa el nombre del parámetro de salida) | `ComputedDailyPL` (nombre distinto, sin solapamiento) |
| Bloques de código | Comentarios inline | Bloques etiquetados separados |
| Legibilidad | Funcional | Más limpia, autodocumentada |

```pascal
// v1 — la variable interna solapa el parámetro de salida
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;

// v2 — variable interna distinta, sin ambigüedad
ComputedDailyPL = CurrentEquity - BeginDayEquity;
oDailyNetPL     = ComputedDailyPL;
```

Function v2 es la versión recomendada y la que se usa en `AccountRiskCore.Strategy v2`.

---

### AccountRiskCore.Strategy

**Nombre anterior:** `Account Equity Risk Gate with Kill Switch`

La capa de ejecución. Este componente llama a `AccountRiskCore.Function` en cada barra viva, impone el mecanismo de latch, cierra todas las posiciones abiertas cuando se superan los límites, y controla cualquier estrategia de trading dentro de un bloque de permiso.

**Strategy v1:**

```pascal
// Evaluar riesgo de cuenta solo en barras vivas
If LastBarOnChart Then
    AccountTradingAllowed =
        AccountEquityStop_JP(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL)
Else
    AccountTradingAllowed = True;   // Barras históricas: asumir trading permitido

// Kill switch
If not AccountTradingAllowed Then
Begin
    If IsLong  Then Sell       ("AcctStop_LX") Next Bar at Market;
    If IsShort Then BuyToCover ("AcctStop_SX") Next Bar at Market;
End;

// Puerta de ejecución de estrategia
If AccountTradingAllowed Then
Begin
    // Lógica de estrategia aquí
End;
```

**Strategy v2 — el mecanismo de latch:**

v1 tiene un gap crítico: `AccountTradingAllowed` se re-evalúa en cada barra. Si el P&L recupera y vuelve dentro de los límites tras una ruptura — por ejemplo, una posición abierta se mueve favorablemente — el flag podría volver a `True` y re-habilitar el trading. Esto anula el propósito de un stop diario fijo.

v2 introduce `RiskTriggered`, un latch booleano que, una vez establecido a `True`, mantiene `AccountTradingAllowed` permanentemente en `False` durante el resto de la sesión:

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountEquityStop_JP(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL);

    // Latch: una vez activado, no puede resetearse dentro de la sesión
    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

// Aplicar estado del latch
If RiskTriggered Then
    AccountTradingAllowed = False;
```

v2 también cambia la orden de salida del kill switch de `Next Bar at Market` a `This Bar on Close`:

```pascal
// v1 — salida en la siguiente barra
Sell ("AcctStop_LX") Next Bar at Market;

// v2 — salida en el cierre de la barra actual (más rápido, misma sesión)
Sell ("AcctStop_LX") This Bar on Close;
```

`This Bar on Close` se ejecuta en la misma barra que activa la ruptura, eliminando el retraso de una barra de v1 y reduciendo la exposición durante el período entre detección y salida.

**Resumen Strategy v1 vs v2:**

| | Strategy v1 | Strategy v2 |
|---|---|---|
| Mecanismo de latch | Ninguno — re-evalúa cada barra | Flag `RiskTriggered` cierra permanentemente |
| Timing del kill switch | Siguiente barra a mercado | Misma barra al cierre |
| Re-habilitación tras ruptura | Posible si el P&L recupera | Imposible — el latch se mantiene |
| Estructura del código | Bloques inline | Bloques separados etiquetados |

---

### AccountRiskCore.Alert

**Nombre anterior:** `AccountEquityAlert`

Un indicador en tiempo real que activa una alerta sonora y visual en el momento en que se superan los límites diarios de P&L. Se ejecuta solo en barras vivas (`LastBarOnChart`) para garantizar que usa valores de equity reales en tiempo real en lugar de datos históricos.

```pascal
If LastBarOnChart Then
Begin
    BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
    CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
    DailyNetPL           = CurrentAccountEquity - BDAccountEquity;

    WithinLimits =
        DailyNetPL > -MaxDailyLoss
        and DailyNetPL < MaxDailyProfit;

    If not WithinLimits Then
        Alert;   // Activa alerta sonora/visual
End;
```

**Plots visuales:**

| Plot | Etiqueta | Valor |
|---|---|---|
| Plot1 | Daily P&L | P&L diario actual |
| Plot2 | Zero | Línea de referencia 0 |
| Plot3 | Max Loss | `-MaxDailyLoss` |
| Plot4 | Max Profit | `+MaxDailyProfit` |

Plot1 se vuelve rojo cuando se superan los límites. Los colores por defecto están definidos en bloques comentados en el código, proporcionando un esquema de color ya preparado (Olive para P&L, Gainsboro para cero, IndianRed para límite de pérdida, RoyalBlue para límite de beneficio) que puede activarse descomentando.

> **Alcance:** La alerta se activa cuando se supera *cualquiera* de los límites — pérdida o beneficio. Sirve como capa de aviso temprano; el kill switch en `AccountRiskCore.Strategy` gestiona el cierre efectivo de posiciones.

---

### AccountRiskCore.Monitor

**Nombre anterior:** `AccountEquityMonitor`

Un indicador de monitorización continua que calcula y muestra el P&L diario en cada barra — no solo en las barras vivas. A diferencia del componente Alert, Monitor se ejecuta en todas las barras para proporcionar una referencia visual persistente del estado de riesgo diario de la cuenta durante toda la sesión.

```pascal
// Se ejecuta en cada barra (sin guard LastBarOnChart)
BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
DailyNetPL           = CurrentAccountEquity - BDAccountEquity;

WithinLimits =
    DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit;
```

**Plots visuales:**

| Plot | Etiqueta | Valor |
|---|---|---|
| Plot1 | Daily P&L | P&L diario actual (verde/rojo) |
| Plot2 | Max Loss | Límite `-MaxDailyLoss` |
| Plot3 | Max Profit | Límite `+MaxDailyProfit` |

Plot1 es verde cuando el P&L está dentro de los límites y se vuelve rojo cuando se cruza cualquier límite. Un Plot4 (línea cero) comentado está disponible para activación.

**Alert vs Monitor — cuándo usar cada uno:**

| | AccountRiskCore.Alert | AccountRiskCore.Monitor |
|---|---|---|
| Ejecución | Solo barras vivas | Cada barra |
| Propósito principal | Notificación | Visualización |
| Activa alerta | Sí | No |
| Visualización histórica | No | Sí |
| Uso en trading en vivo | Sí (capa de notificación) | Sí (capa visual) |
| Uso en backtesting | No útil | Útil para revisión visual |

En trading en vivo, ambos componentes deben estar activos simultáneamente: Monitor proporciona el dashboard visual continuo, Alert proporciona la notificación en tiempo real cuando se requiere acción.

---

## Parámetros

| Parámetro | Function | Strategy | Alert | Monitor |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (como `AccountID`) | vía `GetAccountID` | ✓ (como `AccountNumber`) | ✓ (como `AccountNumber`) |

> **Sobre `AccountID` vs `AccountNumber`:** La función usa `AccountID` (string input pasado por el llamador); la estrategia lo recupera automáticamente vía `GetAccountID`; los indicadores usan `AccountNumber` como string input. Todos se refieren al mismo identificador de cuenta del broker — la inconsistencia de nomenclatura es un artefacto de v1 que se aborda en v2.

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `MaxDailyLoss` | $5.000 | Pérdida diaria máxima en dólares antes de detener todo el trading. |
| `MaxDailyProfit` | $5.000 | Beneficio diario máximo en dólares antes de detener todo el trading. |
| `AccountID` / `AccountNumber` | `""` | Identificador de cuenta del broker usado para recuperar valores de equity. |

---

## Comportamiento del Sistema

### Estado Normal de Trading

- La sesión abre. `GetBDAccountNetWorth` captura la equity de inicio de día.
- `DailyNetPL = 0`. Ambos límites inactivos.
- Monitor muestra la línea de P&L dentro de la banda verde entre `[-MaxDailyLoss, +MaxDailyProfit]`.
- `AccountTradingAllowed = True`. La estrategia se ejecuta con normalidad.

### Secuencia de Ruptura de Límite

1. El P&L diario alcanza o cruza un límite (pérdida o beneficio).
2. `AccountRiskCore.Function` devuelve `False`.
3. **Strategy v1:** `AccountTradingAllowed = False` en esta barra. El kill switch coloca órdenes de salida para la siguiente barra a mercado.
4. **Strategy v2:** `AccountTradingAllowed = False`. `RiskTriggered = True` (latch activado). El kill switch cierra posiciones en el cierre de esta barra.
5. `AccountRiskCore.Alert` activa notificación sonora/visual.
6. Monitor cambia Plot1 a rojo.

### Resto de la Sesión

- `RiskTriggered = True` (solo v2): el latch mantiene `AccountTradingAllowed = False` independientemente del movimiento posterior del P&L.
- No se permiten nuevas entradas. La puerta de ejecución de estrategia bloqueada.
- Monitor permanece en rojo. Alert permanece activo como recordatorio.

### Siguiente Sesión

- `RiskTriggered` se resetea a `False` (las variables de EasyLanguage se resetean entre sesiones).
- `GetBDAccountNetWorth` captura la nueva equity de inicio de día.
- El sistema evalúa desde cero con P&L diario en 0.

### Ejemplo de Día Completo

| Hora | Evento | P&L Diario | Estado |
|---|---|---|---|
| 09:30 | La sesión abre | $0 | Trading permitido |
| 10:15 | Dos operaciones ganadoras | +$3.000 | Dentro de límites |
| 11:45 | Límite de beneficio alcanzado | +$5.100 | **Límite superado** |
| 11:45 | Kill switch se activa | +$5.100 | Posiciones cerradas, latch activado |
| 13:00 | Operación abierta habría recuperado | +$3.800 | Latch se mantiene — sin reentrada |
| 16:00 | Cierre de sesión | +$3.800 | Día protegido |
| 09:30+1 | Nueva sesión | $0 | Sistema se resetea |

---

## Características Clave

- **Protección a nivel de cuenta:** La gestión del riesgo opera a nivel de cuenta, no a nivel de operación. Un único sistema protege todas las estrategias que se ejecutan simultáneamente.
- **Límites bidireccionales:** Se imponen tanto el tope de pérdida como el de beneficio. El tope de beneficio previene el sobretrading en días fuertes y bloquea resultados excepcionales.
- **Garantía de latch (v2):** Una vez activado, el kill switch no puede re-habilitarse dentro de la sesión — ni por recuperación del P&L, ni por lógica manual. El latch es una puerta de un solo sentido.
- **Salida inmediata (v2):** `This Bar on Close` sale en la misma barra que activa la ruptura, eliminando el retraso de una barra del `Next Bar at Market` de v1.
- **Fuente única de verdad:** Toda la lógica de evaluación de riesgo vive en `AccountRiskCore.Function`. La estrategia y los indicadores derivan su estado de permiso del mismo cálculo.
- **Evaluación en tiempo real:** La función y la estrategia usan `LastBarOnChart` para garantizar que solo se usan valores de equity reales para las decisiones de riesgo. Las barras históricas por defecto a `AccountTradingAllowed = True` para permitir backtesting.
- **Diseño sin discrecionalidad:** El sistema es completamente mecánico. No es posible ninguna anulación manual dentro de una sesión una vez activado el latch.
- **Agnóstico a la estrategia:** Cualquier estrategia de trading puede colocarse dentro del bloque `If AccountTradingAllowed Then` sin modificación. El wrapper de riesgo es completamente independiente de la lógica de entrada y salida.

---

## Psicología del Trading

AccountRiskCore encarna un principio rector único: **proteger la cuenta primero, la operación después.**

La mayoría de la gestión del riesgo en trading se centra a nivel de posición — stops de pérdida, sizing de posición, pérdida máxima por operación. Estos son necesarios pero insuficientes. Una estrategia con un stop bien definido por operación puede igualmente destruir una cuenta mediante una secuencia de pérdidas máximas en una única sesión, o mediante sobretrading en una racha ganadora hasta que se revierte. AccountRiskCore opera un nivel por encima: no le importan las operaciones individuales, solo si la cuenta en su conjunto está dentro de los límites diarios aceptables.

El tope de beneficio merece atención particular porque es psicológicamente contraintuitivo. Detener el trading tras un día fuerte parece dejar dinero sobre la mesa. El razonamiento es el opuesto: un día con +$5.000 en P&L es un día que vale la pena proteger. Los mercados que dan generosamente por la mañana frecuentemente recuperan de forma agresiva por la tarde. El tope de beneficio no es pesimismo — es el reconocimiento de que los días excepcionales son escasos y vale la pena consolidarlos.

El mecanismo de latch aborda una trampa psicológica específica: la tentación de racionalizar la reentrada tras una ruptura de límite. *"El P&L ha recuperado, el mercado tiene buen aspecto, el límite solo se tocó brevemente."* El latch elimina esta decisión por completo. Una vez activado, la sesión ha terminado. La regla se estableció antes de que comenzara el día de trading, cuando el juicio era claro — ese pre-compromiso es exactamente lo que impone el latch.

---

## Casos de Uso

**Mesas de trading propietario:** Las firmas que gestionan múltiples traders o estrategias bajo una única cuenta pueden aplicar AccountRiskCore como un circuit breaker diario, garantizando que ninguna sesión individual pueda producir pérdidas catastróficas independientemente de lo que hagan las estrategias individuales.

**Traders sistemáticos individuales:** Un portfolio de estrategias algorítmicas ejecutándose simultáneamente puede sobrepasar los controles de riesgo por operación si múltiples estrategias entran en posiciones grandes en la misma dirección. AccountRiskCore proporciona la red de seguridad final a nivel de cuenta.

**Sesiones de alta volatilidad:** Las publicaciones económicas, anuncios de resultados y eventos geopolíticos pueden producir movimientos rápidos y grandes que superan los supuestos normales de stop por operación. El kill switch a nivel de cuenta proporciona protección en estos escenarios de cola.

**Imposición de disciplina:** Para traders propensos al revenge trading o al sobretrading tras grandes ganancias, el latch mecánico elimina la decisión por completo. El sistema impone las reglas que se establecieron con la cabeza fría antes de que comenzara la sesión.

**Portfolios multi-estrategia:** AccountRiskCore está diseñado para envolver cualquier estrategia sin modificación. Una única instancia puede proteger seguimiento de tendencia en ES, mean reversion en NQ y momentum en CL simultáneamente, tratándolos como un riesgo unificado de cuenta en lugar de riesgos independientes.
