FROM docker.rz.tu-harburg.de:5000/rzt/images/wordpress-base:5.3

COPY ./setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

COPY ./config/htaccess /opt/htaccess

CMD ["/opt/setup.sh"]