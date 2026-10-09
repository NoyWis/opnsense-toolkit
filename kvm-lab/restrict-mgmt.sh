#!/bin/sh
# Usage: MGMT_HOST=192.168.124.1 sh restrict-mgmt.sh
# Blocks SSH (22) and web GUI (443) on LAN for everyone except MGMT_HOST.
MGMT_HOST="${MGMT_HOST:?set MGMT_HOST to the only admin IP}"
export MGMT_HOST
echo "=== restrict mgmt (SSH+GUI) to host $MGMT_HOST only ==="
cp -p /conf/config.xml /conf/config.xml.mgmt.bak 2>/dev/null
cd /usr/local/etc/inc 2>/dev/null
php -r '
require_once("config.inc");
require_once("util.inc");
global $config;
$HOST=getenv("MGMT_HOST");
$TAG="lab-mgmt-hostonly";
// find interface key that maps to vtnet0 (LAN)
$ifkey="lan";
if (isset($config["interfaces"]) && is_array($config["interfaces"])) {
  foreach ($config["interfaces"] as $k=>$v) { if (isset($v["if"]) && $v["if"]=="vtnet0") { $ifkey=$k; break; } }
}
// disable web GUI anti-lockout so the block below is effective
if (!isset($config["system"]["webgui"]) || !is_array($config["system"]["webgui"])) { $config["system"]["webgui"]=array(); }
$config["system"]["webgui"]["noantilockout"]="1";
// ensure filter rule array
if (!isset($config["filter"]) || !is_array($config["filter"])) { $config["filter"]=array(); }
if (!isset($config["filter"]["rule"]) || !is_array($config["filter"]["rule"])) { $config["filter"]["rule"]=array(); }
// idempotent: drop rules created by a previous run
$kept=array();
foreach ($config["filter"]["rule"] as $r) { if (!isset($r["descr"]) || strpos($r["descr"],$TAG)===false) { $kept[]=$r; } }
$config["filter"]["rule"]=$kept;
$mk=function($port,$label) use ($HOST,$TAG,$ifkey){
  return array(
    "type"=>"block","interface"=>$ifkey,"ipprotocol"=>"inet","protocol"=>"tcp",
    "source"=>array("address"=>$HOST,"not"=>"1"),
    "destination"=>array("network"=>"(self)","port"=>"$port"),
    "quick"=>"1",
    "descr"=>"$TAG: $label only from host",
  );
};
array_unshift($config["filter"]["rule"], $mk("443","GUI"), $mk("22","SSH"));
write_config("lab: restrict mgmt to host only");
echo "CFG_OK ifkey=$ifkey\n";
'
echo "--- apply filter ---"
configctl filter reload 2>&1 | head -1
sleep 2
echo "--- lab rules present? ---"
grep -o "lab-mgmt-hostonly[^<]*" /conf/config.xml | head
echo "--- pf: rules touching port 22/443 ---"
pfctl -sr 2>/dev/null | grep -E "\((self|lo0)\)|to any port = (ssh|https|22|443)|$MGMT_HOST" | head
echo "=== DONE ==="
