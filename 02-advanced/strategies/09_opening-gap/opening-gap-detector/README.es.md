# Opening Gap Detector — v1.0

🇺🇸 [English](README.md) | 🇪🇸 Español

## Descripción del sistema

Opening Gap Detector es un indicador de gráfico que proporciona una representación visual de la lógica de detección de gap de apertura compartida por la familia de estrategias Opening Gap — Gap Down, Gap Up y Bidirectional. En lugar de inferir la actividad de gap a partir de entradas y salidas de trades a posteriori, el indicador dibuja la geometría de detección directamente sobre el gráfico de precios: líneas de umbral al final de sesión, líneas de magnitud del gap en la apertura y anotaciones etiquetadas que identifican cada gap válido y su dirección.

El indicador replica la lógica de detección de la estrategia Bidirectional exactamente — `Low` y `High` como precios de referencia fijos, un único umbral `GapTest` — convirtiéndolo en un compañero visual fiel para las tres estrategias sin requerir sincronización de parámetros más allá de `GapTest`.

---

## Mecánica central

### 1. Líneas de umbral — bloque de fin de sesión

```pascal
If Time = SessionEndTime(1, 1) Then
Begin
    // Umbral inferior — nivel de entrada Gap Down
    Value1 = TL_New(Date[1], Time[1], Low - GapTest, Date, Time, Low - GapTest);
    TL_SetColor(Value1, Blue);
    Value2 = Text_New(Date[1], Time[1], Low - GapTest, NumToStr(Low - GapTest, 2) + " ");
    Text_SetStyle(Value2, 1, 2);
    Text_SetColor(Value2, Blue);

    // Umbral superior — nivel de entrada Gap Up
    Value3 = TL_New(Date[1], Time[1], High + GapTest, Date, Time, High + GapTest);
    TL_SetColor(Value3, Green);
    Value4 = Text_New(Date[1], Time[1], High + GapTest, NumToStr(High + GapTest, 2) + " ");
    Text_SetStyle(Value4, 1, 2);
    Text_SetColor(Value4, Green);
End;
```

Este bloque se ejecuta en la última barra de cada sesión — la barra cuyo `Time` es igual a `SessionEndTime(1, 1)`. En ese momento, `Low` y `High` son el mínimo y máximo de la sesión completada, y `GapTest` es el valor umbral actual. Se dibujan dos líneas horizontales desde esa barra hacia la siguiente sesión:

- **Línea azul en `Low - GapTest`:** El nivel mínimo que debe romper hacia abajo la apertura de la siguiente sesión para que un Gap Down sea válido.
- **Línea verde en `High + GapTest`:** El nivel mínimo que debe romper hacia arriba la apertura de la siguiente sesión para que un Gap Up sea válido.

Ambas líneas se etiquetan con su nivel de precio exacto, alineado a la derecha del punto de inicio de la línea. Esto proporciona al trader una referencia visual anticipada antes de que abra la siguiente sesión — las dos líneas definen los límites de la "zona de cualificación" para la detección de gap entrante.

`Value1`–`Value4` son las variables de propósito general de EasyLanguage para handles de objetos. El umbral superior usa `Value3` y `Value4` en lugar de reutilizar `Value1` y `Value2` — reutilizarlos dentro del mismo bloque sobreescribiría los handles antes de que `TL_SetColor` pudiera aplicar el color al primer par de objetos.

### 2. Detección de Gap Down — primera barra de nueva sesión

```pascal
If Date <> Date[1] and Open < Low[1] - GapTest[1] Then
Begin
    Value1 = TL_New(Date[1], Time[1], Low[1], Date[1], Time[1], Open);
    TL_SetColor(Value1, Blue);
    Value1 = TL_New(Date[1], Time[1], Open, Date, Time, Open);
    TL_SetColor(Value1, Blue);
    Gap = Low[1] - Open;
    Value1 = Text_New(Date[1], Time[1], Open, NumToStr(Gap, 2) + " ");
    Text_SetStyle(Value1, 1, 2);
    Text_SetColor(Value1, Blue);
    Value1 = Text_New(Date, Time, High, " Gap Down ");
    Text_SetStyle(Value1, 2, 1);
    Text_SetColor(Value1, DarkCyan);
End;
```

`Date <> Date[1]` identifica la primera barra de una nueva sesión — la barra donde `Date` ha cambiado respecto a la barra anterior. En este punto, `Low[1]` y `GapTest[1]` son los valores de la sesión anterior, y `Open` es el precio de apertura de la barra actual. La condición `Open < Low[1] - GapTest[1]` es exactamente el test de cualificación de Gap Down.

Cuando un Gap Down es válido, se crean cuatro objetos de dibujo:

- **Línea vertical azul** desde `Low[1]` hacia abajo hasta `Open` en el límite de sesión — la extensión vertical del gap.
- **Línea horizontal azul** al nivel de `Open` que se extiende hacia la sesión actual — la referencia del precio de entrada y el origen del objetivo de relleno del gap.
- **Etiqueta de texto azul** en el nivel de apertura mostrando la magnitud del gap en puntos (`Gap = Low[1] - Open`).
- **Etiqueta "Gap Down" en DarkCyan** posicionada en el `High` de la primera barra — por encima de la apertura, proporcionando una anotación direccional clara sin solaparse con la geometría del gap.

La colocación de la etiqueta en `High` es intencional: dado que la apertura está por debajo del mínimo anterior, colocar la etiqueta en el máximo de la barra asegura que aparezca por encima de la apertura, en el espacio de precio visible sobre el gap, en lugar de dentro del gap.

### 3. Detección de Gap Up — primera barra de nueva sesión

```pascal
If Date <> Date[1] and Open > High[1] + GapTest[1] Then
Begin
    Value1 = TL_New(Date[1], Time[1], High[1], Date[1], Time[1], Open);
    TL_SetColor(Value1, Green);
    Value1 = TL_New(Date[1], Time[1], Open, Date, Time, Open);
    TL_SetColor(Value1, Green);
    Gap = Open - High[1];
    Value1 = Text_New(Date[1], Time[1], Open, NumToStr(Gap, 2) + " ");
    Text_SetStyle(Value1, 1, 2);
    Text_SetColor(Value1, Green);
    Value1 = Text_New(Date, Time, Low, " Gap Up ");
    Text_SetStyle(Value1, 2, 1);
    Text_SetColor(Value1, DarkGreen);
End;
```

Estructuralmente simétrico al bloque de Gap Down. `Open > High[1] + GapTest[1]` es el test de cualificación de Gap Up. Los objetos de dibujo replican el conjunto de Gap Down con dos diferencias:

- **La paleta de colores es verde / verde oscuro** en todos los objetos, distinguiendo visualmente los eventos Gap Up de los Gap Down.
- **La etiqueta "Gap Up" se posiciona en `Low`** de la primera barra — por debajo de la apertura, en el espacio de precio visible bajo el gap, simétrico a la colocación de la etiqueta de Gap Down en `High`.

`Gap = Open - High[1]` captura la magnitud del gap alcista con la convención de signo correcta: un valor positivo que representa cuánto por encima del máximo anterior ha abierto la sesión.

### 4. Enfoque de detección — fin de sesión vs. inicio de sesión

El indicador utiliza un momento de detección diferente al de las estrategias, y entender la distinción es importante para una interpretación correcta:

- **Las estrategias** detectan el gap en la **última barra de la sesión anterior** usando `Open of Next Bar` — leen la apertura del día siguiente antes de que esa barra comience, colocan la orden de entrada y se ejecutan en esa misma apertura.
- **El indicador** detecta el gap en la **primera barra de la nueva sesión** usando `Date <> Date[1]` — lee la apertura una vez que ha llegado la primera barra de la nueva sesión.

Ambos acceden al mismo precio: el precio de apertura de la nueva sesión. La diferencia es la barra en la que se ejecuta la lógica. Las estrategias se disparan una barra antes (última barra de la sesión anterior); el indicador se dispara una barra después (primera barra de la nueva sesión). El resultado es idéntico — mismo gap detectado, misma magnitud, misma cualificación — pero los objetos de dibujo están anclados a la primera barra de la nueva sesión en lugar de a la última de la anterior.

---

## Arquitectura

```
Última barra de sesión (Time = SessionEndTime)
    └─ Dibujar líneas de umbral para la siguiente sesión
           Azul:  Low  - GapTest  → nivel de cualificación Gap Down
           Verde: High + GapTest  → nivel de cualificación Gap Up

Primera barra de siguiente sesión (Date <> Date[1])
    ├─ Open < Low[1]  - GapTest[1] ?
    │       └─ SÍ → Dibujar geometría Gap Down (azul)
    │                  Línea vertical: Low[1] → Open
    │                  Línea horizontal: nivel Open
    │                  Etiqueta: magnitud del gap
    │                  Etiqueta: "Gap Down"
    │
    └─ Open > High[1] + GapTest[1] ?
            └─ SÍ → Dibujar geometría Gap Up (verde)
                       Línea vertical: High[1] → Open
                       Línea horizontal: nivel Open
                       Etiqueta: magnitud del gap
                       Etiqueta: "Gap Up"
```

Ambas condiciones de gap son independientes — se evalúan en bloques `If` separados en la primera barra de cada sesión. En la práctica solo una puede ser verdadera en cualquier apertura dada (el precio no puede estar simultáneamente por debajo de `Low - GapTest` y por encima de `High + GapTest`), pero la arquitectura no impone exclusión mutua explícitamente, de forma consistente con el enfoque de la estrategia Bidirectional.

---

## Parámetros

| Parámetro | Por defecto | Descripción |
|-----------|-------------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Umbral adaptativo a la volatilidad para la cualificación del gap. Los gaps deben superar este valor para activar la detección visual. Coincide con el valor por defecto usado por las tres estrategias Opening Gap. |

**Diseño de parámetro único:** `GapPrice` no se expone como input. El indicador hardcodea `Low` como referencia de Gap Down y `High` como referencia de Gap Up — el mismo enfoque utilizado por la estrategia Bidirectional. Esto mantiene la superficie de parámetros en un único input preservando la medición correcta del gap para ambas direcciones. Si se necesita detección de gap desde el cierre, los precios de referencia tendrían que cambiarse directamente en el código, como ocurre en la estrategia Bidirectional.

**Alineación de parámetros con las estrategias:** Para que las líneas de umbral y las anotaciones del indicador coincidan exactamente con las condiciones de entrada de las estrategias, `GapTest` debe establecerse al mismo valor usado en la estrategia. El valor por defecto `Median(Range, 50)[1]` coincide con los valores por defecto de las tres estrategias. Si una estrategia se ejecuta con un valor personalizado de `GapTest`, el indicador debe actualizarse para que coincida.

---

## Escenarios de interpretación

### Escenario A — Gap Down detectado

- La sesión anterior cierra. Última barra: `Low = 3.975`, `High = 3.995`, `GapTest = 10 pts`.
- Líneas de umbral dibujadas: azul en `3.965` (nivel Gap Down), verde en `4.005` (nivel Gap Up).
- La siguiente sesión abre en `3.958`. `3.958 < 3.975 − 10 = 3.965`. **Gap Down válido.**
- Línea vertical azul dibujada desde `3.975` hasta `3.958`.
- Línea horizontal azul dibujada en `3.958`.
- Etiqueta: `17,00` (magnitud del gap). Etiqueta: `Gap Down`.
- Las estrategias Gap Down y Bidirectional entran largo en `3.958`. La línea horizontal del indicador en `3.958` marca el nivel de entrada y el origen del objetivo de relleno del gap.

### Escenario B — Gap Up detectado

- La sesión anterior cierra. `High = 3.995`, `Low = 3.975`, `GapTest = 10 pts`.
- Líneas de umbral dibujadas: azul en `3.965`, verde en `4.005`.
- La siguiente sesión abre en `4.014`. `4.014 > 3.995 + 10 = 4.005`. **Gap Up válido.**
- Línea vertical verde dibujada desde `3.995` hasta `4.014`.
- Línea horizontal verde dibujada en `4.014`.
- Etiqueta: `19,00`. Etiqueta: `Gap Up`.
- Las estrategias Gap Up y Bidirectional entran corto en `4.014`.

### Escenario C — Sin gap válido

- La siguiente sesión abre en `3.978`. `3.978 > 3.965` y `3.978 < 4.005`.
- Ninguna condición es válida. No se dibuja geometría de gap. Solo son visibles las líneas de umbral del final de la sesión anterior.
- Las estrategias no tienen entrada. El indicador muestra correctamente una apertura tranquila dentro del rango de la sesión anterior.

### Escenario D — Múltiples sesiones, continuidad de líneas de umbral

- A lo largo de tres sesiones consecutivas, se dibujan líneas de umbral al final de cada sesión.
- En la sesión 2 se detecta y anota un Gap Down. En las sesiones 1 y 3 no hay gap válido.
- El gráfico muestra líneas de umbral para las tres sesiones, con geometría de gap solo en la sesión 2. Esto proporciona un registro histórico claro de qué sesiones produjeron gaps válidos y cuáles no.

---

## Características clave

- **Líneas de umbral anticipadas:** Dibujadas al final de sesión, antes de la siguiente apertura, dando al trader visibilidad previa de los niveles exactos que cualificarían un gap en la sesión entrante.
- **Codificación de color simétrica:** Los eventos Gap Down son azul / cian oscuro en todos los objetos; los eventos Gap Up son verde / verde oscuro. Los colores son consistentes entre líneas de umbral, geometría del gap, etiquetas de magnitud y etiquetas de dirección.
- **Anotación de magnitud del gap:** El tamaño exacto del gap en puntos se etiqueta en el nivel de apertura para cada gap válido, proporcionando contexto cuantitativo inmediato sin necesidad de medición manual.
- **Precios de referencia hardcodeados:** `Low` para Gap Down, `High` para Gap Up — consistente con la arquitectura de la estrategia Bidirectional y sin requerir sincronización de parámetros más allá de `GapTest`.
- **`Value3`/`Value4` para el umbral superior:** Variables de handle separadas para las líneas de umbral de Gap Up evitan la sobreescritura de handles dentro del bloque de fin de sesión, asegurando que ambas líneas de umbral reciban el color correcto.
- **Posicionamiento de etiquetas por dirección:** Etiquetas de Gap Down en el `High` de la barra, etiquetas de Gap Up en el `Low` — cada etiqueta aparece en el espacio de precio del lado opuesto al gap, evitando solapamiento con la geometría del gap.
- **Bloques de detección independientes:** Gap Down y Gap Up se evalúan en bloques `If` separados. No se impone exclusión mutua en el código — la geometría del precio hace que la cualificación simultánea sea imposible en la práctica.

---

## Limitaciones

### Precio de referencia único para `GapTest` — sin detección de gap desde el cierre

El indicador hardcodea `Low` y `High` como precios de referencia, siguiendo el diseño de la estrategia Bidirectional. Las estrategias direccionales (Gap Down v1/v2, Gap Up v1) exponen `GapPrice` como input configurable que puede establecerse a `Close` para detección de gap desde el cierre. El indicador no soporta esta variante — solo detectará gaps que rompan más allá del máximo o mínimo de la sesión anterior. Los usuarios que ejecuten las estrategias direccionales con `GapPrice = Close` encontrarán una discrepancia entre las líneas de umbral del indicador y las condiciones de entrada reales de las estrategias.

### Objetos de dibujo en barras históricas

Las líneas de tendencia y objetos de texto creados con `TL_New` y `Text_New` son objetos de dibujo persistentes — se añaden al gráfico en cada pasada de cálculo y se acumulan a lo largo del histórico del gráfico. En un gráfico con muchos años de datos, esto puede generar un gran número de objetos, afectando potencialmente al rendimiento de renderizado del gráfico. Este es un comportamiento general de los indicadores ShowMe en EasyLanguage y no es específico de este indicador, pero merece señalarse para los usuarios que lo apliquen sobre conjuntos de datos históricos extensos.

### Comportamiento de recálculo en tiempo real

Los indicadores de EasyLanguage recalculan en cada tick de la última barra. Las líneas de umbral (bloque de fin de sesión) se redibujan en cada tick de la última barra de cada sesión. Los bloques de detección de gap (primera barra de sesión) se redibujan en cada tick de la primera barra de la nueva sesión. En la práctica esto significa que los objetos de dibujo pueden recrearse múltiples veces por barra en el gráfico en vivo — un comportamiento normal de EasyLanguage pero que ocasionalmente puede producir artefactos visuales si el gráfico se actualiza muy rápidamente en los límites de sesión.

---

## Casos de uso

**Validación visual de entradas de estrategia:** Aplicar el indicador al mismo gráfico donde se ejecuta una estrategia Opening Gap. Las líneas de umbral muestran por anticipado si la siguiente apertura tiene probabilidad de cualificar; la geometría del gap confirma qué entradas habrá tomado la estrategia. Esto es especialmente útil durante sesiones de revisión de estrategia para verificar que los gaps detectados coinciden con las entradas reales de los trades.

**Análisis de frecuencia de gaps:** Con el indicador aplicado a un gráfico histórico, la distribución de gaps válidos a lo largo del tiempo se vuelve inmediatamente visible — con qué frecuencia ocurren los gaps, en qué dirección y de qué magnitud. Esto apoya la evaluación inicial de si el edge de fade de gap está presente en un instrumento o temporalidad determinada antes de ejecutar un backtest completo.

**Monitorización de la apertura de sesión:** Durante el trading en vivo, las líneas de umbral dibujadas al cierre de la sesión anterior proporcionan una referencia visual inmediata para la apertura entrante. El trader puede ver de un vistazo cuánto tendría que gapear el precio para activar una entrada de estrategia, sin necesidad de recalcular manualmente.

**Despliegue en múltiples instrumentos:** El indicador puede aplicarse a múltiples instrumentos simultáneamente. Dado que el umbral se adapta al propio `Median(Range, 50)[1]` de cada instrumento, los criterios de cualificación se escalan automáticamente a la volatilidad de cada instrumento — un gap que cualifica en ES puede no cualificar en un instrumento menos volátil usando la misma instancia del indicador.

---

## Relación con la familia de estrategias Opening Gap

El indicador está diseñado como compañero visual de tres estrategias que comparten la misma lógica de detección central:

| Estrategia | Dirección | Precios de referencia | `GapTest` por defecto |
|---|---|---|---|
| Opening Gap Down v1 / v2 | Solo largo | Input `GapPrice` (por defecto `Low`) | `Median(Range, 50)[1]` |
| Opening Gap Up v1 | Solo corto | Input `GapPrice` (por defecto `High`) | `Median(Range, 50)[1]` |
| Opening Gap Bidirectional v1 | Ambas | Hardcodeado `Low` / `High` | `Median(Range, 50)[1]` |
| **Opening Gap Detector v1** | Solo visual | Hardcodeado `Low` / `High` | `Median(Range, 50)[1]` |

La lógica de detección del indicador coincide exactamente con la estrategia Bidirectional. Para las estrategias direccionales, la coincidencia se mantiene siempre que `GapPrice` se deje en su valor por defecto (`Low` para Gap Down, `High` para Gap Up). Si `GapPrice` se cambia en una estrategia direccional, las líneas de umbral y las anotaciones del indicador ya no corresponderán a las condiciones de entrada de esa estrategia.
