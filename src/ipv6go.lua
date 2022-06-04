local socket = require("socket")
local uci = require("uci")

local domainTable = {}
local ipTable = {}
local old_ipTable = {}

local iptables_binding_target = ""
local time_to_update = "600"

function config()
	local x = uci.cursor()
	domainTableConfig(x)
	iptableConfig(x)
	sleepConfig(x)
end

function domainTableConfig(x)
	local addr_list = x:get("ipv6pass", "ipv6", "address")
	if (addr_list == nil ) then return end
	for _, value in ipairs(addr_list)
    do 
	table.insert(domainTable, value)
	print("config loaded ", value, "to table.")
    end
end

function iptableConfig(x)
    local iptables_config = x:get("ipv6pass", "ipv6", "chain")
    if (iptables_config == nil ) then return end
    iptables_binding_target = iptables_config
    print("config loaded ", iptables_config , "for ip6tables rules binding.")
end

function sleepConfig(x)
	local sleepSec = x:get("ipv6pass", "ipv6", "sleep")
	if (sleepSec == nil ) then return end
	time_to_update = sleepSec
	print("config loaded ", sleepSec , "s to sleep.")
end



function sleep(sec)
	socket.sleep(sec)
end

function get_ipv6_addr(resolved)
	for _, v in ipairs(resolved) do
		if (v ~= nil) then
			if (v["family"] == "inet6") then
				return v["addr"]
			end
		end
	end
	return nil
end

function domainToIp(addr)
	local resolved, _ = socket.dns.getaddrinfo(addr)
	if (resolved == nil ) then return nil end
	for _, v in ipairs(resolved) do
		if (v ~= nil) then
			addr = get_ipv6_addr(resolved)
			if (addr ~= nil) then
				return addr
			end
		end
	end
	print("unable to get ipaddress for ", addr)
	return nil
end

function resolveDomainTable( domaintable )
	local iptable = {}
	for _, v in ipairs(domaintable)
		do
	ip = domainToIp(v)
	if (ip ~= nil ) then
		table.insert(iptable, ip)
	end
end
	return iptable
end

function loopResolving(intermit, times)
	local t = times
	repeat
	ipTable = resolveDomainTable(domainTable)
	io.write("sleep ", intermit, " sec and ", t, "\n")
	sleep(intermit)
	t = t-1
    until(t <= 0)
end

function iptablecompare(new, old)
	local ifIPchange = false
	local newlistlen = 0
	local oldlistlen = 0
	for _ in pairs(new) do newlistlen = newlistlen + 1 end
	for _ in pairs(old) do oldlistlen = oldlistlen + 1 end
	if (newlistlen == 0 or oldlistlen == 0 or newlistlen ~= oldlistlen )
		then
			ifIPchange = true
			return ifIPchange
		end

	for i, v in ipairs(new)
	do
		if (new[i] ~= old[i]) then
			ifIPchange = true
		end
	end
	return ifIPchange
end

function create_iptable_rule()
	local handle_create_table = io.popen("ipset create ipv6allow hash:ip family inet6")
	handle_create_table:close()
	local command = string.format("ip6tables -A %s -m set --match-set ipv6allow dst -j ACCEPT",iptables_binding_target)
	local handle_add_rules = io.popen(command)
	handle_add_rules:close()
end

function if_table_created()
	local command = string.format("echo $( ip6tables -S %s ) | grep ipv6allow", iptables_binding_target)
	local handle_check_table = io.popen(command)
	local result = handle_check_table:read("*a")
	handle_check_table:close()
	if (string.len(result) > 0) then
		return true
	end
	return false
end

function addIP()
	local handle_flush = io.popen("ipset flush ipv6allow")
	handle_flush:close()
	for _, v in ipairs(ipTable)
	do
		local handle_add = io.popen("ipset add ipv6allow "..v)
		print("added to ip6tables --- "..v)
		handle_add:close()
	end
end

function ipset_rules_control()
		if (not if_table_created())then
			create_iptable_rule()
		end
		addIP()
	end

function run()
	config()
	print("Starting ip resolving")
	while (true)
		do
			loopResolving(1,2)
			if (iptablecompare(ipTable,old_ipTable)) then 
				old_ipTable = ipTable
				ipset_rules_control()
			end
			local message = string.format("Sleep %s S",time_to_update)
			print(message)
			sleep(time_to_update)
		end
end
run()