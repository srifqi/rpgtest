story = {}

-- string
function string:split(inSplitPattern, outResults)
	if not outResults then
		outResults = {}
	end
	local theStart = 1
	local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	while theSplitStart do
		table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	end
	table.insert( outResults, string.sub( self, theStart ) )
	return outResults
end

-- form

story.talk_form = "size[8,7.5;]"
story.talk_form = story.talk_form..default.gui_colors
story.talk_form = story.talk_form..default.gui_bg
--story.talk_form = story.talk_form.."image[0,0.0;3,8;story_player.png]"
story.talk_form = story.talk_form.."label[0,0;%s]"
--story.talk_form = story.talk_form.."image[6,0.0;3,8;story_character_1.png]"

story.get_talk_form = function(text)
	return string.format(story.talk_form, text)
end

-- hud

story.hud = {}

minetest.register_on_joinplayer(function(player)
	if story.generator.players_storys[player:get_player_name()] and story.generator.players_storys[player:get_player_name()].pos then
		story.hud[player:get_player_name()] = player:hud_add({
			hud_elem_type = "waypoint",
			name = "story",
			text = "",
			number = 0x00FF00,
			world_pos = story.generator.players_storys[player:get_player_name()].pos
		})
	end

	story.hud[player:get_player_name()] = player:hud_add({
		hud_elem_type = "waypoint",
		name = "story",
		text = "",
		number = 0x00FF00,
		world_pos = {x=0,y=0,z=0}
	})
end)

-- generator

story.generator = {}
story.generator.parts = {}
story.generator.dialogs = {}	
story.generator.players_storys = {}
story.generator.file = minetest.get_worldpath() .. "/story"

function story.generator.load_storys()
	local input = io.open(story.generator.file, "r")
	if input then
		local str = input:read("*all")
		if str then
			if minetest.deserialize(str) then
				print("[story] FILE : " .. str)
				story.generator.players_storys = minetest.deserialize(str)
			end
		else 
			print("[WARNING] story file is empty")
		end
		io.close(input)
	else
		print("[ERROR] couldnt find story file")
	end
end

function story.generator.save_storys()
	if story.generator.players_storys then
		local output = io.open(story.generator.file, "w")
		local str = minetest.serialize(story.generator.players_storys)
		output:write(str)
		io.close(output)
	end
end

function story.generator.gen_next_step(player)
	print("[INFO] generating story...")
	if not story.generator.players_storys[player:get_player_name()] then
		print("[ERROR][story] could not find players story")
		return
	end
	-- load part
	local part = story.generator.players_storys[player:get_player_name()].part
	part = story.generator.get_part(story.generator.players_storys[player:get_player_name()].part)
	if part then
		local next_part = {}

		-- run a new part?
		if story.generator.players_storys[player:get_player_name()].wait then
			next_part = story.generator.run(part, player, story.generator.players_storys[player:get_player_name()].wait_pos+1)
		else
			next_part = story.generator.run(part, player, 0)
		end
		
		--quit
		if next_part.quit then
			story.generator.players_storys[player:get_player_name()].pos = nil
			story.generator.players_storys[player:get_player_name()].part = ""
			story.generator.players_storys[player:get_player_name()].wait_for = nil
			story.generator.players_storys[player:get_player_name()].wait_pos = 0
			story.generator.players_storys[player:get_player_name()].wait = false
			print("[story] QUIT")
			return
		end
		
		-- wait or not?
		if next_part.wait then
			story.generator.players_storys[player:get_player_name()].wait = true
			story.generator.players_storys[player:get_player_name()].wait_pos = next_part.param
			story.generator.players_storys[player:get_player_name()].wait_for = next_part.param2
		else
			story.generator.players_storys[player:get_player_name()].part = next_part.part
			story.generator.players_storys[player:get_player_name()].wait_for = nil
			story.generator.players_storys[player:get_player_name()].wait = false
			story.generator.players_storys[player:get_player_name()].wait_pos = 0
		end
		
		-- save
		story.generator.save_storys()
		return
	else
		print("[ERROR][story] could not find part file : " .. (story.generator.players_storys[player:get_player_name()].part or "nothing"))
		return
	end
end

function story.generator.new_player(player)
	-- adds a new entry to the story database
	story.generator.players_storys[player:get_player_name()] = {}
	story.generator.players_storys[player:get_player_name()].part = ""
	story.generator.players_storys[player:get_player_name()].wait_pos = 0
	story.generator.players_storys[player:get_player_name()].wait = false
	story.generator.players_storys[player:get_player_name()].wait_for = nil
end

function story.generator.get_part(name)
	if not name then return end
	if name == "" then return end
	if not story.generator.parts[name] then
		print("[story] loading part : " .. name)
		local file = io.open(minetest.get_modpath("story").."/parts/" ..name..".quest", "r")
		story.generator.parts[name] = file:read("*all")
		io.close(file)
		return story.generator.parts[name]
	else
		print("[story] get part : " .. name)
		return story.generator.parts[name]
	end
end

function story.generator.get_dialog(name, player)
	if not story.generator.dialogs[name] then
		local file = io.open(minetest.get_modpath("story").."/parts/"  .. (character_editor.language[player:get_player_name()] or "") ..name..".dialog", "r")
		story.generator.dialogs[name] = file:read("*all")
		io.close(file)
		return story.generator.dialogs[name]
	else
		return story.generator.dialogs[name]
	end
end

function story.generator.get_quest(player)
	local input = io.open(minetest.get_modpath("story").."/parts/quests.conf", "r")
	if input then
		local str = input:read("*all")
		if str then
			local lines = str:split("\n")
			for k,v in pairs(lines) do
				local var = v:split("=")[1]
				local val = (v:split("=")[2]):split(",")
				if var == "lvl".. tostring(xp.player_levels[player:get_player_name()] or 1) then
					return val[math.random(#val)]
				end
			end
		else 
			print("[WARNING] quest.conf is empty")
		end
		io.close(input)
	else
		print("[ERROR] couldnt find quest.conf")
	end
	return nil
end

quests.callback = function (player)
	print("[quest]  done")
	if (story.generator.players_storys[player:get_player_name()].wait_for and story.generator.players_storys[player:get_player_name()].wait_for == "quest") then
		story.generator.gen_next_step(player)	
	end
end

function story.generator.run(part, player, line_pos)
	local out = {}
	print("[INFO] run script... " .. part)
	local lines = part:split("\n")
	if not lines then 
		return ""
	end	
	local i = 0
	for k,v in pairs(lines) do
		if i > line_pos-1 then
			local cmd = v:split(" ")
			if cmd[1] then
				print("[INFO] run line... " .. v)
				if cmd[1] == "$dialog" and cmd[2] then
					if story.generator.get_dialog(cmd[2], player) then
						story.generator.players_storys[player:get_player_name()].text = story.generator.get_dialog(cmd[2], player)	
					end
				end
				if cmd[1] == "$create" then
					story.generator.show(player, story.generator.players_storys[player:get_player_name()].pos)
				end
				if cmd[1] == "$place" and cmd[2] and cmd[3] then
					if cmd[2] == "at" then
						if places.pos[cmd[3]] then
							story.generator.players_storys[player:get_player_name()].pos = places.pos[cmd[3]]
						end
					elseif cmd[2] == "near" then
						if cmd[3] == "player" then
							if cmd[4] then
								local place = minetest:get_player_by_name(cmd[4]):getpos()
								story.generator.players_storys[player:get_player_name()].pos = {x=place.x+math.random(-5, 5), y=place.y, z=place.z+math.random(-5, 5)}
							else
								local place = player:getpos()
								story.generator.players_storys[player:get_player_name()].pos = {x=place.x+math.random(-5, 5), y=place.y, z=place.z+math.random(-5, 5)}						
							end
						elseif places.pos[cmd[3]] then
							local place = places.pos[cmd[3]]
							story.generator.players_storys[player:get_player_name()].pos = {x=place.x+math.random(-5, 5), y=place.y, z=place.z+math.random(-5, 5)}
						end
					else
						if places.pos[cmd[3]] then
							story.generator.players_storys[player:get_player_name()].pos = places.pos[cmd[3]]
						end
					end
				end
				if cmd[1] == "$quest" and cmd[2] and cmd[3] and cmd[4] and cmd[5] and tonumber(cmd[4]) and tonumber(cmd[5]) then
					local q_id = quests.add_quest(player:get_player_name(), {
						quest_type = cmd[2],
						node = cmd[3],
						progress = 0,
						done = false,
						max = tonumber(cmd[4]),
						xp = tonumber(cmd[5])
					})
				end
				if cmd[1] == "$pos" then
					story.generator.players_storys[player:get_player_name()].pos = {x=0,y=10,z=0}
				end
				if cmd[1] == "$next" and cmd[2] then
					if cmd[2] == "rnd" then
						if cmd[3] and cmd[4] and cmd[5] then
							local rnd = math.random(3)
							if rnd == 1 then
								out = {part=cmd[3], wait=false}
							elseif rnd == 2 then
								out = {part=cmd[4], wait=false}
							else
								out = {part=cmd[5], wait=false}
							end
						elseif cmd[3] and cmd[4] then
							local rnd = math.random(2)
							if rnd == 1 then
								out = {part=cmd[3], wait=false}
							else
								out = {part=cmd[4], wait=false}
							end
						else 
							out = {part=cmd[3], wait=false}
						end
					else
						out = {part=cmd[2], wait=false}
					end
					return out
				end
				if cmd[1] == "$wait" then
					return {cmd="$wait", param=i, wait=true, param2 = cmd[2] or "talk"}
				end
				if cmd[1] == "$spawn" and cmd[2] and cmd[3] then
					if places.pos[cmd[3]] then
						minetest.add_entity(places.pos[cmd[3]], cmd[2])
					end
				end
				if cmd[1] == "$quit" then
					out = {part="", wait=false, quit=true}
					return out
				end
				if cmd[1] == "$give" and cmd[2] and cmd[3] then
					player:get_inventory():add_item("main", cmd[2].. " " .. cmd[3])
				end
			end
		end
		i = i +1
	end
	return out
end

function story.generator.show(player, p)
	-- update waypoint
	player:hud_remove(story.hud[player:get_player_name()])
	story.hud[player:get_player_name()] = player:hud_add({
		hud_elem_type = "waypoint",
		name = "story",
		text = "",
		number = 0x00FF00,
		world_pos = p
	})
	if not p then
		return
	end

	minetest.add_entity(p, "story:human")
end

minetest.register_on_newplayer(function(player)
	story.generator.new_player(player)
	--story.generator.gen_next_step(player)
end)

minetest.register_chatcommand("restart_story", {
	params = "",
	description = "restarts your story",
	privs = {},
	func = function(name, text)
		local player = minetest.get_player_by_name(name)
		if player and player:is_player() then
			story.generator.new_player(player)
			story.generator.gen_next_step(player)
			return true, ""
		end
		return true, "Error"
	end,
})

minetest.register_chatcommand("reset_story", {
	params = "",
	description = "resets your story",
	privs = {},
	func = function(name, text)
		local player = minetest.get_player_by_name(name)
		if player and player:is_player() then
			story.generator.new_player(player)
			return true, ""
		end
		return true, "Error"
	end,
})

-- human
minetest.register_entity("story:human", {
	hp_max = 50,
	physical = true,
	collisionbox = {-0.4,-1,-0.4, 0.4,1,0.4},
 	visual = "mesh",
 	visual_size = {x=1, y=1},
	textures = {"character.png",},
	mesh = "character.x",
	spritediv = {x=1, y=1},
	initial_sprite_basepos = {x=0, y=0},	
	is_visible = true,
	makes_footstep_sound = false,
	automatic_rotate = true,
	speed = 0,
	plname = nil,
	text = nil,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end
		if not story.generator.players_storys[clicker:get_player_name()] then
			return
		end
		-- shows the dialog
		if story.generator.players_storys[clicker:get_player_name()].pos then
			if vector.distance(self.object:getpos(), story.generator.players_storys[clicker:get_player_name()].pos) < 3 then
				print("[story] not near story position")
				if (story.generator.players_storys[clicker:get_player_name()].wait_for and story.generator.players_storys[clicker:get_player_name()].wait_for == "talk") or not(story.generator.players_storys[clicker:get_player_name()].wait_for) then
					story.generator.players_storys[clicker:get_player_name()].wait_for = nil			
					minetest.show_formspec(clicker:get_player_name(), "story:story", story.get_talk_form(story.generator.players_storys[clicker:get_player_name()].text))
					story.generator.gen_next_step(clicker)	
				else
					print("[story] waiting for something else")
				end
				-- TODO : delete npc after talking with it (or move it some where else)	
			end
		else
			story.generator.players_storys[clicker:get_player_name()].wait_for = nil
			story.generator.players_storys[clicker:get_player_name()].part = story.generator.get_quest(clicker)
			story.generator.players_storys[clicker:get_player_name()].pos = self.object:getpos()
			story.generator.players_storys[clicker:get_player_name()].wait_pos = 0
			story.generator.players_storys[clicker:get_player_name()].wait = false
			story.generator.gen_next_step(clicker)	
		end
	end,

	on_step = function(self, dtime)
		self.object:setvelocity({x=0, y=-9.2, z=0})
		if math.random(50) == 15 then
			self.object:setyaw(math.random(10))
		end
	end,
})

minetest.register_craftitem("story:human", {
	description = "Human",
	inventory_image = "story_character_spawn.png",

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		local p = pointed_thing.above
		p.y = p.y + 0.5
		minetest.add_entity(p, "story:human")
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
		return itemstack
	end,
})


story.generator.load_storys()

