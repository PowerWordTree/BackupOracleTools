::Oracle���ݽű�
::@author FB
::@version 1.09

@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "RETURN=0"

::��ȡ�����ļ�
FOR %%I IN ("BACKUP_PATH","REMOTE_PATH","BACKUP_DB") DO SET "%%I="
FOR /F "eol=# tokens=1,* delims== usebackq" %%I IN ("%~dpn0.cfg") DO (
  CALL :TRIM "%%I" "VARNAME"
  CALL :TRIM "%%J" "VARDATA"
  SET "!VARNAME!=!VARDATA!"
)

::��鱸��·��
IF NOT EXIST "%BACKUP_PATH%" (
  MKDIR "%BACKUP_PATH%"
  IF NOT EXIST "%BACKUP_PATH%" (
    ECHO.
    ECHO ����·�������ڻ����ô���!
    SET "RETURN=1"
    GOTO :END
  )
)

::������
IF /I "_%~1" == "_DATABASE"   (SET "BACKUP_OP=DATABASE" & GOTO :START)
IF /I "_%~1" == "_ARCHIVELOG" (SET "BACKUP_OP=ARCHIVELOG" & GOTO :START)
::��������
ECHO.
ECHO ================================================
ECHO                 ORACLE ���ݽű�
ECHO ================================================
ECHO.
ECHO CMD: %~0 ^<����^>
ECHO.
ECHO DATABASE                ����ȫ��
ECHO ARCHIVELOG              ���ݹ鵵��־
ECHO.
SET "RETURN=1"
GOTO :END


::��ʼִ��
:START
::����Ŀ��Ŀ¼·���ַ���
CALL :FORMAT_DATE "%DATE%" BACKUP_DATE
SET "DEST_PATH=%BACKUP_PATH%\%BACKUP_OP%_%BACKUP_DATE%"
::�ж��Ƿ��Ѿ���ִ�л�ִ�й�
IF EXIST "%DEST_PATH%" (
  ECHO.
  ECHO �����Ѿ�ִ�й�!
  SET "RETURN=1"
  GOTO :END
)
::����Ŀ��Ŀ¼
MKDIR "%DEST_PATH%"
::д����־
CALL :ECHO_DATETIME "========== ��ʼ���� " " ==========" >"%DEST_PATH%\RUN.LOG"
::���ɱ��ݽű�
CALL :ECHO_HEAD >"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_SHOW >>"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_BACKUP_%BACKUP_OP% "%DEST_PATH%" "%COMPRESS%">>"%DEST_PATH%\BACKUP.RMAN"
CALL :ECHO_FOOT >>"%DEST_PATH%\BACKUP.RMAN"
::ִ�б���
RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\BACKUP.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
::�жϱ����Ƿ�ɹ�
IF "_%ERRORLEVEL%" == "_0" (
  ::д����־
  CALL :ECHO_DATETIME "========== �������� " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
  ::д����־
  CALL :ECHO_DATETIME "========== ��֤���� " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ::��ѯBS_KEY
  CALL :ECHO_QUERY "%DEST_PATH%" >"%DEST_PATH%\BS_KEY.SQL"
  IF "_%BACKUP_DB:~0,1%" == "_/" (
    SQLPLUS -L -S "%BACKUP_DB%" AS SYSDBA @%DEST_PATH%\BS_KEY.SQL >"%DEST_PATH%\BS_KEY.TXT"
  ) ELSE (
    SQLPLUS -L -S "%BACKUP_DB%" @%DEST_PATH%\BS_KEY.SQL >"%DEST_PATH%\BS_KEY.TXT"
  )
  ::��ȡBS_KEY
  CALL :GET_NUMBERS "%DEST_PATH%\BS_KEY.TXT" "BS_KEY"
  ::����У��ű�
  CALL :ECHO_HEAD >"%DEST_PATH%\VALIDATE.RMAN"
  FOR %%I IN (!BS_KEY!) DO (
    CALL :ECHO_VALIDATE "%%~I" >>"%DEST_PATH%\VALIDATE.RMAN"
  )
  CALL :ECHO_FOOT >>"%DEST_PATH%\VALIDATE.RMAN"
  ::��֤����
  RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\VALIDATE.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
  IF NOT "_!ERRORLEVEL!" == "_0" SET "RETURN=1"
  ::д����־
  CALL :ECHO_DATETIME "========== ��֤���� " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
) ELSE (
  SET "RETURN=1"
)
::�жϱ��ݳɹ�
IF "_%RETURN%" == "_1" (
  ::��Ǵ���
  MOVE /Y "%DEST_PATH%" "%DEST_PATH%_ERROR" 1>NUL 2>NUL
) ELSE (
  ::��������ű�
  CALL :ECHO_HEAD >"%DEST_PATH%\DELETE.RMAN"
  CALL :ECHO_DELETE >>"%DEST_PATH%\DELETE.RMAN"
  CALL :ECHO_FOOT >>"%DEST_PATH%\DELETE.RMAN"
  ::д����־
  CALL :ECHO_DATETIME "========== ������ڱ��� " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ::������ڱ���
  RMAN target="%BACKUP_DB%" CMDFILE="%DEST_PATH%\DELETE.RMAN" LOG="%DEST_PATH%\RUN.LOG" APPEND
  ::����Ƿ�ȫ�ⱸ��
  SET "BACKUP_FULL=FALSE"
  FOR %%I IN (DATABASE,LEVEL0) DO IF /I "_%BACKUP_OP%" == "_%%~I" SET "BACKUP_FULL=TRUE"
  ::�������Ŀ¼
  FOR /D %%I IN ("%BACKUP_PATH%\*") DO (
    ::�ж��Ƿ����Ŀ¼
    SET "BACKUP_EMPTY=%%~I"
    IF /I "_!BACKUP_EMPTY:~-5!" == "_ERROR" (
      ::����Ŀ¼��ȫ�ⱸ��ʱɾ��
      IF /I "_!BACKUP_FULL!" == "_TRUE" RMDIR /S /Q "%%~I" 1>NUL 2>NUL
    ) ELSE (
      ::�����Ѿ����ڱ��ݵĲ���Ŀ¼
      IF NOT EXIST "%%~I\BACKUP-*" RMDIR /S /Q "%%~I" 1>NUL 2>NUL
    )
  )
  SET "BACKUP_EMPTY="
  SET "BACKUP_FULL="
  ::д����־
  CALL :ECHO_DATETIME "========== ���������� " " ==========" >>"%DEST_PATH%\RUN.LOG"
  ECHO.
  ECHO.
)
::ͬ����Զ�̴洢
IF EXIST "%REMOTE_PATH%" (
  CALL :SLEEP 30
  ROBOCOPY "%BACKUP_PATH%" "%REMOTE_PATH%" /MIR /R:10
) 
GOTO :END


::���ɵ�ǰʱ��
::  ����1: ǰ׺����
::  ����2: ��׺����
:ECHO_DATETIME
@ECHO %~1 %DATE% %TIME% %~2
GOTO :EOF

::��ȡ�ı�����
::  ����1: �ı��ļ�
::  ����2: ���ز���(�������������Ļ)
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

::ͳһ���ڸ�ʽ�ַ���
::  ����1: �������ڸ�ʽ(yyyy MM dd)
::  ����2: ���������(�����������Ļ)
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

::����CHOICE�����ӳ�
:SLEEP
CHOICE /C "0" /N /D "0" /T %~1 1>NUL 2>NUL
GOTO :EOF

::���ɲ�ѯBS_KEY
::  ����1: �ļ��ؼ���
:ECHO_QUERY
@ECHO select distinct T2.BS_KEY from V$BACKUP_PIECE T1
@ECHO   inner join V$BACKUP_SET_DETAILS T2
@ECHO   on T1.SET_STAMP = T2.SET_STAMP
@ECHO   where lower(HANDLE) like lower('%%%~1%%') 
@ECHO   order by 1;
@ECHO EXIT;
@GOTO :EOF

::����У�鱸��
::  ����1: BS_KEY
:ECHO_VALIDATE
@ECHO   #У�鱸��SET %~1
@ECHO   validate backupset %~1;
@ECHO.
@GOTO :EOF

::����ɾ��������Ч����
:ECHO_DELETE
@ECHO   #ɾ��������Ч����
@ECHO   report obsolete;
@ECHO   delete noprompt obsolete;
@ECHO   crosscheck archivelog all;
@ECHO   delete noprompt expired archivelog all;
@ECHO   crosscheck backup;
@ECHO   delete noprompt expired backup;
@ECHO.
@GOTO :EOF

::���ɽű�ͷ
:ECHO_HEAD
@ECHO run {
@ECHO.
@GOTO :EOF

::���ɽű���
:ECHO_FOOT
@ECHO }
@GOTO :EOF

::��ʾȫ������
:ECHO_SHOW
@ECHO   #��ʾRMAN����
@ECHO   show all;
@ECHO.
@GOTO :EOF


::����ȫ��
::  ����1: ����·��
::  ����2: �Ƿ�ѹ��
:ECHO_BACKUP_DATABASE
@ECHO   #����ȫ��
IF /I "_%~2" == "_TRUE" (
  @ECHO   backup as compressed backupset
) ELSE (
  @ECHO   backup
)
@ECHO     database tag='DATABASE'
@ECHO     format '%~1\BACKUP-%%U';
@ECHO.
@GOTO :EOF

::���ݹ鵵��־
::  ����1: ����·��
::  ����2: �Ƿ�ѹ��
:ECHO_BACKUP_ARCHIVELOG
@ECHO   #���ݹ鵵��־
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

::ȥ�ո�
::  ����1: Ŀ���ַ���
::  ����2: �����������(��ѡ,ֱ���������Ļ)
:TRIM
CALL :TRIM_TO_VAR %~1
IF "_%~2" == "_" (
  ECHO %TRIMED_STRING%
) ELSE (
  SET "%~2=%TRIMED_STRING%"
)
SET "TRIMED_STRING="
GOTO :EOF

::ȥ�ո񵽹̶�����TRIMED_STRING
::  ����: Ŀ���ַ���
:TRIM_TO_VAR
SET "TRIMED_STRING=%*"
GOTO :EOF

:END
EXIT /B %RETURN%
