#!/bin/bash
# Instala el pre-commit hook anti-secretos en este repositorio
# Uso: ./install-hooks.sh

HOOK_DIR=".git/hooks"
HOOK_FILE="${HOOK_DIR}/pre-commit"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

if [ ! -d "$HOOK_DIR" ]; then
  echo -e "${RED}❌ No se encontró .git/hooks. ¿Estás en la raíz del repo?${RESET}"
  exit 1
fi

cat > "$HOOK_FILE" << 'HOOK'
#!/bin/bash
# pre-commit hook: bloquea commit de archivos con secretos

RED="\e[31m"
RESET="\e[0m"
BOLD="\e[1m"
BLOCKED=0

for file in $(git diff --cached --name-only); do
  case "$file" in
    .env|.env.local|.env.production|.env.development)
      echo -e "${RED}${BOLD}[pre-commit] ❌ BLOQUEADO: '$file' — usar .env.template en su lugar.${RESET}"
      BLOCKED=1
      ;;
    client_secret*.json|*client_secret*.json|*credentials*.json)
      echo -e "${RED}${BOLD}[pre-commit] ❌ BLOQUEADO: '$file' — credencial OAuth/API.${RESET}"
      BLOCKED=1
      ;;
    *.pem|*.key|*.p12)
      echo -e "${RED}${BOLD}[pre-commit] ❌ BLOQUEADO: '$file' — clave criptográfica.${RESET}"
      BLOCKED=1
      ;;
  esac
done

# Avisa si hay CHANGEME sin reemplazar en lo staged (excepto template)
for file in $(git diff --cached --name-only | grep -v ".env.template"); do
  if git show ":$file" 2>/dev/null | grep -q "CHANGEME_"; then
    echo -e "${RED}[pre-commit] ⚠️  '$file' tiene valores CHANGEME_ sin completar.${RESET}"
  fi
done

if [ "$BLOCKED" -eq 1 ]; then
  echo ""
  echo -e "${RED}${BOLD}Commit abortado. Para deshacer el staging:${RESET}"
  echo "   git reset HEAD <archivo>"
  echo ""
  exit 1
fi
exit 0
HOOK

chmod +x "$HOOK_FILE"
echo -e "${GREEN}✅ pre-commit hook instalado en ${HOOK_FILE}${RESET}"
echo -e "${YELLOW}Probalo con: git add .env && git commit -m 'test' (debería bloquearlo)${RESET}"
