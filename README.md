Tonto, silly IP monitoring
==========================

The basic idea of tonto is: you write the list of IP numbers you want to monitor,
and tonto does the rest.

What does tonto do?
-------------------

Tonto gets a list of hosts (HOSTS variable) and pings each of them, if a host does
not respond it will send and alert (to EMAIL variable), it will also notify when the
host is responsive again.  It will also keep a log file with this information and
response times (RTT) from ping.

Additionally, if RRDTOOL is available, it will save all this information (RTT and
packet loss) in an RRD database file, and create a pretty graph every 5 minutes.

How do I install tonto?
-----------------------

1. Make sure you install all dependencies:

    ```shell
    apt-get update
    apt-get install iputils-ping rrdtool git mailutils
    ```

2. Clone GIT repository

    ```shell
    cd /opt
    git clone https://github.com/kastakhov/tonto.git
    ```

3. Create user for tonto service:

    ```shell
    addgroup --system tonto
    adduser --system --shell /usr/sbin/nologin --home /opt/tonto --group tonto --no-create-home tonto
    chown -R tonto:tonto /opt/tonto
    ```

4. Create config file from sample:

    ```shell
    cp /opt/tonto/tonto.config.sh.sample /opt/tonto/tonto.config.sh
    ```

5. Copy crontab file or systemd units to run service every one minute

    5.1 crontab

    ```shell
    cp /opt/tonto/tonto.cron.sample /etc/cron.d/tonto
    ```

    5.2 systemd:

    ```shell
    cp /opt/tonto/systemd/* /usr/lib/systemd/system/
    systemctl enable --now tonto.timer
    ```

How do I configure tonto?
-------------------------

Use tonto.config.sh to configure all options, you basically need to set the dict HOSTS with the lists of hosts and its names
you want to monitor, and the EMAIL address you want to get the alerts.

```shell
HOSTS=(["192.168.0.1"]="192.168.0.1")
HOSTS+=(["192.168.0.2"]="home")
HOSTS+=(["192.168.0.3"]="site")
EMAIL_TO=bob@example.com
```

Other options available include ping deadline, ping packet count, etc.
