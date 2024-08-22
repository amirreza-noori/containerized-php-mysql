
# Use the official OpenLiteSpeed image
FROM litespeedtech/openlitespeed:1.7.11-lsphp74

VOLUME [ "/usr/local/lsws/", "/var/www/vhosts/" ]

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget unzip


# Download and install ionCube Loader
RUN wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip
RUN unzip ioncube_loaders_lin_x86-64.zip && \
    mkdir -p /usr/local/lsws/lsphp74/etc/php/7.4/conf.d && \
    cp ioncube/ioncube_loader_lin_7.4.so /usr/local/lsws/lsphp74/lib/php/ && \
    echo "zend_extension = /usr/local/lsws/lsphp74/lib/php/ioncube_loader_lin_7.4.so" > /usr/local/lsws/lsphp74/etc/php/7.4/mods-available/ioncube.ini && \
    ln -s /usr/local/lsws/lsphp74/etc/php/7.4/mods-available/ioncube.ini /usr/local/lsws/lsphp74/etc/php/7.4/conf.d/00-ioncube.ini && \
    rm -rf ioncube_loaders_lin_x86-64.zip ioncube


# Set the working directory
WORKDIR /var/www/vhosts/localhost/

USER root

# Set permissions for the web root directory
RUN mkdir -p html && \    
    chown -R root:root /var/www/vhosts/localhost/html


# Expose ports
EXPOSE 80 443 7080

# Start OpenLiteSpeed
CMD ["/usr/local/lsws/bin/lswsctrl", "start"]