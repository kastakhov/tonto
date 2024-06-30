#!/usr/bin/bash

#
# silly ip monitoring + rrd
#

LOG=`dirname $0`/log
WWW=`dirname $0`/tonto
HEADER=`dirname $0`/header.html
FOOTER=`dirname $0`/footer.html

if [ ! -f `dirname $0`/tonto.config.sh ]; then
	echo "Please create tonto.config.sh from tonto.config.sh.sample"
	exit 1
fi

source `dirname $0`/tonto.config.sh
mkdir -p $LOG
mkdir -p $WWW

# first time?
if [ ! -f $LOG/LASTTIME ]; then
	touch $LOG/LASTTIME
fi

# graph if 5 minutes have passed by since last run
graph=0
touch -d "$(date -d '5 minutes ago')" $LOG/5MINUTES
if [ $LOG/LASTTIME -ot $LOG/5MINUTES ]; then
	touch $LOG/LASTTIME
	graph=1
	HTML="<small>Last updated `date`</small>"
fi

# loop
for ip in "${!HOSTS[@]}"; do
	ip_desc=${HOSTS[$ip]}

	# create RRD file
	if [ ! -f $LOG/$ip.rrd ] && [ -n $RRDTOOL ] ; then
		$RRDTOOL create $LOG/$ip.rrd -s 60 \
		DS:loss:GAUGE:120:0:100 \
		DS:rtt:GAUGE:120:0:65535 \
		RRA:AVERAGE:0.5:1:2880
	fi

	date=`date +%Y%m%d%H%M%S`
	#rtt=`$PING -c $PING_COUNT -w $PING_DEADLINE $ip | tail -1| awk -F '/' '{print $5}'`
	lines=`$PING -c $PING_COUNT -w $PING_DEADLINE $ip | grep -E 'packet loss|rtt'`
	rtt=`echo $lines | grep rtt | cut -f 5 -d '/'`
	loss=`echo $lines | grep loss | cut -f 6 -d ' ' | tr -d '%'`
	#echo "$ip RC = $rc RT = $rtt PL = $loss"
	if [ -z $rtt ]; then
		rtt=0
		rc_str="FAILED"
		if [ -f $LOG/$ip.up ]; then
			echo "$ip DOWN" | mail -s "${EMAIL_SUB} ${ip_desc}" "$EMAIL_TO"
			rm $LOG/$ip.up
		fi
		touch $LOG/$ip.down
	else
		rc_str="OK"
		if [ -f $LOG/$ip.down ]; then
			echo "$ip UP" | mail -s "${EMAIL_SUB} ${ip_desc}" "$EMAIL_TO"
			rm $LOG/$ip.down
		fi
		touch $LOG/$ip.up
	fi

	# update RRD file
	if [ -f $LOG/$ip.rrd ] && [ -n $RRDTOOL ]; then
		$RRDTOOL update $LOG/$ip.rrd --template loss:rtt N:$loss:$rtt
	fi

	if [ $graph == 1 ]; then
		$RRDTOOL graph $WWW/$ip.png \
		-w 785 -h 120 -a PNG --slope-mode --start -86400 --end now --font DEFAULT:7: \
		--title "ping $ip" --watermark "`date`" --vertical-label "latency(ms)" \
		--right-axis-label "latency(ms)" --lower-limit 0 --right-axis 1:0 \
		--x-grid MINUTE:10:HOUR:1:MINUTE:120:0:%R --alt-y-grid --rigid \
		DEF:roundtrip=$LOG/$ip.rrd:rtt:AVERAGE DEF:packetloss=$LOG/$ip.rrd:loss:AVERAGE \
		CDEF:PLNone=packetloss,0,0,LIMIT,UN,UNKN,INF,IF \
		CDEF:PL10=packetloss,1,10,LIMIT,UN,UNKN,INF,IF \
		CDEF:PL25=packetloss,10,25,LIMIT,UN,UNKN,INF,IF \
		CDEF:PL50=packetloss,25,50,LIMIT,UN,UNKN,INF,IF \
		CDEF:PL100=packetloss,50,100,LIMIT,UN,UNKN,INF,IF \
		LINE1:roundtrip#0000FF:"latency(ms)" \
		GPRINT:roundtrip:LAST:"Cur\: %5.2lf" \
		GPRINT:roundtrip:AVERAGE:"Avg\: %5.2lf" \
		GPRINT:roundtrip:MAX:"Max\: %5.2lf" \
		GPRINT:roundtrip:MIN:"Min\: %5.2lf\t\t\t" \
		COMMENT:"pkt loss\:" \
		AREA:PLNone#FFFFFF:"0%":STACK AREA:PL10#FFFF00:"1-10%":STACK AREA:PL25#FFCC00:"10-25%":STACK\
		AREA:PL50#FF8000:"25-50%":STACK AREA:PL100#FF0000:"50-100%":STACK
		HTML="${HTML}<h2>$ip_desc</h2><img src=\"$ip.png\"/><hr>"
	fi

	# log
	echo "$date $ip $rc $rtt $loss%" >> $LOG/tonto.log
	logger "$date $ip $rc_str $rtt $loss%"

done
if [ $graph == 1 ]; then
	echo $HTML > $LOG/tonto.html
	cat $HEADER $LOG/tonto.html $FOOTER > $WWW/index.html
fi
