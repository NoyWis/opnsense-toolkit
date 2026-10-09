#!/bin/sh
cd /usr/local/etc/inc 2>/dev/null
php -r '
require_once("config.inc");
require_once("util.inc");
global $config;
$user="root";
$idx=-1;
foreach ($config["system"]["user"] as $k=>$u){ if (isset($u["name"]) && $u["name"]==$user){ $idx=$k; break; } }
if ($idx<0){ echo "NO_USER\n"; exit(1); }
$key=bin2hex(random_bytes(20));
$secret=bin2hex(random_bytes(24));
$hash=password_hash($secret, PASSWORD_BCRYPT);
if (!isset($config["system"]["user"][$idx]["apikeys"]) || !is_array($config["system"]["user"][$idx]["apikeys"])) { $config["system"]["user"][$idx]["apikeys"]=array(); }
if (!isset($config["system"]["user"][$idx]["apikeys"]["item"]) || !is_array($config["system"]["user"][$idx]["apikeys"]["item"])) { $config["system"]["user"][$idx]["apikeys"]["item"]=array(); }
$config["system"]["user"][$idx]["apikeys"]["item"][]=array("key"=>$key,"secret"=>$hash);
write_config("lab: add API key for root");
echo "KEY=$key\n";
echo "SECRET=$secret\n";
'
