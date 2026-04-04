# Opening Gap Bidireccional — v1.0

## Descripción de la Estrategia

Opening Gap Bidireccional consolida la lógica de Opening Gap Down v2 y Opening Gap Up v1 en una única estrategia unificada. En lugar de mantener dos archivos separados — uno para cada dirección — la versión bidireccional usa lógica condicional para detectar qué tipo de gap se forma en la apertura de la sesión y entrar en la operación correspondiente. Toda la mecánica central se preserva: el umbral adaptativo a la volatilidad, el objetivo de beneficio en el relleno del gap, y el stop de pérdida basado en el umbral. Lo que cambia es la arquitectura: un único código, un único conjunto de parámetros, un único archivo que mantener.

La estrategia toma como máximo una operación por sesión, en la dirección en que se produzca el gap. Si tanto un gap alcista como un gap bajista estuvieran teóricamente presentes (lo cual no puede ocurrir simultáneamente), ganaría la primera condición evaluada — en la práctica esto nunca es un problema ya que el precio no puede abrir a la vez por encima del máximo anterior y por debajo del mínimo anterior.

---

## Mecánica Central

### 1. Detección de Sesión y Gap

```pascal
IsNewSession = Date of Next Bar <> Date;

IsGapDown = IsNewSession and Open of Next Bar < Low  - GapTest;
IsGapUp   = IsNewSession and Open of Next Bar > High + GapTest;
```

Ambas condiciones de gap se evalúan simultáneamente en cada barra. `IsNewSession` se calcula una vez y se reutiliza en ambas comprobaciones de gap — una factorización limpia que evita repetir la comparación de fechas. Nótese que en la versión bidireccional, `Low` y `High` se usan directamente (el mínimo y máximo de la barra anterior) en lugar de a través de un parámetro de input `GapPrice` — los precios de referencia están implícitos por la dirección.

Esta es una simplificación sutil pero significativa: las estrategias direccionales exponen `GapPrice` como un input configurable (con valor por defecto `Low` o `High`), permitiendo a los usuarios cambiar a detección de gap desde el cierre cambiando un parámetro. La versión bidireccional hardcodea `Low` y `High` como precios de referencia, sacrificando esa flexibilidad por una interfaz más simple de un solo parámetro.

### 2. Bloque de Entrada Unificado

```pascal
If MarketPosition = 0 Then
Begin
    If IsGapDown Then
    Begin
        Gap = Low - Open of Next Bar;
        Buy ("GAP_LE") Next Bar at Market;
    End;

    If IsGapUp Then
    Begin
        Gap = Open of Next Bar - High;
        SellShort ("GAP_SE") Next Bar at Market;
    End;
End;
```

El guard `MarketPosition = 0` garantiza que solo haya una posición abierta en cualquier momento. Ambas condiciones de gap se evalúan dentro del mismo bloque — la que se active primero (o la única que se active) determina la dirección de la operación para esa sesión. `Gap` se asigna dentro de cada rama con la convención de signo correcta para esa dirección.

### 3. Doble Salida Simétrica

```pascal
// Salida larga (operación Gap Down)
If IsLong Then
Begin
    GapExitPxPT = EntryPrice + Gap;      // Vuelve al mínimo anterior — gap rellenado
    GapExitPxSL = EntryPrice - GapTest;  // Gap se amplía — operación invalidada

    Sell ("GapFill_LX") Next Bar at GapExitPxPT Limit;
    Sell ("GapStop_LX") Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;

// Salida corta (operación Gap Up)
If IsShort Then
Begin
    GapExitPxPT = EntryPrice - Gap;      // Vuelve al máximo anterior — gap rellenado
    GapExitPxSL = EntryPrice + GapTest;  // Gap se amplía — operación invalidada

    BuyToCover ("GapFill_SX") Next Bar at GapExitPxPT Limit;
    BuyToCover ("GapStop_SX") Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;
```

La lógica de salida es estructuralmente idéntica a las estrategias direccionales. `GapExitPxPT` apunta al relleno completo del gap; `GapExitPxSL` invalida la operación si el gap se extiende en `GapTest`. Las etiquetas de orden con nombre (`GapFill_LX`, `GapStop_LX`, `GapFill_SX`, `GapStop_SX`) permiten el análisis de rendimiento por tipo de salida en los informes de TradeStation.

---

## Bidireccional vs Direccional — Comparación de Arquitectura

| | Gap Down v2 | Gap Up v1 | Bidireccional v1 |
|---|---|---|---|
| **Direcciones operadas** | Solo largo | Solo corto | Ambas |
| **`GapPrice` configurable** | ✓ (por defecto `Low`) | ✓ (por defecto `High`) | — (hardcodeado `Low` / `High`) |
| **Parámetros** | 2 (`GapTest`, `GapPrice`) | 2 (`GapTest`, `GapPrice`) | 1 (`GapTest`) |
| **Archivos de código a mantener** | 1 | 1 | 1 (reemplaza a ambos) |
| **Operaciones por sesión** | 0 o 1 (si hay gap bajista) | 0 o 1 (si hay gap alcista) | 0 o 1 (cualquier dirección) |
| **Etiquetas de orden con nombre** | `GAP LE`, `Filled LX` | `GAP SE`, `Filled SX` | `GAP_LE`, `GapFill_LX`, `GAP_SE`, `GapFill_SX` |

El trade-off clave es la configurabilidad de `GapPrice`. Las estrategias direccionales permiten cambiar el precio de referencia de `Low`/`High` a `Close` mediante un único parámetro, habilitando la detección de gap desde el cierre sin cambios en el código. La versión bidireccional hardcodea los precios de referencia, por lo que cambiar a gap desde el cierre requeriría modificar el código directamente. Para la mayoría de los casos de uso esto es aceptable — la versión bidireccional está diseñada para la simplicidad y reducción de mantenimiento, no para la máxima flexibilidad.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Umbral de volatilidad para la significatividad del gap. Los gaps deben superar este valor para activar la entrada. Se adapta automáticamente a las condiciones recientes del mercado. |

La reducción a un único parámetro (frente a dos en cada estrategia direccional) es intencional. `GapPrice` ya no es necesario porque los precios de referencia están implícitos por la dirección de la operación: las operaciones largas siempre referencian `Low`, las operaciones cortas siempre referencian `High`.

---

## Escenarios de Operación

### Escenario A — Sesión con Gap Down: Operación Larga

- Sesión anterior: Mínimo en 3.975, Máximo en 3.995. `GapTest = 10 pts`.
- Siguiente sesión abre a 3.960.
- `IsGapDown`: `3.960 < 3.975 − 10 = 3.965` → `True`.
- `IsGapUp`: `3.960 > 3.995 + 10 = 4.005` → `False`.
- `Gap = 3.975 − 3.960 = 15 pts`. Entrada: Compra a 3.960.
- `GapExitPxPT = 3.975`. `GapExitPxSL = 3.950`.
- El precio sube. Objetivo de beneficio ejecutado a 3.975. Operación sale con +15 pts.

### Escenario B — Sesión con Gap Up: Operación Corta

- Sesión anterior: Máximo en 3.995, Mínimo en 3.975. `GapTest = 10 pts`.
- Siguiente sesión abre a 4.012.
- `IsGapDown`: `4.012 < 3.975 − 10 = 3.965` → `False`.
- `IsGapUp`: `4.012 > 3.995 + 10 = 4.005` → `True`.
- `Gap = 4.012 − 3.995 = 17 pts`. Entrada: SellShort a 4.012.
- `GapExitPxPT = 3.995`. `GapExitPxSL = 4.022`.
- El precio retrocede. Objetivo de beneficio ejecutado a 3.995. Operación sale con +17 pts.

### Escenario C — Sin Gap Significativo

- Siguiente sesión abre a 3.980. Mínimo anterior: 3.975. Máximo anterior: 3.995. `GapTest = 10 pts`.
- `IsGapDown`: `3.980 < 3.965` → `False`.
- `IsGapUp`: `3.980 > 4.005` → `False`.
- Sin entrada. La estrategia espera a la siguiente sesión.

### Escenario D — Stop de Pérdida Activado (Gap se Extiende)

- Sesión con gap bajista. Entrada: Compra a 3.960. `GapExitPxSL = 3.950`.
- El precio continúa bajando por debajo de 3.950. El stop se ejecuta. Operación sale con −10 pts.
- Sin más entradas esa sesión (`MarketPosition` fue distinto de cero cuando el stop se ejecutó; `IsNewSession` solo será verdadero de nuevo en la apertura de la siguiente sesión).

---

## Características Clave

- **Único código base:** Un archivo reemplaza dos, eliminando la carga de mantenimiento de mantener dos estrategias sincronizadas cuando cambian parámetros o lógica.
- **Direccionalidad dinámica:** Sin pre-compromiso con largo o corto — la estrategia reacciona al gap que se forma realmente en cada sesión.
- **Guard `MarketPosition = 0`:** Garantiza como máximo una operación por sesión independientemente de la dirección. Si un gap bajista activa un largo, una señal de gap alcista simultánea (imposible en la práctica pero manejada en el código) sería ignorada.
- **Precios de referencia hardcodeados:** `Low` y `High` como referencias simplifican la superficie de parámetros a un único input preservando la medición correcta del gap para cada dirección.
- **Arquitectura de salida simétrica:** Las salidas largas y cortas comparten la misma estructura, haciendo el código fácil de auditar — las únicas diferencias son las convenciones de signo en los cálculos de precio de salida y los tipos de orden (`Sell` vs `BuyToCover`).
- **Etiquetas de orden con nombre:** `GapFill_LX`, `GapStop_LX`, `GapFill_SX`, `GapStop_SX` permiten el análisis de rendimiento por tipo de salida en los informes de TradeStation.
- **Fallback `SetExitOnClose`:** Las posiciones abiertas al final de la sesión se cierran al precio de cierre en backtesting.

---

## Psicología del Trading

La versión bidireccional encarna una postura de *"operaré el gap que aparezca"*. Las estrategias direccionales requieren una pre-decisión: ¿ejecutar Gap Down, Gap Up, o ambos? La versión bidireccional elimina completamente esa decisión — simplemente observa la apertura y responde a lo que el mercado ofrece.

Esto no es solo una conveniencia de código — refleja una posición filosófica genuina. Un trader que ejecuta solo Gap Down está haciendo una apuesta implícita de que las tasas de relleno de gap bajista son mejores que las alcistas, o que se siente más cómodo con posiciones largas. Un trader que ejecuta la versión bidireccional está diciendo: *"confío en el edge de fade de gap en ambas direcciones y no quiero sesgo direccional en mi exposición."*

La restricción de una operación por sesión impone disciplina: una vez que se determina el tipo de gap de la sesión y se toma la operación, el sistema ha terminado por ese día. No hay segunda opinión, no se añade a la posición, y no se cambia de dirección si la primera operación llega al stop. El gap se rellena o no, y el resultado se acepta.

---

## Cuándo Usar Bidireccional vs Estrategias Direccionales

**Usa Bidireccional cuando:**
- Quieres exposición simétrica al fade de gap en ambas direcciones desde un único archivo.
- Prefieres una superficie de parámetros más simple (un input vs dos).
- Estás cómodo con `Low` y `High` como precios de referencia fijos.
- Estás construyendo un portfolio y quieres un único componente de fade de gap que maneje todos los tipos de gap.

**Usa las estrategias direccionales cuando:**
- Quieres testear el edge de gap alcista y bajista de forma independiente antes de combinarlos.
- Quieres la flexibilidad de cambiar `GapPrice` a `Close` para detección de gap desde el cierre.
- Quieres ejecutar solo una dirección (p. ej. cuenta solo largo con solo Gap Down).
- Necesitas atribución de rendimiento separada para cada dirección de gap.

Ambos enfoques implementan la misma lógica de trading. La elección es arquitectónica — depende de cómo quieres gestionar, monitorizar y evolucionar la estrategia en tu portfolio.
