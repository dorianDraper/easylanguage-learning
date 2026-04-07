# Password Protection — v1.0 & v2.0

🇪🇸 Español | 🇺🇸 [English](README.md)

## Descripción del Sistema

Password Protection es un componente de infraestructura para desarrolladores que demuestra cómo implementar protección de licencias en múltiples capas en indicadores y estrategias de EasyLanguage. No es un indicador de trading — es una plantilla para proteger la propiedad intelectual al distribuir código EasyLanguage comercialmente. El componente restringe la ejecución a un entorno de trading específico (símbolo y tipo de barra), valida una clave de licencia basada en contraseña, y soporta expiración de licencia con ventana temporal con un período de solapamiento para renovación sin interrupciones.

Las tres capas de protección operan en cascada: la validación del entorno se ejecuta una vez en la inicialización, la validación de la licencia se ejecuta en cada barra pero solo si el entorno es válido, y la lógica real del indicador se ejecuta solo si la licencia también es válida. Un fallo en cualquier capa impide silenciosamente que el indicador funcione — no se muestran mensajes de error, lo cual es intencional para la distribución comercial.

---

## Mecánica Central

### Capa 1 — Validación del Entorno

```pascal
Once Begin
    AppSymbol      = GetSymbolName;
    CurrentBarType = BarType;

    If AppSymbol = "MSFT" and CurrentBarType = 2 Then
        IsEnvironmentValid = True;
End;
```

`Once` es una palabra clave de EasyLanguage que restringe el bloque encerrado a ejecutarse **exactamente una vez** — en la primera barra del cálculo del indicador, durante la inicialización. Este es el patrón correcto para comprobaciones de entorno porque `GetSymbolName` y `BarType` son constantes durante toda la vida del indicador: no pueden cambiar mientras el indicador está en ejecución. Evaluarlos en cada barra sería computacionalmente redundante.

`GetSymbolName` devuelve el ticker del gráfico al que se aplica el indicador. `BarType` devuelve un entero que identifica el tipo de intervalo del gráfico — el valor `2` corresponde a barras diarias. Juntos, la condición `AppSymbol = "MSFT" and CurrentBarType = 2` restringe el indicador a exactamente una configuración: barras diarias de Microsoft. Cualquier otro símbolo o tipo de barra deja `IsEnvironmentValid = False` y el indicador no produce ninguna salida.

**Valores de `BarType` disponibles como referencia:**

| Valor | Tipo de Barra |
|---|---|
| 0 | Barras de tick |
| 1 | Barras de minutos |
| 2 | Barras diarias |
| 3 | Barras semanales |
| 4 | Barras mensuales |

### Capa 2 — Validación de Licencia

```pascal
If IsEnvironmentValid Then
Begin
    If Date < 1200601 and LicensePassword = "A123456789" Then
        IsLicenseValid = True;

    If Date > 1200401 and LicensePassword = "B123456789" Then
        IsLicenseValid = True;
End;
```

La validación de licencia solo se ejecuta cuando la comprobación del entorno fue exitosa. Se definen dos versiones de licencia por rangos de fecha y contraseñas correspondientes:

- **Licencia A:** Válida cuando `Date < 1200601` (antes del 1 de junio de 2020) y `LicensePassword = "A123456789"`.
- **Licencia B:** Válida cuando `Date > 1200401` (después del 1 de abril de 2020) y `LicensePassword = "B123456789"`.

**Formato de fecha de EasyLanguage:** Las fechas se expresan como enteros en formato `YYYMMDD` donde `YYY` es el año menos 1900. Por tanto `1200601` = año 2020 (1900+120), mes 06, día 01 = 1 de junio de 2020.

**La ventana de solapamiento — diseño intencional de transición de licencia:**

Los dos rangos de fecha se solapan entre el 1 de abril y el 1 de junio de 2020. Durante esta ventana de dos meses, **ambas contraseñas son válidas simultáneamente**. Esta es una decisión de diseño deliberada:

```
      1 Abr 2020    1 Jun 2020
           │               │
Licencia A:─────────────────┤  (expira Jun 1)
Licencia B:            ├────────────────────
           │               │
           └──Solapamiento──┘
           (ambas contraseñas válidas)
```

La ventana de solapamiento permite al vendedor distribuir la nueva contraseña de Licencia B a los clientes antes de que expire la Licencia A. El cliente puede introducir la nueva contraseña cuando le convenga durante el período de transición sin perder acceso. Si la ventana de solapamiento no existiera, cualquier cliente que no actualizara su contraseña antes de que expirara la Licencia A perdería el acceso de inmediato — una mala experiencia de usuario para un producto comercial.

### Capa 3 — Lógica del Indicador

```pascal
If IsLicenseValid Then
Begin
    Plot1(Average(Close, 20), "MA");
End;
```

La lógica real del indicador — en esta plantilla, una simple media móvil de 20 períodos — solo se ejecuta cuando tanto la validación del entorno como la de la licencia han sido superadas. En un indicador comercial real, este bloque contendría el cálculo propietario que se está protegiendo.

La lógica es completamente agnóstica a las capas de protección anteriores. Añadir o modificar la protección no requiere tocar la lógica del indicador, y viceversa. Esta separación de responsabilidades hace la plantilla fácil de adaptar: reemplaza la línea `Plot1` con cualquier lógica de indicador y la protección de tres capas funciona sin cambios.

---

## Arquitectura

Las tres capas se ejecutan en una cascada estricta:

```
Inicialización (Once)
    └─ Comprobación GetSymbolName + BarType
           │
           ├─ FALLO → IsEnvironmentValid = False → indicador silencioso siempre
           │
           └─ ÉXITO → IsEnvironmentValid = True
                          │
                    Cada barra:
                    Comprobación fecha + contraseña de licencia
                          │
                          ├─ FALLO → IsLicenseValid = False → indicador silencioso esta barra
                          │
                          └─ ÉXITO → IsLicenseValid = True
                                         │
                                   Lógica del indicador se ejecuta
                                   Plot1(...) mostrado en gráfico
```

**Por qué importa la cascada:** La validación del entorno usa `Once` porque el entorno nunca cambia. La validación de la licencia se ejecuta en cada barra porque `Date` cambia en cada barra — la comprobación de expiración de la licencia debe re-evaluarse continuamente. La lógica del indicador se ejecuta en cada barra porque el plot debe actualizarse continuamente.

---

## v1 vs v2: La Diferencia

v1 y v2 implementan lógica de protección idéntica. La evolución es enteramente estructural:

```pascal
// v1 — toda la lógica inline
If OK and
((Date < 1200601 and Password = "A123456789") or
 (Date > 1200401 and Password = "B123456789"))
Then Begin
    Plot1(Average(Close, 20), "MA");
End;

// v2 — separado en estados booleanos con nombre
If IsEnvironmentValid Then
Begin
    If Date < 1200601 and LicensePassword = "A123456789" Then IsLicenseValid = True;
    If Date > 1200401 and LicensePassword = "B123456789" Then IsLicenseValid = True;
End;

If IsLicenseValid Then
Begin
    Plot1(Average(Close, 20), "MA");
End;
```

v2 hace cada capa de protección independientemente legible y auditable. En v1, las tres capas están comprimidas en una única condición compuesta — entender la lógica requiere parsear operadores booleanos anidados. v2 asigna una variable de estado con nombre a cada capa (`IsEnvironmentValid`, `IsLicenseValid`), haciendo la cascada explícita y cada condición independientemente testable.

v2 también almacena `GetSymbolName` y `BarType` en variables con nombre (`AppSymbol`, `CurrentBarType`) antes de compararlos, haciendo la comprobación del entorno autodocumentada.

**Resumen:**

| | v1.0 | v2.0 |
|---|---|---|
| **Protección de tres capas** | ✓ | ✓ |
| **`Once` para comprobación de entorno** | ✓ | ✓ |
| **Ventana de transición por solapamiento** | ✓ | ✓ |
| **Variables de estado con nombre** | — | ✓ (`IsEnvironmentValid`, `IsLicenseValid`) |
| **Variables de entorno con nombre** | — | ✓ (`AppSymbol`, `CurrentBarType`) |
| **Bloques separados etiquetados** | — | ✓ |
| **`LicensePassword` (vs `Password`)** | — | ✓ (nombre de input más descriptivo) |

---

## Parámetros

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `LicensePassword` (`Password` en v1) | `"A123456789"` | La clave de licencia introducida por el usuario final. Debe coincidir con la contraseña válida actualmente para el rango de fecha activo. |

**Sobre el valor por defecto:** El valor por defecto `"A123456789"` es la contraseña de Licencia A — la licencia inicial. Un usuario que recibe el indicador introducirá esta como su clave de licencia. Cuando la Licencia B se vuelve activa, el vendedor distribuye `"B123456789"` y el usuario actualiza su input.

**Sobre el diseño de contraseñas para uso comercial:** Las contraseñas en esta plantilla son ilustrativas. En producción, las contraseñas deben ser más complejas (mayúsculas y minúsculas, símbolos, mayor longitud) e idealmente únicas por cliente — una contraseña por cliente permite al vendedor revocar una licencia específica sin afectar a otros clientes.

---

## Escenarios de Implementación

### Escenario A — Entorno Válido, Licencia A Válida

- Gráfico: barras diarias de MSFT. `IsEnvironmentValid = True`.
- Fecha: 15 de marzo de 2020 (`1200315`). `Date < 1200601` ✓.
- Usuario introdujo `LicensePassword = "A123456789"`. Coincide ✓.
- `IsLicenseValid = True`. **La media móvil se representa en el gráfico.**

### Escenario B — Entorno Válido, Licencia A Expirada, Licencia B No Introducida

- Gráfico: barras diarias de MSFT. `IsEnvironmentValid = True`.
- Fecha: 1 de julio de 2020 (`1200701`). `Date < 1200601` ✗ (Licencia A expirada).
- Usuario sigue con `LicensePassword = "A123456789"`. `Date > 1200401` ✓ pero contraseña incorrecta para B ✗.
- `IsLicenseValid = False`. **Indicador silencioso. Sin plot.**

### Escenario C — Ventana de Solapamiento, Ambas Contraseñas Válidas

- Fecha: 1 de mayo de 2020 (`1200501`). Entre el 1 de abril y el 1 de junio.
- `Date < 1200601` ✓ → Licencia A válida si la contraseña coincide.
- `Date > 1200401` ✓ → Licencia B válida si la contraseña coincide.
- Usuario con `"A123456789"` → `IsLicenseValid = True`. Usuario con `"B123456789"` → también `IsLicenseValid = True`.
- **Ambas contraseñas funcionan durante la ventana de transición.**

### Escenario D — Símbolo Incorrecto

- Gráfico: barras diarias de AAPL. `GetSymbolName = "AAPL"` ≠ `"MSFT"`.
- Bloque `Once`: `IsEnvironmentValid = False`.
- La comprobación de licencia nunca se ejecuta. **Indicador silencioso independientemente de la contraseña.**

### Escenario E — Tipo de Barra Incorrecto

- Gráfico: barras de 5 minutos de MSFT. `BarType = 1` ≠ `2`.
- Bloque `Once`: `IsEnvironmentValid = False`.
- **Indicador silencioso. Sin mensaje de error.**

---

## Características Clave

- **Fallo silencioso:** No se muestran mensajes de error cuando fallan las capas de protección — el indicador simplemente no produce salida. Esto evita que los usuarios finales sepan qué condición específica falló, haciendo la protección más difícil de revertir por ingeniería inversa.
- **Inicialización `Once`:** La validación del entorno se ejecuta exactamente una vez, en la inicialización, usando la palabra clave `Once` de EasyLanguage. Esto es tanto computacionalmente eficiente como semánticamente correcto — el entorno no puede cambiar mientras el indicador está en ejecución.
- **Ventana de transición por solapamiento:** El solapamiento de dos meses entre la expiración de la Licencia A y la activación de la Licencia B permite a los vendedores distribuir contraseñas de renovación antes de que expire la licencia existente, garantizando servicio ininterrumpido a los clientes de pago.
- **Expiración basada en fecha:** La validez de la licencia está vinculada a la variable `Date` de EasyLanguage (fecha de la barra del gráfico), no al reloj del sistema del ordenador. Esto significa que la expiración aplica a los datos que se están analizando, no al tiempo de calendario — útil para testing de estrategias sobre datos históricos donde la fecha del sistema no activaría la expiración.
- **Separación de responsabilidades (v2):** Cada capa de protección es un booleano con nombre independiente. Añadir una cuarta capa (p. ej. una comprobación de ID de máquina) requiere añadir una variable y un bloque `If`, sin tocar la lógica existente.
- **Diseño de plantilla:** La lógica del indicador (`Plot1`) está completamente aislada de las capas de protección. Cualquier lógica de indicador o estrategia puede reemplazar el bloque `Plot1` mientras la protección de tres capas permanece sin cambios.

---

## Casos de Uso

**Distribución comercial de EasyLanguage:** El caso de uso principal es proteger indicadores o estrategias propietarios antes de venderlos o licenciarlos a clientes. El código EasyLanguage se distribuye como archivos compilados `.eld` o `.elx`, pero la ingeniería inversa determinada es posible. La protección por contraseña añade una capa de comportamiento — incluso si la estructura del código queda expuesta, el indicador no funcionará sin la contraseña correcta en el entorno correcto.

**Licencias bloqueadas por símbolo:** Restringir el indicador a un símbolo específico (p. ej. `"MSFT"`) crea una licencia específica para ese símbolo — un cliente que compra una licencia para análisis de Microsoft no puede usar la misma contraseña para aplicar el indicador a Apple o futuros ES. Cada despliegue específico de símbolo requiere su propia licencia.

**Imposición del tipo de barra:** Requerir `BarType = 2` (diario) garantiza que el indicador se use en el contexto para el que fue diseñado y testeado. Un cliente que aplica un indicador de barras diarias a datos de 1 minuto y luego se queja de un comportamiento inesperado es un problema de soporte común — la comprobación del tipo de barra previene esta clase de uso inadecuado.

**Licencias basadas en suscripción:** El modelo de licencia con ventana temporal soporta productos de suscripción: un cliente recibe la Licencia A por un período de seis meses, luego recibe la Licencia B al renovar. La ventana de solapamiento garantiza que la transición sea fluida. Añadir más versiones de licencia (C, D, etc.) con ventanas de fecha sucesivas extiende el modelo indefinidamente.

**Protección de código interno:** Más allá del uso comercial, el mismo patrón puede proteger estrategias propietarias internas de ser copiadas o modificadas por miembros del equipo no autorizados — restringir a símbolos de cuenta interna o entornos específicos garantiza que la estrategia solo se ejecute en configuraciones aprobadas.

**Puntos de extensión para v3:** Las mejoras naturales para una versión lista para producción incluyen: contraseñas únicas por cliente (cada cliente recibe una clave diferente, permitiendo la revocación individual de licencias), validación de ID de máquina usando `GetLoginName` o equivalente para vinculación de hardware, comparación de contraseñas encriptada en lugar de comparación de strings en texto plano, y un contador de período de gracia que limita el número de barras que el indicador se ejecuta sin una licencia válida antes de desactivarse permanentemente.
