#!/bin/sh
echo "=== enable SSH ==="
cp -p /conf/config.xml /conf/config.xml.lab.bak 2>/dev/null

# Method 1: proper OPNsense php (write_config) with correct working dir
cd /usr/local/etc/inc 2>/dev/null
OK=$(php -r '
require_once("config.inc");
require_once("util.inc");
global $config;
if (!isset($config["system"]["ssh"]) || !is_array($config["system"]["ssh"])) { $config["system"]["ssh"]=array(); }
$config["system"]["ssh"]["enabled"]="enabled";
$config["system"]["ssh"]["permitrootlogin"]="1";
$config["system"]["ssh"]["passwordauth"]="1";
write_config("lab: enable SSH");
echo "PHP_OK";
' 2>/dev/null)
echo "method1_result: [$OK]"

# Method 2 fallback: edit /conf/config.xml directly
if [ "$OK" != "PHP_OK" ]; then
  echo "method2: editing config.xml directly"
  if grep -q "<ssh>" /conf/config.xml; then
    grep -q "<ssh><enabled>" /conf/config.xml || sed -i '' 's|<ssh>|<ssh><enabled>enabled</enabled><permitrootlogin>1</permitrootlogin><passwordauth>1</passwordauth>|' /conf/config.xml
  else
    sed -i '' 's|</system>|<ssh><enabled>enabled</enabled><permitrootlogin>1</permitrootlogin><passwordauth>1</passwordauth><group>admins</group></ssh></system>|' /conf/config.xml
  fi
  rm -f /tmp/config.cache 2>/dev/null
fi

echo "--- resulting <ssh> block ---"
awk '/<ssh>/{f=1} f{print} /<\/ssh>/{f=0}' /conf/config.xml | head -8

echo "--- apply via configd ---"
configctl openssh configure 2>&1 | head -1
configctl openssh restart 2>&1 | head -1
configctl openssh start 2>&1 | head -1
sleep 3
echo "--- listening on IPv4 :22 ? ---"
sockstat -4 -l 2>/dev/null | grep '\.22 ' || echo "NOT-LISTENING-22"
echo "=== DONE ==="
