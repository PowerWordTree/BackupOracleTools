::Oracle备份脚本
::@author FB
::@version 1.09

@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "RETURN=0"

::读取配置文件
FOR %%I IN ("BACKUP_PATH","REMOTE_PATH","BACKUP_DB") DO SET "%%I="
FOR /F "eol=# tokens=1,* delims== usebackq" %%I IN ("%~dpn0.cfg") DO (
  CALL :TRIM "%%I" "VARNAME"
  CALL :TRIM "%%J" "VARDATA"
  SET "!VARNAME!=!VARDATA!"
)

::检查备份路径
IF NOT EXIST "%BACKUP_PATH%" (
  MKDIR "%BACKUP_PATH%"
  IF NOT EXIST "%BACKUP_PATH%" (
    ECHO.
    ECHO 备份路径不存在或设置错误!
    SET "RETURN=1"
    GOTO :END
  )
)

::检查参数
IF /I "_%~1" == "_DATABASE"   (SET "BACKUP_OP=DATABASE" & GOTO :START)
IF /I "_%~1" == "_ARCHIVELOG" (SET "BACKUP_OP=ARCHIVELOG" & GOTO :START)
::参数错误
ECHO.
ECHO ================================================
ECHO                 ORACLE 备份脚本
ECHO ================================================
ECHO.
ECHO CMD: %~0 ^<操作^>
ECHO.
ECHO DATABASE                备份全库
ECHO ARCHIVELOG              备份归档日志
ECHO.
SET "RETURN=1"
GOTO :END


::开始执行
:START
::生成目标目录路径字符串
CALL :FORMAT_DATE "%DATE%" BACKUP_DATE
SET "DEST_PATH=%BACKUP_PATH%\%BACKUP_OP%_%BACKUP_DATE%"
::判断是否已经在执行或执行过
IF EXIST "%DEST_PATH%" (
  ECHO.
  ECHO 今天已经执行过!
  SET "RETURN=1"
  GOTO :END
)
::创建目标目录
MKDIR "%DEST_PATH%"
::写入日志
CALL :ECHO_DATETIME "========== 开始备份 " " ==========" >"%DEST_PATH%\RUN.LOG"
::生成备份脚本
CALL :ECHO_HEAD >"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_SHOW >>"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_BACKUP_%BACKUP_OP% "%DEST_PATH%" "%COMPRESS%">>"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_FOOT >>"%DEST_PATH%\BACKUP.RMAN"
::执行备份
RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\BACKUP.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
::判断备份是否成功
IF "_%ERRORLEVEL%" == "_0" (
  ::写入日志
  CALL :ECHO_DATETIME "========== 结束备份 " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
  ::写入日志
  CALL :ECHO_DATETIME "========== 验证备份 " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ::查询BS_KEY
  CALL :ECHO_QUERY "%DEST_PATH%" >"%DEST_PATH%\BS_KEY.SQL"
  IF "_%BACKUP_DB:~0,1%" == "_/" (
    SQLPLUS -L -S "%BACKUP_DB%" AS SYSDBA @%DEST_PATH%\BS_KEY.SQL >"%DEST_PATH%\BS_KEY.TXT"
  ) ELSE (
    SQLPLUS -L -S "%BACKUP_DB%" @%DEST_PATH%\BS_KEY.SQL >"%DEST_PATH%\BS_KEY.TXT"
  )
  ::提取BS_KEY
  CALL :GET_NUMBERS "%DEST_PATH%\BS_KEY.TXT" "BS_KEY"
  ::生成校验脚本
  CALL :ECHO_HEAD >"%DEST_PATH%\VALIDATE.RMAN"
  FOR %%I IN (!BS_KEY!) DO (
    CALL :ECHO_VALIDATE "%%~I" >>"%DEST_PATH%\VALIDATE.RMAN"
  )
  CALL :ECHO_FOOT >>"%DEST_PATH%\VALIDATE.RMAN"
  ::验证备份
  RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\VALIDATE.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
  IF NOT "_!ERRORLEVEL!" == "_0" SET "RETURN=1"
  ::写入日志
  CALL :ECHO_DATETIME "========== 验证结束 " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
) ELSE (
  SET "RETURN=1"
)
::判断备份成功
IF "_%RETURN%" == "_1" (
  ::标记错误
  MOVE /Y "%DEST_PATH%" "%DEST_PATH%_ERROR" 1>NUL 2>NUL
) ELSE (
  ::生成清理脚本
  CALL :ECHO_HEAD >"%DEST_PATH%\DELETE.RMAN"
  CALL :ECHO_DELETE >>"%DEST_PATH%\DELETE.RMAN"
  CALL :ECHO_FOOT >>"%DEST_PATH%\DELETE.RMAN"
  ::写入日志
  CALL :ECHO_DATETIME "========== 清理过期备份 " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ::清理过期备份
  RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\DELETE.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
  ::检查是否全库备份
  SET "BACKUP_FULL=FALSE"
  FOR %%I IN (DATABASE,LEVEL0) DO IF /I "_%BACKUP_OP%" == "_%%~I" SET "BACKUP_FULL=TRUE"
  ::清理过期目录
  FOR /D %%I IN ("%BACKUP_PATH%\*") DO (
    ::判断是否错误目录
    SET "BACKUP_EMPTY=%%~I"
    IF /I "_!BACKUP_EMPTY:~-5!" == "_ERROR" (
      ::错误目录在全库备份时删除
      IF /I "_!BACKUP_FULL!" == "_TRUE" RMDIR /S /Q "%%~I" 1>NUL 2>NUL
    ) ELSE (
      ::清理已经过期备份的残余目录
      IF NOT EXIST "%%~I\BACKUP-*" RMDIR /S /Q "%%~I" 1>NUL 2>NUL
    )
  )
  SET "BACKUP_EMPTY="
  SET "BACKUP_FULL="
  ::写入日志
  CALL :ECHO_DATETIME "========== 清理过期完成 " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
)
::同步到远程存储
IF EXIST "%REMOTE_PATH%" (
  CALL :SLEEP 30
  ROBOCOPY "%BACKUP_PATH%" "%REMOTE_PATH%" /MIR /R:10
) 
GOTO :END


::生成当前时间
::  参数1: 前缀文字
::  参数2: 后缀文字
:ECHO_DATETIME
@ECHO %~1 %DATE% %TIME% %~2
GOTO :EOF

::提取文本数字
::  参数1: 文本文件
::  参数2: 返回参数(忽略则输出到屏幕)
:GET_NUMBERS
SET "GET_NUMBERS="
FOR /F "tokens=1,* usebackq" %%I IN ("%~1") DO (
  IF "_%%~J" == "_" (
    SET /A "IS_NUMBER=%%~I + 0" 1>NUL 2>NUL
    IF "_!IS_NUMBER!" == "_%%~I" (
      SET "GET_NUMBERS=!GET_NUMBERS! %%~I"
    )
  )
)
IF "_%~2" == "_" (
  ECHO %GET_NUMBERS:~1%
) ELSE (
  SET "%~2=%GET_NUMBERS:~1%"
)
SET "GET_NUMBERS="
GOTO :EOF

::统一日期格式字符串
::  参数1: 输入日期格式(yyyy MM dd)
::  参数2: 输出到变量(否则输出到屏幕)
:FORMAT_DATE
SET "CU_DATE=%~1"
IF "_%CU_DATE%" == "_" SET "CU_DATE=%DATE%"
FOR /F "tokens=1,2,3,* delims=/.-\ " %%A IN ("%CU_DATE%") DO (
  IF "_%~2" == "_" (
    ECHO %%A-%%B-%%C
  ) ELSE (
    SET "%~2=%%A-%%B-%%C"
  )
)
SET "CU_DATE="
GOTO :EOF

::利用CHOICE进行延迟
:SLEEP
CHOICE /C "0" /N /D "0" /T %~1 1>NUL 2>NUL
GOTO :EOF

::生成查询BS_KEY
::  参数1: 文件关键字
:ECHO_QUERY
@ECHO select distinct T2.BS_KEY from V$BACKUP_PIECE T1
@ECHO   inner join V$BACKUP_SET_DETAILS T2
@ECHO   on T1.SET_STAMP = T2.SET_STAMP
@ECHO   where lower(HANDLE) like lower('%%%~1%%') 
@ECHO   order by 1;
@ECHO EXIT;
@GOTO :EOF

::生成校验备份
::  参数1: BS_KEY
:ECHO_VALIDATE
@ECHO   #校验备份SET %~1
@ECHO   validate backupset %~1;
@ECHO.
@GOTO :EOF

::生成删除过期无效备份
:ECHO_DELETE
@ECHO   #删除过期无效备份
@ECHO   report obsolete;
@ECHO   delete noprompt obsolete;
@ECHO   crosscheck archivelog all;
@ECHO   delete noprompt expired archivelog all;
@ECHO   crosscheck backup;
@ECHO   delete noprompt expired backup;
@ECHO.
@GOTO :EOF

::生成脚本头
:ECHO_HEAD
@ECHO run {
@ECHO.
@GOTO :EOF

::生成脚本脚
:ECHO_FOOT
@ECHO }
@GOTO :EOF

::显示全部参数
:ECHO_SHOW
@ECHO   #显示RMAN设置
@ECHO   show all;
@ECHO.
@GOTO :EOF


::备份全库
::  参数1: 备份路径
::  参数2: 是否压缩
:ECHO_BACKUP_DATABASE
@ECHO   #备份全库
IF /I "_%~2" == "_TRUE" (
  @ECHO   backup as compressed backupset
) ELSE (
  @ECHO   backup
)
@ECHO     database tag='DATABASE'
@ECHO     format '%~1\BACKUP-%%U';
@ECHO.
@GOTO :EOF

::备份归档日志
::  参数1: 备份路径
::  参数2: 是否压缩
:ECHO_BACKUP_ARCHIVELOG
@ECHO   #备份归档日志
IF /I "_%~2" == "_TRUE" (
  @ECHO   backup as compressed backupset
) ELSE (
  @ECHO   backup
)
@ECHO     archivelog all tag='ARCHIVELOG'
@ECHO     format '%~1\BACKUP-%%U'
@ECHO     delete input;
@ECHO.
@GOTO :EOF

::去空格
::  参数1: 目标字符串
::  参数2: 输出到变量名(可选,直接输出到屏幕)
:TRIM
CALL :TRIM_TO_VAR %~1
IF "_%~2" == "_" (
  ECHO %TRIMED_STRING%
) ELSE (
  SET "%~2=%TRIMED_STRING%"
)
SET "TRIMED_STRING="
GOTO :EOF

::去空格到固定变量TRIMED_STRING
::  参数: 目标字符串
:TRIM_TO_VAR
SET "TRIMED_STRING=%*"
GOTO :EOF

:END
EXIT /B %RETURN%
