<p align="left">
  <img src="./logo.png" alt="squid.sh" width="400">
</p>

# 🦑 squid-proxy-gateway

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Squid](https://img.shields.io/badge/Squid-6.x-blue?logo=squid&logoColor=white)](http://www.squid-cache.org/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> Свой прокси-сервер за 1 минуту. Обходи geo-ограничения API и работай откуда угодно. 

## Зачем это нужно

**Проблема:** Многие AI-сервисы (Claude API, OpenAI, Midjourney и др.) недоступны из определённых регионов. VPN на весь сервер — оверкилл и дорого.

**Решение:** Поднимаешь Squid на VPS в нужной стране (Нидерланды, Германия, США) и проксируешь только нужные запросы. Дёшево, быстро, надёжно.

### Когда пригодится

- 🤖 **AI API** — Claude, OpenAI, Anthropic, Gemini с серверов в заблокированных регионах (Работа с агентов внутри сервера)
- 🛠️ **CI/CD** — GitHub Actions, GitLab runners с доступом к geo-ограниченным ресурсам  
- 🔒 **Приватность** — скрыть реальный IP сервера при исходящих запросах
- 🌍 **Любые API** — всё что блокируется по географии

### Как это работает

```
[Твой сервер] → [Squid Proxy в NL/DE/US] → [Claude API / любой сервис]
      ↑                    ↑
   Россия/СНГ        Нидерланды
(заблокировано)     (доступ есть)
```

Одна переменная окружения — и все запросы идут через прокси:

```bash
export HTTPS_PROXY="http://user:pass@proxy-ip:3128"
```

---

## 📋 Содержание

- [Зачем это нужно](#-зачем-это-нужно)
- [Требования](#-требования)
- [Быстрая установка](#-быстрая-установка)
- [Ручная установка](#️-ручная-установка)
- [🔒 Защита прокси (важно!)](#-защита-прокси-важно)
- [Настройка клиента](#-клиент)
- [Проверка](#-проверка)
- [Troubleshooting](#-troubleshooting)

---

## 📦 Требования

- VPS с Ubuntu 20.04+ (Голландия, Германия, США — где API доступен)
- Root доступ
- Открытый порт 3128

---

## ⚡ Быстрая установка

```bash
curl -fsSL https://raw.githubusercontent.com/kitay-sudo/squid-proxy-gateway/main/install.sh | sudo bash
```

Или скачай и запусти:

```bash
wget https://raw.githubusercontent.com/kitay-sudo/squid-proxy-gateway/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

Скрипт спросит логин, пароль и порт — всё остальное сделает сам.

---

## 🖥️ Ручная установка

### 1. Установка

```bash
apt update && apt install squid apache2-utils -y
```

### 2. Создание пользователя

```bash
htpasswd -c /etc/squid/passwords proxyuser
# Введи пароль когда попросит
```

### 3. Конфигурация

```bash
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup
cat > /etc/squid/squid.conf << 'EOF'
# Порт
http_port 3128

# Аутентификация
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED

# Разрешения
http_access allow authenticated
http_access deny all

# Скрыть информацию о прокси
forwarded_for off
request_header_access Via deny all
request_header_access X-Forwarded-For deny all

# Логи (опционально отключить)
# access_log none
EOF
```

### 4. Запуск

```bash
systemctl restart squid
systemctl enable squid
```

### 5. Firewall

> ⚠️ **Не открывай 3128 всему интернету.** Даже с паролем — это мишень для брутфорса и ботов. Разрешай только те IP, с которых реально ходишь.

```bash
# ВАЖНО: сначала разреши SSH, иначе вылетишь с сервера
ufw allow 22/tcp

# разрешить прокси ТОЛЬКО с твоего клиентского IP
ufw allow from TWOЙ_КЛИЕНТСКИЙ_IP to any port 3128 proto tcp

ufw enable
ufw status
```

Если `ufw` уже включён и в нём висит публичное правило `3128/tcp ALLOW Anywhere` — удали его:

```bash
ufw status numbered
ufw delete <номер>             # и v4, и v6 правила
ufw reload
```

Итоговый `ufw status` должен показать:

```
3128/tcp                   ALLOW       TWOЙ_КЛИЕНТСКИЙ_IP
```

Строк `3128/tcp ... Anywhere` быть не должно.

---

## 🔒 Защита прокси (важно!)

Прокси по умолчанию защищён только логином/паролем — этого мало. Прикрой двумя слоями сразу (defense in depth):

### Слой 1 — IP-whitelist внутри Squid

Открой конфиг:
```bash
nano /etc/squid/squid.conf
```

Найди блок:
```
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
```

И замени на:
```
acl authenticated proxy_auth REQUIRED
acl allowed_clients src TWOЙ_КЛИЕНТСКИЙ_IP/32

http_access allow authenticated allowed_clients
http_access deny all
```

Для нескольких клиентов:
```
acl allowed_clients src 1.2.3.4/32 5.6.7.8/32
```

Перезапуск:
```bash
systemctl restart squid
systemctl status squid --no-pager -l
```

### Слой 2 — фаервол (см. пункт 5 выше)

Фаервол дропает пакеты от чужих до того, как они дойдут до Squid — в логах не будет мусора от ботов, и ресурсы сервера не тратятся на авторизационный диалог.

### Почему нужны оба слоя

- Только ACL в Squid — TCP-коннект всё равно устанавливается, Squid тратит CPU, логи забиваются сканами.
- Только фаервол — если в нём ошибка или он выключится (reboot, апдейт пакета), прокси откроется без защиты.
- Оба вместе — чтобы пробить, надо ошибиться в обоих местах.

### Проверка защиты

**С разрешённого клиента:**
```bash
curl -v --max-time 10 -x http://user:pass@PROXY_IP:3128 https://api.telegram.org/
```
Должен вернуть `HTTP/2` или `302` — трафик идёт.

**С любой другой машины:**
```bash
curl -v --max-time 5 -x http://user:pass@PROXY_IP:3128 https://api.telegram.org/
```
Должен **зависнуть до таймаута** (`Connection timed out`). Если вместо этого видишь `Connection refused` или ответ от прокси — защита настроена неправильно.

### Бонус: cloud firewall у провайдера

Hetzner / DO / Vultr имеют Security Group в панели. Продублируй там правило «разрешить 3128 только от TWOЙ_КЛИЕНТСКИЙ_IP». Это защитит даже если `ufw` случайно выключится.

---

## 💻 Клиент

### Вариант 1: Переменные окружения

```bash
export HTTP_PROXY="http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128"
export HTTPS_PROXY="http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128"
```

Для постоянного использования добавь в `~/.bashrc` или `/etc/environment`.

### Вариант 2: Только для одной команды

```bash
HTTPS_PROXY="http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128" curl https://api.anthropic.com/v1/messages
```

### Вариант 3: В коде Python

```python
import os
os.environ["HTTPS_PROXY"] = "http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128"

# или в requests
import requests
proxies = {
    "https": "http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128"
}
response = requests.post(url, proxies=proxies)
```

### Вариант 4: В коде Node.js (axios + https-proxy-agent)

```bash
pnpm add https-proxy-agent
```

```ts
import axios from 'axios';
import { HttpsProxyAgent } from 'https-proxy-agent';

const agent = new HttpsProxyAgent('http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128');

await axios.post(
  'https://api.telegram.org/botTOKEN/sendMessage',
  { chat_id: CHAT_ID, text: 'hello' },
  {
    timeout: 10_000,
    httpAgent: agent,
    httpsAgent: agent,
    proxy: false, // важно: иначе axios попытается использовать свой встроенный прокси
  },
);
```

---

## ✅ Проверка

```bash
# Проверить свой IP через прокси
HTTPS_PROXY="http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128" curl https://ifconfig.me
```

Должен показать IP голландского сервера.

---

## Troubleshooting

### Диагностика

```bash
# Логи на сервере
tail -f /var/log/squid/access.log

# Статус
systemctl status squid --no-pager -l

# Проверить конфиг на ошибки
squid -k parse

# Слушает ли порт
ss -tlnp | grep 3128

# Что видит фаервол
ufw status
```

### Частые проблемы

**`Connection timed out` с клиента**
IP клиента не добавлен в `ufw` или в `acl allowed_clients`. Проверь оба. Не забывай: если клиент за NAT — нужно whitelist'ить внешний IP, не внутренний.

**`407 Proxy Authentication Required`**
Логин/пароль неверны, либо файл `/etc/squid/passwords` недоступен процессу `squid`. Проверь права:
```bash
ls -l /etc/squid/passwords
chown proxy: /etc/squid/passwords
chmod 640 /etc/squid/passwords
```

**`403 Forbidden` через прокси**
ACL отверг запрос. Чаще всего — IP клиента не входит в `allowed_clients`. Смотри `/var/log/squid/access.log` — там видно причину (`TCP_DENIED`).

**После `ufw enable` потерял SSH**
Классика. Если до включения `ufw` не было правила `ufw allow 22/tcp` — SSH рубится. Жди рестарта VPS через панель провайдера или serial-консоль.

**Публичное правило `3128/tcp Anywhere` не удаляется одной командой**
Удали и v4, и v6 отдельно:
```bash
ufw status numbered
ufw delete <номер v4>
ufw delete <номер v6>
```

**ETIMEDOUT на клиенте, хотя прокси отвечает**
У axios без явного `httpAgent`/`httpsAgent` через переменные окружения бывает double-proxy. Добавь `proxy: false` в axios config (см. Node.js-пример выше).

---

## 📄 License

MIT © 2025

<p align="center">
  <sub>⭐ Поставь звезду, если пригодилось!</sub>
</p>
