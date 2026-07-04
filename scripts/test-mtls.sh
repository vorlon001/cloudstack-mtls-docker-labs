#!/usr/bin/env bash
# =============================================================================
# Скрипт тестирования mTLS для NGINX
# Проверяет 3 сценария: без сертификата, с клиентским сертификатом,
# и с полной проверкой цепочки
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/certs"
BASE_URL="https://localhost"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

print_header() {
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  Тестирование mTLS для NGINX${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
}

print_test_header() {
    echo ""
    echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
}

check_prerequisites() {
    # Проверяем, что сертификаты существуют
    if [[ ! -f "$CERTS_DIR/ca.crt" ]]; then
        echo -e "${RED}[ОШИБКА] Файл ca.crt не найден в $CERTS_DIR${NC}"
        echo -e "${YELLOW}Сначала запустите: ./scripts/generate-certs.sh${NC}"
        exit 1
    fi
    if [[ ! -f "$CERTS_DIR/client.crt" || ! -f "$CERTS_DIR/client.key" ]]; then
        echo -e "${RED}[ОШИБКА] Клиентские сертификаты не найдены в $CERTS_DIR${NC}"
        echo -e "${YELLOW}Сначала запустите: ./scripts/generate-certs.sh${NC}"
        exit 1
    fi

    # Проверяем, что curl доступен
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[ОШИБКА] curl не установлен${NC}"
        exit 1
    fi

    # Проверяем, что контейнер запущен
    if ! docker ps --format '{{.Names}}' | grep -q 'nginx-mtls-server'; then
        echo -e "${RED}[ОШИБКА] Контейнер nginx-mtls-server не запущен${NC}"
        echo -e "${YELLOW}Запустите: docker compose up -d${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Все предварительные проверки пройдены${NC}"
}

# =============================================================================
# ТЕСТ 1: Запрос БЕЗ клиентского сертификата (Должен быть ОТКЛОНЁН)
# =============================================================================
test_no_cert() {
    print_test_header "ТЕСТ 1: Запрос БЕЗ клиентского сертификата"
    echo -e "Команда: curl -k ${BASE_URL}"
    echo -e "Ожидание: отказ (400 Bad Request / SSL error)"
    echo ""

    RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "${BASE_URL}" 2>&1 || true)
    CURL_EXIT=$?

    if [[ $CURL_EXIT -ne 0 ]]; then
        # curl вернул ошибку (SSL handshake failure) — это ожидаемо
        echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: соединение отклонено (SSL error)${NC}"
        PASS=$((PASS + 1))
    elif [[ "$RESPONSE" == "400" ]]; then
        echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: сервер вернул 400 Bad Request${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: получен ответ с кодом $RESPONSE (ожидался отказ)${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# ТЕСТ 2: Запрос С КЛИЕНТСКИМ сертификатом (Должен пройти УСПЕШНО)
# =============================================================================
test_with_cert() {
    print_test_header "ТЕСТ 2: Запрос С клиентским сертификатом (режим -k)"
    echo -e "Команда: curl -k --cert $CERTS_DIR/client.crt --key $CERTS_DIR/client.key ${BASE_URL}"
    echo -e "Ожидание: mTLS Success! Welcome, CN=TestClient"
    echo ""

    RESPONSE=$(curl -k -s --max-time 5 \
        --cert "$CERTS_DIR/client.crt" \
        --key "$CERTS_DIR/client.key" \
        "${BASE_URL}" 2>&1)
    CURL_EXIT=$?

    if [[ $CURL_EXIT -ne 0 ]]; then
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: curl вернул ошибку: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    elif echo "$RESPONSE" | grep -q "mTLS Success"; then
        echo -e "Ответ сервера: ${GREEN}${RESPONSE}${NC}"
        echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: mTLS аутентификация успешна${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# ТЕСТ 3: Запрос с ПОЛНОЙ проверкой цепочки (самый строгий)
# =============================================================================
test_full_verify() {
    print_test_header "ТЕСТ 3: Запрос с полной проверкой цепочки (--cacert)"
    echo -e "Команда: curl --cacert $CERTS_DIR/ca.crt --cert $CERTS_DIR/client.crt --key $CERTS_DIR/client.key ${BASE_URL}"
    echo -e "Ожидание: mTLS Success! Welcome, CN=TestClient"
    echo ""

    RESPONSE=$(curl -s --max-time 5 \
        --cacert "$CERTS_DIR/ca.crt" \
        --cert "$CERTS_DIR/client.crt" \
        --key "$CERTS_DIR/client.key" \
        "${BASE_URL}" 2>&1)
    CURL_EXIT=$?

    if [[ $CURL_EXIT -ne 0 ]]; then
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: curl вернул ошибку: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    elif echo "$RESPONSE" | grep -q "mTLS Success"; then
        echo -e "Ответ сервера: ${GREEN}${RESPONSE}${NC}"
        echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: полная двусторонняя проверка TLS успешна${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# ТЕСТ 4: Health check эндпоинт
# =============================================================================
test_health() {
    print_test_header "ТЕСТ 4: Проверка health-эндпоинта (/health)"
    echo -e "Команда: curl -k --cert $CERTS_DIR/client.crt --key $CERTS_DIR/client.key ${BASE_URL}/health"
    echo -e "Ожидание: JSON со статусом ok"
    echo ""

    RESPONSE=$(curl -k -s --max-time 5 \
        --cert "$CERTS_DIR/client.crt" \
        --key "$CERTS_DIR/client.key" \
        "${BASE_URL}/health" 2>&1)
    CURL_EXIT=$?

    if [[ $CURL_EXIT -ne 0 ]]; then
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: curl вернул ошибку: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    elif echo "$RESPONSE" | grep -q '"status":"ok"'; then
        echo -e "Ответ сервера: ${GREEN}${RESPONSE}${NC}"
        echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: health check работает${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: $RESPONSE${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# Итоги
# =============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  ИТОГИ ТЕСТИРОВАНИЯ${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo -e "  Пройдено: ${GREEN}${PASS}${NC}"
    echo -e "  Провалено: ${RED}${FAIL}${NC}"
    echo ""

    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}🎉 Все тесты пройдены успешно!${NC}"
    else
        echo -e "${RED}❌ Некоторые тесты провалены.${NC}"
        exit 1
    fi
}

# =============================================================================
# Главная функция
# =============================================================================
main() {
    print_header
    check_prerequisites
    test_no_cert
    test_with_cert
    test_full_verify
    test_health
    print_summary
}

main
