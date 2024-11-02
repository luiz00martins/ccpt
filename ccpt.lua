--- ComputerCraft Package Tool
--- @author PentagonLP
--- @version 1.1

-- Load properprint library
local properprint = require("/lib/properprint")
-- Load fileutils library
local fileutils = require("/lib/fileutils")
-- Load httputils library
local httputils = require("/lib/httputils")

-- Read arguments
local args = {...}

-- Link to a list of packages that are present by default (used in 'update()')
local defaultpackageurl = "https://raw.githubusercontent.com/PentagonLP/ccpt/main/defaultpackages.ccpt"

-- Counters to print out at the very end
local installed = 0
local updated = 0
local removed = 0

-- Local definitions for config arrays for global access
local actions
local installtypes
local autocomplete

---Prints only if a given boolean is 'false'
---@param text string: Text to print
---@param booleantocheck boolean: Boolean whether not to print
local function bprint(text, booleantocheck)
	if not booleantocheck then
		properprint.pprint(text)
	end
end

-- PACKAGE FUNCTIONS --

---Checks whether a package is installed
---@param packageid string: The ID of the package
---@return boolean: Is the package installed?
local function isinstalled(packageid)
	return not (fileutils.readData("/.ccpt/installedpackages",true)[packageid] == nil)
end

---Checks whether a package is installed
---@param packageid string: The ID of the package
---@return table|false: Read the data of the package from '/.ccpt/packagedata'; If package is not found return false
local function getpackagedata(packageid)
	-- Read package data
	local allpackagedata = fileutils.readData("/.ccpt/packagedata",false)
	-- Is the package data built yet?
	if allpackagedata==false then
		properprint.pprint("Package Date is not yet built. Please execute 'ccpt update' first. If this message still appears, thats a bug, please report.")
		return false
	end
	local packagedata = allpackagedata[packageid]
	-- Does the package exist?
	if packagedata==nil then
		properprint.pprint("No data about package '" .. packageid .. "' available. If you've spelled everything correctly, try executing 'ccpt update'")
		return false
	end
	-- Is the package installed?
	local installedversion = fileutils.readData("/.ccpt/installedpackages",true)[packageid]
	if not (installedversion==nil) then
		packagedata["status"] = "installed"
		packagedata["installedversion"] = installedversion
	else
		packagedata["status"] = "not installed"
	end
	return packagedata
end

---Converts an array to a String; array entrys are split with spaces
---@param array table: The array to convert
---@param iterator? boolean: If true, not the content but the address of the content within the array is converted to a string
---@return string: The String biult from the array
local function arraytostring(array,iterator)
	iterator = iterator or false
	local result = ""
	if iterator then
		for k,v in pairs(array) do
			result = result .. k .. " "
		end
	else
		for k,v in pairs(array) do
			result = result .. v .. " "
		end
	end
	return result
end

local function regexEscape(str)
	return str:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
end

---Searches all packages for updates
---@param installedpackages? table: installedpackages to prevent fetching them again; If nil they are fetched again
---@param reducedprint? boolean: If reducedprint is true, only if updates are available only the result is printed in console, but nothing else. If nil, false is taken as default.
---@return table: Table with packages with updates is returned
local function checkforupdates(installedpackages,reducedprint)
	-- If parameters are nil, load defaults
	reducedprint = reducedprint or false
	installedpackages = installedpackages or fileutils.readData("/.ccpt/installedpackages",true)

	bprint("Checking for updates...",reducedprint)

	-- Check for updates
	local packageswithupdates = {}
	for k,v in pairs(installedpackages) do
		if getpackagedata(k)["newestversion"] > v then
			packageswithupdates[#packageswithupdates+1] = k
		end
	end

	-- Print result
	if #packageswithupdates==0 then
		bprint("All installed packages are up to date!",reducedprint)
	elseif #packageswithupdates==1 then
		print("There is 1 package with a newer version available: " .. arraytostring(packageswithupdates))
	else
		print("There are " .. #packageswithupdates .." packages with a newer version available: " .. arraytostring(packageswithupdates))
	end

	return packageswithupdates
end

-- MISC HELPER FUNCTIONS --

---Checks whether a String starts with another one
---@param haystack string: String to check whether is starts with another one
---@param needle string: String to check whether another one starts with it
---@return boolean: Whether the first String starts with the second one
local function startsWith(haystack,needle)
	return string.sub(haystack,1,string.len(needle))==needle
end

---Presents a choice in console to wich the user can anser with 'y' ('yes') or 'n' ('no'). Captialisation doesn't matter.
---@return boolean: The users choice
local function ynchoice()
	while true do
		local input = io.read()
		if (input=="y") or (input == "Y") then
			return true
		elseif (input=="n") or (input == "N") then
			return false
		else
			print("Invalid input! Please use 'y' or 'n':")
		end
	end
end

-- COMMAND FUNCTIONS --

---Get packageinfo from the internet and search from updates
---@param startup? boolean: Run with startup=true on computer startup; if startup=true it doesn't print as much to the console
local function update(startup)
	startup = startup or false
	-- Fetch default Packages
	bprint("Fetching Default Packages...",startup)
	local packages = httputils.gethttpdata(defaultpackageurl)["packages"]
	if packages==false then 
		return
	end
	-- Load custom packages
	bprint("Reading Custom packages...",startup)
	local custompackages = fileutils.readData("/.ccpt/custompackages",true)
	-- Add Custom Packages to overall package list
	for k,v in pairs(custompackages) do
		packages[k] = v
	end

	-- Fetch package data from the diffrent websites
	local packagedata = {}
	for k,v in pairs(packages) do
		bprint("Downloading package data of '" .. k .. "'...",startup)
		local packageinfo = httputils.gethttpdata(v)
		if not (packageinfo==false) then
			packagedata[k] = packageinfo
		else
			properprint.pprint("Failed to retrieve data about '" .. k .. "' via '" .. v .. "'. Skipping this package.")
		end
	end
	bprint("Storing package data of all packages...",startup)
	fileutils.storeData("/.ccpt/packagedata",packagedata)
	-- Read installed packages
	bprint("Reading Installed Packages...",startup)
	local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	local installedpackagesnew = {}
	for k,v in pairs(installedpackages) do
		if packagedata[k]==nil then
			properprint.pprint("Package '" .. k .. "' was removed from the packagelist, but is installed. It will no longer be marked as 'installed', but its files won't be deleted.")
		else
			installedpackagesnew[k] = v
		end
	end
	fileutils.storeData("/.ccpt/installedpackages",installedpackagesnew)
	bprint("Data update complete!",startup)

	-- Check for updates
	checkforupdates(installedpackagesnew,startup)
end

local installpackage
local upgradepackage

---Recursive function to install Packages and dependencies
---@param packageid string: The ID of the package
---@param packageinfo? table: The packageinfo of the package; If nil it is fetched from the internet
---@return boolean: Whether the installation was successful
installpackage = function(packageid,packageinfo)
	properprint.pprint("Installing '" .. packageid .. "'...")
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		local data = getpackagedata(packageid)
		if data==false then
			return false
		end
		packageinfo = data
	end

	-- Install dependencies
	properprint.pprint("Installing dependencies of '" .. packageid .. "', if there are any...")
	for k,v in pairs(packageinfo["dependencies"]) do
		local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
		if installedpackages[k] == nil then
			if installpackage(k,nil)==false then
				return false
			end
		elseif installedpackages[k] < v then
			if upgradepackage(k,nil)==false then
				return false
			end
		end
	end

	-- Install package
	print("Installing '" .. packageid .. "'...")
	local installdata = packageinfo["install"]
	local result = installtypes[installdata["type"]]["install"](installdata)
	if result==false then
		return false
	end
	local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	installedpackages[packageid] = packageinfo["newestversion"]
	fileutils.storeData("/.ccpt/installedpackages",installedpackages)
	print("'" .. packageid .. "' successfully installed!")
	installed = installed+1
	return true
end

---Recursive function to update Packages and dependencies
---@param packageid string: The ID of the package
---@param packageinfo? table: The packageinfo of the package; If nil it is fetched from the internet
---@return boolean: Whether the update was successful
upgradepackage = function(packageid,packageinfo)
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		local data = getpackagedata(packageid)
		if data==false then
			return false
		end
		packageinfo = data
	end

	local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	if installedpackages[packageid]==packageinfo["newestversion"] then
		properprint.pprint("'" .. packageid .. "' already updated! Skipping... (This is NOT an error)")
		return true
	else
		properprint.pprint("Updating '" .. packageid .. "' (" .. installedpackages[packageid] .. "->" .. packageinfo["newestversion"] .. ")...")
	end

	-- Install/Update dependencies
	properprint.pprint("Updating or installing new dependencies of '" .. packageid .. "', if there are any...")
	for k,v in pairs(packageinfo["dependencies"]) do
		local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
		if installedpackages[k] == nil then
			if installpackage(k,nil)==false then
				return false
			end
		elseif installedpackages[k] < v then
			if upgradepackage(k,nil)==false then
				return false
			end
		end
	end

	-- Install package
	print("Updating '" .. packageid .. "'...")
	local installdata = packageinfo["install"]
	local result = installtypes[installdata["type"]]["update"](installdata)
	if result==false then
		return false
	end
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	installedpackages[packageid] = packageinfo["newestversion"]
	fileutils.storeData("/.ccpt/installedpackages",installedpackages)
	print("'" .. packageid .. "' successfully updated!")
	updated = updated+1
	return true
end

---Install a Package 
local function install()
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt install <PackageID>'")
		return
	end
	local packageinfo = getpackagedata(args[2])
	if packageinfo == false then
		return
	end
	if packageinfo["status"] == "installed" then
		properprint.pprint("Package '" .. args[2] .. "' is already installed.")
		return
	end
	-- Ok, all clear, lets get installing!
	local result = installpackage(args[2],packageinfo)
	if result==false then
		return
	end
	print("Install of '" .. args[2] .. "' complete!")
end

-- Different install methodes

---@param installdata table: The installdata of the package
---@return boolean: Whether the installation was successful
local function installlibrary(installdata)
	local result = httputils.downloadfile("lib/" .. installdata["filename"],installdata["url"])
	if result==false then
		return false
	end
	return true
end

---@param installdata table: The installdata of the package
---@return boolean: Whether the installation was successful
local function installscript(installdata)
	local result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","install")
	fs.delete("/.ccpt/tempinstaller")
	return true
end

---Upgrade installed Packages
local function upgrade()
	--TODO: Single package updates
	local packageswithupdates = checkforupdates(fileutils.readData("/.ccpt/installedpackages",true),false)
	if packageswithupdates==false then
		return
	end
	if #packageswithupdates==0 then
		return
	end
	properprint.pprint("Do you want to update these packages? [y/n]:")
	if not ynchoice() then
		return
	end
	for k,v in pairs(packageswithupdates) do
		upgradepackage(v,nil)
	end
end

---Different install methodes require different update methodes
---@param installdata table: The installdata of the package
---@return boolean: Whether the update was successful
local function updatescript(installdata)
	local result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","update")
	fs.delete("/.ccpt/tempinstaller")
	return true
end

---Recursive function to find all Packages that are dependent on the one we want to remove to also remove them
---@param packageid string: The ID of the package
---@param packageinfo table|nil: The packageinfo of the package; If nil it is fetched from the internet
---@param installedpackages table: The installedpackages table
---@param packagestoremove table: The packagestoremove table
---@return table|false: The packagestoremove table or false if an error occured
local function getpackagestoremove(packageid,packageinfo,installedpackages,packagestoremove)
	packagestoremove[packageid] = true
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		local data = getpackagedata(packageid)
		if data==false then
			return false
		end
		packageinfo = data
	end

	-- Check packages that are dependent on that said package
	for k,v in pairs(installedpackages) do
		if not (getpackagedata(k)["dependencies"][packageid]==nil) then
			local packagestoremovenew = getpackagestoremove(k,nil,installedpackages,packagestoremove)
			if packagestoremovenew==false then
				return false
			end
			for l,w in pairs(packagestoremovenew) do
				packagestoremove[l] = true
			end
		end
	end

	return packagestoremove
end

---Remove installed Packages
local function uninstall()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt uninstall <PackageID>'")
		return
	end
	local packageinfo = getpackagedata(args[2])
	if packageinfo == false then
		return
	end
	if packageinfo["status"] == "not installed" then
		properprint.pprint("Package '" .. args[2] .. "' is not installed.")
		return
	end

	-- Check witch package(s) to remove (A package dependent on a package that's about to get removed is also removed)
	local packagestoremove = getpackagestoremove(args[2],packageinfo,fileutils.readData("/.ccpt/installedpackages",true),{})
	if packagestoremove==false then
		return
	end
	local packagestoremovestring = ""
	for k,v in pairs(packagestoremove) do
		if not (k==args[2]) then
			local packagestoremovestring = packagestoremovestring .. k .. " "
		end
	end

	-- Are you really really REALLY sure to remove these packages?
	if not (#packagestoremovestring==0) then
		properprint.pprint("There are installed packages that depend on the package you want to uninstall: " .. packagestoremovestring)
		properprint.pprint("These packages will be removed if you proceed. Are you sure you want to continue? [y/n]:")
		if ynchoice() == false then
			return
		end
	else
		properprint.pprint("There are no installed packages that depend on the package you want to uninstall.")
		properprint.pprint("'" .. args[2] .. "' will be removed if you proceed. Are you sure you want to continue? [y/n]:")
		if ynchoice() == false then
			return
		end
	end

	-- If ccpt would be removed in the process, tell the user that that's a dump idea. But I mean, who am I to stop him, I guess...
	for k,v in pairs(packagestoremove) do
		if k=="ccpt" then
			if args[2] == "ccpt" then
				properprint.pprint("You are about to uninstall the package tool itself. You won't be able to install or uninstall stuff using the tool afterwards (obviously). Are you sure you want to continue? [y/n]:")
			else
				properprint.pprint("You are about to uninstall the package tool itself, because it depends one or more package that is removed. You won't be able to install or uninstall stuff using the tool afterwards (obviously). Are you sure you want to continue? [y/n]:")
			end

			if ynchoice() == false then
				return
			end
			break
		end
	end

	-- Uninstall package(s)
	for k,v in pairs(packagestoremove) do
		print("Uninstalling '" .. k .. "'...")
		local installdata = getpackagedata(k)["install"]
		local result = installtypes[installdata["type"]]["remove"](installdata)
		if result==false then
			return false
		end
		local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
		installedpackages[k] = nil
		fileutils.storeData("/.ccpt/installedpackages",installedpackages)
		print("'" .. k .. "' successfully uninstalled!")
		removed = removed+1
	end
end

-- Different install methodes require different uninstall methodes

---@param installdata table: The installdata of the package
local function removelibrary(installdata)
	fs.delete("lib/" .. installdata["filename"])
end

---@param installdata table: The installdata of the package
---@return boolean: Whether the uninstallation was successful
local function removescript(installdata)
	local result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","remove")
	fs.delete("/.ccpt/tempinstaller")
	return true
end

---Add custom package URL to local list
local function add()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt add <PackageID> <PackageinfoURL>'")
		return
	end
	if args[3] == nil then
		properprint.pprint("Incomplete command, missing: 'Packageinfo URL'; Syntax: 'ccpt add <PackageID> <PackageinfoURL>'")
		return
	end
	local custompackages = fileutils.readData("/.ccpt/custompackages",true)
	if not (custompackages[args[2]]==nil) then
		properprint.pprint("A custom package with the id '" .. args[2] .. "' already exists! Please choose a different one.")
		return
	end
	if not fs.exists("/.ccpt/packagedata") then
		properprint.pprint("Package Date is not yet built. Please execute 'ccpt update' first. If this message still appears, thats a bug, please report.")
	end
	-- Overwrite default packages?
	if not (fileutils.readData("/.ccpt/packagedata",true)[args[2]]==nil) then
		properprint.pprint("A package with the id '" .. args[2] .. "' already exists! This package will be overwritten if you proceed. Do you want to proceed? [y/n]:")
		if not ynchoice() then
			return
		end
	end
	-- Add entry in custompackages file
	custompackages[args[2]] = args[3]
	fileutils.storeData("/.ccpt/custompackages",custompackages)
	properprint.pprint("Custom package successfully added!")
	-- Update packagedata?
	properprint.pprint("Do you want to update the package data ('ccpt update')? Your custom package won't be able to be installed until updating. [y/n]:")
	if ynchoice() then
		update()
	end
end

---Remove Package URL from local list
local function remove()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt remove <PackageID>'")
		return
	end
	local custompackages = fileutils.readData("/.ccpt/custompackages",true)
	if custompackages[args[2]]==nil then
		properprint.pprint("A custom package with the id '" .. args[2] .. "' does not exist!")
		return
	end
	-- Really wanna do that?
	properprint.pprint("Do you want to remove the custom package '" .. args[2] .. "'? There is no undo. [y/n]:")
	if not ynchoice() then
		properprint.pprint("Canceled. No action was taken.")
		return
	end
	-- Remove entry from custompackages file
	custompackages[args[2]] = nil
	fileutils.storeData("/.ccpt/custompackages",custompackages)
	properprint.pprint("Custom package successfully removed!")
	-- Update packagedata?
	properprint.pprint("Do you want to update the package data ('ccpt update')? Your custom package will still be able to be installed/updated/uninstalled until updating. [y/n]:")
	if ynchoice() then
		update()
	end
end

---Info about a package
local function info()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt info <PackageID>'")
		return
	end
	-- Get packagedata
	local packageinfo = getpackagedata(args[2])
	if packageinfo == false then
		return
	end
	-- Print packagedata
	properprint.pprint(packageinfo["name"] .. " by " .. packageinfo["author"])
	properprint.pprint(packageinfo["comment"])
	if not (packageinfo["website"]==nil) then
		properprint.pprint("Website: " .. packageinfo["website"])
	end
	properprint.pprint("Installation Type: " .. installtypes[packageinfo["install"]["type"]]["desc"])
	if packageinfo["status"]=="installed" then
		properprint.pprint("Installed, Version: " .. packageinfo["installedversion"] .. "; Newest Version is " .. packageinfo["newestversion"])
	else
		properprint.pprint("Not installed; Newest Version is " .. packageinfo["newestversion"])
	end
end

---List all Packages
local function list()
	-- Read data
	print("Reading all packages data...")
	if not fs.exists("/.ccpt/packagedata") then
		properprint.pprint("No Packages found. Please run 'ccpt update' first.'")
		return
	end
	local packagedata = fileutils.readData("/.ccpt/packagedata",true)
	print("Reading Installed packages...")
	local installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	-- Print list
	properprint.pprint("List of all known Packages:")
	for k,v in pairs(installedpackages) do
		local updateinfo
		if packagedata[k]["newestversion"] > v then
			updateinfo = "outdated"
		else
			updateinfo = "up to date"
		end
		properprint.pprint(k .. " (installed, " .. updateinfo .. ")",2)
	end
	for k,v in pairs(packagedata) do
		if installedpackages[k] == nil then
			properprint.pprint(k .. " (not installed)",2)
		end
	end
end

---Run on Startup
local function startup()
	-- Update silently on startup
	update(true)
end

---Print help
local function help()
	print("Syntax: ccpt")
	for i,v in pairs(actions) do
		if (not (v["comment"] == nil)) then
			properprint.pprint(i .. ": " .. v["comment"],5)
		end
	end
	print("")
	print("This package tool has Super Creeper Powers.")
end

---Print Version
local function version()
	-- Count lines
	local linecount = 0
	for _ in io.lines'.ccpt/program/ccpt' do
		linecount = linecount + 1
	end
	-- Print version
	properprint.pprint("ComputerCraft Package Tool")
	properprint.pprint("by PentagonLP")
	properprint.pprint("Version: 1.0")
	properprint.pprint(linecount .. " lines of code containing " .. #fileutils.readFile(".ccpt/program/ccpt",nil) .. " Characters.")
end

-- Idk randomly appeared one day

---Fuse
local function zzzzzz()
	properprint.pprint("The 'ohnosecond':")
	properprint.pprint("The 'ohnosecond' is the fraction of time between making a mistake and realizing it.")
	properprint.pprint("(Oh, and please fix the hole you've created)")
end

---Explode
local function boom()
	print("|--------------|")
	print("| |-|      |-| |")
	print("|    |----|    |")
	print("|  |--------|  |")
	print("|  |--------|  |")
	print("|  |-      -|  |")
	print("|--------------|")
	print("....\"Have you exploded today?\"...")
end

-- TAB AUTOCOMLETE HELPER FUNCTIONS --

---Add Text to result array if it fits
---@param option string: Autocomplete option to check
---@param texttocomplete string: The already typed in text to complete
---@param result table: Array to add the option to if it passes the check
local function addtoresultifitfits(option,texttocomplete,result)
	if startsWith(option,texttocomplete) then
		result[#result+1] = string.sub(option,#texttocomplete+1)
	end
	return result
end

-- Functions to complete different subcommands of a command

---Complete action (eg. "update" or "list")
---@param curText string: The already typed in text to complete
---@return table: The result array
local function completeaction(curText)
	local result = {}
	for i,v in pairs(actions) do
		if (not (v["comment"] == nil)) then
			result = addtoresultifitfits(i,curText,result)
		end
	end
	return result
end

local autocompletepackagecache = {}
---Complete packageid (filter can be nil to display all, "installed" to only recommend installed packages or "not installed" to only recommend not installed packages)
---@param curText? string: The already typed in text to complete
---@param filterstate? string: The filterstate to apply; can be nil to display all, "installed" to only recommend installed packages or "not installed" to only recommend not installed packages
---@return table: The result array
local function completepackageid(curText,filterstate)
	local result = {}
	if curText=="" or curText==nil then
		local packagedata = fileutils.readData("/.ccpt/packagedata",false)
		if not packagedata then
			return {}
		end
		autocompletepackagecache = packagedata
		curText = ""
	end
	local installedversion
	if not (filterstate==nil) then
		installedversion = fileutils.readData("/.ccpt/installedpackages",true)
	end
	for i,v in pairs(autocompletepackagecache) do
		if filterstate=="installed" then
			if not (installedversion[i]==nil) then
				result = addtoresultifitfits(i,curText,result)
			end
		elseif filterstate=="not installed" then
			if installedversion[i]==nil then
				result = addtoresultifitfits(i,curText,result)
			end
		else
			result = addtoresultifitfits(i,curText,result)
		end
	end
	return result
end

---Complete packageid, but only for custom packages, which is much simpler
---@param curText string: The already typed in text to complete
---@return table: The result array
local function completecustompackageid(curText)
	local result = {}
	local custompackages = fileutils.readData("/.ccpt/custompackages",true)
	for i,v in pairs(custompackages) do
		result = addtoresultifitfits(i,curText,result)
	end
	return result
end

---Recursive function to go through the 'autocomplete' array and complete commands accordingly
---@param lookup table: Part of the 'autocomplete' array to look autocomplete up in
---@param lastText table: Numeric array of parameters before the current one
---@param curText string: The already typed in text to complete
---@param iterator integer: Last position in the lookup array
---@return table: Available complete options
local function tabcompletehelper(lookup,lastText,curText,iterator)
	if lookup[lastText[iterator]]==nil then
		return {}
	end
	if #lastText==iterator then
		return lookup[lastText[iterator]]["func"](curText,table.unpack(lookup[lastText[iterator]]["funcargs"]))
	elseif lookup[lastText[iterator]]["next"]==nil then
		return {}
	else
		return tabcompletehelper(lookup[lastText[iterator]]["next"],lastText,curText,iterator+1)
	end
end

-- CONFIG ARRAYS --
---Array to store subcommands, help comment and function
actions = {
	update = {
		func = update,
		comment = "Search for new Versions & Packages"
	},
	install = {
		func = install,
		comment = "Install new Packages"
	},
	upgrade = {
		func = upgrade,
		comment = "Upgrade installed Packages"
	},
	uninstall = {
		func = uninstall,
		comment = "Remove installed Packages"
	},
	add = {
		func = add,
		comment = "Add Package URL to local list"
	},
	remove = {
		func = remove,
		comment = "Remove Package URL from local list"
	},
	list = {
		func = list,
		comment = "List installed and able to install Packages"
	},
	info = {
		func = info,
		comment = "Information about a package"
	},
	startup = {
		func = startup
	},
	help = {
		func = help,
		comment = "Print help"
	},
	version = {
		func = version,
		comment = "Print CCPT Version"
	},
	zzzzzz = {
		func = zzzzzz
	},
	boom = {
		func = boom
	}
} 

---Array to store different installation methodes and corresponding functions
installtypes = {
	library = {
		install = installlibrary,
		update = installlibrary,
		remove = removelibrary,
		desc = "Single file library"
	},
	script = {
		install = installscript,
		update = updatescript,
		remove = removescript,
		desc = "Program installed via Installer"
	}
}

---Array to store autocomplete information
autocomplete = {
	func = completeaction,
	funcargs = {},
	next = {
		install = {
			func = completepackageid,
			funcargs = {"not installed"}
		},
		uninstall = {
			func = completepackageid,
			funcargs = {"installed"}
		},
		remove = {
			func = completecustompackageid,
			funcargs = {}
		},
		info = {
			func = completepackageid,
			funcargs = {}
		}
	}
}

-- MAIN AUTOCOMLETE FUNCTION --

--- Main autocomplete function
---@param shell shell: The shell object
---@param parNumber integer: The number of parameters before the current one
---@param curText string: The already typed in text to complete
---@param lastText table: Numeric array of parameters before the current one
---@return table: The result array
local function tabcomplete(shell, parNumber, curText, lastText)
	local result = {}
	tabcompletehelper(
		{
			ccpt = autocomplete
		},
	lastText,curText or "",1)
	return result
end

-- MAIN PROGRAM --

-- Add to working path
if string.find(shell.path(),regexEscape(":.ccpt/program"))==nil then
	shell.setPath(shell.path()..":.ccpt/program")
end

-- Register autocomplete function
shell.setCompletionFunction(".ccpt/program/ccpt", tabcomplete)

-- Add to startup file/folder to run at startup
local startupcontent = "-- ccpt: Search for updates\nshell.run(\".ccpt/program/ccpt\",\"startup\")"
if fs.isDir("startup") then
	if not fs.exists("startup/ccpt.lua") then
		fileutils.storeFile("startup/ccpt.lua", startupcontent)
		print("[Installer] Startup entry created in startup folder!")
	end
else
	local startup = fileutils.readFile("startup","") or ""
	if string.find(startup,"shell.run(\".ccpt/program/ccpt\",\"startup\")",1,true)==nil then
		startup = startupcontent .. "\n\n" .. startup
		fileutils.storeFile("startup",startup)
		print("[Installer] Startup entry created!")
	end
end

-- Call required function
if #args==0 then
	properprint.pprint("Incomplete command, missing: 'Action'; Type 'ccpt help' for syntax.")
else if actions[args[1]]==nil then
		properprint.pprint("Action '" .. args[1] .. "' is unknown. Type 'ccpt help' for syntax.")
	else
		actions[args[1]]["func"]()
	end
end

-- List stats of recent operation
if not (installed+updated+removed==0) then
	local actionmessage = ""
	if installed==1 then
		actionmessage =	"1 package installed, "
	else
		actionmessage = installed .. " packages installed, "
	end
	if updated==1 then
		actionmessage =	actionmessage .. "1 package updated, "
	else
		actionmessage = actionmessage .. updated .. " packages updated, "
	end
	if removed==1 then
		actionmessage =	actionmessage .. "1 package removed."
	else
		actionmessage = actionmessage .. removed .. " packages removed."
	end
	properprint.pprint(actionmessage)
end