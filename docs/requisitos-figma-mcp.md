# Requisitos para la creación de archivos Figma compatibles con MCP

Versión: 1.0 — 04/06/2026  
Proyecto: Plataforma Gane Web — SERVIRED

---

## REQ-FIG-001 — Nombres únicos por frame de pantalla

Cada frame que represente una pantalla o estado de pantalla debe tener un nombre único dentro del archivo Figma. No se permite repetir el mismo nombre en dos frames distintos.

**Formato obligatorio:**
```
[Producto]-[Pantalla]-[Modo]-[Estado]
```

**Ejemplos:**
```
Baloto-Juego-Manual-Vacío
Baloto-Juego-Manual-ErrorBalotas
Baloto-Juego-Manual-ErrorSuperbalota
Baloto-Juego-Automático-Vacío
Baloto-Juego-Automático-ConNúmeros
Baloto-Carrito-Normal
Cuenta-Perfil-Logueado
```

---

## REQ-FIG-002 — Sufijos de estado obligatorios

Todo frame debe incluir un sufijo que indique el estado visual que representa. No se aceptan frames sin sufijo de estado.

| Sufijo | Cuándo usarlo |
|---|---|
| `-Vacío` | Estado inicial sin datos ingresados |
| `-ConDatos` | Estado con información parcial cargada |
| `-Lleno` | Estado con todos los campos completos |
| `-ConError` | Estado mostrando un mensaje de error |
| `-ErrorBalotas` | Error específico en selección de balotas |
| `-ErrorSuperbalota` | Error específico en selección de superbalota |
| `-Cargando` | Estado de carga o procesamiento |
| `-Exitoso` | Estado tras una acción exitosa |
| `-Bloqueado` | Estado de acceso restringido (ej: geobloqueo) |

---

## REQ-FIG-003 — Sufijos de modo

Cuando una pantalla tiene más de un modo de interacción, el modo debe estar incluido en el nombre del frame.

| Sufijo | Cuándo usarlo |
|---|---|
| `-Manual` | El usuario ingresa datos manualmente |
| `-Automático` | El sistema genera datos automáticamente |
| `-Desktop` | Vista de escritorio (solo si difiere de móvil) |
| `-Mobile` | Vista móvil (solo si difiere de escritorio) |

---

## REQ-FIG-004 — Secciones por flujo

Cada flujo de usuario debe estar agrupado en una sección (Section) de Figma con un nombre descriptivo del flujo completo. No se deben mezclar flujos distintos dentro de una misma sección.

**Formato:**
```
Flujo-[Producto]-[Acción]
```

**Ejemplos:**
```
Flujo-Baloto-SelecciónNúmeros
Flujo-Baloto-Carrito
Flujo-Auth-Login
Flujo-Auth-Registro
Flujo-Cuenta-Perfil
```

---

## REQ-FIG-005 — Nomenclatura de componentes internos

Los componentes y capas internas de cada frame deben tener nombres funcionales. No se aceptan nombres genéricos generados automáticamente por Figma.

| No permitido | Requerido |
|---|---|
| `Frame 1` | `CardPrincipal` |
| `Frame 2085663175` | `HeaderBotones` |
| `Rectangle 3` | `FondoTarjeta` |
| `Group 12` | `SeccionBalotas` |
| `Ellipse 4` | `BolaNumero` |
| `Vector` | `IconoEliminar` |

---

## REQ-FIG-006 — Node ID accesible por URL

Cada frame de pantalla debe poder referenciarse de forma directa mediante su node-id en la URL de Figma. Para verificarlo:

1. Seleccionar el frame en Figma.
2. Copiar el enlace (`Ctrl+L` o clic derecho → "Copy link").
3. Confirmar que la URL contiene `node-id=XXXX-XXXX`.

El node-id debe corresponder al frame raíz de la pantalla, no a un componente interno.

---

## REQ-FIG-007 — Un frame por estado de pantalla

Cada estado posible de una pantalla debe tener su propio frame independiente. No se deben usar un único frame para representar múltiples estados mediante capas ocultas.

**Correcto:** Un frame por estado
```
Baloto-Juego-Manual-Vacío         → frame independiente
Baloto-Juego-Manual-ConError      → frame independiente
Baloto-Juego-Manual-Lleno         → frame independiente
```

**Incorrecto:** Un frame con capas ocultas que simulan estados
```
BalotoRevancha
  └── [layer visible]   Error state
  └── [layer oculta]   Empty state
  └── [layer oculta]   Filled state
```

---

## REQ-FIG-008 — Jerarquía de capas ordenada

La jerarquía de capas dentro de cada frame debe seguir el orden visual de arriba hacia abajo y de izquierda a derecha. Los grupos de capas deben nombrarse según su función en la interfaz.

**Estructura recomendada:**
```
[NombreFrame]
  ├── Header
  ├── Banner
  ├── CardPrincipal
  │     ├── Toggle-ModoJuego
  │     ├── SeccionBalotas
  │     └── SeccionLineas
  └── CardAvanzada
        ├── SelectorRevancha
        ├── SelectorSorteos
        ├── ResumenApuesta
        └── BotonesAccion
```

---

## REQ-FIG-009 — Convención de nombres por producto

Cada producto del catálogo debe usar un prefijo fijo en todos sus frames para facilitar la búsqueda y el filtrado dentro del archivo.

| Producto | Prefijo |
|---|---|
| Baloto / Baloto Revancha | `Baloto-` |
| Chance Millonario | `ChanceM-` |
| Chance Tradicional | `ChanceT-` |
| SuperWin | `Superwin-` |
| Pata Millonaria | `PataM-` |
| Dominguero | `Dominguero-` |
| Paga Todo | `PagaTodo-` |
| Carrito de compras | `Carrito-` |
| Autenticación | `Auth-` |
| Cuenta / Perfil | `Cuenta-` |

---

## REQ-FIG-010 — Revisión antes de entregar el archivo

Antes de compartir el archivo Figma para implementación, el diseñador debe verificar:

- [ ] Ningún frame tiene el mismo nombre que otro frame en el archivo.
- [ ] Todos los frames de pantalla tienen sufijo de estado.
- [ ] Todos los frames de pantalla tienen sufijo de modo (si aplica).
- [ ] Ninguna capa se llama `Frame N`, `Rectangle N`, `Group N`, `Vector`, `Ellipse N`.
- [ ] Cada flujo está agrupado en su propia sección con nombre descriptivo.
- [ ] Cada frame raíz de pantalla es seleccionable y tiene node-id en su URL.
- [ ] La jerarquía de capas refleja el orden visual de la pantalla.

---

## Tabla resumen de requisitos

| ID | Requisito | Prioridad |
|---|---|---|
| REQ-FIG-001 | Nombres únicos por frame | Alta |
| REQ-FIG-002 | Sufijos de estado obligatorios | Alta |
| REQ-FIG-003 | Sufijos de modo | Media |
| REQ-FIG-004 | Secciones por flujo | Alta |
| REQ-FIG-005 | Nomenclatura de componentes internos | Media |
| REQ-FIG-006 | Node ID accesible por URL | Alta |
| REQ-FIG-007 | Un frame por estado de pantalla | Alta |
| REQ-FIG-008 | Jerarquía de capas ordenada | Media |
| REQ-FIG-009 | Convención de nombres por producto | Media |
| REQ-FIG-010 | Revisión antes de entregar | Alta |
