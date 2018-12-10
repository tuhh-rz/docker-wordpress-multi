FROM docker.rz.tu-harburg.de:5000/rzt/images/wordpress-base:5.0

COPY ./setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

CMD ["/opt/setup.sh"]