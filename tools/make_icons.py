#!/usr/bin/env python3
"""Genera los íconos SVG originales del juego (assets/icons). Licencia: propios, CC0."""
import os
D = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
os.makedirs(D, exist_ok=True)
H = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
I = {
 "carbon": '<path d="M10 44 L18 26 L30 20 L44 24 L54 38 L48 50 L28 54 Z" fill="#2a2a2e" stroke="#8a8f99" stroke-width="3"/><path d="M22 34 L30 28 L38 32" stroke="#5a5f69" stroke-width="3" fill="none"/>',
 "madera": '<rect x="8" y="22" width="44" height="20" rx="10" fill="#8a5a34" stroke="#e0b07a" stroke-width="3"/><ellipse cx="50" cy="32" rx="7" ry="10" fill="#d9a066" stroke="#e0b07a" stroke-width="3"/><circle cx="50" cy="32" r="3" fill="#8a5a34"/>',
 "metal": '<path d="M8 42 L18 24 L50 24 L58 42 Z" fill="#7f8896" stroke="#d6dde8" stroke-width="3"/><path d="M18 24 L22 32 L46 32 L50 24" fill="none" stroke="#d6dde8" stroke-width="2"/>',
 "nucleos": '<circle cx="32" cy="32" r="20" fill="#2c4058" stroke="#9fd0ff" stroke-width="3"/><circle cx="32" cy="32" r="8" fill="#ffb347"/><path d="M32 8 V16 M32 48 V56 M8 32 H16 M48 32 H56" stroke="#9fd0ff" stroke-width="4"/>',
 "crudo": '<path d="M14 40 C10 24 26 12 40 16 C54 20 56 36 46 44 C38 50 20 52 14 40 Z" fill="#b5463c" stroke="#ffb0a0" stroke-width="3"/><circle cx="46" cy="44" r="5" fill="#f0e6d8"/>',
 "raciones": '<path d="M8 30 H56 C54 46 44 54 32 54 C20 54 10 46 8 30 Z" fill="#c9a26b" stroke="#ffe2a8" stroke-width="3"/><path d="M22 24 C20 18 26 16 24 10 M32 24 C30 18 36 16 34 10 M42 24 C40 18 46 16 44 10" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.8"/>',
 "poblacion": '<circle cx="24" cy="20" r="8" fill="#d8dee8"/><path d="M10 50 C10 34 38 34 38 50 Z" fill="#d8dee8"/><circle cx="44" cy="24" r="6" fill="#9aa4b4"/><path d="M34 50 C34 38 56 38 56 50 Z" fill="#9aa4b4"/>',
 "enfermos": '<rect x="24" y="10" width="16" height="44" rx="3" fill="#e05050"/><rect x="10" y="24" width="44" height="16" rx="3" fill="#e05050"/>',
 "esperanza": '<path d="M32 6 C40 20 50 26 50 40 A18 18 0 0 1 14 40 C14 30 20 24 24 18 C26 26 30 28 32 28 C28 20 30 12 32 6 Z" fill="#ff9a3c" stroke="#ffe08a" stroke-width="2"/>',
 "descontento": '<path d="M16 50 V28 C16 22 24 22 24 28 V20 C24 14 32 14 32 20 V18 C32 12 40 12 40 18 V22 C40 16 48 16 48 22 V40 C48 48 42 54 34 54 H24 C20 54 16 52 16 50 Z" fill="#c75b4a" stroke="#ffb3a0" stroke-width="3"/>',
 "temperatura": '<rect x="26" y="8" width="12" height="34" rx="6" fill="#dfe9f5" stroke="#9fd0ff" stroke-width="3"/><circle cx="32" cy="46" r="10" fill="#6fb7ff" stroke="#9fd0ff" stroke-width="3"/><rect x="30" y="22" width="4" height="22" fill="#6fb7ff"/>',
 "reloj": '<circle cx="32" cy="32" r="22" fill="none" stroke="#dfe9f5" stroke-width="4"/><path d="M32 18 V32 L42 38" stroke="#ffb347" stroke-width="4" fill="none"/>',
 "construir": '<path d="M12 50 L36 26" stroke="#c8a070" stroke-width="7" stroke-linecap="round"/><path d="M30 14 L48 10 L54 22 L40 32 Z" fill="#9aa4b4" stroke="#e6ecf4" stroke-width="3"/>',
 "generador": '<rect x="20" y="22" width="24" height="34" rx="4" fill="#8a5a3c" stroke="#ffb347" stroke-width="3"/><rect x="27" y="6" width="10" height="18" fill="#5c6470"/><circle cx="32" cy="40" r="7" fill="#ffb347"/>',
 "leyes": '<path d="M10 14 C20 10 28 12 32 16 C36 12 44 10 54 14 V52 C44 48 36 50 32 54 C28 50 20 48 10 52 Z" fill="#6a4a8a" stroke="#d8c0ff" stroke-width="3"/><path d="M32 16 V54" stroke="#d8c0ff" stroke-width="2"/>',
 "investigacion": '<circle cx="32" cy="32" r="12" fill="none" stroke="#9fd0ff" stroke-width="5"/><path d="M32 8 V16 M32 48 V56 M8 32 H16 M48 32 H56 M15 15 L21 21 M43 43 L49 49 M49 15 L43 21 M21 43 L15 49" stroke="#9fd0ff" stroke-width="5"/>',
 "exploracion": '<circle cx="32" cy="32" r="22" fill="#24384c" stroke="#dfe9f5" stroke-width="3"/><path d="M32 14 L38 32 L32 50 L26 32 Z" fill="#ff7a5a"/><path d="M32 32 L38 32 L32 50 Z" fill="#dfe9f5"/>',
 "reporte": '<rect x="14" y="8" width="36" height="48" rx="4" fill="#e9e1cc" stroke="#ffffff" stroke-width="2"/><path d="M20 20 H44 M20 28 H44 M20 36 H38 M20 44 H40" stroke="#6a5a40" stroke-width="3"/>',
 "capas": '<path d="M32 10 L56 22 L32 34 L8 22 Z" fill="#6fb7ff"/><path d="M8 32 L32 44 L56 32" stroke="#ffb347" stroke-width="4" fill="none"/><path d="M8 42 L32 54 L56 42" stroke="#e05050" stroke-width="4" fill="none"/>',
 "menu": '<path d="M12 18 H52 M12 32 H52 M12 46 H52" stroke="#dfe9f5" stroke-width="6" stroke-linecap="round"/>',
 "pausa": '<rect x="16" y="12" width="10" height="40" rx="2" fill="#dfe9f5"/><rect x="38" y="12" width="10" height="40" rx="2" fill="#dfe9f5"/>',
 "x1": '<path d="M20 12 L48 32 L20 52 Z" fill="#dfe9f5"/>',
 "x2": '<path d="M8 12 L32 32 L8 52 Z M32 12 L56 32 L32 52 Z" fill="#dfe9f5"/>',
 "x3": '<path d="M4 14 L22 32 L4 50 Z M22 14 L40 32 L22 50 Z M40 14 L58 32 L40 50 Z" fill="#dfe9f5"/>',
 "cerrar": '<path d="M16 16 L48 48 M48 16 L16 48" stroke="#dfe9f5" stroke-width="7" stroke-linecap="round"/>',
 "ok": '<path d="M12 34 L26 48 L52 18" stroke="#8be08b" stroke-width="7" fill="none" stroke-linecap="round"/>',
 "demoler": '<path d="M14 54 L26 30 L38 34 L50 14" stroke="#e05050" stroke-width="6" fill="none"/><rect x="10" y="50" width="44" height="6" fill="#8a8f99"/>',
 "mejorar": '<path d="M32 8 L54 32 H40 V56 H24 V32 H10 Z" fill="#8be08b" stroke="#e6ffe6" stroke-width="2"/>',
 "automata": '<rect x="18" y="20" width="28" height="28" rx="4" fill="#b08a40" stroke="#ffd98a" stroke-width="3"/><rect x="24" y="8" width="16" height="12" rx="2" fill="#5c6470"/><rect x="24" y="28" width="16" height="6" fill="#ffb347"/>',
 "alerta": '<path d="M32 8 L58 54 H6 Z" fill="#ffb347" stroke="#fff0c0" stroke-width="3"/><rect x="29" y="22" width="6" height="18" fill="#2a2a2e"/><circle cx="32" cy="46" r="3.5" fill="#2a2a2e"/>',
 "muerte": '<path d="M20 54 V24 A12 12 0 0 1 44 24 V54 Z" fill="#9aa4b4" stroke="#dfe9f5" stroke-width="3"/><path d="M32 26 V44 M26 32 H38" stroke="#2a2a2e" stroke-width="4"/>',
 "estrella": '<path d="M32 6 L39 24 L58 24 L43 36 L49 56 L32 44 L15 56 L21 36 L6 24 L25 24 Z" fill="#ffd34d" stroke="#fff3b0" stroke-width="2"/>',
 "estrella_vacia": '<path d="M32 6 L39 24 L58 24 L43 36 L49 56 L32 44 L15 56 L21 36 L6 24 L25 24 Z" fill="none" stroke="#7a8494" stroke-width="3"/>',
 "pedido": '<path d="M10 14 H54 V42 H30 L18 54 V42 H10 Z" fill="#3a5a7a" stroke="#cfe6ff" stroke-width="3"/><path d="M20 24 H44 M20 32 H36" stroke="#cfe6ff" stroke-width="3"/>',
}
for name, body in I.items():
    with open(os.path.join(D, name + ".svg"), "w") as f:
        f.write(H + body + "</svg>")
print(len(I), "íconos")
