## Descripción de la Estrategia

La **Salida de Fin de Día** es un componente de gestión de riesgo de solo salida diseñado para cerrar automáticamente todas las posiciones abiertas antes de que termine la sesión del mercado. Más que ser una estrategia de trading independiente, sirve como un mecanismo protector que asegura que no se mantengan posiciones durante la noche, eliminando el riesgo de brechas nocturnas y la exposición a la decadencia temporal.

### Mecánicas Principales

**Operación en Tiempo Real:** Cuando se opera en vivo, la estrategia monitorea la hora real del ordenador usando `CurrentTime` y activa órdenes de salida al mercado n minutos antes de la hora oficial de cierre de la sesión (por defecto: 3 minutos). Una vez activada, todas las posiciones largas se venden y todas las posiciones cortas se cubren al precio de mercado en la siguiente barra.

**Aproximación para Backtesting:** Para simular salidas de fin de día durante pruebas históricas, la estrategia usa `SetExitOnClose` cuando no está en la barra final en tiempo real. Esto cierra posiciones al precio de cierre diario, proporcionando una aproximación razonable del comportamiento de fin de día para la validación de estrategias.

**Ejecución de Órdenes Intrabarra:** La estrategia requiere `[IntrabarOrderGeneration = TRUE]` para funcionar correctamente. Esto permite que el sistema ejecute órdenes de salida dentro de la barra antes de que el mercado cierre oficialmente, en lugar de esperar hasta que se abra la siguiente barra.

**Lógica Temporal Inteligente:** La estrategia distingue entre:

- **Barras históricas** (`Date ≠ CurrentDate`): Usa precios de cierre para simulación de fin de día
- **Barras del día actual** (`Date = CurrentDate`): Usa la hora real del ordenador para ejecución en vivo
- **La barra final** (`LastBarOnChart and Date = CurrentDate`): Verifica la hora real del reloj contra la hora de fin de sesión

### Parámetros

- **EODExitMinutes** (v2) / **MinstoX** (v1): Número de minutos antes del cierre de sesión para activar salidas (por defecto: 3 minutos)

### Características Clave

- **Lógica de Solo Salida:** No hay reglas de entrada; se integra con cualquier estrategia de entrada
- **Independiente del Marco Temporal:** Funciona con cualquier intervalo de gráfico intradía
- **Agnóstica al Mercado:** Usa `SessionEndTime(1,1)` para funcionar en todos los mercados (acciones, futuros, forex)
- **Sin Sesgo de Precio:** Cierra al mercado independientemente del estado de ganancia/pérdida
- **A Nivel de Portafolio:** Cierra simultáneamente todas las posiciones largas y cortas

### Casos de Uso

- Estrategias de scalping intradía que requieren cierres diarios
- Gestión de riesgo para prevención de brechas nocturnas
- Comodidad del trader (sin exposición a posiciones nocturnas)
- Reducción del impacto de la decadencia temporal en estrategias basadas en opciones
- Cumplimiento con límites de riesgo o reglas de trading

### Notas