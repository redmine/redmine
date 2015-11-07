#! /bin/sh

DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes slapd ldap-utils
dpkg -l '*slapd*' '*ldap-utils*'

TOP_DIR=`dirname $0`/../..

/etc/init.d/slapd stop

rm -rf /etc/ldap/slapd.d/*
rmdir  /etc/ldap/slapd.d/
rm -rf /var/lib/ldap/*

cp ${TOP_DIR}/test/fixtures/ldap/slapd.ubuntu.12.04.conf /etc/ldap/slapd.conf
slaptest -u -v -f /etc/ldap/slapd.conf

/etc/init.d/slapd start

ldapadd -x -D "cn=Manager,dc=redmine,dc=org" \
   -w secret -h localhost -p 389 -f ${TOP_DIR}/test/fixtures/ldap/test-ldap.ldif
