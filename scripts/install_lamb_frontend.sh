#!/bin/bash

# -e: FInaliza el script cuando hay error
# -x: Muestra el comando por pantalla
set -ex

# Actualiza los repositorios
apt update

# Actualizacmos los paquetes
apt upgrade -y

# Instalamos el servidor web apache
apt install apache2 -y

#Instalamos PHP
apt install php libapache2-mod-php php-mysql -y

#Copiamos el archivo de configuracion de apache
cp conf/000-default.conf /etc/apache2/sites-available

#Habilitamos el modulo rewrite de apache
a2enmod rewrite

#Reiniciamos el servicio de Apache
systemctl restart apache2