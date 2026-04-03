# Multi-Data Strategy — v1.0 & v2.0

## Descripción de la Estrategia

La Multi-Data Strategy es un sistema de seguimiento de tendencia que combina dos series de datos del mismo instrumento en distintos marcos temporales: un **timeframe operativo** más rápido (Data1) para la ejecución de operaciones, y un **timeframe superior** más lento (Data2) para el contexto tendencial. Las señales de entrada se generan cuando ambos timeframes coinciden en dirección, actuando como un mecanismo de doble filtro para mejorar la calidad de las señales. Las salidas son técnicas, basadas en la posición del precio respecto a la media móvil operativa.

---

## Mecánica Central

La estrategia opera en tres capas bien definidas:

### 1. Confirmación de Contexto (Data2 — Timeframe Superior)

Se calcula una media móvil en el timeframe superior (Data2). Su dirección — ascendente o descendente — determina el contexto de tendencia dominante:

```pascal
MAValData2 = Average(Close, MALenData2) Data2;

// Contexto alcista: la MA sube
MAValData2 > MAValData2[1]

// Contexto bajista: la MA baja
MAValData2 < MAValData2[1]
```

> **Nota sobre sintaxis:** En v1 y v2, la asignación de Data2 utiliza la sintaxis nativa de EasyLanguage `Average(Close, MALenData2) Data2`, que vincula la serie de datos de la función en el momento de la declaración. Es funcionalmente equivalente a `Average(Close of Data2, MALenData2)` utilizado en versiones posteriores, aunque difieren sintácticamente. Ambos enfoques calculan la media sobre la serie de precios de Data2.

### 2. Señal de Entrada (Data1 — Timeframe Operativo)

Se calcula una media móvil sobre Data1. La condición de entrada exige que el **cierre actual esté en el lado correcto de la MA** — por encima para largos, por debajo para cortos — combinado con la confirmación direccional de Data2:

```pascal
MAValData1 = Average(Close, MALenData1);

// Entrada larga: TF superior alcista Y precio por encima de la MA
If MAValData2 > MAValData2[1] and Close > MAValData1 Then
    Buy Next Bar at Market;

// Entrada corta: TF superior bajista Y precio por debajo de la MA
If MAValData2 < MAValData2[1] and Close < MAValData1 Then
    SellShort Next Bar at Market;
```

Esto es una **condición de estado continuo**: la señal se activa en cada barra donde ambas condiciones se cumplen simultáneamente. Esta es una característica de diseño clave de v1 y v2 — ver la sección v1 vs v2 más abajo.

### 3. Salidas Técnicas

La estrategia sale cuando **la barra completa** (High o Low) queda en el lado incorrecto de la MA operativa, indicando que el precio la ha cruzado con claridad:

```pascal
// Salida largo: la barra entera cierra por debajo de la MA
If MarketPosition = 1 Then
    If High < MAValData1 Then
        Sell Next Bar at Market;

// Salida corto: la barra entera cierra por encima de la MA
If MarketPosition = -1 Then
    If Low > MAValData1 Then
        BuyToCover Next Bar at Market;
```

Usar `High < MAValData1` (en lugar de `Close < MAValData1`) exige que **toda la barra** quede por debajo de la media, haciendo las salidas más robustas y filtrando violaciones puntuales intrabarra.

---

## v1 vs v2: La Diferencia Clave

### v1.0 — Sin Control de Posición

En v1 no existe comprobación del estado de la posición antes de enviar órdenes de entrada. Esto crea una **vulnerabilidad potencial de reentrada**: si la estrategia ya está larga y las condiciones siguen siendo verdaderas, podría intentar enviar otra orden de compra en la siguiente barra.

```pascal
// v1 — Condiciones de entrada evaluadas sin restricción
If MAValData2 > MAValData2[1] and Close > MAValData1 Then
    Buy Next Bar at Market;
```

En la práctica, el control de posición de TradeStation evita entradas duplicadas en backtesting, pero esto supone una dependencia implícita del comportamiento de la plataforma en lugar de una decisión de diseño explícita. El código comunica una intención ambigua.

### v2.0 — Control Explícito de Posición

v2 envuelve ambas condiciones de entrada en un chequeo `MarketPosition = 0`. La estrategia ahora declara explícitamente: *"solo entro cuando estoy fuera del mercado."*

```pascal
// v2 — Entrada solo cuando estamos flat
If MarketPosition = 0 Then
Begin
    If MAValData2 > MAValData2[1] and Close > MAValData1 Then
        Buy Next Bar at Market;

    If MAValData2 < MAValData2[1] and Close < MAValData1 Then
        SellShort Next Bar at Market;
End;
```

Es una mejora pequeña pero significativa: el código ahora codifica explícitamente el comportamiento deseado, facilitando su lectura, auditoría y extensión. Es la diferencia entre una regla que dice *"solo una persona en la cabina a la vez"* (v2) frente a confiar en que la cabina es físicamente demasiado pequeña para que entren dos (v1).

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `MALenData1` | 12 | Longitud de la MA para el timeframe operativo (Data1). Controla la sensibilidad de la señal. |
| `MALenData2` | 24 | Longitud de la MA para el timeframe superior (Data2). Controla la sensibilidad del contexto tendencial. |

**Nota de configuración:** Data1 es el gráfico más rápido (período más corto) — el timeframe de ejecución. Data2 es el gráfico más lento (período más largo) — el contexto de tendencia. Una configuración típica sería Data1 = barras de 15 minutos, Data2 = barras de 60 minutos, ambas sobre el mismo instrumento (p. ej. futuros ES).

---

## Escenarios de Operación

### Escenario A — Entrada Larga (Tendencia Alineada)

- Gráfico ES 60-min: MA en 4.985, MA barra anterior en 4.980 → **ContextoBullish = True** (MA subiendo)
- Gráfico ES 15-min: MA en 4.992, cierre actual en 4.995 → **Close > MAValData1 = True**
- Ambas condiciones cumplidas → **Compra en la siguiente barra a mercado**
- Entrada ejecutada a 4.996

**Condición de salida:** Una barra de 15-min cierra con High < 4.992 (barra completa por debajo de la MA) → Venta en la siguiente barra a mercado.

### Escenario B — Señal Rechazada (Contexto Contrario)

- Gráfico ES 60-min: MA cae de 4.990 a 4.985 → **ContextoBullish = False** (MA bajando)
- Gráfico ES 15-min: cierre en 4.995, por encima de MAValData1 en 4.992
- El precio está por encima de la MA pero el contexto es bajista → **No se genera señal de entrada**

Este escenario ilustra el valor del doble filtro: una señal de compra en el timeframe operativo es suprimida por el contexto del timeframe superior.

### Escenario C — Entrada Corta

- Gráfico ES 60-min: MA cae de 4.990 a 4.985 → **ContextoBearish = True**
- Gráfico ES 15-min: cierre en 4.978, por debajo de MAValData1 en 4.982 → **Close < MAValData1 = True**
- Ambas condiciones cumplidas → **Venta corta en la siguiente barra a mercado**
- Entrada ejecutada a 4.977

**Condición de salida:** Una barra de 15-min cierra con Low > 4.982 (barra completa por encima de la MA) → BuyToCover en la siguiente barra a mercado.

---

## Características Clave

- **Confirmación de doble timeframe:** Reduce señales falsas al exigir alineación entre el contexto tendencial (Data2) y la señal de ejecución (Data1). El timeframe superior actúa como filtro de acceso.
- **Lógica de entrada por estado continuo:** En v1/v2, las condiciones de entrada se basan en la posición del precio respecto a la MA, no en el evento de cruce en sí. Esto significa que las señales están activas mientras las condiciones se mantengan, no solo en el momento del cruce.
- **Salidas estrictas basadas en barra completa:** Las condiciones de salida exigen que toda la barra (High o Low) quede en el lado incorrecto de la MA, proporcionando un margen frente al ruido intrabarra puntual.
- **Gestión explícita de posición (v2):** El guard `MarketPosition = 0` hace explícito el estado de posición, evitando intenciones de reentrada ambiguas.
- **Diseño minimalista:** El sistema utiliza solo dos parámetros y no incorpora stops ni targets, manteniéndolo robusto y fácil de testar.

---

## Psicología del Trading

Esta estrategia encarna un principio fundamental del seguimiento de tendencia: **no luchar contra el flujo dominante.** La dirección de la MA en el timeframe superior representa el sesgo predominante del mercado — la "corriente del río". Entrar solo cuando el timeframe operativo se alinea con esa corriente significa operar *a favor* del momentum del mercado, no en su contra.

La condición de estado continuo en v1/v2 refleja una postura firme: *mientras el precio se mantenga por encima de la MA y el contexto tendencial sea alcista, el mercado está señalando continuación.* La lógica de entrada confía en que esta alineación es significativa y actúa en consecuencia.

La lógica de salida es deliberadamente simple y orientada al precio: cuando el precio no consigue mantenerse por encima de la MA operativa durante una barra completa, la premisa de la operación queda invalidada. No hay target, no hay trailing stop, no hay salida temporal — solo la estructura del mercado indicándote que la operación ya no es válida.

La evolución de v1 a v2 también refleja una disciplina de software que espeja la disciplina del trading: **sé explícito con tus reglas.** Una estrategia que depende del comportamiento implícito de la plataforma es como un plan de trading con entradas ambiguas — técnicamente ejecutable, pero frágil y difícil de revisar bajo presión.

---

## Casos de Uso

**Instrumentos:** Los futuros de índices de renta variable (ES, NQ, YM) son candidatos naturales. La estructura de doble timeframe funciona bien en mercados tendenciales con estructura intradía clara. La estrategia también puede aplicarse a futuros CL, GC y FX en sesiones líquidas.

**Combinaciones de timeframes:** Configuraciones habituales incluyen 15-min (Data1) / 60-min (Data2), o 5-min / 15-min para un trading más activo. Lo fundamental es que Data2 represente un contexto estructural superior significativo respecto a Data1.

**Perfil del trader:** Adecuada para traders sistemáticos que construyen un portfolio de estrategias de seguimiento de tendencia. Mejor utilizada como parte de un portfolio de sistemas diversificado que como estrategia aislada, dado su exposición a condiciones laterales y de rango donde la lógica de entrada por estado continuo genera señales falsas con mayor frecuencia.

**Condiciones de mercado:** Rinde mejor en entornos tendenciales con movimientos direccionales sostenidos. Generará whipsaws en mercados laterales — esta es una característica conocida de los sistemas basados en medias móviles y debe cuantificarse en backtesting antes del despliegue.
