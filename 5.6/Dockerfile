ARG VERSION=${VERSION}
FROM docker.rz.tu-harburg.de/rzt/images/wordpress-base:${VERSION}

COPY ./setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

COPY ./config/htaccess /opt/htaccess

CMD ["/opt/setup.sh"]

LABEL \
  de.tuhh.ci_repository_url=$CI_REPOSITORY_URL \
  de.tuhh.ci_commit_short_sha=$CI_COMMIT_SHORT_SHA \
  de.tuhh.build-date=$BUILD_DATE \
  de.tuhh.version=$VERSION
