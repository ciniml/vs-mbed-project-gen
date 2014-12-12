PUSHD "%~dp0"
if "%1"=="rebuild" goto :rebuild

%MakePath% -j12 %* GCC_BIN=%GccBinDir%\
goto :eof

:rebuild
shift
%MakePath% -j12 clean %* GCC_BIN=%GccBinDir%\
%MakePath% -j12 all %* GCC_BIN=%GccBinDir%\
goto :eof

