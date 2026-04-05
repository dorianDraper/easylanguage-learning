# AccountRiskCore — v2

## Descripción del Sistema

AccountRiskCore v2 es una evolución arquitectónica del sistema v1. La lógica de trading y el comportamiento de protección del riesgo son idénticos — monitorización del P&L diario, límites bidireccionales, mecanismo de latch y kill switch — pero v2 reestructura cómo se consume la función central. En v1, `AccountRiskCore_Function` solo era llamada por la estrategia; los indicadores duplicaban el cálculo del P&L internamente. En v2, los cuatro componentes llaman a la misma función, logrando una verdadera separación de responsabilidades y eliminando toda lógica redundante.

La función también gana un nuevo parámetro de salida (`oWithinLimits`) que expone directamente el booleano de evaluación de límites, de modo que los llamadores ya no necesitan inferir el estado solo a partir del valor de retorno.

AccountRiskCore v2 está compuesto por cuatro componentes, cada uno nombrado con el sufijo `_v2` para identificar su generación dentro del sistema:

| Componente | Tipo | Rol |
|---|---|---|
| `AccountRiskCore_Function_v2` | Función | Cálculo de riesgo centralizado — fuente única de verdad |
| `AccountRiskCore_Strategy_v2` | Estrategia | Impone el halt de trading, latch y kill switch |
| `AccountRiskCore_Alert_v2` | Indicador | Notificación en tiempo real cuando se superan los límites |
| `AccountRiskCore_Monitor_v2` | Indicador | Visualización continua del P&L diario y los límites |

> **Sobre el versionado:** Los componentes llevan el sufijo `_v2` para indicar que pertenecen a la segunda generación del sistema AccountRiskCore, no para distinguir versiones dentro de esta carpeta. Esta convención permite que estrategias e indicadores importen componentes por generación (`AccountRiskCore_Function_v2`) y hace que la evolución futura (v3, v4) sea inequívoca.

> **Sobre la nomenclatura de componentes:** EasyLanguage no permite puntos, espacios ni guiones en los nombres de componentes. La convención de guión bajo se usa en todos los componentes para cumplir las reglas de nomenclatura de TradeStation preservando la legibilidad.

---

## Visión General de la Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│           AccountRiskCore v2 — Arquitectura                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         AccountRiskCore_Function_v2                  │   │
│  │         (Fuente Única de Verdad)                     │   │
│  │  ├─ Recupera equity de inicio de día                 │   │
│  │  ├─ Recupera equity en tiempo real                   │   │
│  │  ├─ Calcula P&L diario          → oDailyNetPL        │   │
│  │  ├─ Evalúa límites              → oWithinLimits      │   │
│  │  └─ Devuelve permiso de trading → True / False       │   │
│  └──────────────────────────────────────────────────────┘   │
│           │               │               │                 │
│           ▼               ▼               ▼                 │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────┐          │
│  │  Strategy_v2 │  │ Monitor_v2 │  │  Alert_v2   │          │
│  │              │  │            │  │             │          │
│  │ Kill switch  │  │ Visualiza  │  │ Notifica    │          │
│  │ Latch        │  │ P&L y      │  │ en ruptura  │          │
│  │ Puerta trade │  │ límites    │  │             │          │
│  └──────────────┘  └────────────┘  └─────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**El cambio arquitectónico clave respecto a v1:** En v1, los indicadores duplicaban la recuperación de equity y el cálculo del P&L internamente porque no podían llamar a la función. En v2, los tres consumidores — estrategia, monitor y alert — llaman directamente a `AccountRiskCore_Function_v2`. Esto significa que la lógica de cálculo del riesgo existe en exactamente un lugar.

**v1 vs v2 de un vistazo:**

| | AccountRiskCore v1 | AccountRiskCore v2 |
|---|---|---|
| Función llamada por la estrategia | ✓ | ✓ |
| Función llamada por los indicadores | ✗ (lógica duplicada) | ✓ |
| Salida `oWithinLimits` | ✗ | ✓ |
| Fuente única de verdad | Parcial | Completa |
| Componentes en la carpeta | 6 (2 funciones, 2 estrategias, 2 indicadores) | 4 (1 de cada) |

---

## Referencia de Componentes

### AccountRiskCore_Function_v2

El núcleo del sistema. Una función EasyLanguage centralizada que gestiona todo el cálculo del riesgo y expone los resultados a través de tres salidas: un valor de retorno, una referencia de P&L y una referencia booleana de estado de límites.

**Firma de la función:**

```pascal
Inputs:
    MaxDailyLoss(numeric),          // Pérdida diaria máxima permitida en dólares
    MaxDailyProfit(numeric),        // Beneficio diario máximo permitido en dólares
    AccountID(string),              // Identificador de cuenta para recuperar la equity
    oDailyNetPL(numericref),        // Salida: P&L diario actual
    oWithinLimits(truefalseref);    // Salida: True si el P&L está dentro de los límites
```

**Lógica interna:**

```pascal
// Recuperar valores de equity
BeginDayEquity = GetBDAccountNetWorth(AccountID);
CurrentEquity  = GetRTAccountNetWorth(AccountID);

// Calcular P&L diario y transmitir salidas
ComputedPL    = CurrentEquity - BeginDayEquity;
oDailyNetPL   = ComputedPL;

// Evaluar límites — resultado expuesto vía oWithinLimits y valor de retorno
oWithinLimits =
    (ComputedPL > -MaxDailyLoss) and
    (ComputedPL <  MaxDailyProfit);

AccountRiskCore_Function_v2 = oWithinLimits;
```

**El nuevo parámetro de salida `oWithinLimits`:**

En v1, la función solo devolvía un booleano a través de su valor de retorno. Los llamadores podían determinar el permiso de trading (`True`/`False`) pero no tenían una variable con nombre para usar en la lógica de color o en condiciones de los indicadores sin realizar cálculos adicionales.

v2 añade `oWithinLimits` como salida `truefalseref` — un booleano pasado por referencia. Esto significa que el componente llamador recibe tanto el valor de retorno como una variable booleana con nombre poblada por la función. Los indicadores de monitor y alert usan `oWithinLimits` directamente para su lógica de color, eliminando cualquier necesidad de que los indicadores realicen su propia evaluación de límites.

**Cambios respecto a las funciones de v1:**

| | Function v1/v2 (carpeta v1) | Function_v2 (esta versión) |
|---|---|---|
| Salida `oDailyNetPL` | ✓ | ✓ |
| Salida `oWithinLimits` | ✗ | ✓ |
| Llamada por indicadores | ✗ | ✓ |
| Nomenclatura de variable interna | `DailyNetPL` / `ComputedDailyPL` | `ComputedPL` (limpio, sin ambigüedad) |

---

### AccountRiskCore_Strategy_v2

La capa de ejecución. Estructuralmente idéntica a `AccountRiskCore_Strategy_v2` en la carpeta v1, con un cambio: llama a `AccountRiskCore_Function_v2` (esta versión) y recibe la salida adicional `WithinLimits`, que está disponible para su uso dentro del bloque contenedor de estrategia si se necesita.

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL,
            WithinLimits);      // Nuevo: recibe estado booleano de límites directamente

    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

If RiskTriggered Then
    AccountTradingAllowed = False;

// Kill switch
If not AccountTradingAllowed Then
Begin
    If IsLong  Then Sell       ("AcctStop_LX") This Bar on Close;
    If IsShort Then BuyToCover ("AcctStop_SX") This Bar on Close;
End;

// Puerta de estrategia
If AccountTradingAllowed Then
Begin
    // Lógica de estrategia aquí
End;
```

El mecanismo de latch (`RiskTriggered`) y el comportamiento de salida `This Bar on Close` se preservan del Strategy_v2 de v1. La diferencia funcional es únicamente la función llamada y la disponibilidad de `WithinLimits` como variable con nombre dentro de la estrategia.

---

### AccountRiskCore_Monitor_v2

El cambio clave en este componente es la eliminación de las llamadas de equity internas. En v1, el monitor calculaba `DailyNetPL` llamando directamente a `GetBDAccountNetWorth` y `GetRTAccountNetWorth`. En v2, llama a `AccountRiskCore_Function_v2` y recibe tanto `DailyNetPL` como `WithinLimits` como salidas:

```pascal
// Monitor v1 — cálculo de equity duplicado
BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
DailyNetPL           = CurrentAccountEquity - BDAccountEquity;
WithinLimits         = DailyNetPL > -MaxDailyLoss and DailyNetPL < MaxDailyProfit;

// Monitor v2 — única llamada a función, todas las salidas recibidas
TradingAllowed =
    AccountRiskCore_Function_v2(
        MaxDailyLoss,
        MaxDailyProfit,
        AccountNumber,
        DailyNetPL,       // Poblado por la función
        WithinLimits);    // Poblado por la función
```

La lógica de plots y color no cambia — `WithinLimits` sigue controlando el cambio de color verde/rojo en Plot1:

```pascal
Plot1(DailyNetPL, "Daily P&L");
Plot2(-MaxDailyLoss, "Max Loss");
Plot3(MaxDailyProfit, "Max Profit");

If WithinLimits Then
    SetPlotColor(1, Green)
Else
    SetPlotColor(1, Red);
```

> **Nota:** `AccountRiskCore_Monitor_v2` no usa `LastBarOnChart` — se ejecuta en cada barra para proporcionar retroalimentación visual continua. Esto significa que `AccountRiskCore_Function_v2` es llamada en cada barra por el monitor, lo cual es el comportamiento correcto: el trabajo del monitor es mostrar siempre el estado actual, no solo en barras vivas.

---

### AccountRiskCore_Alert_v2

Al igual que el monitor, el componente de alerta ahora llama a `AccountRiskCore_Function_v2` en lugar de realizar sus propios cálculos de equity:

```pascal
If LastBarOnChart Then
Begin
    TradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            AccountNumber,
            DailyNetPL,
            WithinLimits);

    If not TradingAllowed Then
        Alert;
End;
```

La alerta conserva el guard `LastBarOnChart` — solo debe activarse en barras vivas, no reproducir datos históricos. La salida `WithinLimits` de la función controla el color de Plot1:

```pascal
Plot1(DailyNetPL, "Daily P&L");
Plot2(0, "Zero");
Plot3(-MaxDailyLoss, "Max Loss");
Plot4(MaxDailyProfit, "Max Profit");

If not WithinLimits Then
    SetPlotColor(1, Red);
```

**Alert vs Monitor — alcance de ejecución:**

| | AccountRiskCore_Alert_v2 | AccountRiskCore_Monitor_v2 |
|---|---|---|
| Guard `LastBarOnChart` | Sí — solo barras vivas | No — cada barra |
| Frecuencia de llamada a función | Una vez por barra viva | Cada barra |
| Activa alerta | Sí | No |
| Visualización histórica | No | Sí |

---

## Parámetros

Los cuatro componentes comparten los mismos tres parámetros, ahora totalmente consistentes en todo el sistema — la inconsistencia de nomenclatura `AccountID` vs `AccountNumber` presente en v1 queda documentada pero persiste en v2:

| Parámetro | Function_v2 | Strategy_v2 | Alert_v2 | Monitor_v2 |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (`AccountID`) | vía `GetAccountID` | ✓ (`AccountNumber`) | ✓ (`AccountNumber`) |

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `MaxDailyLoss` | $5.000 | Pérdida diaria máxima en dólares antes de detener todo el trading. |
| `MaxDailyProfit` | $5.000 | Beneficio diario máximo en dólares antes de detener todo el trading. |
| `AccountID` / `AccountNumber` | `""` | Identificador de cuenta del broker para recuperar valores de equity. |

> **Inconsistencia de nomenclatura pendiente:** La función usa `AccountID` mientras los indicadores usan `AccountNumber`. Ambos se refieren al mismo string de cuenta del broker. Un futuro v3 podría estandarizar esto a un único nombre en todos los componentes.

---

## Comportamiento del Sistema

El comportamiento del sistema es idéntico al de AccountRiskCore v1 Strategy_v2. El cambio arquitectónico no afecta a ningún comportamiento de trading observable — los mismos límites, el mismo latch, el mismo kill switch, el mismo reset de sesión.

### Ejemplo de Día Completo

| Hora | Evento | P&L Diario | Estado |
|---|---|---|---|
| 09:30 | La sesión abre | $0 | Trading permitido |
| 10:15 | Dos operaciones ganadoras | +$3.000 | Dentro de límites — Monitor verde |
| 11:45 | Límite de beneficio alcanzado | +$5.100 | **Límite superado** |
| 11:45 | Kill switch se activa | +$5.100 | Posiciones cerradas, latch activado |
| 11:45 | Alerta se activa | +$5.100 | Notificación sonora/visual |
| 13:00 | Mercado se mueve favorablemente | +$3.800 | Latch se mantiene — sin reentrada |
| 16:00 | Cierre de sesión | +$3.800 | Día protegido |
| 09:30+1 | Nueva sesión | $0 | Todas las variables se resetean |

### Flujo de Información Entre Componentes

| Evento | Function_v2 | Monitor_v2 | Alert_v2 | Strategy_v2 |
|---|---|---|---|---|
| P&L +$2.000 (dentro de límites) | Devuelve True | Verde | — | Trading continúa |
| P&L +$5.200 (ruptura) | Devuelve False | Rojo | Alerta se activa | Cierra posiciones |
| P&L recupera a +$4.000 (con latch) | Devuelve True | Rojo (latch se mantiene) | — | Aún detenido |
| Siguiente sesión | Se resetea | Verde | — | Puede operar |

---

## Características Clave

- **Verdadera fuente única de verdad:** Los cuatro componentes llaman a `AccountRiskCore_Function_v2`. Ningún componente duplica la recuperación de equity ni la evaluación de límites.
- **Salida `oWithinLimits`:** Expone el estado booleano de límites directamente desde la función, eliminando cualquier necesidad de que los llamadores re-evalúen los límites tras recibir el valor de retorno.
- **Código de indicadores simplificado:** Los componentes Monitor y Alert son significativamente más cortos en v2 — cada uno reemplaza seis líneas de cálculo de equity y lógica de límites con una única llamada a función.
- **Garantía de comportamiento consistente:** Como todos los componentes llaman a la misma función, es imposible que evalúen el riesgo de forma diferente. En v1, un error en la lógica duplicada de los indicadores podría haber producido una visualización de estado inconsistente mientras la estrategia se ejecutaba correctamente.
- **Latch y kill switch preservados:** Las protecciones de comportamiento del Strategy_v2 de v1 se mantienen completamente.
- **Mismo comportamiento observable:** Desde una perspectiva de trading, v2 se comporta de forma idéntica a v1. La mejora es arquitectónica, no conductual.

---

## Psicología del Trading

AccountRiskCore v2 no cambia lo que hace el sistema — cambia cómo lo hace. La filosofía de comportamiento descrita en la documentación de v1 aplica en su totalidad: proteger la cuenta primero, imponer límites bidireccionales, prevenir la reentrada mediante el latch, y eliminar la discrecionalidad intrasesión por completo.

Lo que v2 añade es una disciplina arquitectónica que refleja el mismo principio aplicado al código: **eliminar la redundancia, centralizar la verdad.** Un sistema donde cuatro componentes calculan independientemente el mismo valor es un sistema con cuatro puntos potenciales de inconsistencia. v2 colapsa esos cuatro cálculos independientes en uno, del mismo modo que el mecanismo de latch colapsa cuatro potenciales decisiones de reentrada en una única regla.

La salida `oWithinLimits` es una mejora de diseño pequeña pero significativa: en lugar de forzar a los llamadores a inferir el estado de los límites a partir del valor de retorno y luego re-evaluarlo para su propia lógica de visualización, la función simplemente se lo comunica directamente. Menos inferencias, menos potenciales discrepancias entre lo que el sistema está haciendo y lo que está mostrando. En sistemas de gestión del riesgo — como en el trading — la claridad y la consistencia no son preferencias estéticas; son requisitos de seguridad.

---

## Casos de Uso

Idénticos a AccountRiskCore v1. La mejora arquitectónica no cambia la aplicabilidad del sistema — mejora su mantenibilidad y consistencia, lo que importa más cuando se modifican parámetros, se añaden nuevos componentes o se depura un comportamiento inesperado en trading en vivo.

**Cuándo usar v2 sobre v1:**

- **Nuevos despliegues:** v2 debe ser la opción por defecto para cualquier nueva configuración del sistema. La arquitectura es más limpia y mantenible.
- **Extensión del sistema:** Si un nuevo componente necesita mostrar o reaccionar al estado del riesgo de la cuenta, v2 lo hace trivial — llama a la función y recibe todas las salidas. En v1, cada nuevo componente requeriría duplicar el cálculo de equity.
- **Depuración:** Cuando el comportamiento es inesperado, v2 ofrece un único punto de investigación. En v1, las inconsistencias entre la visualización de los indicadores y la ejecución de la estrategia podían requerir revisar tres codebases separadas.

**Cuándo v1 sigue siendo relevante:**

- **Despliegues en vivo existentes:** Si v1 ya está funcionando y rindiendo correctamente, migrar a v2 a mitad de un despliegue introduce riesgo innecesario. El Strategy_v2 de v1 proporciona todas las protecciones de comportamiento de v2.
- **Compatibilidad con TradeStation:** Si la versión de plataforma en uso tiene alguna restricción para llamar funciones desde indicadores, el enfoque de cálculo independiente de v1 sigue siendo válido.
