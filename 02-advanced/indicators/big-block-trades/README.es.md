# Big Block Trade Activity — v1.0 & v2.0

🇺🇸 [English](README.md) | 🇪🇸 Español

## Descripción del sistema

Big Block Trade Activity es un indicador de microestructura en tiempo real que mide la proporción de actividad de tick intrabar generada por actualizaciones de precio de gran tamaño — un proxy de la actividad institucional o de grandes órdenes dentro de la barra actual. El indicador opera exclusivamente sobre la barra viva, usando variables `IntrabarPersist` para acumular estado a través de las actualizaciones tick a tick sin recalcular barras históricas.

En cada tick, el indicador estima el tamaño del trade más reciente calculando el delta entre el recuento acumulado de ticks actual y el anterior. Si este delta alcanza o supera el umbral de block trade definido, su contribución se añade a un acumulador en curso. La ratio de actividad de bloque respecto al total de ticks se expresa como porcentaje y se dibuja continuamente. Se dispara una alerta cuando este porcentaje supera un umbral configurable, señalando que la actividad de grandes órdenes está dominando la barra.

Una línea de referencia auxiliar dibuja el umbral de alerta directamente en el subgráfico del indicador, proporcionando una línea de base visual permanente para interpretar el porcentaje de actividad de bloque.

---

## Mecánica central

### 1. Gestión de estado intrabar

Todas las variables de cálculo se declaran como `IntrabarPersist`:

```pascal
Vars:
    IntrabarPersist CurrentTradeVolume(0),
    IntrabarPersist PreviousTickCount(0),
    IntrabarPersist BigBlockVolume(0),
    IntrabarPersist BigBlockPercentage(0);
```

Las variables `IntrabarPersist` retienen su valor entre actualizaciones de tick consecutivas dentro de la misma barra. Sin este modificador, EasyLanguage resetearía las variables a su valor inicial en cada tick, haciendo imposible la acumulación dentro de la barra. Piensa en `IntrabarPersist` como un portapapeles que sobrevive a cada actualización de tick pero se limpia explícitamente cuando la barra cierra.

El bloque de cálculo completo está envuelto en `If LastBarOnChart Then`, asegurando que no se produzca recálculo histórico. El indicador está diseñado para funcionar únicamente en tiempo real.

### 2. Estimación del delta de ticks

```pascal
If PreviousTickCount > 0 Then
Begin
    CurrentTradeVolume = Ticks - PreviousTickCount;
    ...
End;

PreviousTickCount = Ticks;
```

`Ticks` es una función integrada de EasyLanguage que devuelve el recuento acumulado de actualizaciones de precio en la barra actual desde que abrió. En cada nuevo tick, `Ticks` se incrementa en 1. La diferencia entre el valor actual y el anterior de `Ticks` — `CurrentTradeVolume` — representa el número de actualizaciones de precio ocurridas desde la última evaluación del indicador.

La guarda `If PreviousTickCount > 0` previene un delta espurio en el primer tick de una nueva barra, cuando `PreviousTickCount` acaba de resetearse a `0` y todavía no existe punto de referencia.

> **Importante — qué mide realmente `Ticks`:** `Ticks` cuenta **eventos de actualización de precio**, no contratos o acciones negociadas. Cada vez que el precio cambia dentro de la barra, `Ticks` se incrementa en 1, independientemente del volumen detrás de ese cambio. Una orden institucional de 2.000 contratos puede registrarse como una sola actualización de tick o como varias, dependiendo de cómo el exchange reporte la ejecución. Dos órdenes retail consecutivas al mismo precio pueden contar como un único tick si el precio no cambia entre ellas. `CurrentTradeVolume` es por tanto una aproximación de la intensidad de actividad de trading, no un recuento directo de contratos. Consulta la sección de Limitaciones para una discusión completa.

### 3. Clasificación de block trades

```pascal
If CurrentTradeVolume >= BigBlockTradeSize Then
    BigBlockVolume = BigBlockVolume + CurrentTradeVolume;
```

Si el delta de ticks alcanza o supera `BigBlockTradeSize`, la actualización se clasifica como un block trade y su delta se añade al acumulador `BigBlockVolume`. Este acumulador crece a lo largo de la barra y solo se resetea cuando abre una nueva barra.

### 4. Cálculo del porcentaje

```pascal
If Ticks > 0 Then
    BigBlockPercentage = (BigBlockVolume / Ticks) * 100;
```

`BigBlockPercentage` expresa qué proporción de la actividad total de ticks ha sido clasificada como actividad de block trade. La guarda `If Ticks > 0` previene una división por cero, aunque en la práctica `Ticks` siempre será positivo dentro del bloque `If LastBarOnChart`.

### 5. Lógica de alerta

```pascal
Plot1(BigBlockPercentage, "BlockPct");

If BigBlockPercentage > AlertThresholdPct Then
    Alert("High block trade activity detected");
```

El porcentaje se dibuja continuamente y se compara con `AlertThresholdPct`. Cuando la actividad de bloque supera el umbral, se dispara una alerta. La condición de alerta se evalúa en cada tick, por lo que puede dispararse múltiples veces dentro de la misma barra si la condición permanece verdadera a través de actualizaciones sucesivas.

### 6. Reset de barra

```pascal
If BarStatus(1) = 2 Then
Begin
    CurrentTradeVolume  = 0;
    PreviousTickCount   = 0;
    BigBlockVolume      = 0;
    BigBlockPercentage  = 0;
End
Else
    PreviousTickCount = Ticks;
```

`BarStatus(1) = 2` señala que la barra actual acaba de cerrar. Todos los acumuladores se resetean en preparación para la siguiente barra. De forma crítica, `PreviousTickCount` solo se actualiza cuando la barra **no** está cerrando — la rama `Else` asegura que en el tick de cierre de barra, la referencia se resetea a `0` en lugar de establecerse al recuento final de ticks de la barra cerrada, lo que crearía un delta falso en el primer tick de la nueva barra. Consulta la sección v1 vs v2 para la formulación original de este reset y por qué el orden importa.

### 7. Plots de referencia

```pascal
Plot2(AlertThresholdPct, "Threshold");
Plot3(0, "ZeroLine");
```

`Plot2` y `Plot3` se colocan fuera del bloque `If LastBarOnChart`, por lo que se dibujan en todas las barras históricas. Esto es intencional — la línea de umbral y la línea base cero proporcionan una referencia visual consistente en el subgráfico del indicador independientemente de si se están mostrando datos históricos.

---

## v1 vs v2: La diferencia

Ambas versiones implementan la misma lógica de detección. La evolución aborda la claridad de nombres y un sutil problema de orden de inicialización.

### v1 — Funcional pero con reset dependiente del orden

v1 actualiza `LastV` (la referencia de ticks) y luego resetea todas las variables al cierre de barra en el mismo bloque secuencial:

```pascal
LastV = Ticks;

If Barstatus(1) = 2 Then
Begin
    TradeV    = 0;
    LastV     = 0;
    BigTradeV = 0;
End;
```

El resultado neto es correcto — `LastV` termina en `0` cuando la barra cierra — pero solo porque el reset se ejecuta después de la asignación. El código depende del orden de ejecución en lugar de expresar la intención directamente. Si los dos bloques se reordenaran sin entender esta dependencia, se introduciría un bug silencioso: `PreviousTickCount` llevaría el recuento final de ticks de la barra cerrada al primer tick de la nueva barra, generando un gran delta espurio en la primera clasificación de trade de la nueva barra.

### v2 — Rama `Else` explícita para intención inequívoca

v2 reestructura el reset usando una rama `Else` que hace los dos casos mutuamente excluyentes:

```pascal
If BarStatus(1) = 2 Then
Begin
    CurrentTradeVolume  = 0;
    PreviousTickCount   = 0;
    BigBlockVolume      = 0;
    BigBlockPercentage  = 0;
End
Else
    PreviousTickCount = Ticks;
```

`PreviousTickCount` ahora solo se actualiza cuando la barra está activa. Al cierre de barra, se resetea. La lógica es autodocumentada: un lector no necesita trazar el orden de ejecución para entender qué ocurre en cada caso.

v2 también elimina la variable intermedia redundante `TotalTicks` presente en v1, que era siempre igual a `Ticks` en el punto de uso y no aportaba ninguna información. La división usa `Ticks` directamente.

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Estimación del delta de ticks** | ✓ | ✓ |
| **Acumulación de volumen de bloque** | ✓ | ✓ |
| **Alerta por umbral** | ✓ | ✓ |
| **Rama `Else` para reset (inequívoco)** | — | ✓ |
| **Variable intermedia `TotalTicks`** | ✓ (redundante) | ✗ eliminada |
| **Nombres de variables descriptivos** | `TradeV`, `LastV`, `BigTradeV`, `BigBlockPct` | `CurrentTradeVolume`, `PreviousTickCount`, `BigBlockVolume`, `BigBlockPercentage` |
| **Nombres de inputs descriptivos** | `BigblockTradeSize`, `ThresholdAlertPct` | `BigBlockTradeSize`, `AlertThresholdPct` |

---

## Parámetros

| Parámetro | Por defecto | Descripción |
|-----------|-------------|-------------|
| `BigBlockTradeSize` | 1000 | Delta mínimo de ticks requerido para clasificar una actualización como block trade. Las actualizaciones con un delta inferior a este valor se tratan como actividad retail o de ruido. |
| `AlertThresholdPct` | 66 | Porcentaje de actividad total de ticks que debe provenir de block trades para disparar una alerta. Un valor de 66 significa que los block trades deben representar dos tercios o más de toda la actividad de tick de la barra. |

**Sobre la calibración de `BigBlockTradeSize`:** El umbral apropiado depende del instrumento y sus patrones típicos de actividad de ticks. En futuros del ES durante sesiones activas, un delta de 1.000 puede capturar solo los prints institucionales más grandes; en instrumentos menos líquidos o sesiones más tranquilas, un valor más bajo puede ser más apropiado. Este parámetro requiere calibración empírica contra el comportamiento histórico de ticks del instrumento objetivo.

**Sobre la calibración de `AlertThresholdPct`:** Un umbral del 66% implica que los block trades no solo están presentes sino que son dominantes — dos de cada tres actualizaciones de tick han sido clasificadas como grandes. Valores más bajos producirán alertas más frecuentes con potencialmente menor calidad de señal; valores más altos filtran solo la actividad de bloque más concentrada.

---

## Escenarios de interpretación

### Escenario A — Pico de actividad de bloque en la apertura de sesión

- El ES abre. Llega el primer tick. `PreviousTickCount = 0` — la guarda bloquea el cálculo del delta.
- Tick 2: `Ticks = 3`, `PreviousTickCount = 1`. `CurrentTradeVolume = 2`. Por debajo de `BigBlockTradeSize`. Flujo retail normal.
- Tick 8: `Ticks = 1.050`, `PreviousTickCount = 47`. `CurrentTradeVolume = 1.003 >= 1.000`. Block trade clasificado. `BigBlockVolume = 1.003`.
- `BigBlockPercentage = (1.003 / 1.050) * 100 = 95,5%`. Supera `AlertThresholdPct = 66`.
- **Alerta disparada.** Un clúster de grandes actualizaciones de precio dominó la actividad de tick de la barra en la apertura.

### Escenario B — Actividad retail distribuida, sin alerta

- Sesión de mediodía. Los deltas de ticks llegan consistentemente en pequeños clústeres: 2, 5, 3, 8, 4. Todos por debajo de `BigBlockTradeSize = 1.000`.
- `BigBlockVolume` permanece en `0`. `BigBlockPercentage = 0%`.
- Sin alerta. La barra refleja actividad de tick fragmentada y de escala retail.

### Escenario C — Actividad mixta, umbral no alcanzado

- Primera tarde. Varias actualizaciones clasificadas como bloque se acumulan: `BigBlockVolume = 800`.
- Total de ticks en el mismo momento: `Ticks = 1.600`.
- `BigBlockPercentage = (800 / 1.600) * 100 = 50%`. Por debajo del umbral del `66%`.
- Sin alerta. La actividad de bloque está presente pero no es lo suficientemente dominante para disparar.

### Escenario D — Cierre de barra y reset limpio

- La barra cierra. `BarStatus(1) = 2`. Todos los acumuladores se resetean a `0`. `PreviousTickCount = 0`.
- Primer tick de la nueva barra: `PreviousTickCount = 0` → la guarda bloquea el cálculo del delta. Sin clasificación espuria.
- Segundo tick: `PreviousTickCount > 0` → delta calculado normalmente. Inicio limpio de la nueva barra.

---

## Características clave

- **Acumulación `IntrabarPersist`:** Todas las variables de estado retienen su valor entre actualizaciones de tick dentro de la misma barra, permitiendo el seguimiento dentro de la barra de la composición de la actividad de tick sin recalcular desde cero en cada tick.
- **Ámbito `LastBarOnChart`:** La lógica de detección solo se ejecuta en la barra viva. Las barras históricas no se tocan, haciendo el indicador computacionalmente eficiente e inequívoco sobre su propósito exclusivamente en tiempo real.
- **Delta de ticks como proxy de trade:** Al diferenciar valores consecutivos de `Ticks`, el indicador aproxima la intensidad de cada actualización de precio sin requerir acceso a registros de trades individuales ni datos L2.
- **Reset con rama `Else` (v2):** El reset de barra y la actualización de referencia de ticks son mutuamente excluyentes por construcción, eliminando la fragilidad dependiente del orden presente en v1.
- **Plots de referencia en barras históricas:** `Plot2` (umbral) y `Plot3` (línea cero) se dibujan en todas las barras, proporcionando una línea de base visual estable en el subgráfico independientemente de dónde esté ocurriendo el cálculo en vivo.
- **Alerta en cada tick válido:** La condición de alerta se evalúa en cada actualización de tick, lo que significa que el indicador responde inmediatamente cuando se supera el umbral en lugar de esperar al cierre de barra.

---

## Limitaciones

### `Ticks` como proxy — qué mide realmente el indicador

La limitación más importante de este indicador es la interpretación de `Ticks`. En EasyLanguage, `Ticks` cuenta **eventos de actualización de precio dentro de la barra** — cada vez que el precio cambia, `Ticks` se incrementa en 1. No mide el número de contratos o acciones negociadas en cada evento.

La consecuencia es que `CurrentTradeVolume = Ticks - PreviousTickCount` no es un recuento de contratos por trade. Es un recuento de cuántas actualizaciones de precio ocurrieron entre dos evaluaciones consecutivas del indicador. Esta distinción tiene varias implicaciones prácticas:

- Una única orden institucional de 5.000 contratos puede llegar como una sola actualización de tick (un print, un cambio de precio) o como una ráfaga de muchos prints más pequeños a través de múltiples niveles de precio. En el primer caso, un único delta de `1` no alcanzaría `BigBlockTradeSize = 1.000` aunque la orden fuera enorme. En el segundo caso, la ráfaga podría generar muchos deltas pequeños, ninguno de los cuales supera individualmente el umbral.
- Dos órdenes retail consecutivas al mismo precio pueden registrarse como una única actualización de tick si no se produce ningún cambio de precio entre ellas, apareciendo efectivamente como un evento combinado.
- Los períodos de apertura de sesión y noticias typically comprimen muchos trades grandes en actualizaciones de tick rápidas y sucesivas, lo que puede inflar `CurrentTradeVolume` incluso cuando las órdenes individuales no son inusualmente grandes.

El indicador se entiende mejor por tanto como una medición de **densidad y agrupamiento de actualizaciones de tick** más que de volumen literal de block trades. Lecturas elevadas señalan que la actividad de tick llega en ráfagas concentradas en lugar de uniformemente — un patrón estadísticamente asociado con la actividad de grandes órdenes, pero no una medición directa de la misma.

### Acceso al volumen real de contratos — requisito de datos L2

Medir con precisión el volumen de contratos detrás de cada trade individual requiere acceso a **datos de mercado de Nivel 2 (L2)**, también conocidos como profundidad de mercado o datos de time-and-sales a nivel de trade individual. Los datos L2 proporcionan un registro de cada trade ejecutado con su tamaño exacto en contratos o acciones, el precio y el timestamp — el input raw necesario para clasificar prints individuales como block trades por recuento de contratos en lugar de por delta de ticks.

En TradeStation, acceder al volumen de contratos por trade a nivel de tick requiere una suscripción de datos que incluya detalle de time-and-sales más allá de las barras OHLCV estándar. La mayoría de los planes de datos estándar proporcionan agregados de volumen a nivel de barra; los registros de trades individuales están típicamente disponibles a través de suscripciones premium de tick data o feeds directos de exchange. Otras plataformas y brokers tienen una jerarquía análoga: las suscripciones estándar agregan el volumen a nivel de barra, mientras que las suscripciones de datos L2 o tick exponen los registros de trades individuales que harían posible la detección real de block trades.

Hasta que los datos L2 estén disponibles, la estimación basada en el delta de `Ticks` sigue siendo una aproximación computacionalmente accesible — útil para detectar actividad concentrada, siempre que el usuario entienda que está midiendo frecuencia de actualizaciones de precio en lugar de flujo de contratos.

---

## Casos de uso

**Monitorización de sesión intradiaria en futuros de índices de renta variable:** En ES o NQ, la actividad de block trades tiende a concentrarse en las aperturas de sesión, en torno a publicaciones de datos económicos y durante días de tendencia direccional impulsados por el posicionamiento institucional. El indicador proporciona una señal en tiempo real cuando la actividad de tick cambia del patrón fragmentado típico del flujo retail hacia el patrón de ráfagas asociado con grandes órdenes.

**Detección de actividad pre-ruptura:** La agrupación de block trades a menudo precede o acompaña a las rupturas de precio de rangos intradiarios. Un `BigBlockPercentage` elevado mientras el precio comprime cerca de un nivel clave puede servir como confirmación temprana de que los participantes institucionales están activos antes de que el movimiento sea visible en el precio.

**Filtro para otras señales:** El indicador puede actuar como filtro de calidad de volumen para otras señales de entrada — una señal de cruce o de patrón que coincide con alta actividad de bloque tiene un carácter diferente que la misma señal durante condiciones thin dominadas por retail.

**Temporalidades:** El indicador es significativo únicamente en temporalidades donde la dinámica de ticks intrabar es visible — barras de 1 minuto o más rápidas durante sesiones activas. En barras diarias, el comportamiento de ticks dentro de la barra no es accesible, y el diseño exclusivamente en tiempo real del indicador lo hace inadecuado para análisis histórico.

**Instrumentos:** Mejor adaptado a mercados de futuros líquidos (ES, NQ, CL, GC) donde la participación institucional es significativa y las ráfagas de actualizaciones de tick son una señal significativa. En instrumentos ilíquidos, las actualizaciones de tick esporádicas pueden generar grandes deltas por trading thin en lugar de actividad genuina de bloque, produciendo falsos positivos.

---

## Consideraciones para una futura v3

### 1. Bloque de ciclo de vida de barra formalizado

v2 aborda el reset dependiente del orden de v1 con una rama `Else`. Un refinamiento de v3 haría la intención aún más explícita al encerrar la rama `Else` en su propio bloque `Begin`/`End` y agrupar toda la lógica del ciclo de vida de barra bajo una sola región etiquetada:

```pascal
{--- Gestión del ciclo de vida de barra ---}
If BarStatus(1) = 2 Then
Begin
    {--- Barra cerrada: resetear todos los acumuladores ---}
    CurrentTradeVolume  = 0;
    PreviousTickCount   = 0;
    BigBlockVolume      = 0;
    BigBlockPercentage  = 0;
End
Else
Begin
    {--- Barra activa: actualizar referencia de ticks ---}
    PreviousTickCount = Ticks;
End;
```

Aunque EasyLanguage no requiere `Begin`/`End` para un `Else` de una sola instrucción, los delimitadores explícitos señalan a cualquier lector futuro que las dos ramas son contrapartes deliberadas — no una asignación que por casualidad precede a un reset.

### 2. Volumen real de contratos via datos L2

Una v3 que aborde la limitación de medición central reemplazaría el delta de `Ticks` con el volumen real de contratos por trade obtenido de datos L2 o time-and-sales. En TradeStation, esto requeriría bien una suscripción premium de tick data que exponga registros de trades individuales via `TradeVolume` o una función equivalente de time-and-sales, bien un feed de datos externo integrado via DLL o función externa para acceso a datos de trade a nivel de exchange.

Con volumen real por trade disponible, `BigBlockTradeSize` se convertiría en un umbral real de contratos — clasificar cualquier trade individual de 500 contratos o más como bloque — y `BigBlockPercentage` expresaría la fracción del volumen de la barra transaccionado en prints de tamaño bloque. Esto convertiría el indicador en un detector genuino de huella institucional en lugar de un monitor de densidad de ticks.

### 3. Throttling de alerta por barra

La alerta actual se dispara en cada tick válido, lo que puede generar alertas repetidas dentro de una sola barra cuando la actividad de bloque permanece persistentemente elevada. Una mejora de v3 introduciría un flag de alerta por barra para limitar la alerta a un disparo por barra:

```pascal
IntrabarPersist AlertFiredThisBar(False);

If BigBlockPercentage > AlertThresholdPct and not AlertFiredThisBar Then
Begin
    Alert("High block trade activity detected");
    AlertFiredThisBar = True;
End;
```

`AlertFiredThisBar` se resetearía junto con los demás acumuladores al cierre de barra, asegurando que cada barra pueda generar como máximo una alerta — reduciendo el ruido sin perder la señal en la barra donde el umbral se supera por primera vez.
