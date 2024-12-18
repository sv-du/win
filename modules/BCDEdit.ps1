bcdedit /bootdebug off
bcdedit /debug off
bcdedit /ems off
bcdedit /event on

bcdedit /deletevalue removememory
bcdedit /deletevalue truncatememory

bcdedit /set bootlog yes
bcdedit /set bootmenupolicy Standard
bcdedit /set bootstatuspolicy DisplayAllFailures
bcdedit /set quietboot off
bcdedit /set sos on
bcdedit /set lastknowngood on
bcdedit /set nocrashautoreboot on
bcdedit /set safebootalternateshell off
bcdedit /set winpe off
bcdedit /set onetimeadvancedoptions off
bcdedit /set halbreakpoint no
bcdedit /set useplatformclock no
bcdedit /set forcelegacyplatform no
bcdedit /set tscsyncpolicy Default
bcdedit /set testsigning off
bcdedit /set nointegritychecks off
bcdedit /set disableelamdrivers no
bcdedit /set nx AlwaysOn
bcdedit /set usefirmwarepcisettings on
bcdedit /set vga off
bcdedit /set novga on
bcdedit /set tpmbootentropy ForceEnable
bcdedit /set maxproc yes
bcdedit /set uselegacyapicmode no
bcdedit /set x2apicpolicy default
bcdedit /set disabledynamictick yes
bcdedit /set useplatformtick no
bcdedit /set hypervisordebug Off
bcdedit /set driverloadfailurepolicy UseErrorControl
bcdedit /set ems off