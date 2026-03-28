# 🧭 PathMentor

> Tu mentor de carrera en tech para latinoamericanos

[![Demo](https://img.shields.io/badge/Demo-Live-38bdf8?style=for-the-badge)](http://194.26.100.223)
[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-Live-22c55e?style=for-the-badge)](https://Rodcolca.github.io/Pathmentor/)

## 🌎 Demo en vivo
👉 **[http://194.26.100.223](http://194.26.100.223)**

## 💡 ¿Qué es PathMentor?

PathMentor es un asistente de inteligencia artificial especializado en ayudar a 
jóvenes latinoamericanos a entrar al mundo de la tecnología.

Puedes preguntarle sobre:
- 🚀 Cómo empezar en tech desde cero
- 💰 Salarios y trabajo remoto desde LATAM
- 📚 Qué aprender primero (SQL, Python, etc.)
- 🌍 Cómo conseguir trabajo remoto desde Perú

## ✨ Características

- 💬 Chat con IA en tiempo real
- 🧭 Respuestas especializadas en el contexto LATAM
- 📱 Funciona en celular y computadora
- ⚡ Preguntas sugeridas para empezar rápido
- 🌙 Diseño oscuro moderno

## 🛠️ Tecnologías usadas

- **HTML + CSS + JavaScript** — sin frameworks, puro y simple
- **OpenRouter API** — IA gratuita para las respuestas
- **Nginx** — servidor web en CubePath
- **GitHub Pages** — deploy alternativo

## ☁️ Deploy en CubePath

El proyecto está desplegado en un servidor **gp.nano de CubePath** con:
- Ubuntu 24.04
- Nginx como servidor web
- IP pública IPv4: `194.26.100.223`

CubePath permitió levantar el servidor en minutos con los $15 de crédito gratuito,
sin necesidad de tarjeta de crédito.

## 🤖 Transparencia — Cómo construí esto

Soy **Rodrigo**, tengo 19 años, soy de Lima, Perú, y esta es mi **primera hackatón**.

Cuando empecé este proyecto no sabía nada de programación — nunca había escrito 
una línea de código real, nunca había usado Git, nunca había desplegado nada en internet.

Usé **Claude (IA de Anthropic)** como mentor técnico durante todo el proceso:
me explicó cada concepto desde cero, me ayudó a depurar errores, y me guió 
paso a paso como si fuera un videojuego con misiones.

En 2 días aprendí a:
- ✅ Instalar herramientas de desarrollo (VS Code, Node.js, Git)
- ✅ Crear y gestionar repositorios en GitHub
- ✅ Escribir HTML, CSS y JavaScript
- ✅ Conectar una API de IA gratuita
- ✅ Desplegar en un servidor VPS real con Nginx

**PathMentor nació de mi propia necesidad** — soy exactamente el tipo de persona 
que esta app quiere ayudar: un joven latinoamericano que quiere entrar a tech 
desde cero, sin recursos, sin experiencia, pero con muchas ganas.

## 🚀 Cómo correrlo localmente

1. Clona el repositorio:
```
   git clone https://github.com/Corasannn/Pathmentor.git
```
2. Backend (opcional pero recomendado para seguridad):
   ```
   cd pathmentor/server
   npm install
   npm run dev
   ```
   Servirá en `http://localhost:8080` y proxeará `/api/chat` hacia OpenRouter con tu API key desde `.env.local`.
3. Frontend: abre `index.html` en el navegador (apunta al backend local en `/api/chat`).
4. ¡Listo!

## 🔐 Despliegue seguro en CubePath

> Resumen rápido (usa los archivos de `ops/` y `scripts/`):

1. **Prep VPS** (Ubuntu 24.04 en CubePath gp.nano):
   ```bash
   sudo apt update && sudo apt install -y nginx nodejs npm certbot python3-certbot-nginx ufw fail2ban
   sudo ufw allow OpenSSH && sudo ufw allow 80 && sudo ufw allow 443 && sudo ufw --force enable
   ```
2. **Dominios y TLS** (usando las IPs del VPS):
   - Copiá `ops/nginx.conf.sample` a `/etc/nginx/sites-available/pathmentor` (ya viene con `194.26.100.223`; ajustalo si cambiás IP o usás dominio).
   - Hacé symlink a `sites-enabled` y probá config: `sudo nginx -t && sudo systemctl reload nginx`.
   - Opcional (si consigues dominio): `sudo certbot --nginx -d tu-dominio.com -d www.tu-dominio.com`. Si usás IP, Certbot no emitirá certificados públicos válidos; mantén HTTP/80 + HTTPS self-signed o agrega dominio cuando lo tengas.
   - Programa renovación (ya preparada para cron): `sudo crontab -e` y agrega `0 3 * * * /var/www/pathmentor/ops/certbot-renew.sh`.
3. **Despliegue inicial**:
   ```bash
   sudo mkdir -p /var/www/pathmentor
   sudo chown -R $USER:$USER /var/www/pathmentor
   rsync -avz ./ $USER@VPS:/var/www/pathmentor
   cd /var/www/pathmentor/server && npm install && npm run build
   ```
4. **Servicio backend**:
   - Copia `ops/pathmentor.service` a `/etc/systemd/system/pathmentor.service` (ajusta ruta/domino si cambiaste).
   - `sudo systemctl daemon-reload && sudo systemctl enable --now pathmentor.service`
5. **CI/CD (opcional pero recomendado)**:
   - Define secretos en GitHub: `SSH_KEY` (clave privada), `VPS_HOST`, `VPS_USER`, `VPS_PATH` (e.g. `/var/www/pathmentor`).
   - El workflow `.github/workflows/deploy.yml` compila backend y rsync al VPS, luego corre `scripts/post-deploy.sh` (instala deps y reinicia systemd).

## ⚙️ Variables de entorno
Usá `.env.example` como guía y coloca la versión real en `/var/www/pathmentor/.env.local` (referenciada por systemd):

```
PORT=8080
OPENROUTER_API_KEY=tu-key
OPENROUTER_MODEL=openrouter/free
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
ALLOWED_ORIGINS=https://tu-frontend.com
```

## 🧪 Pruebas
- En `server/`: `npm test` (incluye health check y validación de schema).
- Para smoke en VPS: `curl -I https://tu-dominio.com/health` y `curl -N -X POST https://tu-dominio.com/api/chat -d '{"prompt":"hola"}' -H 'Content-Type: application/json'`.

## 🩹 Runbook rápido
- **Reiniciar backend**: `sudo systemctl restart pathmentor.service`
- **Logs backend**: `journalctl -u pathmentor.service -f`
- **Logs Nginx**: `/var/log/nginx/pathmentor.error.log`
- **Renovar TLS**: `sudo /var/www/pathmentor/ops/certbot-renew.sh`
- **Rollback simple**: conserva snapshot previo o rsync una release anterior y ejecutá `scripts/post-deploy.sh`

## 👤 Autor

Hecho con ❤️ por **Rodcolca* · Lima, Perú · CubePath Hackathon 2026
