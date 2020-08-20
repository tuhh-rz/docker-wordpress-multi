FROM docker.rz.tu-harburg.de:5000/rzt/images/wordpress-base:4.9

COPY ./setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

CMD ["/opt/setup.sh"]

LABEL \
    de.tuhh.ci_repository_url=$CI_REPOSITORY_URL \
    de.tuhh.ci_commit_short_sha=$CI_COMMIT_SHORT_SHA \
    de.tuhh.build-date=$BUILD_DATE \
    de.tuhh.version=$VERSION
