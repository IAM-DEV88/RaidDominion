---
name: verify-335a
description: Gate de verificación QA de RaidDominion para WoW 3.3.5a. Úsala cuando se pida "verificar", "evaluar", "QA", "ronda", "¿está terminado?", "luac", "harness" o antes de dar por terminado un cambio. Contiene la lista de APIs prohibidas, checks de alineación, pipes en chat y el flujo exacto (harness + luac + greps).
---

# Gate de verificación QA — WoW 3.3.5a

Sigue este gate ANTES de dar por terminado cualquier cambio del addon. Cliente: Interface 30300, Lua 5.1, sin librerías externas. Restricciones completas en `AGENTS.md`.

## 1. Harness (obligatorio)

Desde la raíz del repo:

```
python3 harness/verify.py
```

Debe terminar con `RESULTADO: OK`. Un aviso o fallo bloquea la terminación. El harness valida sobre código sin comentarios/strings: balance de bloques Lua 5.1, APIs post-3.3.5a y librerías externas.

## 2. Sintaxis

- Si `luac` está disponible: `luac -p <archivo>.lua` en cada archivo tocado (compila sin ejecutar).
- Si no está disponible (entornos sin binario), nota en el informe: "sintaxis revisada manualmente + balance del harness".

## 3. APIs post-3.3.5a (CERO usos reales; los comentarios explicando por qué no se usan son válidos)

Rechazar en código real (no comentarios):
- `C_Timer.After` / `C_Timer.NewTicker` — usar frame `OnUpdate` persistente con auto-hide.
- `UnitAura` — llegó en Cataclysm; en 3.3.5a usar `UnitBuff(unit, index)` y `UnitDebuff(unit, index)`.
- `RegisterAddonMessagePrefix` — usar `CHAT_MSG_ADDON` + filtro por prefijo.
- `ToggleDropdown` — usar `ToggleDropDownMenu`.
- `ClearAllRaidIcons` (global) — limpiar con `SetRaidTarget("raid"..i, 0)` vía helper local.
- `ScrollBox`, `TextureKit`, `SetFramePools`, `FramePool`, APIs de SharedXML moderno.
- Lua 5.1: `goto`, operador `//`, `table.unpack`/`table.move` (usar `unpack`), librería `utf8`.

## 4. Alineación (sección 6 de AGENTS.md)

- `SetPoint` con parent/relativePoint explícitos; offsets ENTEROS (grid 4px vía `Layout.Snap`).
- `SetSize` en enteros y ANTES de posicionar hijos.
- `SetScale` SOLO en el frame raíz (nunca en hijos).
- Sin `OnSizeChanged` que modifique tamaños sin flag `updatingLayout`.
- Autodimensionado de texto con `GetStringHeight`/`GetStringWidth` (o `EstimateWrappedLines`).
- Ventanas flotantes con `SetToplevel(true)` y `SetClampedToScreen(true)`.

## 5. Strings de chat (pipes y colores)

- NINGÚN mensaje enviado a chat (SendChatMessage/SendMessage/SendSequence/SendSystemMessage/SendAddonMessage) puede tener un `|` suelto seguido de carácter que no sea `c`/`H`/`T`/`r` — es escape inválido en 3.3.5a. Para un pipe literal usar `||` (se renderiza como `|`).
- Todo `|cffRRGGBB` debe cerrarse con `|r` en el mismo mensaje.

## 6. Librerías externas

CERO referencias a `Ace3`/`AceAddon`, `LibStub`, `LibSharedMedia`, `LibDataBroker`, `embeds.xml`, carpetas `Libs/`.

## 7. Convenciones

- Namespace `RaidDominion`/`RD`; sin globales sin prefijo `RD_`/`RaidDominion` (salvo `SLASH_RD*`).
- Patrón de módulo: `local addonName, private = ...` + `_G.RaidDominion = RD` + `return Module`.
- Encabezados `--[[ PROPÓSITO/API/EVENTOS ]]` en español; comentarios en español.
- Archivos ≤ ~700 líneas.
- Sin `print` (usar `RD.messageManager:SendSystemMessage`; fallback a `print` solo si no está cargado).

## 8. Paridad con el addon base

El comportamiento debe replicar `RaidDominion-main` (la v2, en `../RaidDominion-main`). Ante una duda de comportamiento, lee el archivo equivalente de la v2 como fuente de verdad (p.ej. `RD_UI_Utils.lua` de la v2 para el mecanismo de auras).

## 9. Definición de terminado

Un cambio SOLO está terminado cuando:
1. `harness/verify.py` → OK.
2. `luac -p` (si disponible) pasa en los archivos tocados.
3. Cero APIs post-3.3.5a reales, cero pipes sueltos, cero librerías externas.
4. El `.toc` refleja archivos nuevos/eliminados.
5. Reporta: archivos tocados, hallazgos resueltos y veredicto.
