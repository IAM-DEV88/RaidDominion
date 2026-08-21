#!/usr/bin/env python3
r"""verify.py — Control de calidad estático de RaidDominion (WoW 3.3.5a, Lua 5.1).

Ejecutar desde la raíz del addon:
    python3 harness/verify.py

Comprueba, para todos los archivos RD_*.lua (sobre el código SIN comentarios ni
strings, para no generar falsos positivos):
  1. Balance de bloques Lua 5.1 (if/for/while/repeat/function/do/then/end/until).
  2. Ausencia de APIs posteriores a 3.3.5a (C_Timer, ScrollBox, TextureKit,
     SetFramePools, table.unpack, table.move, operador //, goto, utf8).
  3. Ausencia de librerías externas (Ace3/AceAddon, LibStub, LibSharedMedia,
     LibDataBroker).
  4. Aviso de archivos > ~700 líneas (límite del proyecto).

Nota: la colisión de globals sin prefijo RD_ se revisa manualmente por el agente
qa-335a (heurística automática demasiado ruidosa como puerta).

Salida: 0 si pasa (solo avisos), 1 si hay fallos.
"""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA_FILES = sorted(glob.glob(os.path.join(ROOT, "RD_*.lua")))

# APIs que no existen en 3.3.5a (se escanean sobre código sin comentarios/strings)
FORBIDDEN = [
    (r"\bC_Timer\b", "C_Timer"),
    (r"\bScrollBox\b", "ScrollBox"),
    (r"\bTextureKit\b", "TextureKit"),
    (r"\bSetFramePools\b", "SetFramePools"),
    (r"\bFramePool\b", "FramePool"),
    (r"\btable\.unpack\b", "table.unpack (usar unpack en Lua 5.1)"),
    (r"\btable\.move\b", "table.move (no existe en Lua 5.1)"),
    (r"\butf8\b", "utf8 (no existe en Lua 5.1)"),
    (r"::\w+::", "goto labels"),
    (r"\d+\s*//\s*\d+", "operador // (floor division)"),
    (r"\bUnitAura\b", "UnitAura (llegó en Cataclysm; en 3.3.5a usar UnitBuff/UnitDebuff)"),
]

# Librerías externas prohibidas. \bAce[A-Z] evita falsos positivos con palabras
# en español (Aceptar/Acerca); "Ace3" y "AceAddon" son las marcas reales.
EXTERNAL_LIBS = [
    (r"\bAce3\b", "Ace3"),
    (r"\bAce[A-Z]\w*", "AceAddon/otra librería Ace"),
    (r"\bLibStub\b", "LibStub"),
    (r"\bLibSharedMedia\b", "LibSharedMedia"),
    (r"\bLibDataBroker\b", "LibDataBroker"),
]


def strip_lua(src):
    """Devuelve el código sin comentarios (bloque/línea) ni strings."""
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == "-" and i + 1 < n and src[i + 1] == "-":
            j = src.find("\n", i)
            i = n if j == -1 else j + 1
            continue
        if c in ('"', "'"):
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c:
                    break
                j += 1
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def check_balance(src):
    toks = re.findall(r"\b(?:function|if|for|while|repeat|do|then|end|until)\b", src)
    stack = []
    expect = False
    for t in toks:
        if t in ("for", "while"):
            stack.append(t)
            expect = True
        elif t == "do":
            if expect:
                expect = False
            else:
                stack.append("do")
        elif t in ("function", "if", "repeat"):
            stack.append(t)
            expect = False
        elif t == "then":
            expect = False
        elif t in ("end", "until"):
            if not stack:
                return False, "end/until sin abrir"
            stack.pop()
            expect = False
    if expect:
        return False, "bloque abierto con 'do' pendiente"
    if stack:
        return False, "bloques sin cerrar: " + ", ".join(stack)
    return True, None


def find_matches(code, patterns):
    """Devuelve lista de (label, line_number) de los patrones en el código."""
    found = []
    for pat, label in patterns:
        for m in re.finditer(pat, code):
            line_no = code[: m.start()].count("\n") + 1
            found.append((label, line_no))
    return found


def main():
    failures = []
    warnings = []

    for path in LUA_FILES:
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as f:
            src = f.read()
        code = strip_lua(src)

        # 1. Balance Lua 5.1
        ok, err = check_balance(code)
        if not ok:
            failures.append(f"{rel}: balance de bloques -> {err}")

        # 2 + 3. APIs prohibidas y librerías externas (sobre código limpio)
        for label, line_no in find_matches(code, FORBIDDEN):
            failures.append(f"{rel}:{line_no} API no 3.3.5a -> {label}")
        for label, line_no in find_matches(code, EXTERNAL_LIBS):
            failures.append(f"{rel}:{line_no} librería externa -> {label}")

        # 4. Líneas > 700 (aviso): se mide sobre el archivo físico (los bloques
        # de comentarios largos también pesan en la mantenibilidad del archivo).
        lines = src.count("\n") + 1
        if lines > 700:
            warnings.append(f"{rel}: {lines} líneas (límite ~700)")

    print(f"Archivos analizados: {len(LUA_FILES)}")
    for w in warnings:
        print(f"[AVISO] {w}")
    for fl in failures:
        print(f"[FALLO] {fl}")

    if failures:
        print(f"\nRESULTADO: FALLO ({len(failures)})")
        return 1
    print(f"\nRESULTADO: OK ({len(warnings)} avisos no bloqueantes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
