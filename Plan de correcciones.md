# Plan de correcciones, mejoras y optimizaciones
## opencode-template · Auditoría completa Mayo 2026

> **Cómo usar este documento**
> Ejecuta las fases en orden. No saltes a Fase 2 sin resolver Fase 0 —
> hay dependencias reales entre ellas. Cada issue tiene: problema exacto,
> archivos involucrados, cambio concreto con texto/SQL/código real.

---

## Índice de issues por severidad

| ID | Descripción corta | Severidad | Fase |
|---|---|---|---|
| B1 | `.env` con credenciales commiteado | 🔴 Blocker | 0 |
| B2 | `.secrets.baseline` no existe, pre-commit falla en día 1 | 🔴 Blocker | 0 |
| B3 | `riesgos.estado` CHECK no tiene `monitoreado`; queries retornan vacío | 🔴 Blocker | 1 |
| B4 | `DROP TABLE eventos` en init.sql destruye historial al re-ejecutar | 🔴 Blocker | 1 |
| B5 | `.venv/` de `leer-documento` commiteado, binarios de otra plataforma | 🔴 Blocker | 1 |
| I1 | Límites de memoria contradictorios: `higiene-memoria.md` vs `AGENTS.md` | 🟡 Importante | 2 |
| I2 | `decisiones.estado` casing: schema `'aceptada'`, queries `'Aceptada'` | 🟡 Importante | 2 |
| I3 | `setup.sh` hace `git init`; `init-proyecto` dice "No inicialices git" | 🟡 Importante | 2 |
| I4 | `sprint-planning` contradice cómo manejar `$SPRINT_NUMBER` vacío | 🟡 Importante | 2 |
| I5 | `@analista-riesgo` en Lightning Scan: ¿`alertas_tempranas` o `riesgos`? | 🟡 Importante | 3 |
| I6 | 25+ skills declaradas "instaladas" en AGENTS.md que no existen | 🟡 Importante | 3 |
| I7 | Coordinador registra tests con `estado='creado'`; schema exige `'disenado'` | 🟡 Importante | 2 |
| I8 | `sprint-review` DoD exige `cobertura ≥ umbral`; umbral no definido en ningún archivo | 🟡 Importante | 3 |
| I9 | Sin trazabilidad de cuándo se invocó a `@security-specialist` | 🟡 Importante | 3 |
| I10 | `ci.yml` tiene `exit 1` en todos los jobs; AGENTS.md prohíbe tocar CI | 🟡 Importante | 3 |
| I11 | "Contrato antes de código" declarado en AGENTS.md pero sin enforcement en flujos | 🟡 Importante | 3 |
| I12 | Seis directorios existentes (`retrospectivas/`, `reviews/`, etc.) no están en AGENTS.md §13 | 🟡 Importante | 4 |
| I13 | `sprint-review` invoca `metricas-sprint` directamente, sin pasar por `@scrum-master` | 🟡 Importante | 3 |
| I14 | Protocolo coordinador→documentador indefinido: pseudo-YAML vs lenguaje natural | 🟡 Importante | 2 |
| I15 | `sprint-planning` verifica retro cerrada pero no hay query ni estado `cerrada` en schema | 🟡 Importante | 2 |
| M1 | Typo `"tefiás"` en `docs/modelos.md` | ⚪ Menor | 4 |
| M2 | `limpiar-memoria` agrupa bajo "Sprint" en `docs/comandos.md`; no es ceremonia | ⚪ Menor | 4 |
| M3 | `commitizen` en `.pre-commit-config.yaml`; `git-workflow` skill recomienda `conventional-pre-commit` | ⚪ Menor | 4 |
| M4 | `nueva-feature.md` invoca `generar_handoff` dos veces en el paso 4 | ⚪ Menor | 4 |
| M5 | `onboarding.md` hardcodea "13 agentes y 26 comandos" | ⚪ Menor | 4 |
| M6 | Docs: `docs/reviews/`, `docs/spikes/`, `docs/releases/` sin `.gitkeep` | ⚪ Menor | 4 |
| M7 | `leer-documento` skill description no menciona `.txt` aunque la lógica lo soporta | ⚪ Menor | 4 |
| M8 | `sprint-review` step 1 invoca `metricas-sprint` sin vía `@scrum-master` (duplicado con I13) | ⚪ Menor | 3 |
| M9 | `limpiar-memoria.md` menciona límite duro 250; `higiene-memoria.md` dice 400 (duplicado con I1) | ⚪ Menor | 2 |
| M10 | `AGENTS.md` §12 y `.opencode/skills/README.md` listan mismos ecosystem skills | ⚪ Menor | 4 |

---

## FASE 0 — Seguridad inmediata
> **Ejecutar antes que cualquier otra cosa. No comitear nada más hasta resolver B1 y B2.**

---

### B1 — `.env` con credenciales en texto plano commiteado

**Problema:** `docs/infra-stacks/bigdata/.env` contiene credenciales reales
commiteadas. El `.gitignore` solo cubre `.env` en la raíz, no en subdirectorios.

**Archivos involucrados:**
- `docs/infra-stacks/bigdata/.env` ← eliminar del historial
- `.gitignore` ← ampliar cobertura

**Pasos exactos:**

#### Paso 1 — Revocar las credenciales antes de cualquier otra cosa

Antes de tocar el repo, revocar/rotar todas las credenciales que aparezcan
en ese `.env`. El historial de git ya las expuso; retirar el archivo no
las invalida retroactivamente.

#### Paso 2 — Eliminar el archivo del historial de git

```bash
# Eliminar el archivo del tracking de git (sin borrar el archivo local)
git rm --cached docs/infra-stacks/bigdata/.env

# Si ya fue commiteado en el pasado, limpiar del historial completo:
git filter-repo --path docs/infra-stacks/bigdata/.env --invert-paths
# (requiere: pip install git-filter-repo)
```

#### Paso 3 — Crear `.env.example` como reemplazo documentado

Crear `docs/infra-stacks/bigdata/.env.example` con las mismas variables
pero con valores placeholder:

```bash
# docs/infra-stacks/bigdata/.env.example
# Copia este archivo como .env y rellena con tus valores reales.
# NUNCA commitees .env — está en .gitignore.

POSTGRES_USER=<usuario_db>
POSTGRES_PASSWORD=<contraseña_segura>
POSTGRES_DB=<nombre_base_de_datos>
KAFKA_BROKER_URL=<host:puerto>
# ... resto de variables según el stack
```

#### Paso 4 — Ampliar `.gitignore` para cubrir subdirectorios

Abrir `.gitignore` y añadir al final:

```gitignore
# Archivos de entorno en cualquier subdirectorio
**/.env
**/.env.local
**/.env.production
# Excepción: archivos de ejemplo sí se versioanan
!**/.env.example
```

#### Paso 5 — Verificar que no hay otros `.env` commiteados

```bash
git ls-files | grep -E '(^|/)\.env$'
```

Si devuelve resultados, repetir el proceso del Paso 2 para cada uno.

---

### B2 — `.secrets.baseline` no existe; `detect-secrets` falla en el primer commit

**Problema:** `.pre-commit-config.yaml` configura el hook `detect-secrets`
con `args: ["--baseline", ".secrets.baseline"]`. El archivo `.secrets.baseline`
no existe en el repo. Cualquier dev que instale los hooks ejecutará `git commit`
y el hook fallará inmediatamente con un error de archivo no encontrado.

**Archivos involucrados:**
- `.pre-commit-config.yaml` ← referencia al baseline
- `.secrets.baseline` ← crear este archivo
- `setup.sh` ← añadir generación automática del baseline
- `README.md` ← documentar el paso de inicialización

**Pasos exactos:**

#### Paso 1 — Generar el baseline inicial

```bash
# Instalar detect-secrets si no está disponible
pip install detect-secrets

# Generar el baseline escaneando el repo actual
detect-secrets scan > .secrets.baseline

# Auditar el baseline para marcar falsos positivos
detect-secrets audit .secrets.baseline
```

#### Paso 2 — Commitear el baseline

```bash
git add .secrets.baseline
git commit -m "chore: agregar baseline de detect-secrets para pre-commit"
```

#### Paso 3 — Añadir generación automática en `setup.sh`

Localizar en `setup.sh` la sección `── 5. Inicializar git si no existe ──`
y añadir **antes** de ese bloque:

```bash
# ── 4b. Generar baseline de detect-secrets (si pre-commit está activo) ──
if command -v detect-secrets >/dev/null 2>&1; then
  if [ ! -f .secrets.baseline ]; then
    detect-secrets scan > .secrets.baseline
    echo "✅ .secrets.baseline generado"
  else
    echo "✅ .secrets.baseline ya existe"
  fi
else
  echo "⚠️  detect-secrets no instalado. Instala con: pip install detect-secrets"
  echo "    Luego ejecuta: detect-secrets scan > .secrets.baseline"
fi
```

#### Paso 4 — Documentar en `README.md`

En la sección de setup inicial del README, añadir:

```markdown
### Pre-commit hooks

Este proyecto usa `pre-commit` con `detect-secrets`. Antes de tu primer commit:

\`\`\`bash
pip install pre-commit detect-secrets
pre-commit install
detect-secrets scan > .secrets.baseline  # solo la primera vez
\`\`\`
```

---

## FASE 1 — Blockers técnicos

---

### B3 — `riesgos.estado` CHECK constraint no incluye `monitoreado`

**Problema:** `init.sql` define el CHECK constraint de `riesgos.estado` como:
```sql
CHECK (estado IN ('identificado', 'mitigado', 'materializado', 'cerrado'))
```
Pero `sprint-ejecutar.md` consulta:
```sql
WHERE estado IN ('identificado', 'monitoreado')
```
El valor `'monitoreado'` no existe en el constraint. La query retorna solo
`'identificado'` silenciosamente; los riesgos en estado `monitoreado` nunca
aparecen en ejecución de sprint.

**Archivos involucrados:**
- `.opencode/progreso/init.sql` ← añadir `monitoreado` al CHECK
- `.opencode/command/sprint-ejecutar.md` ← la query ya usa el valor correcto
- `.opencode/agent/documentador-interno.md` ← documentar el estado

**Cambio exacto en `init.sql`:**

Localizar la tabla `riesgos` y cambiar la línea:

```sql
-- ANTES:
estado TEXT DEFAULT 'identificado' CHECK (estado IN ('identificado', 'mitigado', 'materializado', 'cerrado')),

-- DESPUÉS:
estado TEXT DEFAULT 'identificado' CHECK (estado IN ('identificado', 'monitoreado', 'mitigado', 'materializado', 'cerrado')),
```

**Cambio en `documentador-interno.md`:**

En la sección `### registrar_riesgo`, actualizar la línea de documentación
de estados:

```markdown
-- ANTES:
Estados: `identificado`, `mitigado`, `materializado`, `cerrado`.

-- DESPUÉS:
Estados: `identificado`, `monitoreado`, `mitigado`, `materializado`, `cerrado`.
- `identificado` → riesgo detectado, sin plan de acción aún.
- `monitoreado` → bajo observación activa; se revisa en cada sprint.
- `mitigado` → plan de mitigación ejecutado; riesgo reducido.
- `materializado` → el riesgo ocurrió; requiere respuesta.
- `cerrado` → resuelto o aceptado formalmente.
```

**Nota:** Si ya existe una base SQLite con datos en producción (`.opencode/progreso/progreso.db`),
ejecutar esta migración manual en lugar de re-correr `init.sql`:

```sql
-- Migración segura (SQLite no soporta ALTER CHECK directamente)
-- 1. Crear tabla nueva con el constraint correcto
CREATE TABLE riesgos_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sprint_id TEXT,
    feature_slug TEXT,
    categoria TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    probabilidad TEXT NOT NULL CHECK (probabilidad IN ('baja', 'media', 'alta')),
    impacto TEXT NOT NULL CHECK (impacto IN ('bajo', 'medio', 'alto')),
    mitigacion TEXT,
    estado TEXT DEFAULT 'identificado' CHECK (estado IN ('identificado', 'monitoreado', 'mitigado', 'materializado', 'cerrado')),
    agente TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
-- 2. Copiar datos
INSERT INTO riesgos_new SELECT * FROM riesgos;
-- 3. Reemplazar tabla
DROP TABLE riesgos;
ALTER TABLE riesgos_new RENAME TO riesgos;
```

---

### B4 — `DROP TABLE eventos` destruye el historial al re-ejecutar `init.sql`

**Problema:** `init.sql` tiene:
```sql
DROP TABLE IF EXISTS eventos;
CREATE TABLE eventos (...);
```
Cada vez que un dev nuevo configura el entorno o se re-corre `init.sql`,
se borra todo el historial de eventos. La tabla `eventos` está diseñada como
log inmutable — el DROP la convierte en efímera.

Adicionalmente, `documentador-interno.md` usa:
```sql
INSERT INTO eventos (agente, tipo, descripcion, referencia_id) VALUES (?, ?, ?, ?);
```
Pero la tabla tiene `UNIQUE(agente, tipo, referencia_id)`. Si se registra dos
veces el mismo evento, el INSERT falla silenciosamente.

**Archivos involucrados:**
- `.opencode/progreso/init.sql` ← cambiar DROP por CREATE IF NOT EXISTS + índice
- `.opencode/agent/documentador-interno.md` ← cambiar INSERT por INSERT OR IGNORE

**Cambio exacto en `init.sql`:**

```sql
-- ANTES:
DROP TABLE IF EXISTS eventos;
CREATE TABLE eventos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    agente TEXT,
    tipo TEXT NOT NULL,
    descripcion TEXT,
    referencia_id TEXT,
    UNIQUE(agente, tipo, referencia_id)
);

-- DESPUÉS:
CREATE TABLE IF NOT EXISTS eventos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    agente TEXT,
    tipo TEXT NOT NULL,
    descripcion TEXT,
    referencia_id TEXT
);
-- Índice para búsquedas frecuentes por agente y referencia (sin UNIQUE destructivo)
CREATE INDEX IF NOT EXISTS idx_eventos_agente ON eventos(agente);
CREATE INDEX IF NOT EXISTS idx_eventos_referencia ON eventos(referencia_id);
CREATE INDEX IF NOT EXISTS idx_eventos_timestamp ON eventos(timestamp);
```

**Razón del cambio en UNIQUE:** el constraint `UNIQUE(agente, tipo, referencia_id)`
impide registrar dos eventos del mismo tipo para el mismo recurso (ej: dos
`track_completado` para la misma feature en distintas sesiones). Esto es un
anti-patrón para un log de auditoría. Se reemplaza por índices de búsqueda.

**Cambio en `documentador-interno.md`**, sección `### registrar_evento`:

```sql
-- ANTES:
INSERT INTO eventos (agente, tipo, descripcion, referencia_id)
VALUES (?, ?, ?, ?);

-- DESPUÉS:
INSERT INTO eventos (agente, tipo, descripcion, referencia_id)
VALUES (?, ?, ?, ?);
-- Nota: se permiten múltiples eventos del mismo tipo para el mismo recurso.
-- El timestamp distingue cada ocurrencia. Esto es intencional — es un log de auditoría.
```

---

### B5 — `.venv/` de `leer-documento` commiteado

**Problema:** El directorio `.opencode/skills/leer-documento/.venv/` está
bajo control de versiones. El `.gitignore` solo ignora `.venv/` en la raíz.
Esto versiona cientos de binarios Python específicos de la plataforma del
dev original, potencialmente con symlinks rotos en otros sistemas.

**Archivos involucrados:**
- `.gitignore` ← añadir cobertura para `.venv/` en subdirectorios
- `.opencode/skills/leer-documento/.venv/` ← eliminar del tracking

**Pasos exactos:**

#### Paso 1 — Quitar `.venv/` del tracking

```bash
git rm -r --cached .opencode/skills/leer-documento/.venv/
git commit -m "chore: eliminar .venv de leer-documento del tracking de git"
```

#### Paso 2 — Ampliar `.gitignore`

En `.gitignore`, asegurarse de que la línea `**/.venv` esté presente
(ya debería estar después de la corrección B1, pero verificar):

```gitignore
# Entornos virtuales Python en cualquier ubicación del repo
**/.venv/
**/.venv
```

#### Paso 3 — Verificar que el skill funciona sin el .venv commiteado

El skill `leer-documento` ya tiene un `setup.sh` que reconstruye el `.venv`
localmente. Verificar que `init-proyecto.md` lo invoca correctamente:

```
Si .opencode/skills/leer-documento/.venv no existe,
ejecuta: bash .opencode/skills/leer-documento/setup.sh
```

Esta lógica ya existe en `init-proyecto.md` — no requiere cambio.

---

## FASE 2 — Inconsistencias de datos y proceso

---

### I1 + M9 — Límites de memoria contradictorios entre dos archivos

**Problema:** Dos fuentes distintas definen límites distintos:

| Archivo | Límite warning | Límite bloqueo |
|---|---|---|
| `AGENTS.md` §11 | 250 líneas | 400 líneas |
| `docs/higiene-memoria.md` | 250 líneas | 400 líneas ✅ coincide |
| `limpiar-memoria.md` salida final | 150 líneas | 250 líneas ❌ no coincide |

`limpiar-memoria.md` dice en su sección "Salida final esperada":
> "Tamaño de AGENTS.md de vuelta a < **150** líneas."

Pero `AGENTS.md` §11 y `higiene-memoria.md` definen el saludable como < 250.

**Archivo involucrado:**
- `.opencode/command/limpiar-memoria.md`

**Cambio exacto:**

Localizar en `limpiar-memoria.md` la sección `## Salida final esperada` y cambiar:

```markdown
-- ANTES:
- Tamaño de AGENTS.md de vuelta a < 150 líneas.

-- DESPUÉS:
- Tamaño de AGENTS.md de vuelta a zona saludable (< 250 líneas según política
  definida en `AGENTS.md` §11 y `docs/higiene-memoria.md`).
```

También en la sección `### 1. Medir`, el comentario inline menciona números.
Cambiar para que siempre los lea de `AGENTS.md` en lugar de hardcodearlos:

```markdown
-- ANTES:
Compara con los límites definidos en la sección "11. Higiene de memoria"
del propio `AGENTS.md` (lee de allí los números actuales — pueden haber
sido ajustados por el equipo):

-- SIN CAMBIO (esta parte ya está bien) --
```

La sección `### 3. Reporte` tiene una tabla con los números hardcodeados:
```markdown
-- ANTES (en la tabla del reporte de auditoría):
**Tamaño**: NN líneas (límite blando 150, duro 250)

-- DESPUÉS:
**Tamaño**: NN líneas (límite blando 250, bloqueo 400 — ver AGENTS.md §11)
```

---

### I2 — `decisiones.estado` casing inconsistente

**Problema:** `init.sql` no define CHECK constraint en `decisiones.estado`
(usa default `'propuesta'` libre), pero el uso está fragmentado:

- `sprint-planning.md` consulta: `WHERE estado = 'aceptada'`
- `sprint-ejecutar.md` consulta: `WHERE estado = 'aceptada'`
- `decision.md` escribe: `Estado: Propuesta` (mayúscula)
- `documentador-interno.md` escribe: `estado: 'Propuesta'` (mayúscula)
- `escribir-adr` skill usa: `Estado: Aceptada` (mayúscula)

En SQLite, `=` es case-sensitive. Si se registra `'Propuesta'` y se consulta
`estado = 'propuesta'`, no hay match.

**Archivos involucrados:**
- `.opencode/progreso/init.sql` ← añadir CHECK constraint con enum fijo
- `.opencode/command/decision.md` ← normalizar a minúsculas
- `.opencode/agent/documentador-interno.md` ← normalizar estados en registrar_decision
- `.opencode/skills/escribir-adr/SKILL.md` ← normalizar a minúsculas

**Cambio en `init.sql`:**

```sql
-- ANTES:
CREATE TABLE IF NOT EXISTS decisiones (
    ...
    estado TEXT DEFAULT 'propuesta',
    ...
);

-- DESPUÉS:
CREATE TABLE IF NOT EXISTS decisiones (
    ...
    estado TEXT DEFAULT 'propuesta' CHECK (estado IN ('propuesta', 'aceptada', 'rechazada', 'reemplazada', 'obsoleta')),
    ...
);
```

**Cambio en `documentador-interno.md`**, sección `### registrar_decision`:

```markdown
-- AÑADIR después de la SQL:
Estados válidos (siempre en **minúsculas**):
- `propuesta` → ADR redactado, pendiente de aprobación.
- `aceptada` → aprobada por el equipo, en vigor.
- `rechazada` → evaluada y descartada (conservar para contexto histórico).
- `reemplazada` → supersedida por otro ADR (incluir referencia al nuevo).
- `obsoleta` → ya no aplica por cambio de contexto.
```

**Cambio en `decision.md`**, sección `### 6. Registrar en SQLite`:

```markdown
-- ANTES:
- Estado: Propuesta

-- DESPUÉS:
- Estado: propuesta
```

**En `escribir-adr` skill**, buscar cualquier mención de `Estado: Aceptada`
o `Estado: Propuesta` y cambiar a minúsculas: `estado: aceptada` / `estado: propuesta`.

---

### I3 — `setup.sh` inicializa git; `init-proyecto` prohíbe hacerlo

**Problema:** `setup.sh` en su sección 5 ejecuta:
```bash
if [ ! -d .git ]; then
  git init
  git add -A
  git commit -m "chore: init desde opencode-template"
fi
```

Pero `init-proyecto.md` en sus reglas dice explícitamente:
```
**No inicialices git.** El usuario decidirá.
```

Un dev que ejecute `setup.sh` primero y luego `/init-proyecto` tendrá el repo
ya inicializado con un commit que el agente desconoce, y en su paso 1
(`git rev-parse --show-toplevel`) detectará que git ya existe e informará
al usuario — generando confusión.

**Archivos involucrados:**
- `setup.sh`
- `.opencode/command/init-proyecto.md` (sin cambio — es la fuente de verdad)

**Cambio en `setup.sh`:**

Reemplazar la sección 5 completa:

```bash
# ── 5. Verificar git (NO inicializar automáticamente) ──
if [ ! -d .git ]; then
  echo ""
  echo "ℹ️  Git no está inicializado en este directorio."
  echo "   Para inicializarlo, ejecuta:"
  echo "     git init && git add -A && git commit -m 'chore: init desde opencode-template'"
  echo "   O usa el comando /init-proyecto en OpenCode para un setup guiado."
else
  echo "✅ git ya inicializado ($(git rev-parse --short HEAD) en rama $(git branch --show-current))"
fi
```

---

### I4 — `sprint-planning` contradice el comportamiento con `$SPRINT_NUMBER` vacío

**Problema:** El mismo archivo tiene dos comportamientos mutuamente excluyentes:

- Sección `## Argumentos` dice: *"si está vacío, detectar el siguiente mirando `docs/sprints/`"*
- Sección `## Reglas` dice: *"Si `$SPRINT_NUMBER` o `$DURATION` están vacíos, detente y pide al usuario que los especifique."*

**Archivo involucrado:**
- `.opencode/command/sprint-planning.md`

**Decisión a tomar:** La detección automática (comportamiento de la sección Argumentos)
es la opción más ergonómica. Eliminar la regla contradictoria y documentar el comportamiento real.

**Cambio en `sprint-planning.md`:**

En la sección `## Argumentos`, dejar como está (auto-detectar es correcto).

En la sección `## Reglas`, cambiar:

```markdown
-- ANTES:
- **Si $SPRINT_NUMBER o $DURATION están vacíos**, detente y pide al usuario que los especifique.

-- DESPUÉS:
- **Si $SPRINT_NUMBER está vacío**, auto-detecta el siguiente número leyendo `docs/sprints/`
  (directorios `NN/` más reciente + 1). Si no existe ninguno, empieza en `01`.
  Informa al usuario el número detectado antes de continuar.
- **Si $DURATION está vacío**, usa el default de 2 semanas e informa al usuario.
```

---

### I7 — Coordinador registra tests con `estado='creado'`; schema exige `'disenado'`

**Problema:** `coordinador.md` sección `### 8. Registrar tests creados` dice:
```
- estado: creado
```
Pero `init.sql` define `tests.estado DEFAULT 'disenado'` y el CHECK implícito
del documentador lista: `disenado | listo | ejecutado | fallido`.
El valor `'creado'` viola el flujo — un test recién diseñado está `disenado`,
no `creado`.

**Archivos involucrados:**
- `.opencode/agent/coordinador.md` ← corregir el valor de estado
- `.opencode/agent/documentador-interno.md` ← documentar el ciclo de vida de estados

**Cambio en `coordinador.md`**, sección `### 8. Registrar tests creados`:

```markdown
-- ANTES:
- estado: creado

-- DESPUÉS:
- estado: disenado
```

**Añadir en `documentador-interno.md`**, sección `### registrar_test`, después del SQL:

```markdown
Ciclo de vida de `estado` en tests:
- `disenado` → test definido (casos de prueba escritos, sin ejecutar).
- `listo` → test automatizado e integrado en la suite, listo para CI.
- `ejecutado` → corrió en la última ejecución de CI/suite.
- `fallido` → la última ejecución arrojó error.

Al registrar un test nuevo (recién diseñado por `@tester`): usar `disenado`.
Al automatizarlo: actualizar a `listo`.
```

---

### I14 — Protocolo coordinador→documentador indefinido

**Problema:** El coordinador usa pseudo-YAML estructurado:
```yaml
registrar_alerta_temprana:
  - agente: @infra-specialist
  - tipo: "configuracion"
  - severidad: "alta"
```
Pero el documentador dice: *"Cuando te invoquen, interpreta el comando"* —
esperando lenguaje natural. No hay contrato de interfaz. El formato real
de la invocación queda a interpretación del LLM en cada sesión.

**Archivos involucrados:**
- `.opencode/agent/documentador-interno.md` ← definir formato de invocación aceptado
- `.opencode/agent/coordinador.md` ← alinear todos los ejemplos al formato definido

**Cambio en `documentador-interno.md`**, añadir sección `## Formato de invocación` después de `## Operaciones`:

```markdown
## Formato de invocación

Acepto comandos en **lenguaje natural estructurado** siguiendo este patrón:

```
<operacion>:
  campo1: valor1
  campo2: valor2
  campoJSON: '{"key": "value"}'
```

**Ejemplo correcto:**
```
registrar_alerta_temprana:
  agente: @infra-specialist
  tipo: configuracion
  descripcion: "No hay healthcheck configurado en el API"
  severidad: alta
  sprint_id: Sprint-03
  feature_slug: pago-con-tarjeta
```

**Reglas de formato:**
- Los valores de enums (severidad, estado, tipo de test, etc.) siempre en **minúsculas**.
- Los campos JSON (`contrato_json`) se pasan como string JSON válido entre comillas simples.
- Si un campo es opcional y no aplica, omitirlo (no pasar `null` literal).
- Si el formato es ambiguo o falta un campo requerido, devuelvo error descriptivo
  antes de ejecutar la inserción.
```

**Cambio en `coordinador.md`:** Revisar todos los ejemplos de invocación al documentador
y eliminar los guiones `-` de lista YAML (reemplazar por indentación directa sin `-`),
alineando con el formato definido en el documentador. Ejemplo en sección `### 0. Lightning Scan`:

```markdown
-- ANTES:
registrar_alerta_temprana:
  - agente: @infra-specialist
  - tipo: "configuracion"
  - descripcion: "No hay healthcheck configurado en el API"
  - severidad: "alta"

-- DESPUÉS:
registrar_alerta_temprana:
  agente: @infra-specialist
  tipo: configuracion
  descripcion: No hay healthcheck configurado en el API
  severidad: alta
  resolucion: null
```

Aplicar el mismo cambio (quitar `-` de lista) en todas las secciones de
`coordinador.md` que muestren ejemplos de invocación al documentador:
secciones 0b, 2b, 4, 5, 7, 8, 10, 11.

---

### I15 — `sprint-planning` verifica retro cerrada pero no hay query ni estado `cerrada` en schema

**Problema:** `sprint-planning.md` paso 1 dice:
> *"¿Retro del sprint anterior cerrada? Si no, ejecuta /retrospectiva primero."*

Pero:
1. El schema de `sprints` tiene `estado TEXT DEFAULT 'planning'` sin CHECK constraint.
   Los valores usados son `planificado`, `activo`, `cerrado` — pero no hay un estado
   `retrospectiva_completada` o similar que indique que la retro ya ocurrió.
2. `retrospectiva.md` registra un evento de tipo `retrospectiva_completada` en la tabla
   `eventos`, pero no actualiza el estado del sprint.
3. No hay query definida en `sprint-planning` para verificar esto.

**Archivos involucrados:**
- `.opencode/command/sprint-planning.md` ← añadir query concreta de verificación
- `.opencode/command/retrospectiva.md` ← añadir actualización de estado del sprint al cerrar
- `.opencode/progreso/init.sql` ← añadir CHECK constraint en `sprints.estado`
- `.opencode/agent/documentador-interno.md` ← documentar `actualizar_sprint`

**Cambio en `init.sql`**, tabla `sprints`:

```sql
-- ANTES:
CREATE TABLE IF NOT EXISTS sprints (
    id TEXT PRIMARY KEY,
    goal TEXT,
    fecha_inicio TEXT,
    fecha_fin TEXT,
    estado TEXT DEFAULT 'planning'
);

-- DESPUÉS:
CREATE TABLE IF NOT EXISTS sprints (
    id TEXT PRIMARY KEY,
    goal TEXT,
    fecha_inicio TEXT,
    fecha_fin TEXT,
    estado TEXT DEFAULT 'planificado' CHECK (estado IN ('planificado', 'activo', 'cerrado', 'retrospectiva_completada'))
);
```

**Cambio en `retrospectiva.md`**, paso 7 (después de guardar la retro), añadir:

```markdown
### 7b. Actualizar estado del sprint a retrospectiva_completada

Invoca a `@documentador-interno`:

\`\`\`
actualizar_sprint:
  id: <sprint_id>
  estado: retrospectiva_completada
  fecha_fin: <fecha de hoy>
\`\`\`

Esto habilita el pre-requisito de `/sprint-planning` para el siguiente sprint.
```

**Cambio en `sprint-planning.md`**, paso 1, reemplazar el check de retro:

```markdown
-- ANTES:
- [ ] **¿Retro del sprint anterior cerrada?** (Salta si es Sprint 1 o si
      no existe `docs/sprints/` anterior.) Si no, ejecuta `/retrospectiva`
      primero.

-- DESPUÉS:
- [ ] **¿Retro del sprint anterior completada?**
  (Salta si es Sprint 1 o si no existe `docs/sprints/` anterior.)

  Verificar con `@documentador-interno`:
  \`\`\`
  consultar:
    tabla: sprints
    criterios: estado = 'retrospectiva_completada' AND id = 'Sprint-<NN-1>'
  \`\`\`

  Si la query retorna vacío: el sprint anterior no cerró su retro.
  Ejecutar `/retrospectiva` antes de continuar. No se planifica sin cerrar el anterior.
```

---

## FASE 3 — Gaps de trazabilidad y proceso

---

### I5 — `@analista-riesgo` en Lightning Scan: ¿`alertas_tempranas` o `riesgos`?

**Problema:** El protocolo del Lightning Scan (coordinador.md §0) dice que
**todos** los agentes registran en `alertas_tempranas`. Pero `analista-riesgo.md`
describe que su output natural es la tabla `riesgos` (con probabilidad, impacto,
categoría, mitigación). Son dos tablas distintas con propósitos distintos.

**Decisión de diseño:** Las alertas del Lightning Scan son detecciones rápidas
de "ojo fresco" → van a `alertas_tempranas`. Los riesgos formales con evaluación
probabilidad × impacto → van a `riesgos`. El `@analista-riesgo` puede producir
ambos: alerta rápida primero, riesgo formal si la alerta es crítica.

**Archivos involucrados:**
- `.opencode/agent/coordinador.md` ← clarificar el flujo dual
- `.opencode/agent/analista-riesgo.md` ← especificar qué va a cada tabla

**Cambio en `coordinador.md`**, sección `### 0. Lightning Scan`, en las Reglas:

```markdown
-- AÑADIR después de "Todas las alertas se registran en @documentador-interno (tabla alertas_tempranas)":

**Caso especial — @analista-riesgo:**
El analista de riesgos produce dos tipos de output en el Lightning Scan:
1. **Alerta rápida** (siempre): se registra en `alertas_tempranas` como cualquier agente.
   - `tipo`: `riesgo-tecnico`, `riesgo-negocio`, `riesgo-timeline` o `riesgo-dependencia`.
2. **Riesgo formal** (solo si la alerta es `alta` o `critica`): el coordinador
   invoca a `@analista-riesgo` para que evalúe probabilidad × impacto y registre
   en la tabla `riesgos` con su formato completo (categoria, mitigacion, etc.).

Este flujo dual evita sobrecargar `riesgos` con entradas de baja calidad
y garantiza que alertas críticas siempre tienen evaluación formal.
```

**Cambio en `analista-riesgo.md`**, añadir sección `## Participación en Lightning Scan`:

```markdown
## Participación en Lightning Scan

Cuando el coordinador te invoque para el Lightning Scan:

### Paso 1 — Alerta rápida (siempre, para todos los riesgos detectados)
Registra una alerta por cada riesgo que detectes:

\`\`\`
registrar_alerta_temprana:
  agente: @analista-riesgo
  tipo: riesgo-tecnico         ← o: riesgo-negocio | riesgo-timeline | riesgo-dependencia
  descripcion: <descripción concreta del riesgo>
  severidad: <baja | media | alta | critica>
  sprint_id: <sprint actual>
  feature_slug: <slug si aplica>
\`\`\`

### Paso 2 — Evaluación formal (solo para alertas `alta` o `critica`)
Si el coordinador lo solicita para una alerta crítica, produce la evaluación completa:

\`\`\`
registrar_riesgo:
  sprint_id: <sprint>
  feature_slug: <slug>
  categoria: <tecnico | dependencias | timeline | negocio | seguridad | operacional | proceso>
  descripcion: <descripción>
  probabilidad: <baja | media | alta>
  impacto: <bajo | medio | alto>
  mitigacion: <acción concreta>
  estado: identificado
  agente: @analista-riesgo
\`\`\`
```

---

### I6 — Skills declaradas "instaladas" en AGENTS.md que no existen localmente

**Problema:** `AGENTS.md` §12 lista 26 skills de `obra/superpowers`,
`mattpocock/skills`, `anthropics/skills` y `vercel-labs/skills` como
*"instaladas"*, pero ninguna existe en `.opencode/skills/` ni en `.agents/`.
Los agentes que las listan en su sección "Skills recomendadas" las presentan
como disponibles cuando no lo están.

**Archivos involucrados:**
- `AGENTS.md` §12 ← cambiar "instaladas" por "disponibles en el ecosistema"
- Todos los archivos de agente con sección "Skills recomendadas" ← añadir nota

**Cambio en `AGENTS.md`**, sección `## 12. Skills del ecosistema (skills.sh)`:

```markdown
-- ANTES (título de la sección):
Skills instaladas desde el ecosistema abierto (`npx skills add`). OpenCode las descubre
automáticamente desde `.agents/skills/` y `~/.agents/skills/`.

-- DESPUÉS:
Skills **disponibles** en el ecosistema abierto. Para instalarlas:
\`\`\`bash
npx skills add obra/superpowers          # instala las 14 skills de obra
npx skills add mattpocock/skills         # instala las 9 skills de mattpocock
npx skills add anthropics/skills@docx    # instala skill individual
\`\`\`
Una vez instaladas, OpenCode las descubre automáticamente desde `.agents/skills/` y `~/.agents/skills/`.

> **Estado actual:** ninguna de estas skills está instalada en este template por defecto.
> Instálalas según las necesidades de tu proyecto.
```

**En cada archivo de agente** que tenga sección `## Skills recomendadas`
con skills del ecosistema (coordinador, tester, infra-specialist, etc.),
añadir una nota al inicio de esa sección:

```markdown
## Skills recomendadas

> Las skills con `*` son del ecosistema externo y requieren instalación previa:
> `npx skills add <owner/repo>`. Las skills sin `*` están incluidas en este template.

- `metricas-sprint` — cálculo de velocity, throughput, lead/cycle time. *(incluida)*
- `dispatching-parallel-agents`* — orquestación de tracks paralelos. *(ecosistema: `obra/superpowers`)*
```

---

### I8 — `sprint-review` DoD exige cobertura ≥ umbral sin definir el umbral

**Problema:** `sprint-review.md` incluye en su DoD checklist:
```
- [ ] Cobertura de tests ≥ objetivo definido en AGENTS.md.
```
Pero `AGENTS.md` §9 (DoD) no menciona ningún umbral de cobertura.
El criterio no puede verificarse objetivamente.

**Archivos involucrados:**
- `.opencode/command/sprint-review.md` ← hacerlo condicional
- `AGENTS.md` §9 ← añadir placeholder de umbral o hacer el criterio condicional

**Cambio en `AGENTS.md`**, sección `### Definition of Done (DoD)`, añadir un ítem:

```markdown
-- AÑADIR al final de la lista del DoD:
- [ ] Si el proyecto define un umbral de cobertura (ver sección 2 "Stack y herramientas"),
  la cobertura de tests no decrece respecto al sprint anterior.
```

**Cambio en `sprint-review.md`**, sección `### 5. Validar Definition of Done`, checklist:

```markdown
-- ANTES:
- [ ] Cobertura de tests ≥ objetivo definido en AGENTS.md.

-- DESPUÉS:
- [ ] Si el proyecto define un umbral de cobertura en AGENTS.md §2,
  verificar que no decreció. Si no está definido, omitir este ítem (N/A).
```

**Nota:** Para proyectos concretos que clonen este template, se recomienda
añadir en AGENTS.md §2 una línea como:
```markdown
- **Cobertura mínima:** 80% (líneas) para módulos de lógica de negocio.
```

---

### I9 — Sin trazabilidad de invocaciones de `@security-specialist`

**Problema:** `deploy-checklist.md` tiene el ítem:
```
- [ ] `/security-check` ejecutado sobre el diff.
```
Y `security-check.md` delega en `@security-specialist`. Pero ninguno de los
dos registra en SQLite que la auditoría ocurrió, cuándo, y qué encontró.
El DoD de seguridad no tiene evidencia persistida.

**Archivos involucrados:**
- `.opencode/command/security-check.md` ← añadir paso de registro
- `.opencode/agent/documentador-interno.md` ← ya tiene `registrar_evento`, no necesita cambio

**Cambio en `security-check.md`**, añadir paso 6 al final:

```markdown
### 6. Registrar auditoría en SQLite

Independientemente del resultado, registra que la auditoría se ejecutó.
Invoca a `@documentador-interno`:

\`\`\`
registrar_evento:
  agente: @security-specialist
  tipo: auditoria_seguridad
  descripcion: "Auditoría de seguridad completada. Alcance: <$ALCANCE>.
    Hallazgos: <N> críticos, <N> altos, <N> medios, <N> bajos."
  referencia_id: <sprint_id o feature_slug si aplica>
\`\`\`

Si hubo hallazgos críticos o altos, además registra como riesgo:

\`\`\`
registrar_riesgo:
  categoria: seguridad
  descripcion: <hallazgo principal>
  probabilidad: alta
  impacto: alto
  mitigacion: <fix sugerido por @security-specialist>
  estado: identificado
  agente: @security-specialist
\`\`\`

Esto garantiza que el DoD de seguridad tiene evidencia trazable en SQLite.
```

---

### I10 — `ci.yml` tiene `exit 1` en todos los jobs; AGENTS.md prohíbe tocar CI

**Problema:** `ci.yml` tiene todos sus jobs con `run: echo "..." && exit 1`
como stubs intencionales. `AGENTS.md` §8 regla 4 dice:
> *"Prohibido modificar sin razón: lockfiles, configuraciones de CI, migraciones aplicadas."*

Resultado: el CI nunca pasa (siempre falla), pero ningún agente puede arreglarlo
porque la regla lo prohíbe. Es un callejón sin salida.

**Archivos involucrados:**
- `.github/workflows/ci.yml` ← comentar los exit 1, documentar que es un placeholder
- `AGENTS.md` §8 ← añadir excepción explícita para el CI placeholder

**Cambio en `ci.yml`:** Reemplazar los `exit 1` por un mensaje más claro que
explique que el CI es un placeholder y que no falla intencionalmente en CI
(o hacer que los jobs sean `continue-on-error: true` hasta ser configurados):

```yaml
# ANTES (ejemplo de un job):
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          echo "Configura tu comando de tests aquí"
          exit 1

# DESPUÉS:
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        # TODO: reemplazar este placeholder con el comando real de tu stack
        # Ejemplos: pytest, npm test, go test ./..., cargo test
        # Una vez configurado, eliminar el 'echo' y el 'exit 0'
        run: |
          echo "⚠️ CI placeholder — configura tu comando de tests en este step"
          exit 0   # ← cambiado de 1 a 0 para que el pipeline no bloquee PRs
                   #   mientras se personaliza el template
```

**Cambio en `AGENTS.md`** §8, regla 4:

```markdown
-- ANTES:
4. **Prohibido modificar sin razón:** lockfiles, configuraciones de CI, migraciones aplicadas.

-- DESPUÉS:
4. **Prohibido modificar sin razón:** lockfiles, configuraciones de CI, migraciones aplicadas.
   Excepción explícita: `.github/workflows/ci.yml` en este template contiene
   placeholders (`exit 0`) que **deben reemplazarse** al personalizar el template
   para el proyecto. Esa modificación está autorizada y es el único caso donde
   un agente puede tocar CI sin justificación adicional.
```

---

### I11 — "Contrato antes de código" sin enforcement en los flujos

**Problema:** `AGENTS.md` §8 regla 8 dice:
> *"Ningún track empieza hasta que su entrada (contrato del módulo anterior) esté definida."*

Pero ni `sprint-ejecutar.md` ni `nueva-feature.md` tienen un paso de verificación
que consulte `contratos_modulo` en SQLite antes de lanzar cada track. La regla
existe en papel pero no en el flujo ejecutable.

**Archivos involucrados:**
- `.opencode/agent/coordinador.md` ← añadir gate explícito en el flujo de tracks
- `.opencode/command/nueva-feature.md` ← añadir gate en el checklist
- `.opencode/command/sprint-ejecutar.md` ← añadir gate en quality gates

**Cambio en `coordinador.md`**, sección `### 6. Ejecutar tracks`, insertar gate al inicio:

```markdown
### 6. Ejecutar tracks

**Gate de contratos — verificar ANTES de iniciar cada track:**

Para cada track que tenga dependencia de otro track, verificar que el contrato
del track del que depende ya está registrado en SQLite:

\`\`\`
consultar:
  tabla: contratos_modulo
  criterios: track = '<track-dependencia>' AND sprint_id = '<sprint_actual>'
\`\`\`

Si la query retorna vacío: el contrato no está registrado.
**No iniciar el track dependiente.** Volver al paso 5 (Definir y registrar contratos).

Si retorna resultado: el contrato existe. Proceder con la ejecución del track.

---
Para cada track, en orden de dependencia: [... resto del contenido actual ...]
```

**Cambio en `nueva-feature.md`**, sección `### 7. Checklist final`, añadir ítem:

```markdown
- [ ] Contratos de módulo registrados en SQLite **antes** de ejecutar cada track
  (verificado por @coordinador en paso 5)
```

---

### I13 + M8 — `sprint-review` invoca `metricas-sprint` directamente sin `@scrum-master`

**Problema:** `sprint-review.md` paso 1 dice:
> *"Invoca la skill `metricas-sprint`..."*

El skill `metricas-sprint` está asignado a `@scrum-master`. Invocar el skill
directamente desde el comando rompe la cadena de responsabilidad y produce
output sin el contexto y narrativa que el scrum-master añadiría.

**Archivo involucrado:**
- `.opencode/command/sprint-review.md`

**Cambio en `sprint-review.md`**, paso 1:

```markdown
-- ANTES:
### 1. Cargar métricas del sprint
Invoca la skill `metricas-sprint` y presenta al equipo: [...]

-- DESPUÉS:
### 1. Cargar métricas del sprint

Delega en `@scrum-master` para obtener las métricas con contexto de proceso:

\`\`\`
@scrum-master: Carga la skill metricas-sprint para el Sprint <NN>.
Presenta al equipo:
- Velocity real vs. estimada
- Throughput (historias completadas)
- % de completitud vs. compromiso
- Lead / cycle time promedio
- Comparación con los últimos 3 sprints si hay datos
\`\`\`

El scrum-master interpreta los números con contexto del equipo (ausencias,
imprevistos) antes de presentarlos. No los presentes como números crudos.
```

---

## FASE 4 — Documentación y menores

---

### I12 — Seis directorios sin mencionar en `AGENTS.md` §13

**Problema:** Los siguientes directorios existen en `docs/` y son escritos
por comandos, pero no aparecen en la tabla de AGENTS.md §13:
- `docs/retrospectivas/` (escrito por `/retrospectiva`)
- `docs/reviews/` (escrito por `/code-review`)
- `docs/spikes/` (escrito por `/spike`)
- `docs/releases/` (escrito por `/release`)
- `docs/devs/` (escrito por `/onboarding`)
- `docs/post-mortems/` (escrito por `/emergency`)

**Archivo involucrado:**
- `AGENTS.md` §13

**Cambio en `AGENTS.md`**, sección `## 13. Documentación ágil`:

```markdown
-- AÑADIR las filas faltantes a la tabla:

| Qué | Dónde |
|---|---|
| Análisis de dominio | `docs/anteproyecto.md` (generado por `/anteproyecto`) |
| Sprint activo | `docs/sprints/<NN>/` (goal, backlog, demo, retro) |
| Features en curso | `docs/features/<slug>/handoff.md` (generado por `@documentador-interno`) |
| Historias de usuario | `docs/historias/` o `docs/backlog/` |
| Decisiones arquitectónicas | `docs/decisiones/` (ADRs) |
| Análisis de datos | `docs/analisis/` (generado por `/explorar-datos`) |
| Runbooks operativos | `docs/runbooks/` |
| Threat models | `docs/threat-models/` |
| Contexto archivado | `docs/contexto-archivado/` |
| Retrospectivas | `docs/retrospectivas/<fecha>.md` (generado por `/retrospectiva`) |
| Code reviews | `docs/reviews/<fecha>-<scope>.md` (generado por `/code-review`) |
| Spikes técnicos | `docs/spikes/<slug>.md` (generado por `/spike`) |
| Release notes | `docs/releases/<version>.md` (generado por `/release`) |
| Perfiles de devs | `docs/devs/<usuario>.md` (generado por `/onboarding`) |
| Post-mortems | `docs/post-mortems/<fecha>.md` (generado por `/emergency`) |
```

---

### M1 — Typo `"tefiás"` en `docs/modelos.md`

**Archivo involucrado:** `docs/modelos.md`

Buscar la cadena `tefiás` y reemplazar por la palabra correcta en contexto.
(Presumiblemente `"tendrías"` o `"verías"` — leer el contexto para confirmarlo.)

```bash
grep -n "tefiás" docs/modelos.md
```

---

### M2 — `/limpiar-memoria` agrupado bajo "Sprint" en `docs/comandos.md`

**Problema:** `/limpiar-memoria` aparece en la tabla de `docs/comandos.md`
bajo el grupo de ceremonias de sprint. No es una ceremonia de sprint —
es una operación de mantenimiento de memoria que puede ejecutarse en cualquier
momento.

**Archivo involucrado:** `docs/comandos.md`

Mover `/limpiar-memoria` al grupo de mantenimiento/documentación de la tabla
de comandos, o crear un grupo nuevo `Mantenimiento del template` si no existe.

---

### M3 — `commitizen` vs `conventional-pre-commit` en git-workflow skill

**Problema:** `.pre-commit-config.yaml` usa `commitizen` para validar Conventional
Commits. El skill `git-workflow/SKILL.md` recomienda `conventional-pre-commit`
(herramienta diferente). Para un dev que siga el skill, instalaría la herramienta
equivocada.

**Archivos involucrados:**
- `.opencode/skills/git-workflow/SKILL.md`

**Cambio en `git-workflow` skill**: Actualizar la sección de hooks para que
muestre `commitizen` (alineado con lo que realmente usa el template) y añadir
nota sobre la alternativa:

```markdown
-- CAMBIAR el ejemplo de hook de commit-msg en la skill:

# Hook de Conventional Commits (usando commitizen — ya configurado en este template)
- repo: https://github.com/commitizen-tools/commitizen
  rev: v3.29.0
  hooks:
    - id: commitizen
      stages: [commit-msg]

# Alternativa: conventional-pre-commit (más ligero, sin configuración adicional)
# - repo: https://github.com/compilerla/conventional-pre-commit
#   rev: v3.0.0
#   hooks:
#     - id: conventional-pre-commit
#       stages: [commit-msg]
```

---

### M4 — `nueva-feature.md` invoca `generar_handoff` dos veces en el paso 4

**Problema:** En `nueva-feature.md` paso 4 (instrucciones al coordinador),
aparece `generar_handoff` listado dos veces en las instrucciones de registro:

```
5. Invoca a @documentador-interno para registrar:
   ...
   - Genera el handoff desde SQLite al final
   ...
   - La decisión de integrar si pasa
6. Genera el handoff desde SQLite (`@documentador-interno → generar_handoff`)
```

El item 5 y el item 6 son redundantes.

**Archivo involucrado:** `.opencode/command/nueva-feature.md`

**Cambio:** Eliminar la referencia duplicada a `generar_handoff` del item 5
de la lista anidada, dejando solo el paso 6 como el lugar canónico donde se
genera el handoff:

```markdown
-- ANTES (en la lista de instrucciones al coordinador, ítem 5):
5. Invoca a @documentador-interno para registrar:
   - La feature como requerimiento
   - Cada track completado como evento
   - Los tests creados
   - Los contratos de módulo (tabla contratos_modulo)
   - Las alertas tempranas (tabla alertas_tempranas)
   - Genera el handoff desde SQLite al final      ← ELIMINAR esta línea
   - La decisión de integrar si pasa
6. Genera el handoff desde SQLite (`@documentador-interno → generar_handoff`)

-- DESPUÉS:
5. Invoca a @documentador-interno para registrar:
   - La feature como requerimiento
   - Cada track completado como evento
   - Los tests creados
   - Los contratos de módulo (tabla contratos_modulo)
   - Las alertas tempranas (tabla alertas_tempranas)
   - La decisión de integrar si pasa
6. Genera el handoff desde SQLite (`@documentador-interno → generar_handoff`)
```

---

### M5 — `onboarding.md` hardcodea "13 agentes y 26 comandos"

**Problema:** `onboarding.md` paso 6 dice:
> *"este proyecto tiene 13 agentes y 26 comandos definidos"*

Si se añade un agente o comando al template, esta frase queda desactualizada.

**Archivo involucrado:** `.opencode/command/onboarding.md`

**Cambio:**

```markdown
-- ANTES:
"este proyecto tiene 13 agentes y 26 comandos definidos; ejecuta @ o / en
cualquier momento para autocompletar"

-- DESPUÉS:
"este proyecto tiene agentes y comandos definidos en AGENTS.md §6 y §7;
ejecuta @ o / en cualquier momento para autocompletar, o ejecuta
/docs-update para ver la tabla completa"
```

---

### M6 — Directorios sin `.gitkeep` que no pueden commitearse vacíos

**Problema:** Algunos directorios documentados en `docs/README.md` y escritos
por comandos no tienen `.gitkeep`, por lo que git no los versiona si están vacíos.
Un dev que clone el repo y ejecute un comando que asuma que el directorio existe
puede obtener un error.

**Directorios a verificar:**
```bash
for dir in docs/reviews docs/spikes docs/releases docs/retrospectivas docs/post-mortems docs/devs; do
  [ -d "$dir" ] && echo "existe: $dir" || echo "FALTA: $dir"
  [ -f "$dir/.gitkeep" ] && echo "  .gitkeep: ✅" || echo "  .gitkeep: ❌"
done
```

**Para cada directorio faltante:**
```bash
mkdir -p docs/reviews docs/spikes docs/releases docs/retrospectivas docs/post-mortems docs/devs
touch docs/reviews/.gitkeep
touch docs/spikes/.gitkeep
touch docs/releases/.gitkeep
touch docs/retrospectivas/.gitkeep
touch docs/post-mortems/.gitkeep
touch docs/devs/.gitkeep
git add docs/*/. gitkeep
git commit -m "chore: agregar .gitkeep en directorios docs/ necesarios"
```

---

### M7 — `leer-documento` description no menciona `.txt`

**Problema:** La skill `leer-documento` puede manejar archivos `.txt` (según
la lógica de `init-proyecto.md` que la invoca para ambos), pero su `description`
en el frontmatter solo menciona `.docx`. Los agentes que busquen un skill para
leer `.txt` no la encontrarán.

**Archivo involucrado:** `.opencode/skills/leer-documento/SKILL.md`

**Cambio en el frontmatter `description`:**

```markdown
-- ANTES:
description: Extrae texto y tablas de archivos Word (.docx) para procesarlos
             como texto plano en el contexto del agente.

-- DESPUÉS:
description: Extrae texto y tablas de archivos Word (.docx) o texto plano (.txt)
             para procesarlos como texto plano en el contexto del agente.
             Úsala cuando recibas especificaciones, historias de usuario o
             documentación de requisitos en formato Word o texto.
```

---

### M10 — `AGENTS.md` §12 y `.opencode/skills/README.md` listan los mismos ecosystem skills

**Problema:** Dos archivos distintos mantienen la misma lista de skills del
ecosistema. Si se actualiza uno, el otro queda desactualizado.

**Archivos involucrados:**
- `AGENTS.md` §12 ← reemplazar la tabla por un enlace
- `.opencode/skills/README.md` ← fuente de verdad (sin cambio)

**Cambio en `AGENTS.md`** §12, reemplazar la tabla completa por:

```markdown
## 12. Skills del ecosistema

> Lista completa, versiones y comandos de instalación:
> [`.opencode/skills/README.md`](.opencode/skills/README.md)

Instalación rápida: `npx skills add <owner/repo>` o `npx skills find <query>`.
```

---

## Checklist de verificación post-correcciones

Una vez aplicados todos los cambios, ejecutar esta verificación:

```bash
# B1 — Verificar que no hay .env con secretos
git ls-files | grep -E '(^|/)\.env$'
# Debe retornar vacío

# B2 — Verificar que .secrets.baseline existe
[ -f .secrets.baseline ] && echo "✅" || echo "❌ FALTA .secrets.baseline"

# B3 — Verificar el constraint de riesgos.estado en el schema
grep -A5 "estado TEXT" .opencode/progreso/init.sql | grep "monitoreado"
# Debe encontrar 'monitoreado' en el CHECK

# B4 — Verificar que no hay DROP TABLE en init.sql
grep "DROP TABLE" .opencode/progreso/init.sql
# Debe retornar vacío

# B5 — Verificar que .venv no está trackeado
git ls-files | grep ".venv"
# Debe retornar vacío

# I3 — Verificar que setup.sh no hace git init automático
grep "git init" setup.sh
# Debe retornar solo el comentario, no el comando real

# I4 — Verificar que sprint-planning no tiene la regla contradictoria
grep "detente y pide" .opencode/command/sprint-planning.md
# Debe retornar vacío

# I7 — Verificar que coordinador usa 'disenado' no 'creado'
grep "estado: creado" .opencode/agent/coordinador.md
# Debe retornar vacío

# I15 — Verificar que sprints tiene el estado retrospectiva_completada
grep "retrospectiva_completada" .opencode/progreso/init.sql
# Debe encontrar el valor en el CHECK

# Verificar que .gitignore cubre **/.env
grep "\*\*/\.env" .gitignore
# Debe encontrar la línea

# Verificar que todos los directorios tienen .gitkeep
for dir in docs/reviews docs/spikes docs/releases docs/retrospectivas docs/post-mortems docs/devs; do
  [ -f "$dir/.gitkeep" ] && echo "✅ $dir" || echo "❌ FALTA $dir/.gitkeep"
done
```

---

## Orden de ejecución recomendado

```
Fase 0 (seguridad) → Fase 1 (blockers SQL y git) → Fase 2 (proceso) → Fase 3 (trazabilidad) → Fase 4 (docs y menores)

Dentro de Fase 0: B1 primero (revocar credenciales ANTES de cualquier git push), luego B2.
Dentro de Fase 1: B4 primero (corregir init.sql), luego B3 (depende del schema correcto), luego B5 (independiente).
Las fases 2, 3 y 4 son independientes entre sí y pueden ejecutarse en paralelo.
```

---

*Generado en Mayo 2026 como resultado de auditoría de segunda pasada del opencode-template.*
