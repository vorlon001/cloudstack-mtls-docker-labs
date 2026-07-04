#!/usr/bin/env bash
# =============================================================================
# Скрипт тестирования mTLS из клиентского контейнера
# Работает с NGINX и Envoy через переменную TARGET_SERVER
# =============================================================================

set -euo pipefail

SERVER="${TARGET_SERVER:-https://nginx-mtls-server}"
CERTS="/certs"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  mTLS-тестирование из клиентского контейнера${NC}"
echo -e "${CYAN}  Целевой сервер: ${SERVER}${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# Ждём, пока NGINX поднимется
echo -e "${YELLOW}Ожидание запуска NGINX...${NC}"
for i in $(seq 1 30); do
    if curl -k -s -o /dev/null -w "%{http_code}" --max-time 2 "${SERVER}/" 2>/dev/null | grep -qE '4[0-9]{2}'; then
        echo -e "${GREEN}NGINX готов${NC}"
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

# =============================================================================
# ТЕСТ 1: Запрос БЕЗ клиентского сертификата (Должен быть ОТКЛОНЁН)
# =============================================================================
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  ТЕСТ 1: Запрос БЕЗ клиентского сертификата${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"

RESPONSE=$(curl -k -s -o /tmp/test1_body.txt -w "%{http_code}" --max-time 5 "${SERVER}/" 2>&1 || true)

if echo "$RESPONSE" | grep -qE '4[0-9]{2}'; then
    echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: сервер вернул ${RESPONSE} (доступ без сертификата отклонён)${NC}"
    PASS=$((PASS + 1))
elif [[ "$RESPONSE" == "000" ]]; then
    echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: соединение отклонено (SSL handshake failure)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: получен ответ ${RESPONSE} (ожидался отказ)${NC}"
    cat /tmp/test1_body.txt 2>/dev/null
    FAIL=$((FAIL + 1))
fi

# =============================================================================
# ТЕСТ 2: Запрос С клиентским сертификатом (режим -k)
# =============================================================================
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  ТЕСТ 2: Запрос С клиентским сертификатом (-k)${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"

RESPONSE=$(curl -k -s --max-time 5 \
    --cert "${CERTS}/client.crt" \
    --key "${CERTS}/client.key" \
    "${SERVER}/" 2>&1)

if echo "$RESPONSE" | grep -q "mTLS Success"; then
    echo -e "Ответ: ${GREEN}${RESPONSE}${NC}"
    echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: mTLS аутентификация успешна${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: ${RESPONSE}${NC}"
    FAIL=$((FAIL + 1))
fi

# =============================================================================
# ТЕСТ 3: Запрос с ПОЛНОЙ проверкой цепочки (--cacert)
# =============================================================================
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  ТЕСТ 3: Полная проверка цепочки (--cacert)${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"

RESPONSE=$(curl -s --max-time 5 \
    --cacert "${CERTS}/ca.crt" \
    --cert "${CERTS}/client.crt" \
    --key "${CERTS}/client.key" \
    "${SERVER}/" 2>&1)

if echo "$RESPONSE" | grep -q "mTLS Success"; then
    echo -e "Ответ: ${GREEN}${RESPONSE}${NC}"
    echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: полная двусторонняя проверка TLS успешна${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: ${RESPONSE}${NC}"
    FAIL=$((FAIL + 1))
fi

# =============================================================================
# ТЕСТ 4: Health-эндпоинт
# =============================================================================
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  ТЕСТ 4: Health-эндпоинт (/health)${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────${NC}"

RESPONSE=$(curl -k -s --max-time 5 \
    --cert "${CERTS}/client.crt" \
    --key "${CERTS}/client.key" \
    "${SERVER}/health" 2>&1)

if echo "$RESPONSE" | grep -q '"status":"ok"'; then
    echo -e "Ответ: ${GREEN}${RESPONSE}${NC}"
    echo -e "${GREEN}✓ ТЕСТ ПРОЙДЕН: health check работает${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ ТЕСТ ПРОВАЛЕН: неожиданный ответ: ${RESPONSE}${NC}"
    FAIL=$((FAIL + 1))
fi

# =============================================================================
# Итоги
# =============================================================================
echo ""
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  ИТОГИ ТЕСТИРОВАНИЯ${NC}"
echo -e "${CYAN}=============================================${NC}"
echo -e "  Пройдено: ${GREEN}${PASS}${NC}"
echo -e "  Провалено: ${RED}${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}🎉 Все тесты пройдены успешно!${NC}"
    exit 0
else
    echo -e "${RED}❌ Некоторые тесты провалены.${NC}"
    exit 1
fi
