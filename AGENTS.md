# RaidDominion — Guía para Agentes

> Versión: 3.0.0 (reescritura) · Cliente: World of Warcraft 3.3.5a (WotLK) · Interface: 30300 · Locale: esMX
> Restricción de oro: **NO usar librerías externas (ni Ace3, ni LibStub, ni widgets de terceros).** Solo API estándar de WoW 3.3.5a + Lua 5.1.

## 1. Propósito

RaidDominion es un addon de gestión de raid para WoW 3.3.5a. Facilita asignación de roles, buffs, auras y habilidades en la banda, además de herramientas de hermandad (mensajes, sorteos, gearscore, bandas Core, reconocimiento).

Esta reescritura (v3) debe conservar la funcionalidad y *apariencia general* de la v2 (`RaidDominion-main`) pero con una arquitectura limpia, escalable y con alineación píxel-perfecta.

## 2. Objetivos de la v3

1. **Menú flotante**: una ventana flotante principal, arrastrable, escalable, con submenús definidos por datos (no por código hardcodeado).
2. **Ventana de configuración vinculada**: se abre desde el menú flotante y se **renderiza dinámicamente según lo que el usuario tenga seteado** (secciones/pestañas definidas por esquema + configuración activa).
3. **Alineación precisa**: todo elemento se posiciona con el sistema de alineación documentado abajo. WoW 3.3.5a usa unidades de `SetPoint/SetSize` sujetas a `UIParent:GetScale()`; los alineamientos deben ser consistentes y verificables.
4. **Sin dependencias**: ninguna librería externa.

## 3. Restricciones de plataforma (WoW 3.3.5a)

Conocimiento crítico que TODO cambio de código debe respetar:

- **Lua 5.1**: sin `goto`, sin operadores `//`, sin `table.move`/`table.unpack` (usar `unpack`). `select`, `ipairs/pairs` estándar.
- **Interface 30300**: APIs nuevas post-3.3.5a NO existen (APIs tipo `CreateFrame` modernas tipo `ScrollBox`, `TextureKit`, `SetFramePools` NO). **No usar `C_Timer`** (ni `After` ni `NewTicker`): en este proyecto se prefiere la ejecución sincrónica y los eventos clásicos de WoW. Ante la duda, usar la forma clásica.
- **SavedVariables**: se guardan automáticamente al salir/logout. No llamar a `ReloadUI` sin necesidad.
- **Color codes en chat**: usar `|cFFRRGGBB` con `|r`.
- **Fonts**: `GameFontNormal`, `GameFontNormalSmall`, `GameFontHighlight`, `GameFontNormalLarge`, `GameFontDisable` están disponibles.
- **Templates**: `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate`, `UIDropDownMenuTemplate`, `UIPanelScrollFrameTemplate`, `CharacterFrameTabButtonTemplate`, `InputBoxTemplate` son seguros.
- **In combat**: no se pueden crear frames con templates que requieran `UIParent` seguro, ni cambios de atributos como `SetFrameStrata` arbitrarios. Preferir crear UI en `PLAYER_LOGIN`.
- **Límite de memoria/integridad**: WoW 3.3.5a puede patear a Lua por abuso de CPU (loops infinitos, `OnUpdate` pesados). Evitar `OnUpdate` continuos; usar eventos.
- **Colisión de nombres globales**: prefijar TODO con `RD_`. Nunca crear globales sin prefijo.

## 4. Arquitectura

Namespace único: tabla global `RaidDominion` (alias corto `RD`). No hay variable local compartida entre archivos; cada archivo es un archivo Lua autocontenido que se registra en `RD`.

```
RaidDominion/
├── RaidDominion.toc              # Orden de carga (crítico)
├── AGENTS.md
├── RD_Constants.lua              # Constantes, definiciones de menú, esquemas de config
├── RD_Events.lua                 # Bus pub/sub minimalista
├── RD_Config.lua                 # Persistencia (SavedVariables) + Get/Set por path "a.b.c"
├── RD_Init.lua                   # Entry point, slash commands, inicialización en orden
├── RD_UI_Utils.lua               # Utilidades de frame/string/alineación (Pool, anchors, fonts)
├── RD_UI_Layout.lua              # Motor de layout/alineación (ver sección 6)
├── RD_UI_MenuFrame.lua           # Menú flotante principal (reemplaza MainFrame v2)
├── RD_UI_MenuFactory.lua         # Fábrica de menús/submenús por definición de datos
├── RD_UI_ConfigWindow.lua        # Ventana de configuración vinculada, render por esquema
├── RD_UI_Widgets.lua             # Widgets reutilizables (Checkbox, Slider, Dropdown, Text)
├── RD_MenuActions.lua            # Acciones invocadas por los ítems de menú
├── RD_Module_*.lua               # Módulos funcionales (RoleManager, MessageManager, etc.)
└── RD_Utils_*.lua                # Utilidades de dominio (Group, CoreBands, Gearscore, ...)
```

### 4.1 Patrón de módulo

Cada archivo de módulo sigue este patrón:

```lua
-- RD_UI_Widgets.lua
local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Widgets = {}

function Widgets:CreateCheckbox(...) end

RD.ui = RD.ui or {}
RD.ui.widgets = Widgets
return Widgets
```

Reglas:
- `local addonName, private = ...` en la primera línea (asignado por el .toc).
- Nunca declarar `local` de alto nivel compartido; todo se accede vía `RD.*`.
- Devuelve la tabla del módulo (`return Module`).
- Comentarios en español, encabezado en el formato del archivo (bloque `--[[ ]]` con PROPÓSITO/API/EVENTOS).

### 4.2 Namespaces

- `RD.constants`, `RD.config`, `RD.events`
- `RD.ui` (objetos de UI), `RD.modules`, `RD.utils`, `RD.data`
- `RD.MenuData` (definiciones de menú resueltas)

## 5. Convenciones de código

- **Indentación**: 4 espacios. Sin tabs.
- **Comillas**: dobles para strings con interpolación probable, simples para constantes; consistencia > gusto.
- **Nombres de funciones**: camelCase (`GetFrame`, `ShowMainMenu`).
- **Constantes**: UPPER_SNAKE.
- **Tablas de datos**: llaves/valores en minúscula para claves de config (`showRoles`, `channel`).
- **Guardado de booleans en SavedVariables**: la v2 guardaba `true` como `1`/`0`. **En v3 se guardan booleanos nativos** (`true`/`false`) para simplicidad; el sistema de config normaliza al leer.
- **No usar `print`**: usar `RD.messageManager:SendSystemMessage(...)` cuando exista; fallback a `print` solo si el módulo no está cargado.
- **Una responsabilidad por archivo**: los archivos no deben superar ~700 líneas. Si crece, dividir (p.ej. `RD_UI_ConfigWindow_General.lua`).

## 6. Sistema de alineación (CRÍTICO)

WoW 3.3.5a renderiza con escalas de UI que hacen que medias-píxeles se vean borrosas. Para un alineamiento preciso:

### 6.1 Principios

1. **Anclaje relativo**: SIEMPRE usar `SetPoint` con parent/relativePoint explícitos. Nunca posicionar por coordenadas absolutas sueltas.
2. **Cantidades enteras y múltiplos de la cuadrícula**: usar un grid base `GUTTER = 4` (o `8`) para espaciados. Todos los offsets de `SetPoint` en enteros.
3. **Consistencia de escala**: multiplicar los offsets por `UIParent:GetScale()` NO es necesario si anclamos a `UIParent`; pero al mezclar parents con escalas distintas usar `UIParent:GetScale()` para normalizar cuando se lea el cursor (`GetCursorPosition()` devuelve en pantalla; dividir por la escala del frame).
4. **Autodimensionamiento**: nunca hardcodear el alto de un contenedor de texto; medir con `fontString:GetStringHeight()`/`GetStringWidth()` y ajustar el contenedor.
5. **Centralización por construcción**: usar `SetPoint("CENTER")` del hijo al centro del padre, y `SetAllPoints()` cuando el hijo ocupe todo el padre.

### 6.2 API del motor de layout (`RD_UI_Layout.lua`)

Debe exponer ayudantes que centralicen la geometría:

```lua
RD.ui.layout:Column(parent, x, yTop, width, spacing)  -- crea/posiciona una columna y devuelve el próximo y
RD.ui.layout:Row(parent, xLeft, y, height, gap)       -- posiciona una fila horizontal
RD.ui.layout:StackChildren(parent, anchor, ...)       -- apila hijos contra un ancla
RD.ui.layout:SyncHeight(container, fontString)        -- ajusta alto del contenedor al texto
RD.ui.layout:EnsureVisible(frame, margin)             -- clamp contra pantalla (reemplazo de SetClampedToScreen para casos especiales)
```

### 6.3 Checks de alineación obligatorios (QA)

Todo elemento UI nuevo debe:
- Usar `SetPoint` (no offsets absolutos crudos) y sizes explícitos en enteros.
- No usar `SetScale` en hijos (distorsiona alineación); si se necesita escala, aplicarla al frame raíz.
- Verificar que el frame padre tenga tamaño definido antes de posicionar hijos.
- Evitar `OnSizeChanged` recursivos; si un `OnSizeChanged` modifica tamaños, proteger con un flag `updatingLayout`.

## 7. Menú flotante y escalabilidad

### 7.1 Definición por datos

Los menús se definen como datos en `RD_Constants.MENU_DEFINITIONS` (o `RD.data.menus`). Forma de cada ítem:

```lua
{
    id = "skills",                 -- clave única (opcional, derivada del nombre si falta)
    name = "Habilidades",          -- texto visible
    action = "ShowSkills",         -- acción registrada en RD.MenuActions
    tooltip = "Gestionar habilidades del grupo",
    icon = "Interface/Icons/...",  -- opcional
    submenu = "guildOptions",      -- si abre un submenú (por nombre de definición)
    enabled = function() ... end,  -- opcional: controla visibilidad dinámica
    order = 1                      -- opcional: controla el orden de render
}
```

### 7.2 Render escalable

- `RD_UI_MenuFactory:BuildMenu(definitions, opts)` recibe definiciones y devuelve el frame renderizado.
- El motor de layout calcula filas/columnas con límites (`MAX_ITEMS_PER_COLUMN`, `MAX_COLUMNS`) y ajusta el tamaño del frame automáticamente.
- Los ítems deshabilitados por `enabled` se omiten del cálculo de layout (no dejar huecos).

### 7.3 Ventana flotante (`RD_UI_MenuFrame`)

- Frame raíz `RaidDominionMenuFrame`, strata `MEDIUM`, `SetToplevel(true)`, `SetClampedToScreen(true)`, arrastrable, posición guardada en config (`ui.menu.position`).
- Botón de minimapa opcional para abrir/cerrar.
- Atajo `/rd` para mostrar/ocultar.

## 8. Ventana de configuración vinculada y render por esquema

### 8.1 Concepto

La ventana de configuración NO tiene UI hardcodeada por pestaña. Se define un **esquema** (`CONFIG_SCHEMA`) en `RD_Constants`, y la ventana **renderiza widgets según el esquema y según el valor seteado actual** en `RD.config`.

### 8.2 Esquema

```lua
CONFIG_SCHEMA = {
    { id = "general", title = "General", order = 1, sections = {
        { id = "menu", title = "Menú", fields = {
            { key = "ui.menu.scale",       type = "slider",  label = "Escala", min = 0.7, max = 1.5, step = 0.05 },
            { key = "ui.menu.lockPosition", type = "checkbox", label = "Bloquear posición" },
            { key = "chat.channel",         type = "dropdown", label = "Canal", options = { ["DEFAULT"]="Predeterminado", ["RAID"]="Banda", ["GUILD"]="Hermandad" } },
        }},
    }},
}
```

### 8.3 Render

- `RD_UI_ConfigWindow:Render()` limpia el contenedor activo y construye los widgets desde el esquema.
- Widgets: checkbox, slider (con edición numérica), dropdown, textbox, color, button. Definidos en `RD_UI_Widgets`.
- Cada widget lee el valor actual con `RD.config:Get(key, default)` y escribe con `RD.config:Set(key, value)`, que dispara `CONFIG_CHANGED` en el bus de eventos.
- Los cambios que afectan al menú flotante (p.ej. escala, mostrar/ocultar secciones) re-renderizan el menú automáticamente al recibir `CONFIG_CHANGED`.
- Los ítems de menú cuyos `enabled` dependan de config se recalculan al recibir `CONFIG_CHANGED`.

### 8.4 Vínculo con el menú flotante

- Ítem del menú flotante "Opciones" → `RD_UI_ConfigWindow:Toggle()`.
- La config se abre centrada (o junto al menú si hay espacio, anclada al frame flotante) según la preferencia `ui.config.position` (`"screen"` | `"menu"`).

## 9. Bus de eventos (`RD_Events`)

- API: `RD.events:Subscribe(event, fn)`, `RD.events:Unsubscribe(event, fn)`, `RD.events:Publish(event, ...)`.
- Eventos reservados: `CONFIG_LOADED`, `CONFIG_CHANGED(key, value)`, `CONFIG_RESET`, `ADDON_INITIALIZED`, `UI_SHOW`, `UI_HIDE`, `CONFIG_WINDOW_SHOWN`, `CONFIG_WINDOW_HIDDEN`.
- No suscribirse a `CONFIG_CHANGED` para re-render pesado; delegar a funciones de actualización acotadas.

## 10. Persistencia (`RD_Config`)

- SavedVariables: `RaidDominionDB` (perfil global) + `RaidDominionDBPC` (por personaje, opcional).
- `RD.config:Get(key, default)` acepta paths `"ui.menu.scale"`.
- `RD.config:Set(key, value)` escribe, guarda y publica `CONFIG_CHANGED`.
- Valores por defecto centralizados en `RD_Constants.DEFAULT_CONFIG`; al cargar se hace merge profundo con la DB (respetando valores ya guardados).

## 11. Flujo de carga (orden en .toc)

```
# Core
RD_Events.lua
RD_Constants.lua
RD_Config.lua
RD_Init.lua
# UI Framework
RD_UI_Utils.lua
RD_UI_Layout.lua
RD_UI_Widgets.lua
RD_UI_MenuFactory.lua
RD_UI_MenuFrame.lua
RD_UI_ConfigWindow.lua
# Módulos y utilidades
RD_Module_*.lua
RD_Utils_*.lua
# Acciones (después de todo lo anterior)
RD_MenuActions.lua
```

`RD_Init` inicia todo en `ADDON_LOADED` (solo el addon propio) + `PLAYER_LOGIN` (construcción de UI).

## 12. Verificación antes de dar por terminado un cambio

0. **Gate del repo**: `python3 harness/verify.py` (estático + luac si está instalado) y `python3 harness/run_tests.py` (tests lógicos con mocks). Ambos deben terminar en `RESULTADO: OK`. Ver `harness/README.md`. El hook pre-commit (`git config core.hooksPath harness/git-hooks`) ejecuta ambos en cada commit.

1. **Sintaxis Lua**: verify.py ya corre `luac -p` cuando el binario está disponible (`harness/install_luac.sh` lo instala localmente); si no, nota de revisión manual.
2. **Compatibilidad 3.3.5a**: la lista de APIs prohibidas vive SOLO en `harness/rules.json` (fuente única; verify.py la aplica). Lo no automatizable (global `ClearAllRaidIcons`, pipes sueltos en chat) está en rules.json -> "manual_only" y lo revisa qa-335a.
3. **Alineación**: aplicar las reglas de la sección 6. Verificar parents y sizes enteros.
4. **Contrato SV con el portal**: si el cambio toca `RD_Utils_Registry.lua`,
   `RD_Utils_Characters.lua` o claves persistidas de `RD.config` consumidas
   por el portal web, verificar compatibilidad según la sección 14
   (custodiado también por qa-335a vía rules.json -> "manual_only").
5. **Comando de test**: `/rd`, `/rdc` deben funcionar sin errores en chat.
6. **Sin librerías externas**: cubierto por verify.py (reglas en rules.json); cualquier duda se grepea igual.

## 13. Equipo de agentes especializados

Los agentes se definen en `.opencode/agent/`:

| Agente | Rol |
| --- | --- |
| `ui-architect` | Diseña arquitectura de UI, escalabilidad del menú flotante y esquemas de config |
| `frame-builder` | Implementa frames/widgets con alineación píxel-perfecta para 3.3.5a |
| `config-system` | Implementa persistencia y render de la ventana de config por esquema |
| `lua-core` | Módulos lógicos (eventos, mensajes, roles, utilidades de dominio) |
| `refactorer` | Refactorización segura que preserva comportamiento (divide >700 líneas, extrae helpers, elimina código muerto) |
| `qa-335a` | Revisión: compatibilidad de API 3.3.5a, alineación, ausencia de librerías externas; ejecuta `harness/verify.py` |

Cada agente debe ser invocado para su especialidad; consultar el archivo correspondiente en `.opencode/agent/` para instrucciones detalladas. Flujo recomendado: `ui-architect` diseña → `frame-builder`/`lua-core`/`config-system` generan → `refactorer` mantiene → `qa-335a` aprueba antes de commit.

### 13.1 Gate de verificación reutilizable (skill)

La skill `.opencode/skills/verify-335a/SKILL.md` centraliza el gate completo de QA (harness, `luac -p`, lista de APIs prohibidas, checks de alineación, pipes/códigos de color en chat, convenciones, paridad con la v2). Cárgala (vía la herramienta `skill`) siempre que se pida "verifica",
"verificar", "QA", "ronda", o antes de dar por terminado un cambio.

### 13.2 Comandos de opencode

- **`/verifica [N] "objetivo"`** — ejecuta N rondas de implementación
  personalizada recorriendo los agentes del proyecto por especialidad
  (diseño → generación → refactor → QA), validando con el gate
  (`harness/verify.py` + `run_tests.py`) en cada paso. La revisión puntual
  del gate en solo lectura la cubren la skill `verify-335a` y el agente
  `qa-335a`.

## 14. Producto compañero: Portal web RaidDominion (contrato SV)

El portal comunitario (`D:\_DEV\raid-dominion-guild`, Astro + Supabase, con
sus propios agentes) consume las SavedVariables que este addon genera.
Trátalo como una API pública:

1. **Productor del contrato:** el árbol `registry["Nombre-Reino"]` lo escribe
   `RD_Utils_Registry.lua` (ítem de menú "Registrar") y el roster de cuenta
   lo escribe `RD_Utils_Characters.lua`. El portal lo parsea en
   `src/lib/parser/savedVariables.ts` (+ `src/types/parser.ts`).
2. **Sincronía obligatoria:** renombrar/mover claves o cambiar tipos de
   `registry`, `characters`, `bands` o `Guild` exige coordinar el cambio con
   el portal EN EL MISMO ciclo (y viceversa). El formato espejo vive en el
   AGENTS.md del portal (§5 y §11).
3. **Privacidad:** `registry.guild.memberList` (roster GM) NO incluye notas
   pública/oficial por diseño; mantenerlo así — el portal jamás expone notas
   de oficio.
4. **Versionado:** al cambiar el esquema del contrato, incrementar `version`
   en las entradas de `characters` para que el portal pueda detectar archivos
   antiguos.
5. El gate §12 (4bis) y la entrada "Contrato SV con el portal" de
   `harness/rules.json` ("manual_only") custodian este contrato en cada QA.

Slash commands vigentes: `/rd`, `/rdc`, `/rdh`, `/rdloot` (`RD_Init.lua`).

