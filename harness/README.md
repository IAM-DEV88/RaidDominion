# Harness de verificación de RaidDominion

Puerta de control de calidad del addon (AGENTS.md §12). El agente **qa-335a** lo
usa antes de dar un cambio por terminado; el **refactorer** lo ejecuta antes y
después de cada refactor.

## Herramientas

| Archivo | Propósito | Cómo ejecutar |
|---|---|---|
| `verify.py` | QA estático: balance Lua 5.1, APIs prohibidas (3.3.5a), librerías externas, líneas >700, globals sin prefijo `RD_` | `python3 harness/verify.py` |

## Metodología

1. **Verificación-antes-de-terminar** (AGENTS.md §12): ningún cambio se da por
   terminado sin pasar `verify.py` y, en lo posible, `luac -p <archivo>` /
   `luacheck` cuando existan en el entorno.
2. **Refactor seguro**: el refactorizador preserva comportamiento y verifica con
   el harness antes y después de cada cambio.
3. **Separación de deberes**: los generadores escriben (edit:allow); el QA solo
   revisa e informa (edit:deny) y ejecuta el harness (bash:allow).
4. Los harnesses se versionan en el repo (no en /tmp) para que sean reproducibles
   por cualquier sesión/agente.

## Notas de entorno

- En entornos sin intérprete Lua, `verify.py` cubre el balance de bloques con un
  parser estático de tokens; los agentes qa-335a/refactorer complementan con
  revisión estática manual de sintaxis.
- Los harnesses funcionales ad-hoc (simulaciones de protocolo, round-trip de
  datos) se documentan en `sesion.txt` y se regeneran cuando se necesiten.
