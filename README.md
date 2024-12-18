# Windows Hardening Script

This is a script with the combined knowledge of a multitude of resources

Make an issue or PR with any updates I should make

# How to Run
Run ``Enable Scripts.bat`` as admin and then run ``main.ps1`` **as a regular user**
* After the first run, running the script as TrustedInstaller directly is fine

**IF RUNNING FAILS, YOU CAN RUN THE SCRIPT MANUALLY WITH YOUR USERNAME AS AN ARGUMENT IN A TRUSTED INSTALLER POWERSHELL WINDOW**

``.\main.ps1 'username here'``

# UserData Format
**THESE MUST BE ON SEPARATE LINES**

**ANY USERS NOT INCLUDED WILL BE DELETED**

``USERNAME|GROUPS`` (Assigning users to group(s)) (users and groups will be added automatically)

EX: User ``Bob`` needs to be in the Administrators and Replicator groups

``Bob|Administrators, Replicator``

If a group has a space, it'll still be the same format

# Services

If a particular service is being fucky, you can find a reg key export below

Windows 10, Server 2019, and Server 2022: https://www.tenforums.com/tutorials/57567-restore-default-services-windows-10-a.html

Windows 11: https://www.elevenforum.com/t/restore-default-services-in-windows-11.3109/

I personally recommend do this as a last resort if a service is being fucky if baselining does not work

Remember, these don't import registry sddls so you'd have to set those manually (or let the baseline do it)
