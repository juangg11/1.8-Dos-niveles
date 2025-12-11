# 1.8-Dos-niveles
# Automatización de Despliegue de WordPress en Arquitectura 2 Niveles (Frontend/Backend)

Este repositorio contiene un conjunto de scripts en Bash diseñados para automatizar la instalación y configuración de una pila LAMP y un sitio WordPress, separados en una arquitectura de dos niveles: un servidor para el Frontend (Apache/PHP/WP) y otro para el Backend (MySQL).

Los scripts utilizan un archivo `.env` (no incluido por seguridad) para gestionar variables de configuración como credenciales de base de datos, IPs y nombres de dominio.

## Requisitos Previos

Antes de ejecutar estos scripts, asegúrate de:

1.  Tener dos servidores (o máquinas virtuales/contenedores) con una distribución basada en Debian/Ubuntu.
2.  Tener acceso root o sudo en ambas máquinas.
3.  Haber configurado el archivo `.env` con todas las variables necesarias (ej. `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `BACKEND_PRIVATE_IP`, etc.).

---

## Descripción de los Scripts

A continuación se detalla la función de cada script incluido en este repositorio.

### 1. `install_lamp_backend.sh` (Instalación del Backend)

Este script se encarga de aprovisionar el servidor de base de datos. Instala MySQL y lo configura para aceptar conexiones externas desde el servidor frontend.

**Comandos clave:**

| Comando | Descripción |
| :--- | :--- |
| `source .env` | Carga las variables de entorno desde el archivo oculto `.env`. |
| `apt update` / `apt upgrade -y` | Actualiza la lista de paquetes y el sistema operativo a las últimas versiones. |
| `apt install mysql-server -y` | Instala el servidor de base de datos MySQL. |
| `sed -i "s/127.0.0.1/$BACKEND_PRIVATE_IP/" ...` | Modifica el archivo de configuración de MySQL (`mysqld.cnf`) cambiando la dirección de enlace (bind-address) de localhost a la IP privada del servidor backend, permitiendo conexiones remotas. |
| `systemctl restart mysql` | Reinicia el servicio de MySQL para aplicar los cambios de configuración. |

---

### 2. `deploy_backend.sh` (Configuración Base de Datos)

Este script se ejecuta en el servidor backend *después* de que MySQL haya sido instalado. Su función es crear la base de datos y el usuario específico para la instalación de WordPress.

**Comandos clave:**

| Comando | Descripción |
| :--- | :--- |
| `mysql -u root -e "DROP DATABASE IF EXISTS..."` | Se conecta a MySQL como root y elimina la base de datos si ya existe (para instalaciones limpias). |
| `mysql -u root -e "CREATE DATABASE..."` | Crea una nueva base de datos vacía para WordPress usando la variable `$DB_NAME`. |
| `mysql -u root -e "CREATE USER..."` | Crea un nuevo usuario de base de datos. Es crucial que el host se defina como `$IP_CLIENTE_MYSQL` (la IP del frontend) para permitir la conexión remota. |
| `mysql -u root -e "GRANT ALL PRIVILEGES..."` | Otorga permisos completos al usuario recién creado sobre la base de datos de WordPress. |

---

### 3. `install_lamp_frontend.sh` (Instalación del Frontend)

Este script prepara el servidor web. Instala Apache, PHP y los módulos necesarios para que WordPress funcione correctamente.

**Comandos clave:**

| Comando | Descripción |
| :--- | :--- |
| `apt install apache2 -y` | Instala el servidor web Apache. |
| `apt install php libapache2-mod-php php-mysql -y` | Instala PHP, el módulo conector para Apache y el módulo para conectar PHP con MySQL. |
| `cp conf/000-default.conf /etc/apache2/...` | Copia un archivo de configuración de VirtualHost personalizado (ubicado en una carpeta `conf/` del repositorio) a la configuración de Apache. |
| `a2enmod rewrite` | Habilita el módulo `mod_rewrite` de Apache, esencial para que funcionen los enlaces permanentes (permalinks) de WordPress. |
| `systemctl restart apache2` | Reinicia Apache para cargar los nuevos módulos y configuraciones. |

---

### 4. `deploy_frontend.sh` (Despliegue de WordPress)

Este es el script más complejo. Descarga WordPress, lo instala y lo configura utilizando WP-CLI (la interfaz de línea de comandos de WordPress).

**Comandos clave:**

| Comando | Descripción |
| :--- | :--- |
| `wget ... wp-cli.phar` / `chmod +x` / `mv ...` | Descarga la herramienta WP-CLI, le da permisos de ejecución y la mueve a `/usr/local/bin/wp` para hacerla accesible globalmente. |
| `rm -rf /var/www/html/*` | Limpia el directorio raíz del servidor web para asegurar una instalación limpia. |
| `wp core download --locale=es_ES ...` | Descarga los archivos del núcleo de WordPress en español directamente en el directorio web. |
| `wp config create --dbname=$DB_NAME ...` | Genera el archivo `wp-config.php` con los datos de conexión a la base de datos remota (Backend). |
| `wp core install --url=$CERTBOT_DOMAIN ...` | Ejecuta la instalación de WordPress, creando las tablas en la DB y configurando el usuario administrador inicial del sitio y la URL. |
| `wp rewrite structure '/%postname%/' ...` | Configura la estructura de enlaces permanentes para que sean amigables (SEO-friendly). |
| `wp plugin install wps-hide-login --activate` | Instala y activa un plugin de seguridad para ocultar la página de inicio de sesión `/wp-admin`. |
| `wp option update whl_page $URL_HIDE_LOGIN` | Configura el plugin anterior para definir la nueva URL de acceso personalizada. |
| `cp htaccess/.htaccess /var/www/html/` | Copia un archivo `.htaccess` personalizado con reglas de seguridad o rendimiento adicionales. |
| `chown -R www-data:www-data /var/www/html` | Cambia el propietario de todos los archivos web al usuario `www-data` (el usuario de Apache) para evitar problemas de permisos. |

---

### 5. `certificado.sh` (Configuración SSL/TLS)

Este script genera e instala un certificado SSL autofirmado para habilitar HTTPS en el servidor Apache.

> **Nota:** Los certificados autofirmados provocarán una advertencia de seguridad en el navegador. Para producción, se recomienda usar Certbot/Let's Encrypt.

**Comandos clave:**

| Comando | Descripción |
| :--- | :--- |
| `openssl req -x509 ...` | Genera un certificado SSL autofirmado (`.crt`) y su clave privada (`.key`) de forma no interactiva, usando datos del archivo `.env` (País, Organización, CN, etc.). |
| `cp ../conf/default-ssl.conf ...` | Copia la plantilla de configuración para el VirtualHost SSL de Apache. |
| `a2ensite default-ssl.conf` | Habilita el sitio virtual para SSL. |
| `a2enmod ssl` | Habilita el módulo SSL necesario en Apache. |

# Capturas

<img width="1230" height="247" alt="image" src="https://github.com/user-attachments/assets/dd074d5d-008c-44c8-862b-8554320f94f6" />
<img width="1219" height="264" alt="image" src="https://github.com/user-attachments/assets/1db063e5-7253-4336-af15-1b005765adae" />
<img width="1459" height="277" alt="image" src="https://github.com/user-attachments/assets/5d94c1ca-a9e9-46bd-9ac4-0d26cb43fdac" />
<img width="1563" height="279" alt="image" src="https://github.com/user-attachments/assets/0d8ba610-bbf0-4cac-b392-2db9a8ef3ff8" />
<img width="1564" height="272" alt="image" src="https://github.com/user-attachments/assets/b0d4dd78-34bc-438b-ade1-6a76d4c8c0e7" />
<img width="1866" height="1035" alt="image" src="https://github.com/user-attachments/assets/2b708fa4-32b0-4e68-b206-d5079b1c94fa" />
<img width="1869" height="1034" alt="image" src="https://github.com/user-attachments/assets/e2572ff8-5ef0-41b7-a638-c07b6ee419a7" />
