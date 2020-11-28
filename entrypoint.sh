#!/bin/sh
#
### entrypoint script for mariadb container
#

convertCase () {
    printf "%s" "$1" | tr "[:lower:]" "[:upper:]"
}

# instantiate variables
sqlCmd='/tmp/cmd.sql'

# generate root password if not specified
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD="$( head /dev/urandom | tr -dc A-Za-z0-9 | head -c32 )"
    export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
fi

# change mysql UID & GID
sed -i "s/mysql:x:100:101/mysql:x:${MYSQL_UID}:${MYSQL_GID}/" /etc/passwd
sed -i "s/mysql:x:101/mysql:x:${MYSQL_GID}/" /etc/group
chown -R mysql:mysql /var/lib/mysql

# execute pre-init scripts: /docker-entrypoint-preinit.d/*.sh
for f in /docker-entrypoint-preinit.d/*.sh; do
    if [ -s "$f" ]; then
        printf "PRE-INIT: Executing %s\n" "$f"
        if (! /bin/sh "$f"); then
            exit 2
        fi
    fi
done

# create socket file
mkdir -p /run/mysqld > /dev/null 2>&1
touch /run/mysqld/mysqld.dock
chown -R mysql:mysql /run/mysqld

# create database if one does not already exist
if [ -z "$(ls -A /var/lib/mysql/ 2> /dev/null)" ]; then
    # create SQL cmd file
    touch "$sqlCmd"

    # create system tables
    printf "DB-CREATE: Setting up mySQL system tables\n"
    if (! mysql_install_db --user=mysql --ldata=/var/lib/mysql > /dev/null); then
        exit 1
    fi

    # statement to create new SQL database
    printf "DB-CREATE: Generating SQL database create statement for '%s'\n" "$MYSQL_DATABASE"
    printf "CREATE DATABASE IF NOT EXISTS \`%s\` CHARACTER SET %s COLLATE %s;\n" "$MYSQL_DATABASE" "$MYSQL_CHARSET" "$MYSQL_COLLATION" >> "$sqlCmd"

    # statements to:
    # cleanup permissions:
    #   leave root@localhost as root-account integrated,
    #   add root@% with password authentication
    # create SQL user if requested
    # remove 'test' table
    printf "FLUSH PRIVILEGES;\n" >> "$sqlCmd"
    printf "DB-CREATE: Generating SQL permissions statement for 'root@%%'\n"
    printf "GRANT ALL ON *.* TO 'root'@'%%' IDENTIFIED BY '%s' WITH GRANT OPTION;\n" "$MYSQL_ROOT_PASSWORD" >> "$sqlCmd"
    if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
        printf "DB-CREATE: Generating SQL permissions statement for '%s'\n" "$MYSQL_USER"
        printf "GRANT ALL ON \`%s\`.* TO '%s'@'%%' IDENTIFIED BY '%s';\n" "$MYSQL_DATABASE" "$MYSQL_USER" "$MYSQL_PASSWORD" >> "$sqlCmd"
    fi
    printf "DB-CREATE: Generating statement to drop 'test' table\n"
    printf "DROP DATABASE IF EXISTS test;\n" >> "$sqlCmd"
    printf "FLUSH PRIVILEGES;\n" >> "$sqlCmd"

    # execute statements against mariadb and cleanup
    printf "DB-CREATE: Bootstrapping mySQL database\n"
    if (! mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$sqlCmd"); then
        exit 1
    fi
    shred -u "$sqlCmd"
else
    # files exist, ignore the request to create a database
    printf "DB-CREATE: NOT creating %s\n" "$MYSQL_DATABASE"
    printf "DB-CREATE: Using existing database\n"
fi

# process supplied SQL files in /docker-entrypoint-initdb.d/*.(sql|sql.gz)
for f in /docker-entrypoint-initdb.d/*; do
    case "$f" in
        *.sql)
            if [ -s "$f" ]; then
                printf "IMPORT-SQL: Importing %s\n" "$f"
                if (! mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$f"); then
                    exit 3
                fi
                printf "\n"
            fi
            ;;
        *.sql.gz)
            if [ -s "$f" ]; then
                printf "IMPORT-SQL: Importing %s\n" "$f"
                if (! gunzip -c "$f" | mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0); then
                    exit 3
                fi
                printf "\n"
            fi
            ;;
        *)
            ;;
    esac
done

# execute post-init scripts: /docker-entrypoint-postinit.d/*.sh
for f in /docker-entrypoint-postinit.d/*.sh; do
    if [ -s "$f" ]; then
        printf "POST-INIT: Executing %s\n" "$f"
        if (! /bin/sh "$f"); then
            exit 4
        fi
    fi
done

# note initialization complete and display root password
printf "\nInitialization complete...\n"
printf "(mySQL root password: %s)\n\n" "$MYSQL_ROOT_PASSWORD"

# process CMD sent to this container
case "$1" in
    -*)
        # param starts with '-' --> assume mysqld parameter(s) and append to CMD
        set -- /usr/bin/mysqld --user=mysql --console --skip-name-resolve "$@"
        printf "\nExecuting: %s\n" "$*"
        exec "$@"
        ;;
    *)
        # param does NOT start with '-' --> execute as given
        printf "\nExecuting: %s\n" "$@"
        exec "$@"
        ;;
esac

exit 0
#EOF