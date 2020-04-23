#!/bin/sh

VERSION='20200423001' # Welcome to Portugal

if [ -f "/etc/samba.patch.version" ]; then
	if [ "$(cat /etc/samba.patch.version)" = "$VERSION" ]; then
		echo "ERROR: Changes have been applied!"
		exit 2
	fi
fi

# Verifica versao pfSense
if [ "$(cat /etc/version)" != "2.4.5-RELEASE" ]; then
	echo "ERROR: You need the pfSense version 2.4.4 to apply this script"
	exit 2
fi

ASSUME_ALWAYS_YES=YES
export ASSUME_ALWAYS_YES

mkdir -p /var/db/samba4/winbindd_privileged
chown -R :proxy /var/db/samba4/winbindd_privileged
chmod -R 0750 /var/db/samba4/winbindd_privileged

fetch -o /usr/local/pkg -q https://openjdtec.com.br/pfsense/2.4.4/samba/samba.inc
fetch -o /usr/local/pkg -q https://openjdtec.com.br/pfsense/2.4.4/samba/samba.xml

/usr/local/sbin/pfSsh.php <<EOF
\$samba = false;
foreach (\$config['installedpackages']['service'] as \$item) {
  if ('samba' == \$item['name']) {
    \$samba = true;
    break;
  }
}
if (\$samba == false) {
	\$config['installedpackages']['service'][] = array(
	  'name' => 'samba',
	  'rcfile' => 'samba.sh',
	  'executable' => 'smbd',
	  'description' => 'Samba daemon'
  );
}
\$samba = false;
foreach (\$config['installedpackages']['menu'] as \$item) {
  if ('Samba (AD)' == \$item['name']) {
    \$samba = true;
    break;
  }
}
if (\$samba == false) {
  \$config['installedpackages']['menu'][] = array(
    'name' => 'Samba (AD)',
    'section' => 'Services',
    'url' => '/pkg_edit.php?xml=samba.xml'
  );
}
write_config();
exec;
exit
EOF


if [ ! "$(/usr/sbin/pkg info | grep pfSense-pkg-squid)" ]; then
	/usr/sbin/pkg install -r pfSense pfSense-pkg-squid
fi
cd /usr/local/pkg
fetch -o - -q https://openjdtec.com.br/pfsense/2.4.4/samba/squid_winbind_auth.patch | patch -b -p0 -f

if [ ! -f "/usr/local/etc/smb4.conf" ]; then
	touch /usr/local/etc/smb4.conf
fi
cp -f /usr/local/bin/ntlm_auth /usr/local/libexec/squid/ntlm_auth

/etc/rc.d/ldconfig restart

echo "$VERSION" > /etc/samba.patch.version
