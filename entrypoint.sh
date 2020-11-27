#!/bin/sh
#
### entrypoint script for mariadb container
#

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
        /bin/sh "$f"
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
    mysql_install_db --user=mysql --ldata=/var/lib/mysql > /dev/null

    # statement to create new SQL database
    printf "DB-CREATE: Generating SQL database create statement for '%s'\n" "$MYSQL_DATABASE"
    echo "CREATE DATABASE IF NOT EXISTS '$MYSQL_DATABASE' CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> "$sqlCmd"

    # statements to:
    # cleanup permissions:
    #   leave root@localhost as root-account integrated,
    #   add root@% with password authentication
    # create SQL user if requested
    # remove 'test' table
    echo 'USE mysql;' >> "$sqlCmd"
    echo 'FLUSH PRIVILEGES;' >> "$sqlCmd"
    printf "DB-CREATE: Generating SQL permissions statement for 'root@%%'\n"
    echo "GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION;" >> "$sqlCmd"
    if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
        printf "DB-CREATE: Generating SQL permissions statement for '%s'\n" "$MYSQL_USER"
        echo "GRANT ALL ON '$MYSQL_DATABASE'.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$sqlCmd"
    fi
    printf "DB-CREATE: Generating statement to drop 'test' table\n"
    echo 'DROP DATABASE IF EXISTS test;' >> "$sqlCmd"
    echo 'FLUSH PRIVILEGES;' >> "$sqlCmd"

    # execute statements against mariadb and cleanup
    printf "DB-CREATE: Bootstrapping mySQL database\n"
    mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$sqlCmd"
    rm -f "$sqlCmd"
else
    # files exist, ignore the request to create a database
    printf "DB-CREATE: NOT creating %s\n" "$MYSQL_DATABASE"
    printf "DB-CREATE: Using existing database\n"
fi

# process supplied SQL files in /docker-entrypoint-initdb.d/*.(sql|sql.gz)
for f in /docker-entrypoint-initdb.d/*.sh; do
    case "$f" in
        *.sql)
            if [ -s "$f" ]; then
                printf "IMPORT-SQL: Importing %s\n" "$f"
                mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$f"
                printf "\n"
            fi
            ;;
        *.sql.gz)
            if [ -s "$f" ]; then
                printf "IMPORT-SQL: Importing %s\n" "$f"
                gunzip -c "$f" | mysqld --user=mysql --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0
                printf "\n"
            fi
            ;;
        *)
            printf "IMPORT-SQL: Cannot import %s\n" "$f"
            ;;
    esac
done

# execute post-init scripts: /docker-entrypoint-postinit.d/*.sh
for f in /docker-entrypoint-postinit.d/*.sh; do
    if [ -s "$f" ]; then
        printf "POST-INIT: Executing %s\n" "$f"
        /bin/sh "$f"
    fi
done

# execute commands passed to this container
printf "\nInitialization complete... Container ready...\n"
exec "$@"

#EOF