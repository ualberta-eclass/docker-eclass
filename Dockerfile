# Docker file for eclass-unified project
FROM ubuntu:14.04.4
MAINTAINER Joey Andres <jandres@ualberta.ca>

# Install ``python-software-properties``, ``software-properties-common`` and PostgreSQL 9.3
#  There are some warnings (in red) that show up during the build. You can hide
#  them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install -y python-software-properties software-properties-common \
    apache2 apache2-dev wget

# Install required files for php extensions (php extension required by moodle).
# https://docs.moodle.org/29/en/Compiling_PHP_from_source (should still work for 28)
RUN apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng-dev \
    libxpm-dev \
    libpq-dev \
    libicu-dev \
    libfreetype6-dev \
    libldap2-dev \
    libxslt-dev \
    libgcrypt11-dev zlib1g-dev # zlib
    
RUN apt-get install -y build-essential

# Note: The official Debian and Ubuntu images automatically ``apt-get clean``
# after each ``apt-get``

# USER postgres

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
# Note: here we use ``&&\`` to run commands one after the other - the ``\``
#       allows the RUN command to span multiple lines.
# RUN /etc/init.d/postgresql start && \
#    psql --command "CREATE USER moodle WITH SUPERUSER PASSWORD 'moodle';" && \
#    createdb -E UTF8 -O moodle moodledb

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible. 
# RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.5.1/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
# RUN echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf

USER root

# Install php5
RUN cd /tmp
RUN apt-get install -y graphviz aspell \
    php5-pspell \
    php5-curl \
    php5-gd \
    php5-intl \
    php5-pgsql \
    php5-xmlrpc \
    php5-ldap \
    php5-memcached \
    libapache2-mod-php5 \
    clamav && \

    # Restart apache service.    
    service apache2 restart

# memcached
RUN apt-get install -y memcached

# Dev tools
RUN apt-get install -y emacs vim

# Expose the memcached, PostgreSQL and Apache port
EXPOSE 5432
EXPOSE 11211
EXPOSE 80

# Add VOLUMEs to allow backup of config, logs and databases
# Note no need to volume partition for server data due to having more than sufficient (10GB).
VOLUME  ["/eclass-unified"]

USER root

# Create a non root sudoer user.
RUN useradd -ms /bin/bash -G sudo lmsadmin
RUN echo lmsadmin:lmsadmin | chpasswd
RUN mkdir -p /eclass-unified
RUN chmod -R 755 /eclass-unified
RUN chown -R  lmsadmin:lmsadmin /eclass-unified

# Create moodledata directory.
RUN mkdir -p /moodledata
RUN chmod 777 /moodledata  # So we can write into it.
RUN chown lmsadmin:lmsadmin /moodledata

# Create phpu_moodledata. This is data folder for phpunit.
RUN mkdir -p /phpu_moodledata
RUN chmod 777 /phpu_moodledata  # So we can write into it.
RUN chown lmsadmin:lmsadmin /phpu_moodledata

# Create b_moodledata. This is data folder for behat.
RUN mkdir -p /b_moodledata
RUN chmod 777 /b_moodledata  # So we can write into it.
RUN chown lmsadmin:lmsadmin /b_moodledata

# Change DocumentRoot to /eclass-unified
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf
# Change apache2.conf.
COPY apache2.conf /etc/apache2/apache2.conf

################################################################################
# Miscellaneous ################################################################
################################################################################
# npm for other developer tools like ressc and shifter.
RUN cd /tmp && \
    wget https://nodejs.org/dist/v0.12.7/node-v0.12.7.tar.gz && \
    tar -zxvf node-v0.12.7.tar.gz && \
    cd node-v0.12.7 && \
    ./configure && \
    make -j16 && \
    make install

# TODO: Install lessc

# Now that npm is installed, install related development tools.
RUN npm install -g shifter && \
    npm install -g recess

RUN apt-get install -y git

COPY custom-startup.sh /docker-entrypoint-initdb.d/