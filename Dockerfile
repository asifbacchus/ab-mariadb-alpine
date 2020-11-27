#
### mariadb running on Alpine Linux
#

FROM alpine:3.12

# standardized labels
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.label-schema.cmd="docker run -d --name db [-e TZ=Etc/UTC] docker.asifbacchus.app/mariadb/mariadb-alpine:latest"
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
    pwgen \
    && rm -f /var/cache/apk/*

# expose ports
EXPOSE 3306

# create volume if user forgets
VOLUME ["/var/lib/mysql"]

# copy scripts and make pre-exec and post-exec directories

# set environment variables
ENV TZ=Etc/UTC
ENV UID=8100
ENV GID=8100
ENV MYSQL_ROOT_PASSWORD=''
ENV MYSQL_DATABASE='myData'
ENV MYSQL_USER=''
ENV MYSQL_PASSWORD=''

# set entrypoint and default command
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "" ]

# add build date and version labels
ARG BUILD_DATE
LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.vendor="mariaDB (10.5.6-r0)"
LABEL org.label-schema.version="0.1"