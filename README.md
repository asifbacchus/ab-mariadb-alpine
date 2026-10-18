# MariaDB on Alpine Linux (dockerized)

Fully functional dockerized installation of MariaDB server and client running on Alpine Linux. This container is roughly
half the size of the official MariaDB container which runs on Ubuntu but still aims to mimic all its features while
adding a few more ;-)

<!-- TOC -->
* [MariaDB on Alpine Linux (dockerized)](#mariadb-on-alpine-linux-dockerized)
  * [Quick Start](#quick-start)
    * [Pull the image](#pull-the-image)
    * [Run the image](#run-the-image)
    * [Create a database](#create-a-database)
      * [Root password](#root-password)
      * [User password](#user-password)
  * [Connecting as a client](#connecting-as-a-client)
    * [Direct-to-Container](#direct-to-container)
    * [Separate Container](#separate-container)
  * [Shell Access](#shell-access)
  * [Checking Logs](#checking-logs)
  * [Environment Variables](#environment-variables)
    * [System-related](#system-related)
    * [MariaDB configuration](#mariadb-configuration)
    * [Database configuration](#database-configuration)
    * [Backup configuration](#backup-configuration)
  * [Root Account](#root-account)
    * [Integrated-account](#integrated-account)
    * [Root-at-any-host](#root-at-any-host)
  * [User account](#user-account)
  * [Data Persistence](#data-persistence)
  * [Data instantiation/import](#data-instantiationimport)
    * [Existing DB (mysql directory)](#existing-db-mysql-directory)
    * [Instantiation](#instantiation)
  * [Custom Scripts](#custom-scripts)
    * [Entrypoint Task Order](#entrypoint-task-order)
  * [Custom Configuration](#custom-configuration)
    * [Command-line parameters](#command-line-parameters)
    * [Configuration file(s)](#configuration-files)
  * [Database dumps](#database-dumps)
  * [Online backups](#online-backups)
    * [Helper-script](#helper-script)
    * [Backup storage](#backup-storage)
    * [Initial setup](#initial-setup)
    * [Full backup](#full-backup)
    * [Incremental backup](#incremental-backup)
    * [Check the names of your backups](#check-the-names-of-your-backups)
  * [Restoring your backups](#restoring-your-backups)
  * [Healthcheck](#healthcheck)
  * [Source](#source)
  * [Script exit codes](#script-exit-codes)
  * [Final Thoughts](#final-thoughts)
<!-- TOC -->

## Quick Start

### Pull the image

The latest images are on my private docker registry. I also try to keep the ones on Dockerhub updated within a few
days.

```sh
# pull from my private repo
docker pull docker.asifbacchus.dev/mariadb/ab-mariadb-alpine:latest

# pull from dockerhub
docker pull asifbacchus/ab-mariadb-alpine:latest
```

The examples in this document will refer to dockerhub, but know that anywhere you
see `asifbacchus/ab-mariadb-alpine:tag` you can use `docker.asifbacchus.app/mariadb/ab-mariadb-alpine:tag` to use my
registry instead.

### Run the image

The image has sensible defaults and can be run without setting many environment variables. In the example below, we will start MariaDB server and create an empty database called 'CompanyX', set a root password and create a user account for Jane Doe which has *full privileges* for the *CompanyX* database. Data will be stored in the named volume 'companyDB'.

```sh
docker run -d \
    -v companyDB:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD='SuPeR$ecurEP@$$w0rd' \
    -e MYSQL_DATABASE='CompanyX' \
    -e MYSQL_USER='JaneDoe' \
    -e MYSQL_PASSWORD='JanesPa$$w0rd' \
    asifbacchus/ab-mariadb-alpine
```

Let's take a quick overview of the options used above:

### Create a database

Assuming an existing database does not exist in the container's data directory already, it will create an empty database for you. The name of this database is controlled by the environment variable `MYSQL_DATABASE`. This defaults to 'myData'. If you would like to create a database called 'CompanyX', for example, you would set the environment variable as follows:

```sh
docker run -d -e MYSQL_DATABASE='CompanyX' asifbacchus/ab-mariadb-alpine
```

#### Root password

If you do not set a root password for mySQL, the container will generate one for you and will display that password in the logs right before MariaDB starts up. To see the password, you will have to access the logs:  `docker logs <container name>`. Then scroll up until you see the password.

In normal usage, you will want to set the root password instead of having it generated for you. This is accomplished by setting the environment variable `MYSQL_ROOT_PASSWORD`. The command would look something like:

```sh
docker run -d -e MYSQL_ROOT_PASSWORD='SuPeR$ecurEP@$$w0rd' asifbacchus/ab-mariadb-alpine
```

#### User password

If you would like a user account created for you with FULL privileges to the database created by the container, you must set two environment variables: `MYSQL_USER` and `MYSQL_PASSWORD`. You can do that as follows:

```sh
docker run -d -e MYSQL_USER='JaneDoe' -e MYSQL_PASSWORD='JanesPa$$w0rd' asifbacchus/ab-mariadb-alpine
```

## Connecting as a client

### Direct-to-Container

You can connect directly to the container, depending on how you have set your permissions. By default, the container allows integrated *root* access via the root account. You can connect this way from your host machine:

```sh
docker exec -it container_name mariadb
```

This will log you into the container using the root account and connect you to MariaDB using that root account without a password since we are taking advantage of the local socket connection. Naturally, you will have to weigh whether retaining this ability is appropriate for your environment. This type of direct access is especially helpful for private networks and for development environments since it is difficult to accidentally lock yourself out.

> [!CAUTION]
> In case the above was not entirely clear: By default, the container allows local (socket) root logins **without a password**. If you do not have strict control over who connects directly to the container, you should disable this or add a password for 'root'@'localhost'.

> [!TIP]
> Starting with `version 2.4.0`, the `MYSQL_USER` generated account is also granted @localhost (socket) login privileges by default. Unlike the integrated root login, the user account requires a password for socket connections.

> [!IMPORTANT]
> Connecting this way is distinct from logging in using the root account with a password. Here, we are implicitly using the account *'root'@'localhost'*. `localhost` is a special address that instructs MariaDB to connect via its unix socket. If you are logging in using root with a password, that account is 'root'@'%' (meaning any host) and is a TCP connection. Thus, you will also have to specify `-h 127.0.0.1`. The full command would be: `docker exec -it container_name mariadb -uroot -p -h 127.0.0.1`. You will then be prompted for the root password.

### Separate Container

You can launch another instance of the container and use that as a client to connect to your server container or any other remote MariaDB/mySQL instance. In this case, we don't want to pass any environment variables, but we want to pass a separate CMD parameter as follows:

```sh
docker run -it --rm asifbacchus/ab-mariadb-alpine mariadb -h mysql.host.tld -u username -p
```

> [!TIP]
> Specifying `-p` without an actual password will cause MariaDB to prompt you for the password. This prevents leaking passwords in the terminal history.

> [!NOTE]
> I used the `--rm` Docker parameter to automatically remove the container on exit. This is optional, but handy in this instance.

## Shell Access

There are times where you will want to connect to your container and access the shell. Most often this is for troubleshooting or verifying settings. Logs are better accessed as outlined in the next section. To access the container's shell, run the following command:

```sh
docker exec -it container_name /bin/sh
```

Please note this is an *Alpine Linux* container so it uses the ASH shell. This is a POSIX-compliant shell that does not have the bells and whistles you may be used to in shells like BASH, etc. Also, Alpine uses BusyBox for most of its commands so some familiar Linux commands may not work as you are used to or may be entirely missing. Notably, however, *ping* is installed and functional in this container.

## Checking Logs

The container logs everything to the console, so the best way to check logs is via the `docker logs` command:

```sh
# get the default look-back period of logs
docker logs container_name

# get the last 50 lines (n can be whatever you like)
docker logs -n50 container_name

# follow log (see realtime updates -- CTRL-C to exit)
docker logs -f container_name

# display the last 5 lines and follow in realtime after that
docker logs -n5 -f container_name
```

## Environment Variables

Most container configuration is achieved via environment variables. We've already encountered some in the Quick Start but I'll reiterate them here for completeness:

### System-related

|Variable|Default|Description|
|---|:---:|---|
|MYSQL_UID|8100|User ID (UID) for the *mysql* user account. Useful when coordinating between your host and the container.|
|MYSQL_GID|8100|Group ID (GID) for the *mysql* user account. Useful when coordinating between your host and the container.|
|TZ|Etc/UTC|Timezone used by the container and, by extension, MariaDB.|

### MariaDB configuration

| Variable                |      Default       | Description                                                                                                                                                                                                                                                                                                                                                                                          |
|-------------------------|:------------------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MYSQL_SKIP_NAME_RESOLVE |        TRUE        | This will tell MariaDB NOT to run reverse DNS lookups on connecting hosts. As a result, user accounts should be defined by IP address versus hostname. This is the default setting for Docker containers since hostnames are generally random and accounts are specified as 'user'@'%'. If you need to use hostnames, set this to 'FALSE' so you can use hostnames in account definitions.           |
| MYSQL_CHARSET           |      utf8mb4       | Character Set for the newly created database. Will NOT affect existing or imported databases.                                                                                                                                                                                                                                                                                                        |
| MYSQL_COLLATION         | utf8mb4_general_ci | Collation rules for the newly created database. Will NOT affect existing or imported databases.                                                                                                                                                                                                                                                                                                      |
| MYSQL_ROOT_PASSWORD     |   auto-generated   | Sets the *root* password for your MariaDB server. If you leave this blank (default) the container will generate a password for you and display it in the logs. In practice, you should really define this yourself. **This will be ignored if you are mounting a volume/directory with an existing database.** Please refer to the [Root Account](#root-account) section for some interesting notes. |

### Database configuration

|Variable|Default|Description|
|---|:---:|---|
|MYSQL_DATABASE|myData|Name of the new database you would like created. If you do not specify anything, a new database called 'myData' will be created. **If you mount a volume/directory with an existing database, this value will be ignored.**|
|MYSQL_USER|*none*|Username of the account to be created and granted *full privileges* on MYSQL_DATABASE. If you do not specify this value, no user account will be created. **This only applies to the MYSQL_DATABASE**|
|MYSQL_PASSWORD|*none*|Password for the account specified by MYSQL_USER. If you do not specify this value, MYSQL_USER will not be created. **This only applies to the MYSQL_DATABASE**|

### Backup configuration

> [!NOTE]
> The following only apply to container `version 2.5.0` and later.

|Variable|Default|Description|
|---|:---:|---|
|BACKUP_USER|backupuser|The username for the backup user|
|BACKUP_USER_PASSWORD|*none*|The password for the backup user|

## Root Account

There are actually two (2) root accounts for this container, and you should carefully review whether your need both or just one.

### Integrated-account

The default setup of the container allows *'root'@'localhost'* to connect without a password using Linux-integrated authentication. In other words, if you are logged into the container as root, you also have root access to the database **without a password**. You can delete this by changing/removing the *'root'@'localhost'* account in the `mysql.user` table using the regular `GRANT` command.

### Root-at-any-host

The container creates a user *'root'@'%'* account using the password as set or auto-generated by `MYSQL_ROOT_PASSWORD`. This account can connect by remote assuming the correct password is used. You may want to change the '%' (any) host to a specific address/hostname, but that is a decision for you as the DB-admin!

## User account

Assuming you set `MYSQL_USER` and `MYSQL_PASSWORD`, the container will create a user account with the specified username and password. This user will have **full** privileges on the `MYSQL_DATABASE`.

> [!IMPORTANT]
> Starting with `version 2.4.0`, this user will have both 'user'@'%' (the same as previous versions) and 'user'@'localhost' accounts. The latter is new and allows for socket connections. Unlike the integrated root account, however, this account still requires a password for socket connections.

## Data Persistence

By default, the container will create a volume to store your MariaDB database so you don't accidentally lose any important information. In this case, the name is auto-generated by docker and is not very user-friendly. If, instead, you would like to use an existing volume, control the name of the created volume or use a bind-mount, you can do so by specifying a mapping to `/var/lib/mysql` in the container. For example:

```sh
# create a volume or use an existing named-volume
docker run -d -v mydatabase:/var/lib/mysql asifbacchus/ab-mariadb-alpine

# use a bind-mount location
docker run -d -v /my/local/dir:/var/lib/mysql asifbacchus/ab-mariadb-alpine
```

## Data instantiation/import

### Existing DB (mysql directory)

The entrypoint script of the container checks to see if the `/var/lib/mysql` directory is empty and, if so, creates a new database for you. Thus, if you want to import an existing database, you simply have to mount a valid *mysql* subdirectory:

```sh
# bind-mount an existing directory
docker run -d -v /existing/mysql:/var/lib/mysql asifbacchus/ab-mariadb-alpine

# mount a volume with mysql data
docker run -d -v mydatabase:/var/lib/mysql asifbacchus/ab-mariadb-alpine
```

### Instantiation

If you want to 'instantiate' your newly created database (add tables, some default data, set privileges, etc.) then you can import SQL files with commands preloaded. Any `.sql` or `.sql.gz` files mounted in the container's `/docker-entrypoint-initdb.d` folder will be imported after the new database is created.

```sh
docker run -d -v /sql/import/scripts:/docker-entrypoint-initdb.d asifbacchus/ab-mariadb-alpine
```

You should review the logs when doing this to see if MariaDB throws any errors due to syntax errors or other mistakes in your SQL files. An easy way to do this is:

```sh
docker run -d --name db \
  -v /sql/import/scripts:/docker-entrypoint-initdb.d \
  asifbacchus/ab-mariadb-alpine \
  && docker logs -f db
```

You can, of course, name your container anything you like. Change `db` in both places to whatever you choose.

## Custom Scripts

You can run custom scripts for whatever reason before and after MariaDB initialization by importing them into your container in the appropriate location.

To run scripts before MariaDB is initialized (i.e. before a database is created), mount your scripts in `/docker-entrypoint-preinit.d`.

To run scripts after MariaDB is initialized (i.e. after a database is created and SQL files are imported) but right before *mariadbd* is started, mount your scripts in `/docker-entrypoint-postinit.d`.

```sh
docker run -d \
    -v /my/pre-init/scripts:/docker-entrypoint-preinit.d \
    -v /my/post-init/scripts:/docker-entrypoint-postinit.d \
    asifbacchus/ab-mariadb-alpine
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
9. Start *mariadbd*

## Custom Configuration

### Command-line parameters

You can pass MariaDB command-line parameters to your container just as you would with a regular `mariadbd` instance. For example:

```sh
docker run -d asifbacchus/ab-mariadb-alpine --innodb-ft-min-token-size=2
```

The container will concatenate any parameters you supply with the default ones of `--console --user=mysql`.

> [!CAUTION]
> Command-line parameters override environment variable parameters supplied to the container.

### Configuration file(s)

If you would like to use a completely custom MariaDB configuration, you will need to mount your configuration files in the proper locations. In most cases, it's easiest to just load a single `/etc/my.cnf` file. If you want to use a multi-directory/multi-file format, I would still suggest creating a `/etc/my.cnf` file and pointing to the other locations within that file. If you only want to change a few server-related parameters, you can add files to the `/etc/my.cnf.d/` directory.

```sh
# mount a custom my.cnf
docker run -d \
    -v /mysql/configuration/my.cnf:/etc/my.cnf \
    asifbacchus/ab-mariadb-alpine

# custom server-related files
docker run -d \
    -v /mysql/server-config:/etc/my.cnf.d \
    asifbacchus/ab-mariadb-alpine

# complex configuration using custom my.cnf
# this completely depends on how you specify things in my.cnf
docker run -d \
    -v /mysql/config/my.cnf:/etc/my.cnf \
    -v /mysql/other-config:/etc/mysql/some-directory \
    -v /mysql/more-configs:/etc/mysql/cnf/another-dir \
    asifbacchus/ab-mariadb-alpine
```

You should be aware that the container passes `--console --user=mysql` command-line parameters to `mariadbd` by default. This could _override_ parameters specified in your custom `my.cnf` or any other configuration file. To avoid any issues this may cause, you should pass the `mariadbd` command manually:

```sh
docker run -d \
    -v /mysql/configuration/my.cnf:/etc/my.cnf \
    asifbacchus/ab-mariadb-alpine \
    /usr/bin/mariadbd --user=anotheruser
```

The above command would run the process forked into the background (why you would do this, I'm not sure) and would run as 'anotheruser'. **This is a contrived example for illustration purposes only.**

## Database dumps

This is exactly the same as the official container. I will repeat their instructions here for completeness and add a few more examples to make things clearer.

**Creating dumps** can be done using `docker exec` and will be written to the *host* machine. It is easiest to take advantage of root-integrated access for operations like this.

> [!TIP]
> This is possibly the single best reason to keep root-integrated access to your container. It allows you to perform operations like database dumps and restores without having to worry about permissions or user authentication. However, you still should consider the security implications of such integrated passwordless authentication. 

```sh
# dump all databases -- root-integrated access
docker exec container_name /bin/sh -c 'mariadb-dump --all-databases' >/local/path/mySQLdumps/all_databases.sql

# dump selected databases -- remote-root access
docker exec container_name /bin/sh -c 'mariadb-dump -uroot -p"SuPeR$ecurEP@$$w0rd" --databases myData otherDB' >/local/path/mySQLdumps/multiple.sql

# dump 'myData' database -- user access (assuming permissions are correct)
docker exec container_name /bin/sh -c 'mariadb-dump -uusername -p"password" --database myData' >/local/path/mySQLdumps/myData.sql
```

**Restoring dumps** can also be done using `docker exec`. Again, this is easiest using root-integrated authentication.

```sh
# restore using root-integrated authentication
docker exec -it container_name /bin/sh -c 'mariadb' </local/path/mySQLdumps/filename.sql

# restore using username and password (e.g. root)
docker exec -it container_name /bin/sh -c 'mariadb -uroot -p"SuPeR$ecurEP@$$w0rd"' </local/path/mySQLdumps/filename.sql
```

## Online backups

> [!NOTE]
> This section only applies to container `version 2.4.0` or newer.

Starting with container version `2.4.0`, `mariadb-backup` is now available as a command within the container. Full details and usage examples can be found in the [MariaDB documentation](https://mariadb.com/docs/server/server-usage/backup-and-restore/mariadb-backup).

### Helper-script

Starting with version `2.5.0`, the container now includes a helper script that executes online backups using `mariadb-backup`. The `online-backup` command/script is a convenient way to execute backups from host-scripts or other containers since it can safely run everything as root via local-socket connections or use a dedicated _limited @localhost user_.

You can refer to the embedded help within the script by running the following command:

```sh
docker exec container_name online-backup --help
```

> [!NOTE]
> The `online-backup` script is provided as a convenience for common use-cases. For more advanced use-cases, you may want to use the `mariadb-backup` command directly.

When using the `online-backup` script, it is recommended that you set the `BACKUP_USER` and `BACKUP_USER_PASSWORD` environment
variables to avoid having to provide a username and password with each command.

### Backup storage

Backups are stored and read from `/var/mariadb/backup`. As such, it is **strongly** recommended you mount a named volume or bind-mount a directory to this location if you plan on using the integrated backup options provided by this container. 

> [!CAUTION]
> If you do not provide a named volume or bind-mount, an anonymous mount will be created by the container. However, anonymous mounts do not guarantee data persistence! Ensure you mount a volume or bind-mount to `/var/mariadb/backup` to avoid losing your backups! If using a bind-mount, ensure the container's `mysql` user can read/write to the mounted directory.

### Initial setup

If your database does not already have a `mysql.mariadb_backup_history` table, you can add it easily with the following command:

```sh
docker exec container_name add-backup-history-table
```

> [!NOTE]
> If your database was created by this container, you still have to run the above command.

> [!TIP]
> This command is non-destrutive and only creates the table if it does not already exist. Thus, you can safely run this command multiple times without damaging your database.

Following this, you will want to grant the necessary privileges to at least one user so they can perform online backups. By default, `root` has all necessary privileges, but using the database root account is considered a bad practice.

```sh
# create/enable the BACKUP_USER account and set privileges
docker exec container_name enable-backup-user

# create/enable a new user and set privileges
docker exec container_name enable-backup-user -u username -p password

# set privileges for an existing user
docker exec container_name enable-backup-user -u username
```

Finally, verify privileges have been set correctly by running the following command:

```sh
docker exec container_name enable-backup-user -u username --check
```

You should see `RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR` privileges for `*.*` for the selected user. You should also see `SELECT, INSERT, CREATE, ALTER` ON `mysql.mariadb_backup_history` for the selected user. All permissions should be for **'user'@'localhost'**.

> [!TIP]
> You can run `docker exec container_name enable-backup-user --help` to see all script options.

### Full backup

A full backup is the default option for the `online-backup` command. It is recommended you provide a backup name (label) as per the `mariadb-backup` documentation, but if you don't, one will be generated automatically for you using the current timestamp. The backup will be stored in an auto-generated timestamped subdirectory of `/var/mariadb/backup` within the container.

> [!IMPORTANT]
> Please ensure at least one user has appropriate privileges to run an online-backup as per the [Initial Setup](#initial-setup) section above. If you skip that step, your backup will fail.

```sh
# use the default backup account and auto-generated backup label
docker exec container_name online-backup

# use the specified account and auto-generated backup label
docker exec container_name online-backup -u username -p "MyPa$$word"

# use the default backup account and specify a backup label
docker exec container_name online-backup --name "my-backup-label"
```

> [!TIP]
> You can see all available backup parameters by running `docker exec container_name online-backup --help`

### Incremental backup

You must complete at least one full backup before running an incremental backup. The options are similar to a full backup, except that you must provide a `base-name` upon which this incremental backup is based. The `base-name` can refer to either a full backup or a previous incremental backup. In addition, it is recommended you provide a name (label) for this backup, especially if other incremental backups will be based on it.

```sh
# use the default backup account
docker exec container_name online-backup --incremental --base-name "my-full-backup" --name "incremental__1"

# create an incremental backup based on the one above
docker exec container_name online-backup -i --base-name "incremental__1" -n "incremental__2"
```

> [!TIP]
> I hope even this brief example shows why supplying a useful name (label) makes things easier instead of relying on the auto-generated timestamp labels.


> [!TIP]
> You can see all available backup parameters by running `docker exec container_name online-backup --help`

### Check the names of your backups

Especially when working with incremental backups, it is useful to know the names of previous backups.

```sh
docker exec container-name show-backup-history
```

You should see a tabular list of backups sorted by date in descending order and secondarily sorted by LSN information. If there are no backups in the logs, the command will exit with an error.

## Restoring your backups

While this container provides scripts for making backups easier, it does not (yet) provide scripts for restoring your backups. This is partly because I haven't decided how I want to implement this feature, and partly because restoring backups can get very complicated based on individual configurations and deployments. In my opinion, it is easier and more flexible to restore your backups manually using `mariadb-backup` and the [relevant documentation](https://mariadb.com/docs/server/server-usage/backup-and-restore/mariadb-backup).

> [!WARNING]
> The `online-backup` script only saves the backup files. It **does NOT** `prepare` the backup files. You MUST `prepare` them as per the documentation before attempting to restore them.

## Healthcheck

Starting with `version 2.0`, I've added a very basic healthcheck to the container. It checks that the `mariadbd` (`mysqld`) daemon is running in the container and accepting connections. It **does NOT** check anything to do with the actual database. As such, you may want to override this with a more specific healthcheck for your particular use-case. If you just need to know MariaDB is actually running, this healthcheck will work just fine.

If anyone has suggestions for a better healthcheck, PLEASE let me know!

## Source

The source for this container build (Dockerfile, entrypoint.sh) are available on my [private git repo](https://git.asifbacchus.app/ab-docker/mariadb-alpine) or on [GitHub](https://github.com/asifbacchus/ab-mariadb-alpine.git). Note that the newest versions will be on my repo and GitHub will be updated at most a few days later. Also, I'd prefer issues be filed on my repo, but I understand if GitHub is easier/more familiar for you.

## Script exit codes

Starting with `version 2.4.0`, exit codes for all helper-scripts have been coordinated. If you run into an error or need to trap errors in your deployment, please run the following command to get a description of all script exit codes:

```sh
docker exec container_name show-exit-codes
```

## Final Thoughts

I hope this container is useful to you and helps you run a database where memory may be at a premium. I do my best to make sure everything runs properly and as much like the official container as possible. If you find any bugs, implementation issues or have any suggestions, please file an issue and let me know! I am *NOT* affiliated with MariaDB in any way and this container is strictly my implementation of their software. Please **do not** bother them with any issues you have with this container, let me know instead! Happy dockerizing :-)