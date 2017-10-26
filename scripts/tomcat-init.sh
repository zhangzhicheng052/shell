#!/bin/bash
#
# tomcat Startup script for the Apache Tomcat Server
#
# chkconfig: - 81 21
# description: Apache Tomcat is a servlet/JSP container.
# processname: tomcat

# Source function library.
. /etc/rc.d/init.d/functions

JAVA_HOME=/opt/jdk
CATALINA_HOME=/opt/tomcat
CATALINA_BASE=/opt/tomcat
TOMCAT_USER=root

prog=tomcat
lockfile=/var/lock/subsys/tomcat
pidfile=/var/run/tomcat.pid
RETVAL=0

# Ensure that any user defined CLASSPATH variables are not used on startup,
# but allow them to be specified in setenv.sh, in rare case when it is needed.
CLASSPATH=
JAVA_OPTS=
if [ -r "$CATALINA_BASE/bin/setenv.sh" ]; then
. "$CATALINA_BASE/bin/setenv.sh"
elif [ -r "$CATALINA_HOME/bin/setenv.sh" ]; then
. "$CATALINA_HOME/bin/setenv.sh"
fi

# Add on extra jar files to CLASSPATH
test ".$CLASSPATH" != . && CLASSPATH="${CLASSPATH}:"
CLASSPATH="$CLASSPATH$CATALINA_HOME/bin/bootstrap.jar:$CATALINA_HOME/bin/commons-daemon.jar"

test ".$CATALINA_OUT" = . && CATALINA_OUT="$CATALINA_BASE/logs/catalina-daemon.out"
test ".$CATALINA_TMP" = . && CATALINA_TMP="$CATALINA_BASE/temp"

# Add tomcat-juli.jar to classpath
# tomcat-juli.jar can be over-ridden per instance
if [ -r "$CATALINA_BASE/bin/tomcat-juli.jar" ] ; then
CLASSPATH="$CLASSPATH:$CATALINA_BASE/bin/tomcat-juli.jar"
else
CLASSPATH="$CLASSPATH:$CATALINA_HOME/bin/tomcat-juli.jar"
fi
# Set juli LogManager config file if it is present and an override has not been issued
if [ -z "$LOGGING_CONFIG" ]; then
if [ -r "$CATALINA_BASE/conf/logging.properties" ]; then
LOGGING_CONFIG="-Djava.util.logging.config.file=$CATALINA_BASE/conf/logging.properties"
else
# Bugzilla 45585
LOGGING_CONFIG="-Dnop"
fi
fi

test ".$LOGGING_MANAGER" = . && LOGGING_MANAGER="-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager"
JAVA_OPTS="$JAVA_OPTS $LOGGING_MANAGER"


# The semantics of these two functions differ from the way apachectl does
# things -- attempting to start while running is a failure, and shutdown
# when not running is also a failure. So we just do it the way init scripts
# are expected to behave here.
start() {
echo -n $"Starting $prog: "
$CATALINA_HOME/bin/jsvc -home "$JAVA_HOME" \
-jvm server \
-user "$TOMCAT_USER" \
-outfile "$CATALINA_OUT" \
-errfile "&1" \
-pidfile $pidfile \
-classpath "$CLASSPATH" \
"$LOGGING_CONFIG" $JAVA_OPTS $CATALINA_OPTS \
-Djava.endorsed.dirs="$JAVA_ENDORSED_DIRS" \
-Dcatalina.base="$CATALINA_BASE" \
-Dcatalina.home="$CATALINA_HOME" \
-Djava.io.tmpdir="$CATALINA_TMP" \
org.apache.catalina.startup.Bootstrap
RETVAL=$?
[ $RETVAL = 0 ] && touch ${lockfile} && echo_success || echo_failure
echo
return $RETVAL
}

# When stopping httpd a delay of >10 second is required before SIGKILLing the
# httpd parent; this gives enough time for the httpd parent to SIGKILL any
# errant children.
stop() {
echo -n $"Stopping $prog: "
$CATALINA_HOME/bin/jsvc -stop \
-home $JAVA_HOME \
-jvm server \
-pidfile $pidfile \
-classpath "$CLASSPATH" \
-Djava.endorsed.dirs="$JAVA_ENDORSED_DIRS" \
-Dcatalina.base="$CATALINA_BASE" \
-Dcatalina.home="$CATALINA_HOME" \
-Djava.io.tmpdir="$CATALINA_TMP" \
org.apache.catalina.startup.Bootstrap
RETVAL=$?
[ $RETVAL = 0 ] && rm -f ${lockfile} && echo_success || echo_failure
echo
return $RETVAL
}

case "$1" in
start)
start
;;
stop)
stop
;;
restart)
stop
start
;;
*)
echo $"Usage: $prog {start|stop|restart}"
exit 1
esac

exit $RETVAL
