# Trend Reentry — v1.0 & v2.0

## Descripción de la Estrategia

Trend Reentry es una estrategia de seguimiento de tendencia solo en largo que utiliza un cruce de medias móviles para identificar el inicio de una tendencia alcista y luego gestiona la posición mediante una arquitectura de dos salidas y múltiples reentradas. En lugar de mantener una única posición a lo largo de todo el movimiento, la estrategia toma un beneficio táctico cuando el precio alcanza un nuevo máximo significativo, y luego reingresa si la tendencia se reanuda — potencialmente múltiples veces dentro de la misma tendencia alcista. La salida final siempre está determinada por el fallo de la tendencia, no por un objetivo de precio, garantizando que la estrategia permanezca en tendencias fuertes todo el tiempo que duren.

---

## Mecánica Central

### 1. Detección de Tendencia

Dos medias móviles simples definen el estado de la tendencia:

```pascal
FastMA = Average(Close, FastLen);   // Por defecto: 13 períodos
SlowMA = Average(Close, SlowLen);   // Por defecto: 21 períodos

BullCross = FastMA Crosses Over SlowMA;   // La tendencia comienza
BearCross = FastMA Crosses Under SlowMA;  // La tendencia termina
```

`BullCross` y `BearCross` son eventos discretos — son `True` únicamente en la barra exacta donde se produce el cruce. Esto significa que la estrategia entra y sale de posiciones basadas en tendencia en el momento de la confirmación, no sobre una condición de estado continuo.

### 2. Entrada Inicial

```pascal
If IsFlat and BullCross Then
Begin
    Buy ("InitLE") Next Bar at Market;
    MoveHigh   = High;
    CanReEnter = False;
End;
```

Ante un cruce alcista de medias, la estrategia abre una posición larga en la siguiente barra a mercado. `MoveHigh` se inicializa al máximo de la barra actual — esto se convierte en el pico acumulado que la estrategia rastrea a lo largo de la operación. `CanReEnter` se establece explícitamente a `False` en la entrada, garantizando que la lógica de reentrada no pueda activarse antes de que se haya producido una salida técnica.

### 3. MoveHigh — Rastreador de Pico Acumulado

Mientras está largo, la estrategia mantiene un máximo acumulado del movimiento del precio:

```pascal
If High > MoveHigh Then
    MoveHigh = High;
```

`MoveHigh` registra el máximo intrabarra más alto alcanzado desde que se abrió la posición (o se reingresó). Sirve como nivel de referencia para la condición de reentrada: tras una salida técnica, la estrategia solo reingresa si el precio supera `MoveHigh` en el buffer de reentrada, confirmando que la tendencia alcista se ha reanudado en lugar de simplemente consolidar.

### 4. Salida Técnica — Toma de Beneficio por Extensión

```pascal
If not CanReEnter and High > Highest(High, ExtensionLen)[1] Then
Begin
    Sell ("ExtLX") Next Bar at Market;
    CanReEnter = True;
End;
```

Mientras está largo y antes de que se haya producido alguna reentrada (`not CanReEnter`), la estrategia monitoriza la aparición de un nuevo máximo más alto durante el período de lookback. `Highest(High, ExtensionLen)[1]` devuelve el máximo más alto de las `ExtensionLen` barras anteriores, desplazado una barra atrás para evitar sesgo de lookahead. Cuando el máximo de la barra actual supera este nivel, el precio ha alcanzado un nuevo extremo significativo — la estrategia toma beneficio y establece `CanReEnter = True`.

Esta salida se denomina deliberadamente `ExtLX` (salida por extensión) en lugar de objetivo de beneficio, porque se activa ante una señal estructural del mercado (nuevo máximo relativo) en lugar de a un nivel de precio fijo.

### 5. Salida Final — Fallo de Tendencia

```pascal
If BearCross Then
Begin
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;
    MoveHigh   = 0;
End;
```

Cuando la MA rápida cruza por debajo de la MA lenta, la tendencia se considera rota independientemente del estado de la posición. La estrategia vende inmediatamente, resetea `CanReEnter` a `False` y `MoveHigh` a cero en preparación para el siguiente ciclo de tendencia.

El bloque `Begin`/`End` que encierra las tres instrucciones es crítico — ver la nota del bug en la sección v1 vs v2 más abajo.

### 6. Lógica de Reentrada

```pascal
If MarketPosition = 0 and CanReEnter
    and High > MoveHigh + ReEntryBuffer Then
    Buy ("ReEntryLE") Next Bar at Market;
```

Tras una salida técnica (`CanReEnter = True`), la estrategia vigila la reanudación de la tendencia. La reentrada requiere tres condiciones simultáneas:

- `MarketPosition = 0`: La estrategia está actualmente flat.
- `CanReEnter = True`: La salida anterior fue una salida técnica de toma de beneficio, no un fallo de tendencia.
- `High > MoveHigh + ReEntryBuffer`: El precio ha superado el pico previo en el importe del buffer, confirmando nuevo impulso alcista en lugar de una consolidación lateral.

Son posibles múltiples reentradas dentro de un único ciclo de tendencia — cada salida técnica reinicia el ciclo sin resetear `CanReEnter`, permitiendo a la estrategia participar en sucesivas extensiones de precio dentro de la misma tendencia alcista.

### 7. Máquina de Estados

```
┌─────────┐
│  FLAT   │
└────┬────┘
     │ FastMA cruza sobre SlowMA
     ▼
┌──────────────┐
│  LARGO ACTIVO│  ← rastreando MoveHigh, monitorizando extensión
└────┬─────────┘
     │ Nuevo máximo más alto en ExtensionLen barras
     ▼
┌──────────────┐
│ SALIDA TÉC.  │  ← beneficio tomado, CanReEnter = True
│ CanReEnter=1 │
└────┬─────────┘
     │ High > MoveHigh + ReEntryBuffer
     ▼
┌──────────────┐
│  REENTRADA   │  ← largo de nuevo, rastreando nuevo MoveHigh
└────┬─────────┘
     │ FastMA cruza bajo SlowMA
     ▼
┌─────────┐
│  FLAT   │  ← tendencia invalidada, CanReEnter = False
└─────────┘
```

La máquina de estados puede ciclar por el bucle LARGO ACTIVO → SALIDA TÉC. → REENTRADA múltiples veces antes de que un BearCross termine la tendencia y devuelva la estrategia a FLAT con todos los flags reseteados.

---

## v1 vs v2: La Diferencia

Las dos versiones implementan la misma lógica de trading. La evolución es estructural y corrige un bug importante presente en ambas versiones tal como fueron escritas originalmente.

### v1 — Funcional pero con un Problema de Ámbito

v1 usa `MarketPosition <= 0` como condición para tanto la entrada inicial como la reentrada, agrupándolas en el mismo bloque:

```pascal
If MarketPosition <= 0 Then
Begin
    If FastAvg Crosses Over SlowAvg Then
        Buy ("InitLE") Next Bar at Market;

    If MarketPosition(1) = 1 and BarsSinceExit(1) >= 1 and ReEnterOK
        and High > MoveHigh + ReEntryPoints Then
        Buy ("ReEnterLE") Next Bar at Market;
End;
```

La lógica de reentrada está mezclada con la lógica de entrada inicial en el mismo bloque, dificultando la lectura de los dos caminos de entrada.

### v2 — Máquina de Estados Explícita y Separación Limpia

v2 separa cada preocupación lógica en su propio bloque con nombre, haciendo los dos caminos de entrada — entrada inicial y reentrada — claramente distintos. Los booleanos con nombre (`IsFlat`, `IsLong`, `BullCross`, `BearCross`, `CanReEnter`) reemplazan las comparaciones inline en todo el código.

### Bug: `Begin`/`End` Ausente en el Bloque BearCross

Ambas versiones tal como fueron escritas originalmente compartían un bug crítico de ámbito en la salida por fallo de tendencia. En EasyLanguage, un `If` sin `Begin`/`End` solo gobierna la **primera instrucción** que le sigue. Cualquier línea posterior se ejecuta incondicionalmente en cada barra donde la condición exterior (`IsLong`) es verdadera.

**Código con bug (v2 original):**

```pascal
If BearCross Then
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;   // ← se ejecuta en CADA barra mientras IsLong = True
    MoveHigh   = 0;       // ← se ejecuta en CADA barra mientras IsLong = True
```

Solo `Sell ("TrendLX")` está condicionado al `BearCross`. Los dos resets de estado que le siguen se ejecutan en cada barra mientras la estrategia está en posición larga — reseteando `CanReEnter` a `False` y `MoveHigh` a `0` continuamente. Esto destruye la lógica de reentrada por completo: `CanReEnter` nunca puede permanecer en `True` el tiempo suficiente para que una reentrada se active, y `MoveHigh` se resetea a cero en cada barra, haciendo el umbral de reentrada inalcanzable.

**Código corregido:**

```pascal
If BearCross Then
Begin
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;
    MoveHigh   = 0;
End;
```

El bloque `Begin`/`End` delimita correctamente las tres instrucciones al evento `BearCross`. Esta es la versión reflejada en el código actual.

**Resumen:**

| | v1.0 | v2.0 (corregida) |
|---|---|---|
| **Lógica de trading** | ✓ | ✓ |
| **Máquina de estados explícita** | — | ✓ (`IsFlat`, `IsLong`, `BullCross`, `BearCross`) |
| **Caminos de entrada separados** | — | ✓ (entrada inicial / reentrada en bloques propios) |
| **`CanReEnter` (vs `ReEnterOK`)** | — | ✓ |
| **Corrección `Begin`/`End` BearCross** | ✗ bug | ✓ corregido |
| **Nombres de variables descriptivos** | `FastAvg`, `ReEnterOK` | `FastMA`, `CanReEnter` |
| **Nombres de parámetros** | `HHExitLen`, `ReEntryPoints` | `ExtensionLen`, `ReEntryBuffer` |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `FastLen` | 13 | Período de la media móvil rápida. Controla la sensibilidad de la señal. |
| `SlowLen` | 21 | Período de la media móvil lenta. Define la referencia de tendencia. |
| `ExtensionLen` | 50 | Período de lookback para detectar un nuevo máximo más alto. Valores más grandes requieren extensiones más significativas antes de activar la salida técnica. |
| `ReEntryBuffer` | $0,10 | Importe de precio por encima de `MoveHigh` requerido para activar una reentrada. Previene reentradas en nuevos máximos marginales. |

**Sobre las relaciones entre parámetros:** `FastLen` debe ser menor que `SlowLen` — si son iguales o están invertidos, la señal de cruce pierde significado. `ExtensionLen` debe ser significativamente mayor que `FastLen` para que la salida por extensión mida un nuevo máximo significativo en relación con el contexto de tendencia. El `ReEntryBuffer` debe calibrarse al tamaño de tick típico del instrumento — $0,10 es apropiado para acciones pero puede necesitar ajuste para futuros.

---

## Escenarios de Operación

### Escenario A — Ciclo Completo: Entrada, Salida Técnica, Reentrada, Salida Final

- FastMA(13) cruza sobre SlowMA(21). `BullCross = True`.
- **Entrada inicial:** Compra a $45,20. `MoveHigh = 45,15`.

**Barras 1–8 (construyendo el movimiento):**
- El precio avanza hasta $46,80. `MoveHigh` se actualiza a $46,80.
- `Highest(High, 50)[1] = $46,50`. High actual $46,80 > $46,50. Salida por extensión activada.
- **Salida técnica:** `Sell ("ExtLX")`. Posición sale a $46,82. `CanReEnter = True`.

**Barras 9–12 (consolidación):**
- El precio retrocede a $46,20. `MarketPosition = 0`, `CanReEnter = True`.
- `High (46,35) < MoveHigh (46,80) + ReEntryBuffer (0,10) = 46,90`. Reentrada no activada.

**Barra 13 (reentrada):**
- El precio empuja hasta $46,95. `High (46,95) > 46,90`. `CanReEnter = True`, `MarketPosition = 0`.
- **Reentrada activada:** Compra a $46,97.

**Barra 20 (fallo de tendencia):**
- FastMA(13) cruza bajo SlowMA(21). `BearCross = True`.
- **Salida final:** `Sell ("TrendLX")`. `CanReEnter = False`. `MoveHigh = 0`. Ciclo completo.

### Escenario B — Fallo de Tendencia Antes de la Salida por Extensión

- Entrada BullCross a $45,20.
- El precio se mueve contra la posición. FastMA cruza bajo SlowMA en la barra 4.
- `BearCross = True`. `Sell ("TrendLX")`. `CanReEnter = False`. `MoveHigh = 0`.
- La salida por extensión nunca se activó. No es posible ninguna reentrada. La estrategia espera un nuevo BullCross.

### Escenario C — Múltiples Reentradas Dentro de una Tendencia

- Entrada BullCross. Salida técnica tras primera extensión. `CanReEnter = True`.
- Reentrada 1 tras superar `MoveHigh + Buffer`.
- Segunda extensión alcanzada. Salida técnica de nuevo. `CanReEnter = True` (sigue).
- Reentrada 2 tras superar nuevo `MoveHigh + Buffer`.
- BearCross finalmente se activa. Salida final. `CanReEnter = False`. Ciclo completo.

La estrategia participó en dos extensiones separadas dentro de la misma tendencia sin mantener nunca más de una posición simultáneamente.

---

## Características Clave

- **Arquitectura de dos salidas:** Una salida técnica captura beneficios en extensiones de precio sin tratarlas como fallos de tendencia; una salida por tendencia cierra la posición solo cuando la estructura de medias confirma que la tendencia alcista ha terminado.
- **Flag `CanReEnter`:** Distingue entre salidas causadas por toma de beneficio (reentrada permitida) y salidas causadas por fallo de tendencia (reentrada bloqueada). Esta es la variable de estado central que habilita el diseño de múltiples reentradas.
- **Rastreador de pico `MoveHigh`:** Un máximo acumulado que registra el mejor precio de la tendencia. Solo se resetea en el fallo de tendencia, preservando el contexto a través de múltiples entradas dentro de la misma tendencia.
- **Sin pirámide:** La estrategia mantiene como máximo una posición larga en cualquier momento. Las reentradas reemplazan las posiciones existentes; no se añaden a ellas.
- **Entradas y salidas por eventos discretos:** Tanto la entrada inicial como la salida por fallo de tendencia se activan por eventos de cruce de medias, no por condiciones de estado continuo.
- **Offset `[1]` en `Highest`:** El lookback para la salida por extensión usa el máximo más alto de la barra anterior, eliminando el sesgo de lookahead en la barra actual.
- **Disciplina de ámbito `Begin`/`End`:** El bloque BearCross requiere delimitadores explícitos para delimitar correctamente los tres resets de estado. Su ausencia es un bug silencioso que deshabilita completamente el mecanismo de reentrada.

---

## Psicología del Trading

Trend Reentry encarna una visión matizada de cómo se mueven realmente las tendencias: **no en línea recta, sino en una serie de impulsos y consolidaciones.** Una estrategia que mantiene posición a través de cada retroceso arriesga devolver ganancias significativas cuando una extensión revierte bruscamente. Una estrategia que sale en cada retroceso pierde el movimiento mayor. Trend Reentry navega entre estos extremos definiendo un evento estructural específico — un nuevo máximo significativo — como disparador para tomar beneficios, manteniendo abierta la puerta a reingresar si la tendencia demuestra que aún tiene momentum.

El flag `CanReEnter` codifica una distinción crucial que los traders discrecionales hacen intuitivamente: *"salí porque la posición se había extendido, no porque la operación estuviera equivocada."* Cuando una posición se cierra por toma de beneficio en un extremo, la tesis original de la operación (la tendencia alcista está intacta) no ha sido invalidada. La reentrada es racional. Cuando una posición se cierra por un cruce bajista de medias, la tesis ha sido invalidada. La reentrada no es racional hasta que aparezca una nueva señal.

La condición `MoveHigh + ReEntryBuffer` para la reentrada también es psicológicamente significativa: exige que el mercado *demuestre* que la tendencia se está reanudando haciendo un nuevo máximo, en lugar de reingresar por esperanza durante una consolidación.

Esta arquitectura refleja cómo se comportan a menudo las tendencias fuertes: un impulso brusco, una consolidación superficial, otro impulso. Trend Reentry está diseñada para participar en cada impulso mientras se aparta durante las consolidaciones — extrayendo valor de la estructura de la tendencia en lugar de simplemente mantener posición a través de toda ella.

---

## Casos de Uso

**Instrumentos:** Principalmente adecuada para instrumentos tendenciales con estructura clara de impulso-consolidación — acciones individuales en fases de momentum, futuros de índices de renta variable (ES, NQ) durante sesiones direccionales, o futuros de materias primas durante movimientos sostenidos. La estrategia es solo en largo, por lo que requiere instrumentos donde las tendencias alcistas sean una parte significativa de la acción del precio.

**Marcos temporales:** La combinación de medias 13/21 funciona en múltiples marcos temporales. En gráficos de 15 minutos captura ciclos de tendencia intradía; en gráficos diarios captura tendencias de varias semanas. `ExtensionLen = 50` debe interpretarse en relación al marco temporal — 50 barras en un gráfico de 5 minutos son aproximadamente cuatro horas de historial de precio; en un gráfico diario son diez semanas.

**Diseño solo en largo:** La estrategia no tiene lado corto. Para un sistema simétrico, podría desarrollarse independientemente una versión solo en corto (entrando en BearCross, saliendo en BullCross, con salidas por extensión en nuevos mínimos) y ejecutarse junto a este componente.

**Combinación con componentes de riesgo:** Trend Reentry gestiona la lógica de entrada y salida técnica pero no tiene stop loss por operación. En producción, combinarla con ATRDollar TrailStop como capa de salida adicional, AccountRiskCore para los límites diarios a nivel de cuenta, y End-of-Day Exit para la gestión del riesgo overnight crea un sistema intradiario completo con múltiples capas de protección.
