local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

h2omes = {}
h2omes.homes = {} -- table players home
h2omes.path = minetest.get_worldpath() .. "/h2omes/"
minetest.mkdir(h2omes.path)

local tmp_players = {}
local from_players = {}


function h2omes.check(name)
	if minetest.player_exists(name) then
		h2omes.load_homes(name)
	else
		h2omes.homes[name] = {}
	end
end


--function check_privs
function h2omes.check_privs(name)
	return minetest.check_player_privs(name, {home=true})
end


--function save_homes
function h2omes.save_homes(name)
	local file = h2omes.path..name
	local input, err = io.open(file, "w")
	if input then
		input:write(minetest.serialize(h2omes.homes[name]))
		input:close()
	else
		minetest.log("error", "open(" .. file .. ", 'w') failed: " .. err)
	end
end


--function load_homes
function h2omes.load_homes(name)
	h2omes.homes[name] = {}
	local file = h2omes.path..name
	local input, err = io.open(file, "r")
	if input then
		local data = minetest.deserialize(input:read())
		io.close(input)
		if data and type(data) == "table" then
			if data.home then
				h2omes.homes[name].home = data.home
			end
			if data.pit then
				h2omes.homes[name].pit = data.pit
			end
		end
	end
end

--function set_homes
function h2omes.set_home(name, home_type, pos)
	h2omes.check(name)
	if not pos then
		local player = minetest.get_player_by_name(name)
		if not player then return end
		pos = player:get_pos()
	end
	if not pos then return false end
	if minetest.is_protected(pos, name) then
		return false
	end
	if not h2omes.check_privs(name) then
		return false
	end
	h2omes.homes[name][home_type] = pos
	minetest.chat_send_player(name, S("@1 set!", home_type))
	minetest.sound_play("dingdong",{to_player=name, gain = 1.0})
	h2omes.save_homes(name)
	return true
end


--function get_home
function h2omes.get_home(name, home_type)
	h2omes.check(name)
	if not minetest.player_exists(name) then return nil end
	if h2omes.homes[name][home_type] then
		return h2omes.homes[name][home_type]
	end
	return nil
end

--function getspawn
function h2omes.getspawn(name)
	local player = minetest.get_player_by_name(name)
	if not player then return nil end
	local pos = player:get_pos()
	if not pos then return nil end
	local spawn_pos
	spawn_pos = minetest.setting_get_pos("static_spawnpoint")
	return spawn_pos
end


--function to_spawn
function h2omes.to_spawn(name)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	if not minetest.check_player_privs(name, "spawn") then
		return false
	end
	local spawn_pos = h2omes.getspawn(name)
	if spawn_pos then
		minetest.chat_send_player(name, S("Teleporting to spawn..."))
		player:set_pos(spawn_pos)
		minetest.sound_play("teleport", {to_player=name, gain = 1.0})
		minetest.log("action", S("Player @1 respawned.", name))
		return true
	else
		minetest.chat_send_player(name, S("ERROR: No spawn point is set on this server!"))
		return false
	end
end


--function to_home
function h2omes.to_home(name_from, name_to, home_type)
	h2omes.check(name_to)
	local player_from = minetest.get_player_by_name(name_from)
	local player_to = minetest.get_player_by_name(name_to)
	if not minetest.player_exists(name_to) then return false end
	if not h2omes.check_privs(name_from) then
		return false
	end
	local pos = player_from:get_pos()
	if not pos then return false end
	if h2omes.homes[name_to][home_type] then
		player_from:set_pos(h2omes.homes[name_to][home_type])
		minetest.chat_send_player(name_from, S("Teleported to @1 of @2!", home_type, name_to))
		minetest.sound_play("teleport", {to_player=name_from, gain = 1.0})
		return true
	end
	return false
end


--function to_player
function h2omes.to_player(name, to_pos, to_name)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	if not h2omes.check_privs(name) then
		return false
	end
	local from_pos = player:get_pos()
	if to_pos then
		minetest.chat_send_player(name, S("Teleporting to player @1",to_name))
		player:set_pos(to_pos)
		minetest.sound_play("teleport", {to_player=name, gain = 1.0})
		return true
	else
		minetest.chat_send_player(name, S("ERROR: No position to player!"))
		return false
	end
end


function h2omes.update_pos(name, pos, from_name)
	from_players[name] = {name=from_name, pos=pos}
	minetest.chat_send_player(name, S("@1 sent you their position to teleport", from_name))
	minetest.sound_play("dingdong",{to_player=name, gain = 0.8})
	return true
end


function h2omes.send_pos_to_player(name, pos, to_name)
	local player = minetest.get_player_by_name(to_name)
	if not player or not pos then return false end
	if not h2omes.check_privs(name) then
		return false
	end
	if not minetest.check_player_privs(to_name, {interact = true}) then
		minetest.chat_send_player(name, S("You cannot send your position to a player before they have the interact privilege."))
		return false
	end

	if h2omes.update_pos(to_name, pos, name) then
		minetest.chat_send_player(name, S("Your position has been sent to @1", to_name))
		return true
	else
		minetest.chat_send_player(name, S("Error: @1 already received a request. please try again later.", to_name))
	end
	return false
end


function h2omes.show_formspec_home(name)
	if tmp_players[name] == nil then
		tmp_players[name] = {}
	end
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local formspec = {"size[8,9]label[3.15,0;"..S("Home Settings").."]"}
	local pos = player:get_pos()
	--spawn
	table.insert(formspec, "label[3.45,0.8;".. S("TO SPAWN") .."]")
	local spawn_pos = h2omes.getspawn(name)
	if spawn_pos then
		table.insert(formspec, string.format("label[2.9,1.3;x:%s, y:%s, z:%s]", math.floor(spawn_pos.x), math.floor(spawn_pos.y), math.floor(spawn_pos.z) ))
		table.insert(formspec, "button_exit[6,1.1;1.5,1;to_spawn;".. S("To Spawn") .."]")
	else
		table.insert(formspec, "label[3.3,1.3;".. S("No spawn set") .."]")
	end

	--home
	table.insert(formspec, "label[3.5,2.1;".. S("TO HOME") .."]")
	table.insert(formspec, "button[0.5,2.4;1.5,1;set_home;".. S("Set Home") .."]")
	local home_pos = h2omes.get_home(name, "home")
	if home_pos then
		table.insert(formspec, string.format("label[2.9,2.5;x:%s, y:%s, z:%s]", math.floor(home_pos.x), math.floor(home_pos.y), math.floor(home_pos.z) ))
		table.insert(formspec, "button_exit[6,2.4;1.5,1;to_home;".. S("To Home") .."]")
	else
		table.insert(formspec, "label[3.3,2.5;".. S("Home no set") .."]")
	end

	--pit
	table.insert(formspec, "label[3.55,3.4;".. S("TO PIT") .."]")
	table.insert(formspec, "button[0.5,3.7;1.5,1;set_pit;".. S("Set Pit") .."]")
	local pit_pos = h2omes.get_home(name, "pit")
	if pit_pos then
		table.insert(formspec, string.format("label[2.9,3.8;x:%s, y:%s, z:%s]", math.floor(pit_pos.x), math.floor(pit_pos.y), math.floor(pit_pos.z) ))
		table.insert(formspec, "button_exit[6,3.7;1.5,1;to_pit;".. S("To Pit") .."]")
	else
		table.insert(formspec, "label[3.3,3.8;".. S("Pit no set") .."]")
	end

	--to player
	table.insert(formspec, "label[3.35,4.7;".. S("TO PLAYER") .."]")
	local to_player = from_players[name]
	if to_player and to_player.name and to_player.pos then
		table.insert(formspec, string.format("label[0.5,5.1;".. S("To %s") .."]", to_player.name))
		table.insert(formspec,string.format("label[2.9,5.1;x:%s, y:%s, z:%s]", math.floor(to_player.pos.x),math.floor(to_player.pos.y),math.floor(to_player.pos.z)))
		table.insert(formspec, "button_exit[6,5;1.5,1;to_player;".. S("To Player") .."]")
	else
		table.insert(formspec, "label[2.7,5.1;".. S("No request from player") .."]")
	end

	table.insert(formspec, "label[2.8,6;".. S("SEND MY POS TO PLAYER") .."]")
	if not tmp_players[name] or not tmp_players[name].players_list or #tmp_players[name].players_list < 1 or tmp_players[name].refresh then
		tmp_players[name].refresh = nil
		tmp_players[name].players_list = {}
		tmp_players[name].selected_id = 0
		for _,player in pairs(minetest.get_connected_players()) do
			local player_name = player:get_player_name()
			if player_name and player_name ~= "" and player_name ~= name then
				table.insert(tmp_players[name].players_list, player_name)
			end
		end
		tmp_players[name]["select_player"] = nil
	end
	if #tmp_players[name].players_list == 0 then
		table.insert(formspec, "label[3,6.4;".. S("No player, try later") .."]")
	else
		table.insert(formspec,"button[3.5,6.4;1.5,1;refresh;".. S("refresh") .."]")
		table.insert(formspec, "dropdown[0.5,6.5;3,1;select_player;"..table.concat(tmp_players[name].players_list, ",")..";"..tmp_players[name].selected_id.."]")
	end
	if tmp_players[name].selected_id and tmp_players[name].selected_id > 0 then
		table.insert(formspec, "button_exit[6,6.4;1.5,1;send_to;".. S("Send To") .."]")
	end

	table.insert(formspec, "button_exit[3.25,8.3;1.5,1;close;".. S("Close") .."]")
	minetest.show_formspec(name, "h2omes:formspec", table.concat(formspec))
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if not name or name == "" then return end
	if formname == "h2omes:formspec" then
		if fields["set_home"] then
			h2omes.set_home(name, "home")
		elseif fields["set_pit"] then
			h2omes.set_home(name, "pit")
		elseif fields["to_home"] then
			h2omes.to_home(name, name, "home")
		elseif fields["to_pit"] then
			h2omes.to_home(name, name, "pit")
		elseif fields["to_spawn"] then
			return h2omes.to_spawn(name)
		elseif fields["to_player"] then
			if not from_players[name] then return end
			local to_name = from_players[name].name
			local pos = from_players[name].pos
			from_players[name] = nil
			if not to_name or not pos then return end
			h2omes.to_player(name, pos, to_name)
		elseif fields["send_to"] then
			if not tmp_players[name] then return end
			local to_name = tmp_players[name]["select_player"]
			if not to_name then return end
			local pos = player:get_pos()
			h2omes.send_pos_to_player(name, pos, to_name)
			tmp_players[name] = nil
		elseif fields["refresh"] then
			if not tmp_players[name] then return end
			tmp_players[name].refresh = true
		elseif fields["select_player"] then
			if not tmp_players[name] then return end
			for i, n in pairs(tmp_players[name].players_list) do
				if n == fields["select_player"] then
					tmp_players[name]["select_player"] = fields["select_player"]
					tmp_players[name].selected_id = i
					break
				end
			end
		end
		if not fields["quit"] then
			h2omes.show_formspec_home(name)
		end
	end
end)


minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if not name or name == "" then return end
	h2omes.homes[name] = nil
	tmp_players[name] = nil
	from_players[name] = nil
end)


minetest.register_privilege("home", S("Can use /sethome, /home, /setpit and /pit"))
minetest.register_privilege("spawn", S("Can use /spawn"))

minetest.register_chatcommand("spawn", {
	description = S("Teleport a player to the defined spawnpoint"),
	privs = {spawn=true},
	func = function(name)
		local spawn_pos = h2omes.getspawn(name)
		if spawn_pos then
			h2omes.to_spawn(name)
		else
			minetest.chat_send_player(name, S("ERROR: No spawn point is set on this server!"))
			return false
		end
	end
})

minetest.register_chatcommand("home", {
	description = S("Teleport you to your home point"),
	privs = {home=true},
	func = function (name_from, params)
		local name_to = name_from
		if params ~= "" and h2omes.get_home(params, "home") and minetest.check_player_privs(name_from, "teleport") then
			name_to = params
		end
		if not h2omes.get_home(name_to, "home") then
			minetest.chat_send_player(name_from, S("Player needs to set a home using /sethome"))
			return false
		end
		h2omes.to_home(name_from, name_to, "home")
	end,
})


minetest.register_chatcommand("sethome", {
	description = S("Set your home point"),
	privs = {home=true},
	func = function (name, params)
		h2omes.set_home(name, "home")
	end,
})


minetest.register_chatcommand("pit", {
	description = S("Teleport you to your pit point"),
	privs = {home=true},
	func = function (name_from, params)
		local name_to = name_from
		if params ~= "" and h2omes.get_home(params, "pit") and minetest.check_player_privs(name_from, "teleport") then
			name_to = params
		end
		if not h2omes.get_home(name_to, "pit") then
			minetest.chat_send_player(name_from, S("Player needs to set a pit using /setpit"))
			return false
		end
		h2omes.to_home(name_from, name_to, "pit")
	end,
})


minetest.register_chatcommand("setpit", {
	description = S("Set your pit point"),
	privs = {home=true},
	func = function (name, params)
		h2omes.set_home(name, "pit")
	end,
})

minetest.register_chatcommand("invite_player", {
	description = S("Send a teleportation invitation to a player"),
	params = S("<name>"),
	privs = {home=true},
	func = function(name, params)
		if params == "" then
			return false, S("Please specify a player name. See /help invite_player.")
		end
		if not minetest.get_player_by_name(params) then
			return false, S("Player '@1' does not exist or is not currently connected.", params)
		end
		h2omes.send_pos_to_player(name, minetest.get_player_by_name(name):get_pos(), params)
	end,
})

minetest.register_chatcommand("to_player", {
	description = S("Accept a teleportation invitation"),
	privs = {home=true},
	func = function(name, params)
		if not from_players[name] then
			return false, S("No pending teleportation invitation.")
		end
		local to_name = from_players[name].name
		local pos = from_players[name].pos
		from_players[name] = nil
		if not to_name or not pos then
			return false, S("Unknown error")
		end
		h2omes.to_player(name, pos, to_name)
	end,
})

if minetest.get_modpath("unified_inventory") then
	for i, def in pairs(unified_inventory.buttons) do
		if def.name == "home_gui_set" then
			def.type = "image"
			def.image = "ui_gohome_icon.png"
			def.tooltip = unified_inventory.gettext("My Homes")
			def.action = function(player)
				h2omes.show_formspec_home(player:get_player_name())
			end
		elseif def.name == "home_gui_go" then
			def.type = "image"
			def.image = "ui_gohome_icon.png"
			def.tooltip = unified_inventory.gettext("Go Home")
			def.action = function(player)
				h2omes.to_home(player:get_player_name(), player:get_player_name(), "home")
			end
		end
	end
end

minetest.log("action",S("[h2omes] Loaded."))
