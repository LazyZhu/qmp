--[[
    Copyright (C) 2011 Fundacio Privada per a la Xarxa Oberta, Lliure i Neutral guifi.net

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

    The full GNU General Public License is included in this distribution in
    the file called "COPYING".

 Contributors:
	Simó Albert i Beltran

--]]

require("luci.sys")
local http = require "luci.http"
package.path = package.path .. ";/etc/qmp/?.lua"
qmpinfo = require "qmpinfo"


m = Map("qmp", "qMp wireless interfaces settings")

local uci = luci.model.uci.cursor()
local wdevs = qmpinfo.get_wifi_index()

for _,wdev in ipairs(wdevs) do
	mydev = uci:get("qmp",wdev,"device")
end

local iw = luci.sys.wifi.getiwinfo(mydev)


---------------------------
-- Section Wireless Main --
---------------------------
s_wireless_main = m:section(NamedSection, "wireless", "qmp", translate("Wireless general options"), "")
s_wireless_main.addremove = False

-- Country selection
local cl = iw and iw.countrylist

if cl and #cl > 0 then
cc = s_wireless_main:option(ListValue, "country", translate("Country Code"), translate("Use ISO/IEC 3166 alpha2 country codes."))

cc.default = tostring(iw and iw.country or "00")
for _, s in ipairs(cl) do
  	cc:value(s.alpha2, "%s - %s" %{ s.alpha2, s.name })
end                                        
   
--   else
--                s_wireless_main:option(Value, "country", translate("Country Code"), translate("Use ISO/IEC 3166 alpha2 country codes2."))
  end



-- BSSID
bssid = s_wireless_main:option(Value,"bssid","BSSID")


-----------------------------
-- Section Wireless Device --
-----------------------------
for _,wdev in ipairs(wdevs) do

	mydev = uci:get("qmp",wdev,"device")

	s_wireless = m:section(NamedSection, wdev, "Wireless device", "Wireless device " .. mydev)
	s_wireless.addremove = False

	-- Device
	dev = s_wireless:option(DummyValue,"device","Device")

	-- MAC
	mac = s_wireless:option(DummyValue,"mac","MAC")

	-- Mode
        mode = s_wireless:option(ListValue,"mode","Mode")                                                                                      
        mode:value("adhoc_ap","AdHoc (mesh) + Acess point (LAN)")                                                                                  
        mode:value("adhoc","AdHoc (mesh)")                                                                                                       
        mode:value("ap","Master (mesh, no DHCP)")                                                                                       
        mode:value("client","Client")                                                                                                          
        mode:value("none","Disabled")  

	-- Name
	local essid = s_wireless:option(Value,"name","ESSID", translate("Name of the WiFi network"))
	-- maxlength is documented but not implemented
	-- http://luci.subsignal.org/trac/wiki/Documentation/CBI#a.maxlengthnil
	-- http://luci.subsignal.org/trac/browser/luci/trunk/libs/web/luasrc/cbi.lua?rev=9834#L1463
	essid.maxlength = 32

	-- Channel
	channel = s_wireless:option(ListValue,"channel","Channel",translate("WiFi channel to be used in this device.<br/>Selecting channels with + or - enables 40MHz bandwidth."))
	mymode = m.uci:get("qmp",wdev,"mode")

	for _,ch in ipairs(qmpinfo.get_channels(mydev)) do
		if mymode ~= "adhoc" or ch.adhoc then
			channel:value(ch.channel, ch.channel)
			if ch.ht40p then channel:value(ch.channel .. '+', ch.channel .. '+') end
			if ch.ht40m then channel:value(ch.channel .. '-', ch.channel .. '-') end
			if ch.channel < 15 then channel:value(ch.channel .. 'b', ch.channel .. 'b') end
		end
	end

	-- WPA key
	local key=s_wireless:option(Value,"key","WPA2 key", 
		translate("WPA2 key for AP (8 chars or more).<br/>Leave blank for make it OPEN (recomended)"))
	key.default = ""
	key:depends("mode","ap")
	key:depends("mode","adhoc_ap")

	-- Txpower
	txpower = s_wireless:option(ListValue,"txpower",translate("Transmission power (dBm)"),translate("Radio power in dBm. Each 3 dB increment doubles the power."))
	for _,t in ipairs(qmpinfo.get_txpower(mydev)) do
		txpower:value(t,t)
	end
end


function m.on_commit(self,map)
	http.redirect("/luci-static/resources/qmp/wait_short.html")
	luci.sys.call('(/etc/qmp/qmp_control.sh configure_wifi ; /etc/init.d/network reload; /etc/init.d/gwck enabled && /etc/init.d/gwck restart)&')
end

---------------------------
-- Section Wireless Main --
---------------------------
s_wireless_reconfigure = m:section(NamedSection, "wireless", "qmp", translate("Reconfigure wireless"), translate("Use this button to rescan and reconfigure all wireless interfaces. This is useful in case new interfaces are added. <br/> <br/><strong>All current wireless settings will be restored to the default ones.</strong> "))
s_wireless_main.addremove = False

-- Button Rescan Wifi devices
confwifi = s_wireless_reconfigure:option(Button, "_confwifi", translate("Reconfigure wireless interfaces"),translate("Rescan and reconfigure all devices. <strong>Current wireless settings will be restored to defaults.</strong>"))

function confwifi.write(self, section)
	luci.sys.call("qmpcontrol reset_wifi")
end


return m

