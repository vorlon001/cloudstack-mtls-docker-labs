# Постановка задачи: Развёртывание mTLS в NGINX через Docker

## Описание

Создать полноценное развёртывание Mutual TLS (mTLS) в NGINX через Docker. Создать собственный Центр Сертификации (CA), выпустить все необходимые ключи, упаковать NGINX в контейнер и проверить работу с помощью curl.

---

## Требования

### 1. Подготовка структуры проекта
- Создать рабочую директорию `nginx-mtls` с подпапками `certs` и `conf`

### 2. Генерация сертификатов через OpenSSL
Создать скрипт генерации, который последовательно выполняет:

1. **Root CA** (собственный удостоверяющий центр):
   - `openssl genrsa -out ca.key 4096`
   - `openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=My-Root-CA"`

2. **Сертификат для СЕРВЕРА (NGINX)**:
   - `openssl genrsa -out server.key 2048`
   - `openssl req -new -key server.key -out server.csr -subj "/CN=localhost"`
   - Подписать серверный сертификат нашим CA

3. **Сертификат для КЛИЕНТА (curl / браузер)**:
   - `openssl genrsa -out client.key 2048`
   - `openssl req -new -key client.key -out client.csr -subj "/CN=TestClient"`
   - Подписать клиентский сертификат нашим CA

```


docker exec -it nginx-mtls-proxy curl --cacert /etc/nginx/certs/ca.crt  --cert /etc/nginx/certs/client.crt --key /etc/nginx/certs/client.key https://nginx-mtls-server:443
curl --cacert certs/ca.crt --cert certs/client.crt --key certs/client.key https://localhost:19443  -v  && echo
curl --cacert certs/ca.crt --cert certs/client.crt --key certs/client.key https://localhost:19444  -v  && echo
curl --cacert certs/ca.crt --cert certs/client.crt --key certs/client.key https://localhost:9445  -v  && echo


172.31.2.7 - [04/Jul/2026:13:08:16 +0000] "GET / HTTP/1.1" 200 75 client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" client_fingerprint="fc1cf53c7fd4cd3eb89751939a7c3748bcc85e0e" client_serial="6FE694576201D581F3C7B5FB569F510527CDB3B1" client_v_start="Jul  4 12:37:05 2026 GMT" client_v_end="Jul  4 12:37:05 2027 GMT" client_v_remain="364" ssl_protocol="TLSv1.3" ssl_cipher="TLS_AES_256_GCM_SHA384" x_client_dn="/C=RU/ST=Moscow/L=Moscow/O=TestClient/CN=TestClient" x_client_serial="o\xE6\x94Wb%01\xD5\x81\xF3\xC7\xB5\xFBV\x9FQ%05'\xCD\xB3\xB1" x_client_fingerprint="J\xDEa\xFD\x09%17\xA4\xC2\xA3\xEF\xD3\xA1\xD6\xF7\xE0\x96wzV\x80" x_client_cert_notbefore="260704123705Z" x_client_cert_notafter="270704123705Z" x_tls_version="TLSv1.3" x_tls_cipher="TLS_AES_256_GCM_SHA384" x_client_verify="0"
172.31.2.5 - [04/Jul/2026:13:08:16 +0000] "GET / HTTP/1.1" 200 74 client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" client_fingerprint="fc1cf53c7fd4cd3eb89751939a7c3748bcc85e0e" client_serial="6FE694576201D581F3C7B5FB569F510527CDB3B1" client_v_start="Jul  4 12:37:05 2026 GMT" client_v_end="Jul  4 12:37:05 2027 GMT" client_v_remain="364" ssl_protocol="TLSv1.3" ssl_cipher="TLS_AES_256_GCM_SHA384" x_client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" x_client_serial="6FE694576201D581F3C7B5FB569F510527CDB3B1" x_client_fingerprint="fc1cf53c7fd4cd3eb89751939a7c3748bcc85e0e" x_client_cert_notbefore="Jul  4 12:37:05 2026 GMT" x_client_cert_notafter="Jul  4 12:37:05 2027 GMT" x_tls_version="TLSv1.3" x_tls_cipher="TLS_AES_256_GCM_SHA384" x_client_verify="SUCCESS"
172.31.2.8 - [04/Jul/2026:13:08:16 +0000] "GET / HTTP/1.1" 200 74 client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" client_fingerprint="fc1cf53c7fd4cd3eb89751939a7c3748bcc85e0e" client_serial="6FE694576201D581F3C7B5FB569F510527CDB3B1" client_v_start="Jul  4 12:37:05 2026 GMT" client_v_end="Jul  4 12:37:05 2027 GMT" client_v_remain="364" ssl_protocol="TLSv1.3" ssl_cipher="TLS_AES_256_GCM_SHA384" x_client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" x_client_serial="" x_client_fingerprint="" x_client_cert_notbefore="" x_client_cert_notafter="" x_tls_version="TLSv1.3" x_tls_cipher="TLS_AES_256_GCM_SHA384" x_client_verify="-"
172.31.2.7 - [04/Jul/2026:13:08:44 +0000] "GET / HTTP/1.1" 200 75 client_dn="CN=TestClient,O=TestClient,L=Moscow,ST=Moscow,C=RU" client_fingerprint="fc1cf53c7fd4cd3eb89751939a7c3748bcc85e0e" client_serial="6FE694576201D581F3C7B5FB569F510527CDB3B1" client_v_start="Jul  4 12:37:05 2026 GMT" client_v_end="Jul  4 12:37:05 2027 GMT" client_v_remain="364" ssl_protocol="TLSv1.3" ssl_cipher="TLS_AES_256_GCM_SHA384" x_client_dn="/C=RU/ST=Moscow/L=Moscow/O=TestClient/CN=TestClient" x_client_serial="o\xE6\x94Wb%01\xD5\x81\xF3\xC7\xB5\xFBV\x9FQ%05'\xCD\xB3\xB1" x_client_fingerprint="J\xDEa\xFD\x09%17\xA4\xC2\xA3\xEF\xD3\xA1\xD6\xF7\xE0\x96wzV\x80" x_client_cert_notbefore="260704123705Z" x_client_cert_notafter="270704123705Z" x_tls_version="TLSv1.3" x_tls_cipher="TLS_AES_256_GCM_SHA384" x_client_verify="0"


```

### 3. Конфигурация NGINX
Создать `conf/nginx.conf` со следующими настройками:

```nginx
events {
    worker_connections 1024;
}

http {
    server {
        listen 443 ssl;
        server_name localhost;

        # Сертификаты сервера NGINX
        ssl_certificate     /etc/nginx/certs/server.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;

        # Настройки mTLS для проверки клиентов
        ssl_client_certificate /etc/nginx/certs/ca.crt;
        ssl_verify_client      on;
        ssl_verify_depth       1;

        location / {
            default_type text/plain;
            return 200 "mTLS Success! Welcome, $ssl_client_s_dn\n";
        }
    }
}
```

### 4. Запуск NGINX в Docker
- Создать `Dockerfile` на базе `nginx:alpine`
- Создать `docker-compose.yml` для запуска с примонтированными конфигурацией и сертификатами
- Контейнер должен слушать порт 443

### 5. Команды проверки работоспособности

**Тест 1: Запрос БЕЗ клиентского сертификата (Должен быть отклонён)**
```bash
curl -k https://localhost
```
- Ожидаемый результат: SSL error или 400 Bad Request / No required SSL certificate was sent

**Тест 2: Запрос С КЛИЕНТСКИМ сертификатом (Должен пройти успешно)**
```bash
curl -k --cert certs/client.crt --key certs/client.key https://localhost
```
- Ожидаемый результат: `mTLS Success! Welcome, CN=TestClient`

**Тест 3: Запрос с полной проверкой (самый строгий и правильный)**
```bash
curl --cacert certs/ca.crt --cert certs/client.crt --key certs/client.key https://localhost
```
- Ожидаемый результат: `mTLS Success! Welcome, CN=TestClient`

---

## Состав поставки

| Компонент | Файл | Назначение |
|-----------|------|------------|
| Скрипт генерации сертификатов | `scripts/generate-certs.sh` | Создание CA, серверных и клиентских сертификатов |
| Конфигурация NGINX | `conf/nginx.conf` | Настройка mTLS на стороне сервера |
| Dockerfile | `Dockerfile` | Сборка образа NGINX |
| Docker Compose | `docker-compose.yml` | Оркестрация контейнера |
| Скрипт тестирования | `scripts/test-mtls.sh` | Автоматическая проверка всех сценариев mTLS |
| Скрипт развёртывания | `scripts/deploy.sh` | Полный цикл: генерация → сборка → тесты |

---

## Возможные расширения (не входят в текущую задачу)

- Упаковать генерацию ключей и запуск в один docker-compose файл
- Отзыв сертификатов через CRL (Certificate Revocation List)
- Настройка выпуска клиентского сертификата в формате .p12 / .pfx для импорта в браузер
