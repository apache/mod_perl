# Microsoft Developer Studio Generated NMAKE File, Based on ApacheModulePerl.dsp
!IF "$(CFG)" == ""
CFG=ApacheModulePerl - Win32 Debug
!MESSAGE No configuration specified. Defaulting to ApacheModulePerl - Win32\
 Debug.
!ENDIF 

!IF "$(CFG)" != "ApacheModulePerl - Win32 Release" && "$(CFG)" !=\
 "ApacheModulePerl - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "ApacheModulePerl.mak" CFG="ApacheModulePerl - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "ApacheModulePerl - Win32 Release" (based on\
 "Win32 (x86) Dynamic-Link Library")
!MESSAGE "ApacheModulePerl - Win32 Debug" (based on\
 "Win32 (x86) Dynamic-Link Library")
!MESSAGE 
!ERROR An invalid configuration is specified.
!ENDIF 

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE 
NULL=nul
!ENDIF 

CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

OUTDIR=.\Release
INTDIR=.\Release
# Begin Custom Macros
OutDir=.\Release
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\ApacheModulePerl.dll"

!ELSE 

ALL : "$(OUTDIR)\ApacheModulePerl.dll"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\Apache.obj"
	-@erase "$(INTDIR)\Constants.obj"
	-@erase "$(INTDIR)\mod_perl.obj"
	-@erase "$(INTDIR)\perl_config.obj"
	-@erase "$(INTDIR)\perl_util.obj"
	-@erase "$(INTDIR)\perlio.obj"
	-@erase "$(INTDIR)\perlxsi.obj"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(OUTDIR)\ApacheModulePerl.dll"
	-@erase "$(OUTDIR)\ApacheModulePerl.exp"
	-@erase "$(OUTDIR)\ApacheModulePerl.lib"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MD /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS"\
 /Fp"$(INTDIR)\ApacheModulePerl.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD\
 /c 
CPP_OBJS=.\Release/
CPP_SBRS=.
MTL_PROJ=/nologo /D "NDEBUG" /mktyplib203 /o NUL /win32 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\ApacheModulePerl.bsc" 
BSC32_SBRS= \
	
LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib\
 advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib\
 odbccp32.lib /nologo /subsystem:windows /dll /incremental:no\
 /pdb:"$(OUTDIR)\ApacheModulePerl.pdb" /machine:I386\
 /out:"$(OUTDIR)\ApacheModulePerl.dll" /implib:"$(OUTDIR)\ApacheModulePerl.lib" 
LINK32_OBJS= \
	"$(INTDIR)\Apache.obj" \
	"$(INTDIR)\Constants.obj" \
	"$(INTDIR)\mod_perl.obj" \
	"$(INTDIR)\perl_config.obj" \
	"$(INTDIR)\perl_util.obj" \
	"$(INTDIR)\perlio.obj" \
	"$(INTDIR)\perlxsi.obj" \
	"..\..\..\..\..\Apache\ApacheCore.lib" \
	"..\..\..\..\..\perl\lib\CORE\perl.lib"

"$(OUTDIR)\ApacheModulePerl.dll" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

OUTDIR=.\Debug
INTDIR=.\Debug
# Begin Custom Macros
OutDir=.\Debug
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\ApacheModulePerl.dll" "$(OUTDIR)\ApacheModulePerl.bsc"

!ELSE 

ALL : "$(OUTDIR)\ApacheModulePerl.dll" "$(OUTDIR)\ApacheModulePerl.bsc"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\Apache.obj"
	-@erase "$(INTDIR)\Apache.sbr"
	-@erase "$(INTDIR)\Constants.obj"
	-@erase "$(INTDIR)\Constants.sbr"
	-@erase "$(INTDIR)\mod_perl.obj"
	-@erase "$(INTDIR)\mod_perl.sbr"
	-@erase "$(INTDIR)\perl_config.obj"
	-@erase "$(INTDIR)\perl_config.sbr"
	-@erase "$(INTDIR)\perl_util.obj"
	-@erase "$(INTDIR)\perl_util.sbr"
	-@erase "$(INTDIR)\perlio.obj"
	-@erase "$(INTDIR)\perlio.sbr"
	-@erase "$(INTDIR)\perlxsi.obj"
	-@erase "$(INTDIR)\perlxsi.sbr"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\vc50.pdb"
	-@erase "$(OUTDIR)\ApacheModulePerl.bsc"
	-@erase "$(OUTDIR)\ApacheModulePerl.dll"
	-@erase "$(OUTDIR)\ApacheModulePerl.exp"
	-@erase "$(OUTDIR)\ApacheModulePerl.ilk"
	-@erase "$(OUTDIR)\ApacheModulePerl.lib"
	-@erase "$(OUTDIR)\ApacheModulePerl.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MTd /W3 /Gm /GX /Zi /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS"\
 /FR"$(INTDIR)\\" /Fp"$(INTDIR)\ApacheModulePerl.pch" /YX /Fo"$(INTDIR)\\"\
 /Fd"$(INTDIR)\\" /FD /c 
CPP_OBJS=.\Debug/
CPP_SBRS=.\Debug/
MTL_PROJ=/nologo /D "_DEBUG" /mktyplib203 /o NUL /win32 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\ApacheModulePerl.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\Apache.sbr" \
	"$(INTDIR)\Constants.sbr" \
	"$(INTDIR)\mod_perl.sbr" \
	"$(INTDIR)\perl_config.sbr" \
	"$(INTDIR)\perl_util.sbr" \
	"$(INTDIR)\perlio.sbr" \
	"$(INTDIR)\perlxsi.sbr"

"$(OUTDIR)\ApacheModulePerl.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib\
 advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib\
 odbccp32.lib /nologo /subsystem:windows /dll /incremental:yes\
 /pdb:"$(OUTDIR)\ApacheModulePerl.pdb" /debug /machine:I386\
 /out:"$(OUTDIR)\ApacheModulePerl.dll" /implib:"$(OUTDIR)\ApacheModulePerl.lib"\
 /pdbtype:sept 
LINK32_OBJS= \
	"$(INTDIR)\Apache.obj" \
	"$(INTDIR)\Constants.obj" \
	"$(INTDIR)\mod_perl.obj" \
	"$(INTDIR)\perl_config.obj" \
	"$(INTDIR)\perl_util.obj" \
	"$(INTDIR)\perlio.obj" \
	"$(INTDIR)\perlxsi.obj" \
	"..\..\..\..\..\Apache\ApacheCore.lib" \
	"..\..\..\..\..\perl\lib\CORE\perl.lib"

"$(OUTDIR)\ApacheModulePerl.dll" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ENDIF 

.c{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<


!IF "$(CFG)" == "ApacheModulePerl - Win32 Release" || "$(CFG)" ==\
 "ApacheModulePerl - Win32 Debug"
SOURCE=..\perl\Apache.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_APACH=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\Apache.obj" : $(SOURCE) $(DEP_CPP_APACH) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

DEP_CPP_APACH=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\Apache.obj"	"$(INTDIR)\Apache.sbr" : $(SOURCE) $(DEP_CPP_APACH)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\Constants.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_CONST=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	

"$(INTDIR)\Constants.obj" : $(SOURCE) $(DEP_CPP_CONST) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

DEP_CPP_CONST=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	

"$(INTDIR)\Constants.obj"	"$(INTDIR)\Constants.sbr" : $(SOURCE)\
 $(DEP_CPP_CONST) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\mod_perl.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_MOD_P=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\mod_perl.obj" : $(SOURCE) $(DEP_CPP_MOD_P) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

DEP_CPP_MOD_P=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\mod_perl.obj"	"$(INTDIR)\mod_perl.sbr" : $(SOURCE) $(DEP_CPP_MOD_P)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\perl_config.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_PERL_=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\perl_config.obj" : $(SOURCE) $(DEP_CPP_PERL_) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

DEP_CPP_PERL_=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\perl_config.obj"	"$(INTDIR)\perl_config.sbr" : $(SOURCE)\
 $(DEP_CPP_PERL_) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\perl_util.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_PERL_U=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\perl_util.obj" : $(SOURCE) $(DEP_CPP_PERL_U) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"

DEP_CPP_PERL_U=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\perl_util.obj"	"$(INTDIR)\perl_util.sbr" : $(SOURCE)\
 $(DEP_CPP_PERL_U) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\perlio.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_PERLI=\
	"..\..\..\..\..\apache\src\main\alloc.h"\
	"..\..\..\..\..\apache\src\main\buff.h"\
	"..\..\..\..\..\apache\src\main\conf.h"\
	"..\..\..\..\..\apache\src\main\http_conf_globals.h"\
	"..\..\..\..\..\apache\src\main\http_config.h"\
	"..\..\..\..\..\apache\src\main\http_core.h"\
	"..\..\..\..\..\apache\src\main\http_log.h"\
	"..\..\..\..\..\apache\src\main\http_main.h"\
	"..\..\..\..\..\apache\src\main\http_protocol.h"\
	"..\..\..\..\..\apache\src\main\http_request.h"\
	"..\..\..\..\..\apache\src\main\httpd.h"\
	"..\..\..\..\..\apache\src\main\multithread.h"\
	"..\..\..\..\..\apache\src\main\util_script.h"\
	"..\..\..\..\..\apache\src\os\win32\os.h"\
	"..\..\..\..\..\apache\src\os\win32\readdir.h"\
	"..\..\..\..\..\apache\src\regex\regex.h"\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\..\..\..\..\perl\lib\core\xsub.h"\
	"..\perl\dirent.h"\
	"..\perl\mod_perl.h"\
	

"$(INTDIR)\perlio.obj" : $(SOURCE) $(DEP_CPP_PERLI) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"


"$(INTDIR)\perlio.obj"	"$(INTDIR)\perlio.sbr" : $(SOURCE) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 

SOURCE=..\perl\perlxsi.c

!IF  "$(CFG)" == "ApacheModulePerl - Win32 Release"

DEP_CPP_PERLX=\
	"..\..\..\..\..\perl\lib\core\av.h"\
	"..\..\..\..\..\perl\lib\core\config.h"\
	"..\..\..\..\..\perl\lib\core\cop.h"\
	"..\..\..\..\..\perl\lib\core\cv.h"\
	"..\..\..\..\..\perl\lib\core\dosish.h"\
	"..\..\..\..\..\perl\lib\core\embed.h"\
	"..\..\..\..\..\perl\lib\core\extern.h"\
	"..\..\..\..\..\perl\lib\core\form.h"\
	"..\..\..\..\..\perl\lib\core\gv.h"\
	"..\..\..\..\..\perl\lib\core\handy.h"\
	"..\..\..\..\..\perl\lib\core\hv.h"\
	"..\..\..\..\..\perl\lib\core\mg.h"\
	"..\..\..\..\..\perl\lib\core\netdb.h"\
	"..\..\..\..\..\perl\lib\core\op.h"\
	"..\..\..\..\..\perl\lib\core\opcode.h"\
	"..\..\..\..\..\perl\lib\core\perl.h"\
	"..\..\..\..\..\perl\lib\core\perlio.h"\
	"..\..\..\..\..\perl\lib\core\perlsdio.h"\
	"..\..\..\..\..\perl\lib\core\perly.h"\
	"..\..\..\..\..\perl\lib\core\pp.h"\
	"..\..\..\..\..\perl\lib\core\proto.h"\
	"..\..\..\..\..\perl\lib\core\regexp.h"\
	"..\..\..\..\..\perl\lib\core\scope.h"\
	"..\..\..\..\..\perl\lib\core\sv.h"\
	"..\..\..\..\..\perl\lib\core\sys\socket.h"\
	"..\..\..\..\..\perl\lib\core\util.h"\
	"..\..\..\..\..\perl\lib\core\win32.h"\
	"..\..\..\..\..\perl\lib\core\win32io.h"\
	"..\..\..\..\..\perl\lib\core\win32iop.h"\
	"..\perl\dirent.h"\
	

"$(INTDIR)\perlxsi.obj" : $(SOURCE) $(DEP_CPP_PERLX) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ELSEIF  "$(CFG)" == "ApacheModulePerl - Win32 Debug"


"$(INTDIR)\perlxsi.obj"	"$(INTDIR)\perlxsi.sbr" : $(SOURCE) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


!ENDIF 


!ENDIF 

