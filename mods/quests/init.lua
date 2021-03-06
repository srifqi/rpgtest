-- story quests

quests = {}
quests.player_quests = {}
quests.file = minetest.get_worldpath() .. "/quests"
quests.callback = nil

function quests.load_quests()
	local input = io.open(quests.file, "r")
	if input then
		local str = input:read("*all")
		if str then
			if minetest.deserialize(str) then
				quests.player_quests = minetest.deserialize(str)
			end
		else 
			print("[WARNING] quest file is empty")
		end
		io.close(input)
	else
		print("[ERROR] couldnt find quest file")
	end
end

function quests.save_quests()
	if quests.player_quests then
		local output = io.open(quests.file, "w")
		local str = minetest.serialize(quests.player_quests)
		output:write(str)
		io.close(output)
	end
end

function quests.add_quest(player, quest)
	if not quests.player_quests[player] then
		quests.player_quests[player] = {}
	end
	print("[quests] add quest")
	table.insert(quests.player_quests[player], quest)
	quests.save_quests()
	return #quests.player_quests[player]
end

quests.show_quests_form = "size[8,7.5;]"
quests.show_quests_form = quests.show_quests_form..default.gui_colors
quests.show_quests_form = quests.show_quests_form..default.gui_bg
quests.show_quests_form = quests.show_quests_form.."label[0,0;%s]"

minetest.register_chatcommand("quests", {
	params = "",
	description = "Shows your quests",
	privs = {},
	func = function(name, text)
		if not quests.player_quests[name] then
			local s = quests.show_quests_form
			s = string.format(s, "You have not got any quests yet.")
			minetest.show_formspec(name, "quests:show_quests", s)
			return
		end
		local s = quests.show_quests_form
		local txt = ""
		for k,v in pairs(quests.player_quests[name]) do
			txt = txt .. " -> " .. v.quest_type .. " " .. v.node .. " (" .. tostring(v.progress) .. "/" .. tostring(v.max) .. ")\n"
		end
		s = string.format(s, txt)
		minetest.show_formspec(name, "quests:show_quests", s)
		return true, ""
	end,
})

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then
		return
	end
	if not quests.player_quests[digger:get_player_name()] then
		return
	end
	table.foreach(quests.player_quests[digger:get_player_name()], function(k, v)
		print("[quests] run quest " .. v.quest_type .. ", " .. v.node)
		if v.quest_type == "dignode" and oldnode.name == v.node then
			v.progress = v.progress + 1
			if v.progress > (v.max-1) and v.done == false then
				xp.add_xp(digger, v.xp)
				v.done = true
				quests.callback(digger)
			end
			quests.save_quests()
		end
	end)
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not placer or not placer:is_player() then
		return
	end
	if not quests.player_quests[placer:get_player_name()] then
		return
	end
	table.foreach(quests.player_quests[placer:get_player_name()], function(k, v)
		if v.quest_type == "placenode" and newnode.name == v.node then
			v.progress = v.progress + 1
			if v.progress > (v.max-1) and v.done == false then
				xp.add_xp(placer, v.xp)
				v.done = true
				quests.callback(placer)
			end
			quests.save_quests()
		end
	end)
end)

minetest.register_on_newplayer(function(player)
	quests.player_quests[player:get_player_name()] = {}
end)

quests.load_quests()

-- exploring
minetest.register_node("quests:map", {
	description = "Map",
	tiles = {"quests_map_top.png", "quests_map_top.png", "quests_map.png", "quests_map.png", "quests_map.png", "quests_map.png"},	
	groups = {quest = 1, cracky = 3},
	on_punch = function(pos, node, player, pointed_thing)
		xp.add_xp(player, math.random(3, 30))
		minetest.remove_node(pos)
	end,
})

minetest.register_node("quests:ray", {
	description = "Ray",
	tiles = {"quests_glowing_ray.png"},
	groups = {cracky = 1, ray=1},
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "nodebox",
	light_source = 7,
	node_box = {
		type = "fixed",
		fixed = {
				{-0.2, -0.5, -0.2, 0.2, 0.5, 0.2},
			},
	},
	drop = "",
})
