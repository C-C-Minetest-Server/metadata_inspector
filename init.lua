local S = minetest.get_translator("metadata_inspector")
local gui = flow.widgets

local my_gui = flow.make_gui(function(player, ctx)
	-- ctx.pos should be the position of the node.
	local name = player:get_player_name()
	local pos = ctx.pos

	local privs = minetest.get_player_privs(name)
	if minetest.is_protected(pos,name) and not(privs.protection_bypass or privs.server) then
		minetest.record_protection_violation(pos,name)
		return gui.Label {label = S("Position is protected!")}
	end

	if not ctx.cache then
		ctx.cache = (minetest.get_meta(pos):to_table() or {}).fields or {}
	end

	local function update_cache(player,ctx)
		for x,y in pairs(ctx.form) do
			local actioncode = string.sub(x,1,1)
			if actioncode == "v" then
				local key = string.sub(x,2)
				ctx.cache[key] = y
			end
		end
	end
	local function svbox_build_component(x,y)
		return gui.HBox {
			gui.Label {
				label = x,
				h = 1,
				w = 3,
			},
			gui.Textarea {
				name = "v" .. x, -- v<x>
				label = S("Value"),
				default = y,
				h = 1, align_h = "left", expand = true,
				w = 7,
			},
			gui.Button {
				name = "d" .. x, -- d<x>
				label = "x",
				h = 1, w = 1,
				on_event = function(player,ctx)
					update_cache(player,ctx)
					ctx.cache[x] = nil
					ctx.form["v" .. x] = nil
					print(dump(ctx.cache))
					return true
				end,
			},
		}
	end
	local svbox_content = {}
	for x, y in pairs(ctx.cache) do
		if x == "metadatainspect_dummy" then else -- see Ln.119
			table.insert(svbox_content,svbox_build_component(x,y))
		end
	end
	table.insert(svbox_content,gui.HBox {
		gui.Field {
			name = "inewname",
			label = S("Name"),
			h = 1,w = 4,
		},
		gui.Button{
			label = "+",
			h = 1, w = 1,expand=true,align_h = "left",
			on_event = function(player,ctx)
				update_cache(player,ctx)
				if not ctx.form.inewname or ctx.form.inewname == "" then return end
				ctx.cache[ctx.form.inewname] = ""
				return true
			end
		},
	})
	svbox_content.name = "svbox"
	svbox_content.h = 7
	svbox_content.w = 12

	return gui.VBox {
		gui.label { label = S("Editing metadata of node at @1",minetest.pos_to_string(pos))},
		gui.Box{w = 1, h = 0.05, color = "grey", padding = 0.25},
		gui.ScrollableVBox(svbox_content),
		gui.Box{w = 1, h = 0.05, color = "grey", padding = 0.25},
		gui.HBox {
			gui.Label {
				label = ctx.msg or S("Ready"),
				expand = true, align_h = "left",
			},
			gui.ButtonExit {
				label = S("Abort/Exit")
			},
			gui.Button {
				label = S("Save"),
				on_event = function(player,ctx)
					update_cache(player,ctx)
					local name = player:get_player_name()
					local pos = ctx.pos

					local privs = minetest.get_player_privs(name)
					if minetest.is_protected(pos,name) and not(privs.protection_bypass or privs.server) then
						minetest.record_protection_violation(pos,name)
						ctx.msg = S("Position is protected!")
						return true
					end

					local name = player:get_player_name()
					local node = minetest.get_node(ctx.pos).name
					if node == "air" or node == "ignore" then
						ctx.msg = S("Invalid node!")
						return true
					end

					local meta = minetest.get_meta(pos)
					local metatable = meta:to_table()
					metatable.fields = ctx.cache
					-- Workaround: Infotext won't update if the resulting metadata is empty until restart
					ctx.cache.metadatainspect_dummy = "" .. os.time()
					meta:from_table(metatable)
					ctx.msg = S("Saved.")
					return true
				end
			}
		}
	}
end)

minetest.register_craftitem("metadata_inspector:tool",{
	description = S("Metadata Inspector"),
	inventory_image = default and "default_stick.png^[brighten",
	on_place = function(itemstack, placer, pointed_thing)
		if not placer:is_player() then return end
		local pos = pointed_thing.under
		local node = minetest.get_node(pos).name
		local name = placer:get_player_name()
		if node == "air" or node == "ignore" then
			minetest.chat_send_player(name,S("Invalid node!"))
			return
		end

		my_gui:show(placer, {pos=pos})
	end
})
