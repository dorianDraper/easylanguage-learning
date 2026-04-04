# Equity-Adaptive Donchian Mean Reversion — v1.0, v2.0 & v3.0

## Descripción de la Estrategia

La Equity-Adaptive Donchian Mean Reversion Strategy combina dos ideas distintas en un único sistema: un breakout del canal Donchian como disparador de entrada, y un mecanismo de sizing dinámico que escala la exposición al alza durante períodos de ganancia y la contrae durante drawdowns. La lógica de entrada es contraria — compra cuando el precio marca un nuevo mínimo y vende corto cuando marca un nuevo máximo, apostando por la reversión a la media en lugar de la continuación de tendencia. La capa de sizing introduce un efecto de compuesto: por cada cantidad fija de beneficio acumulado, el tamaño de posición crece un paso definido, hasta un máximo configurable.

> **Nota conceptual importante:** Utilizar breakouts del canal Donchian como señal de mean reversion es estructuralmente contraintuitivo. Los breakouts Donchian fueron diseñados originalmente — y validados empíricamente — como señales de seguimiento de tendencia. Esta tensión está documentada en las notas de investigación de esta estrategia y se discute en detalle en la sección de Psicología del Trading.

---

## Mecánica Central

### 1. Cálculo del Canal Donchian

La estrategia calcula el máximo más alto y el mínimo más bajo durante un período de lookback, desplazado una barra atrás para evitar sesgo de lookahead:

```pascal
DonchianLow  = Lowest(Low,  DonchianLength)[1];
DonchianHigh = Highest(High, DonchianLength)[1];
```

El offset `[1]` es crítico: significa que los límites del canal se calculan usando barras *completadas*, no la barra actual en progreso. Esto garantiza que la señal se active solo cuando el precio ha roto genuinamente el extremo del canal previo, no durante un spike intrabarra que puede no cerrar más allá del nivel.

### 2. Señales de Mean Reversion

Las señales de entrada son contrarias — la estrategia entra *contra* la dirección del breakout:

```pascal
LongSignal  = Low  < DonchianLow;   // Precio rompe por debajo del canal → compra (espera reversión al alza)
ShortSignal = High > DonchianHigh;  // Precio rompe por encima del canal → vende corto (espera reversión a la baja)
```

La lógica asume que una ruptura del extremo Donchian representa un movimiento de agotamiento — el precio se ha sobreextendido y es probable que revierta. Esta es la hipótesis de mean reversion. Si esta hipótesis se sostiene en la práctica depende en gran medida del instrumento y el régimen de mercado, y es la pregunta empírica central que plantea esta estrategia.

### 3. Sizing Adaptativo por Equity

Esta es la característica arquitectónicamente más distintiva de la estrategia. El tamaño de posición no es fijo; se recalcula en cada barra en función del beneficio neto acumulado de la estrategia:

```pascal
If AbsValue(NetProfit) >= RiskUnit Then
    TradeSizeAdjust = Round(NetProfit / RiskUnit, 0) * SizeStep
Else
    TradeSizeAdjust = 0;

TradeSize = BaseTradeSize + TradeSizeAdjust;
```

**Desglose de la fórmula:**

- `NetProfit / RiskUnit` calcula cuántas unidades de riesgo completas de beneficio (o pérdida) se han acumulado.
- `Round(..., 0)` convierte esto en un entero — solo cuentan las unidades de riesgo completas, no las fracciones.
- Multiplicar por `SizeStep` convierte el entero en un incremento de acciones.
- Sumar `TradeSizeAdjust` a `BaseTradeSize` produce el tamaño final de posición.

**La asimetría entre ganancias y pérdidas:** Cuando `NetProfit` es positivo, `TradeSizeAdjust` es positivo — el tamaño de posición crece. Cuando `NetProfit` es negativo, `TradeSizeAdjust` es negativo — el tamaño de posición se contrae por debajo de la base. Este es el comportamiento autocorrector: el sistema desapalanca automáticamente durante los drawdowns sin intervención manual.

> **Diferencia v1 vs v2+:** En v1, el ajuste de sizing solo se activa si `NetProfit >= ProfitStopLoss OR NetProfit <= -ProfitStopLoss` — usando una comprobación de umbral simple. Desde v2 en adelante, se usa `AbsValue(NetProfit) >= RiskUnit`, que es la formulación correcta y simétrica. La condición de v1 produce resultados idénticos en el caso positivo, pero es lógicamente más limpia en v2+.

### 4. Límites de Tamaño de Posición

```pascal
If TradeSize > MaxTradeSize Then
    TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
    TradeSize = MinTradeSize;
```

Dos límites fijos previenen el sizing extremo en cualquier dirección. El tope máximo evita el crecimiento descontrolado durante rachas ganadoras extendidas. El suelo mínimo garantiza que la estrategia siempre tenga exposición de mercado significativa — y también significa que la estrategia continúa operando incluso durante drawdowns, lo que tiene implicaciones de riesgo relevantes (ver Psicología del Trading).

### 5. Ejecución de Entradas

```pascal
If IsFlat and LongSignal  Then
    Buy       ("Donchian_MR_LE") Next Bar TradeSize Shares at Market;

If IsFlat and ShortSignal Then
    SellShort ("Donchian_MR_SE") Next Bar TradeSize Shares at Market;
```

El guard `IsFlat` (`MarketPosition = 0`) evita entradas mientras ya hay una posición abierta. Estaba ausente en v1 — ver la sección de evolución de versiones más abajo.

### 6. Gestión del Riesgo

```pascal
SetStopLoss(RiskUnit);
SetProfitTarget(RiskUnit);
```

`SetStopLoss` y `SetProfitTarget` son funciones nativas de EasyLanguage que colocan salidas simétricas alrededor del precio de entrada. Ambas se establecen en `RiskUnit` (por defecto: $500), creando una estructura de riesgo/beneficio 1:1 en cada operación en términos de dólares. Como el tamaño de posición varía, el beneficio o pérdida por acción cambia — pero el importe en dólares en riesgo en cada operación permanece constante.

---

## v1 → v2 → v3: Evolución de la Arquitectura de Código

Como en las otras estrategias de este repositorio, las tres versiones implementan la misma lógica de trading. La evolución es estructural.

### v1 — Mínimo y Directo

v1 es compacto pero tiene dos debilidades notables. Primero, no hay guard `IsFlat` — la estrategia podría intentar entrar mientras ya está en una posición (dependiendo del comportamiento de la plataforma para evitar entradas duplicadas). Segundo, el nombrado de parámetros es menos preciso: `InitialTradeSize` en lugar de `BaseTradeSize`, y `ProfitStopLoss` haciendo doble función como umbral de sizing y nivel de stop/target:

```pascal
// v1 — sin guard de posición, lógica de sizing inline
If Low < Lowest(Low, 21)[1] Then
    Buy Next Bar TradeSize Shares at Market;
```

La longitud Donchian también está hardcodeada a `21` en lugar de exponerse como parámetro.

### v2 — Estado Explícito y Parámetros con Nombre

v2 añade `IsFlat`, separa `RiskUnit` y `DonchianLen` como inputs propios, introduce `AbsValue()` para la condición de sizing simétrica, y usa variables booleanas con nombre `LongSetup` / `ShortSetup` para las señales:

```pascal
// v2 — guard de posición + señales con nombre
LongSetup = Low < Lowest(Low, DonchianLen)[1];
ShortSetup = High > Highest(High, DonchianLen)[1];

If IsFlat and LongSetup Then
    Buy Next Bar TradeSize Shares at Market;
```

### v3 — Separación Completa de Responsabilidades

v3 introduce variables dedicadas para `DonchianLow` y `DonchianHigh`, renombra las señales a `LongSignal` / `ShortSignal` (coherente con la convención de nomenclatura usada en este repositorio), y organiza el código en bloques claramente etiquetados:

```pascal
{ CANAL }
DonchianLow  = Lowest(Low,  DonchianLength)[1];
DonchianHigh = Highest(High, DonchianLength)[1];

{ SEÑALES }
LongSignal  = Low  < DonchianLow;
ShortSignal = High > DonchianHigh;

{ SIZING }
If AbsValue(NetProfit) >= RiskUnit Then
    TradeSizeAdjust = Round(NetProfit / RiskUnit, 0) * SizeStep
Else
    TradeSizeAdjust = 0;
```

Almacenar `DonchianLow` y `DonchianHigh` como variables con nombre en lugar de llamar a `Lowest()` y `Highest()` inline es tanto una mejora de legibilidad como una optimización menor — cada función se llama una vez por barra en lugar de potencialmente dos veces.

### Resumen

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Guard de posición `IsFlat`** | — | ✓ | ✓ |
| **`DonchianLength` como input** | — | ✓ | ✓ |
| **Condición simétrica `AbsValue()`** | — | ✓ | ✓ |
| **Variables de canal con nombre** | — | — | ✓ |
| **Separación señal/ejecución** | — | — | ✓ |
| **Etiquetas de orden con nombre** | — | — | ✓ |
| **Parámetros** | 4 | 6 | 6 |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `BaseTradeSize` | 1.000 | Tamaño base de posición en acciones antes de cualquier ajuste por equity. |
| `SizeStep` | 100 | Incremento de acciones añadido (o restado) por cada `RiskUnit` completa de beneficio neto. |
| `MaxTradeSize` | 2.000 | Tope fijo en el tamaño de posición durante períodos ganadores. |
| `MinTradeSize` | 100 | Suelo fijo en el tamaño de posición durante períodos de pérdida. |
| `RiskUnit` | 500 | Importe en dólares usado como umbral de sizing y como nivel de stop/target. |
| `DonchianLength` | 21 | Período de lookback para el cálculo del máximo y mínimo del canal. |

**Sobre el doble rol de `RiskUnit`:** Un único parámetro controla tanto cuándo se ajusta el tamaño de posición como cuánto se arriesga por operación. Este acoplamiento es intencional — la unidad de riesgo que define el sizing es la misma unidad usada para medir si una operación fue ganadora o perdedora. Separarlos en dos parámetros sería una extensión futura válida.

---

## Escenarios de Operación

### Escenario A — Escalado de Posición Durante Racha Ganadora

- Equity inicial: `NetProfit = $0` → `TradeSizeAdjust = 0` → `TradeSize = 1.000 acciones`
- ES cierra por debajo de `DonchianLow` → `LongSignal = True` → entrada a mercado, 1.000 acciones
- Target de beneficio ejecutado (+$500). `NetProfit = $500`.
- Recálculo siguiente barra: `Round(500/500, 0) * 100 = 100` → `TradeSize = 1.100 acciones`
- Segunda entrada larga a 1.100 acciones. Target ejecutado de nuevo.
- `NetProfit = $1.050` (500 + 550 del tamaño mayor). `Round(1050/500, 0) * 100 = 200` → `TradeSize = 1.200 acciones`
- Cada operación ganadora financia posiciones incrementalmente mayores.

### Escenario B — Desapalancamiento Automático Durante Drawdown

- Tras racha ganadora: `NetProfit = $2.000` → `TradeSize = 1.400 acciones`
- Tres stops consecutivos ejecutados. `NetProfit` cae a $500.
- `Round(500/500, 0) * 100 = 100` → `TradeSize = 1.100 acciones`
- Dos pérdidas más. `NetProfit = -$500`.
- `Round(-500/500, 0) * 100 = -100` → `TradeSize = 1.000 + (-100) = 900 acciones`
- El tamaño de posición se contrae automáticamente a medida que la equity se erosiona — sin ajuste manual necesario.

### Escenario C — Suelo Mínimo Durante Drawdown Profundo

- `NetProfit = -$4.500`. `TradeSizeAdjust = Round(-4500/500, 0) * 100 = -900`
- `TradeSize = 1.000 + (-900) = 100 acciones`
- Comprobación de suelo: `100 >= MinTradeSize (100)` → tamaño se mantiene en 100 acciones
- Pérdidas adicionales: `TradeSizeAdjust` produciría tamaños por debajo de 100, pero el suelo lo impide
- La estrategia continúa operando al tamaño mínimo, arriesgando $500 por operación en términos de dólares

---

## Características Clave

- **Sizing adaptativo por equity:** El tamaño de posición se ajusta automáticamente en función del beneficio neto acumulado, creando un efecto de compuesto natural durante períodos ganadores y un mecanismo de desapalancamiento incorporado durante los drawdowns.
- **Riesgo simétrico por operación:** `SetStopLoss` y `SetProfitTarget` ambos establecidos en `RiskUnit` — cada operación arriesga exactamente el mismo importe en dólares independientemente de la cantidad de acciones.
- **Simplicidad del canal Donchian:** La señal de entrada requiere solo dos cálculos (máximo y mínimo del canal) y una comparación por lado. La lógica es transparente y auditable.
- **Límites fijos de tamaño:** Los topes máximo y mínimo evitan el escalado descontrolado en cualquier dirección, haciendo el sizing acotado y predecible.
- **Offset `[1]` en el canal:** Calcular los niveles del canal sobre barras completadas elimina el sesgo de lookahead y garantiza que las señales se activen solo en cierres genuinos más allá del extremo previo.
- **Arquitectura autocorrectora:** No se necesita intervención externa para ajustar la exposición al riesgo — el sistema recalibra el tamaño de posición en cada barra basándose en métricas de equity observables.

---

## Psicología del Trading

El mecanismo de sizing adaptativo encarna un principio común a muchos enfoques profesionales de trading: **deja que tus ganadores financien tu riesgo, no tu capital base.** Cuando la estrategia rinde bien, despliega más capital en la siguiente operación — no porque tenga exceso de confianza, sino porque se ha ganado el derecho a hacerlo a través de una rentabilidad demostrada. Cuando rinde mal, retrocede automáticamente. El tamaño de posición se convierte en una medida en tiempo real de la validez actual de la estrategia.

La estructura de riesgo/beneficio 1:1 ($500 de stop, $500 de target) es deliberadamente austera. Implica que la estrategia necesita una tasa de acierto superior al 50% para ser rentable, colocando la carga del edge completamente en la calidad de la señal de entrada — el breakout del canal Donchian. Esto merece examinarse cuidadosamente.

**La tensión conceptual central:** La señal de entrada usa un breakout del canal Donchian para entrar *contra* la dirección del breakout. Esto es arquitectónicamente contraintuitivo. Los sistemas de breakout Donchian fueron validados empíricamente como herramientas de seguimiento de tendencia — el trabajo original de Richard Donchian, y más tarde el sistema Turtle Trading desarrollado por Richard Dennis, usaban los breakouts de canal para entrar *con* el breakout, no contra él. Un nuevo mínimo en un canal Donchian es más comúnmente el comienzo de una tendencia bajista que un punto de agotamiento.

Esto no significa que la estrategia no pueda funcionar — la reversión a la media en extremos de canal es un concepto legítimo — pero sí significa que la señal de entrada por sí sola es evidencia insuficiente de agotamiento. La investigación sobre este sistema sugiere que varios filtros mejoran significativamente la robustez de las entradas Donchian contrarias:

- **Confirmación de rechazo:** En lugar de `Low < DonchianLow`, requerir `Low < DonchianLow AND Close > DonchianLow` — la barra intentó romper pero fue rechazada, lo que es una señal de reversión real en lugar de simplemente un nuevo extremo.
- **Filtro de régimen ADX:** La lógica de mean reversion funciona mejor en mercados de rango (`ADX < umbral`). Operarla durante tendencias fuertes aumenta la probabilidad de entrar contra momentum sostenido.
- **Filtro RSI o z-score:** Requerir una condición adicional de sobrecompra/sobreventa (p. ej. `RSI < 20` para largos) añade una confirmación estadística de que el movimiento está genuinamente sobreextendido.
- **Confirmación de volumen:** Los movimientos de agotamiento reales suelen ir acompañados de expansión de volumen. Un filtro de volumen elevado puede separar reversiones climáticas de nuevos mínimos rutinarios.

La investigación que acompaña a esta estrategia también plantea una hipótesis de inversión interesante: si el sistema Donchian contrario tiene dificultades, puede ser porque la señal en sí tiene edge — pero en la dirección del seguimiento de tendencia. Testear la versión invertida (comprar nuevos máximos, vender nuevos mínimos) contra el mismo mecanismo de sizing es el siguiente paso natural de investigación.

> **Pregunta abierta de investigación:** ¿Tiene esta estrategia expectativa positiva con su lógica de señal actual, o el sizing adaptativo simplemente enmascara una señal de entrada débil compuesto las ganancias y amortiguando las pérdidas? Separar la contribución de la señal de entrada de la contribución del mecanismo de sizing — ejecutando ambas con sizing fijo y adaptativo de forma independiente — es la forma correcta de responder a esto.

---

## Casos de Uso

**Instrumentos:** La lógica de mean reversion es más aplicable a instrumentos que exhiben comportamiento de rango: índices de renta variable en regímenes de baja volatilidad, acciones individuales con reversión a la media, o pares de divisas con rangos de trading bien definidos. Evitar aplicar esta estrategia a instrumentos fuertemente tendenciales sin un filtro de régimen — la entrada contraria trabajará consistentemente contra el momentum sostenido.

**Marcos temporales:** El canal Donchian de 21 barras escala con el timeframe. En barras de 5 minutos captura el rango de las últimas ~1,75 horas; en barras diarias captura el rango del último mes. El timeframe apropiado depende de la hipótesis de reversión que se esté testando — reversiones de ruido intradía vs. reversiones de sobreextensión multidía son ideas de trading fundamentalmente diferentes.

**Perfil del trader:** Adecuada para traders sistemáticos interesados en la intersección del diseño de señales de entrada y la mecánica del sizing de posición. La estrategia es particularmente valiosa como **vehículo de investigación**: la separación limpia entre lógica de señal (canal Donchian) y lógica de sizing (adaptativo por equity) facilita aislar la contribución de cada componente en backtesting.

**Sobre la preparación para producción:** La versión actual requiere validación de varias preguntas abiertas — la hipótesis de inversión de señal, el impacto del suelo mínimo en el comportamiento del drawdown, y la robustez del supuesto de riesgo/beneficio 1:1 entre instrumentos — antes del despliegue. El mecanismo de sizing adaptativo es sofisticado y bien construido; la lógica de señal de entrada justifica una investigación más profunda antes de tratar esta estrategia como lista para producción.
