#!/bin/bash

chown -Rf www-data.www-data /var/www/html/

if [[ ${ENABLE_SSL} == "true" ]]; then
    sed -i '/SSLCertificateFile/d' /etc/apache2/sites-available/default-ssl.conf
    sed -i '/SSLCertificateKeyFile/d' /etc/apache2/sites-available/default-ssl.conf
    sed -i '/SSLCertificateChainFile/d' /etc/apache2/sites-available/default-ssl.conf
    
    sed -i 's/SSLEngine.*/SSLEngine on\nSSLCertificateFile \/etc\/apache2\/ssl\/cert.pem\nSSLCertificateKeyFile \/etc\/apache2\/ssl\/private_key.pem\nSSLCertificateChainFile \/etc\/apache2\/ssl\/cert-chain.pem/' /etc/apache2/sites-available/default-ssl.conf

    ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/
    
    /usr/sbin/a2enmod ssl
else
    /usr/sbin/a2dismod ssl
    rm /etc/apache2/sites-enabled/default-ssl.conf
fi
/usr/sbin/a2enmod rewrite

/usr/sbin/a2enconf remoteip
/usr/sbin/a2enmod remoteip

perl -i -pe 's/^(\s*LogFormat ")%h( %l %u %t \\"%r\\" %>s %O \\"%\{Referer\}i\\" \\"%\{User-Agent\}i\\"" combined)/\1%a\2/g' /etc/apache2/apache2.conf


# Default .htaccess
if [ ! -f "/var/www/html/.htaccess" ]; then
    cp /opt/wordpress/htaccess /var/www/html/.htaccess
fi

# Limits: Default values
export UPLOAD_MAX_FILESIZE=${UPLOAD_MAX_FILESIZE:-300M}
export POST_MAX_SIZE=${POST_MAX_SIZE:-300M}
export MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:-360}
export MAX_FILE_UPLOADS=${MAX_FILE_UPLOADS:-20}
export MAX_INPUT_VARS=${MAX_INPUT_VARS:-1000}
export MEMORY_LIMIT=${MEMORY_LIMIT:-512M}


export PATH_CURRENT_SITE=${PATH_CURRENT_SITE:-/}

export DISABLE_WP_CRON=${DISABLE_WP_CRON:-true}
export AUTOMATIC_UPDATER_DISABLED=${AUTOMATIC_UPDATER_DISABLED:-false}


# Limits
perl -i -pe 's/^(\s*;\s*)*upload_max_filesize.*/upload_max_filesize = $ENV{'UPLOAD_MAX_FILESIZE'}/g' /etc/php/7.0/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*post_max_size.*/post_max_size = $ENV{'POST_MAX_SIZE'}/g' /etc/php/7.0/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_execution_time.*/max_execution_time = $ENV{'MAX_EXECUTION_TIME'}/g' /etc/php/7.0/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_file_uploads.*/max_file_uploads = $ENV{'MAX_FILE_UPLOADS'}/g' /etc/php/7.0/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_input_vars.*/max_input_vars = $ENV{'MAX_INPUT_VARS'}/g' /etc/php/7.0/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*memory_limit.*/memory_limit = $ENV{'MEMORY_LIMIT'}/g' /etc/php/7.0/apache2/php.ini

sed -i 's/<\/VirtualHost>/<Directory \/var\/www\/html>\nAllowOverride ALL\n<\/Directory>\n<\/VirtualHost>/' /etc/apache2/sites-available/000-default.conf

mkdir -p "/var/www/html/${RELATIVE_PATH}"
rsync -rc /opt/wordpress/wordpress/* "/var/www/html/${RELATIVE_PATH}"
chown -Rf www-data.www-data "/var/www/html/${RELATIVE_PATH}"

rsync -avr /opt/wp-plugins/ "/var/www/html/${RELATIVE_PATH}/wp-content/plugins"

chown -Rf www-data.www-data /var/www/html/

if [ -e "/usr/local/bin/wp" ]; then
    # wp-config.php anlegen
    if [ -z "${DBNAME+x}" ] || [ -z "${DBUSER+x}" ] || [ -z "${DBPASS+x}" ] || [ -z "${DBHOST+x}" ] || [ -z "${DBPREFIX+x}" ] || [ -z "${INITIAL_URL+x}" ] || [ -z "${SMTP_HOST+x}" ] || [ -z "${SMTP_PORT+x}" ] || [ -z "${SMTP_SMTP_AUTH+x}" ] || [ -z "${SMTP_USER_NAME+x}" ] || [ -z "${SMTP_PASSWORD+x}" ] || [ -z "${SMTP_FROM+x}" ] || [ -z "${SMTP_FROM_NAME+x}" ] || [ -z "${SMTP_SENDER+x}" ] || [ -z "${DOMAIN_CURRENT_SITE+x}" ]; then
         echo 'WARNING: skipping `wp config create`: One or more environment variables not defined: DBNAME, DBUSER, DBPASS, DBHOST, DBPREFIX, INITIAL_URL, SMTP_HOST, SMTP_PORT, SMTP_SMTP_AUTH, SMTP_USER_NAME, SMTP_PASSWORD, SMTP_FROM, SMTP_FROM_NAME, SMTP_SENDER, DOMAIN_CURRENT_SITE'
    else
        su -s /bin/bash -c "/usr/local/bin/wp --path=/var/www/html/${RELATIVE_PATH} config create --dbname='${DBNAME}' --dbuser='${DBUSER}' --dbpass='${DBPASS}' --dbhost='${DBHOST}' --dbprefix='${DBPREFIX}' --skip-check --force --extra-php <<PHP
define('WP_ALLOW_MULTISITE', true);
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', false);
define('DOMAIN_CURRENT_SITE', '${DOMAIN_CURRENT_SITE}');

define('PATH_CURRENT_SITE', '${PATH_CURRENT_SITE}');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);

# bst-smtp Plugin settings
define('BST_SMTP_HOST', '${SMTP_HOST}');
define('BST_SMTP_PORT', ${SMTP_PORT});
define('BST_SMTP_SMTP_AUTH', ${SMTP_SMTP_AUTH});
define('BST_SMTP_USER_NAME', '${SMTP_USER_NAME}');
define('BST_SMTP_PASSWORD', '${SMTP_PASSWORD}');
define('BST_SMTP_FROM', '${SMTP_FROM}');
define('BST_SMTP_FROM_NAME', '${SMTP_FROM_NAME}');
define('BST_SMTP_SENDER', '${SMTP_SENDER}');      

define('AUTOMATIC_UPDATER_DISABLED', ${AUTOMATIC_UPDATER_DISABLED});
define('DISABLE_WP_CRON', ${DISABLE_WP_CRON});
PHP
" www-data
    fi

    # WP initialisieren
    if [ -n "${INITIAL_TITLE}" ] && [ -n "${INITIAL_URL}" ] && [ -n "${INITIAL_ADMIN_USER}" ] && [ -n "${INITIAL_ADMIN_PASSWORD}" ] && [ -n "${INITIAL_ADMIN_EMAIL}" ]; then
        su -s /bin/bash -c "/usr/local/bin/wp --path=/var/www/html/${RELATIVE_PATH} core multisite-install --title='${INITIAL_TITLE}' --url='${INITIAL_URL}' --base='${RELATIVE_PATH}' --admin_user='${INITIAL_ADMIN_USER}' --admin_password='${INITIAL_ADMIN_PASSWORD}' --admin_email='${INITIAL_ADMIN_EMAIL}' --skip-email" www-data
    else
        echo 'WARNING: skipping `wp core multisite-install`: One or more environment variables not defined: INITIAL_TITLE, INITIAL_URL, INITIAL_ADMIN_USER, INITIAL_ADMIN_PASSWORD, INITIAL_ADMIN_EMAIL'
    fi

    # Mitgelieferte Plugins sofort aktualisieren
    #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin update --all" www-data

    # Updates the active translation of core, plugins, and themes.
    #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' core language update" www-data
    #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' theme update --all" www-data

    # WordPress Plugins
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install wpdirauth" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install shortcodes-ultimate" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install auto-submenu" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install media-file-sizes" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install qtranslate-x" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install svg-support" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install wp-user-avatar" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install akismet" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install stops-core-theme-and-plugin-updates" www-data

    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate wpdirauth --network" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate shortcodes-ultimate --network" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate auto-submenu --network" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate media-file-sizes --network" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate qtranslate-x --network" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate bst-smtp --network" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate wp-user-avatar --network" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate akismet --network" www-data
    # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate stops-core-theme-and-plugin-updates --network" www-data

    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin deactivate stops-core-theme-and-plugin-updates --network" www-data
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete stops-core-theme-and-plugin-updates" www-data

    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete hello" www-data
    #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete akismet" www-data
    
    echo "!!!! quick'n'dirty hack !!!!"
    echo "Logout für LDAP auf 24 Stunden"
    sed -i 's/\$intExpireTime *= *.*/\$intExpireTime = 60 * 60 * 24;/' "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/wpdirauth/wpDirAuth.php"
fi

chown -Rf www-data.www-data /var/www/html/

find /var/www/html -type f -print0 | xargs -0 chmod 660
find /var/www/html -type d -print0 | xargs -0 chmod 770

exec /usr/bin/supervisord -nc /etc/supervisord.conf
