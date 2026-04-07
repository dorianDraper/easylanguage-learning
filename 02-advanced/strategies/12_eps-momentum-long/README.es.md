# EPS Momentum Long — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

EPS Momentum Long es una estrategia solo en largo que combina análisis fundamental con momentum técnico para cronometrar las entradas en acciones individuales. En lugar de usar únicamente la acción del precio, la estrategia requiere que el beneficio por acción (EPS) de una empresa esté mejorando antes de considerar cualquier entrada — la condición fundamental actúa como filtro primario que define el universo de condiciones operables. Dentro de ese universo filtrado, una señal de momentum de precio a corto plazo activa la entrada real. La estrategia mantiene la posición hasta que la tesis fundamental se deteriora (un nuevo informe de resultados muestra EPS en declive) o la estructura técnica falla (el precio hace un nuevo mínimo de seis meses).

Esta es la primera estrategia en este repositorio que usa datos fundamentales directamente en la lógica de trading, accediendo a valores de EPS y fechas de informes desde el feed de datos integrado de TradeStation mediante las funciones `FundValue` y `FundDate` de EasyLanguage.

---

## Mecánica Central

### 1. Acceso a Datos Fundamentales — `FundValue` y `FundDate`

```pascal
EPSCurr        = FundValue("SBBF", 0, ErrorEPS);
EPSPrev        = FundValue("SBBF", 1, ErrorEPSPrev);
EPSReleaseDate = JulianToDate(FundDate("SBBF", 0, ErrorDate));
```

**`FundValue(campo, offset, errorCode)`** recupera valores de datos fundamentales de la fuente de datos integrada de TradeStation:
- `"SBBF"` es el código de campo de Thomson Reuters/Refinitiv para *Basic EPS Before Extraordinary Items* — el beneficio por acción reportado antes de incluir cargos o ganancias puntuales.
- `offset = 0` devuelve el informe disponible más reciente; `offset = 1` devuelve el anterior.
- `errorCode` es un parámetro de salida — recibe un valor distinto de cero si los datos no están disponibles, están desactualizados o el campo no está soportado para el instrumento. Este es el patrón estándar de gestión de errores de EasyLanguage para llamadas de datos fundamentales.

**`FundDate(campo, offset, errorCode)`** devuelve la fecha del correspondiente informe de resultados en formato de fecha Julian. `JulianToDate` convierte esto al entero de fecha estándar YYYMMDD de EasyLanguage, habilitando la comparación directa con `Date` y `Date[1]`.

**¿Por qué `"SBBF"`?** Diferentes campos fundamentales están disponibles mediante distintos códigos. `SBBF` apunta específicamente al beneficio por acción antes de partidas extraordinarias, lo que proporciona una comparación más consistente entre períodos de reporte que las cifras de EPS que incluyen eventos puntuales. Otros códigos disponibles incluyen ingresos, valor contable, dividendos y muchos más — el mismo patrón `FundValue`/`FundDate` aplica a todos ellos.

### 2. Validación de Datos

```pascal
// v1
DataOK     = True;   // Reset a True; se pone False si hay error
EPSVal     = FundValue("SBBF", 0, oErrorCode);
If oErrorCode > 0 Then DataOK = False;

// v2 — consolidado
FundamentalOK = ErrorEPS = 0 and ErrorEPSPrev = 0 and ErrorDate = 0;
```

Ambas versiones validan que las tres llamadas de datos tuvieron éxito antes de ejecutar cualquier lógica. Un código de error distinto de cero significa que los datos no son fiables — el instrumento puede no tener datos de resultados, el campo puede no estar soportado o el feed de datos puede tener un vacío. Operar con datos fundamentales inválidos produciría señales incorrectas, por lo que las tres condiciones deben estar libres de errores.

v2 consolida las tres variables de flag separadas (`DataOK`, `DataOKPrev`, `DateDataOK`) en un único booleano `FundamentalOK`, siguiendo el mismo principio de separación de responsabilidades usado en todo el repositorio.

### 3. Detección de Tendencia EPS

```pascal
EPSImproving = EPSCurr > EPSPrev;   // v2
EPSInc       = EPSVal > EPSPrevVal;  // v1
```

El filtro fundamental es directo: ¿es el informe de EPS más reciente superior al anterior? Una única comparación entre el informe de resultados actual y el anterior determina si la empresa está en una tendencia de mejora de beneficios. Esto es deliberadamente simple — una versión más sofisticada podría comparar EPS interanual, estimaciones de analistas o tasa de crecimiento del EPS, pero el concepto central de "los beneficios están mejorando" está capturado por esta única condición.

### 4. Detección de Nuevo Informe de Resultados

```pascal
// v1 — la fecha del informe más reciente es posterior a la barra de ayer
EPSDateToday = EPSReportDate > Date[1];

// v2 — la fecha del informe más reciente es hoy o posterior
NewEPSReleased = EPSReleaseDate >= Date;
```

Esta condición identifica cuándo hay disponible un informe de resultados nuevo. Se usa en la lógica de salida — si se publica un nuevo informe y el EPS ha empeorado, la operación sale.

**Precisión semántica v1 vs v2:** La condición de v1 (`EPSReportDate > Date[1]`) captura con precisión "se publicó un nuevo informe después de la barra de ayer" — es decir, se hizo disponible hoy. Esta es la intención de diseño original del material del curso. La condición de v2 (`EPSReleaseDate >= Date`) es más amplia: también es `True` cuando la fecha del informe está en el futuro, lo que podría incluir teóricamente informes aún no publicados. En la práctica, `FundValue` no devuelve datos de informes no publicados, por lo que esta diferencia rara vez afecta al comportamiento. Sin embargo, la formulación de v1 es semánticamente más ajustada y describe con más precisión la condición prevista. Este es un caso donde la refactorización de v2 mejoró la estructura del código pero introdujo una ligera relajación de la precisión semántica original.

### 5. Señal de Momentum de Precio para Entrada

```pascal
// v1 — confirmación de momentum en dos puntos
High > High[4] and High[1] > High[5]

// v2 — condición única más limpia
PriceMomentum = High > Highest(High, 5)[1];
```

Ambas versiones requieren momentum de precio alcista a corto plazo como disparador de ejecución. Las condiciones son similares pero no idénticas:

- **v1** requiere dos condiciones simultáneas: el máximo de hoy supera el de hace 4 barras, Y el máximo de ayer superó el de hace 5 barras. Esta es una confirmación de momentum en dos puntos — tanto la barra actual como la anterior muestran fortaleza relativa respecto a sus respectivos puntos de lookback.
- **v2** requiere una única condición: el máximo de hoy supera el máximo más alto de las 5 barras anteriores (excluida la barra actual, gracias al offset `[1]`). Es más limpio de leer y razonar — simplemente pregunta si el precio está actualmente rompiendo por encima de su rango reciente.

La condición de v2 puede ser más o menos restrictiva que v1 dependiendo de la secuencia específica de precios. En la mayoría de los escenarios tendenciales producen señales similares, pero v2 es la expresión más natural de "ruptura de momentum de precio por encima de máximos recientes".

### 6. Condición de Entrada

```pascal
// v2
If MarketPosition = 0 and FundamentalOK and EPSImproving and PriceMomentum Then
    Buy ("MO_EPS_Long") Next Bar at Market;
```

La entrada requiere que las tres condiciones independientes sean simultáneamente verdaderas:
- `MarketPosition = 0`: sin posición existente — la estrategia no añade posiciones.
- `FundamentalOK`: todas las llamadas de datos fundamentales devolvieron datos válidos.
- `EPSImproving`: el EPS más reciente supera el anterior.
- `PriceMomentum`: el precio está rompiendo por encima de su rango de máximos reciente.

La condición fundamental actúa como filtro primario — define si la empresa califica. La condición de momentum actúa como disparador de timing — dentro de las empresas calificadas, identifica cuándo entrar.

### 7. Lógica de Salida — Fundamental y Técnica

```pascal
// Salida 1 — deterioro fundamental
If NewEPSReleased and Not EPSImproving Then
    Sell ("EPS_Down") This Bar on Close;

// Salida 2 — fallo de tendencia estructural
If StructuralTrendFailure Then
    Sell ("6M_Low") This Bar on Close;
```

Dos condiciones de salida independientes, cualquiera de las cuales cierra la posición al cierre de la barra actual:

**Salida fundamental:** Cuando se publica un nuevo informe de resultados y muestra EPS en declive (`Not EPSImproving`), la tesis original para mantener la acción — mejora de beneficios — ha sido invalidada. La salida es inmediata (`This Bar on Close`) en lugar de retrasada, reflejando que el deterioro fundamental es una razón clara para salir independientemente de dónde esté el precio intrabarra.

**Salida técnica:** `Low < Lowest(Low, StructuralLookback)[1]` — el mínimo de la barra actual está por debajo del mínimo más bajo de las `StructuralLookback` barras anteriores (por defecto 26, representando aproximadamente seis meses de barras semanales). Un nuevo mínimo de seis meses indica que la estructura técnica que soportaba la tendencia alcista se ha roto. El offset `[1]` excluye la barra actual del cálculo del canal, garantizando que la salida se active solo cuando el precio rompe el mínimo establecido del período anterior, no simplemente cuando toca el rango en desarrollo de la barra actual.

`This Bar on Close` se ejecuta en la misma barra que activa la condición, proporcionando la salida más oportuna disponible dentro de la barra sin requerir generación de órdenes intrabarra.

---

## v1 vs v2: La Diferencia

| | v1.0 | v2.0 |
|---|---|---|
| **Acceso a datos fundamentales** | ✓ | ✓ |
| **Validación de datos** | ✓ (3 flags separados) | ✓ (`FundamentalOK` consolidado) |
| **Detección de mejora EPS** | ✓ | ✓ |
| **Detección de nuevo informe EPS** | `> Date[1]` (preciso) | `>= Date` (ligeramente más amplio) |
| **Condición de momentum** | Dos puntos (`High > High[4] and High[1] > High[5]`) | Única (`High > Highest(High, 5)[1]`) |
| **Guard de entrada `MarketPosition = 0`** | — | ✓ |
| **`StructuralLookback` como parámetro** | Hardcodeado `26` | ✓ configurable |
| **Señales booleanas con nombre** | Parcial | ✓ separación completa |
| **Bloques separados etiquetados** | Parcial | ✓ |

---

## Parámetros

### v1
Sin inputs — todos los valores están hardcodeados.

### v2

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `StructuralLookback` | 26 | Barras de lookback para el cálculo del mínimo de seis meses. El valor por defecto de 26 corresponde a aproximadamente seis meses de barras semanales o un trimestre de barras diarias. |

**Sobre `StructuralLookback = 26`:** La interpretación prevista es 26 barras semanales — aproximadamente seis meses de calendario de trading. Si la estrategia se aplica a barras diarias, 26 barras representa aproximadamente cinco semanas, que es una referencia estructural mucho más corta. En ese caso, `StructuralLookback` debería establecerse en aproximadamente 130 (26 semanas × 5 días de trading) para preservar la intención de seis meses.

---

## Escenarios de Operación

### Escenario A — Entrada Completa: EPS Mejorando + Precio Rompiendo al Alza

- `FundValue("SBBF", 0)` = 2,45. `FundValue("SBBF", 1)` = 2,10. Todos los códigos de error = 0.
- `EPSImproving = True` (2,45 > 2,10). `FundamentalOK = True`.
- Barra actual: `High = 48,20`. `Highest(High, 5)[1] = 47,80`. `PriceMomentum = True`.
- `MarketPosition = 0`. Todas las condiciones cumplidas.
- **Compra en la siguiente barra a mercado.** Se abre posición larga.

### Escenario B — Entrada Bloqueada: EPS en Declive

- `FundValue("SBBF", 0)` = 1,85. `FundValue("SBBF", 1)` = 2,10.
- `EPSImproving = False` (1,85 < 2,10). La condición de entrada falla.
- Aunque el momentum de precio sea fuerte, no se activa ninguna entrada. El filtro fundamental suprime la señal.

### Escenario C — Salida Fundamental: Nuevo Informe Muestra EPS en Declive

- Posición larga abierta. `EPSImproving` era `True` en la entrada.
- Nuevo informe de resultados publicado. `NewEPSReleased = True`. Último EPS = 1,90, anterior = 2,45.
- `EPSImproving = False`. Ambas condiciones verdaderas: `NewEPSReleased and Not EPSImproving`.
- **Venta al cierre de esta barra.** La posición sale por deterioro fundamental.

### Escenario D — Salida Técnica: Nuevo Mínimo de Seis Meses

- Posición larga abierta. La estrategia lleva varias semanas manteniendo la posición.
- Mínimo de barra actual: 41,20. `Lowest(Low, 26)[1]` = 42,50.
- `Low (41,20) < 42,50`. `StructuralTrendFailure = True`.
- **Venta al cierre de esta barra.** La posición sale por fallo de tendencia estructural.

### Escenario E — Fallo de Validación de Datos: Sin Entrada

- La llamada `FundValue("SBBF", 0, ErrorEPS)` devuelve `ErrorEPS = 3` (datos no disponibles).
- `FundamentalOK = False`. Toda la lógica de la estrategia suspendida.
- Sin órdenes de entrada colocadas. La estrategia espera datos válidos en la siguiente barra.

---

## Características Clave

- **Filtrado fundamental primero:** La mejora del EPS es un prerrequisito para la entrada, no una señal de confirmación. La estrategia solo considera acciones donde la tendencia de beneficios es positiva, independientemente de lo atractivo que parezca el setup técnico.
- **Acceso a datos `FundValue`/`FundDate`:** La integración directa con el feed de datos fundamentales de TradeStation permite el uso sistemático de datos de beneficios dentro de la lógica de estrategia automatizada — sin entrada manual de datos ni fuentes de datos separadas.
- **Validación por código de error:** Las tres llamadas de datos fundamentales se validan independientemente. Un único fallo de recuperación de datos suspende toda actividad de trading hasta que haya datos válidos disponibles, evitando entradas basadas en inputs fundamentales incompletos o desactualizados.
- **Framework de salida dual:** Una salida fundamental (deterioro del EPS en un nuevo informe) y una salida técnica (mínimo de seis meses) operan independientemente. La posición se cierra con la primera señal que se active.
- **Salidas `This Bar on Close`:** Ambas condiciones de salida cierran la posición en la barra que las activa, proporcionando la salida más oportuna disponible sin requerir generación de órdenes intrabarra.
- **`Commentary` para desarrollo:** Ambas versiones incluyen instrucciones `Commentary` que muestran valores de datos fundamentales en el gráfico para depuración barra a barra y validación visual de las lecturas de datos fundamentales.

---

## Psicología del Trading

EPS Momentum Long encarna una filosofía de inversión híbrida: **la calidad fundamental establece el campo de juego; el momentum técnico determina el timing.** Muchos traders sistemáticos tratan el análisis fundamental y el técnico como dominios separados — uno para la selección de acciones, otro para la ejecución. Esta estrategia integra ambos en un único conjunto de reglas, requiriendo que la empresa esté mejorando fundamentalmente *antes* de que siquiera se considere la entrada técnica.

El filtro EPS aborda una fuente común de señales falsas en las estrategias de momentum puro: una acción puede romper por encima de un máximo reciente por muchas razones — cobertura de cortos, rotación de mercado, entusiasmo especulativo — sin ninguna mejora subyacente en el rendimiento empresarial. Al requerir beneficios crecientes como precondición, la estrategia solo entra en movimientos de momentum respaldados por mejora empresarial fundamental, filtrando los movimientos impulsados puramente por la acción del precio.

La lógica de salida refleja la naturaleza dual de la estrategia con igual rigor. Si la tesis fundamental falla — un nuevo informe de resultados muestra que el negocio se está deteriorando — la posición sale independientemente del precio. Y si la estructura técnica falla — el precio hace un nuevo mínimo de seis meses — la posición sale independientemente de lo que pueda decir el próximo informe de resultados. Ninguno de los dos pilares por sí solo puede sostener la operación; ambos deben permanecer intactos.

La salida `StructuralLookback` es también una declaración sobre el horizonte temporal. La estrategia no es una operación de swing apuntando a un nivel de precio específico — es una posición que se mantiene mientras tanto la tendencia fundamental como la estructura técnica están intactas. El umbral del mínimo de seis meses define el límite exterior del deterioro técnico aceptable: una acción que ha hecho un nuevo mínimo de seis meses ha perdido el soporte estructural que justifica mantenerla como posición de momentum.

---

## Casos de Uso

**Instrumentos:** Acciones individuales con informes de resultados trimestrales — las acciones cotizadas en EE.UU. son el objetivo principal, ya que el campo fundamental `"SBBF"` de TradeStation está más fiablemente poblado para empresas cotizadas en EE.UU. La estrategia requiere que tanto los datos de precio como los fundamentales estén disponibles para el mismo instrumento. Los futuros sobre índices, materias primas y FX no tienen datos de EPS y no pueden usar esta estrategia.

**Marcos temporales:** Diseñada para barras semanales (`StructuralLookback = 26` = 26 semanas = ~6 meses) o barras diarias con lookback ajustado (`StructuralLookback = 130` para referencia equivalente de seis meses). En marcos temporales intradiarios más cortos, los informes de resultados no son señales significativas — los datos de EPS cambian como máximo trimestralmente.

**Dependencias de datos:** La estrategia requiere:
1. El servicio de datos fundamentales de TradeStation activo y correctamente licenciado.
2. Que el instrumento tenga datos de EPS disponibles bajo el código de campo `"SBBF"`.
3. Historial de resultados suficiente (al menos dos informes) para que la comparación sea significativa.

**Aplicación en portfolio:** Dado que el filtro fundamental define un subconjunto de alta calidad del universo invertible, esta estrategia es adecuada para ejecutarse simultáneamente en un portfolio de acciones individuales — cada instancia filtra independientemente, y solo las acciones con beneficios crecientes califican para la entrada en cualquier momento dado.

**Extensiones de investigación:** Las mejoras naturales para versiones futuras incluyen: comparación EPS interanual (trimestre actual vs mismo trimestre del año anterior, en lugar de comparación secuencial de informes), superación/decepción de estimaciones de analistas como filtro adicional, y sizing de posición basado en la magnitud de la tasa de crecimiento del EPS en lugar de tamaño fijo de acciones.
