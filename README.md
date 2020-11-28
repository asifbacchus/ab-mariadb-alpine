# MariaDB on Alpine Linux (dockerized)

Fully functional dockerized installation of MariaDB server and client running on Alpine Linux. This container is roughly half the size of the official MariaDB container which runs on Ubuntu but still aims to mimic all its features while adding a few extra ;-)

- [Quick Start](#quick-start)
  - [Pull the image](#pull-the-image)
  - [Run the image](#run-the-image)
  - [Create a database](#create-a-database)
    - [Root password](#root-password)
    - [User password](#user-password)
- [Connecting as a client](#connecting-as-a-client)
  - [Direct-to-Container](#direct-to-container)
  - [Separate Container](#separate-container)
- [Shell Access](#shell-access)
- [Checking Logs](#checking-logs)
- [Environment Variables](#environment-variables)
  - [System-related](#system-related)
  - [MariaDB configuration](#mariadb-configuration)
  - [Database configuration](#database-configuration)
- [Root Account](#root-account)
  - [Integrated-account](#integrated-account)
  - [Root-at-any-host](#root-at-any-host)
- [Data Persistence](#data-persistence)
- [Data instantiation/import](#data-instantiationimport)
  - [Existing DB (mysql directory)](#existing-db-mysql-directory)
  - [Instantiation](#instantiation)
- [Custom Scripts](#custom-scripts)
  - [Entrypoint Task Order](#entrypoint-task-order)
- [Custom Configuration](#custom-configuration)
  - [Command-line parameters](#command-line-parameters)
  - [Configuration file(s)](#configuration-files)
- [Database dumps](#database-dumps)
- [Source](#source)
- [Final Thoughts](#final-thoughts)

## Quick Start

### Pull the image

The latest images are on my private Docker Repo but I also try to keep the ones on Dockerhub updated within a few days. As such, you have two choices:

```bash
# my private repo
docker pull docker.asifbacchus.app/mariadb/ab-mariadb-alpine:latest
```

or

```bash
# dockerhub
docker pull asifbacchus/ab-mariadb-alpine:latest
```

All the examples in this document will refer to my repo, but you can use Dockerhub if you prefer.

### Run the image

The image has sensible defaults and can be run without setting many environment variables. In the example below, we will start MariaDB server and create an empty database called 'CompanyX', set a root password and create a user account for Jane Doe which has *full privileges* for the *CompanyX* database. Data will be stored in the named volume 'companyDB'.

```bash
docker run -d \
    -v companyDB:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD='SuPeR$ecurEP@$$w0rd' \
    -e MYSQL_DATABASE='CompanyX' \
    -e MYSQL_USER='JaneDoe' \
    -e MYSQL_PASSWORD='JanesPa$$w0rd' \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

Let's take a quick overview of the options used above:

### Create a database

Assuming an existing database does not exist in the container's data directory already, it will create an empty database for you. The name of this database is controlled by the environment variable `MYSQL_DATABASE`. This defaults to 'myData'. If you would like to create a database called 'CompanyX', for example, you would set the environment variable as follows:

```bash
docker run -d -e MYSQL_DATABASE='CompanyX' docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

#### Root password

If you do not set a root password for mySQL, the container will generate one for you and will display that password in the logs right before MariaDB starts up. To see the password, you will have to access the logs:  `docker logs <container name>`. Then scroll up until you see the password.

In normal usage, you will want to set the root password instead of having it generated for you. This is accomplished by setting the environment variable `MYSQL_ROOT_PASSWORD`. The command would look something like:

```bash
docker run -d -e MYSQL_ROOT_PASSWORD='SuPeR$ecurEP@$$w0rd' docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

#### User password

If you would like a user account created for you with FULL privileges to the database created by the container, you must set two environment variables: `MYSQL_USER` and `MYSQL_PASSWORD`. You can do that as follows:

```bash
docker run -d -e MYSQL_USER='JaneDoe' -e MYSQL_PASSWORD='JanesPa$$w0rd' docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

## Connecting as a client

### Direct-to-Container

You can connect directly to the container, depending on how you have set your permissions. By default, the container allows integrated *root* access via the root account. You can connect this way from your host machine:

```bash
docker exec -it container_name mysql
```

This will log you into the container using the root account and connect you to MariaDB using that root account without a password. Naturally, you will have to weigh whether or not retaining this ability is appropriate for your environment, but it is very helpful when testing/developing or learning about MariaDB/mySQL since you actively have to try to lock yourself out.

*N.B.* Connecting this way is distinct from logging in using the root account with a password. Here, we are using the account *'root'@'localhost'* whereas using the one with a password (even the one created by this container) is *'root'@'%'*.

### Separate Container

You can launch another instance of the container and use that as a client to connect to your server container or any other remote MariaDB/mySQL instance. In this case, we don't want to pass any environment variables, but we want to pass a separate CMD parameter as follows:

```bash
docker run -it --rm docker.asifbacchus.app/mariadb/ab-mariadb-alpine mysql -hmysql.host.tld -uusername -ppassword
```

**N.B.* I used the `--rm` Docker parameter to automatically remove the container on exit. This is optional.

## Shell Access

There are times where you will want to connect to your container and access the shell. Most often this is for troubleshooting or verifying settings. Logs are better accessed as outlined in the next section. To access the container's shell, run the following command:

```bash
docker exec -it container_name /bin/sh
```

Please note this is an *Alpine Linux* container so it uses the ASH shell. This is a POSIX-compliant shell that does not have the bells and whistles you may be used to in shells like BASH, etc. Also, Alpine uses BusyBox for most of its commands so some familiar Linux commands may not work as you are used to or may be entirely missing. Notably, however, *ping* is installed and functional in this container.

## Checking Logs

The container logs everything to the console, so the best way to check logs is via the `docker logs` command:

```bash
# get default look-back period of logs
docker logs container_name

# get last 50 lines (n can be whatever you like)
docker logs -n50 container_name

# follow log (see realtime updates -- CTRL-C to exit)
docker logs -f container_name

# display the last 5 lines and follow in realtime after that
docker logs -n5 -f container_name
```

## Environment Variables

Most container configuration is accomplished via environment variables. We've already encountered some in the Quick Start but I'll reiterate them here for completeness:

### System-related

|Variable|Default|Description|
|---|:---:|---|
|MYSQL_UID|8100|User ID (UID) for the *mysql* user account. Useful when coordinating between your host and the container.|
|MYSQL_GID|8100|Group ID (GID) for the *mysql* user account. Useful when coordinating between your host and the container.|
|TZ|Etc/UTC|Timezone used by the container and, by extension, MariaDB.|

### MariaDB configuration

|Variable|Default|Description|
|---|:---:|---|
MYSQL_SKIP_NAME_RESOLVE|TRUE|This will tell MariaDB NOT to run reverse DNS lookups on connecting hosts. As a result, user accounts should be defined by IP address versus hostname. This is the default setting for Docker containers since hostnames are generally random and accounts are specified as 'user'@'%'. If you need to use hostnames, set this to 'FALSE' so you can use hostnames in account definitions.|
|MYSQL_CHARSET|utf8mb4|Character Set for the newly created database. Will NOT affect existing or imported databases.|
|MYSQL_COLLATION|utf8mb4_general_ci|Collation rules for the newly created database. Will NOT affect existing or imported databases.|
|MYSQL_ROOT_PASSWORD|auto-generated|Sets the *root* password for your MariaDB server. If you leave this blank (default) the container will generate a password for you and display it in the logs. In practice, you should really define this yourself. **This will be ignored if you are mounting a volume/directory with an existing database.** Please refer to the [Root Account](#root-account) section for some interesting notes.|

### Database configuration

|Variable|Default|Description|
|---|:---:|---|
|MYSQL_DATABASE|myData|Name of the new database you would like created. If you do not specify anything, a new database called 'myData' will be created. **If you mount a volume/directory with an existing database, this value will be ignored.**|
|MYSQL_USER|*none*|Username of the account to be created and granted *full privileges* on MYSQL_DATABASE. If you do not specify this value, no user account will be created. **This only applies to the MYSQL_DATABASE**|
|MYSQL_PASSWORD|*none*|Password for the account specified by MYSQL_USER. If you do not specify this value, MYSQL_USER will not be created. **This only applies to the MYSQL_DATABASE**|

## Root Account

There are actually two (2) root accounts for this container and you should carefully review whether your need both or just one.

### Integrated-account

The default setup of the container allows *'root'@'localhost'* to connect without a password using Linux-integrated authentication. In other words, if you are logged into the container as root, you also have root access to the database **without a password**. You can delete this by changing/removing the *root@localhost* account in the mysql.user container using the regular GRANT command.

### Root-at-any-host

The container creates a user *'root'@'%'* account using the password as set or auto-generated by MYSQL_ROOT_PASSWORD. This account can connect by remote assuming the correct password is used. You may want to change the '%' (any) host to a specific address/hostname, but that is a decision for you as the DB-admin!

## Data Persistence

By default, the container will create a volume to store your mySQL database so you don't accidentally lose any important information. In this case, the name is auto-generated by docker and is not very user-friendly. If, instead, you would like to use an existing volume, control the name of the created volume or use a bind-mount, you can do so by specifying a mapping to */var/lib/mysql* in the container. For example:

```bash
# create a volume or use an existing named-volume
docker run -d -v mydatabase:/var/lib/mysql docker.asifbacchus.app/mariadb/ab-mariadb-alpine

# use a bind-mount location
docker run -d -v /my/local/dir:/var/lib/mysql docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

## Data instantiation/import

### Existing DB (mysql directory)

The entrypoint script of the container simply checks to see if the */var/lib/mysql* directory is empty and, if so, creates a new database for you. Thus, if you want to import an existing database, you simply have to mount a valid *mysql* subdirectory:

```bash
docker run -d -v /existing/mysql:/var/lib/mysql docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

### Instantiation

If you want to 'instantiate' your newly created database (add tables, some default data, set privileges, etc.) then you can import SQL files with commands preloaded. Any *.sql* or *.sql.gz* files mounted in the container's */docker-entrypoint-initdb.d* folder will be imported after the new database is created.

```bash
docker run -d -v /sql/import/scripts:/docker-entrypoint-initdb.d docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

You should review the logs when doing this to see if MariaDB throws any errors due to syntax errors or other mistakes in your SQL files. An easy way to do this is:

```bash
docker run -d --name db -v /sql/import/scripts:/docker-entrypoint-initdb.d docker.asifbacchus.app/mariadb/ab-mariadb-alpine && docker logs -f db
```

You can, of course, name your container anything you like. Just change *'db'* in both places to whatever you choose.

## Custom Scripts

You can run custom scripts for whatever reason before and after MariaDB initialization by importing them into your container in the appropriate location.

To run scripts before MariaDB is initialized (i.e. before a database is created), simply mount your scripts in */docker-entrypoint-preinit.d*.

To run scripts after MariaDB is initialized (i.e. after a database is created and SQL files are imported) but right before *mysqld* is started, simply mount your scripts in */docker-entrypoint-postinit.d*.

```bash
docker run -d \
    -v /my/pre-init/scripts:/docker-entrypoint-preinit.d \
    -v /my/post-init/scripts:/docker-entrypoint-postinit.d \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

### Entrypoint Task Order

For reference, the sequence of events in the entrypoint script is:

1. Verify environment variables
2. Change mysql UID/GID
3. Update mysql configuration file
4. **Execute pre-init scripts**
5. Create runtime PID file
6. Create database if one does not exist
    - Create system tables
    - Create database
    - Add root account and set permissions
    - Add user account if necessary
    - Drop default 'test' table
7. Import SQL files if they exist
8. **Execute post-init scripts**
9. Start *mysqld*

## Custom Configuration

### Command-line parameters

You can pass MariaDB command-line parameters to your container just as your would with a regular *mysqld* instance. For example:

```bash
docker run -d docker.asifbacchus.app/mariadb/ab-mariadb-alpine --innodb-ft-min-token-size=2
```

The container will concatenate any parameters your supply with the default ones of *--console --user=mysql*. Note that command-line parameters override environment variable parameters supplied to the container.

### Configuration file(s)

If you would like to use a completely custom MariaDB configuration you will need to mount your configuration files in the proper locations. In most cases, it's easiest to just load a single */etc/my.cnf* file. If you want to use a multi-directory/multi-file format, I would still suggest creating a */etc/my.cnf* file and pointing to the other locations within that file. If you only want to change a few server-related parameters, you can add files to the */etc/my.cnf.d/* directory.

```bash
# custom my.cnf
docker run -d \
    -v /mysql/configuration/my.cnf:/etc/my.cnf \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine

# custom server-related files
docker run -d \
    -v /mysql/server-config:/etc/my.cnf.d \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine

# complex configuration using custom my.cnf
# this completely depends on how you specify things in my.cnf
docker run -d \
    -v /mysql/config/my.cnf:/etc/my.cnf \
    -v /mysql/other-config:/etc/mysql/some-directory \
    -v /mysql/more-configs:/etc/mysql/cnf/another-dir \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine
```

You should be aware that the container passes *'--console --user=mysql'* command-line parameters to *mysqld* by default and that will override parameters specified in *my.cnf* or any other configuration file. If you need to override these defaults, you will have to pass the *mysqld* command manually:

```bash
docker run -d \
    -v /mysql/configuration/my.cnf:/etc/my.cnf \
    docker.asifbacchus.app/mariadb/ab-mariadb-alpine \
    mysqld --user=anotheruser
```

The above command would run the process forked into the background (why you would do this, I'm not sure) and would run as 'anotheruser'. This is a contrived example for illustration purposes only.

## Database dumps

This is exactly the same as the official container. I will repeat their instructions here for completeness and add a few more examples to make things clearer.

**Creating dumps** can be done using `docker exec` and will be written to the *host* machine. It is easiest to take advantage of root-integrated access for operations like this.

```bash
# dump all databases -- root-integrated access
docker exec container_name /bin/sh -c 'exec mysqldump --all-databases' > /local/path/mySQLdumps/all_databases.sql

# dump selected databases -- remote-root access
docker exec container_name /bin/sh -c 'exec mysqldump -uroot -p"SuPeR$ecurEP@$$w0rd" --databases myData otherDB' > /local/path/mySQLdumps/multiple.sql

# dump 'myData' database -- user access (assuming permissions are correct)
docker exec container_name /bin/sh -c 'exec mysqldump -uusername -p"password" --database myData' > /local/path/mySQLdumps/myData.sql
```

**Restoring dumps** can also be done using `docker exec`. Again, this is easiest using root-integrated authentication.

```bash
# restore using root-integrated authentication
docker exec -it container_name /bin/sh -c 'exec mysql' < /local/path/mySQLdumps/filename.sql

# restore using username and password (e.g. root)
docker exec -it container_name /bin/sh -c 'exec mysql -uroot -p"SuPeR$ecurEP@$$w0rd"' < /local/path/mySQLdumps/filename.sql
```

## Source

The source for this container build (Dockerfile, entrypoint.sh) are available on my [private git repo](https://git.asifbacchus.app/ab-docker/mariadb-alpine) or on [GitHub](https://github.com/asifbacchus/mariadb-alpine). Note that the newest versions will be on my repo and GitHub will be updated at most a few days later. Also, I'd prefer issues be filed on my repo, but I understand if GitHub is easier/more familiar for you.

## Final Thoughts

I hope this container is useful to you and helps you run a database where memory may be at a premium. I do my best to make sure everything runs properly and as much like the official container as possible. If you find any bugs, implementation issues or have any suggestions, please file an issue and let me know! I am *NOT* affiliated with MariaDB in any way and this container is strictly my implementation of their software. Please **do not** bother them with any issues you have with this container, let me know instead! Happy dockerizing :-)
