# ESPECIFICACIONES TÉCNICAS DE DISEÑO EN FIGMA
## Documento de requisitos para diseñadores UI/UX
### Plataforma Gane Web — SERVIRED
---

**Versión:** 1.0  
**Fecha:** 04 de junio de 2026  
**Estado:** Vigente  
**Aplicación:** Este documento forma parte integral del contrato de prestación de servicios de diseño. Su cumplimiento es obligatorio para la aprobación y recepción a satisfacción de los entregables de diseño.

---

## 1. PROPÓSITO

El presente documento establece los estándares mínimos que deben cumplir todos los archivos de diseño entregados en Figma para el proyecto Plataforma Gane Web. Estos estándares garantizan la correcta integración entre el equipo de diseño y el equipo de desarrollo, y son requisito indispensable para que las herramientas de implementación automatizada (MCP — Model Context Protocol) funcionen sin errores.

El incumplimiento de cualquiera de las especificaciones aquí descritas será causal de devolución del entregable sin aprobación hasta que sea corregido.

---

## 2. ESPECIFICACIONES DE NOMENCLATURA

### 2.1 Regla principal — Nombres únicos

**Cada frame que represente una pantalla o estado de pantalla debe tener un nombre único dentro del archivo Figma. Está estrictamente prohibido que dos frames tengan el mismo nombre.**

Esta es la regla más importante del documento. Cuando dos frames comparten el mismo nombre, las herramientas de desarrollo no pueden distinguirlos, lo que genera errores en la implementación, pérdida de tiempo y reproceso.

**Formato obligatorio para nombrar frames:**

```
[Producto] — [Pantalla] — [Modo] — [Estado]
```

Cada segmento está separado por un guion largo ( — ) y debe escribirse respetando mayúsculas y minúsculas tal como se definen en la sección 2.4 de este documento.

---

### 2.2 Segmentos del nombre

#### Segmento 1 — Producto

Indica el producto o módulo al que pertenece la pantalla. Debe usarse exactamente el prefijo asignado en la siguiente tabla. No se acepta ninguna variación ortográfica.

| Producto | Prefijo obligatorio |
|---|---|
| Baloto / Baloto Revancha | `Baloto` |
| Chance Millonario | `ChanceMillonario` |
| Chance Tradicional | `ChanceTradicional` |
| SuperWin | `Superwin` |
| Pata Millonaria | `PataMillonaria` |
| Dominguero | `Dominguero` |
| Paga Todo | `PagaTodo` |
| Carrito de compras | `Carrito` |
| Inicio de sesión / Registro | `Auth` |
| Perfil y cuenta de usuario | `Cuenta` |
| Resultados de sorteos | `Resultados` |
| Página de inicio | `Home` |

---

#### Segmento 2 — Pantalla

Indica el nombre de la pantalla específica dentro del producto. Debe ser una sola palabra o palabras unidas sin espacios, describiendo la función principal de la pantalla.

Ejemplos válidos: `Juego`, `Carrito`, `Confirmacion`, `Ticket`, `Perfil`, `Resultados`, `Registro`, `Login`.

---

#### Segmento 3 — Modo

Indica el modo de interacción que se muestra en el frame. Este segmento es obligatorio únicamente cuando la pantalla tiene más de un modo de funcionamiento.

| Modo | Cuándo usarlo |
|---|---|
| `Manual` | El usuario ingresa los datos de forma manual |
| `Automatico` | El sistema genera los datos automáticamente |
| `Desktop` | Vista diseñada exclusivamente para escritorio |
| `Mobile` | Vista diseñada exclusivamente para móvil |

Si la pantalla tiene una sola versión sin variaciones de modo, este segmento puede omitirse.

---

#### Segmento 4 — Estado

Indica el estado visual específico que representa el frame. Este segmento es **siempre obligatorio**. Ningún frame puede entregarse sin un sufijo de estado.

| Estado | Cuándo usarlo |
|---|---|
| `Vacio` | Estado inicial de la pantalla, sin datos ingresados por el usuario |
| `ConDatos` | Estado con información parcialmente completada |
| `Lleno` | Estado con todos los campos y selecciones completas |
| `ConError` | Estado que muestra un mensaje de error general |
| `ErrorCampo` | Estado que muestra un error en un campo específico |
| `Cargando` | Estado durante un proceso de carga o envío |
| `Exitoso` | Estado que confirma que una acción fue completada con éxito |
| `Bloqueado` | Estado de acceso restringido por cualquier motivo |

---

### 2.3 Ejemplos de nombres correctos e incorrectos

| Nombre incorrecto | Motivo del rechazo | Nombre correcto |
|---|---|---|
| `BalotoRevancha` | Sin modo ni estado | `Baloto — Juego — Manual — Vacio` |
| `BalotoRevancha` (repetido 6 veces) | Nombre duplicado | `Baloto — Juego — Manual — ConError` |
| `Pantalla 1` | Sin estructura definida | `Auth — Login — Vacio` |
| `Frame 2085663175` | Nombre generado automáticamente | `Baloto — Juego — Manual — Lleno` |
| `Carrito` | Sin estado | `Carrito — Resumen — Normal` |
| `Login copy` | Nombre de duplicado no renombrado | `Auth — Login — ConError` |

---

### 2.4 Nomenclatura de componentes y capas internas

Todas las capas, grupos y componentes dentro de un frame deben tener nombres funcionales que describan su rol en la interfaz. Están completamente prohibidos los nombres genéricos que Figma genera automáticamente.

**Nombres prohibidos:** `Frame 1`, `Frame 2`, `Rectangle`, `Rectangle 3`, `Group`, `Group 12`, `Vector`, `Ellipse`, `Ellipse 4`, `Layer 1`, `Component 1`, cualquier nombre que sea solo un tipo de elemento seguido de un número.

**Criterio para nombrar:** El nombre debe responder a la pregunta ¿qué función cumple este elemento en la pantalla?

| Elemento | Nombre prohibido | Nombre correcto |
|---|---|---|
| Contenedor principal | `Frame 1` | `CardPrincipal` |
| Barra de encabezado | `Rectangle 3` | `HeaderBarra` |
| Grupo de botones | `Group 12` | `BotonesAccion` |
| Ícono de eliminar | `Vector` | `IconoEliminar` |
| Círculo de número | `Ellipse 4` | `BolaNumero` |
| Sección de balotas | `Frame 2085663275` | `SeccionBalotas` |
| Área de líneas | `Frame 2085663276` | `AreaLineas` |
| Sección de revancha | `Frame 2085663141` | `SelectorRevancha` |

---

## 3. ESPECIFICACIONES DE ORGANIZACIÓN

### 3.1 Secciones por flujo de usuario

Cada flujo de usuario debe estar contenido dentro de una sección (Section) de Figma. Una sección agrupa exclusivamente los frames que pertenecen a un mismo flujo. Está prohibido mezclar flujos distintos dentro de una misma sección.

**Formato del nombre de sección:**
```
Flujo — [Producto] — [Descripción del flujo]
```

**Ejemplos:**
```
Flujo — Baloto — Selección de números
Flujo — Baloto — Carrito y pago
Flujo — Auth — Registro de usuario
Flujo — Auth — Recuperación de contraseña
Flujo — Cuenta — Gestión de perfil
```

---

### 3.2 Orden de los frames dentro de una sección

Los frames dentro de cada sección deben estar ordenados de izquierda a derecha siguiendo el orden cronológico del flujo del usuario, es decir, el primer estado que ve el usuario va primero, y el último estado va al final. Este orden facilita la lectura del flujo por parte del equipo de desarrollo.

---

### 3.3 Un frame por estado — prohibición de capas ocultas para simular estados

Cada estado posible de una pantalla debe tener su propio frame independiente y visible. Está prohibido usar un solo frame con capas ocultas (visibility off) para representar múltiples estados.

**Incorrecto — un frame con capas ocultas:**
```
BalotoRevancha
  ├── [visible]   Contenido estado vacío
  ├── [oculto]    Contenido estado con error
  └── [oculto]    Contenido estado lleno
```

**Correcto — un frame por estado:**
```
Baloto — Juego — Manual — Vacio       → frame visible e independiente
Baloto — Juego — Manual — ConError    → frame visible e independiente
Baloto — Juego — Manual — Lleno       → frame visible e independiente
```

---

## 4. ESPECIFICACIONES DE ACCESIBILIDAD TÉCNICA

### 4.1 Node ID referenciable por URL

Cada frame de pantalla debe poder ser referenciado de forma directa mediante su URL en Figma. Para verificar que un frame cumple este requisito:

1. Seleccionar el frame en Figma.
2. Usar la opción "Copy link" (clic derecho sobre el frame → "Copy link to selection").
3. Verificar que la URL generada contenga el parámetro `node-id=XXXX-XXXX`.

Si al copiar el enlace la URL no contiene `node-id`, el frame no está correctamente definido como frame raíz y debe corregirse.

---

### 4.2 Jerarquía de capas

La jerarquía de capas dentro de cada frame debe reflejar el orden visual de la pantalla, de arriba hacia abajo y de izquierda a derecha. La estructura recomendada es la siguiente:

```
[NombreDelFrame]
  ├── Header
  ├── Banner
  ├── [SeccionPrincipal]
  │     ├── [SubseccionA]
  │     ├── [SubseccionB]
  │     └── [SubseccionC]
  └── [SeccionSecundaria]
        ├── [Elemento1]
        ├── [Elemento2]
        └── [BotonesAccion]
```

Las capas no deben estar desordenadas ni ubicadas por fuera de sus contenedores lógicos. Un elemento que visualmente pertenece a una sección debe estar dentro de esa sección en el panel de capas.

---

### 4.3 Uso correcto de componentes y variantes

Cuando un elemento se repite en múltiples pantallas (botones, inputs, tarjetas, íconos), debe estar definido como componente en Figma y reutilizarse mediante instancias. No se aceptan copias manuales del mismo elemento en pantallas distintas sin haberlo definido como componente.

Las variantes de un componente deben nombrarse con claridad indicando qué cambia entre una variante y otra.

**Ejemplo correcto de variantes de un botón:**
```
Boton / Primario / Activo
Boton / Primario / Deshabilitado
Boton / Secundario / Activo
Boton / Secundario / Deshabilitado
```

---

## 5. GESTIÓN DE TAREAS EN CLICKUP

### 5.1 Obligatoriedad

El uso de ClickUp como herramienta de gestión de tareas es obligatorio para todos los diseñadores vinculados al proyecto. No se acepta ningún flujo de trabajo que no esté registrado y actualizado en ClickUp. La ausencia de registro en ClickUp equivale a trabajo no realizado desde el punto de vista contractual.

---

### 5.2 Creación de tareas

El diseñador debe crear una tarea en ClickUp por cada pantalla, flujo o componente que vaya a diseñar, antes de iniciar el trabajo. No se aceptan tareas creadas con retroactividad (después de que el trabajo ya fue realizado).

**Cada tarea debe contener obligatoriamente los siguientes campos:**

| Campo | Descripción | Ejemplo |
|---|---|---|
| **Nombre de la tarea** | Nombre exacto del frame o flujo que se va a diseñar, siguiendo la nomenclatura definida en la sección 2 de este documento | `Baloto — Juego — Manual — Vacio` |
| **Descripción** | Explicación breve de qué pantalla o componente se está diseñando, qué estados incluye y cuál es el objetivo funcional del diseño | `Pantalla inicial del juego Baloto en modo manual. Incluye toggle de modo, grilla de selección de balotas, grilla de superbalota y barra de línea vacía.` |
| **Estado inicial** | Al crear la tarea debe marcarse como `En progreso` desde el momento en que se empieza a trabajar | `En progreso` |
| **Fecha de entrega** | Fecha límite acordada con el líder del proyecto para ese entregable específico | `08/06/2026` |
| **Prioridad** | Nivel de urgencia asignado en coordinación con el líder del proyecto | `Alta`, `Media` o `Baja` |
| **Asignado a** | El diseñador responsable del entregable | Nombre del diseñador |
| **Enlace a Figma** | URL directa al frame en Figma (con node-id), no al archivo general | `https://figma.com/design/...?node-id=1026-4047` |
| **Etiquetas** | Etiquetas que clasifiquen la tarea por producto y tipo de trabajo | `Baloto`, `Diseño de pantalla`, `Desktop` |

---

### 5.3 Actualización de tareas

El diseñador tiene la obligación de mantener actualizado el estado de cada tarea durante todo su ciclo de vida. Los estados disponibles y el momento en que deben usarse son los siguientes:

| Estado en ClickUp | Cuándo cambiarlo |
|---|---|
| `Por hacer` | Tarea creada pero no iniciada aún |
| `En progreso` | En el momento en que se empieza a trabajar en el diseño |
| `En revisión` | Cuando el diseño está terminado y se envía al líder para aprobación |
| `Con observaciones` | Cuando el líder o el equipo de desarrollo devuelve el diseño con comentarios |
| `Corrigiendo` | Cuando el diseñador está aplicando las correcciones señaladas |
| `Completado` | Cuando el diseño fue aprobado sin observaciones pendientes |

**El estado de la tarea debe actualizarse el mismo día en que ocurre el cambio.** No se acepta actualizar estados con días de retraso.

---

### 5.4 Comentarios y trazabilidad

Cada vez que ocurra un evento relevante relacionado con la tarea, el diseñador debe dejar un comentario en ClickUp registrando dicho evento. Esto incluye:

- Cuando se sube una nueva versión del diseño a Figma: indicar qué cambió y adjuntar el enlace actualizado.
- Cuando se reciben observaciones: confirmar que fueron leídas y describir brevemente cómo se van a resolver.
- Cuando se terminan correcciones: indicar qué se corrigió y actualizar el enlace de Figma.
- Cuando se bloquea el avance por una dependencia externa: describir el bloqueo y a quién corresponde resolverlo.

---

### 5.5 Nomenclatura de tareas en ClickUp

El nombre de la tarea en ClickUp debe coincidir exactamente con el nombre del frame en Figma. Esto permite al equipo de desarrollo encontrar el diseño correspondiente a cada tarea sin ambigüedad.

**Formato obligatorio del nombre de la tarea:**
```
[Producto] — [Pantalla] — [Modo] — [Estado]
```

Si una tarea agrupa varios estados de una misma pantalla, el nombre debe indicarlo explícitamente:
```
Baloto — Juego — Manual — Todos los estados
```

Y en la descripción listar cada estado incluido:
- `Baloto — Juego — Manual — Vacio`
- `Baloto — Juego — Manual — ConError`
- `Baloto — Juego — Manual — Lleno`

---

### 5.6 Estructura de carpetas en ClickUp

Las tareas deben organizarse dentro de la estructura de carpetas definida por el líder del proyecto. El diseñador no debe crear carpetas o listas nuevas sin autorización previa. La estructura base es la siguiente:

```
Proyecto: Plataforma Gane Web
  └── Diseño UI/UX
        ├── Baloto
        ├── Chance Millonario
        ├── Chance Tradicional
        ├── SuperWin
        ├── Pata Millonaria
        ├── Dominguero
        ├── Paga Todo
        ├── Carrito y Pagos
        ├── Autenticación
        ├── Cuenta y Perfil
        └── Componentes y Sistema de Diseño
```

---

## 6. CHECKLIST DE ENTREGA

Antes de considerar un entregable como terminado y enviarlo para revisión, el diseñador debe completar la siguiente lista de verificación. El entregable no será recibido si algún punto está sin cumplir.

**Figma — Nomenclatura y estructura**

| # | Verificación | Cumple |
|---|---|---|
| 1 | Ningún frame tiene el mismo nombre que otro frame en el archivo | ☐ |
| 2 | Todos los frames de pantalla siguen el formato `[Producto] — [Pantalla] — [Modo] — [Estado]` | ☐ |
| 3 | Todos los frames de pantalla tienen sufijo de estado | ☐ |
| 4 | Ninguna capa o componente tiene nombre genérico (`Frame N`, `Rectangle N`, `Group N`, `Vector`, etc.) | ☐ |
| 5 | Cada flujo está agrupado en su propia sección con nombre descriptivo | ☐ |
| 6 | Los frames dentro de cada sección están ordenados siguiendo el flujo del usuario | ☐ |
| 7 | Cada frame de pantalla tiene node-id accesible mediante URL | ☐ |
| 8 | No existen frames con capas ocultas para simular estados distintos | ☐ |
| 9 | La jerarquía de capas refleja el orden visual de la pantalla | ☐ |
| 10 | Los elementos repetidos están definidos como componentes y se usan instancias | ☐ |

**ClickUp — Gestión de tareas**

| # | Verificación | Cumple |
|---|---|---|
| 11 | Existe una tarea en ClickUp creada antes de iniciar el diseño | ☐ |
| 12 | El nombre de la tarea en ClickUp coincide exactamente con el nombre del frame en Figma | ☐ |
| 13 | La tarea contiene todos los campos obligatorios: descripción, fecha de entrega, prioridad, asignado, enlace a Figma y etiquetas | ☐ |
| 14 | El estado de la tarea está actualizado al estado real del trabajo | ☐ |
| 15 | Se dejó un comentario en ClickUp registrando el envío del entregable | ☐ |
| 16 | El enlace de Figma en la tarea apunta al frame específico con node-id, no al archivo general | ☐ |
| 17 | La tarea está ubicada dentro de la carpeta correcta según el producto | ☐ |

---

## 7. CONDICIONES DE RECEPCIÓN Y DEVOLUCIÓN

El equipo de desarrollo revisará el cumplimiento de estas especificaciones en un plazo máximo de **2 días hábiles** tras recibir el entregable. En caso de incumplimiento:

- Se notificará al diseñador los puntos específicos que no cumplen.
- El diseñador tendrá **2 días hábiles** para realizar las correcciones.
- El entregable no se considerará recibido a satisfacción hasta que pase la revisión completa.
- Los reprocesos generados por incumplimiento de estas especificaciones son responsabilidad del diseñador y no generan tiempo adicional en el cronograma del proyecto.

**Causales de devolución inmediata sin revisión:**

Las siguientes situaciones generan devolución automática del entregable sin iniciar revisión de contenido:

1. Frames con nombres duplicados en el archivo Figma.
2. Ausencia de tarea en ClickUp correspondiente al entregable.
3. Tarea en ClickUp sin enlace directo al frame con node-id.
4. Estado de la tarea en ClickUp no actualizado al momento de la entrega.
5. Frames nombrados con texto genérico (`Frame N`, `Rectangle N`, `Pantalla 1`, etc.).

---

## 8. GLOSARIO

| Término | Definición |
|---|---|
| **Frame** | Contenedor principal en Figma que representa una pantalla completa o un componente de pantalla. |
| **Sección (Section)** | Agrupador visual en Figma que permite organizar frames por flujos o categorías. |
| **Node ID** | Identificador único que Figma asigna a cada elemento. Permite referenciar un frame directamente desde una URL. |
| **MCP** | Model Context Protocol. Herramienta de integración que permite al equipo de desarrollo leer e implementar diseños de Figma de forma automática. |
| **Variante** | Versión alternativa de un componente que difiere en alguna propiedad visual (color, tamaño, estado). |
| **Instancia** | Copia de un componente que hereda sus propiedades y se actualiza automáticamente cuando el componente original cambia. |
| **Capa oculta** | Elemento en Figma con visibilidad desactivada. Su uso para simular estados distintos dentro de un mismo frame está prohibido por este documento. |
| **Estado** | Condición visual específica de una pantalla en un momento dado del flujo del usuario (vacío, con error, cargando, exitoso, etc.). |
| **ClickUp** | Plataforma de gestión de tareas y proyectos utilizada por el equipo para registrar, hacer seguimiento y aprobar el trabajo de diseño. Su uso es obligatorio durante toda la vigencia del contrato. |
| **Tarea en ClickUp** | Registro formal del trabajo a realizar. Debe crearse antes de iniciar el diseño, mantenerse actualizada durante el proceso y cerrarse únicamente cuando el entregable es aprobado. |

---

*Este documento debe ser firmado por el diseñador como parte del contrato de prestación de servicios y constituye un anexo técnico de obligatorio cumplimiento.*
