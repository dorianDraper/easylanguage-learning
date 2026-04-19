# Intermarket Filtered Trend Breakout — Investigación de Estrategia

🇺🇸 [English](strategy-research.md) | 🇪🇸 Español

> Este documento complementa el README técnico con el razonamiento macroeconómico detrás del diseño del filtro intermercado de la estrategia. Explica por qué se eligen los tres feeds de datos, cómo se codifican sus relaciones en la estrategia, qué miden realmente los filtros y dónde se queda corta la implementación actual respecto a la correlación estadística real. Está concebido como un documento de investigación vivo — las secciones sobre ejemplos de régimen incluyen marcadores de posición para gráficos que se añadirán a medida que avance la investigación empírica.

---

## 1. La tesis intermercado

Los mercados financieros no se mueven de forma aislada. Los índices de renta variable, las divisas y los bonos son todos expresiones de las mismas fuerzas macroeconómicas subyacentes — expectativas de crecimiento, inflación, apetito por el riesgo y flujos de capital. Cuando estas fuerzas cambian, lo hacen en todos los mercados simultáneamente, aunque no siempre a la misma velocidad ni con la misma magnitud.

La tesis central de esta estrategia es simple: **una tendencia en un índice de renta variable que está confirmada por movimientos alineados en los mercados asociados de divisas y bonos tiene más probabilidades de persistir que una tendencia que ocurre de forma aislada.** Por el contrario, una ruptura en el mercado primario que contradice el régimen señalado por los mercados secundarios es una señal de menor calidad — una en la que el contexto macro más amplio está trabajando en contra del trade.

Esta no es una idea nueva. El análisis intermercado es una disciplina reconocida desde al menos los trabajos fundacionales de John Murphy en los años 90, y las relaciones entre renta variable, bonos y divisas son de las más estudiadas en macrofinanzas. Lo que hace esta estrategia es codificar esas relaciones como filtros computables — transformando el razonamiento macro cualitativo en condiciones de entrada cuantitativas.

La estructura de tres mercados refleja una jerarquía deliberada:

- **Data1** es donde se gana o pierde dinero. Es el mercado de ejecución.
- **Data2 y Data3** son mercados de contexto. No generan trades — los filtran.

Una señal de tendencia en Data1 que pasa ambos filtros de contexto entra. Una que falla cualquiera de los dos no entra. El edge de la estrategia, si existe, proviene de la mejora incremental de calidad que la confirmación de contexto proporciona sobre las señales puras de ruptura de tendencia.

---

## 2. Los tres mercados — roles y relaciones

### Data1 — El mercado primario (índice de renta variable)

Los futuros sobre índices de renta variable — DAX, NQ, ES y similares — representan el agregado de beneficios esperados y el apetito por el riesgo de un mercado amplio. Son la expresión más directa del sentimiento inversor sobre el crecimiento económico y la rentabilidad empresarial.

Los índices de renta variable se eligen como mercado primario por tres razones. Primero, tienden a producir tendencias direccionales sostenidas impulsadas por cambios de régimen macro — el tipo de movimientos que las estrategias de seguimiento de tendencia están diseñadas para capturar. Segundo, son altamente líquidos, asegurando que las órdenes stop y límite se ejecuten cerca de sus precios cotizados. Tercero, su relación con divisas y bonos está bien documentada y es económicamente intuitiva, haciendo el diseño del filtro intermercado abordable.

La estrategia opera sobre Data1 para entradas, salidas, detección de tendencia y niveles de ruptura. Todo en el motor de señal se refiere exclusivamente a Data1.

### Data2 — El mercado de divisas (EURUSD)

Los pares de divisas codifican información sobre la fortaleza económica relativa, los flujos de capital y el sentimiento global de riesgo de una forma que los precios de renta variable por sí solos no capturan.

**Por qué EURUSD para el DAX:** El DAX es un índice de renta variable alemán, y Alemania es la mayor economía de la Eurozona. Cuando el euro se fortalece frente al dólar, típicamente refleja una mejora de los fundamentos económicos de la Eurozona o un entorno risk-on donde el capital fluye hacia activos europeos. Un euro debilitándose a menudo refleja sentimiento risk-off, estrés económico en la Eurozona, o fortaleza del dólar impulsada por demanda de activo refugio. La relación entre EURUSD y DAX no es fija — puede invertirse durante episodios macro específicos — pero como filtro general de régimen captura si el mercado de divisas está contando una historia macro consistente con el mercado de renta variable.

**Por qué un filtro de divisa para el NQ:** El Nasdaq 100 tiene una dinámica de divisa diferente. Las grandes empresas tecnológicas estadounidenses generan ingresos internacionales significativos, por lo que un dólar fuerte puede presionar las expectativas de beneficios incluso cuando el crecimiento doméstico permanece robusto. Más importante aún, EURUSD sirve como proxy del apetito global por el riesgo — cuando el euro sube frente al dólar, a menudo refleja un entorno risk-on más amplio que apoya a los mercados de renta variable globalmente, incluida la tecnología estadounidense.

El filtro codifica esta relación mediante una comparación simple: ¿está la divisa por encima o por debajo de su media móvil? Es un estado direccional, no una medición de magnitud.

```pascal
// CurrencyCorrelation = -1: el DAX tiende a moverse en dirección opuesta a la fortaleza del EURUSD
// El filtro pasa para entradas largas cuando EURUSD está POR DEBAJO de su MA
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

> **Marcador de gráfico:** Retornos diarios EURUSD vs. DAX, 2018–2024. Destacar períodos donde ambos se movieron en direcciones opuestas (régimen de correlación negativa) vs. períodos donde se movieron juntos (ruptura de correlación).

### Data3 — El mercado de bonos (Bund / US20Y)

Antes de analizar el papel del mercado de bonos como filtro, una relación mecánica es esencial: **los precios de los bonos y sus rendimientos (yields) se mueven siempre en direcciones opuestas**. Un bono paga una cantidad fija al vencimiento. Si su precio de mercado sube — porque muchos inversores quieren comprarlo — la rentabilidad efectiva para un nuevo comprador cae, ya que paga más por recibir el mismo pago fijo. Si su precio baja, la rentabilidad efectiva sube. Esta no es una tendencia empírica; es una identidad matemática. Cuando los analistas dicen "los yields cayeron", significan que los precios de los bonos subieron, y viceversa. A lo largo de este documento, las referencias a bonos "por encima de su MA" significan que los *precios* de los bonos están elevados — lo que corresponde a yields bajos, típicamente asociados con regímenes risk-off o de pesimismo sobre el crecimiento. Las referencias a bonos "por debajo de su MA" significan que los precios están deprimidos — los yields son elevados, reflejando típicamente expectativas de crecimiento, preocupaciones inflacionarias o un ciclo de subida de tipos.

Los mercados de bonos codifican expectativas sobre tipos de interés, inflación y riesgo macroeconómico de una forma que a menudo es más anticipada que los mercados de renta variable. Los precios de los bonos se mueven de forma inversa a los rendimientos: cuando los rendimientos suben, los precios de los bonos caen, y viceversa.

**La relación renta variable-bonos:** En la teoría macro estándar, la renta variable y los bonos tienden a estar negativamente correlacionados durante episodios risk-off. Cuando los inversores temen una recesión o un shock de mercado, venden renta variable y compran bonos (huida hacia la seguridad), empujando los precios de la renta variable hacia abajo y los de los bonos hacia arriba. Durante entornos risk-on, el capital fluye de los bonos de vuelta a la renta variable.

Esta es la intuición detrás del `BondCorrelation = -1` por defecto: cuando los precios de los bonos están por debajo de su media móvil (bonos cayendo, rendimientos subiendo), el entorno macro es típicamente uno de expectativas de crecimiento o preocupación por la inflación. Cuando los bonos están por encima de su MA (bonos subiendo, rendimientos cayendo), puede dominar el sentimiento risk-off.

**Por qué esta relación no es estable:** El régimen de correlación renta variable-bonos ha cambiado significativamente a lo largo de la historia de mercado. Durante el período 2000–2020, la relación fue fiablemente negativa. Durante 2022, cuando los bancos centrales subieron tipos agresivamente para combatir la inflación, tanto la renta variable como los bonos cayeron simultáneamente, rompiendo la cobertura tradicional. Un filtro basado en la suposición de correlación negativa habría estado sistemáticamente equivocado durante este período. Esto se discute en la Sección 5.

```pascal
// BondCorrelation = -1: el índice de renta variable tiende a moverse opuesto a los precios de bonos
// El filtro pasa para entradas largas cuando el mercado de bonos está POR DEBAJO de su MA
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, FilterMALength));
```

> **Marcador de gráfico:** Futuros Bund (o US20Y) vs. DAX (o NQ) precios diarios, 2015–2024. Marcar el período 2022 donde ambos cayeron simultáneamente. Superponer la MA de 50 períodos en cada uno para mostrar cuándo el filtro de bonos habría estado activo vs. inactivo.

---

## 3. Direcciones de correlación — lógica económica

La estrategia codifica cada relación intermercado como uno de tres estados mediante los inputs de correlación:

| Valor del input | Significado | Condición filtro largo | Condición filtro corto |
|---|---|---|---|
| `1` (positiva) | El mercado secundario tiende con el primario | Data2/3 por encima de MA | Data2/3 por debajo de MA |
| `-1` (negativa/inversa) | El mercado secundario tiende contra el primario | Data2/3 por debajo de MA | Data2/3 por encima de MA |
| `0` (desactivada) | Filtro ignorado | Siempre pasa | Siempre pasa |

### Por qué `-1` es el valor por defecto para ambos

La configuración por defecto (`CurrencyCorrelation = -1`, `BondCorrelation = -1`) codifica las relaciones macro clásicas para índices de renta variable europeos en un entorno macro normal:

- **DAX / EURUSD inverso:** Cuando el euro se debilita (EURUSD por debajo de MA), a menudo refleja una actitud acomodaticia del BCE o estrés de la Eurozona — condiciones donde la renta variable europea puede subir por la competitividad exportadora más barata o expectativas de estímulo monetario.
- **DAX / Bund inverso:** Cuando los precios del Bund caen (rendimientos suben, Bund por debajo de MA), refleja expectativas de crecimiento o inflación — un entorno macro donde la renta variable puede tender al alza.

Estas son hipótesis de partida, no leyes universales. Antes de desplegar la estrategia en cualquier par de instrumentos específico, la dirección de correlación histórica debe verificarse empíricamente sobre los datos objetivo.

### Cuándo usar `1` (correlación positiva)

Algunos pares de instrumentos se mueven en la misma dirección durante regímenes normales. Por ejemplo, las divisas de materias primas (AUD, CAD) tienden a moverse con los índices de renta variable ligados a materias primas. Si el mercado primario es un índice del sector de recursos, una correlación positiva con su divisa asociada puede ser más apropiada que una inversa.

### Cuándo usar `0` (filtro desactivado)

Desactivar un filtro tiene dos propósitos. Primero, es la configuración correcta cuando la relación económica entre el mercado primario y un secundario es poco clara, inestable o no ha sido validada empíricamente. Segundo, permite pruebas de línea base: ejecutar la estrategia con ambos filtros desactivados revela el edge puro de ruptura de tendencia, contra el que la versión filtrada puede compararse para cuantificar el valor incremental de cada filtro.

---

## 4. Cómo codifica esto la estrategia — la lógica del filtro

La lógica del filtro traduce las relaciones intermercado cualitativas en condiciones booleanas computables. Entender la traducción es esencial para interpretar qué está haciendo realmente la estrategia en cada barra.

### La construcción completa del filtro

```pascal
{--- Filtro de divisa para entradas largas ---}
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));

{--- Filtro de bonos para entradas largas ---}
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation =  1 and Close of Data3 > Average(Close of Data3, FilterMALength))
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, FilterMALength));

{--- Filtro combinado ---}
LongFilterPassed = CurrencyLongFilter and BondLongFilter;
```

### Qué significa cada condición en lenguaje claro

Con la configuración por defecto (`CurrencyCorrelation = -1`, `BondCorrelation = -1`), `LongFilterPassed = True` cuando:

1. EURUSD está por debajo de su media móvil de `FilterMALength` períodos **y**
2. Bund (o US20Y) está por debajo de su media móvil de `FilterMALength` períodos

En términos macro: el mercado de divisas está señalando debilidad del euro **y** el mercado de bonos está señalando caída de precios de bonos (subida de rendimientos, expectativas de crecimiento o inflación). Ambos mercados secundarios están en un estado consistente con una potencial tendencia alcista en el mercado primario.

### El filtro corto es el espejo lógico

```pascal
CurrencyShortFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 < Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 > Average(Close of Data2, FilterMALength));
```

Para entradas cortas con `CurrencyCorrelation = -1`, el filtro corto pasa cuando EURUSD está **por encima** de su MA — el espejo de la condición larga. Los filtros no solo son independientes — están estructuralmente opuestos. Cuando el contexto macro favorece largos, simultáneamente bloquea cortos.

### El parámetro `FilterMALength`

Ambos filtros de mercados secundarios usan `FilterMALength` como período de MA, independiente de `SlowMALength` usado en el mercado primario. Esto es una mejora deliberada de v3: Data2 y Data3 pueden operar en diferentes intervalos de barra que Data1, y el mismo período numérico representa duraciones de calendario distintas en cada feed. Un `FilterMALength = 20` en un gráfico diario de bonos es aproximadamente un mes de trading; el mismo valor en un gráfico de 4 horas de divisas son aproximadamente dos semanas. El parámetro debe establecerse con conciencia de lo que representa en tiempo calendario en cada feed secundario.

---

## 5. Qué mide realmente la estrategia — y qué no

Esta es la sección más importante para cualquier investigador o profesional que trabaje con esta estrategia. Los filtros intermercado son una aproximación útil de la confirmación de régimen macro, pero no son una medición de correlación estadística. Entender la diferencia entre ambos es esencial para establecer expectativas realistas.

### Lo que los filtros miden: alineamiento direccional

La condición del filtro `Close of Data2 < Average(Close of Data2, FilterMALength)` responde una única pregunta binaria: **¿está este mercado actualmente tendiendo por debajo de su media reciente?** No dice nada sobre:

- Con qué fuerza está tendiendo el mercado secundario
- Si los movimientos del mercado secundario están estadísticamente relacionados con los del primario
- Si la relación entre los dos mercados ha sido estable o se ha roto recientemente
- La magnitud de la desviación del mercado secundario respecto a su media

Este es un filtro de estado direccional, no una medición de correlación. Dos mercados pueden estar ambos por debajo de sus medias móviles sin estar correlacionados entre sí — simplemente se encuentran en el mismo régimen direccional por casualidad.

### Lo que los filtros no miden: correlación estadística

La correlación intermercado real requiere medir la relación estadística entre los **retornos** (o cambios de precio) de dos mercados sobre una ventana móvil. Un coeficiente de correlación móvil entre los retornos de Data1 y Data2 a lo largo de los últimos N períodos respondería: *¿con qué consistencia se han movido juntos (o en direcciones opuestas) estos dos mercados recientemente?*

Un z-score de la correlación móvil respondería adicionalmente: *¿es la correlación actual significativamente diferente de su media histórica?* Una correlación inusualmente alta o baja respecto a su propia historia es una señal más informativa que una simple comparación por encima/por debajo de una MA.

La implementación actual no mide nada de esto. El siguiente pseudocódigo ilustra lo que requeriría un filtro estadísticamente más riguroso:

```
// Conceptual — no es implementación actual de EasyLanguage
CorrelacionMovil = Correlacion(
    Retornos(Close of Data1, 1),    // Retornos diarios del mercado primario
    Retornos(Close of Data2, 1),    // Retornos diarios de la divisa
    VentanaCorrelacion              // Ventana móvil, p.ej. 60 barras
);

ZScoreCorrelacion = (CorrelacionMovil - Media(CorrelacionMovil, VentanaZScore))
                   / DesviacionTipica(CorrelacionMovil, VentanaZScore);

// El filtro pasa solo cuando la correlación está significativamente alineada con la dirección esperada
// Y la propia correlación es estadísticamente estable (z-score dentro del rango normal)
FiltroLargoDivisa = (CurrencyCorrelation = -1 and CorrelacionMovil < -UmbralCorrelacion)
                    and ValorAbsoluto(ZScoreCorrelacion) < UmbralZScore;
```

Esto filtraría períodos donde la correlación esperada se ha roto — precisamente los períodos donde la implementación actual tiene más probabilidad de generar señales falsas.

### Implicaciones prácticas de la diferencia

La distancia entre "alineamiento direccional" y "correlación estadística" tiene tres consecuencias concretas para el rendimiento de la estrategia:

**1. Los cambios de régimen de correlación son invisibles para el filtro actual.** Durante 2022, la correlación renta variable-bonos se volvió fuertemente positiva — ambos cayeron juntos mientras los tipos subían. Un filtro `BondCorrelation = -1` habría continuado pasando entradas largas cuando los bonos estaban por debajo de su MA, precisamente el entorno donde la relación tradicional estaba rota.

**2. El ruido a corto plazo pasa el filtro.** Un mercado secundario puede pasar unos pocos barras por debajo de su MA debido a fluctuación aleatoria más que por un compromiso direccional genuino. El filtro actual trata ambos casos de forma idéntica. Un filtro de correlación estadística con ventana móvil sería más resistente al ruido a corto plazo porque requiere que la relación haya sido consistente a lo largo de toda la ventana.

**3. El filtro no proporciona información sobre la fuerza de la correlación.** Tanto si Data2 está un 0,1% por debajo de su MA como si está un 5% por debajo, el resultado del filtro es idéntico: `True`. Un filtro basado en z-score ponderaría las desviaciones significativas más que las marginales.

---

## 6. Ejemplos de régimen — episodios históricos

Los siguientes episodios ilustran cómo se comportó la relación entre los tres mercados durante regímenes macro significativos. Para cada episodio, una tabla de régimen muestra el estado direccional aproximado de cada mercado y si la configuración de filtro por defecto (`CurrencyCorrelation = -1`, `BondCorrelation = -1`) habría permitido o bloqueado las entradas largas.

### Episodio 1 — Crisis Financiera Global (2008–2009)

**Narrativa macro:** El colapso de Lehman Brothers en septiembre de 2008 desencadenó un episodio risk-off global de severidad excepcional. Los mercados de renta variable colapsaron globalmente. El capital huyó hacia activos refugio — Treasuries estadounidenses, Bunds alemanes y el dólar estadounidense. EURUSD cayó bruscamente ante la demanda de dólares. Los precios de los bonos subieron (rendimientos cayeron) mientras los inversores compraban seguridad.

| Mercado | Dirección | vs. MA | Contribución filtro largo |
|---|---|---|---|
| DAX (Data1) | Bruscamente a la baja | Por debajo | — (señal de tendencia: solo cortos) |
| EURUSD (Data2) | A la baja (fortaleza del dólar) | Por debajo | `CurrencyLongFilter = True` (corr. inversa) |
| Bund (Data3) | Al alza (huida hacia seguridad) | Por encima | `BondLongFilter = False` (corr. inversa) |
| **LongFilterPassed** | — | — | **False** |

El filtro de bonos bloqueó correctamente las entradas largas durante el colapso risk-off. Incluso si el filtro de divisa pasaba (EURUSD por debajo de MA), el filtro de bonos fallaba — los precios del Bund subiendo (por encima de MA) señalaban huida hacia la seguridad, no un régimen de crecimiento. El filtro combinado habría prevenido entradas largas durante lo peor de la caída.

> **Marcador de gráfico:** Precios diarios DAX, EURUSD, Bund con superposición de MA de 50 períodos, septiembre 2008 – marzo 2009. Marcar la fecha del colapso de Lehman. Mostrar el estado del filtro (pasa/falla) para cada mercado.

---

### Episodio 2 — Crisis de Deuda Soberana Europea (2011–2012)

**Narrativa macro:** Las preocupaciones sobre la deuda soberana griega, italiana y española crearon un prolongado episodio risk-off específico de la Eurozona. El DAX cayó significativamente. EURUSD se debilitó al descontarse el riesgo de ruptura de la Eurozona. Los precios del Bund subieron fuertemente al convertirse en el activo refugio de la Eurozona — los rendimientos alemanes cayeron a mínimos históricos mientras los periféricos se disparaban.

| Mercado | Dirección | vs. MA | Contribución filtro largo |
|---|---|---|---|
| DAX (Data1) | Bajada luego recuperación | Mixta | — |
| EURUSD (Data2) | A la baja (estrés euro) | Por debajo | `CurrencyLongFilter = True` |
| Bund (Data3) | Al alza (refugio Eurozona) | Por encima | `BondLongFilter = False` |
| **LongFilterPassed** | — | — | **False durante estrés, True en recuperación** |

Este episodio ilustra una dinámica específica de la relación DAX/Bund: durante el estrés específico de la Eurozona, el Bund y el DAX pueden decorrelacionarse de su relación típica. El Bund subió no por un risk-off global sino porque era el refugio interno de la Eurozona.

**El "whatever it takes" de Draghi (julio 2012):** Cuando el presidente del BCE Draghi se comprometió a preservar el euro, tanto el DAX como el EURUSD subieron mientras los precios del Bund cayeron (rendimientos subieron ligeramente al retroceder la demanda de refugio). Este es el régimen que el filtro por defecto está diseñado para capturar — divisa y bonos ambos alineados para largos en renta variable.

> **Marcador de gráfico:** Precios diarios DAX, EURUSD, Bund con superposición de MA de 50 períodos, enero 2011 – diciembre 2012. Marcar el discurso "whatever it takes". Mostrar la transición del filtro de bloqueado a pasando.

---

### Episodio 3 — Crash COVID y recuperación (febrero–agosto 2020)

**Narrativa macro:** La pandemia de COVID-19 desencadenó el crash de mercado más rápido de la historia (febrero–marzo 2020) seguido de una recuperación igualmente rápida impulsada por estímulos fiscales y monetarios sin precedentes. La fase de crash fue un episodio risk-off clásico; la fase de recuperación fue un régimen risk-on apoyado por la intervención de los bancos centrales.

| Fase | DAX | EURUSD | Bund | LongFilterPassed |
|---|---|---|---|---|
| Crash (feb–mar 2020) | Bruscamente a la baja | Mixto (pico dólar luego reversión) | Al alza (huida hacia seguridad) | **False** |
| Recuperación (abr–ago 2020) | Bruscamente al alza | Al alza (fortalecimiento euro) | Por debajo luego por encima de MA | **Mixto** |

La fase de crash bloqueó correctamente las entradas largas. La fase de recuperación presenta un cuadro más complejo: EURUSD se fortaleció significativamente (euro por encima de MA) — con `CurrencyCorrelation = -1`, esto habría bloqueado las entradas largas durante la recuperación. El euro fuerte reflejaba debilidad del dólar y flujos de capital risk-on hacia Europa, lo que era en realidad consistente con la subida del DAX — pero el filtro, configurado para correlación inversa, habría interpretado la fortaleza del euro como señal negativa.

Esto ilustra una limitación clave: la suposición de correlación `-1` por defecto puede producir falsos negativos durante recuperaciones risk-on donde divisa y renta variable se mueven en la misma dirección.

> **Marcador de gráfico:** Precios diarios DAX, EURUSD, Bund con superposición de MA de 50 períodos, enero 2020 – septiembre 2020. Marcar el mínimo del crash (23 de marzo) y la recuperación. Mostrar el estado del filtro para cada fase.

---

### Episodio 4 — Ciclo de subida de tipos (2022)

**Narrativa macro:** En 2022, la Reserva Federal y el BCE subieron tipos agresivamente para combatir la inflación post-pandemia. Esto creó un régimen macro inusual: tanto la renta variable como los bonos cayeron simultáneamente — la correlación negativa tradicional renta variable-bonos se rompió completamente. El DAX cayó ~20%. Los precios del Bund colapsaron (rendimientos se dispararon). EURUSD cayó bruscamente (debilidad del euro por el retraso del BCE frente a la Fed).

| Mercado | Dirección | vs. MA | Contribución filtro largo |
|---|---|---|---|
| DAX (Data1) | A la baja | Por debajo | — (señal de tendencia: solo cortos) |
| EURUSD (Data2) | Bruscamente a la baja | Por debajo | `CurrencyLongFilter = True` (corr. inversa) |
| Bund (Data3) | Bruscamente a la baja | Por debajo | `BondLongFilter = True` (corr. inversa) |
| **LongFilterPassed** | — | — | **True** |

Este es el episodio más peligroso para la configuración por defecto de esta estrategia. Ambos mercados secundarios estaban por debajo de sus MAs — el filtro pasaba para entradas largas — pero el régimen macro era inequívocamente bajista para la renta variable. La correlación inversa tradicional renta variable-bonos se había roto: bonos y renta variable estaban cayendo juntos, no en el patrón clásico risk-off.

Una estrategia ejecutándose con `CurrencyCorrelation = -1` y `BondCorrelation = -1` durante 2022 habría tenido sus filtros pasando para entradas largas precisamente cuando el mercado primario estaba en una tendencia bajista sostenida. La señal de tendencia (`FastMA < SlowMA` para el DAX) habría bloqueado las entradas largas — pero el filtro no habría añadido la protección para la que fue diseñado.

**Este episodio es el argumento empírico más claro a favor de la medición de correlación estadística frente a los filtros de estado direccional.** Un filtro de correlación móvil habría detectado que la relación renta variable-bonos había cambiado de negativa a positiva y habría desactivado el filtro de bonos en lugar de permitir que pasara en un régimen roto.

> **Marcador de gráfico:** Precios diarios DAX, EURUSD, Bund con superposición de MA de 50 períodos, enero 2022 – diciembre 2022. Mostrar ambos mercados secundarios por debajo de MA (filtro pasando) mientras el DAX tiende a la baja. Superponer la correlación móvil de 60 días entre los retornos del DAX y el Bund para ilustrar el cambio de régimen.

### Un patrón a través de los episodios

La revisión conjunta de los cuatro episodios revela una tendencia estructural del diseño de filtro actual: **cuando la correlación intermercado tradicional se rompe, los filtros tienden a bloquear ambas direcciones simultáneamente**, dejando la estrategia sin operar en períodos donde existían tendencias claras y operables en el mercado primario. En 2008, la fortaleza del dólar que acompañó al colapso de la renta variable bloqueó las entradas cortas mediante el filtro de divisa. En 2022, la caída simultánea de bonos y renta variable pasó el filtro largo mientras la señal de tendencia bloqueaba los largos — y la condición espejo bloqueaba los cortos. Esto no es un fallo de la lógica del filtro en sí; es una consecuencia de usar suposiciones de correlación estáticas en un entorno macro dinámico. Es el argumento más claro a favor del enfoque de correlación estadística descrito en la Sección 7.

---

## 7. Hacia un filtro intermercado más riguroso — Consideraciones para una futura v4

Las limitaciones identificadas en la Sección 5 e ilustradas por el episodio de 2022 apuntan hacia un diseño de filtro estadísticamente más fundamentado. Una v4 abordaría tres debilidades específicas de la implementación actual.

### 7.1 Filtro de correlación móvil

Reemplazar la comparación de MA con una correlación móvil entre retornos:

```
// Diseño conceptual — requiere función personalizada en EasyLanguage o feed de datos externo
CorrelacionMovil_D2 = CorrelacionMovil(
    RetornoDiario(Close of Data1),
    RetornoDiario(Close of Data2),
    VentanaCorrelacion    // p.ej. 60 barras
);

// El filtro pasa solo cuando la dirección de correlación coincide con el régimen esperado
// Y la correlación es estadísticamente significativa (no cercana a cero)
FiltroLargoDivisa_v4 =
    (CurrencyCorrelation = -1 and CorrelacionMovil_D2 < -UmbralCorrelacion)  // p.ej. < -0.3
    or (CurrencyCorrelation =  1 and CorrelacionMovil_D2 >  UmbralCorrelacion)
    or (CurrencyCorrelation =  0);
```

`UmbralCorrelacion` sería un nuevo parámetro (p.ej. `0.3`) que requiere que la correlación sea significativamente negativa o positiva antes de que el filtro se active. Una correlación cercana a cero desactivaría el filtro — la relación no es actualmente informativa.

### 7.2 Z-Score de correlación para detección de cambio de régimen

Una correlación móvil sola no detecta cuándo la correlación ha cambiado respecto a su norma histórica. Un z-score de la correlación móvil lo haría:

```
// Conceptual
ZScoreCorrelacion = (CorrelacionMovil_D2 - Media(CorrelacionMovil_D2, VentanaZScore))
                   / DesviacionTipica(CorrelacionMovil_D2, VentanaZScore);

// Desactivar filtro cuando la correlación está en un régimen anormal
// (z-score más allá de ±2 sugiere que la relación ha cambiado estructuralmente)
CorrelacionEstable = ValorAbsoluto(ZScoreCorrelacion) < 2.0;

FiltroLargoDivisa_v4 = FiltroLargoDivisa_v4 and CorrelacionEstable;
```

Durante 2022, el z-score renta variable-bonos habría alcanzado valores extremos al invertirse la correlación — esta condición habría desactivado el filtro de bonos en lugar de permitir que pasara en un régimen roto.

### 7.3 Dirección de correlación dinámica

La mejora más ambiciosa de v4 eliminaría completamente los inputs estáticos `CurrencyCorrelation` y `BondCorrelation` y los reemplazaría con dirección de correlación detectada dinámicamente:

```
// Conceptual
DireccionCorrelacionDetectada_D2 = Signo(CorrelacionMovil_D2);  // +1 o -1 según correlación móvil actual

FiltroLargoDivisa_v4 =
    (DireccionCorrelacionDetectada_D2 =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (DireccionCorrelacionDetectada_D2 = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

Esto haría la estrategia completamente adaptativa a los cambios de régimen intermercado sin requerir actualizaciones manuales de parámetros. El trade-off es la complejidad: una correlación detectada dinámicamente introduce su propio ruido y retardo, y el comportamiento de la estrategia se vuelve más difícil de razonar durante las transiciones.

### Nota de implementación para EasyLanguage

EasyLanguage nativo no incluye una función de correlación móvil integrada entre dos feeds de datos. Implementar v4 requeriría bien una `Function` personalizada que compute el coeficiente de correlación de Pearson sobre una ventana móvil a partir de dos series de precios, o acceso a una serie de correlación pre-calculada mediante un feed de datos externo o indicador. Esta es una extensión no trivial pero factible — la base matemática es directa, y la complejidad de implementación reside principalmente en el diseño de la función EasyLanguage más que en la lógica de la estrategia en sí.

---

*Este documento es una referencia de investigación viva. Los marcadores de gráficos deben reemplazarse con gráficos de precios reales de TradeStation o TradingView a medida que avance la investigación empírica sobre configuraciones específicas de instrumentos. Los ejemplos de régimen son ilustrativos de las dinámicas macro generales y deben verificarse contra resultados reales de backtest sobre el instrumento objetivo antes de extraer conclusiones de trading.*
