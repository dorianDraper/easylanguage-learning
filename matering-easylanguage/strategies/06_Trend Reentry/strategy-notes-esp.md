## Descripción de la Estrategia

La **Reentrada en Tendencia** es una estrategia de solo largos que sigue tendencias y reingresa dinámicamente en tendencias alcistas después de salidas parciales rentables. En lugar de mantener una sola posición a través de todo un movimiento, toma ganancias tácticas cuando el precio se extiende significativamente desde la entrada, luego reingresa oportunistamente si la tendencia subyacente permanece intacta.

### Mecánicas Principales

**Entrada Inicial:** La estrategia genera señales de entrada cuando la media móvil rápida (por defecto: 13 períodos) cruza por encima de la media móvil lenta (por defecto: 21 períodos), indicando el nacimiento de una tendencia alcista. Se establece una posición larga al mercado en la siguiente barra.

**Salida por Extensión (Toma de Ganancias):** Mientras mantiene la posición larga, la estrategia monitorea un nuevo máximo alto relativo al período de retroceso (por defecto: 50 barras). Cuando ocurre esta extensión—señalando que el precio se ha acelerado más allá del movimiento típico—la posición se vende para bloquear ganancias. Esta salida técnica establece una bandera (`CanReEnter`) permitiendo reentradas posteriores.

**Seguimiento de Tendencia:** A lo largo del trade, la estrategia mantiene un máximo en ejecución (`MoveHigh`). Este pico sirve como punto de referencia para medir si el precio continúa su momentum alcista.

**Lógica de Reentrada:** Después de salir en el nivel de extensión, la estrategia puede reingresar si:

1. Existe una posición plana (sin trade abierto)
2. La bandera `CanReEnter` es verdadera (la salida previa fue técnica, no debido a fallo de tendencia)
3. El precio excede el pico anterior por el buffer de reentrada (por defecto: $0.10)

Se permiten múltiples reentradas mientras la tendencia permanezca válida, permitiendo participación en múltiples extensiones dentro de una sola tendencia alcista sin piramidación.

**Terminación de Tendencia:** Cuando la MA rápida cruza por debajo de la MA lenta, la tendencia se considera rota. La posición se vende inmediatamente, y la bandera de reentrada se deshabilita, previniendo entradas adicionales hasta que emerja una nueva señal alcista.

### Parámetros

- **FastLen:** Período para la media móvil rápida (por defecto: 13 barras)
- **SlowLen:** Período para la media móvil lenta (por defecto: 21 barras)
- **ExtensionLen** (v2) / **HHExitLen** (v1): Período de retroceso para detectar nuevos máximos (por defecto: 50 barras)
- **ReEntryBuffer** (v2) / **ReEntryPoints** (v1): Buffer de precio por encima del pico anterior para activar reentrada (por defecto: $0.10)

### Flujo de Trade

1. **Plano** → Esperar cruce alcista de MA
2. **Largo Inicial** → Primera posición entra en cruce de MA
3. **Primera Salida SA** → Precio alcanza nuevo máximo; posición vendida; reentrada habilitada
4. **Reentrada Largo** → Precio excede pico anterior por buffer; posición reingresa
5. **Salida por Extensión** → Nuevo máximo alcanzado nuevamente; posición vendida; reentrada permanece habilitada
6. **Salida Final** → Cruce bajista de MA; tendencia rota; reentrada deshabilitada; posición vendida

### Características Clave

- **Posición Única**: Nunca más de un trade largo a la vez; las reentradas reemplazan posiciones antiguas, no las agregan
- **Preservación de Ganancias**: Salidas técnicas capturan ganancias en extensiones de precio en lugar de montar a través de reversiones
- **Resiliencia de Tendencia**: Puede reingresar múltiples veces dentro de una tendencia alcista, capturando varias extensiones de precio
- **Salidas Limpias**: Salida final en muerte de tendencia vía cruce de media móvil previene mantener a través de reversiones
- **Basado en Estados**: Flujo lógico claro basado en posición de mercado y banderas de validez de tendencia

### Casos de Uso

- Seguimiento de tendencias intradía con múltiples oportunidades de entrada por movimiento
- Captura de extensiones escalonadas de precio en tendencias alcistas fuertes
- Gestión de riesgo a través de extracción táctica de ganancias
- Traders de tendencia buscando maximizar captura sin sobre-exposición

### Notas
