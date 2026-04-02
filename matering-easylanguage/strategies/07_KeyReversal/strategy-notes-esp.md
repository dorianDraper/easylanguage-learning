## Descripción de la Estrategia

La **Reversión de Clave** es una estrategia de reversión de media que identifica y opera el patrón clásico de reversión de clave—un mínimo estructural seguido por un cierre alcista a un nivel de precio más alto. Incorpora un mecanismo avanzado de promediación que agrega a posiciones perdedoras cuando cumple condiciones específicas, ofreciendo gestión de exposición a través de múltiples niveles de entrada.

### Mecánicas Principales

**Detección de Reversión de Clave:** La estrategia escanea las últimas n barras (por defecto: canal Donchian de 21 barras) para encontrar el mínimo estructural más reciente—una barra que forma un nuevo mínimo bajo relativo a barras anteriores. Una vez identificado, verifica si el cierre de la barra siguiente a ese mínimo (la barra potencial de reversión) es alcista relativo al cierre del mínimo. Un factor de tolerancia (por defecto: 0%) permite ajustes leves para tener en cuenta brechas o deslizamientos menores.

**Entrada Inicial:** Cuando ambas condiciones se cumplen—existe un mínimo estructural Y se confirma el cierre de reversión—la estrategia ingresa una posición larga (LE1) al precio de mercado en la siguiente barra.

**Lógica de Promediación (Avanzada):** Mientras mantiene la posición base, si el patrón de Reversión de Clave permanece válido (mínimo estructural aún detectado, cierre de reversión confirmado) Y el trade está actualmente en pérdida (`OpenPositionProfit < 0`), la estrategia dobla la apuesta con una segunda entrada (LE2). Esto agrega 100 acciones adicionales al mercado, promediando efectivamente en una configuración de inversión favorable.

**Temporizadores de Salida Independientes:** Cada entrada opera en su propio reloj:

- **Entrada Base (LE1):** Sale automáticamente 100 acciones después de n barras (por defecto: 5 barras) desde su fecha de entrada
- **Entrada de Promediación (LE2):** Sale automáticamente 100 acciones después de n barras (por defecto: 5 barras) desde su fecha de entrada (solo si ocurrió promediación)

Este mecanismo de salida escalonado permite que la posición base se ejecute independientemente de la posición de promediación, previniendo liquidación en sincronía.

**Máquina de Estados:** La estrategia mantiene tres estados distintos:

- **Estado 0 (Plano):** Sin posiciones; esperando señal de Reversión de Clave
- **Estado 1 (Largo Base):** Primera entrada realizada; monitoreando oportunidad de promediación
- **Estado 2 (Largo Promediado):** Ambas entradas activas; cada una con temporizador de salida independiente

### Parámetros

- **DonchianLen:** Período de retroceso para detectar mínimos estructurales (por defecto: 21 barras)
- **CarryForwardBars:** Barras adicionales para escanear hacia atrás antes del mínimo visible más temprano (por defecto: 0)
- **ConfirmationTolerancePct:** Tolerancia % para que el cierre de reversión exceda el cierre del mínimo (por defecto: 0%)
- **ExitAfterBars:** Número de barras que cada entrada se mantiene antes de salida automática (por defecto: 5 barras)

### Escenarios de Trade

**Escenario 1: Recuperación en Forma de V**

1. Mínimo bajo detectado, cierre de reversión confirmado
2. Entrada base se activa; trade se mueve a ganancia
3. 5 barras transcurridas → entrada base sale con ganancia
4. Sin promediación (condición nunca se cumplió)

**Escenario 2: Promediación Durante Retroceso**

1. Mínimo bajo detectado, cierre de reversión confirmado
2. Entrada base se activa; trade se mueve a pérdida
3. Reversión de Clave aún válida; entrada de promediación se activa (LE2)
4. Posición ahora tiene 200 acciones (100 base + 100 promediación)
5. 5 barras desde entrada base → posición base sale
6. 5 barras desde entrada de promediación → posición de promediación sale (ligeramente después)

### Características Clave

- **Basado en Patrones**: Usa un patrón de reversión bien conocido con validación estructural
- **Protección de Pérdida con Convicción**: Promedia en pérdidas solo cuando la configuración de reversión permanece válida—no promediación ciega
- **Gestión de Posición Multi-Nivel**: Relojes de salida independientes para cada entrada previenen liquidación correlacionada
- **Riesgo Controlado**: Tamaño de acción fijo (100 acciones por entrada) y marcos de salida definidos
- **Claridad de Estado**: Seguimiento explícito de estado (0=Plano, 1=Largo Base, 2=Largo Promediado) asegura ejecución limpia de órdenes

### Psicología del Trade

La estrategia encarna una mentalidad de "doblar apuesta en fortaleza": si el patrón de reversión aún es válido cuando se enfrenta a una pérdida, el precio de entrada más bajo se ve como convicción adicional, no capitulación. Los temporizadores independientes aseguran que ambas entradas obtengan su propia oportunidad de recuperarse.

### Casos de Uso

- Traders contra tendencia capturando rebotes de reversión de clave
- Traders de volatilidad explotando reversión de media en mínimos estructurales
- Constructores de posición cómodos con mecánicas de promediación
- Traders combinando reconocimiento de patrones técnicos con dimensionamiento sistemático de posiciones

### Notas
