This file is unfinished!
# Contributing Guidelines
## Repository structure
### About branches
This repository has no releases because of how the way CCPT updates itself. It always downloads its newest version from the main branch. There must be no commits changing CCPT's code directly to the main branch. The part of "packageinfo.ccpt" that is relevant to the installment process ("newestversion", "dependencies" and the "install"-section) must also not be directly commited to the main branch. Commiting to other files like the installer (after extensive testing! You are still affecting files that are needed in the ongoing operation!) is allowed.  
The next version of "CCPT" has its own branch where developement changes (eg. implementing a new feature or fixing a bug) have to be commited to. Once everything is tested and enough new features and bugfixes are impemented, a new version is released (don't forget to change the readme, social preview, packageinfo, documentation, and, if necessary, installer!) and the "version branch" is merged with the main branch.
### About the folder and file structure
```
ccpt  
| - .gitattributes: .gitattributes file for this repo  
| - .gitignore: .gitignore file for this repo  
| - CONTRIBUTING.md: This file :)  
| - LICENSE: License file under which ccpt is published   
| - README.md: Readme file for this repo  
| - ccpt: Main code file for CCPT (lua)  
| - ccptinstall.lua: Installer for CCPT (also hosted on pastebin) (lua)  
| - defaultpackages.ccpt: List of default packages able to be installed  
| - packageinfo.ccpt: packageinfo file for ccpt  
|  
| - .github: Github-related files  
|   \ - ISSUE_TEMPLATES: Templates to create issues  
|       | - apply-for-default-package-list.md: Template for applying for DPL  
|       | - bug_report.md: Template for applying for reporting a bug  
|       \ - feature_request.md: Template for requesting a feature  
|  
| - img: Images for Github presence  
|   | - (images used in readme)  
|   | - social-preview.gif: Social preview picture (Updating this does not automaticly change the social preview picture!)  
|   \ - work: Folder to store image presets like backgrounds and unexported gimp files  
|       \ - (raw image files and gimp files to reuse in new images)  
|  
\ - testing: Test data to test CCPT's features  
    \ - (different packageinfo files and other files only used for testing CCPT's features without habing to use real packages)
```

## Code structure
- Every codefile must have the following comment ad the first few lines:
```lua
---<Title/file function>
---@author <Original author>
---@version <Corresponding ccpt version or file version if the file is not directly related to a ccpt version (eg. installer)>
```
- All functions must be members of a group, containing one or more functions. These functions must be below each other. Every Group has a comment with tha gruop name/function at the beginning:
```lua
-- <Description/name> --
```
- Every function definition must begin with the following comment:
```lua
---<Description of what the function does>
---@param <parameter type> <name>: <description what it is for/what it does>
---(1 line per parameter)
---...
---@return <variable type> <name>: <description of what is returned>
---(1 line per returned variable)
---...
```
- All functions that don't just do one thing (eg. reading a file or writing something in console) but follow different steps, one after the other (like first fetch a file, then store it somewhere) to achive a result, must have these different steps commented.
## Dealing with issues
The first thing to do when dealing with an issue is always to write a comment that you are dealing with the issue so that no issue is dealt with by two people at the same time!
## Process applies for default package list
