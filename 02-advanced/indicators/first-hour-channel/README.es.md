## Canal de la Primera Hora - Indicador

🇪🇸 Español | 🇺🇸 [English](README.md)

### Descripción

Muestra el máximo y el mínimo de la primera hora de apertura como líneas horizontales fijas de referencia durante la sesión de trading. El indicador captura los precios más altos y más bajos durante los primeros 60 minutos (por defecto), y posteriormente dibuja estos niveles desde el final de la primera hora hasta una hora de finalización especificada (por defecto: 15:00). Se utiliza para identificar rupturas del rango de apertura (opening range breakouts) y niveles de soporte/resistencia a lo largo del día.

### Mecánica

1. **Captura de la Primera Hora** (0:00 - 1:00): Registra el máximo y el mínimo diarios durante el periodo de apertura  
2. **Visualización del Canal** (1:00 - 3:00): Dibuja los niveles capturados como líneas horizontales con codificación por colores  
3. **Ocultación Automática**: Deja de dibujar después de la hora de finalización para reducir la saturación del gráfico  

### Parámetros

- **FirstHourMinutes**: Duración del periodo de apertura (por defecto: 60 minutos)  
- **StopPlotTime**: Hora en la que el indicador deja de dibujar (por defecto: 1500 / 15:00)  
- **HighColor**: Color para la línea del máximo de la primera hora (por defecto: Azul)  
- **LowColor**: Color para la línea del mínimo de la primera hora (por defecto: Rojo)  

### Casos de Uso

- Traders intradía que identifican soportes y resistencias del rango de apertura  
- Traders de rupturas que detectan cuándo el precio sale del rango de apertura  
- Traders de rango que monitorizan los límites de consolidación  

### Notas