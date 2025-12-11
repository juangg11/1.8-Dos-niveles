# 1.8-Dos-niveles

Este repositorio contiene una serie de scripts en Bash diseñados para automatizar la instalación y configuración de una pila LAMP (Linux, Apache, MySQL, PHP) distribuida en dos niveles (Frontend y Backend), y el despliegue posterior de WordPress mediante WP-CLI y certificados SSL autofirmados.

A continuación se detalla la función de cada script y una explicación línea por línea de los comandos clave que contienen.

---

## Scripts de Despliegue (Configuración de Aplicación)

Estos scripts se ejecutan una vez que el software base (LAMP) ya está instalado.

### 1. `deploy_backend.sh`

**Propósito:** Este script se ejecuta en el servidor de base de datos (Backend). Su función es preparar MySQL para WordPress, creando la base de datos y el usuario con los permisos necesarios para conectarse remotamente desde el Frontend.

**Explicación de comandos:**

* `set -ex`: Configura el script para que se detenga inmediatamente si un comando falla (`-e`) y muestra en pantalla cada comando que se ejecuta (`-x`), útil para depuración.
* `source .env`: Carga las variables definidas en el archivo `.env` para usarlas en el script (como nombres de DB, usuarios y contraseñas).
* `mysql -u root -e "DROP DATABASE IF EXISTS $DB_NAME"`: Se conecta a MySQL como root y elimina la base de datos definida en la variable `$DB_NAME` si ya existe. Esto asegura una instalación limpia.
* `mysql -u root -e "CREATE DATABASE $DB_NAME"`: Crea la nueva base de datos vacía que usará WordPress.
* `mysql -u root -e "DROP USER IF EXISTS $DB_USER@'$IP_CLIENTE_MYSQL'"`: Elimina el usuario de base de datos si ya existe. Es importante notar que el usuario se define asociado a la IP desde donde se conectará (`$IP_CLIENTE_MYSQL`, que es la IP del Frontend).
* `mysql -u root -e "CREATE USER $DB_USER@'$IP_CLIENTE_MYSQL' IDENTIFIED BY '$DB_PASSWORD'"`: Crea el nuevo usuario de MySQL y le asigna su contraseña.
* `mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO $DB_USER@'$IP_CLIENTE_MYSQL'"`: Otorga permisos totales al usuario recién creado únicamente sobre la base de datos de WordPress creada anteriormente.

### 2. `deploy_frontend.sh`

**Propósito:** Este script se ejecuta en el servidor web (Frontend). Se encarga de descargar e instalar WP-CLI (la herramienta de línea de comandos para WordPress), y luego usa esta herramienta para descargar WordPress, generar su archivo de configuración, instalarlo, configurar enlaces permanentes y añadir plugins de seguridad.

**Explicación de comandos:**

* `set -ex`: Detiene el script ante errores y muestra los comandos ejecutados.
* `source .env`: Carga las variables de entorno.
* `rm -f /tmp/wp-cli.phar`: Elimina cualquier descarga previa de WP-CLI en el directorio temporal para evitar conflictos.
* `wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp`: Descarga la herramienta WP-CLI desde su repositorio oficial y la guarda en `/tmp`.
* `chmod +x /tmp/wp-cli.phar`: Otorga permisos de ejecución al archivo descargado.
* `mv /tmp/wp-cli.phar /usr/local/bin/wp`: Mueve el archivo a una ruta del sistema para que pueda ejecutarse simplemente escribiendo `wp` desde cualquier lugar.
* `rm -rf /var/www/html/*`: Elimina todo el contenido del directorio raíz del servidor web para asegurar una instalación de WordPress limpia.
* `wp core download --locale=es_ES --path=/var/www/html --allow-root`: Usa WP-CLI para descargar los archivos del núcleo de WordPress en español directamente en el directorio web. Se usa `--allow-root` porque se está ejecutando el script como superusuario.
* `wp config create ...`: Genera el archivo `wp-config.php` con los datos de conexión a la base de datos (host, nombre, usuario, contraseña) que se encuentran en el archivo `.env`.
* `wp core install ...`: Ejecuta el instalador de WordPress. Aquí se define la URL del sitio, el título, y se crea el usuario administrador inicial.
* `wp rewrite structure '/%postname%/' ...`: Configura la estructura de los enlaces permanentes (permalinks) para que sean amigables para el SEO (ej. usando el nombre de la entrada).
* `wp plugin install wps-hide-login --activate ...`: Descarga, instala y activa el plugin de seguridad "WPS Hide Login".
* `wp option update whl_page $URL_HIDE_LOGIN ...`: Configura el plugin anterior para cambiar la URL de acceso por defecto (`/wp-admin`) por una personalizada definida en la variable `$URL_HIDE_LOGIN`.
* `cp htaccess/.htaccess /var/www/html/`: Copia un archivo `.htaccess` personalizado (con reglas extra de seguridad o configuración) desde una carpeta local al directorio raíz de la web.
* `chown -R www-data:www-data /var/www/html`: Cambia el propietario y el grupo de todos los archivos en el directorio web al usuario `www-data` (el usuario bajo el que corre Apache) para asegurar que el servidor web tenga permisos de lectura y escritura.

---

## Scripts de Instalación Base (Pila LAMP)

Estos scripts preparan el sistema operativo e instalan los servicios necesarios.

### 3. `install_lamp_backend.sh`

**Propósito:** Prepara el servidor backend actualizando el sistema, instalando el servidor MySQL y configurándolo para aceptar conexiones que no sean locales.

**Explicación de comandos:**

* `set -ex`: Detiene el script ante errores y muestra los comandos ejecutados.
* `source .env`: Carga las variables de entorno.
* `apt update`: Actualiza la lista de paquetes disponibles en los repositorios.
* `apt upgrade -y`: Instala las versiones más nuevas de todos los paquetes actualmente instalados en el sistema.
* `apt install mysql-server -y`: Instala el servidor de base de datos MySQL.
* `sed -i "s/127.0.0.1/$BACKEND_PRIVATE_IP/" /etc/mysql/mysql.conf.d/mysqld.cnf`: Este comando usa `sed` para editar el archivo de configuración principal de MySQL. Busca la línea que dice `bind-address = 127.0.0.1` (que fuerza a MySQL a escuchar solo localmente) y la reemplaza por la IP privada del servidor backend (`$BACKEND_PRIVATE_IP`). Esto permite que el servidor frontend se conecte a la base de datos a través de la red privada.
* `systemctl restart mysql`: Reinicia el servicio de MySQL para que aplique los cambios de configuración realizados con `sed`.

### 4. `install_lamp_frontend.sh`

**Propósito:** Prepara el servidor frontend actualizando el sistema, instalando el servidor web Apache, el lenguaje PHP y los módulos necesarios para su integración y para el funcionamiento de WordPress.

**Explicación de comandos:**

* `set -ex`: Detiene el script ante errores y muestra los comandos ejecutados.
* `apt update`: Actualiza la lista de paquetes disponibles.
* `apt upgrade -y`: Actualiza los paquetes del sistema.
* `apt install apache2 -y`: Instala el servidor web Apache.
* `apt install php libapache2-mod-php php-mysql -y`: Instala el intérprete PHP, el módulo que permite a Apache ejecutar código PHP, y el módulo que permite a PHP comunicarse con bases de datos MySQL.
* `cp conf/000-default.conf /etc/apache2/sites-available`: Copia un archivo de configuración de VirtualHost personalizado (desde una carpeta local `conf`) a la carpeta de configuración de sitios de Apache, sobrescribiendo el predeterminado.
* `a2enmod rewrite`: Habilita el módulo `mod_rewrite` de Apache. Este módulo es esencial para que funcionen las URLs amigables (enlaces permanentes) de WordPress.
* `systemctl restart apache2`: Reinicia el servicio de Apache para cargar los nuevos módulos instalados y la nueva configuración.

---

## Scripts de Seguridad

### 5. `certificado.sh`

**Propósito:** Genera un certificado SSL/TLS autofirmado y configura Apache para usarlo, habilitando el acceso por HTTPS.

**Explicación de comandos:**

* `set -ex`: Detiene el script ante errores y muestra los comandos ejecutados.
* `apt update`: Actualiza la lista de paquetes.
* `source .env`: Carga las variables necesarias para rellenar los datos del certificado (País, Organización, etc.).
* `sudo openssl req -x509 ...`: Este comando largo utiliza OpenSSL para generar un nuevo certificado (`-x509`).
    * `-nodes`: Indica que no se encripte la clave privada (para que Apache no pida contraseña al arrancar).
    * `-days 365`: El certificado será válido por un año.
    * `-newkey rsa:2048`: Genera una nueva clave RSA de 2048 bits.
    * `-keyout ...` y `-out ...`: Define dónde se guardarán la clave privada (`.key`) y el certificado público (`.crt`).
    * `-subj "/C=..."`: Rellena la información del sujeto del certificado de forma no interactiva usando las variables del archivo `.env`.
* `cp ../conf/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf`: Copia una plantilla de configuración de VirtualHost para SSL (puerto 443) a la carpeta de Apache. Este archivo debe estar configurado para apuntar a los archivos `.crt` y `.key` generados anteriormente.
* `sudo a2ensite default-ssl.conf`: Habilita el nuevo sitio virtual SSL en Apache.
* `a2enmod ssl`: Habilita el módulo SSL en Apache, necesario para manejar conexiones HTTPS.
* `systemctl restart apache2`: Reinicia Apache para aplicar toda la nueva configuración de seguridad.
# Capturas

<img width="1230" height="247" alt="image" src="https://github.com/user-attachments/assets/dd074d5d-008c-44c8-862b-8554320f94f6" />
<img width="1219" height="264" alt="image" src="https://github.com/user-attachments/assets/1db063e5-7253-4336-af15-1b005765adae" />
<img width="1459" height="277" alt="image" src="https://github.com/user-attachments/assets/5d94c1ca-a9e9-46bd-9ac4-0d26cb43fdac" />
<img width="1563" height="279" alt="image" src="https://github.com/user-attachments/assets/0d8ba610-bbf0-4cac-b392-2db9a8ef3ff8" />
<img width="1564" height="272" alt="image" src="https://github.com/user-attachments/assets/b0d4dd78-34bc-438b-ade1-6a76d4c8c0e7" />
<img width="1866" height="1035" alt="image" src="https://github.com/user-attachments/assets/2b708fa4-32b0-4e68-b206-d5079b1c94fa" />
<img width="1869" height="1034" alt="image" src="https://github.com/user-attachments/assets/e2572ff8-5ef0-41b7-a638-c07b6ee419a7" />
