# Key Reversal (Básico) — v1.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción de la Estrategia

Key Reversal Básico es una estrategia de reconocimiento de patrones que identifica señales de reversión de una sola barra y coloca órdenes límite en la dirección de reversión anticipada. Un key reversal alcista ocurre cuando una barra hace un nuevo mínimo respecto a la barra anterior pero cierra por encima del cierre anterior — indicando que una extensión bajista fue rechazada y la presión compradora tomó el control. El key reversal bajista es el espejo. La estrategia entra con una orden límite ligeramente desplazada desde el cierre, buscando un pequeño retroceso tras la barra de señal en lugar de perseguir el precio a mercado.

Esta es una estrategia fundacional solo de entradas — no se definen salidas. Está diseñada para estudiar el comportamiento del patrón de key reversal de forma aislada antes de añadir stop loss, objetivo de beneficio o reglas de salida temporal en versiones posteriores.

---

## Mecánica Central

### 1. Detección del Patrón

```pascal
BullKeyRev = Low < Low[1] and Close > Close[1];
BearKeyRev = High > High[1] and Close < Close[1];
```

El patrón se define por dos condiciones simultáneas en una única barra:

**Bull Key Reversal:**
- `Low < Low[1]`: la barra hace un nuevo mínimo por debajo del mínimo de la barra anterior — una extensión bajista inicial que parece negativa.
- `Close > Close[1]`: la barra cierra por encima del cierre de la barra anterior — la presión compradora absorbió el movimiento bajista e impulsó el precio hacia arriba.

**Bear Key Reversal:**
- `High > High[1]`: la barra hace un nuevo máximo por encima del máximo de la barra anterior — una extensión alcista inicial.
- `Close < Close[1]`: la barra cierra por debajo del cierre de la barra anterior — la presión vendedora rechazó el movimiento alcista.

La combinación de estas dos condiciones en la misma barra crea la señal de reversión: el mercado *intentó* continuar en una dirección, *fracasó*, y cerró con convicción en la dirección opuesta. El extremo (nuevo mínimo o nuevo máximo) establece el punto de rechazo; el cierre establece la dirección de la convicción recuperada.

### 2. Definición Permisiva vs Clásica

Esta implementación usa una **definición permisiva** del patrón de key reversal. La definición clásica más estricta añade una tercera condición:

- **Bull clásico:** `Low < Low[1]` Y `Close > Close[1]` Y `Close > High[1]` — el cierre debe superar la barra anterior *completa*, no solo el cierre anterior.
- **Bear clásico:** `High > High[1]` Y `Close < Close[1]` Y `Close < Low[1]` — el cierre debe caer por debajo de la barra anterior completa.

La condición más estricta requiere un rechazo más dramático — la barra no solo cierra más alto que el cierre anterior sino que engulle completamente el rango de la barra anterior. Esto produce menos señales pero de mayor convicción.

La versión permisiva usada aquí (`Close > Close[1]` sin requerir `Close > High[1]`) genera más señales, incluyendo casos donde la barra de reversión cierra más alto que el cierre anterior pero aún dentro del rango de la barra anterior. Esto es apropiado para un contexto de aprendizaje — más señales significa más instancias del patrón para estudiar — pero en despliegue en vivo, la mayor frecuencia de señales conlleva una mayor tasa de falsos positivos.

```
Key Reversal Bull Clásico (estricto):     Key Reversal Bull Permisivo:

   High[1]  ──────────                       High[1]  ──────────
             │        │                               │
   Close[1] ─┤        │         Close ─────────────  │
             │        │                               │
             │        │         Close[1] ──────────  │
             │        │Close ─                        │
   Low[1]    │        │                      Low[1]   │
             ──────────                               ──────────
   Low ──                                   Low ──
   
   (Close debe superar High[1])            (Close solo necesita superar Close[1])
```

### 3. Órdenes de Entrada — Límite con Offset

```pascal
If BullKeyRev Then
    Buy Next Bar at Close of This Bar - LimitPoints Limit;
If BearKeyRev Then
    SellShort Next Bar at Close of This Bar + LimitPoints Limit;
```

En lugar de entrar a mercado en la siguiente barra, la estrategia coloca órdenes límite con un pequeño desplazamiento desde el cierre de la barra de señal:

- **Entrada alcista:** límite colocado `LimitPoints` *por debajo* del cierre. El largo se ejecuta solo si el precio retrocede a ese nivel en la siguiente barra, proporcionando una entrada marginalmente mejor que el cierre de la barra de señal.
- **Entrada bajista:** límite colocado `LimitPoints` *por encima* del cierre. El corto se ejecuta solo si el precio rebota ligeramente hasta ese nivel.

Este enfoque refleja una paciencia deliberada: *"el patrón ha aparecido — pero no estoy dispuesto a perseguir el precio. Esperaré una pequeña concesión antes de entrar."* El offset es pequeño por diseño (por defecto `0,05`) — no es un requisito de retroceso significativo, simplemente un buffer mínimo contra perseguir un cierre ya extendido.

Si la siguiente barra no opera hasta el nivel límite — por ejemplo, abre con un gap adicional en la dirección de la reversión — la orden expira sin ejecutarse. Esto es aceptable: un gap de continuación a menudo señala un movimiento de reversión más fuerte que habría sido mejor capturado al precio de cierre, pero la estrategia prioriza la disciplina de entrada sobre la tasa de ejecución.

### 4. Sin Reglas de Salida

La estrategia define solo entradas. No hay stop loss, objetivo de beneficio ni condiciones de salida temporales. En EasyLanguage, esto significa que las posiciones permanecen abiertas hasta que una entrada de reversión en la dirección opuesta cierra la posición existente y abre una nueva — creando efectivamente un sistema always-in-the-market con entradas determinadas por señales de key reversal en cualquier dirección.

Esta es una elección de diseño intencional para una estrategia de aprendizaje: estudiar el comportamiento del patrón sin interferencia de las salidas permite un análisis limpio de con qué frecuencia se materializa el seguimiento de la reversión y durante cuántas barras. Las reglas de salida se añadirán en versiones posteriores una vez que se comprenda el comportamiento del patrón.

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `LimitPoints` | 0,05 | Offset desde el cierre de la barra de señal usado para fijar el precio de la orden límite. |

**Sobre `LimitPoints`:** El valor por defecto de `0,05` está calibrado para precios de acciones donde un offset de 5 céntimos es una concesión significativa pero pequeña. Para contratos de futuros, este valor debe escalarse al tamaño de tick del instrumento — para futuros ES, un offset significativo podría ser 0,25 a 1,00 puntos dependiendo del rango de barra típico. Establecer `LimitPoints` demasiado grande reduce la tasa de ejecución; establecerlo demasiado pequeño se aproxima al comportamiento de una orden a mercado.

---

## Escenarios de Operación

### Escenario A — Bull Key Reversal, Límite Ejecutado

- Barra anterior: Mínimo en 44,80, Cierre en 44,90.
- Barra de señal: Mínimo en 44,70 (`Low < Low[1]` ✓), Cierre en 44,95 (`Close > Close[1]` ✓). `BullKeyRev = True`.
- Orden límite colocada en `44,95 − 0,05 = 44,90`.
- La siguiente barra opera brevemente hasta 44,88 antes de recuperarse. Límite ejecutado a 44,90.
- Posición ahora larga. Sin salida definida — la posición permanece abierta hasta que se active una entrada de bear key reversal.

### Escenario B — Bull Key Reversal, Límite No Ejecutado (Gap de Continuación)

- Misma barra de señal con cierre en 44,95. Límite en 44,90.
- La siguiente barra abre en 45,20 (gap alcista en la dirección de la reversión). El precio nunca opera hasta 44,90.
- El límite expira sin ejecución. Sin posición.
- El movimiento de reversión continuó con fuerza sin concesión — la estrategia perdió la entrada al priorizar la disciplina de precio.

### Escenario C — Bear Key Reversal

- Barra anterior: Máximo en 46,50, Cierre en 46,40.
- Barra de señal: Máximo en 46,60 (`High > High[1]` ✓), Cierre en 46,30 (`Close < Close[1]` ✓). `BearKeyRev = True`.
- Orden límite colocada en `46,30 + 0,05 = 46,35`.
- La siguiente barra rebota ligeramente hasta 46,36. Corto ejecutado a 46,35.
- Posición ahora corta. Sin salida definida.

### Escenario D — Patrón Detectado Pero Sin Fuerza Clásica

- Barra anterior: Máximo en 46,50, Cierre en 46,40, Mínimo en 46,20.
- Barra de señal: Mínimo en 46,15 (`Low < Low[1]` ✓), Cierre en 46,45 (`Close > Close[1]` ✓).
- `BullKeyRev = True` — el patrón se activa bajo la definición permisiva.
- Nota: Cierre en 46,45 está por debajo del High[1] en 46,50. Bajo la definición clásica estricta, esto *no* calificaría como key reversal — el cierre no superó el máximo de la barra anterior.
- La entrada se activa independientemente. Esto ilustra la diferencia práctica entre las dos definiciones.

---

## Características Clave

- **Patrón de una sola barra:** La señal completa está contenida en una barra y su relación con la barra anterior. No se requiere ningún lookback más allá de `[1]` — el patrón es inmediato y computacionalmente mínimo.
- **Estructura de rechazo:** La combinación de un nuevo extremo y un cierre de reversión codifica un evento de estructura de mercado: los participantes que llevaron el precio al nuevo extremo fueron superados por el lado opuesto antes de que la barra cerrara.
- **Definición permisiva:** `Close > Close[1]` (en lugar de `Close > High[1]`) produce más instancias de señal, haciéndola más adecuada para el estudio del patrón pero requiriendo conciencia de la mayor tasa de falsos positivos en uso en vivo.
- **Entrada límite con offset:** El offset de `LimitPoints` introduce un requisito mínimo de paciencia — la estrategia espera una pequeña concesión de precio tras la señal en lugar de entrar inmediatamente al cierre.
- **Sin salidas por diseño:** La arquitectura solo de entradas es intencional para el contexto de aprendizaje. Permite el estudio aislado del seguimiento direccional del patrón sin interferencia de reglas de salida.

---

## Psicología del Trading

El patrón de key reversal codifica una narrativa de mercado específica: **el movimiento intentado fracasó.** Cuando el precio alcanza un nuevo mínimo pero la barra cierra más alto, significa que los vendedores llevaron el precio a un extremo y luego los compradores entraron con suficiente fuerza no solo para detener el descenso sino para revertirlo — todo dentro de una única barra. El nuevo mínimo es una trampa; el cierre más alto es la evidencia de que la trampa fue rechazada.

Entrar con una orden límite por debajo del cierre (para alcistas) es una expresión de paciencia medida. La señal ha aparecido, pero la estrategia no reacciona con urgencia — espera a que el mercado ofrezca un precio ligeramente mejor. Esto refleja el reconocimiento de que las barras de reversión a menudo van seguidas de una continuación menor en la dirección de la reversión antes de que comience el movimiento más grande. El offset no intenta capturar un retroceso profundo; simplemente evita la peor ejecución al no aceptar el precio de cierre por su valor nominal.

La ausencia de salidas es la decisión de diseño más importante de esta versión. Una estrategia sin salidas no es un sistema de trading completo — es una herramienta de estudio del patrón. La intención es observar: ¿con qué frecuencia la reversión tiene seguimiento? ¿Durante cuántas barras? ¿El patrón funciona de forma diferente en días tendenciales versus días de rango? Estas preguntas solo pueden responderse con limpieza cuando las salidas no interfieren con la observación.

La distinción permisiva vs clásica también contiene una lección psicológica: definir un patrón de forma más estricta produce menos señales pero de mayor calidad. La disciplina de esperar un patrón más fuerte — `Close > High[1]` en lugar de simplemente `Close > Close[1]` — es la misma disciplina que separa las operaciones de alta convicción del ruido. Ambas definiciones merecen estudiarse, pero son hipótesis diferentes sobre qué constituye una reversión significativa.

---

## Casos de Uso

**Instrumentos:** El patrón de key reversal es agnóstico al instrumento — solo requiere datos de barra OHLC. Se estudia principalmente en gráficos diarios de acciones individuales y futuros de índices de renta variable, donde las reversiones de una sola barra en niveles de soporte/resistencia tienen significado estructural. En gráficos intradiarios, el patrón se activa con más frecuencia y con menor convicción promedio.

**Marcos temporales:** En barras diarias, un key reversal en un mínimo de varias semanas es un evento significativo — representa una sesión completa de descubrimiento de precios que termina en rechazo. En barras de 5 minutos, el mismo patrón puede reflejar solo unos minutos de actividad de trading. El peso interpretativo del patrón escala con el marco temporal.

**Como herramienta de aprendizaje:** Esta versión está diseñada explícitamente como línea de base de investigación. El enfoque de estudio recomendado es ejecutar la estrategia sobre datos históricos y examinar cada entrada en detalle — observando si el patrón llevó a una reversión sostenida, cuántas barras tardó en materializarse, y qué condiciones de mercado (tendencia, volatilidad, volumen) acompañaron a las señales más fuertes. Este análisis informa directamente las elecciones de parámetros y las reglas de salida para la versión siguiente.

**Relación con Key Reversal (Avanzado):** Esta versión básica comparte el concepto de reversión con la estrategia Key Reversal más sofisticada documentada en otro lugar de este repositorio, que usa detección de mínimos estructurales basada en MRO, un canal Donchian para el filtrado de significatividad, y un mecanismo de scale-in adaptativo a la equity. La versión básica estudia la señal del patrón en bruto; la versión avanzada añade el marco estructural y estadístico que requiere un sistema de producción.
