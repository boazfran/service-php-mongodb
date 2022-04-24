# work around for writting to stdout and stderr as non root
mkfifo -m 600 /tmp/logpipe
cat <> /tmp/logpipe 1>&2 &
exec /usr/sbin/httpd -D FOREGROUND
