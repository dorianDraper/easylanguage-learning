## Descripción de la Estrategia ATRDollar TrailStop v2

### ¿Qué es este componente?

🧩 **Este NO es una estrategia completa**, es un bloque con:

- 🔹 Componente de salida (exit-only)
- 🔹 Trailing stop dinámico basado en ATR
- 🔹 Con activación previa ("floor")
- 🔹 No decide cuándo entrar, solo decide cómo salir, y lo hace de forma inteligente, adaptándose a la volatilidad del mercado (ATR) y protegiendo beneficios una vez que el precio se ha movido a nuestro favor lo suficiente (floor).
- 🔹 Las entradas: NO están aquí, vienen de estrategias pre-creadas (MACD LE / SE)

### Detalle y explicación original según curso

Creación de un componente de estrategia de salida trailing stop con nivel de activación y cálculo de niveles de stop dinámicos predefinidos usando el ATR. Dicho componente de estrategia de sólo salida cierra las posiciones, tanto largas como cortas, con un stop trailing monetario usando el ATR pero solo después de que se haya alcanzado un nivel de activación del ATR. Usamos estrategias MACD predefinidas de TradeStation para las entradas.

### Motor de salida basado en volatilidad y estados

🧩 Se trata de un componente de salida inteligente, basado en volatilidad (ATR), que:

- 🔹 Protege al inicio
- 🔹 Exige progreso real al trade
- 🔹 Y solo entonces deja correr beneficios con un trailing dinámico
- 🔹 No entra al mercado. No decide dirección. Solo gestiona la salida
- 🔹 Las entradas: NO están aquí, vienen de estrategias pre-creadas (e.g., MACD LE/SE...)

### Flujo lógico paso a paso (barra a barra)

#### 🟦 Estado 1: Flat

- MarketPosition = 0
- TrailingActive = false
- Nada ocurre. El sistema está limpio.

#### 🟨 Estado 2: Trade abierto – SIN trailing

- MarketPosition ≠ 0
- TrailingActive = false
- ✔ Se aplica Stop Loss inicial
- ✔ Basado en ATRStopLoss × ATR
- ✔ Convertido a dinero con BigPointValue
- 📌 Objetivo aquí: no perder demasiado si el trade falla rápido

#### 🚪 Evento clave: activación del trailing (el "floor")

- 🔹 Para largo: High ≥ EntryPrice + (ATRFloor × ATR)
- 🔹 Para corto: Low ≤ EntryPrice − (ATRFloor × ATR)
- 👉 Solo si el mercado realmente se mueve a favor, activamos trailing.
- TrailingActive = true;

#### 🟩 Estado 3: Trailing activo

- SetDollarTrailing(ATRTrail × ATR × BigPointValue);
- Ahora:
  - 🔹 El stop sigue al precio
  - 🔹 Se adapta a la volatilidad
  - 🔹 Protege beneficios
  - 🔹 Deja respirar al mercado

### Resumen mental / interpretación conceptual

🧠 **Para interiorizar:**

- 🔑 Entro al mercado con riesgo controlado
- 🔑 Si el trade no demuestra valor, salgo rápido
- 🔑 Si demuestra valor, lo dejo correr
- 🔑 El mercado decide cuándo me saca, no yo
- 🔑 Todo se adapta automáticamente a la volatilidad

**O dicho de otra forma:** Primero sobrevivo, luego participo, solo después optimizo.
