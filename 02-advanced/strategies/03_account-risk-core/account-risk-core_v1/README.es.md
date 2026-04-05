# AccountRiskCore — v1

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción del Sistema

AccountRiskCore es un sistema de gestión del riesgo a nivel de cuenta que monitoriza el beneficio y la pérdida diarios en tiempo real y detiene automáticamente toda actividad de trading cuando se superan límites predefinidos. No es una estrategia de trading — es un wrapper de protección dentro del cual puede vivir cualquier estrategia. El sistema evalúa la equity de la cuenta de forma continua, proporciona monitorización visual y alertas sonoras, y cierra mecánicamente todas las posiciones abiertas en el momento en que se cruza un umbral de riesgo.

El sistema impone dos límites simétricos: una pérdida diaria máxima (protección a la baja) y un beneficio diario máximo (disciplina al alza). Una vez que se supera cualquiera de los dos límites, un mecanismo de latch garantiza que el trading no pueda reanudarse durante el resto de la sesión — incluso si el P&L recupera y vuelve dentro de los límites.

AccountRiskCore v1 está compuesto por seis componentes organizados en dos pares versionados más dos indicadores compartidos:

| Componente | Tipo | Rol |
|---|---|---|
| `AccountRiskCore_Function_v1` | Función | Lógica central de evaluación del riesgo (v1) |
| `AccountRiskCore_Function_v2` | Función | Lógica central de evaluación del riesgo (v2, estructura mejorada) |
| `AccountRiskCore_Strategy_v1` | Estrategia | Impone el halt de trading y cierra posiciones (llama a Function v1) |
| `AccountRiskCore_Strategy_v2` | Estrategia | Impone el halt de trading con mecanismo de latch (llama a Function v2) |
| `AccountRiskCore_Alert` | Indicador | Notificación en tiempo real cuando se superan los límites |
| `AccountRiskCore_Monitor` | Indicador | Visualización continua del P&L diario y los límites |

> **Sobre la nomenclatura de componentes:** EasyLanguage no permite puntos, espacios ni guiones en los nombres de componentes. La convención de guión bajo (`AccountRiskCore_Strategy_v1`) se usa en todos los componentes para mantener la legibilidad cumpliendo las reglas de nomenclatura de TradeStation.

---

## Visión General de la Arquitectura

Los componentes comparten un principio de diseño común: **un único cálculo, múltiples consumidores.** La lógica de P&L diario y evaluación de límites vive en la capa de funciones. Cada versión de estrategia llama a su correspondiente versión de función. Los dos indicadores replican el mismo cálculo del P&L de forma independiente, porque los indicadores de EasyLanguage no pueden llamar a funciones de estrategia.

```
AccountRiskCore_Function_v1 ──► AccountRiskCore_Strategy_v1
AccountRiskCore_Function_v2 ──► AccountRiskCore_Strategy_v2

AccountRiskCore_Alert    (cálculo de P&L independiente — solo barras en tiempo real)
AccountRiskCore_Monitor  (cálculo de P&L independiente — todas las barras)
```

El emparejamiento estrategia/función es explícito por diseño: estrategia v1 con función v1, estrategia v2 con función v2. Esto mantiene cada versión autocontenida e independientemente testable.

> **Limitación arquitectónica en v1:** Los indicadores no llaman a ninguna función — duplican el cálculo del P&L internamente. Esta redundancia es la principal brecha arquitectónica que AccountRiskCore v2 aborda refactorizando en una única utilidad compartida invocable por todos los componentes.

---

## Referencia de Componentes

### AccountRiskCore_Function_v1 y AccountRiskCore_Function_v2

El núcleo del sistema. Una función EasyLanguage reutilizable que recupera la equity de la cuenta en tiempo real, calcula el P&L del día, lo compara con los límites configurados y devuelve un booleano indicando si el trading está permitido.

**Firma de la función (idéntica en ambas versiones):**

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
BeginDayEquity = GetBDAccountNetWorth(AccountID);   // Equity de inicio de sesión
CurrentEquity  = GetRTAccountNetWorth(AccountID);   // Equity en tiempo real

// Calcular y transmitir P&L diario
DailyNetPL  = CurrentEquity - BeginDayEquity;       // Variable interna v1
oDailyNetPL = DailyNetPL;                           // Pasar al llamador por referencia

// Evaluar límites y devolver booleano
If DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit Then
    AccountRiskCore_Function_v1 = True    // Trading permitido
Else
    AccountRiskCore_Function_v1 = False;  // Trading bloqueado
```

**Decisiones de diseño clave:**
- `GetBDAccountNetWorth` recupera la equity de inicio de día — una instantánea tomada en la apertura de sesión. Esto garantiza que el P&L diario se resetee limpiamente en cada sesión independientemente de la equity de cierre del día anterior.
- `GetRTAccountNetWorth` recupera la equity en tiempo real, reflejando todo el P&L abierto y cerrado de la sesión actual.
- `oDailyNetPL` usa `numericref` — un parámetro de salida por referencia — permitiendo al llamador recibir el valor de P&L calculado sin hacer una segunda llamada de equity.
- La función devuelve su resultado asignando el booleano a su propio nombre (`AccountRiskCore_Function_v1 = True`), que es el patrón estándar de EasyLanguage para los valores de retorno de funciones.

**v1 vs v2 — la diferencia:**

Ambas versiones implementan lógica idéntica. La evolución es puramente estructural:

| | Function v1 | Function v2 |
|---|---|---|
| Variable interna de P&L | `DailyNetPL` — visualmente próxima al parámetro de salida `oDailyNetPL`, posible confusión | `ComputedDailyPL` — nombre distinto, sin ambigüedad |
| Organización del código | Comentarios inline | Bloques separados etiquetados |
| Legibilidad | Funcional | Autodocumentada |

```pascal
// v1 — nombre de variable interna próximo al parámetro de salida
Vars: DailyNetPL(0);
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;

// v2 — variable interna distinta, sin riesgo de confusión
Vars: ComputedDailyPL(0);
ComputedDailyPL = CurrentEquity - BeginDayEquity;
oDailyNetPL     = ComputedDailyPL;
```

`AccountRiskCore_Function_v2` es la versión recomendada y la que llama `AccountRiskCore_Strategy_v2`.

---

### AccountRiskCore_Strategy_v1 y AccountRiskCore_Strategy_v2

La capa de ejecución. Cada versión de estrategia llama a su correspondiente función, impone la puerta de permiso de trading, cierra todas las posiciones abiertas cuando se superan los límites, y proporciona un bloque vacío donde puede colocarse cualquier lógica de trading.

**Strategy v1 — puerta básica:**

```pascal
// Evaluar riesgo de cuenta solo en barras vivas; por defecto permitido en barras históricas
If LastBarOnChart Then
    AccountTradingAllowed =
        AccountRiskCore_Function_v1(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL)
Else
    AccountTradingAllowed = True;

// Kill switch — salir de todas las posiciones si el trading no está permitido
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

**Strategy v2 — mecanismo de latch:**

v1 tiene una brecha crítica: `AccountTradingAllowed` se re-evalúa en cada barra viva. Si el P&L recupera y vuelve dentro de los límites tras una ruptura — por ejemplo, un movimiento favorable en una posición abierta antes de que el kill switch se ejecute completamente — el flag podría volver a `True` en la siguiente barra y re-habilitar el trading. Esto anula el propósito de un stop diario fijo.

v2 introduce `RiskTriggered`, un latch booleano que, una vez establecido a `True`, mantiene `AccountTradingAllowed` permanentemente en `False` durante el resto de la sesión independientemente del movimiento posterior del P&L:

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL);

    // Latch: una vez activado, no puede resetearse dentro de la sesión
    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

// Aplicar estado del latch — anula cualquier recuperación posterior de AccountTradingAllowed
If RiskTriggered Then
    AccountTradingAllowed = False;
```

v2 también cambia la salida del kill switch de `Next Bar at Market` a `This Bar on Close`, eliminando el retraso de una barra:

```pascal
// v1 — salida en la siguiente barra (una barra de exposición adicional tras la ruptura)
Sell ("AcctStop_LX") Next Bar at Market;

// v2 — salida en el cierre de la barra actual (misma barra que la detección de ruptura)
Sell ("AcctStop_LX") This Bar on Close;
```

**Resumen Strategy v1 vs v2:**

| | Strategy v1 | Strategy v2 |
|---|---|---|
| Función llamada | `AccountRiskCore_Function_v1` | `AccountRiskCore_Function_v2` |
| Mecanismo de latch | Ninguno — re-evalúa cada barra | Flag `RiskTriggered` cierra permanentemente |
| Timing del kill switch | Siguiente barra a mercado | Misma barra al cierre |
| Re-habilitación tras ruptura | Posible si el P&L recupera | Imposible — el latch se mantiene |
| Estructura del código | Bloques inline | Bloques separados etiquetados |

---

### AccountRiskCore_Alert

Un indicador en tiempo real que activa una alerta sonora y visual en el momento en que se superan los límites diarios de P&L. Se ejecuta solo en barras vivas (`LastBarOnChart`) para garantizar que usa valores de equity reales en tiempo real en lugar de datos históricos desactualizados.

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
        Alert;
End;
```

**Plots visuales:**

| Plot | Etiqueta | Valor |
|---|---|---|
| Plot1 | Daily P&L | P&L diario actual (se vuelve rojo en ruptura) |
| Plot2 | Zero | Línea de referencia 0 |
| Plot3 | Max Loss | `-MaxDailyLoss` |
| Plot4 | Max Profit | `+MaxDailyProfit` |

Un esquema de color comentado (Olive, Gainsboro, IndianRed, RoyalBlue) está disponible en el código fuente y puede activarse descomentando.

> **Rol:** Alert sirve como capa de aviso temprano — se activa cuando se supera cualquiera de los límites. El cierre efectivo de posiciones es responsabilidad del kill switch en `AccountRiskCore_Strategy_v1` o `_v2`.

---

### AccountRiskCore_Monitor

Un indicador de monitorización continua que calcula y muestra el P&L diario en cada barra — no solo en las barras vivas. A diferencia de `AccountRiskCore_Alert`, Monitor se ejecuta en todas las barras para proporcionar una referencia visual persistente del estado de riesgo diario de la cuenta durante toda la sesión.

```pascal
// Sin guard LastBarOnChart — se ejecuta en cada barra
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
| Plot1 | Daily P&L | Verde dentro de límites, rojo en ruptura |
| Plot2 | Max Loss | Límite `-MaxDailyLoss` |
| Plot3 | Max Profit | Límite `+MaxDailyProfit` |

Una línea cero comentada (Plot4) y un esquema de color explícito (Darkgreen, Darkred, Cyan, Darkgray) están disponibles para activación.

**Alert vs Monitor — cuándo usar cada uno:**

| | AccountRiskCore_Alert | AccountRiskCore_Monitor |
|---|---|---|
| Ejecución | Solo barras vivas | Cada barra |
| Propósito principal | Notificación | Visualización |
| Activa alerta | Sí | No |
| Visualización histórica | No | Sí |
| Útil en backtesting | No | Sí (revisión visual) |

En trading en vivo, ambos deben estar activos simultáneamente: Monitor proporciona el dashboard visual continuo, Alert proporciona la notificación en tiempo real cuando se requiere acción.

---

## Parámetros

| Parámetro | Function v1/v2 | Strategy v1/v2 | Alert | Monitor |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (como `AccountID`) | vía `GetAccountID` | ✓ (como `AccountNumber`) | ✓ (como `AccountNumber`) |

> **Sobre `AccountID` vs `AccountNumber`:** Las funciones reciben la identidad de cuenta como un string input llamado `AccountID`; las estrategias lo recuperan automáticamente vía `GetAccountID` en tiempo de ejecución; los indicadores lo aceptan como un string input llamado `AccountNumber`. Todos se refieren al mismo identificador de cuenta del broker. Esta inconsistencia de nomenclatura entre componentes es un artefacto de diseño de v1.

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `MaxDailyLoss` | $5.000 | Pérdida diaria máxima en dólares antes de detener todo el trading. |
| `MaxDailyProfit` | $5.000 | Beneficio diario máximo en dólares antes de detener todo el trading. |
| `AccountID` / `AccountNumber` | `""` | Identificador de cuenta del broker para recuperar valores de equity. |

---

## Comportamiento del Sistema

### Estado Normal de Trading

- La sesión abre. `GetBDAccountNetWorth` captura la equity de inicio de día.
- `DailyNetPL = 0`. Ambos límites inactivos.
- Monitor muestra el P&L dentro de la banda verde `[-MaxDailyLoss, +MaxDailyProfit]`.
- `AccountTradingAllowed = True`. Cualquier estrategia dentro de la puerta se ejecuta con normalidad.

### Secuencia de Ruptura de Límite

1. El P&L diario alcanza o cruza cualquiera de los límites (pérdida o beneficio).
2. La función correspondiente devuelve `False`.
3. **Strategy v1:** `AccountTradingAllowed = False`. El kill switch coloca órdenes de salida para la siguiente barra a mercado.
4. **Strategy v2:** `AccountTradingAllowed = False`. `RiskTriggered = True` (latch activado). El kill switch cierra posiciones en el cierre de esta barra.
5. `AccountRiskCore_Alert` activa notificación sonora/visual.
6. Monitor cambia Plot1 a rojo.

### Resto de la Sesión

- **v1:** `AccountTradingAllowed` podría teóricamente recuperar `True` si el P&L vuelve dentro de los límites — la brecha conocida de v1.
- **v2:** `RiskTriggered = True` mantiene `AccountTradingAllowed = False` permanentemente independientemente del movimiento posterior del P&L.
- Monitor permanece en rojo. Alert permanece activo como recordatorio.

### Siguiente Sesión

- Todas las variables de EasyLanguage se resetean entre sesiones. `RiskTriggered` vuelve a `False`.
- `GetBDAccountNetWorth` captura la nueva equity de inicio de día.
- El sistema evalúa desde cero con P&L diario en 0.

### Ejemplo de Día Completo

| Hora | Evento | P&L Diario | Estado |
|---|---|---|---|
| 09:30 | La sesión abre | $0 | Trading permitido |
| 10:15 | Dos operaciones ganadoras | +$3.000 | Dentro de límites |
| 11:45 | Límite de beneficio alcanzado | +$5.100 | **Límite superado** |
| 11:45 | Kill switch se activa | +$5.100 | Posiciones cerradas, latch activado (v2) |
| 13:00 | Mercado se mueve favorablemente | +$3.800 | Latch se mantiene — sin reentrada (v2) |
| 16:00 | Cierre de sesión | +$3.800 | Día protegido |
| 09:30+1 | Nueva sesión | $0 | Sistema se resetea |

---

## Características Clave

- **Protección a nivel de cuenta:** La gestión del riesgo opera a nivel de cuenta, no a nivel de operación. Un único sistema protege todas las estrategias que se ejecutan simultáneamente en la misma cuenta.
- **Límites bidireccionales:** Se imponen tanto el tope de pérdida como el de beneficio. El tope de beneficio previene el sobretrading en días fuertes y consolida resultados excepcionales.
- **Garantía de latch (v2):** Una vez establecido `RiskTriggered`, el kill switch no puede re-habilitarse dentro de la sesión por ningún medio.
- **Salida inmediata (v2):** `This Bar on Close` sale en la misma barra que activa la ruptura, eliminando el retraso de una barra de v1.
- **Pares función/estrategia versionados:** Cada versión de estrategia llama a su propia versión de función, manteniendo las dos implementaciones autocontenidas e independientemente testables.
- **Evaluación en tiempo real:** Ambas estrategias usan `LastBarOnChart` para garantizar que solo los valores de equity en vivo guían las decisiones de riesgo. Las barras históricas por defecto a `AccountTradingAllowed = True` para preservar la compatibilidad con backtesting.
- **Agnóstico a la estrategia:** Cualquier estrategia de trading puede colocarse dentro del bloque `If AccountTradingAllowed Then` sin modificación.
- **Diseño sin discrecionalidad:** El sistema es completamente mecánico. Una vez que el latch se activa, no es posible ninguna anulación dentro de la sesión.

---

## Psicología del Trading

AccountRiskCore encarna un principio rector único: **proteger la cuenta primero, la operación después.**

La mayoría de la gestión del riesgo en trading se centra a nivel de posición — stops de pérdida, sizing de posición, pérdida máxima por operación. Estos son necesarios pero insuficientes. Una estrategia con stops bien definidos por operación puede igualmente producir pérdidas catastróficas en una sesión mediante una secuencia de pérdidas máximas, o sobretradeando una racha ganadora hasta que se revierte. AccountRiskCore opera un nivel por encima: no evalúa operaciones individuales, solo si la cuenta en su conjunto permanece dentro de los límites diarios aceptables.

El tope de beneficio es psicológicamente contraintuitivo. Detener el trading tras un día fuerte parece dejar dinero sobre la mesa. El razonamiento es el opuesto: un día con +$5.000 en P&L es un día que vale la pena proteger. Los mercados que dan generosamente por la mañana frecuentemente recuperan de forma agresiva por la tarde. El tope de beneficio no es pesimismo — es el reconocimiento de que los días excepcionales son escasos y vale la pena consolidarlos intactos.

El mecanismo de latch aborda una trampa psicológica específica: la tentación de racionalizar la reentrada tras una ruptura de límite. *"El P&L ha recuperado, el mercado tiene buen aspecto, el límite solo se tocó brevemente."* El latch elimina esta decisión por completo. Una vez activado, la sesión ha terminado. La regla se estableció antes de que comenzara el día de trading, cuando el juicio era claro — ese pre-compromiso es exactamente lo que impone el latch.

---

## Casos de Uso

**Mesas de trading propietario:** Las firmas que gestionan múltiples traders o estrategias bajo una única cuenta pueden aplicar AccountRiskCore como un circuit breaker diario, garantizando que ninguna sesión individual produzca pérdidas catastróficas independientemente de lo que hagan las estrategias individuales.

**Traders sistemáticos individuales:** Un portfolio de estrategias algorítmicas ejecutándose simultáneamente puede sobrepasar los controles de riesgo por operación si múltiples estrategias entran en posiciones grandes en la misma dirección. AccountRiskCore proporciona la red de seguridad final a nivel de cuenta.

**Sesiones de alta volatilidad:** Las publicaciones económicas, anuncios de resultados y eventos geopolíticos pueden producir movimientos rápidos que superan los supuestos normales de stop por operación. El kill switch a nivel de cuenta proporciona protección en estos escenarios de cola.

**Imposición de disciplina:** Para traders propensos al revenge trading o al sobretrading tras grandes ganancias, el latch mecánico elimina la decisión por completo. El sistema impone las reglas que se establecieron con la cabeza fría antes de que comenzara la sesión.

**Portfolios multi-estrategia:** Una única instancia de AccountRiskCore envuelve cualquier combinación de estrategias — seguimiento de tendencia en ES, mean reversion en NQ, momentum en CL — tratándolos como una exposición de cuenta unificada en lugar de riesgos independientes.
