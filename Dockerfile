#
# mariadb running on Alpine Linux
#

# build arguments
ARG ALPINE_VERSION="3.24"
ARG MARIADB_VERSION="11.8.8-r0"

FROM alpine:${ALPINE_VERSION}
ARG ALPINE_VERSION
ARG MARIADB_VERSION

# standardized labels
LABEL dev.asifbacchus.docker.internalName="ab-mariadb-alpine"
LABEL org.opencontainer.image.authors="Asif Bacchus <asif@asifbacchus.dev>"
LABEL org.opencontainer.image.description="Mariadb on Alpine Linux."
LABEL org.opencontainer.image.documentation="https://git.asifbacchus.dev/ab-docker/ab-mariadb-alpine/raw/branch/main/README.md"
LABEL org.opencontainer.image.source="https://git.asifbacchus.dev/ab-docker/ab-mariadb-alpine.git"
LABEL org.opencontainer.image.title="ab-mariadb-alpine"
LABEL org.opencontainer.image.url="https://git.asifbacchus.dev/ab-docker/ab-mariadb-alpine"
LABEL org.opencontainer.image.vendor="Asif Bacchus <asif@asifbacchus.dev>"

# install mariadb and turn on TCP connection in default config
RUN apk --update --no-cache add \
        tzdata \
        mariadb>${MARIADB_VERSION} \
        mariadb-client>${MARIADB_VERSION} \
        mariadb-server-utils>${MARIADB_VERSION} \
        mariadb-backup>${MARIADB_VERSION} \
    && apk --no-cache --update upgrade \
    && sed -i 's/skip-networking/skip-networking=0/' /etc/my.cnf.d/mariadb-server.cnf

# expose ports
EXPOSE 3306

# create volume if user forgets
VOLUME ["/var/lib/mysql"]

# basic healthcheck (service only)
HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=5s \
    --retries=3 \
    CMD mysqladmin ping --silent

# set environment variables
ENV TZ=Etc/UTC
ENV MYSQL_UID=8100
ENV MYSQL_GID=8100
ENV MYSQL_SKIP_NAME_RESOLVE=TRUE
ENV MYSQL_ROOT_PASSWORD=''
ENV MYSQL_DATABASE='myData'
ENV MYSQL_CHARSET='utf8mb4'
ENV MYSQL_COLLATION='utf8mb4_general_ci'
ENV MYSQL_USER=''
ENV MYSQL_PASSWORD=''

# copy scripts and make script/sql directories
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN mkdir -p /docker-entrypoint-preinit.d \
    && mkdir -p /docker-entrypoint-initdb.d \
    && mkdir -p /docker-entrypoint-postinit.d \
    && chmod +x /usr/local/bin/entrypoint.sh

# set entrypoint and default command
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/bin/mariadbd", "--user=mysql", "--console" ]

# add parameters, version and build date labels
# set build timestamp and version labels
ARG INTERNAL_VERSION
ARG GIT_COMMIT
ARG BUILD_DATE
LABEL dev.asifbacchus.docker.internalVersion=${INTERNAL_VERSION}
LABEL org.opencontainers.image.version="${INTERNAL_VERSION}-${MARIADB_VERSION}"
LABEL org.opencontainers.image.revision=${GIT_COMMIT}
LABEL org.opencontainers.image.created=${BUILD_DATE}

#EOF
