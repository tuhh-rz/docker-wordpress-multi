#!/bin/bash

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

perl -i -pe 's/^(\s*LogFormat\s+.*)%h(.*)/\1%a\2/g' /etc/apache2/apache2.conf

# Limits: Default values
export UPLOAD_MAX_FILESIZE=${UPLOAD_MAX_FILESIZE:-300M}
export POST_MAX_SIZE=${POST_MAX_SIZE:-300M}
export MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:-360}
export MAX_FILE_UPLOADS=${MAX_FILE_UPLOADS:-20}
export MAX_INPUT_VARS=${MAX_INPUT_VARS:-1000}
export MEMORY_LIMIT=${MEMORY_LIMIT:-512M}

export PATH_CURRENT_SITE=${PATH_CURRENT_SITE:-/}

export DISABLE_WP_CRON=${DISABLE_WP_CRON:-false}
export AUTOMATIC_UPDATER_DISABLED=${AUTOMATIC_UPDATER_DISABLED:-true}

# Limits
perl -i -pe 's/^(\s*;\s*)*upload_max_filesize.*/upload_max_filesize = $ENV{'UPLOAD_MAX_FILESIZE'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*post_max_size.*/post_max_size = $ENV{'POST_MAX_SIZE'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_execution_time.*/max_execution_time = $ENV{'MAX_EXECUTION_TIME'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_file_uploads.*/max_file_uploads = $ENV{'MAX_FILE_UPLOADS'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_input_vars.*/max_input_vars = $ENV{'MAX_INPUT_VARS'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*memory_limit.*/memory_limit = $ENV{'MEMORY_LIMIT'}/g' /etc/php/7.2/apache2/php.ini

sed -i 's/<\/VirtualHost>/<Directory \/var\/www\/html>\nAllowOverride ALL\n<\/Directory>\n<\/VirtualHost>/' /etc/apache2/sites-available/000-default.conf

mkdir -p "/var/www/html/${RELATIVE_PATH}"
rsync -au /opt/wordpress/ "/var/www/html/${RELATIVE_PATH}"

# Default .htaccess
if [ ! -f "/var/www/html/${RELATIVE_PATH}/.htaccess" ]; then
  cp /opt/htaccess "/var/www/html/${RELATIVE_PATH}/.htaccess"
fi
perl -i -pe 's/^(RewriteBase\s+).*/\1$ENV{'PATH_CURRENT_SITE'}/g' "/var/www/html/${RELATIVE_PATH}/.htaccess"

find /var/www/html/ ! -user www-data -exec chown www-data: {} +

if [ -e "/usr/local/bin/wp" ]; then
  # wp-config.php anlegen
  if [ -z "${DBNAME+x}" ] || [ -z "${DBUSER+x}" ] || [ -z "${DBPASS+x}" ] || [ -z "${DBHOST+x}" ] || [ -z "${DBPREFIX+x}" ] || [ -z "${INITIAL_URL+x}" ] || [ -z "${SMTP_HOST+x}" ] || [ -z "${SMTP_PORT+x}" ] || [ -z "${SMTP_SMTP_AUTH+x}" ] || [ -z "${SMTP_USER_NAME+x}" ] || [ -z "${SMTP_PASSWORD+x}" ] || [ -z "${SMTP_FROM+x}" ] || [ -z "${SMTP_FROM_NAME+x}" ] || [ -z "${SMTP_SENDER+x}" ] || [ -z "${DOMAIN_CURRENT_SITE+x}" ]; then
    echo WARNING: skipping 'wp config create': One or more environment variables not defined: DBNAME, DBUSER, DBPASS, DBHOST, DBPREFIX, INITIAL_URL, SMTP_HOST, SMTP_PORT, SMTP_SMTP_AUTH, SMTP_USER_NAME, SMTP_PASSWORD, SMTP_FROM, SMTP_FROM_NAME, SMTP_SENDER, DOMAIN_CURRENT_SITE
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
    echo WARNING: skipping 'wp core multisite-install': One or more environment variables not defined: INITIAL_TITLE, INITIAL_URL, INITIAL_ADMIN_USER, INITIAL_ADMIN_PASSWORD, INITIAL_ADMIN_EMAIL
  fi

  # Mitgelieferte Plugins sofort aktualisieren
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin update --all" www-data

  # Updates the active translation of core, plugins, and themes.
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' core language update" www-data
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' theme update --all" www-data

  # WordPress Plugins
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install wpdirauth" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install shortcodes-ultimate" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install auto-submenu" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install qtranslate-x" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install svg-support" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install wp-user-avatar" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install akismet" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install stops-core-theme-and-plugin-updates" www-data

  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate wpdirauth --network" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate shortcodes-ultimate --network" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate akismet --network" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate stops-core-theme-and-plugin-updates --network" www-data

  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete hello" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete easy-wp-smtp" www-data

  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete akismet" www-data

  # if [ -d "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/.git" ]; then
  #   git -C "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/" pull
  # else
  #   git clone https://collaborating.tuhh.de/open-source/wordpress-plugins/tuhh-filter.git "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/"
  # fi
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate tuhh-filter --network" www-data

  # if [ -d "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/bst-smtp/.git" ]; then
  #   git -C "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/bst-smtp/" pull
  # else
  #   git clone https://collaborating.tuhh.de/open-source/wordpress-plugins/bst-smtp.git "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/bst-smtp/"
  # fi
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate bst-smtp --network" www-data

  # echo "!!!! quick'n'dirty hack !!!!"
  # echo "Logout für LDAP auf 24 Stunden"
  # sed -i 's/\$intExpireTime *= *.*/\$intExpireTime = 60 * 60 * 24;/' "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/wpdirauth/wpDirAuth.php"
fi

# consider a table prefix
export TABLE_PREFIX=${TABLE_PREFIX:-wp_}
perl -i -pe 's/^(\$table_prefix\s+=\s+).*/\1\x27$ENV{'TABLE_PREFIX'}\x27;/g' "/var/www/html/${RELATIVE_PATH}/wp-config.php"

find /var/www/html -type f -print0 | xargs -0 chmod 660
find /var/www/html -type d -print0 | xargs -0 chmod 770

chmod 440 "/var/www/html/${RELATIVE_PATH}/.htaccess"

exec /usr/bin/supervisord -nc /etc/supervisord.conf
