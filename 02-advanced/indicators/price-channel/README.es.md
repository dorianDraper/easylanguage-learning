# Indicador de Ruptura Estilo Donchian v2

🇪🇸 Español | 🇺🇸 [English](README.md)

## Visión General
Este indicador identifica **rupturas de precio desde un rango histórico** utilizando un canal estilo Donchian. Calcula el máximo más alto y el mínimo más bajo durante un periodo de observación especificado (excluyendo la barra actual) y genera señales cuando el precio rompe por encima o por debajo de estos niveles.

El indicador está diseñado tanto para entornos de **Chart** como de **RadarScreen**, adaptando su visualización y alertas en consecuencia.

---

## Cómo Funciona

- **Banda Superior** → Máximo más alto de las últimas *N* barras (excluyendo la barra actual)  
- **Banda Inferior** → Mínimo más bajo de las últimas *N* barras (excluyendo la barra actual)

Condiciones de ruptura:
- **Ruptura alcista** → El precio cruza por encima de la banda superior  
- **Ruptura bajista** → El precio cruza por debajo de la banda inferior  

Detalles clave de implementación:
- Usa desplazamiento `[1]` para evitar sesgo de anticipación (*look-ahead bias*)  
- Soporta desplazamiento de gráficos (`Displace`) para análisis visual  
- Proporciona **alertas en tiempo real** solo cuando no se proyecta hacia el futuro  
- Adapta la visualización:
  - **Charts** → resaltado de líneas (color + grosor)
  - **RadarScreen** → coloreado de celdas (fondo + texto)

---

## Características Clave

- Detección de rupturas mediante canal Donchian  
- Alertas en tiempo real ante eventos de ruptura  
- Visualización adaptada al entorno (Chart vs RadarScreen)  
- Manejo seguro de gráficos desplazados  
- Separación clara entre lógica de cálculo, visualización y alertas  

---

## Casos de Uso en Estrategias de Trading

Este indicador puede utilizarse como bloque base en múltiples tipos de estrategias:

### 1. Seguimiento de Tendencia (Sistemas de Ruptura)
- Entrada en largo en ruptura superior  
- Entrada en corto en ruptura inferior  
- Ejemplo: sistemas tipo Turtle Trading  

### 2. Estrategias de Expansión de Volatilidad
- Usar rupturas como señal de incremento de volatilidad  
- Combinar con ATR o filtros de volumen  

### 3. Reversión a la Media (con Filtros)
- Detectar extremos y esperar **rupturas fallidas / reentrada al canal**  
- Combinar con RSI o z-score para confirmación  

### 4. Ruptura de Rango Intradía
- Aplicar sobre rangos basados en sesión  
- Útil en sistemas de ruptura del rango de apertura  

### 5. Escaneo de Mercado (RadarScreen)
- Identificar instrumentos que rompen niveles clave en una watchlist  
- Usar alertas codificadas por color para decisiones rápidas  

---

## Notas

- Las rupturas por sí solas no implican continuidad de la dirección; se recomienda combinar con:
  - Filtros de tendencia (ej. medias móviles)
  - Filtros de volatilidad (ej. ATR)
  - Indicadores de momentum  

- Especialmente efectivo en **contextos de seguimiento de tendencia**, pero requiere lógica de confirmación en sistemas de reversión a la media.

---