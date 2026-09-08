#!/bin/sh
set -eu
export PORT="${PORT:-8080}"
export API_URL="${API_URL:-http://localhost:8080}"

cat > /usr/share/nginx/html/config.js <<EOF
window.APP_CONFIG = { apiUrl: "${API_URL}" };
EOF

exec /docker-entrypoint.sh nginx -g "daemon off;"
