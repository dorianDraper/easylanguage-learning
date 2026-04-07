# Trendline Entry Strategy — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Trendline Entry Strategy conecta el trading discrecional con el sistemático ejecutando entradas mecánicas contra una línea de tendencia dibujada manualmente en el gráfico. La estrategia lee la posición de la línea de tendencia en tiempo real usando la API de trendlines de TradeStation, proyecta su valor una barra hacia adelante, y coloca una orden límite (cuando el precio ya está en el lado favorable de la línea, buscando un retroceso hacia ella) o una orden stop (cuando el precio está en el lado desfavorable, buscando una ruptura a través de ella). La dirección de trading — largo o corto — se controla mediante el signo del input `TradeSize` en lugar de un parámetro de dirección separado.

La estrategia opera únicamente en la última barra visible del gráfico (`LastBarOnChart`), haciéndola una herramienta de ejecución en tiempo real más que un sistema de backtesting. Está diseñada para traders que dibujan líneas de tendencia como parte de su análisis discrecional y quieren ejecución sistemática y basada en reglas en esos niveles.

---

## Mecánica Central

### 1. API de Trendlines de TradeStation

La estrategia interactúa con objetos de gráfico dibujados manualmente usando tres funciones de trendline de EasyLanguage:

```pascal
TL_Exist(TLID)                          // Devuelve True si la línea de tendencia existe
TL_GetValue(TLID, Date, Time)           // Devuelve el precio de la línea en una barra dada
```

`TLID` es el identificador interno que TradeStation asigna a cada objeto de dibujo en el gráfico. Para usar esta estrategia, el trader debe:

1. Dibujar una línea de tendencia en el gráfico manualmente.
2. Hacer clic derecho en la línea de tendencia y anotar su ID de objeto (visible en las propiedades de la línea o en el panel de Herramientas de Dibujo).
3. Introducir ese ID como el input `TLID`.

Este no es un valor calculado — es una referencia a un objeto dibujado específico. Si la línea de tendencia se elimina y se vuelve a dibujar, TradeStation asigna un nuevo ID y `TLID` debe actualizarse. `TL_Exist(TLID)` proporciona una comprobación de seguridad: la estrategia solo se activa si la línea de tendencia referenciada realmente existe en el gráfico.

### 2. Lectura de la Línea y Cálculo de Pendiente

```pascal
TLCurrent  = TL_GetValue(TLID, Date,    Time);      // Valor en la barra actual
TLPrevious = TL_GetValue(TLID, Date[1], Time[1]);   // Valor en la barra anterior
```

`TL_GetValue` devuelve el nivel de precio de la línea de tendencia en cualquier fecha y hora dada. Leerlo en la barra actual y la barra anterior proporciona dos puntos en la línea — suficientes para determinar su dirección de pendiente (ascendente o descendente) y para proyectar su valor hacia adelante.

La pendiente no se almacena como una variable explícita sino que está integrada en la fórmula de proyección.

### 3. Proyección Lineal — Dónde Estará la Línea en la Siguiente Barra

```pascal
TLProjected = TLCurrent + (TLCurrent - TLPrevious);
```

Esto extrapola la línea de tendencia una barra hacia el futuro asumiendo pendiente constante. El razonamiento:

- `TLCurrent - TLPrevious` = el cambio de precio de la línea por barra (su pendiente).
- Añadir esta pendiente a `TLCurrent` estima el valor de la línea en la siguiente barra.

Para una línea de tendencia recta esto es exacto por definición — una línea recta tiene pendiente constante, por lo que la proyección siempre es correcta. El valor proyectado es donde se colocan las órdenes límite o stop, garantizando que las entradas apunten a la posición futura de la línea más que a su posición actual. Esto importa en situaciones tendenciales donde una diferencia de una barra puede ser significativa.

### 4. `TradeSize` como Selector de Dirección

```pascal
If TradeSize > 0 Then
    Buy (...)  ...     // Modo largo
If TradeSize < 0 Then
    SellShort (...) ... // Modo corto
```

El signo de `TradeSize` controla la dirección:
- `TradeSize` positivo → solo operaciones largas.
- `TradeSize` negativo → solo operaciones cortas.

Para entradas cortas, la cantidad de la orden usa `-TradeSize` para convertir el input negativo en un conteo de acciones positivo:

```pascal
SellShort ("TL_SE_Limit") Next Bar -TradeSize Shares at TLProjected Limit;
```

Este es un diseño compacto: un parámetro codifica tanto el tamaño de posición como la intención direccional. El trade-off es que el signo del parámetro tiene significado semántico que debe entenderse antes de su uso.

### 5. Tipo Dual de Entrada — Límite o Stop Según la Posición del Precio

La estrategia usa dos tipos de orden diferentes dependiendo de dónde esté el precio respecto a la línea de tendencia proyectada:

**Para operaciones largas:**
```pascal
If CrossUp Then
    Buy (...) Next Bar TradeSize Shares at TLProjected Limit   // Precio sobre la línea → orden límite
Else
    Buy (...) Next Bar TradeSize Shares at TLProjected Stop;   // Precio bajo la línea → orden stop
```

- `CrossUp = Close > TLProjected` (v2): el precio está actualmente por encima de la línea de tendencia.
  - Se coloca una **orden límite** en `TLProjected` — la estrategia espera a que el precio retroceda hasta la línea. Esta es la entrada típica de soporte en línea de tendencia: comprar cuando el precio vuelve a la línea de tendencia ascendente desde arriba.
- El precio está por debajo de la línea de tendencia:
  - Se coloca una **orden stop** en `TLProjected` — la estrategia espera a que el precio rompa hacia arriba a través de la línea. Esto captura una ruptura alcista por encima de una línea de resistencia descendente.

**Para operaciones cortas:** la lógica es el espejo — órdenes límite cuando el precio está por debajo de la línea (esperando un rebote hasta la línea), órdenes stop cuando el precio está por encima de la línea (esperando una ruptura bajista).

Este diseño dual maneja ambos escenarios comunes de trading con líneas de tendencia — entradas por retroceso al soporte y entradas por ruptura — dentro de una estrategia unificada.

---

## `CrossUp`/`CrossDown` — Estado, No Evento

Una nota de diseño crítica de los comentarios de v2 aplica a ambas versiones:

```pascal
CrossUp   = Close > TLProjected;   // El precio ESTÁ por encima de la línea (estado)
CrossDown = Close < TLProjected;   // El precio ESTÁ por debajo de la línea (estado)
```

Estas son **condiciones de estado posicional**, no eventos de cruce. `CrossUp` es `True` en cada barra donde el precio está por encima de la línea proyectada — no detecta la barra específica donde el precio cruzó de abajo hacia arriba. Esto significa:

- Si el precio ha estado por encima de la línea de tendencia durante 10 barras, `CrossUp` ha sido `True` durante las 10 barras.
- La orden límite se re-evalúa y se coloca en cada una de esas barras.

Este es el comportamiento correcto para una estrategia de línea de tendencia: la orden límite debe estar activa mientras el precio esté por encima de la línea esperando retroceder hasta ella. El guard `IsFlat` en v2 evita la reentrada después de que una posición ya está abierta.

Usar un evento discreto `Crosses Over` en su lugar colocaría la orden límite solo en la barra exacta del cruce — potencialmente perdiendo la entrada si el retroceso ocurre varias barras después.

---

## v1 vs v2: La Diferencia

### v1 — Sin Guard de Posición

v1 no tiene comprobación de `IsFlat` antes de colocar órdenes. En cada evaluación de `LastBarOnChart` donde la línea de tendencia es válida, coloca órdenes de entrada independientemente de si ya hay una posición abierta:

```pascal
// v1 — órdenes colocadas incondicionalmente (sin comprobación IsFlat)
If TradeSize > 0 Then
Begin
    If Close > TLV Then
        Buy ("TLBuy LE") Next Bar TradeSize Shares at TLV Limit
    Else
        Buy ("TL Buy LE") Next Bar TradeSize Shares at TLV Stop;
End;
```

EasyLanguage evita que se abra una posición larga duplicada si ya hay un largo, pero la orden se sigue enviando en cada barra — generando actividad de órdenes innecesaria. En trading en vivo con `LastBarOnChart`, esto significa que se coloca una nueva orden en cada tick intrabarra, lo que puede causar problemas de gestión de órdenes con algunos brokers.

v1 también usa `TLV` (el valor de la barra actual extrapolado un paso) en lugar de tener una variable proyectada con nombre separado, y mezcla el cálculo de proyección con la lógica de órdenes en el mismo bloque.

### v2 — Máquina de Estados Completa y Bloques Separados

v2 introduce `IsFlat`, `IsLong`, `IsShort` y condiciona el bloque de entrada con `If IsFlat and ValidTL`. Las órdenes solo se colocan cuando la estrategia no tiene posición abierta, eliminando el envío continuo de órdenes de v1.

v2 también separa las responsabilidades en bloques claramente etiquetados: validación, lectura y proyección de la línea, cálculo de señales estructurales (`CrossUp`/`CrossDown`), y ejecución de entradas. `ValidTL` consolida las cuatro condiciones guard (`TradeSize <> 0`, `TLID >= 0`, `TL_Exist(TLID)`, `LastBarOnChart`) en un único booleano con nombre.

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Lectura y proyección de línea** | ✓ | ✓ |
| **Entrada dual límite / stop** | ✓ | ✓ |
| **Guard de posición `IsFlat`** | — | ✓ |
| **Guard consolidado `ValidTL`** | — | ✓ |
| **Variable `TLProjected` con nombre** | — | ✓ |
| **Señales con nombre `CrossUp`/`CrossDown`** | — | ✓ |
| **Bloques separados etiquetados** | — | ✓ |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `TradeSize` | 500 | Tamaño de posición en acciones. Positivo = operaciones largas; negativo = operaciones cortas. Cero desactiva la estrategia. |
| `TLID` | 0 | ID interno de TradeStation de la línea de tendencia dibujada manualmente. Debe coincidir con el ID de objeto asignado por la plataforma. |

**Sobre `TLID`:** El valor por defecto de `0` no es un ID de línea de tendencia válido en la mayoría de configuraciones — sirve como marcador de posición. Antes de usar la estrategia, el ID correcto debe obtenerse del gráfico e introducirse como input. Un `TLID` incorrecto hace que `TL_Exist(TLID)` devuelva `False`, y la estrategia no colocará ninguna orden.

**Sobre el signo de `TradeSize`:** Cambiar de modo largo a corto requiere cambiar el signo de `TradeSize` (p. ej. de `500` a `-500`). El valor absoluto determina el número de acciones en ambos casos.

---

## Escenarios de Operación

### Escenario A — Entrada Larga: Precio por Encima de Línea Ascendente (Orden Límite)

- Línea de tendencia ascendente con `TLCurrent = 4.985`, `TLPrevious = 4.980`.
- `TLProjected = 4.985 + (4.985 − 4.980) = 4.990`.
- Cierre actual: 4.998. `CrossUp = True` (precio por encima de la línea proyectada).
- `TradeSize = 500` (modo largo).
- **Orden límite colocada en 4.990.** La estrategia espera a que el precio retroceda hasta la línea.
- Siguiente barra: el precio cae hasta 4.989, tocando 4.990 de camino. Largo ejecutado a 4.990.

### Escenario B — Entrada Larga: Precio por Debajo de Línea Ascendente (Orden Stop)

- Misma línea. `TLProjected = 4.990`.
- Cierre actual: 4.978. `CrossUp = False` (precio por debajo de la línea proyectada).
- **Orden stop colocada en 4.990.** La estrategia espera a que el precio rompa hacia arriba a través de la línea.
- Siguiente barra: el precio sube a través de 4.990. Largo ejecutado a 4.990.

### Escenario C — Entrada Corta: Precio por Debajo de Línea Descendente (Orden Límite)

- Línea de tendencia descendente. `TLCurrent = 5.010`, `TLPrevious = 5.015`.
- `TLProjected = 5.010 + (5.010 − 5.015) = 5.005`.
- Cierre actual: 4.998. `CrossDown = True` (precio por debajo de la línea proyectada).
- `TradeSize = -500` (modo corto).
- **Orden límite colocada en 5.005.** La estrategia espera a que el precio rebote hasta la línea.
- Siguiente barra: el precio rebota hasta 5.006. Corto ejecutado a 5.005.

### Escenario D — Línea No Encontrada, Sin Órdenes

- `TLID = 42`. `TL_Exist(42)` devuelve `False` — la línea de tendencia fue eliminada o el ID es incorrecto.
- `ValidTL = False`. Sin órdenes colocadas.
- La estrategia permanece inactiva hasta que `TLID` se actualice a una línea de tendencia válida.

---

## Características Clave

- **Integración con líneas de tendencia manuales:** La estrategia lee una línea de tendencia dibujada por el trader, combinando el dibujo discrecional con la ejecución sistemática en ese nivel.
- **Proyección lineal:** Las órdenes apuntan a la posición estimada de la línea de tendencia en la siguiente barra más que a su posición actual, teniendo en cuenta la pendiente de la línea en tiempo real.
- **Tipo de orden dual:** Órdenes límite cuando el precio está en el lado favorable (buscando un retorno a la línea); órdenes stop cuando está en el lado desfavorable (buscando una ruptura a través de la línea). Ambos escenarios de entrada con línea de tendencia se manejan automáticamente.
- **`TradeSize` como selector de dirección:** Un único parámetro controla tanto el tamaño de posición como el modo direccional (largo/corto) mediante su signo, manteniendo la superficie de parámetros mínima.
- **Guard `LastBarOnChart`:** La estrategia solo evalúa en la barra en vivo actual, haciéndola una herramienta de ejecución en tiempo real. Las barras históricas no activan órdenes.
- **Guard `IsFlat` (v2):** Las órdenes solo se colocan cuando la estrategia no tiene posición abierta, evitando el envío continuo de órdenes mientras hay una operación activa.
- **Comprobación consolidada `ValidTL` (v2):** Las cuatro precondiciones — tamaño válido, ID válido, línea existe, barra en vivo — se combinan en un único booleano con nombre para mayor claridad.

---

## Psicología del Trading

Trendline Entry Strategy aborda uno de los desafíos más comunes en el trading discrecional: **dibujar el nivel correcto es una habilidad; ejecutar en él sin dudar es otra.** Muchos traders identifican líneas de tendencia correctamente pero luego se lo piensan demasiado en el momento de la ejecución — entrando demasiado pronto, esperando demasiado, o ajustando la línea a posteriori. Al codificar las reglas de ejecución mecánicamente, la estrategia separa la decisión analítica (dónde dibujar la línea) de la decisión de ejecución (cómo entrar en ella).

El tipo de orden dual refleja una comprensión matizada del comportamiento de las líneas de tendencia. Una línea de tendencia ascendente que actúa como soporte espera que el precio retroceda hacia ella — una orden límite es apropiada. Una línea de tendencia descendente que actúa como resistencia y que el precio se aproxima desde abajo puede producir una ruptura — una orden stop captura ese escenario. La estrategia maneja ambos sin que el trader necesite predecir de antemano cuál de los dos escenarios se materializará.

El diseño solo en tiempo real (`LastBarOnChart`) es también una característica psicológica: la estrategia no genera entradas históricas hipotéticas que podrían lucir mejor en backtesting que en trading en vivo. Solo actúa cuando el mercado está realmente abierto y la posición de la línea de tendencia puede evaluarse contra el precio actual. Esto mantiene la estrategia honesta sobre lo que puede ofrecer de forma realista.

---

## Casos de Uso

**Instrumentos:** Aplicable a cualquier instrumento líquido donde el análisis de líneas de tendencia sea significativo — futuros de índices de renta variable (ES, NQ), acciones individuales en fases tendenciales, futuros de materias primas y futuros FX. La línea de tendencia debe tener suficientes toques de precio para considerarse estructuralmente significativa; una línea trazada a través de solo dos puntos es menos fiable que una con múltiples confirmaciones.

**Marcos temporales:** Las líneas de tendencia en gráficos diarios y semanales tienen mayor peso estructural que las líneas intradiarias. La estrategia funciona en cualquier marco temporal, pero la calidad de la entrada depende enteramente de la calidad de la línea dibujada.

**Flujo de trabajo:** El flujo de trabajo previsto es:
1. Identificar una línea de tendencia significativa mediante análisis de gráfico.
2. Dibujarla en el gráfico y anotar el `TLID`.
3. Configurar la estrategia con el `TLID` correcto y el `TradeSize` deseado.
4. Dejar que la estrategia gestione la ejecución en el nivel de la línea de tendencia automáticamente.

**Limitaciones:** Dado que la estrategia lee un objeto dibujado manualmente, no puede someterse a backtesting en el sentido tradicional — las líneas de tendencia históricas no se conservan entre sesiones. La estrategia se evalúa por su calidad de ejecución en tiempo real, no por resultados estadísticos de backtesting. Cualquier backtesting requeriría reconstruir manualmente las líneas de tendencia históricas para cada período, lo que no es práctico a escala.

**Relación con otras estrategias:** Esta estrategia es arquitectónicamente única en el repositorio — es la única que lee objetos de gráfico externos en lugar de calcular todos los inputs exclusivamente a partir de datos de precio. Representa una filosofía de diseño específica: conservar la intuición discrecional (la línea de tendencia) y sistematizar únicamente la mecánica de ejecución alrededor de ella.
