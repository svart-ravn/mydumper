# mydumper
mydumper builded over 5.7.13.

How to:
- wget from https://launchpad.net/mydumper/+download
- copy hash.h from mysql sources to /usr/include
- apt-get install libglib2.0-dev libmysqlclient-dev libmysqlclient18 zlib1g-dev libpcre3-dev libssl-dev build-essential
- untar sources
- cmake . && make && make install

If you will face issue: MySQL not found then go to #4
