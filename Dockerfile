#
### mariadb running on Alpine Linux
#

FROM alpine:3.12

# standardized labels
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.label-schema.cmd="docker run -d --name db [-e TZ=Etc/UTC -e MYSQL_UID=8100 -e MYSQL_GID=8100 -e MYSQL_ROOT_PASSWORD=... -e MYSQL_DATABASE='myData' -e MYSQL_CHARSET='utf8mb4' -e MYSQL_COLLATION='utf8mb4_general_ci' -e MYSQL_USER=... -e MYSQL_PASSWORD=...] docker.asifbacchus.app/mariadb/mariadb-alpine:latest"
LABEL org.label-schema.description="mariadb running on Alpine Linux."
LABEL org.label-schema.name="mariadb-alpine"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.url="https://git.asifbacchus.app/ab-docker/mariadb-alpine"
LABEL org.label-schema.usage="https://git.asifbacchus.app/ab-docker/mariadb-alpine/wiki"
LABEL org.label-schema.vcs-url="https://git.asifbacchus.app/ab-docker/mariadb-alpine.git"

# install mariadb
RUN apk --no-cache add \
    tzdata \
    mariadb \
    mariadb-client \
    mariadb-server-utils \
    && rm -f /var/cache/apk/*

# expose ports
EXPOSE 3306

# create volume if user forgets
VOLUME ["/var/lib/mysql"]

# set environment variables
ENV TZ=Etc/UTC
ENV MYSQL_UID=8100
ENV MYSQL_GID=8100
ENV MYSQL_ROOT_PASSWORD=''
ENV MYSQL_DATABASE='myData'
ENV MYSQL_CHARSET='utf8mb4'
ENV MYSQL_COLLATION='utf8mb4_general_ci'
ENV MYSQL_USER=''
ENV MYSQL_PASSWORD=''

# copy scripts and make pre-exec and post-exec directories
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# set entrypoint and default command
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/bin/mysqld", "--user=mysql", "--console", "--skip-name-resolve", "--skip-networking=0" ]

# add build date and version labels
ARG BUILD_DATE
LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.vendor="mariaDB (10.5.6-r0)"
LABEL org.label-schema.version="0.1"