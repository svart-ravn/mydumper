# mydumper
mydumper built over 5.7.13.

How to:
- wget from https://launchpad.net/mydumper/+download
- copy hash.h from mysql sources to /usr/include
- apt-get install libglib2.0-dev libmysqlclient-dev libmysqlclient18 zlib1g-dev libpcre3-dev libssl-dev build-essential
- untar sources
- cmake . && make && make install

If you will face issue: MySQL not found then go to #4


## backup_tool.sh

sample call:
> ./backup_tool.sh -p /mnt/backups/mysql_backups
````
- searching for a folder started with "current_" in mentioned path
- if not found or found empty folder then it starts full backup
- else starting incremental backup. which will be immediately applied on full backup

can be restored
- --copy-back
- rm -r @@datadir; cp -R /path/to/backup @@datadir
````
