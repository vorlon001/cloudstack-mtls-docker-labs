#!/usr/bin/env bash
# =============================================================================
# Скрипт генерации сертификатов для mTLS
# Создаёт: Root CA, серверный сертификат, клиентский сертификат
# Все сертификаты содержат корректные X509v3 расширения
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/certs"

echo "============================================="
echo "  Генерация сертификатов для mTLS"
echo "============================================="
echo "Папка сертификатов: $CERTS_DIR"
echo ""

# Создаём папку, если не существует
mkdir -p "$CERTS_DIR"

# Очищаем старые сертификаты, если есть
shopt -s nullglob
OLD_FILES=("$CERTS_DIR"/*.{key,crt,csr,srl,p12,cnf})
if [[ ${#OLD_FILES[@]} -gt 0 ]]; then
    echo "[!] Найдены старые сертификаты. Удаляем..."
    rm -f "${OLD_FILES[@]}"
    echo "    Старые сертификаты удалены."
    echo ""
fi
shopt -u nullglob

# =============================================================================
# Конфигурационные файлы расширений OpenSSL
# =============================================================================

# --- Расширения для Root CA ---
cat > "$CERTS_DIR/ca.cnf" <<'EOF'
[ req ]
distinguished_name = req_dn
x509_extensions = v3_ca
prompt = no

[ req_dn ]
C  = RU
ST = Moscow
L  = Moscow
O  = My-Root-CA
CN = My-Root-CA

[ v3_ca ]
basicConstraints       = critical, CA:TRUE
keyUsage               = critical, keyCertSign, cRLSign
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always, issuer
EOF

# --- Расширения для серверного сертификата ---
cat > "$CERTS_DIR/server.cnf" <<'EOF'
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName         = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = nginx-mtls-server
DNS.3 = envoy-mtls-server
IP.1  = 127.0.0.1
IP.2  = ::1
EOF

# --- Расширения для клиентского сертификата ---
cat > "$CERTS_DIR/client.cnf" <<'EOF'
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature
extendedKeyUsage       = clientAuth
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
EOF

# =============================================================================
# 1. Создаём Root CA (Наш собственный удостоверяющий центр)
# =============================================================================
echo "[1/6] Генерация закрытого ключа Root CA (ca.key)..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$CERTS_DIR/ca.key"
echo "      ✓ ca.key создан (PKCS#8)"

echo "[2/6] Создание самоподписанного сертификата Root CA (ca.crt)..."
openssl req -new -x509 -days 3650 \
    -key "$CERTS_DIR/ca.key" \
    -out "$CERTS_DIR/ca.crt" \
    -config "$CERTS_DIR/ca.cnf"
echo "      ✓ ca.crt создан (действителен 10 лет)"
echo "      ✓ X509v3: CA:TRUE, keyCertSign, cRLSign"
echo ""

# =============================================================================
# 2. Создаём сертификат для СЕРВЕРА (NGINX)
# =============================================================================
echo "[3/6] Генерация закрытого ключа сервера (server.key) и CSR..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$CERTS_DIR/server.key"
openssl req -new \
    -key "$CERTS_DIR/server.key" \
    -out "$CERTS_DIR/server.csr" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=MyServer/CN=localhost"
echo "      ✓ server.key (PKCS#8) и server.csr созданы"

echo "[4/6] Подписываем серверный сертификат нашим CA..."
openssl x509 -req -days 365 \
    -in "$CERTS_DIR/server.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/server.crt" \
    -extfile "$CERTS_DIR/server.cnf"
echo "      ✓ server.crt создан (действителен 1 год)"
echo "      ✓ X509v3: serverAuth, digitalSignature, keyEncipherment, SAN"
echo ""

# =============================================================================
# 3. Создаём сертификат для КЛИЕНТА (curl / браузер)
# =============================================================================
echo "[5/6] Генерация закрытого ключа клиента (client.key) и CSR..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$CERTS_DIR/client.key"
openssl req -new \
    -key "$CERTS_DIR/client.key" \
    -out "$CERTS_DIR/client.csr" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=TestClient/CN=TestClient"
echo "      ✓ client.key (PKCS#8) и client.csr созданы"

echo "[6/6] Подписываем клиентский сертификат нашим CA..."
openssl x509 -req -days 365 \
    -in "$CERTS_DIR/client.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/client.crt" \
    -extfile "$CERTS_DIR/client.cnf"
echo "      ✓ client.crt создан (действителен 1 год)"
echo "      ✓ X509v3: clientAuth, digitalSignature"
echo ""

# =============================================================================
# 4. (Бонус) Создаём .p12 для импорта в браузер
# =============================================================================
echo "[*] Создание PKCS#12 хранилища для браузера (client.p12)..."
openssl pkcs12 -export \
    -out "$CERTS_DIR/client.p12" \
    -inkey "$CERTS_DIR/client.key" \
    -in "$CERTS_DIR/client.crt" \
    -certfile "$CERTS_DIR/ca.crt" \
    -passout pass:changeit
echo "      ✓ client.p12 создан (пароль: changeit)"
echo ""

# =============================================================================
# Проверка сертификатов
# =============================================================================
echo "============================================="
echo "  Проверка X509v3 расширений"
echo "============================================="
echo ""

echo "--- Root CA ---"
openssl x509 -in "$CERTS_DIR/ca.crt" -noout -text | grep -A2 "X509v3 extensions" | head -5
echo ""

echo "--- Server Certificate ---"
openssl x509 -in "$CERTS_DIR/server.crt" -noout -text | grep -A5 "X509v3 extensions" | head -8
echo ""

echo "--- Client Certificate ---"
openssl x509 -in "$CERTS_DIR/client.crt" -noout -text | grep -A4 "X509v3 extensions" | head -6
echo ""

# =============================================================================
# Итог
# =============================================================================
echo "============================================="
echo "  Все сертификаты успешно сгенерированы!"
echo "============================================="
echo ""
echo "Файлы в $CERTS_DIR/:"
echo "  ca.key        — закрытый ключ Root CA (ХРАНИТЬ В СЕКРЕТЕ!)"
echo "  ca.crt        — сертификат Root CA (CA:TRUE, keyCertSign, cRLSign)"
echo "  server.key    — закрытый ключ сервера"
echo "  server.crt    — сертификат сервера (serverAuth, SAN)"
echo "  client.key    — закрытый ключ клиента"
echo "  client.crt    — сертификат клиента (clientAuth, digitalSignature)"
echo "  client.p12    — PKCS#12 для импорта в браузер (пароль: changeit)"
echo ""
echo "Теперь запустите: docker compose up -d --build"
