## Descripción de la Estrategia

El **Canal de Primera Hora** es una estrategia de breakout intradía que establece un rango de trading durante la primera hora del mercado, luego ingresa al mercado cuando el precio intenta romper más allá de ese rango. Opera bajo el principio de que la primera hora de trading establece límites de volatilidad, y los breakouts desde estos límites a menudo señalan movimientos de momentum dignos de operar.

### Mecánicas Principales

**Captura de Hora de Apertura:** Durante los primeros 60 minutos (por defecto) de la sesión de trading, la estrategia construye un canal registrando el máximo alto y el mínimo bajo de ese período usando datos intradía. Este rango, conocido como "Canal de Primera Hora", representa el consenso inicial del mercado y el sobre de volatilidad.

**Ventana Post-Apertura:** Una vez que cierra la primera hora, la estrategia ingresa a una ventana de trading activa. Comienza aceptando señales de entrada mientras el tiempo permanece antes del corte de parada de trading (por defecto: 15:00 / 3 PM). Esta ventana permite a la estrategia capturar los movimientos de momentum del día fuera del rango de apertura.

**Lógica de Entrada por Breakout:**

- **Entrada Larga:** Si no existe posición y aún se permiten trades largos para el día, la estrategia coloca una orden de compra en el Mínimo de Primera Hora (el límite inferior de la hora de apertura). Esto se activa cuando el precio rompe por debajo o toca el nivel de soporte inferior establecido durante la apertura.
- **Entrada Corta:** Si no existe posición y aún se permiten trades cortos para el día, la estrategia coloca una orden de venta corta en el Máximo de Primera Hora (el límite superior de la hora de apertura). Esto se activa cuando el precio rompe por encima o toca el nivel de resistencia superior.

Ambas órdenes límite permanecen activas durante la ventana de trading, esperando que el precio alcance estos niveles críticos.

**Un Trade Por Lado Por Día:** Una vez que se establece una posición larga, la bandera `CanLongToday` se deshabilita, previniendo entradas largas adicionales para el resto del día. Similarmente, una vez que se llena una posición corta, la bandera `CanShortToday` deshabilita entradas cortas adicionales. Esto asegura que la estrategia tome como máximo un trade por dirección por día de trading.

**Gestión de Riesgo:**

- **Stop Loss:** Todas las posiciones están protegidas con un monto fijo de stop loss (por defecto: $250)
- **Objetivo de Ganancia:** Todas las posiciones intentan alcanzar un objetivo de ganancia fijo (por defecto: $250)

### Parámetros

- **StopTradingTime:** Hora cuando la estrategia deja de aceptar nuevas entradas (por defecto: 1500, significando 3:00 PM)
- **StopLossAmount:** Monto en dólares para la protección de stop loss (por defecto: 250)
- **ProfitTargetAmount:** Monto en dólares para el objetivo de ganancia (por defecto: 250)
- **FirstHourMinutes:** Duración de la hora de apertura para establecer el canal (por defecto: 60 minutos)

### Escenarios de Trade

**Escenario 1: Breakout de Rango de Apertura Largo**

1. Primera hora: Máximo 100.50, Mínimo 99.80 (canal establecido)
2. 10:30 AM: Precio cae para tocar 99.80
3. Entrada larga activada en 99.80; riesgo/recompensa: $250 stop / $250 objetivo
4. Si el precio cae más, stop loss se llena en 99.30
5. Si el precio sube, objetivo de ganancia se llena en 100.30

**Escenario 2: Ambos Lados Bloqueados**

1. Primera hora: Máximo 100.50, Mínimo 99.80
2. 10:15 AM: Precio rompe por encima de 100.50 hacia 101.00
3. Entrada corta activada en 100.50
4. Trade se mueve a ganancia, cierra en $250 objetivo de ganancia
5. Poco después, precio cae a 99.80; entrada larga bloqueada (no largos permitidos después de corto llenado)
6. Estrategia espera hasta el siguiente día

### Características Clave

- **Reinicio Basado en Sesión**: Recarga diaria de banderas de entrada asegura oportunidades frescas cada día de trading
- **Ejecución Intrabarra**: `[IntraBarOrderGeneration = TRUE]` permite entradas precisas en niveles críticos sin esperar al cierre de barra
- **Riesgo-Recompensa Definido**: Stop loss y objetivo de ganancia fijos proporcionan gestión de posición inmediata sin discreción
- **Exclusividad Direccional**: Solo un largo y un corto por día previene sobre-trading del mismo rango
- **Limitado por Tiempo**: Deja de aceptar entradas en una hora predeterminada, reduciendo riesgo de deslizamiento tardío en el día
- **Configuración Simple**: Patrón clásico de breakout de rango de apertura requiere cálculo mínimo

### Psicología del Trade

La estrategia encarna una filosofía de "momentum-después-de-rango": la hora de apertura define expectativas de volatilidad, y cuando el precio claramente rompe esos límites poco después, a menudo señala movimiento de convicción. Al permitir solo un trade por dirección, la estrategia evita whipsaws y breakouts falsos que ocurren después de múltiples toques de rango.

### Casos de Uso

- Traders intradía explotando breakouts de rango de apertura
- Traders mecánicos buscando un sistema diario simple basado en reglas
- Mercados con volatilidad predecible en hora de apertura (acciones, ES, NQ, etc.)
- Traders queriendo riesgo definido con mecánicas de stop/objetivo fijos
- Portafolio de reinicios diarios para ritmo consistente de entrada/salida

### Notas
