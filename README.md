# mTLS Demo: NGINX + Envoy + HAProxy

Демонстрационный проект Mutual TLS (mTLS) с различными прокси-серверами перед NGINX-backend.

## Архитектура

```
                          ┌─────────────────────────────────────────────┐
                          │              NGINX-backend (:443)           │
                          │   mTLS-сервер, проверяет клиентский cert   │
                          │   Поддерживает X-Client-* заголовки        │
                          └──────┬──────────┬──────────┬───────────────┘
                                 │          │          │
                    mTLS         │   mTLS   │   mTLS   │
                                 │          │          │
                          ┌──────┴──┐ ┌─────┴────┐ ┌───┴──────────┐
                          │ HAProxy │ │  NGINX   │ │   Envoy      │
                          │  :9443  │ │  :9444   │ │   :9445      │
                          └────┬────┘ └────┬─────┘ └───┬──────────┘
                               │           │           │
                          ┌────┴───────────┴───────────┴────┐
                          │         Клиент (curl)            │
                          │   --cert client.crt              │
                          │   --key  client.key              │
                          └──────────────────────────────────┘

  Также доступны standalone-серверы без проксирования:
  ┌─────────────────┐  ┌─────────────────┐
  │  NGINX :7443    │  │  Envoy :8443    │
  │  (прямой mTLS)  │  │  (прямой mTLS)  │
  └─────────────────┘  └─────────────────┘
```

## Сервисы

| Сервис | Контейнер | Порт | Описание |
|--------|-----------|------|----------|
| **nginx-mtls** | nginx-mtls-server | 7443 | NGINX-backend с mTLS (прямой доступ) |
| **envoy-mtls** | envoy-mtls-server | 8443, 9901 | Envoy standalone с mTLS + Lua |
| **haproxy-mtls-proxy** | haproxy-mtls-proxy | 9443, 8404 | HAProxy → NGINX mTLS-прокси |
| **nginx-mtls-proxy** | nginx-mtls-proxy | 9444 | NGINX → NGINX mTLS-прокси |
| **envoy-mtls-proxy** | envoy-mtls-proxy | 9445, 9902 | Envoy → NGINX mTLS-прокси |

## Структура проекта

```
nginx-mtls/
├── certs/                        # Сертификаты (генерируются скриптом)
│   ├── ca.crt                    #   CA-сертификат
│   ├── server.crt / server.key   #   Серверный сертификат
│   └── client.crt / client.key   #   Клиентский сертификат
├── conf/
│   └── nginx.conf                # Конфигурация NGINX-backend
├── envoy/
│   ├── envoy.yaml                # Конфигурация Envoy standalone
│   ├── Dockerfile                # Docker-образ Envoy
│   └── entrypoint.sh             # Конвертация PKCS#1→PKCS#8, запуск
├── haproxy/
│   ├── haproxy.cfg               # Конфигурация HAProxy-прокси
│   ├── Dockerfile                # Docker-образ HAProxy
│   └── entrypoint.sh             # Сборка PEM-файлов, запуск
├── nginx-proxy/
│   ├── nginx-proxy.conf          # Конфигурация NGINX-прокси
│   └── Dockerfile                # Docker-образ NGINX-прокси
├── envoy-proxy/
│   ├── envoy-proxy.yaml          # Конфигурация Envoy-прокси
│   ├── Dockerfile                # Docker-образ Envoy-прокси
│   └── entrypoint.sh             # Конвертация ключей, запуск
├── client/
│   ├── Dockerfile                # Docker-образ клиента (alpine + curl)
│   └── test.sh                   # Скрипт автоматического тестирования
├── scripts/
│   ├── generate-certs.sh         # Генерация сертификатов
│   ├── deploy.sh                 # Деплой
│   └── test-mtls.sh              # Ручное тестирование
├── docker-compose.yml            # Оркестрация всех сервисов
└── Dockerfile                    # Docker-образ NGINX-backend
```

## Быстрый старт

### 1. Генерация сертификатов

```bash
cd nginx-mtls
./scripts/generate-certs.sh
```

### 2. Запуск всех сервисов

```bash
docker compose up -d --build
```

### 3. Тестирование

```bash
# Прямой доступ к NGINX
curl -k --cert certs/client.crt --key certs/client.key https://localhost:7443/

# Прямой доступ к Envoy
curl -k --cert certs/client.crt --key certs/client.key https://localhost:8443/

# Через HAProxy-прокси
curl -k --cert certs/client.crt --key certs/client.key https://localhost:9443/

# Через NGINX-прокси
curl -k --cert certs/client.crt --key certs/client.key https://localhost:9444/

# Через Envoy-прокси
curl -k --cert certs/client.crt --key certs/client.key https://localhost:9445/
```

### 4. Автоматические тесты

```bash
# Тест NGINX (прямой)
docker compose run --rm mtls-client-nginx

# Тест Envoy (прямой)
docker compose run --rm mtls-client-envoy

# Тест HAProxy-прокси
docker compose run --rm mtls-client-haproxy

# Тест NGINX-прокси
docker compose run --rm mtls-client-nginx-proxy

# Тест Envoy-прокси
docker compose run --rm mtls-client-envoy-proxy
```

## Эндпоинты

Каждый сервис поддерживает одинаковые эндпоинты:

| Путь | Описание |
|------|----------|
| `/` | Приветствие с DN клиента |
| `/health` | JSON-статус с DN клиента |
| `/cert-info` | Полная информация о клиентском сертификате |

Пример ответа `/cert-info`:
```json
{
  "client_dn": "CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU",
  "client_fingerprint": "A1:B2:C3:D4:...",
  "client_serial": "01",
  "client_v_start": "Jan  1 00:00:00 2025 GMT",
  "client_v_end": "Dec 31 23:59:59 2026 GMT",
  "ssl_protocol": "TLSv1.3",
  "ssl_cipher": "TLS_AES_256_GCM_SHA384"
}
```

## Схемы проксирования

### HAProxy → NGINX (порт 9443)

```
Клиент --mTLS--> HAProxy:9443 --mTLS--> NGINX:443
```

- HAProxy терминирует mTLS, проверяет клиентский сертификат
- Проксирует на NGINX по mTLS с клиентским сертификатом
- Передаёт cert-info в заголовках `X-Client-*`
- PEM-файлы собираются из cert+key в entrypoint.sh
- Stats-панель: http://localhost:8404/stats

### NGINX → NGINX (порт 9444)

```
Клиент --mTLS--> NGINX-proxy:9444 --mTLS--> NGINX:443
```

- NGINX-proxy терминирует mTLS, проверяет клиентский сертификат
- Использует `proxy_ssl_certificate` для mTLS к backend
- `proxy_ssl_name nginx-mtls-server` для верификации CN сертификата
- Передаёт cert-info через `proxy_set_header X-Client-*`

### Envoy → NGINX (порт 9445)

```
Клиент --mTLS--> Envoy-proxy:9445 --mTLS--> NGINX:443
```

- Envoy терминирует mTLS (`DownstreamTlsContext` + `require_client_certificate`)
- Upstream mTLS через `UpstreamTlsContext` с `sni: nginx-mtls-server`
- Lua-фильтр извлекает cert-info через `connection():ssl()` + `streamInfo():getProperty()`
- Добавляет заголовки `X-Client-*` к запросу на backend
- Admin UI: http://localhost:9902

## Передача cert-info через прокси

Все прокси передают информацию о клиентском сертификате в заголовках:

| Заголовок | Описание | NGINX-переменная |
|-----------|----------|------------------|
| `X-Client-DN` | Subject DN клиента | `$ssl_client_s_dn` |
| `X-Client-Serial` | Серийный номер | `$ssl_client_serial` |
| `X-Client-Fingerprint` | SHA1 fingerprint | `$ssl_client_fingerprint` |
| `X-Client-Cert-NotBefore` | Дата начала | `$ssl_client_v_start` |
| `X-Client-Cert-NotAfter` | Дата окончания | `$ssl_client_v_end` |
| `X-TLS-Version` | Версия TLS | `$ssl_protocol` |
| `X-TLS-Cipher` | Шифр | `$ssl_cipher` |

NGINX-backend использует приоритет: заголовки `X-Client-*` от прокси > прямые `$ssl_client_*`.

## Проверка без сертификата

```bash
# Должен быть отклонён (400 или SSL handshake failure)
curl -k https://localhost:7443/
```

## Остановка

```bash
docker compose down
```

Для полной очистки (включая volumes):

```bash
docker compose down -v
```

## Полезные команды

```bash
# Логи конкретного сервиса
docker compose logs -f nginx-mtls
docker compose logs -f haproxy-mtls-proxy
docker compose logs -f envoy-mtls-proxy

# Перезапуск отдельного сервиса
docker compose up -d --build --force-recreate haproxy-mtls-proxy

# Проверка сертификата сервера
openssl s_client -connect localhost:7443 -cert certs/client.crt -key certs/client.key

# Проверка сертификата через прокси
openssl s_client -connect localhost:9443 -cert certs/client.crt -key certs/client.key
```
