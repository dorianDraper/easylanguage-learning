# Opening Gap — Estrategias Direccionales

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Las estrategias direccionales de Opening Gap explotan una tendencia bien documentada del mercado: los gaps entre el rango de cierre de la sesión anterior y la apertura de la sesión actual tienden a rellenarse durante el día. El sistema se divide en dos estrategias independientes — **Opening Gap Down** (operaciones largas) y **Opening Gap Up** (operaciones cortas) — cada una fadeando el gap en una dirección. Ambas comparten la misma mecánica central: un umbral adaptativo a la volatilidad para filtrar gaps significativos, un objetivo de beneficio basado en el tamaño del gap que apunta al relleno completo, y un stop de pérdida basado en el umbral que invalida la operación si el gap se amplía.

Gap Down existe en dos versiones (v1 y v2). Gap Up v1 fue construida con la misma arquitectura que Gap Down v2, por lo que las dos estrategias direccionales son estructuralmente simétricas. Ambas pueden ejecutarse de forma independiente o juntas como un par.

---

## Mecánica Central

### 1. `Open of Next Bar` — Lookahead por Diseño

```pascal
IsNewSession = Date of Next Bar <> Date;
IsGapDown    = Open of Next Bar < GapPrice - GapTest;
```

`Open of Next Bar` accede al precio de apertura de la siguiente barra antes de que ésta haya cerrado. En backtesting esto es técnicamente lookahead — el sistema lee la apertura de mañana antes de que esa barra comience. Sin embargo, este es un patrón de EasyLanguage intencional y correcto para estrategias de entrada en apertura: la orden de entrada es `Next Bar at Market`, que se ejecuta exactamente a ese mismo precio de apertura. El sistema lee la apertura para decidir si entrar, luego entra en esa apertura. No hay ventaja informacional — el precio de ejecución y el precio de detección son la apertura de la misma barra.

`Date of Next Bar <> Date` identifica la última barra de la sesión actual — la barra cuya "siguiente barra" es la primera barra de la sesión siguiente. Aquí es donde se activa la detección del gap.

### 2. Detección del Gap y Umbral

```pascal
GapTest = Median(Range, 50)[1]
```

`GapTest` es el valor de input por defecto — la mediana del rango de barra sobre las últimas 50 barras, desplazada una barra atrás para evitar lookahead. Usar la mediana en lugar del promedio hace el umbral robusto a sesiones atípicas (p. ej. días de resultados, eventos macro) que podrían inflar un promedio. El offset `[1]` garantiza que el umbral se calcule solo sobre barras completadas.

Un gap se considera significativo solo cuando su tamaño supera este umbral:

```pascal
// Gap Down: la apertura está por debajo del mínimo anterior más que GapTest
IsGapDown = Open of Next Bar < GapPrice - GapTest;

// Gap Up: la apertura está por encima del máximo anterior más que GapTest
IsGapUp = Open of Next Bar > GapPrice + GapTest;
```

`GapPrice` por defecto es `Low` para Gap Down y `High` para Gap Up — el límite de la sesión anterior en el lado relevante. Esto hace el umbral relativo: solo califican los gaps que rompen el rango de la sesión anterior en más que el rango mediano.

### 3. Cálculo del Tamaño del Gap

```pascal
// Gap Down (v2):
Gap = GapPrice - Open of Next Bar;   // Cuánto por debajo del mínimo anterior está la apertura

// Gap Up (v1):
Gap = Open of Next Bar - GapPrice;   // Cuánto por encima del máximo anterior está la apertura
```

`Gap` captura la magnitud del movimiento overnight más allá del límite de la sesión anterior. Se usa directamente para establecer el objetivo de beneficio en el nivel exacto donde el gap quedaría completamente rellenado.

### 4. Entrada

```pascal
// Gap Down — entrada larga
If IsNewSession and IsGapDown Then
Begin
    Gap = GapPrice - Open of Next Bar;
    Buy ("GAP LE") Next Bar at Market;
End;

// Gap Up — entrada corta
If IsNewSession and IsGapUp Then
Begin
    Gap = Open of Next Bar - GapPrice;
    SellShort ("GAP SE") Next Bar at Market;
End;
```

La entrada es a mercado en la barra de apertura de la nueva sesión. Sin entrada limitada o stop — la estrategia acepta el precio de apertura como entrada, confiando en que un gap de magnitud suficiente es la señal en sí misma.

### 5. Marco de Doble Salida

Ambas estrategias usan salidas simultáneas de límite y stop colocadas en cada barra mientras hay posición:

```pascal
// Salidas Gap Down (posición larga)
GapExitPxPT = EntryPrice + Gap;      // Gap completamente rellenado → objetivo de beneficio
GapExitPxSL = EntryPrice - GapTest;  // Gap se amplía más → stop de pérdida

Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
Sell ("Stop LX")   Next Bar at GapExitPxSL Stop;

// Salidas Gap Up (posición corta)
GapExitPxPT = EntryPrice - Gap;      // Gap completamente rellenado → objetivo de beneficio
GapExitPxSL = EntryPrice + GapTest;  // Gap se amplía más → stop de pérdida

BuyToCover ("Filled SX") Next Bar at GapExitPxPT Limit;
BuyToCover ("Stop SX")   Next Bar at GapExitPxSL Stop;
```

El objetivo de beneficio se establece exactamente en el nivel de relleno del gap — el precio límite de la sesión anterior (`EntryPrice + Gap` devuelve el precio a `GapPrice`). El stop de pérdida se establece una unidad `GapTest` contra la operación: si el gap se amplía tanto como el umbral de detección, la premisa de la operación se considera inválida.

`SetExitOnClose` proporciona el fallback para backtesting: si ni el límite ni el stop se han ejecutado al final de la sesión, la posición cierra al precio de cierre. En trading en vivo, End-of-Day Exit cumple esta función.

**El objetivo de beneficio y el stop de pérdida son simétricos en distancia en dólares** cuando `Gap = GapTest` — es decir, cuando el gap está exactamente en el umbral. A medida que `Gap` crece por encima de `GapTest`, el objetivo de beneficio se aleja más mientras el stop de pérdida permanece a una unidad `GapTest`, creando un riesgo/beneficio asimétrico que favorece los gaps más grandes.

---

## Gap Down v1 vs v2: La Diferencia

Gap Down v1 es la implementación original. Gap Down v2 refactoriza la misma lógica en booleanos con nombre y bloques separados sin cambiar ningún comportamiento de trading.

### v1 — Compacto e Inline

```pascal
// v1 — toda la detección y entrada inline
If Date of Next Bar <> Date and Open of Next Bar < GapPrice - GapTest Then
Begin
    Buy ("GAP LE") Next Bar at Market;
    Gap = GapPrice - Open Next Bar;   // Nota: sintaxis antigua sin "of"
End;

If MarketPosition = 1 Then
Begin
    GapExitPxPT = EntryPrice + Gap;
    GapExitPxSL = EntryPrice - GapTest;
    Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
    Sell ("Stop LX")   Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;
```

Dos observaciones sobre v1:
- `Open Next Bar` (sin `of`) es la sintaxis antigua de EasyLanguage. Ambas formas son funcionalmente idénticas; v2 usa `Open of Next Bar` de forma consistente.
- El tamaño del gap (`Gap`) se calcula dentro del bloque de entrada junto con la orden de entrada. Funciona pero mezcla la medición de la señal con la ejecución de órdenes en un único bloque.

### v2 — Condiciones con Nombre y Bloques Separados

```pascal
// v2 — detección separada en booleanos con nombre
IsNewSession = Date of Next Bar <> Date;
IsGapDown    = Open of Next Bar < GapPrice - GapTest;

If IsNewSession and IsGapDown Then
Begin
    Gap = GapPrice - Open of Next Bar;
    Buy ("GAP LE") Next Bar at Market;
End;

IsLong = MarketPosition = 1;

If IsLong Then
Begin
    ...salidas...
End;
```

La condición de entrada es ahora una composición de dos booleanos legibles. `IsLong` hace explícita la condición del bloque de salida en lugar de incrustar `MarketPosition = 1` directamente. La separación refleja la arquitectura Señal/Ejecución establecida en todo el repositorio de estrategias.

**Resumen:**

| | Gap Down v1 | Gap Down v2 | Gap Up v1 |
|---|---|---|---|
| **Lógica de trading** | ✓ | ✓ | ✓ (espejo) |
| **Booleanos de sesión/gap con nombre** | — | ✓ | ✓ |
| **Estado `IsLong` / `IsShort`** | — | ✓ | ✓ |
| **Sintaxis `Open of Next Bar`** | `Open Next Bar` | ✓ | ✓ |
| **Bloques de código separados** | — | ✓ | ✓ |

### Gap Up v1 — Simetría Estructural con Gap Down v2

Gap Up v1 fue construida directamente reflejando la arquitectura de Gap Down v2. Cada variable, bloque y convención de nomenclatura es simétrica — `IsGapDown` se convierte en `IsGapUp`, `IsLong` en `IsShort`, `Buy` en `SellShort`, `Sell` en `BuyToCover`, y los cálculos de precio de salida invierten la dirección. La única diferencia estructural es el input por defecto de `GapPrice`: `Low` para Gap Down, `High` para Gap Up.

Esto significa que Gap Up v1 ya está al nivel de estructura de v2 — se beneficia de todas las mejoras de legibilidad de Gap Down v2 sin requerir una versión separada.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Umbral de volatilidad para la significatividad del gap. Solo los gaps que superen este valor activan la entrada. Se adapta automáticamente a la volatilidad reciente del mercado. |
| `GapPrice` | `Low` (Gap Down) / `High` (Gap Up) | Precio de referencia para la detección del gap. El límite de la sesión anterior en el lado relevante. Puede cambiarse a `Close` para detectar gaps desde el cierre anterior en lugar del máximo/mínimo anterior. |

**Sobre la flexibilidad de `GapPrice`:** Usar `High`/`Low` como referencia significa que la estrategia solo se activa cuando la apertura rompe *más allá* del rango de la sesión anterior. Usar `Close` en su lugar detectaría gaps más pequeños que comienzan desde dentro del rango anterior — una señal diferente y más frecuente. La elección del precio de referencia afecta significativamente a la frecuencia de operaciones y al tamaño promedio del gap.

---

## Escenarios de Operación

### Escenario A — Gap Down, Relleno Completo (Objetivo de Beneficio)

- Sesión anterior: Mínimo en 3.975. `GapTest = Median(Range, 50)[1] = 10 pts`.
- Siguiente sesión abre a 3.960. `3.960 < 3.975 − 10 = 3.965`. El gap califica.
- `Gap = 3.975 − 3.960 = 15 pts`. Entrada: Compra a 3.960.
- `GapExitPxPT = 3.960 + 15 = 3.975` (mínimo anterior — gap completamente rellenado).
- `GapExitPxSL = 3.960 − 10 = 3.950` (un umbral por debajo de la entrada).
- A las 10:30 el precio sube hasta 3.975. Objetivo de beneficio ejecutado. Operación sale con +15 pts.

### Escenario B — Gap Down, el Gap se Amplía (Stop de Pérdida)

- Mismo setup: entrada a 3.960. Stop en 3.950. Target en 3.975.
- El precio continúa bajando. A 3.950, el stop se ejecuta. Operación sale con −10 pts.
- El gap se amplió en `GapTest` — el setup se considera invalidado.

### Escenario C — Gap Up, Relleno Completo (Objetivo de Beneficio)

- Sesión anterior: Máximo en 3.995. `GapTest = 10 pts`.
- Siguiente sesión abre a 4.012. `4.012 > 3.995 + 10 = 4.005`. El gap califica.
- `Gap = 4.012 − 3.995 = 17 pts`. Entrada: SellShort a 4.012.
- `GapExitPxPT = 4.012 − 17 = 3.995` (máximo anterior — gap completamente rellenado).
- `GapExitPxSL = 4.012 + 10 = 4.022` (un umbral por encima de la entrada).
- El precio retrocede hasta 3.995. Objetivo de beneficio ejecutado. Operación sale con +17 pts.

### Escenario D — Gap Demasiado Pequeño, Sin Entrada

- Sesión anterior: Mínimo en 3.975. `GapTest = 10 pts`.
- Siguiente sesión abre a 3.968. `3.968 > 3.975 − 10 = 3.965`. El gap no califica.
- `IsGapDown = False`. Sin entrada. La estrategia espera a la siguiente sesión.

---

## Características Clave

- **Umbral adaptativo a la volatilidad:** `Median(Range, 50)[1]` garantiza que el filtro del gap se ajuste automáticamente a las condiciones actuales del mercado — más amplio en períodos volátiles, más estrecho en períodos tranquilos.
- **Objetivo de beneficio en el relleno del gap:** El objetivo de beneficio se establece en el precio exacto donde el gap queda completamente cerrado, alineando la salida con la hipótesis de mean-reversion.
- **Riesgo/beneficio asimétrico para gaps más grandes:** Cuando `Gap > GapTest`, el objetivo de beneficio está más lejos que el stop de pérdida, recompensando proporcionalmente los eventos de gap más grandes y más significativos.
- **Detección con `Open of Next Bar`:** La evaluación del gap ocurre en la última barra de la sesión actual, usando la apertura de la siguiente barra — un patrón de EasyLanguage correcto y eficiente para estrategias de entrada en apertura.
- **Fallback `SetExitOnClose`:** Las posiciones que no han alcanzado ni el objetivo de beneficio ni el stop al final de la sesión se cierran al precio de cierre en backtesting, preservando el realismo de la simulación.
- **Independencia direccional:** Gap Down y Gap Up son archivos de estrategia separados. Cada uno puede aplicarse independientemente para testear el edge direccional, o ambos pueden aplicarse simultáneamente al mismo instrumento para cobertura completa.

---

## Psicología del Trading

Las estrategias Opening Gap encarnan el principio de *los gaps tienden a rellenarse* — una de las tendencias más empíricamente observadas en renta variable y futuros de índices. La lógica es que los gaps overnight frecuentemente representan sobrereacciones: pánico impulsado por noticias, liquidez pre-mercado escasa, o posicionamiento de participantes que no pueden acceder a la sesión regular. Cuando la sesión regular abre con participación completa, el desequilibrio inicial tiende a corregirse a medida que el mercado encuentra el equilibrio.

El umbral adaptativo es el control de riesgo clave. Al exigir que el gap supere la volatilidad mediana reciente, la estrategia filtra los gaps que son simplemente ruido overnight normal — solo actúa sobre gaps que son estructuralmente anómalos en relación al comportamiento reciente. Un gap que duplica el rango mediano es un evento de mercado diferente a un gap que es la mitad del rango mediano.

La doble salida — un límite en el nivel de relleno del gap y un stop a una unidad de umbral de distancia — codifica con precisión la convicción de la estrategia: *"creo que este gap se rellenará, y permaneceré en la operación mientras el gap no se haya ampliado más que el umbral que activó mi entrada."* Si el gap se amplía en `GapTest`, la premisa de la operación queda invalidada — el mercado no está fadeando el gap, lo está extendiendo.

---

## Casos de Uso

**Instrumentos:** Los futuros de índices de renta variable (ES, NQ, YM) son el encaje natural — producen gaps de apertura consistentes y medibles impulsados por el movimiento overnight de futuros, y su liquidez en apertura garantiza que las órdenes a mercado se ejecuten cerca del precio cotizado. Las acciones individuales con trading pre-mercado activo también son candidatas, aunque las tasas de relleno de gap varían más según sector y contexto de noticias.

**Ejecutar ambas direcciones:** Gap Down y Gap Up pueden aplicarse simultáneamente al mismo instrumento. En cualquier día, como máximo uno puede activarse (ambos requieren que la apertura rompa en una dirección). Ejecutar ambos proporciona exposición simétrica al edge de fade de gap independientemente de la dirección en que se forme el gap.

**Despliegue selectivo:** Gap Down solo es apropiado para traders que quieren exposición long de mean-reversion sin riesgo del lado corto. Gap Up solo proporciona exposición short de mean-reversion. Se recomienda testear cada dirección independientemente primero — las tasas de relleno de gap pueden diferir entre el lado alcista y bajista para un instrumento específico.

**Combinación con componentes de riesgo:** Ninguna estrategia tiene salida temporal más allá de `SetExitOnClose`. En trading en vivo, End-of-Day Exit garantiza que las posiciones cierren antes de que termine la sesión si ni el límite ni el stop se han activado. AccountRiskCore proporciona protección de pérdida diaria a nivel de cuenta independientemente del stop por operación.
