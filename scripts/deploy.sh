#!/usr/bin/env bash
# =============================================================================
# Полный цикл развёртывания mTLS NGINX
# 1. Генерация сертификатов
# 2. Сборка и запуск Docker-контейнера
# 3. Тестирование
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  Развёртывание mTLS NGINX (полный цикл)${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Шаг 1: Генерация сертификатов
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[Шаг 1/4] Генерация сертификатов...${NC}"
if ls "$PROJECT_DIR/certs/"*.crt 1>/dev/null 2>&1; then
    echo -e "${YELLOW}  Сертификаты уже существуют. Пропускаем генерацию.${NC}"
    echo -e "${YELLOW}  Для перегенерации удалите папку certs/ и запустите снова.${NC}"
else
    bash "$SCRIPT_DIR/generate-certs.sh"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}  ОШИБКА: Не удалось сгенерировать сертификаты${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}  ✓ Сертификаты готовы${NC}"
echo ""

# -----------------------------------------------------------------------------
# Шаг 2: Сборка и запуск Docker
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[Шаг 2/4] Сборка и запуск Docker-контейнеров...${NC}"
cd "$PROJECT_DIR"

# Останавливаем старый контейнер, если есть
docker compose down 2>/dev/null || true

# Собираем и запускаем
docker compose up -d --build
if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ОШИБКА: Не удалось запустить Docker-контейнер${NC}"
    exit 1
fi

# Ждём, пока NGINX поднимется
echo -e "${YELLOW}  Ожидание запуска NGINX...${NC}"
for i in $(seq 1 15); do
    if docker exec nginx-mtls-server wget --no-check-certificate -q -O /dev/null https://localhost/ 2>/dev/null; then
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

# Проверяем, что контейнер действительно работает
if ! docker ps --format '{{.Names}}' | grep -q 'nginx-mtls-server'; then
    echo -e "${RED}  ОШИБКА: Контейнер не запущен${NC}"
    docker compose logs
    exit 1
fi

echo -e "${GREEN}  ✓ Контейнер nginx-mtls-server запущен${NC}"
echo ""

# -----------------------------------------------------------------------------
# Шаг 3: Тестирование NGINX из клиентского контейнера
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[Шаг 3/4] Тестирование NGINX mTLS...${NC}"
docker compose run --rm mtls-client-nginx
if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ОШИБКА: Тесты NGINX не пройдены${NC}"
    exit 1
fi
echo ""

# -----------------------------------------------------------------------------
# Шаг 4: Тестирование Envoy из клиентского контейнера
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[Шаг 4/4] Тестирование Envoy mTLS...${NC}"
docker compose run --rm mtls-client-envoy
if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ОШИБКА: Тесты Envoy не пройдены${NC}"
    exit 1
fi
echo ""

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  Развёртывание завершено!${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""
echo -e "  NGINX:           ${GREEN}https://localhost:7443${NC}"
echo -e "  Envoy:           ${GREEN}https://localhost:8443${NC}"
echo -e "  Envoy Admin:     ${GREEN}http://localhost:9901${NC}"
echo ""
echo -e "  Тесты NGINX:     ${YELLOW}docker compose run --rm mtls-client-nginx${NC}"
echo -e "  Тесты Envoy:     ${YELLOW}docker compose run --rm mtls-client-envoy${NC}"
echo -e "  Тесты (хост):    ${YELLOW}./scripts/test-mtls.sh${NC}"
echo -e "  Остановка:       ${YELLOW}docker compose down${NC}"
echo -e "  Логи NGINX:      ${YELLOW}docker compose logs -f nginx-mtls${NC}"
echo -e "  Логи Envoy:      ${YELLOW}docker compose logs -f envoy-mtls${NC}"
