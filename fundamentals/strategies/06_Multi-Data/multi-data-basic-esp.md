# Multi-Data (Básico) — v1.0

## Descripción de la Estrategia

Multi-Data Básico es una estrategia de seguimiento de tendencia solo en largo que usa dos series de datos del mismo instrumento en distintos timeframes para confirmar las entradas. El timeframe primario (Data1) proporciona la señal de ejecución; el timeframe secundario (Data2) proporciona el filtro de contexto tendencial. Una posición larga se establece cuando el precio está por encima de su media móvil en ambos timeframes simultáneamente — confirmando que el momentum a corto y largo plazo están alineados. Cuando cualquiera de las condiciones falla, la posición se cierra.

Esta es una versión fundacional diseñada para introducir el concepto multi-timeframe en su forma más simple. Comparte la misma idea central que la más sofisticada Multi-Data Strategy v1–v4 documentada en otro lugar de este repositorio, pero sin máquinas de estado, eventos discretos de cruce, lógica de reentrada o variables de señal con nombre.

---

## Mecánica Central

### 1. Cálculo Dual de Medias Móviles

```pascal
MAD1 = Average(Close Data1, MALenD1);
MAD2 = Average(Close Data2, MALenD2);
```

Cada media móvil se calcula sobre su propia serie de datos de forma independiente:

- `Average(Close Data1, MALenD1)`: media móvil simple de los cierres de Data1 durante `MALenD1` barras. Data1 es el primario — el timeframe operativo donde se ejecutan entradas y salidas.
- `Average(Close Data2, MALenD2)`: media móvil simple de los cierres de Data2 durante `MALenD2` barras. Data2 es el secundario — el timeframe superior que proporciona el contexto tendencial.

La sintaxis `Close Data1` y `Close Data2` especifica explícitamente qué serie de datos usar para el cálculo. Cada media vive en su propio universo temporal — una media de 20 barras en barras de 5 minutos y una de 50 barras en barras de 60 minutos se calculan de forma independiente y no se influyen mutuamente. Este es un análisis multi-timeframe genuino: la estrategia lee dos vistas estructuralmente diferentes del mismo instrumento simultáneamente.

> **Sobre la configuración Data1 vs Data2 en TradeStation:** Data1 es siempre el gráfico principal al que se aplica la estrategia. Data2 debe añadirse como segunda serie de datos en el diálogo Format Symbols del gráfico, típicamente configurada como el mismo instrumento en un timeframe superior (p. ej. Data1 = ES 5-min, Data2 = ES 60-min). Sin Data2 configurado, la estrategia producirá un error o resultados inesperados.

### 2. Lógica de Entrada y Salida

```pascal
If Close > MAD1 and Close Data2 > MAD2 Then
    Buy Next Bar at Market
Else
    Sell Next Bar at Market;
```

**Condición de entrada:** Ambas condiciones deben ser verdaderas simultáneamente:
- `Close > MAD1`: el precio de cierre actual en Data1 está por encima de su media — el precio está en una posición localmente alcista respecto al historial reciente.
- `Close Data2 > MAD2`: el precio de cierre en Data2 está por encima de su media — el contexto tendencial del timeframe superior también es alcista.

Ambas condiciones imponen el principio de doble filtro: *"solo voy largo cuando el corto plazo y el largo plazo apuntan en la misma dirección."* Si el precio está por encima de MAD1 pero Data2 está por debajo de MAD2 — o viceversa — ninguna condición por sí sola es suficiente.

**El `Else Sell` — no es una salida simétrica:**

La rama `Else` se activa en cada barra donde la condición de entrada es falsa. `Sell Next Bar at Market` cierra cualquier posición larga existente. Sin embargo, **no** abre una posición corta — `Sell` en EasyLanguage solo sale de un largo existente; no crea un nuevo corto. Si la estrategia está flat cuando la condición es falsa, la orden de venta se envía pero la plataforma la ignora porque no hay posición larga que cerrar.

Esto significa que el `Else` genera una orden de venta en cada barra donde las condiciones no se cumplen — incluyendo barras donde la estrategia ya está flat. Esto es arquitectónicamente ruidoso: EasyLanguage lo gestiona correctamente, pero el registro de órdenes muestra actividad de venta constante incluso cuando no hay posición abierta. La formulación más limpia, usada en las versiones más avanzadas de Multi-Data, hace la salida condicional:

```pascal
// Alternativa más limpia — comprobación explícita de posición
If MarketPosition = 1 Then
    Sell Next Bar at Market;
```

Esta es una nota de diseño para versiones futuras, no un bug en la implementación actual.

---

## Estado Continuo vs Evento Discreto

Una característica fundamental de esta versión es que la condición de entrada es un **estado continuo**: `Close > MAD1` se evalúa en cada barra y permanece verdadera mientras el precio esté por encima de la media móvil. Esto significa que la orden `Buy` se coloca en cada barra donde ambas condiciones se cumplen — no solo en el momento del cruce.

La gestión de posiciones de EasyLanguage evita entradas duplicadas (no puedes ir largo si ya estás largo), por lo que en la práctica solo hay una posición abierta en cualquier momento. Pero la señal de entrada se activa continuamente mientras las condiciones son favorables, lo que puede causar reentradas inmediatas tras una salida si las condiciones siguen cumpliéndose en la barra siguiente.

Esto contrasta con el enfoque de evento discreto de cruce usado en Multi-Data Strategy v3/v4, donde `Close Crosses Over MAData1` solo se activa en la barra exacta del cruce. El enfoque de estado continuo es más simple de escribir y entender, pero genera más ruido de señal en tendencias sostenidas.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `MALenD1` | 20 | Período de la media móvil para el timeframe primario (Data1). Controla la sensibilidad de entrada. |
| `MALenD2` | 50 | Período de la media móvil para el timeframe secundario (Data2). Controla la sensibilidad del filtro tendencial. |

**Sobre el dimensionamiento de parámetros:** La relación entre `MALenD1` y `MALenD2` importa más que los valores absolutos. `MALenD2` debe representar un contexto tendencial significativamente más largo que `MALenD1`. Una configuración inicial típica: Data1 = barras de 5-min con `MALenD1 = 20` (100 minutos de contexto), Data2 = barras de 60-min con `MALenD2 = 50` (50 horas de contexto). Las dos medias operan en timeframes diferentes, por lo que sus períodos absolutos no son directamente comparables.

---

## Escenarios de Operación

### Escenario A — Ambas Condiciones Cumplidas, Entrada Larga

- Data1 (ES 5-min): Cierre en 4.985. MAD1 en 4.978. `Close > MAD1` ✓
- Data2 (ES 60-min): Cierre en 4.990. MAD2 en 4.975. `Close Data2 > MAD2` ✓
- Ambas condiciones verdaderas → `Buy Next Bar at Market`. Se abre posición larga.
- La posición permanece abierta mientras ambas condiciones sigan siendo verdaderas.

### Escenario B — Filtro Data2 Rechaza la Entrada

- Data1 (ES 5-min): Cierre en 4.985. MAD1 en 4.978. `Close > MAD1` ✓
- Data2 (ES 60-min): Cierre en 4.960. MAD2 en 4.975. `Close Data2 > MAD2` ✗
- El filtro Data2 falla → rama `Else` se activa. Si largo: `Sell Next Bar at Market`. Si flat: orden de venta enviada pero ignorada.
- No se abre posición larga a pesar de que Data1 es alcista.

### Escenario C — Largo Cerrado por Fallo de la Condición Data1

- Posición larga abierta. Data2 sigue siendo alcista.
- Data1: Cierre cae a 4.970. MAD1 en 4.978. `Close > MAD1` ✗
- Condición de entrada falsa → `Else Sell` se activa. La posición larga se cierra.
- La posición sale aunque el timeframe superior (Data2) sigue siendo favorable.

### Escenario D — Flat con Condiciones Falsas (Órdenes Sell Ruidosas)

- La estrategia está flat. Ambas condiciones falsas.
- `Else Sell` se activa. Orden enviada a la plataforma. La plataforma la ignora — no hay largo que cerrar.
- El mismo comportamiento se repite en cada barra mientras está flat y las condiciones son falsas.
- Esto ilustra el ruido arquitectónico del `Else Sell` incondicional.

---

## Características Clave

- **Análisis multi-timeframe genuino:** Cada media móvil se calcula de forma independiente sobre su propia serie de datos. Los dos timeframes proporcionan vistas estructuralmente diferentes de la tendencia del mismo instrumento — no una aproximación visual.
- **Requisito de doble confirmación:** Tanto Data1 como Data2 deben ser alcistas simultáneamente. Un Data1 alcista con un Data2 bajista — o viceversa — no activa una entrada, imponiendo el principio de doble filtro.
- **Diseño solo en largo:** La estrategia no tiene lado corto. Cuando las condiciones no se cumplen, cierra posiciones largas y espera flat. Esto limita la exposición a una apuesta direccional a la vez.
- **Entrada por estado continuo:** La condición de entrada se re-evalúa en cada barra. La posición permanece abierta mientras las condiciones se mantengan, sin requerir un evento de cruce específico para activarse.
- **`Else Sell` incondicional:** Genera órdenes de venta en cada barra donde las condiciones son falsas, incluyendo barras donde la estrategia está flat. Funcionalmente correcto pero arquitectónicamente ruidoso — una característica de diseño que vale la pena refinar en versiones futuras.

---

## Psicología del Trading

Multi-Data Básico codifica la versión más simple posible de un principio que subyace a la mayoría de los sistemas tendenciales profesionales: **no operes contra el timeframe superior.** La media móvil de Data2 actúa como guardián — cuando el contexto tendencial mayor no es favorable, incluso una señal local favorable en Data1 se suprime.

La lógica es intuitiva: si el gráfico de 60 minutos muestra el precio por debajo de su media móvil, comprar cada vez que el gráfico de 5 minutos supera su media significa luchar contra la tendencia mayor. El requisito de doble confirmación es una forma mecánica de la regla discrecional *"no compres en una tendencia bajista."*

La condición de estado continuo refleja una elección de diseño orientada al aprendizaje: la estrategia permanece larga mientras ambas condiciones son verdaderas, saliendo solo cuando cualquiera falla. Esto es fácil de razonar — si ambas medias van en la misma dirección, mantén; si cualquiera falla, sal. La complejidad de eventos discretos, máquinas de estado y lógica de reentrada viene después. Esta versión establece el concepto antes de añadir sofisticación arquitectónica.

---

## Relación con Multi-Data Strategy v1–v4

Esta versión básica y la Multi-Data Strategy v1–v4 documentada anteriormente en este repositorio comparten el mismo concepto fundacional — confirmación por media móvil en doble timeframe — pero lo implementan a niveles de sofisticación muy diferentes:

| Aspecto | Multi-Data Básico v1 | Multi-Data Strategy v1–v4 |
|---|---|---|
| **Señal de entrada** | Estado continuo (`Close > MA`) | Evento discreto (`Crosses Over`) desde v3 |
| **Guard de posición** | Ninguno | `MarketPosition = 0` explícito desde v2 |
| **Máquina de estados** | Ninguna | `IsLong`, `IsShort`, `ContextBullish` |
| **Lógica de reentrada** | Ninguna | Añadida en v4 |
| **Condición de salida** | `Else Sell` incondicional | `High < MAData1` (barra completa bajo MA) |
| **Largo/corto** | Solo largo | Ambas direcciones |

Multi-Data Básico es el punto de partida conceptual — una prueba de concepto legible para la idea de doble timeframe. Las versiones de Multi-Data Strategy añaden el rigor estructural, la gestión de estado explícita y la lógica de señal refinada necesarios para un sistema de calidad de producción. Leer ambos juntos ilustra el recorrido completo de desarrollo desde el concepto hasta la implementación.

---

## Casos de Uso

**Instrumentos:** Cualquier instrumento líquido disponible en dos timeframes simultáneamente — futuros de índices de renta variable (ES, NQ), acciones individuales, futuros de materias primas y futuros FX. La estrategia requiere la configuración de gráfico multi-data de TradeStation con Data1 y Data2 definidos.

**Combinaciones de timeframes:** Las configuraciones iniciales comunes incluyen Data1 = 5-min / Data2 = 60-min, o Data1 = 15-min / Data2 = diario. El requisito clave es que Data2 represente un contexto tendencial estructuralmente superior — no solo una media móvil más larga en el mismo timeframe.

**Como herramienta de aprendizaje:** Esta versión es más valiosa para entender el concepto multi-timeframe y la mecánica de la sintaxis `Data1`/`Data2` de EasyLanguage antes de trabajar con las versiones más complejas. Ejecutar tanto Multi-Data Básico como Multi-Data Strategy v3 en el mismo gráfico y comparar sus señales de entrada directamente ilustra la diferencia de comportamiento entre la lógica de entrada por estado continuo y por evento discreto de cruce.
