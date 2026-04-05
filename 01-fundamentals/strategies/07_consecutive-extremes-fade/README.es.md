# Consecutive Extremes Fade — v1.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Consecutive Extremes Fade es una estrategia de mean-reversion que entra en contra de rachas de momentum a corto plazo. En lugar de detectar una ruptura de nivel de precio, cuenta barras consecutivas haciendo nuevos máximos o nuevos mínimos y entra en una posición de fading una vez que la racha alcanza una longitud mínima configurable. La premisa es que los extremos consecutivos sostenidos representan sobreextensión a corto plazo — un precio que ha hecho nuevos mínimos en múltiples barras consecutivas probablemente ha ido demasiado lejos en una dirección y es candidato a un rebote.

Ambas direcciones de entrada son contrarias: la estrategia compra durante una racha de mínimos consecutivos (esperando un rebote) y vende corto durante una racha de máximos consecutivos (esperando un retroceso). Las salidas se gestionan con un objetivo de beneficio fijo y un stop loss aplicados por posición.

---

## Mecánica Central

### 1. Contadores de Extremos Consecutivos

```pascal
If High > High[1] Then
    HighsCount = HighsCount + 1
Else
    HighsCount = 0;

If Low < Low[1] Then
    LowsCount = LowsCount + 1
Else
    LowsCount = 0;
```

`HighsCount` incrementa en uno en cada barra donde el máximo actual supera el máximo de la barra anterior — un nuevo máximo a corto plazo. Se resetea a cero en el momento en que cualquier barra no logra hacer un nuevo máximo. `LowsCount` hace lo mismo para barras que hacen mínimos sucesivos.

Este es un **contador de racha consecutiva**, no un lookback de canal. La distinción importa:

- `Highest(High, N)` encuentra el máximo absoluto dentro de N barras — no le importa si esos máximos fueron consecutivos.
- `HighsCount >= 2` requiere que las últimas 2 barras hayan hecho cada una un máximo más alto que la barra anterior — una racha de momentum direccional.

Un `HighsCount` de 3 significa que tres barras consecutivas hicieron cada una un nuevo máximo: barra−2 > barra−3, barra−1 > barra−2, barra−0 > barra−1. Esta es una condición más ajustada y específica que simplemente encontrar el máximo más alto en 3 barras.

**Cómo se comporta el contador:**

```
Barra:      1     2     3     4     5     6     7
High:      45    46    47    46    48    49    48
HighsCount: 1     2     3     0     1     2     0

Barra 4: High (46) < High[1] (47) → contador se resetea a 0
Barra 7: High (48) < High[1] (49) → contador se resetea a 0
```

En la barra 6, `HighsCount = 2` — dos máximos consecutivos nuevos. Con `HighsToSell = 2`, la condición de entrada corta se cumple.

### 2. Lógica de Entrada Contraria

```pascal
If LowsCount >= LowsToBuy Then
    Buy Next Bar at Close of This Bar - LimitPoints Limit;

If HighsCount >= HighsToSell Then
    SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

Ambas entradas son **contra-direccionales** — la estrategia fadea la racha de momentum:

- **Entrada larga durante una racha de mínimos:** Cuando `LowsCount >= LowsToBuy`, el mercado ha hecho `LowsToBuy` mínimos consecutivos más bajos. La estrategia compra, esperando que la racha bajista se agote y revierta.
- **Entrada corta durante una racha de máximos:** Cuando `HighsCount >= HighsToSell`, el mercado ha hecho `HighsToSell` máximos consecutivos más altos. La estrategia vende corto, esperando que la racha alcista se desvanezca.

Esta es lógica de mean-reversion aplicada a una estructura de momentum: los extremos consecutivos se tratan como sobreextensión en lugar de señales de continuación. La estrategia no interpreta una racha de nuevos mínimos como una tendencia a seguir — la interpreta como una condición estirada a fadear.

**Orden límite con offset:** Ambas entradas usan una orden límite desplazada desde el cierre de la barra de señal:

- Límite largo: `Close of This Bar - LimitPoints` — colocado ligeramente por debajo del cierre, requiriendo un pequeño retroceso adicional antes de la ejecución.
- Límite corto: `Close of This Bar + LimitPoints` — colocado ligeramente por encima del cierre, requiriendo un pequeño rebote antes de la ejecución.

El pequeño offset (por defecto `0,02`) evita perseguir el precio de cierre directamente y proporciona una entrada marginalmente mejor. Como se señala en otras estrategias de este repositorio, `Close of This Bar` en una orden límite `Next Bar` produce menos ejecuciones en mercados con gaps.

### 3. Gestión del Riesgo

```pascal
SetStopPosition;
SetProfitTarget(ProfTgt);
SetStopLoss(StopLoss);
```

`SetStopPosition` aplica las funciones de stop subsiguientes a la posición total en lugar de por acción o por contrato. `SetProfitTarget` y `SetStopLoss` son simétricos con sus valores por defecto ($50 cada uno), creando una ratio riesgo/beneficio de 1:1. Ambos están activos simultáneamente — el que se alcance primero cierra la posición.

Con stop y target simétricos, la estrategia necesita una tasa de acierto superior al 50% para ser rentable. La hipótesis de mean-reversion proporciona el edge direccional: si los extremos consecutivos tienen estadísticamente más probabilidad de revertir que de continuar, la tasa de acierto debería sostener la ratio 1:1 en una muestra suficiente.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `LowsToBuy` | 2 | Mínimo de mínimos consecutivos más bajos requeridos para activar una entrada larga. |
| `HighsToSell` | 2 | Mínimo de máximos consecutivos más altos requeridos para activar una entrada corta. |
| `LimitPoints` | 0,02 | Offset desde el cierre de la barra de señal para el precio de la orden límite. |
| `ProfTgt` | $50 | Objetivo de beneficio por posición en moneda de la cuenta. |
| `StopLoss` | $50 | Stop loss por posición en moneda de la cuenta. |

**Sobre `LowsToBuy` y `HighsToSell`:** El valor por defecto de `2` es la racha mínima significativa — una sola barra haciendo un nuevo extremo es ruido; dos barras consecutivas sugieren una racha direccional a corto plazo. Aumentar a `3` o `4` requiere una racha más sostenida antes de la entrada, reduciendo la frecuencia de señales pero potencialmente mejorando su calidad. Los valores por encima de `5` producirán muy pocas señales en la mayoría de instrumentos.

**Sobre el stop y target simétricos:** Los valores por defecto de $50 están calibrados para acciones. Para futuros, deben escalarse al `BigPointValue` del instrumento. Para futuros ES a $50/punto, un stop y target de $50 equivalen a 1 punto cada uno — extremadamente ajustados para cualquier prueba significativa de la hipótesis de mean-reversion en un instrumento con rangos diarios típicos de 30–60 puntos.

---

## Escenarios de Operación

### Escenario A — Entrada Larga Tras Mínimos Consecutivos

```
Barra:      1      2      3      4      5
Low:      44,80  44,60  44,40  44,55  44,70
LowsCount:   1      2      3      0      0
```

- Barra 3: `LowsCount = 3 >= LowsToBuy (2)`. Señal activada.
- Límite largo colocado en `Close (44,45) - 0,02 = 44,43`.
- Barra 4: opera brevemente hasta 44,43 antes de recuperarse. Largo ejecutado a 44,43.
- `ProfTgt = $50` activo. `StopLoss = $50` activo.
- El precio sube. El objetivo de beneficio se ejecuta. Operación sale con +$50.

### Escenario B — Entrada Corta Tras Máximos Consecutivos

```
Barra:       1      2      3
High:      46,20  46,45  46,68
HighsCount:   1      2      3
```

- Barra 3: `HighsCount = 3 >= HighsToSell (2)`. Señal activada.
- Límite corto colocado en `Close (46,60) + 0,02 = 46,62`.
- La siguiente barra rebota hasta 46,62. Corto ejecutado.
- El precio retrocede. El objetivo de beneficio se ejecuta. Operación sale con +$50.

### Escenario C — Contador se Resetea, Sin Entrada

```
Barra:       1      2      3
Low:       44,80  44,60  44,65
LowsCount:    1      2      0
```

- Barra 3: `Low (44,65) > Low[1] (44,60)` → `LowsCount` se resetea a 0.
- Racha rota. No se activa ninguna entrada aunque `LowsCount` alcanzó 2 en la barra 2.
- El contador debe estar en o por encima de `LowsToBuy` en la barra actual para que la entrada se active.

### Escenario D — Límite No Ejecutado

- `LowsCount >= LowsToBuy` en la barra X. Límite largo en `44,43`.
- La siguiente barra abre en 44,60 y sube inmediatamente. Nunca llega a 44,43.
- El límite expira sin ejecución. Sin posición.
- En la barra X+1, `LowsCount` puede que ya no sea `>= LowsToBuy` dependiendo de si se hizo otro mínimo más bajo.

---

## Características Clave

- **Detección de racha consecutiva:** El mecanismo de contador identifica rachas de momentum direccional barra a barra, reseteándose inmediatamente en cualquier barra que rompa la racha. Es más específico que un lookback de canal.
- **Lógica de entrada contraria:** Ambas direcciones fadean la racha de momentum — comprando en mínimos consecutivos, vendiendo en máximos consecutivos. La estrategia trata los extremos sostenidos como sobreextensión en lugar de señales de tendencia.
- **Superficie de parámetros mínima:** Dos umbrales de racha, un offset límite y dos niveles de riesgo. La estrategia es fácil de testear e iterar.
- **Riesgo/beneficio simétrico:** Stop y target iguales con los valores por defecto crean una estructura de riesgo equilibrada donde el edge debe provenir completamente del sesgo direccional de la señal.
- **Entrada límite con offset:** Ambas entradas requieren una pequeña concesión de precio tras la barra de señal, evitando perseguir directamente el cierre ya extendido con una orden a mercado.
- **`SetStopPosition`:** Stop y target aplicados a la posición total, no por acción — apropiado para trading de acciones de tamaño fijo donde el riesgo en dólares por posición es la unidad natural.

---

## Psicología del Trading

Consecutive Extremes Fade codifica una creencia específica sobre el mercado: **las rachas de momentum a nivel de barra tienden a agotarse tras una racha corta.** Un mercado que ha hecho mínimos más bajos durante dos o tres barras consecutivas ha sido impulsado en una dirección por vendedores persistentes. La estrategia apuesta a que la presión vendedora es temporal — que los compradores entrarán una vez que la racha a corto plazo alcance un umbral.

Esta no es una tesis de mean-reversion macro (el instrumento volverá a su media a largo plazo) sino una tesis de mean-reversion micro (el impulso direccional a corto plazo perderá fuerza en pocas barras). La distinción importa para la calibración de parámetros: el umbral de `LowsToBuy` de 2 es deliberadamente pequeño porque la hipótesis trata sobre el agotamiento de rachas a corto plazo, no sobre reversiones de tendencias de varios días.

La postura contraria requiere una relación psicológica diferente con la señal del mercado que el seguimiento de tendencia. Cuando `LowsCount` alcanza 2, el mercado está cayendo — se siente peligroso comprar. El edge de la estrategia, si existe, proviene de actuar contra ese sentimiento de forma sistemática. El offset de la orden límite añade una capa de paciencia: en lugar de comprar al cierre de la barra en caída, la estrategia espera una pequeña concesión más, reconociendo que el movimiento puede tener una breve continuación antes de revertir.

El stop y target simétricos codifican una expectativa de resultado neutral: la estrategia no sabe *hasta dónde* llegará la reversión, solo que espera una. El objetivo de beneficio captura una porción definida del rebote esperado; el stop loss acota la pérdida si la racha continúa en lugar de revertir.

---

## Casos de Uso

**Instrumentos:** Más aplicable a instrumentos líquidos que exhiben comportamiento de mean-reversion a corto plazo a nivel de barra — futuros de índices de renta variable (ES, NQ) en sesiones de rango o baja volatilidad, acciones individuales con oscilaciones a corto plazo identificables, y futuros de materias primas con swings intradiarios regulares. Los instrumentos fuertemente tendenciales donde los máximos o mínimos consecutivos son la norma en lugar de la excepción producirán frecuentes operaciones perdedoras.

**Marcos temporales:** En barras diarias, dos mínimos consecutivos más bajos es una caída de dos días — un retroceso a corto plazo significativo en muchos mercados. En barras de 5 minutos, dos mínimos consecutivos más bajos abarca 10 minutos — un movimiento muy a corto plazo que puede ser ruido en futuros líquidos. Los umbrales `LowsToBuy`/`HighsToSell` deben calibrarse en relación a la longitud de racha típica para el marco temporal e instrumento elegidos.

**Como línea de base de investigación:** Esta versión es deliberadamente mínima — sin filtro de tendencia, sin filtro de hora del día, sin confirmación adicional. Está diseñada para aislar y estudiar la señal de agotamiento de racha en bruto antes de añadir filtros. Las preguntas naturales de investigación son: ¿cuál es la tasa de acierto de la señal en bruto? ¿La señal funciona de forma diferente en regímenes de mercado tendencial vs. de rango? ¿Añadir una longitud mínima de racha de 3 o 4 mejora o perjudica los resultados? Estas preguntas motivan directamente el diseño de una v2.

**Relación con otras estrategias:** El contador de extremos consecutivos es una arquitectura de señal diferente tanto al breakout de canal Donchian usado en Opening Gap como a la detección de mínimos estructurales basada en MRO usada en Key Reversal (Avanzado). Las tres identifican extremos de precio, pero a través de lentes diferentes: límites de canal absolutos, escaneo de ocurrencia más reciente, y rachas de barras consecutivas. Comparar sus frecuencias de señal y características de rendimiento en el mismo instrumento es un ejercicio de investigación productivo.
