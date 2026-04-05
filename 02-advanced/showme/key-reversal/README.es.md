## Detector de Key Reversal - Indicador ShowMe

🇪🇸 Español | 🇺🇸 [English](README.md)

### Visión General

El **Detector de Key Reversal** es un indicador visual que identifica patrones clásicos de reversión clave en un gráfico. Detecta cuándo el precio forma un mínimo estructural seguido de un cierre alcista, lo que a menudo señala el inicio de un rebote o una reversión. El indicador muestra tres niveles distintos de confirmación, permitiendo a los traders visualizar tanto el desarrollo como la finalización del patrón.

### Mecánica Principal

**Detección de Mínimo Estructural:**
El indicador busca la barra más reciente que haya marcado un nuevo mínimo respecto a las *n* barras anteriores (por defecto: canal Donchian de 21 barras). Este mínimo estructural representa un test relevante de soporte.

**Captura del Cierre de Referencia:**
Una vez identificado el mínimo estructural, el indicador registra el cierre de esa barra como `ReferenceClose`. Este valor actúa como punto de referencia para medir la confirmación alcista.

**Confirmación de Cierre Alcista:**
El indicador comprueba si las barras siguientes cierran por encima del cierre de referencia (con posibilidad de tolerancia). Si el cierre actual supera:

- `ReferenceClose × (1 - ConfirmationTolerancePct * 0.01)`

Entonces se confirma un cierre alcista, señalando rechazo del mínimo estructural.

### Parámetros

- **DonchianLen:** Periodo de observación para identificar mínimos estructurales (por defecto: 21 barras). Las barras que rompen por debajo del mínimo de este periodo califican como mínimos estructurales.  
- **CarryForwardBars:** Número de barras posteriores al mínimo estructural durante las cuales este sigue siendo válido (por defecto: 0). Permite flexibilidad sobre cuán reciente debe ser el mínimo.  
- **ConfirmationTolerancePct:** Porcentaje de tolerancia para la confirmación del cierre alcista (por defecto: 0%). Permite ajustar pequeños deslizamientos o gaps. Por ejemplo, una tolerancia del 5% implica que el cierre solo necesita recuperar el 95% hasta el cierre de referencia.  

### Salidas Visuales (Plots)

El indicador genera tres niveles de visualización, cada uno representando una etapa de confirmación del patrón:

**Plot 1: Mínimo Estructural (HasStructuralLow)**

- Se muestra a un tercio por debajo del mínimo de la barra  
- Indica que se ha identificado un mínimo estructural  
- Aparece cuando se forma un nuevo mínimo respecto al periodo de observación  
- Color: Indica un posible test de soporte  

**Plot 2: Cierre Alcista (HasBullishClose)**

- Se muestra a dos tercios por debajo del mínimo de la barra  
- Indica que se ha producido una confirmación alcista  
- Aparece cuando el cierre supera el cierre de referencia (con tolerancia)  
- Color: Marca la señal de rechazo y posible reversión  

**Plot 3: Key Reversal Completo (HasStructuralLow AND HasBullishClose)**

- Se muestra al 99% por debajo del mínimo de la barra (cerca del mínimo real)  
- Solo aparece cuando ambas condiciones se cumplen simultáneamente  
- Indica que el mínimo estructural ha sido seguido inmediatamente por confirmación alcista  
- Color: Señala un patrón completo y confirmado de key reversal  

### Interpretación Operativa

**Solo Mínimo Estructural:**
Cuando únicamente aparece el Plot 1, el mercado ha alcanzado un nuevo mínimo. Esto representa un posible test de soporte, pero aún sin señal de reversión. Se requiere confirmación alcista.

**Mínimo Estructural + Cierre Alcista:**
Cuando aparecen los Plots 1 y 2, el mercado ha rechazado el mínimo estructural mediante un cierre alcista. Esto constituye una señal de key reversal: el mercado prueba soporte y rebota con convicción.

**Señal Completa de Key Reversal:**
Cuando aparece el Plot 3 (ambas condiciones en la misma barra o consecutivas), se ha formado un key reversal de alta probabilidad. Este patrón suele preceder operaciones de rebote o entradas de reversión a la media.

### Uso Práctico

**Detección Autónoma:**
Utiliza este indicador en gráficos intradía o diarios para identificar automáticamente formaciones de key reversal, sin necesidad de análisis manual.

**Confirmación de Entrada:**
Combínalo con estrategias existentes. Cuando el indicador muestra los tres plots, confirma la existencia del patrón y valida entradas basadas en él.

**Análisis de Soporte:**
Permite seguir dónde se forman mínimos estructurales y detectar zonas donde entran compradores. La confirmación alcista refleja convicción en dichos niveles.

**Indicador de Volatilidad:**
En mercados laterales, los mínimos estructurales (Plot 1) aparecen con frecuencia sin confirmación alcista (Plot 3 raro). En tendencias más limpias, las señales de key reversal tienden a agruparse cerca de zonas de soporte.

### Resumen de la Lógica del Código
