#
### mariadb running on Alpine Linux
#

FROM alpine:3.12

# standardized labels
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.label-schema.cmd="docker run -d --name db -v volume:/var/lib/mysql [-v /pre/exec/scripts:/docker-entrypoint-preinit.d] [-v /sql/scripts:/docker-entrypoint-initdb.d] [-v /post/exec/scripts:/docker-entrypoint-postinit.d] [-e TZ=Etc/UTC -e MYSQL_UID=8100 -e MYSQL_GID=8100 -e MYSQL_ROOT_PASSWORD=... -e MYSQL_DATABASE='myData' -e MYSQL_CHARSET='utf8mb4' -e MYSQL_COLLATION='utf8mb4_general_ci' -e MYSQL_USER=... -e MYSQL_PASSWORD=...] docker.asifbacchus.app/mariadb/mariadb-alpine:latest"
LABEL org.label-schema.description="mariadb running on Alpine Linux."
LABEL org.label-schema.name="mariadb-alpine"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.url="https://git.asifbacchus.app/ab-docker/mariadb-alpine"
LABEL org.label-schema.usage="https://git.asifbacchus.app/ab-docker/mariadb-alpine/wiki"
LABEL org.label-schema.vcs-url="https://git.asifbacchus.app/ab-docker/mariadb-alpine.git"

# install mariadb and turn on TCP connection in default config
RUN apk --no-cache add \
    tzdata \
    iputils \
    mariadb \
    mariadb-client \
    mariadb-server-utils \
    && rm -f /var/cache/apk/* \
    && sed -i 's/skip-networking/skip-networking=0/' /etc/my.cnf.d/mariadb-server.cnf

# expose ports
EXPOSE 3306

# create volume if user forgets
VOLUME ["/var/lib/mysql"]

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
    && chown -R mysql:mysql /docker-entrypoint-*

# set entrypoint and default command
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/bin/mysqld", "--user=mysql", "--console" ]

# add build date and version labels
ARG BUILD_DATE
LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.vendor="mariaDB (10.5.6-r0)"
LABEL org.label-schema.version="1.0"