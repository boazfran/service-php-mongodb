# work around for writting to stdout and stderr as non root
# create self signed certificate        
openssl req -newkey rsa:4096 -nodes -keyout /etc/pki/tls/private/localhost.key \
-x509 -days 3650 -out /etc/pki/tls/certs/localhost.crt \
-subj "/C=IL/ST=IL/L=TLV/O=CLALIT/OU=DAVIDOF/CN=localhost/emailAddress=boaz@domain"
mkfifo -m 600 /tmp/logpipe
cat <> /tmp/logpipe 1>&2 &
php-fpm
exec /usr/sbin/httpd -D FOREGROUND
