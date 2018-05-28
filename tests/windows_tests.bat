@echo OFF

cd "%~dp0%.."
set ROOT=%cd%

echo ROOT: "%ROOT%"
if not exist "%ROOT%" exit 1

set PROJECT_NAME=pluginval
set DEPLOYMENT_DIR=%ROOT%/bin/windows
set PLUGINVAL_EXE=%DEPLOYMENT_DIR%\%PROJECT_NAME%.exe

::============================================================
::   First build pluginval
::============================================================
call "%ROOT%/install/windows_build.bat" || exit 1

::============================================================
::   Build Projucer and generate test plugin projects
::============================================================
echo "Building Projucer and creating projects"

set PROJUCER_ROOT=%ROOT%/modules/juce/extras/Projucer/Builds/VisualStudio2017
set PROJUCER_EXE=%PROJUCER_ROOT%/x64/Release/App/Projucer.exe
set PLUGINS_PIP_DIR=%ROOT%/modules/juce/examples/Plugins
set TEMP_DIR=%ROOT%/tmp
rd /S /Q "%TEMP_DIR%"

cd "%PROJUCER_ROOT%"
"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe" Projucer.sln /p:VisualStudioVersion=15.0 /m /p:Configuration=Release /p:Platform=x64 /p:PreferredToolArchitecture=x64
if not exist "%PROJUCER_EXE%" exit 1


::============================================================
::   Test plugins
::============================================================
call "%PROJUCER_EXE%" --set-global-search-path windows defaultJuceModulePath "%ROOT%/modules/juce/modules"
call "%PROJUCER_EXE%" --set-global-search-path windows vst3Path "%ROOT%/vst3"
call :TestPlugin "ArpeggiatorPlugin", "ArpeggiatorPluginDemo.h"
call :TestPlugin "AudioPluginDemo", "AudioPluginDemo.h"
call :TestPlugin "DSPModulePluginDemo", "DSPModulePluginDemo.h"
call :TestPlugin "GainPlugin", "GainPluginDemo.h"
call :TestPlugin "MultiOutSynthPlugin", "MultiOutSynthPluginDemo.h"
call :TestPlugin "NoiseGatePlugin", "NoiseGatePluginDemo.h"
call :TestPlugin "SamplerPlugin", "SamplerPluginDemo.h"
call :TestPlugin "SurroundPlugin", "SurroundPluginDemo.h"
exit /B %ERRORLEVEL%

:TestPlugin
	echo "=========================================================="
	echo "Testing: %~1%"
	set PLUGIN_NAME=%~1%
	set PLUGIN_PIP_FILE=%~2%
	set PLUGIN_VST="%TEMP_DIR%/%PLUGIN_NAME%/Builds/VisualStudio2017/x64/Release/VST/%PLUGIN_NAME%.dll"
    call "%PROJUCER_EXE%" --create-project-from-pip "%PLUGINS_PIP_DIR%\%PLUGIN_PIP_FILE%" "%TEMP_DIR%"
    call "%PROJUCER_EXE%" --resave "%TEMP_DIR%/%PLUGIN_NAME%/%PLUGIN_NAME%.jucer"
	cd "%TEMP_DIR%/%PLUGIN_NAME%/Builds/VisualStudio2017"
	"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe" %PLUGIN_NAME%.sln /p:VisualStudioVersion=15.0 /m /t:Build /p:Configuration=Release /p:Platform=x64 /p:PreferredToolArchitecture=x64  /p:TreatWarningsAsErrors=true

	:: Test out of process
	call "%PLUGINVAL_EXE%" --strictnessLevel 5 --validate %PLUGIN_VST%
	if %ERRORLEVEL% NEQ 0 exit 1

	:: Test in process
	call "%PLUGINVAL_EXE%" --validate-in-process --strictnessLevel 5 --validate %PLUGIN_VST%
	if %ERRORLEVEL% NEQ 0 exit 1
exit /B 0
