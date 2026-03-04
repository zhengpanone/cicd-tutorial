@echo off
setlocal

REM ===== check param =====
if "%1"=="" (
    echo Usage: build.bat dev^|test^|prod
    exit /b 1
)

set ENV=%1

REM ===== variables =====
set BASE_JAR=app.jar
set OUT_DIR=dist\%ENV%
set TARGET_JAR=%OUT_DIR%\app.jar
set CONFIG_DIR=config\%ENV%
set TMP_DIR=__tmp_jar_update__

REM ===== check files =====
if not exist "%BASE_JAR%" (
    echo ERROR: app.jar not found
    exit /b 1
)

if not exist "%CONFIG_DIR%\application.properties" (
    echo ERROR: application.properties not found
    exit /b 1
)

REM ===== prepare output dir =====
if exist "%OUT_DIR%" rd /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

REM ===== temp dir =====
if exist "%TMP_DIR%" rd /s /q "%TMP_DIR%"
mkdir "%TMP_DIR%\BOOT-INF\classes"

copy "%CONFIG_DIR%\application.properties" "%TMP_DIR%\BOOT-INF\classes\application.properties" >nul

REM ===== copy jar =====
copy "%BASE_JAR%" "%TARGET_JAR%" >nul

REM ===== update jar =====
pushd "%TMP_DIR%"
jar uf "..\%TARGET_JAR%" BOOT-INF\classes\application.properties
popd

REM ===== verify =====
echo ---- verify ----
jar tf "%TARGET_JAR%" | findstr "BOOT-INF/classes/application.properties"

REM ===== cleanup =====
rd /s /q "%TMP_DIR%"

echo.
echo DONE: %TARGET_JAR%
endlocal
