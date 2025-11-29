# 🦑 squid-proxy-gateway

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Squid](https://img.shields.io/badge/Squid-6.x-blue?logo=squid&logoColor=white)](http://www.squid-cache.org/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> Свой прокси-сервер за 1 минуту. Обходи geo-ограничения API и работай откуда угодно. 

--

## 🎯 Зачем это нужно

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
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/squid-proxy-gateway/main/install.sh | sudo bash
```

Или скачай и запусти:

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/squid-proxy-gateway/main/install.sh
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

```bash
ufw allow 3128/tcp
```

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

---

## ✅ Проверка

```bash
# Проверить свой IP через прокси
HTTPS_PROXY="http://proxyuser:PASSWORD@IP_СЕРВЕРА:3128" curl https://ifconfig.me
```

Должен показать IP голландского сервера.

---

## 🔧 Troubleshooting

```bash
# Логи на сервере
tail -f /var/log/squid/access.log

# Статус
systemctl status squid

# Проверить конфиг
squid -k parse
```

---

## 📄 License

MIT © 2024

---

<p align="center">
  <sub>⭐ Star this repo if it helped you!</sub>
</p>
