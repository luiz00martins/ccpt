---ComputerCraft Package Tool Installer
---@author PentagonLP, SkyTheCodeMaster
---@version 1.1

-- Read arguments
local args = {...}
-- Read branch or use main
args[2] = args[2] or "main"

-- FILE MANIPULATION FUNCTIONS --

--- Stores a file in a desired location
---@param filepath string: Filepath where to create file (if file already exists, it gets overwritten)
---@param content string: Content to store in file
local function storeFile(filepath,content)
	local writefile = fs.open(filepath,"w")
	writefile.write(content)
	writefile.close()
end

--- Reads a file from a desired location
---@param filepath string: Filepath to the file to read
---@param createnew? string: (Optional) Content to store in new file and return if file does not exist. Can be nil.
---@return string|false content|error: Content of the file; If createnew is nil and file doesn't exist boolean false is returned
local function readFile(filepath,createnew)
	local readfile = fs.open(filepath,"r")
	if not readfile then
		if not (createnew==nil) then
			storeFile(filepath,createnew)
			return createnew
		else
			return false
		end
	end
	local content = readfile.readAll()
	readfile.close()
	if content==nil then
		return false
	end
	return content
end

--- Stores a table in a file
---@param filepath string: Filepath where to create file (if file already exists, it gets overwritten)
---@param data table: Table to store in file
local function storeData(filepath,data)
	storeFile(filepath,textutils.serialize(data):gsub("\n",""))
end

--- Reads a table from a file in a desired location
---@param filepath string: Filepath to the file to read
---@param createnew? boolean: If true, an empty table is stored in new file and returned if file does not exist.
---@return table|boolean content|error: Table thats stored in the file; If createnew is false and file doesn't exist boolean false is returned
local function readData(filepath,createnew)
	local content
	if createnew then
		content = readFile(filepath,textutils.serialize({}):gsub("\n",""))
	else
		content = readFile(filepath,nil)
	end
	if content==false then
		return false
	end
	return textutils.unserialize(content)
end

-- HTTP FETCH FUNCTIONS --
--- Gets result of HTTP URL
---@param url string: The desired URL
---@return table|boolean result|error: The result of the request; If the URL is not reachable, an error is printed in the terminal and boolean false is returned
local function gethttpresult(url)
	if not http.checkURL(url) then
		print("ERROR: Url '" .. url .. "' is blocked in config. Unable to fetch data.")
		return false
	end
	local result,err = http.get(url)
	if not result then
		print("ERROR: Unable to reach '" .. url .. "' because '" .. err .. "'")
		return false
	end
	return result
end

--- Downloads a file from a desired URL
---@param filepath string: Filepath where to create file (if file already exists, it gets overwritten)
---@param url string: The desired URL
---@return boolean error: If the URL is not reachable, an error is printed in the terminal and boolean false is returned; If everything goes well, true is returned
local function downloadfile(filepath,url)
	local result = gethttpresult(url)
	if not result then 
		return false
	end
	storeFile(filepath,result.readAll())
	return true
end

-- MISC HELPER FUNCTIONS --

--- Checks whether a String starts with another one
---@param haystack string: String to check whether is starts with another one
---@param needle string: String to check whether another one starts with it
---@return boolean result: Whether the first String starts with the second one
local function startsWith(haystack,needle)
	return string.sub(haystack,1,string.len(needle))==needle
end

local function regexEscape(str)
	return str:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
end

local toInstall = {
	pprint = {
		url = "https://raw.githubusercontent.com/PentagonLP/properprint/main/properprint",
		path = "lib/properprint"
	},
	fileutils = {
		url = "https://raw.githubusercontent.com/PentagonLP/fileutils/main/fileutils",
		path = "lib/fileutils"
	},
	httputils = {
		url = "https://raw.githubusercontent.com/PentagonLP/httputils/main/httputils.lua",
		path = "lib/httputils"
	},
	ccpt = {
		url = "https://raw.githubusercontent.com/PentagonLP/ccpt/" .. args[2] .. "/ccpt.lua",
		path = ".ccpt/program/ccpt"
	}
}

-- MAIN PROGRAM --
if (args[1]=="install") or (args[1]==nil) then
	print("[Installer] Well, hello there!")
	print("[Installer] Thank you for downloading the ComputerCraft Package Tool! Installing...")
	for k,v in pairs(toInstall) do
		print("[Installer] Installing '" .. k .. "'...")
		if not downloadfile(v["path"],v["url"]) then
			return false
		end
		print("[Installer] Successfully installed '" .. k .. "'!")
	end
	print("[Installer] Running 'ccpt update'...")
	shell.run(toInstall["ccpt"]["path"],"update")
	print("[Installer] Reading package data...")
	local packagedata = readData("/.ccpt/packagedata")
	print("[Installer] Storing installed packages...")
	local installedpackages = {}
	for k,v in pairs(toInstall) do
		installedpackages[k] = packagedata[k]["newestversion"]
	end
	storeData("/.ccpt/installedpackages",installedpackages)
	print("[Installer] Install of 'ccpt' finished!")
elseif args[1]=="update" then
	print("[Installer] Updating 'ccpt'...")
	fs.delete("/ccpt")
	if not downloadfile(toInstall["ccpt"]["path"],toInstall["ccpt"]["url"]) then
		return false
	end
elseif args[1]=="remove" then
	print("[Installer] Uninstalling 'ccpt'...")
	fs.delete("/.ccpt")
	shell.setCompletionFunction("ccpt", nil)
	shell.setPath(string.gsub(shell.path(),regexEscape(":.ccpt/program")))

	if fs.isDir("startup") then
		print("[Installer] Removing 'ccpt' from startup folder...")
		if fs.exists("startup/ccpt.lua") then
			fs.delete("startup/ccpt.lua")
		end
	else
		print("[Installer] Removing 'ccpt' from startup...")
		local startup = readFile("startup","")
		if startup == false then
			print("[Installer] No 'ccpt' found in startup!")
		else
			startup = string.gsub(startup,regexEscape("-- ccpt: Search for updates"), "")
			startup = string.gsub(startup,regexEscape("shell.run(\".ccpt/program/ccpt\",\"startup\")"), "")
			storeFile("startup",startup)
		end
	end
	print("[Installer] So long, and thanks for all the fish!")
else
	print("[Installer] Invalid argument: " .. args[1])
end