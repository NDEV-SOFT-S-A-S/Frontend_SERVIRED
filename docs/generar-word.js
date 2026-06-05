const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
  UnderlineType, PageBreak
} = require("docx");
const fs = require("fs");

// ── Colores ───────────────────────────────────────────────────────────────────
const AZUL_OSCURO  = "0C2577";
const AZUL_CLARO   = "BDD7EE";
const GRIS_HEADER  = "F0F0F0";
const GRIS_FILA    = "F7F7F7";
const ROJO_CLARO   = "FFE0E0";
const VERDE_CLARO  = "E2EFDA";
const BLANCO       = "FFFFFF";
const NEGRO        = "000000";

// ── Helpers de texto ──────────────────────────────────────────────────────────
const t = (text, opts = {}) => new TextRun({
  text,
  font: "Calibri",
  size: opts.size || 22,
  bold: opts.bold || false,
  color: opts.color || NEGRO,
  italics: opts.italic || false,
  underline: opts.underline ? { type: UnderlineType.SINGLE } : undefined,
});

const h1 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_1,
  spacing: { before: 400, after: 200 },
  children: [new TextRun({ text, font: "Calibri", size: 36, bold: true, color: AZUL_OSCURO })],
});

const h2 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_2,
  spacing: { before: 360, after: 160 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: AZUL_OSCURO } },
  children: [new TextRun({ text, font: "Calibri", size: 28, bold: true, color: AZUL_OSCURO })],
});

const h3 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_3,
  spacing: { before: 240, after: 120 },
  children: [new TextRun({ text, font: "Calibri", size: 24, bold: true, color: AZUL_OSCURO })],
});

const p = (text, opts = {}) => new Paragraph({
  alignment: opts.center ? AlignmentType.CENTER : AlignmentType.JUSTIFIED,
  spacing: { before: 100, after: 100 },
  children: [t(text, opts)],
});

const bullet = (text, opts = {}) => new Paragraph({
  bullet: { level: 0 },
  spacing: { before: 60, after: 60 },
  children: [t(text, opts)],
});

const bullet2 = (text) => new Paragraph({
  bullet: { level: 1 },
  spacing: { before: 40, after: 40 },
  children: [t(text, { size: 20 })],
});

const spacer = () => new Paragraph({ children: [t("")], spacing: { before: 80, after: 80 } });

const aviso = (text) => new Paragraph({
  spacing: { before: 140, after: 140 },
  shading: { type: ShadingType.CLEAR, fill: ROJO_CLARO },
  border: {
    left: { style: BorderStyle.THICK, size: 12, color: "C00000" },
  },
  children: [new TextRun({ text, font: "Calibri", size: 22, bold: true, color: "C00000" })],
});

const nota = (text) => new Paragraph({
  spacing: { before: 140, after: 140 },
  shading: { type: ShadingType.CLEAR, fill: AZUL_CLARO },
  border: {
    left: { style: BorderStyle.THICK, size: 12, color: AZUL_OSCURO },
  },
  children: [new TextRun({ text, font: "Calibri", size: 22, color: AZUL_OSCURO })],
});

const codigo = (text) => new Paragraph({
  spacing: { before: 80, after: 80 },
  shading: { type: ShadingType.CLEAR, fill: "EFEFEF" },
  children: [new TextRun({ text, font: "Courier New", size: 20, color: "333333" })],
});

// ── Helpers de tabla ──────────────────────────────────────────────────────────
const cell = (text, opts = {}) => new TableCell({
  shading: opts.bg ? { type: ShadingType.CLEAR, fill: opts.bg } : undefined,
  width: opts.width ? { size: opts.width, type: WidthType.PERCENTAGE } : undefined,
  margins: { top: 80, bottom: 80, left: 120, right: 120 },
  children: [new Paragraph({
    alignment: AlignmentType.LEFT,
    children: [new TextRun({
      text,
      font: "Calibri",
      size: opts.size || 20,
      bold: opts.bold || false,
      color: opts.color || NEGRO,
    })],
  })],
});

const tableHeader = (cols) => new TableRow({
  tableHeader: true,
  children: cols.map(([text, w]) => cell(text, { bg: AZUL_OSCURO, bold: true, color: BLANCO, width: w })),
});

const tableRow = (cols, bg) => new TableRow({
  children: cols.map(([text, w]) => cell(text, { bg: bg || BLANCO, width: w })),
});

const tableRowAlt = (cols, isOdd) => tableRow(cols, isOdd ? GRIS_FILA : BLANCO);

const checkRow = (num, text) => new TableRow({
  children: [
    cell(String(num), { bg: AZUL_OSCURO, bold: true, color: BLANCO, width: 5 }),
    cell(text, { width: 75 }),
    cell("☐", { width: 20, bold: true }),
  ],
});

// ── DOCUMENTO ────────────────────────────────────────────────────────────────

const doc = new Document({
  styles: {
    default: {
      document: { run: { font: "Calibri", size: 22, color: NEGRO } },
    },
  },
  sections: [{
    properties: {
      page: {
        margin: { top: 1200, bottom: 1200, left: 1200, right: 1200 },
      },
    },
    children: [

      // ── PORTADA ──────────────────────────────────────────────────────────
      new Paragraph({ spacing: { before: 1200 }, children: [t("")] }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 200, after: 200 },
        children: [new TextRun({ text: "ESPECIFICACIONES TÉCNICAS DE DISEÑO EN FIGMA", font: "Calibri", size: 44, bold: true, color: AZUL_OSCURO })],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 100, after: 100 },
        children: [new TextRun({ text: "Documento de Requisitos para Diseñadores UI/UX", font: "Calibri", size: 30, bold: true, color: "444444" })],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 100, after: 600 },
        children: [new TextRun({ text: "Plataforma Gane Web  —  SERVIRED", font: "Calibri", size: 26, color: "666666" })],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 600 },
        children: [new TextRun({ text: "Versión: 1.0     |     Fecha: 04 de junio de 2026     |     Estado: Vigente", font: "Calibri", size: 22, color: "888888" })],
      }),
      new Paragraph({ children: [new PageBreak()] }),

      // ── 1. PROPÓSITO ─────────────────────────────────────────────────────
      h1("1. PROPÓSITO"),
      p("El presente documento establece los estándares mínimos que deben cumplir todos los archivos de diseño entregados en Figma para el proyecto Plataforma Gane Web. Estos estándares garantizan la correcta integración entre el equipo de diseño y el equipo de desarrollo, y son requisito indispensable para que las herramientas de implementación automatizada (MCP — Model Context Protocol) funcionen sin errores."),
      spacer(),
      aviso("IMPORTANTE: El incumplimiento de cualquiera de las especificaciones aquí descritas será causal de devolución del entregable sin aprobación hasta que sea corregido."),

      // ── 2. NOMENCLATURA ──────────────────────────────────────────────────
      h1("2. ESPECIFICACIONES DE NOMENCLATURA"),

      h2("2.1  Regla principal — Nombres únicos"),
      aviso("Está estrictamente prohibido que dos frames tengan el mismo nombre dentro del mismo archivo de Figma."),
      spacer(),
      p("Cuando dos frames comparten el mismo nombre, las herramientas de desarrollo no pueden distinguirlos, lo que genera errores en la implementación, pérdida de tiempo y reproceso."),
      spacer(),
      p("Formato obligatorio para nombrar frames:", { bold: true }),
      codigo("    [Producto] — [Pantalla] — [Modo] — [Estado]"),
      spacer(),
      p("Cada segmento está separado por un guion largo ( — ). Todos los segmentos deben escribirse respetando las mayúsculas y minúsculas definidas en este documento."),

      h2("2.2  Segmentos del nombre"),
      h3("Segmento 1 — Producto"),
      p("Indica el producto o módulo al que pertenece la pantalla. Debe usarse exactamente el prefijo de la siguiente tabla. No se acepta ninguna variación ortográfica."),
      spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Producto", 60], ["Prefijo obligatorio", 40]]),
          tableRowAlt([["Baloto / Baloto Revancha", 60], ["Baloto", 40]], true),
          tableRowAlt([["Chance Millonario", 60], ["ChanceMillonario", 40]], false),
          tableRowAlt([["Chance Tradicional", 60], ["ChanceTradicional", 40]], true),
          tableRowAlt([["SuperWin", 60], ["Superwin", 40]], false),
          tableRowAlt([["Pata Millonaria", 60], ["PataMillonaria", 40]], true),
          tableRowAlt([["Dominguero", 60], ["Dominguero", 40]], false),
          tableRowAlt([["Paga Todo", 60], ["PagaTodo", 40]], true),
          tableRowAlt([["Carrito de compras", 60], ["Carrito", 40]], false),
          tableRowAlt([["Inicio de sesión / Registro", 60], ["Auth", 40]], true),
          tableRowAlt([["Perfil y cuenta de usuario", 60], ["Cuenta", 40]], false),
          tableRowAlt([["Resultados de sorteos", 60], ["Resultados", 40]], true),
          tableRowAlt([["Página de inicio", 60], ["Home", 40]], false),
        ],
      }),

      spacer(),
      h3("Segmento 2 — Pantalla"),
      p("Indica el nombre de la pantalla específica dentro del producto. Debe ser una sola palabra o palabras unidas sin espacios, describiendo la función principal de la pantalla."),
      p("Ejemplos válidos: Juego, Carrito, Confirmacion, Ticket, Perfil, Resultados, Registro, Login."),

      spacer(),
      h3("Segmento 3 — Modo"),
      p("Indica el modo de interacción que se muestra en el frame. Es obligatorio únicamente cuando la pantalla tiene más de un modo de funcionamiento."),
      spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Modo", 30], ["Cuándo usarlo", 70]]),
          tableRowAlt([["Manual", 30], ["El usuario ingresa los datos de forma manual", 70]], true),
          tableRowAlt([["Automatico", 30], ["El sistema genera los datos automáticamente", 70]], false),
          tableRowAlt([["Desktop", 30], ["Vista diseñada exclusivamente para escritorio", 70]], true),
          tableRowAlt([["Mobile", 30], ["Vista diseñada exclusivamente para móvil", 70]], false),
        ],
      }),

      spacer(),
      h3("Segmento 4 — Estado"),
      p("Indica el estado visual específico que representa el frame. Este segmento es siempre obligatorio. Ningún frame puede entregarse sin sufijo de estado."),
      spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Estado", 30], ["Cuándo usarlo", 70]]),
          tableRowAlt([["Vacio", 30], ["Estado inicial de la pantalla, sin datos ingresados por el usuario", 70]], true),
          tableRowAlt([["ConDatos", 30], ["Estado con información parcialmente completada", 70]], false),
          tableRowAlt([["Lleno", 30], ["Estado con todos los campos y selecciones completas", 70]], true),
          tableRowAlt([["ConError", 30], ["Estado que muestra un mensaje de error general", 70]], false),
          tableRowAlt([["ErrorCampo", 30], ["Estado que muestra un error en un campo específico", 70]], true),
          tableRowAlt([["Cargando", 30], ["Estado durante un proceso de carga o envío", 70]], false),
          tableRowAlt([["Exitoso", 30], ["Estado que confirma que una acción fue completada con éxito", 70]], true),
          tableRowAlt([["Bloqueado", 30], ["Estado de acceso restringido por cualquier motivo", 70]], false),
        ],
      }),

      h2("2.3  Ejemplos correctos e incorrectos"),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Nombre incorrecto", 30], ["Motivo del rechazo", 40], ["Nombre correcto", 30]]),
          tableRowAlt([["BalotoRevancha", 30], ["Sin modo ni estado", 40], ["Baloto — Juego — Manual — Vacio", 30]], true),
          tableRowAlt([["BalotoRevancha (×6 veces)", 30], ["Nombre duplicado", 40], ["Baloto — Juego — Manual — ConError", 30]], false),
          tableRowAlt([["Pantalla 1", 30], ["Sin estructura definida", 40], ["Auth — Login — Vacio", 30]], true),
          tableRowAlt([["Frame 2085663175", 30], ["Nombre automático de Figma", 40], ["Baloto — Juego — Manual — Lleno", 30]], false),
          tableRowAlt([["Carrito", 30], ["Sin estado", 40], ["Carrito — Resumen — Normal", 30]], true),
          tableRowAlt([["Login copy", 30], ["Duplicado no renombrado", 40], ["Auth — Login — ConError", 30]], false),
        ],
      }),

      h2("2.4  Nomenclatura de componentes y capas internas"),
      p("Todas las capas, grupos y componentes dentro de un frame deben tener nombres funcionales. Están completamente prohibidos los nombres genéricos que Figma genera automáticamente."),
      spacer(),
      aviso("Nombres prohibidos: Frame 1, Frame 2, Rectangle, Rectangle 3, Group, Group 12, Vector, Ellipse, Ellipse 4, Layer 1, Component 1, o cualquier nombre que sea un tipo de elemento seguido de un número."),
      spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Elemento", 25], ["Nombre prohibido", 35], ["Nombre correcto", 40]]),
          tableRowAlt([["Contenedor principal", 25], ["Frame 1", 35], ["CardPrincipal", 40]], true),
          tableRowAlt([["Barra de encabezado", 25], ["Rectangle 3", 35], ["HeaderBarra", 40]], false),
          tableRowAlt([["Grupo de botones", 25], ["Group 12", 35], ["BotonesAccion", 40]], true),
          tableRowAlt([["Ícono de eliminar", 25], ["Vector", 35], ["IconoEliminar", 40]], false),
          tableRowAlt([["Círculo de número", 25], ["Ellipse 4", 35], ["BolaNumero", 40]], true),
          tableRowAlt([["Sección de balotas", 25], ["Frame 2085663275", 35], ["SeccionBalotas", 40]], false),
        ],
      }),

      // ── 3. ORGANIZACIÓN ──────────────────────────────────────────────────
      new Paragraph({ children: [new PageBreak()] }),
      h1("3. ESPECIFICACIONES DE ORGANIZACIÓN"),

      h2("3.1  Secciones por flujo de usuario"),
      p("Cada flujo de usuario debe estar contenido dentro de una sección (Section) de Figma con un nombre descriptivo. Está prohibido mezclar flujos distintos dentro de una misma sección."),
      spacer(),
      p("Formato del nombre de sección:", { bold: true }),
      codigo("    Flujo — [Producto] — [Descripción del flujo]"),
      spacer(),
      p("Ejemplos:"),
      bullet("Flujo — Baloto — Selección de números"),
      bullet("Flujo — Baloto — Carrito y pago"),
      bullet("Flujo — Auth — Registro de usuario"),
      bullet("Flujo — Auth — Recuperación de contraseña"),
      bullet("Flujo — Cuenta — Gestión de perfil"),

      h2("3.2  Orden de los frames dentro de una sección"),
      p("Los frames dentro de cada sección deben estar ordenados de izquierda a derecha, siguiendo el orden cronológico del flujo del usuario. El primer estado que ve el usuario va primero, y el último estado va al final."),

      h2("3.3  Un frame por estado — prohibición de capas ocultas"),
      p("Cada estado posible de una pantalla debe tener su propio frame independiente y visible. Está prohibido usar un solo frame con capas ocultas para representar múltiples estados."),
      spacer(),
      nota("INCORRECTO: Un frame con capas ocultas (visibility off) que simulan estados distintos."),
      nota("CORRECTO: Un frame independiente y visible por cada estado de la pantalla."),

      // ── 4. ACCESIBILIDAD TÉCNICA ─────────────────────────────────────────
      h1("4. ESPECIFICACIONES DE ACCESIBILIDAD TÉCNICA"),

      h2("4.1  Node ID referenciable por URL"),
      p("Cada frame de pantalla debe poder ser referenciado de forma directa mediante su URL en Figma. Para verificar que un frame cumple este requisito:"),
      bullet("Seleccionar el frame en Figma."),
      bullet('Usar la opcion "Copy link" (clic derecho -> "Copy link to selection").'),
      bullet("Verificar que la URL generada contenga el parámetro node-id=XXXX-XXXX."),
      spacer(),
      aviso("Si al copiar el enlace la URL no contiene node-id, el frame no está correctamente definido y debe corregirse antes de entregar."),

      h2("4.2  Jerarquía de capas"),
      p("La jerarquía de capas dentro de cada frame debe reflejar el orden visual de la pantalla, de arriba hacia abajo y de izquierda a derecha. Las capas no deben estar desordenadas ni por fuera de sus contenedores lógicos."),

      h2("4.3  Uso correcto de componentes y variantes"),
      p("Cuando un elemento se repite en múltiples pantallas (botones, inputs, tarjetas, íconos), debe estar definido como componente en Figma y reutilizarse mediante instancias. No se aceptan copias manuales del mismo elemento sin haberlo definido como componente."),
      spacer(),
      p("Ejemplo correcto de variantes de un botón:"),
      bullet("Boton / Primario / Activo"),
      bullet("Boton / Primario / Deshabilitado"),
      bullet("Boton / Secundario / Activo"),
      bullet("Boton / Secundario / Deshabilitado"),

      // ── 5. CLICKUP ───────────────────────────────────────────────────────
      new Paragraph({ children: [new PageBreak()] }),
      h1("5. GESTIÓN DE TAREAS EN CLICKUP"),

      h2("5.1  Obligatoriedad"),
      aviso("El uso de ClickUp es obligatorio para todos los diseñadores. Trabajo sin registro en ClickUp equivale contractualmente a trabajo no realizado."),
      spacer(),
      p("El diseñador debe crear una tarea en ClickUp por cada pantalla, flujo o componente que vaya a diseñar, antes de iniciar el trabajo. No se aceptan tareas creadas con retroactividad."),

      h2("5.2  Campos obligatorios de cada tarea"),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Campo", 20], ["Descripción", 55], ["Ejemplo", 25]]),
          tableRowAlt([["Nombre de la tarea", 20], ["Nombre exacto del frame siguiendo la nomenclatura de la sección 2", 55], ["Baloto — Juego — Manual — Vacio", 25]], true),
          tableRowAlt([["Descripción", 20], ["Qué pantalla se diseña, qué estados incluye y cuál es el objetivo funcional", 55], ["Pantalla inicial del juego Baloto en modo manual...", 25]], false),
          tableRowAlt([["Estado inicial", 20], ["Debe marcarse En progreso desde el momento en que se empieza a trabajar", 55], ["En progreso", 25]], true),
          tableRowAlt([["Fecha de entrega", 20], ["Fecha límite acordada con el líder del proyecto", 55], ["08/06/2026", 25]], false),
          tableRowAlt([["Prioridad", 20], ["Nivel de urgencia asignado con el líder del proyecto", 55], ["Alta, Media o Baja", 25]], true),
          tableRowAlt([["Asignado a", 20], ["El diseñador responsable del entregable", 55], ["Nombre del diseñador", 25]], false),
          tableRowAlt([["Enlace a Figma", 20], ["URL directa al frame con node-id, no al archivo general", 55], ["https://figma.com/design/...?node-id=1026-4047", 25]], true),
          tableRowAlt([["Etiquetas", 20], ["Clasifican la tarea por producto y tipo de trabajo", 55], ["Baloto, Diseño de pantalla, Desktop", 25]], false),
        ],
      }),

      h2("5.3  Estados del ciclo de vida de la tarea"),
      p("El diseñador tiene la obligación de mantener actualizado el estado de cada tarea. Los estados deben cambiarse el mismo día en que ocurre el evento."),
      spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Estado en ClickUp", 30], ["Cuándo cambiarlo", 70]]),
          tableRowAlt([["Por hacer", 30], ["Tarea creada pero no iniciada aún", 70]], true),
          tableRowAlt([["En progreso", 30], ["En el momento en que se empieza a trabajar en el diseño", 70]], false),
          tableRowAlt([["En revisión", 30], ["Cuando el diseño está terminado y se envía al líder para aprobación", 70]], true),
          tableRowAlt([["Con observaciones", 30], ["Cuando el líder o desarrollo devuelve el diseño con comentarios", 70]], false),
          tableRowAlt([["Corrigiendo", 30], ["Cuando el diseñador está aplicando las correcciones señaladas", 70]], true),
          tableRowAlt([["Completado", 30], ["Cuando el diseño fue aprobado sin observaciones pendientes", 70]], false),
        ],
      }),
      aviso("El estado de la tarea debe actualizarse el mismo día en que ocurre el cambio. No se acepta actualizar estados con días de retraso."),

      h2("5.4  Comentarios y trazabilidad"),
      p("Cada vez que ocurra un evento relevante, el diseñador debe dejar un comentario en ClickUp registrando dicho evento:"),
      bullet("Al subir una nueva versión a Figma: indicar qué cambió y adjuntar el enlace actualizado."),
      bullet("Al recibir observaciones: confirmar que fueron leídas y describir cómo se van a resolver."),
      bullet("Al terminar correcciones: indicar qué se corrigió y actualizar el enlace de Figma."),
      bullet("Al bloquearse por una dependencia: describir el bloqueo y a quién corresponde resolverlo."),

      h2("5.5  Nomenclatura de tareas en ClickUp"),
      p("El nombre de la tarea en ClickUp debe coincidir exactamente con el nombre del frame en Figma."),
      spacer(),
      p("Si una tarea agrupa varios estados, el nombre indica esto y la descripción lista cada estado:"),
      bullet("Nombre: Baloto — Juego — Manual — Todos los estados"),
      bullet2("Baloto — Juego — Manual — Vacio"),
      bullet2("Baloto — Juego — Manual — ConError"),
      bullet2("Baloto — Juego — Manual — Lleno"),

      h2("5.6  Estructura de carpetas en ClickUp"),
      p("Las tareas deben organizarse dentro de la estructura de carpetas definida por el líder del proyecto. El diseñador no debe crear carpetas o listas nuevas sin autorización previa."),
      spacer(),
      new Table({
        width: { size: 70, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Carpeta en ClickUp", 100]]),
          tableRowAlt([["Diseño UI/UX > Baloto", 100]], true),
          tableRowAlt([["Diseño UI/UX > Chance Millonario", 100]], false),
          tableRowAlt([["Diseño UI/UX > Chance Tradicional", 100]], true),
          tableRowAlt([["Diseño UI/UX > SuperWin", 100]], false),
          tableRowAlt([["Diseño UI/UX > Pata Millonaria", 100]], true),
          tableRowAlt([["Diseño UI/UX > Dominguero", 100]], false),
          tableRowAlt([["Diseño UI/UX > Paga Todo", 100]], true),
          tableRowAlt([["Diseño UI/UX > Carrito y Pagos", 100]], false),
          tableRowAlt([["Diseño UI/UX > Autenticacion", 100]], true),
          tableRowAlt([["Diseño UI/UX > Cuenta y Perfil", 100]], false),
          tableRowAlt([["Diseño UI/UX > Componentes y Sistema de Diseño", 100]], true),
        ],
      }),

      // ── 6. CHECKLIST ─────────────────────────────────────────────────────
      new Paragraph({ children: [new PageBreak()] }),
      h1("6. CHECKLIST DE ENTREGA"),
      p("Antes de enviar cualquier entregable para revisión, el diseñador debe completar la siguiente lista de verificación. El entregable no será recibido si algún punto está sin cumplir."),
      spacer(),
      h2("Figma — Nomenclatura y estructura"),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["#", 5], ["Verificación", 75], ["Cumple", 20]]),
          checkRow(1,  "Ningún frame tiene el mismo nombre que otro frame en el archivo"),
          checkRow(2,  "Todos los frames siguen el formato [Producto] — [Pantalla] — [Modo] — [Estado]"),
          checkRow(3,  "Todos los frames de pantalla tienen sufijo de estado"),
          checkRow(4,  "Ninguna capa tiene nombre genérico (Frame N, Rectangle N, Group N, Vector, etc.)"),
          checkRow(5,  "Cada flujo está agrupado en su propia sección con nombre descriptivo"),
          checkRow(6,  "Los frames dentro de cada sección están ordenados siguiendo el flujo del usuario"),
          checkRow(7,  "Cada frame de pantalla tiene node-id accesible mediante URL"),
          checkRow(8,  "No existen frames con capas ocultas para simular estados distintos"),
          checkRow(9,  "La jerarquía de capas refleja el orden visual de la pantalla"),
          checkRow(10, "Los elementos repetidos están definidos como componentes y se usan instancias"),
        ],
      }),
      spacer(),
      h2("ClickUp — Gestión de tareas"),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["#", 5], ["Verificación", 75], ["Cumple", 20]]),
          checkRow(11, "Existe una tarea en ClickUp creada antes de iniciar el diseño"),
          checkRow(12, "El nombre de la tarea en ClickUp coincide exactamente con el nombre del frame en Figma"),
          checkRow(13, "La tarea contiene todos los campos obligatorios: descripción, fecha, prioridad, asignado, enlace Figma y etiquetas"),
          checkRow(14, "El estado de la tarea está actualizado al estado real del trabajo"),
          checkRow(15, "Se dejó un comentario en ClickUp registrando el envío del entregable"),
          checkRow(16, "El enlace de Figma en la tarea apunta al frame específico con node-id"),
          checkRow(17, "La tarea está ubicada dentro de la carpeta correcta según el producto"),
        ],
      }),

      // ── 7. CONDICIONES ───────────────────────────────────────────────────
      h1("7. CONDICIONES DE RECEPCIÓN Y DEVOLUCIÓN"),
      p("El equipo de desarrollo revisará el cumplimiento de estas especificaciones en un plazo máximo de 2 días hábiles tras recibir el entregable. En caso de incumplimiento:"),
      bullet("Se notificará al diseñador los puntos específicos que no cumplen."),
      bullet("El diseñador tendrá 2 días hábiles para realizar las correcciones."),
      bullet("El entregable no se considerará recibido a satisfacción hasta que pase la revisión completa."),
      bullet("Los reprocesos generados por incumplimiento son responsabilidad del diseñador y no generan tiempo adicional en el cronograma."),
      spacer(),
      aviso("CAUSALES DE DEVOLUCIÓN INMEDIATA SIN REVISIÓN:"),
      bullet("1. Frames con nombres duplicados en el archivo Figma.", { bold: true }),
      bullet("2. Ausencia de tarea en ClickUp correspondiente al entregable.", { bold: true }),
      bullet("3. Tarea en ClickUp sin enlace directo al frame con node-id.", { bold: true }),
      bullet("4. Estado de la tarea en ClickUp no actualizado al momento de la entrega.", { bold: true }),
      bullet("5. Frames nombrados con texto genérico (Frame N, Rectangle N, Pantalla 1, etc.).", { bold: true }),

      // ── 8. GLOSARIO ──────────────────────────────────────────────────────
      h1("8. GLOSARIO"),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          tableHeader([["Término", 25], ["Definición", 75]]),
          tableRowAlt([["Frame", 25], ["Contenedor principal en Figma que representa una pantalla completa o un componente de pantalla.", 75]], true),
          tableRowAlt([["Sección (Section)", 25], ["Agrupador visual en Figma que permite organizar frames por flujos o categorías.", 75]], false),
          tableRowAlt([["Node ID", 25], ["Identificador único que Figma asigna a cada elemento. Permite referenciar un frame directamente desde una URL.", 75]], true),
          tableRowAlt([["MCP", 25], ["Model Context Protocol. Herramienta de integración que permite al equipo de desarrollo leer e implementar diseños de Figma de forma automatizada.", 75]], false),
          tableRowAlt([["Variante", 25], ["Versión alternativa de un componente que difiere en alguna propiedad visual (color, tamaño, estado).", 75]], true),
          tableRowAlt([["Instancia", 25], ["Copia de un componente que hereda sus propiedades y se actualiza automáticamente cuando el componente original cambia.", 75]], false),
          tableRowAlt([["Capa oculta", 25], ["Elemento en Figma con visibilidad desactivada. Su uso para simular estados distintos dentro de un mismo frame está prohibido.", 75]], true),
          tableRowAlt([["Estado", 25], ["Condición visual específica de una pantalla en un momento dado del flujo del usuario (vacío, con error, cargando, exitoso, etc.).", 75]], false),
          tableRowAlt([["ClickUp", 25], ["Plataforma de gestión de tareas utilizada por el equipo para registrar, hacer seguimiento y aprobar el trabajo de diseño. Su uso es obligatorio.", 75]], true),
          tableRowAlt([["Tarea en ClickUp", 25], ["Registro formal del trabajo a realizar. Debe crearse antes de iniciar el diseño, mantenerse actualizada y cerrarse solo cuando el entregable es aprobado.", 75]], false),
        ],
      }),

      // ── FIRMA ────────────────────────────────────────────────────────────
      spacer(), spacer(),
      new Paragraph({
        border: { top: { style: BorderStyle.SINGLE, size: 6, color: AZUL_OSCURO } },
        spacing: { before: 400, after: 200 },
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "Este documento debe ser firmado por el diseñador como parte del contrato de prestación de servicios", font: "Calibri", size: 20, italics: true, color: "666666" })],
      }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "y constituye un anexo técnico de obligatorio cumplimiento.", font: "Calibri", size: 20, italics: true, color: "666666" })] }),

      spacer(), spacer(),
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          new TableRow({
            children: [
              new TableCell({
                width: { size: 45, type: WidthType.PERCENTAGE },
                borders: { bottom: { style: BorderStyle.SINGLE, size: 6, color: NEGRO } },
                margins: { top: 600, bottom: 200, left: 200, right: 200 },
                children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Firma del Diseñador", { size: 20 })] })],
              }),
              new TableCell({ width: { size: 10, type: WidthType.PERCENTAGE }, borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, children: [new Paragraph({ children: [t("")] })] }),
              new TableCell({
                width: { size: 45, type: WidthType.PERCENTAGE },
                borders: { bottom: { style: BorderStyle.SINGLE, size: 6, color: NEGRO } },
                margins: { top: 600, bottom: 200, left: 200, right: 200 },
                children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Firma del Líder de Proyecto", { size: 20 })] })],
              }),
            ],
          }),
          new TableRow({
            children: [
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, margins: { top: 100 }, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Nombre: _________________________", { size: 20 })] })] }),
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, children: [new Paragraph({ children: [t("")] })] }),
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, margins: { top: 100 }, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Nombre: _________________________", { size: 20 })] })] }),
            ],
          }),
          new TableRow({
            children: [
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, margins: { top: 60 }, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Fecha: ___________________________", { size: 20 })] })] }),
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, children: [new Paragraph({ children: [t("")] })] }),
              new TableCell({ borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } }, margins: { top: 60 }, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [t("Fecha: ___________________________", { size: 20 })] })] }),
            ],
          }),
        ],
      }),
    ],
  }],
});

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync("Especificaciones-Figma-SERVIRED.docx", buffer);
  console.log("Word generado: Especificaciones-Figma-SERVIRED.docx");
});
