# 1. Show the structure first
echo "===== PROJECT STRUCTURE ====="
tree -a -I '.git|venv|.venv|__pycache__|*.pyc|node_modules' -L 5 2>/dev/null || find . -type d | head -60

echo -e "\n\n===== RELEVANT FILE CONTENTS ====="

# 2. Dump content of all interesting files
find . -type f \( \
  -name "*.yml" -o -name "*.yaml" -o -name "*.j2" -o \
  -name "*.ini" -o -name "*.cfg" -o -name "Dockerfile*" -o \
  -name "docker-compose*" -o -name "*.conf" -o \
  -name "requirements*.txt" -o -name "*.env.example" -o \
  -name "Makefile" -o -name "*.sh" \
\) \
-not -path '*/.git/*' \
-not -path '*/venv/*' \
-not -path '*/.venv/*' \
-not -path '*/__pycache__/*' \
-not -name "*vault*" \
-not -name "*secret*" \
-not -name "*.key" \
-not -name "id_*" \
| sort | while read -r f; do
  echo -e "\n\n########## FILE: $f ##########\n"
  cat "$f"
done