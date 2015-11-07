local component = require("component")
local event = require("event")
local os = require("os")
local serialization = require("serialization")
local filesystem = require("filesystem")
local keyboard = require("keyboard")
local string = require("string")
local math = require("math")
local term = require("term")

local superlib = require("superlib")

dbfile = "/authdb.dat"

writer = component.os_cardwriter

function loadDB()
	if filesystem.exists(dbfile) == false then
		ldb = {pairs = {}, registered = {}, new = {}}
	else
		f = filesystem.open(dbfile, "rb")
		rdb = f:read(filesystem.size(dbfile))
		ldb = serialization.unserialize(rdb)
		f:close()
	end
	return ldb
end

function saveDB(ldb)
	f = io.open(dbfile, "wb")
	f:write(serialization.serialize(ldb))
	f:close()
end

rdb = loadDB()
saveDB(rdb)

local function openDoor(door)
	if door.isopen() == false then
		door.toggle()
	end
end

local function closeDoor(door)
	if door.isopen() then
		door.toggle()
	end
end

local function toggleDoor(door)
	door = component.proxy(door)
	door.toggle()
	os.sleep(5)
	openDoor(door)
	os.sleep(5)
	closeDoor(door)
end

local function checkCard(UUID)
	db = loadDB()
	for i in ipairs(db["registered"]) do
		if db["registered"][i]["uuid"] == UUID then
			return true, db["registered"]["username"]
		end
	end
	return false
end

local function getUser(msg)
	io.write(msg)
	return io.read()
end

local function makeCode(l)
    local s = ""
    for i = 1, l do
        s = s .. string.char(math.random(32, 126))
    end
    return s
end

local function registerCard()
	db = loadDB()
	print("Registering new card.")
	cardcode = makeCode(10)
	title = getUser("Enter the title for the card: ")
	writer.write(cardcode, title, true)
	table.insert(db["new"], cardcode)
	print("The card will be registered to the user who swipes it next.")
	saveDB(db)
	os.sleep(1)
end

local function registerDoor()
	db = loadDB()
	freeDoors = {}
	freeMags = {}

	for address, ctype in component.list() do
		if ctype == "os_door" then
			reg = false
			for raddr in ipairs(db["pairs"]) do
				if address == db["pairs"][raddr]["door"] then
					reg = true
				end
			end
			if not reg then 
				table.insert(freeDoors, address) 
			end
		end

		if ctype == "os_magreader" then
			reg = false
			for raddr in ipairs(db["pairs"]) do
				if address == db["pairs"][raddr]["mag"] then
					reg = true
				end
			end
			if not reg then 
				table.insert(freeMags, address) 
			end
		end
	end

	print("Please select the door uuid you want to add.")
	superlib.clearMenu()
	for i, d in ipairs(freeDoors) do
		superlib.addItem(d, d)
	end
	superlib.addItem("Cancel", "c")
	door = superlib.runMenu()
	print(door)
	os.sleep(1)

	if door ~= "c" then
		print("Please select the mag reader uuid you want to pair to the door.")
		superlib.clearMenu()
		for i, d in ipairs(freeMags) do
			superlib.addItem(d, d)
		end
		superlib.addItem("Cancel", "c")
		mag = superlib.runMenu()

		if mag ~= "c" then
			table.insert(db["pairs"], {door=door, mag=mag})
		end
	end
	saveDB(db)
end

function check(maddr, paddr, dooraddr)
	if maddr == paddr then 
		print("Opening Door") 
		toggleDoor(dooraddr) 
	end
	if maddr ~= paddr then print("Invalid Door") end
end

function auth(_,addr, playerName, data, UUID, locked)
	db = loadDB()

	for i in ipairs(db["new"]) do --Check for first swipe of newly registered card, and get its UUID
		if db["new"][i] == data then
			table.insert(db["registered"], {username=playerName, uuid=UUID})
			print("Registered card ".. UUID .. " to user ".. playerName)
			table.remove(db["new"], i)
			saveDB(db)
		end
	end

	allowed, username = checkCard(UUID)
	if allowed then
		for u, d in ipairs(db["pairs"]) do
			check(addr, d["mag"], d["door"])
		end
	end	
end



local function menus() 
	term.clear()

	print("Super Security System [Beta]")
	superlib.clearMenu()
	superlib.addItem("Register a card", "r")
	superlib.addItem("Register a door", "d")

	key = superlib.runMenu()

	if key == "r" then
		registerCard()
	elseif key == "d" then
		registerDoor()
	end
end

function main()
	event.ignore("magData", auth)
	event.listen("magData", auth)
	while true do
		menus()
	end
end
main()
