#!/bin/bash

# -e: FInaliza el script cuando hay error
# -x: Muestra el comando por pantalla
set -ex

#importamos el archivo de variables
source .env

# Actualiza los repositorios
apt update

# Actualizacmos los paquetes
apt upgrade -y

#instalamos mysql-server
apt install mysql-server -y

# Configurar el parámetro 'bind-address' en el archivo de configuración de MySQL
sed -i "s/127.0.0.1/$BACKEND_PRIVATE_IP/" /etc/mysql/mysql.conf.d/mysqld.cnf

# Reiniciamos el servicio de mysql para aplicar los cambios
systemctl restart mysql