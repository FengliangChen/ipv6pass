local socket = require("socket")
local uci = require("uci")

local iptables_binding_target = ""
local time_to_update = "600"
local domain_link_head = nil
local domain_table = {}

function config()
	local x = uci.cursor()
	domain_table_config(x)
	iptable_config(x)
	sleep_config(x)
end

function domain_table_config(x)
	local addr_list = x:get("ipv6pass", "ipv6", "address")
	if (addr_list == nil ) then return end
	for _, value in ipairs(addr_list)
    do 
	table.insert(domain_table, value)
	print("config loaded ", value, "to table.")
    end
end

function iptable_config(x)
    local iptables_config = x:get("ipv6pass", "ipv6", "chain")
    if (iptables_config == nil ) then return end
    iptables_binding_target = iptables_config
    print("config loaded ", iptables_config , "for ip6tables rules binding.")
end

function sleep_config(x)
	local sleep_sec = x:get("ipv6pass", "ipv6", "sleep")
	if (sleep_sec == nil ) then return end
	time_to_update = sleep_sec
	print("config loaded ", sleep_sec , "s to sleep.")
end

function sleep(sec)
	socket.sleep(sec)
end

function domain_info_init()
	local head = nil
	for _, v in ipairs(domain_table)
	do
		head = {domain = v, cur_ip = nil, pre_ip = nil, is_ip_changed = false, next = head}
		domain_link_head = head
	end
end

function ip_update()
	local head = domain_link_head
	while(head ~= nil)
		do
		local ip = domain_to_ip(head.domain)
		if (ip ~= nil ) then
			head.pre_ip = head.cur_ip
			head.cur_ip = ip
		end
		head = head.next
	end
end

function is_ip_changed_update()
	local head = domain_link_head
	while(head ~= nil)
		do
		local cur = head.cur_ip
		local pre = head.pre_ip
		if (cur ~= pre ) then
			head.is_ip_changed = true
		end
		head = head.next
	end
end

function is_ip_changed_reset()
	local head = domain_link_head
	while(head ~= nil)
		do
		head.is_ip_changed = false
		head = head.next
	end
end

function ip_status_update()
	ip_update()
	is_ip_changed_reset()
	is_ip_changed_update()
end

function fetch_cur_ip()
	local iplist = {}
	local head = domain_link_head
	
	while(head ~= nil)
		do
		if (head.is_ip_changed == true ) then
			table.insert(iplist, head.cur_ip)
		end
		head = head.next
	end
	return iplist
end

function fetch_pre_ip()
	local iplist = {}
	local head = domain_link_head
	while(head ~= nil)
		do
		if (head.is_ip_changed == true ) then
			table.insert(iplist, head.pre_ip)
		end
		head = head.next
	end
	return iplist
end

function domain_to_ip(addr)
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

function add_ip_to_ipset()
	local ipTable = fetch_cur_ip()
	for _, v in ipairs(ipTable)
	do
		local handle_add = io.popen("ipset add ipv6allow "..v)
		print("added to ip6tables --- "..v)
		handle_add:close()
	end
end

function del_ip_from_ipset()
	local ipTable = fetch_pre_ip()
	for _, v in ipairs(ipTable)
	do
		local handle_add = io.popen("ipset del ipv6allow "..v)
		print("deleted from ip6tables --- "..v)
		handle_add:close()
	end
end

function flush_ipset()
	local handle_flush = io.popen("ipset flush ipv6allow")
	handle_flush:close()
end

function ipset_rules_init()
	if (if_table_created())then
		flush_ipset()
	else
		create_iptable_rule()
	end
	
end

function ipset_rules_control()
	add_ip_to_ipset()
	del_ip_from_ipset()
end

function PrintStatus()
	local head = domain_link_head
	while(head ~= nil)
		do
		print(head.is_ip_changed, "--------",head.domain,"----", head.cur_ip,"----", head.pre_ip)
		head = head.next
	end
end

function run()
	config()
	print("Starting ip resolving")
	domain_info_init()
	ipset_rules_init()
	while (true)
		do
			ip_status_update()
			-- PrintStatus()
			ipset_rules_control()
			local message = string.format("Sleep %s S",time_to_update)
			print(message)
			sleep(time_to_update)
		end
end

run()


