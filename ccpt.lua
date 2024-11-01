--[[ 
	ComputerCraft Package Tool
	Author: PentagonLP
	Version: 1.1
]]

-- Load properprint library
local properprint = require("/lib/properprint")
-- Load fileutils library
local fileutils = require("/lib/fileutils")
-- Load httputils library
local httputils = require("/lib/httputils")

-- Read arguments
args = {...}

-- Link to a list of packages that are present by default (used in 'update()')
defaultpackageurl = "https://raw.githubusercontent.com/PentagonLP/ccpt/main/defaultpackages.ccpt"

-- Counters to print out at the very end
installed = 0
updated = 0
removed = 0

-- PACKAGE FUNCTIONS --
--[[ Checks wether a package is installed
	@param String packageid: The ID of the package
	@return boolean installed: Is the package installed?
]]--
function isinstalled(packageid)
	return not (fileutils.readData("/.ccpt/installedpackages",true)[packageid] == nil)
end

--[[ Checks wether a package is installed
	@param String packageid: The ID of the package
	@return Table|boolean packagedata|error: Read the data of the package from '/.ccpt/packagedata'; If package is not found return false
]]--
function getpackagedata(packageid)
	-- Read package data
	allpackagedata = fileutils.readData("/.ccpt/packagedata",false)
	-- Is the package data built yet?
	if allpackagedata==false then
		properprint.pprint("Package Date is not yet built. Please execute 'ccpt update' first. If this message still apears, thats a bug, please report.")
		return false
	end
	packagedata = allpackagedata[packageid]
	-- Does the package exist?
	if packagedata==nil then
		properprint.pprint("No data about package '" .. packageid .. "' availible. If you've spelled everything correctly, try executing 'ccpt update'")
		return false
	end
	-- Is the package installed?
	installedversion = fileutils.readData("/.ccpt/installedpackages",true)[packageid]
	if not (installedversion==nil) then
		packagedata["status"] = "installed"
		packagedata["installedversion"] = installedversion
	else
		packagedata["status"] = "not installed"
	end
	return packagedata
end

--[[ Searches all packages for updates
	@param Table|nil installedpackages|nil: installedpackages to prevent fetching them again; If nil they are fetched again
	@param boolean|nil reducedprint|nil: If reducedprint is true, only if updates are availible only the result is printed in console, but nothing else. If nil, false is taken as default.
	@result Table packageswithupdates: Table with packages with updates is returned
]]--
function checkforupdates(installedpackages,reducedprint)
	-- If parameters are nil, load defaults
	reducedprint = reducedprint or false
	installedpackages = installedpackages or fileutils.readData("/.ccpt/installedpackages",true)
	
	bprint("Checking for updates...",reducedprint)
	
	-- Check for updates
	packageswithupdates = {}
	for k,v in pairs(installedpackages) do
		if getpackagedata(k)["newestversion"] > v then
			packageswithupdates[#packageswithupdates+1] = k
		end
	end
	
	-- Print result
	if #packageswithupdates==0 then
		bprint("All installed packages are up to date!",reducedprint)
	elseif #packageswithupdates==1 then
		print("There is 1 package with a newer version availible: " .. arraytostring(packageswithupdates))
	else
		print("There are " .. #packageswithupdates .." packages with a newer version availible: " .. arraytostring(packageswithupdates))
	end
	
	return packageswithupdates
end

-- MISC HELPER FUNCTIONS --
--[[ Checks wether a String starts with another one
	@param String haystack: String to check wether is starts with another one
	@param String needle: String to check wether another one starts with it
	@return boolean result: Wether the firest String starts with the second one
]]--
function startsWith(haystack,needle)
	return string.sub(haystack,1,string.len(needle))==needle
end

--[[ Presents a choice in console to wich the user can anser with 'y' ('yes') or 'n' ('no'). Captialisation doesn't matter.
	@return boolean choice: The users choice
]]--
function ynchoice()
	while true do
		input = io.read()
		if (input=="y") or (input == "Y") then
			return true
		elseif (input=="n") or (input == "N") then
			return false
		else
			print("Invalid input! Please use 'y' or 'n':")
		end
	end
end

--[[ Prints only if a given boolean is 'false'
	@param String text: Text to print
	@param boolean booleantocheck: Boolean wether not to print
]]--
function bprint(text, booleantocheck)
	if not booleantocheck then
		properprint.pprint(text)
	end
end

--[[ Converts an array to a String; array entrys are split with spaces
	@param Table array: The array to convert
	@param boolean|nil iterator|nil: If true, not the content but the address of the content within the array is converted to a string
	@return String convertedstring: The String biult from the array
]]--
function arraytostring(array,iterator)
	iterator = iterator or false
	result = ""
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

function regexEscape(str)
	return str:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
end

-- COMMAND FUNCTIONS --
-- Update
--[[ Get packageinfo from the internet and search from updates
	@param boolean startup: Run with startup=true on computer startup; if startup=true it doesn't print as much to the console
]]--
function update(startup)
	startup = startup or false
	-- Fetch default Packages
	bprint("Fetching Default Packages...",startup)
	packages = httputils.gethttpdata(defaultpackageurl)["packages"]
	if defaultpackages==false then 
		return
	end
	-- Load custom packages
	bprint("Reading Custom packages...",startup)
	custompackages = fileutils.readData("/.ccpt/custompackages",true)
	-- Add Custom Packages to overall package list
	for k,v in pairs(custompackages) do
		packages[k] = v
	end
	
	-- Fetch package data from the diffrent websites
	packagedata = {}
	for k,v in pairs(packages) do
		bprint("Downloading package data of '" .. k .. "'...",startup)
		packageinfo = httputils.gethttpdata(v)
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
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	installedpackagesnew = {}
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

-- Install
--[[ Install a Package 
]]--
function install()
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt install <PackageID>'")
		return
	end
	packageinfo = getpackagedata(args[2])
	if packageinfo == false then
		return
	end
	if packageinfo["status"] == "installed" then
		properprint.pprint("Package '" .. args[2] .. "' is already installed.")
		return
	end
	-- Ok, all clear, lets get installing!
	result = installpackage(args[2],packageinfo)
	if result==false then
		return
	end
	print("Install of '" .. args[2] .. "' complete!")
end

--[[ Recursive function to install Packages and dependencies
]]--
function installpackage(packageid,packageinfo)
	properprint.pprint("Installing '" .. packageid .. "'...")
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		packageinfo = getpackagedata(packageid)
		if packageinfo==false then
			return false
		end
	end
	
	-- Install dependencies
	properprint.pprint("Installing dependencies of '" .. packageid .. "', if there are any...")
	for k,v in pairs(packageinfo["dependencies"]) do
		installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
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
	installdata = packageinfo["install"]
	result = installtypes[installdata["type"]]["install"](installdata)
	if result==false then
		return false
	end
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	installedpackages[packageid] = packageinfo["newestversion"]
	fileutils.storeData("/.ccpt/installedpackages",installedpackages)
	print("'" .. packageid .. "' successfully installed!")
	installed = installed+1
end

--[[ Different install methodes
]]--
function installlibrary(installdata)
	result = httputils.downloadfile("lib/" .. installdata["filename"],installdata["url"])
	if result==false then
		return false
	end
end

function installscript(installdata)
	result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","install")
	fs.delete("/.ccpt/tempinstaller")
end

-- Upgrade
-- Upgrade installed Packages
-- TODO: Single package updates
function upgrade()
	packageswithupdates = checkforupdates(fileutils.readData("/.ccpt/installedpackages",true),false)
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

--[[ Recursive function to update Packages and dependencies
]]--
function upgradepackage(packageid,packageinfo)
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		packageinfo = getpackagedata(packageid)
		if packageinfo==false then
			return false
		end
	end
	
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	if installedpackages[packageid]==packageinfo["newestversion"] then
		properprint.pprint("'" .. packageid .. "' already updated! Skipping... (This is NOT an error)")
		return true
	else
		properprint.pprint("Updating '" .. packageid .. "' (" .. installedpackages[packageid] .. "->" .. packageinfo["newestversion"] .. ")...")
	end
	
	-- Install/Update dependencies
	properprint.pprint("Updating or installing new dependencies of '" .. packageid .. "', if there are any...")
	for k,v in pairs(packageinfo["dependencies"]) do
		installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
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
	installdata = packageinfo["install"]
	result = installtypes[installdata["type"]]["update"](installdata)
	if result==false then
		return false
	end
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	installedpackages[packageid] = packageinfo["newestversion"]
	fileutils.storeData("/.ccpt/installedpackages",installedpackages)
	print("'" .. packageid .. "' successfully updated!")
	updated = updated+1
end

--[[ Different install methodes require different update methodes
]]--
function updatescript(installdata)
	result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","update")
	fs.delete("/.ccpt/tempinstaller")
end

-- Uninstall
-- Remove installed Packages
function uninstall()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt uninstall <PackageID>'")
		return
	end
	packageinfo = getpackagedata(args[2])
	if packageinfo == false then
		return
	end
	if packageinfo["status"] == "not installed" then
		properprint.pprint("Package '" .. args[2] .. "' is not installed.")
		return
	end
	
	-- Check witch package(s) to remove (A package dependend on a package that's about to get removed is also removed)
	packagestoremove = getpackagestoremove(args[2],packageinfo,fileutils.readData("/.ccpt/installedpackages",true),{})
	packagestoremovestring = ""
	for k,v in pairs(packagestoremove) do
		if not (k==args[2]) then
			packagestoremovestring = packagestoremovestring .. k .. " "
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
	
	-- If cctp would be removed in the process, tell the user that that's a dump idea. But I mean, who am I to stop him, I guess...
	for k,v in pairs(packagestoremove) do
		if k=="ccpt" then
			if args[2] == "ccpt" then
				properprint.pprint("You are about to uninstall the package tool itself. You won't be able to install or uninstall stuff using the tool afterwords (obviously). Are you sure you want to continue? [y/n]:")
			else
				properprint.pprint("You are about to uninstall the package tool itself, because it depends one or more package that is removed. You won't be able to install or uninstall stuff using the tool afterwords (obviously). Are you sure you want to continue? [y/n]:")
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
		installdata = getpackagedata(k)["install"]
		result = installtypes[installdata["type"]]["remove"](installdata)
		if result==false then
			return false
		end
		installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
		installedpackages[k] = nil
		fileutils.storeData("/.ccpt/installedpackages",installedpackages)
		print("'" .. k .. "' successfully uninstalled!")
		removed = removed+1
	end
end

--[[ Recursive function to find all Packages that are dependend on the one we want to remove to also remove them
]]--
function getpackagestoremove(packageid,packageinfo,installedpackages,packagestoremove)
	packagestoremove[packageid] = true
	-- Get Packageinfo
	if (packageinfo==nil) then
		print("Reading packageinfo of '" .. packageid .. "'...")
		packageinfo = getpackagedata(packageid)
		if packageinfo==false then
			return false
		end
	end
	
	-- Check packages that are dependend on that said package
	for k,v in pairs(installedpackages) do
		if not (getpackagedata(k)["dependencies"][packageid]==nil) then
			packagestoremovenew = getpackagestoremove(k,nil,installedpackages,packagestoremove)
			for l,w in pairs(packagestoremovenew) do
				packagestoremove[l] = true
			end
		end
	end
	
	return packagestoremove
end

--[[ Different install methodes require different uninstall methodes
]]--
function removelibrary(installdata)
	fs.delete("lib/" .. installdata["filename"])
end

function removescript(installdata)
	result = httputils.downloadfile("/.ccpt/tempinstaller",installdata["scripturl"])
	if result==false then
		return false
	end
	shell.run("/.ccpt/tempinstaller","remove")
	fs.delete("/.ccpt/tempinstaller")
end

-- Add
--[[ Add custom package URL to local list
]]--
function add()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt add <PackageID> <PackageinfoURL>'")
		return
	end
	if args[3] == nil then
		properprint.pprint("Incomplete command, missing: 'Packageinfo URL'; Syntax: 'ccpt add <PackageID> <PackageinfoURL>'")
		return
	end
	custompackages = fileutils.readData("/.ccpt/custompackages",true)
	if not (custompackages[args[2]]==nil) then
		properprint.pprint("A custom package with the id '" .. args[2] .. "' already exists! Please choose a different one.")
		return
	end
	if not fileutils.file_exists("/.ccpt/packagedata") then
		properprint.pprint("Package Date is not yet built. Please execute 'ccpt update' first. If this message still apears, thats a bug, please report.")
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
	properprint.pprint("Do you want to update the package data ('cctp update')? Your custom package won't be able to be installed until updating. [y/n]:")
	if ynchoice() then
		update()
	end
end

-- Remove
--[[  Remove Package URL from local list
]]--
function remove()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt remove <PackageID>'")
		return
	end
	custompackages = fileutils.readData("/.ccpt/custompackages",true)
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
	properprint.pprint("Do you want to update the package data ('cctp update')? Your custom package will still be able to be installed/updated/uninstalled until updating. [y/n]:")
	if ynchoice() then
		update()
	end
end

-- Info
--[[ Info about a package
]]--
function info()
	-- Check input
	if args[2] == nil then
		properprint.pprint("Incomplete command, missing: 'Package ID'; Syntax: 'ccpt info <PackageID>'")
		return
	end
	-- Get packagedata
	packageinfo = getpackagedata(args[2])
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

-- List
--[[ List all Packages 
]]--
function list()
	-- Read data
	print("Reading all packages data...")
	if not fileutils.file_exists("/.ccpt/packagedata") then
		properprint.pprint("No Packages found. Please run 'cctp update' first.'")
		return
	end
	packagedata = fileutils.readData("/.ccpt/packagedata",true)
	print("Reading Installed packages...")
	installedpackages = fileutils.readData("/.ccpt/installedpackages",true)
	-- Print list
	properprint.pprint("List of all known Packages:")
	for k,v in pairs(installedpackages) do
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

-- Startup
--[[ Run on Startup
]]--
function startup()
	-- Update silently on startup
	update(true)
end

-- Help
--[[ Print help
]]--
function help()
	print("Syntax: ccpt")
	for i,v in pairs(actions) do
		if (not (v["comment"] == nil)) then
			properprint.pprint(i .. ": " .. v["comment"],5)
		end
	end
	print("")
	print("This package tool has Super Creeper Powers.")
end

-- Version
--[[ Print Version
]]--
function version()
	-- Count lines
	linecount = 0
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
--[[ Fuse
]]--
function zzzzzz()
	properprint.pprint("The 'ohnosecond':")
	properprint.pprint("The 'ohnosecond' is the fraction of time between making a mistake and realizing it.")
	properprint.pprint("(Oh, and please fix the hole you've created)")
end

--[[ Explode
]]--
function boom()
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
--[[ Add Text to result array if it fits
	@param String option: Autocomplete option to check
	@param String texttocomplete: The already typed in text to.. complete...
	@param Table result: Array to add the option to if it passes the check
]]--
function addtoresultifitfits(option,texttocomplete,result)
	if startsWith(option,texttocomplete) then
		result[#result+1] = string.sub(option,#texttocomplete+1)
	end
	return result
end

-- Functions to complete different subcommands of a command
-- Complete action (eg. "update" or "list")
function completeaction(curText)
	result = {}
	for i,v in pairs(actions) do
		if (not (v["comment"] == nil)) then
			result = addtoresultifitfits(i,curText,result)
		end
	end
	return result
end

-- Complete packageid (filter can be nil to display all, "installed" to only recommend installed packages or "not installed" to only recommend not installed packages)
autocompletepackagecache = {}
function completepackageid(curText,filterstate)
	result = {}
	if curText=="" or curText==nil then
		packagedata = fileutils.readData("/.ccpt/packagedata",false)
		if not packagedata then
			return {}
		end
		autocompletepackagecache = packagedata
	end
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

-- Complete packageid, but only for custom packages, which is much simpler
function completecustompackageid(curText)
	result = {}
	custompackages = fileutils.readData("/.ccpt/custompackages",true)
	for i,v in pairs(custompackages) do
		result = addtoresultifitfits(i,curText,result)
	end
	return result
end

--[[ Recursive function to go through the 'autocomplete' array and complete commands accordingly
	@param Table lookup: Part of the 'autocomplete' array to look autocomplete up in
	@param String lastText: Numeric array of parameters before the current one
	@param String curText: The already typed in text to.. complete...
	@param int iterator: Last position in the lookup array
	@return Table completeoptions: Availible complete options
]]--
function tabcompletehelper(lookup,lastText,curText,iterator)
	if lookup[lastText[iterator]]==nil then
		return {}
	end
	if #lastText==iterator then
		return lookup[lastText[iterator]]["func"](curText,unpack(lookup[lastText[iterator]]["funcargs"]))
	elseif lookup[lastText[iterator]]["next"]==nil then
		return {}
	else
		return tabcompletehelper(lookup[lastText[iterator]]["next"],lastText,curText,iterator+1)
	end
end

-- CONFIG ARRAYS --
--[[ Array to store subcommands, help comment and function
]]--
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

--[[ Array to store different installation methodes and corresponding functions
]]--
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
		desc = "Programm installed via Installer"
	}
}

--[[ Array to store autocomplete information
]]--
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
function tabcomplete(shell, parNumber, curText, lastText)
	result = {}
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

-- Add to startup file to run at startup
startup = fileutils.readFile("startup","") or ""
if string.find(startup,"shell.run(\".ccpt/program/ccpt\",\"startup\")",1,true)==nil then
	startup = "-- ccpt: Seach for updates\nshell.run(\".ccpt/program/ccpt\",\"startup\")\n\n" .. startup
	fileutils.storeFile("startup",startup)
	print("[Installer] Startup entry created!")
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