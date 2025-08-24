ECHO OFF
CLS
:MENU
ECHO.
ECHO ...............................................
ECHO PRESS 1, 2, 3, 4, 5, 6 to select your task, or 7 to EXIT.
ECHO ...............................................
ECHO.
ECHO 1 - Open Apps
ECHO 2 - Open Networks
ECHO 3 - Open Printers
ECHO 4 - Open Device Managements
ECHO 5 - Open System Admin
ECHO 6 - Open User
ECHO 7 - EXIT
ECHO.
SET /P M=Type 1, 2, 3, 4, 5, 6 or 7 then press ENTER:
IF %M%==1 GOTO APPS
IF %M%==2 GOTO NETWORKS
IF %M%==3 GOTO PRINTERS
IF %M%==4 GOTO DEVICE_MANAGEMENT
IF %M%==5 GOTO SYSTEM_ADMIN
IF %M%==6 GOTO USER
IF %M%==7 GOTO EOF
:APPS
start appwiz.cpl
GOTO MENU
:NETWORKS
start control netconnections
GOTO MENU
:PRINTERS
start control printers
GOTO MENU
:DEVICE_MANAGEMENT
start devmgmt
GOTO MENU
:SYSTEM_ADMIN
start sysdm.cpl
GOTO MENU
:USER
start control userpasswords2
GOTO MENU