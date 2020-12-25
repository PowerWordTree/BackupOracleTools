��������BackupOracleTools.cfg�ļ�

����:
    DATABASE: �������ݿ�
    ARCHIVELOG: ���ݹ鵵��־
    CONTROLFILE: ���ݿ����ļ�
    SPFILE: ���ݲ����ļ�

======================================================

# ��Ҫ���á����ݱ������ԡ��� �Ƽ����ָ����ڵı������ԡ�
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
# ���ñ��ݷ�Ƭ
CONFIGURE CHANNEL DEVICE TYPE DISK MAXPIECESIZE 10G;
# ���ò���ͨ��
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
# ����ѹ��ģʽ
CONFIGURE COMPRESSION ALGORITHM 'LOW';
======================================================

#���ù鵵ģʽ
shutdown immediate;
startup mount;
alter database archivelog;
alter database open;

# �鿴�鵵��־����
archive log list;
# �鿴����·��
show parameter db_recover;
# �鿴����ʹ�����
select name,SPACE_LIMIT,SPACE_USED from v$recovery_file_dest;
# ��������������
alter system set db_recovery_file_dest_size=5G;
# ���Ĺ鵵��־λ��
alter system set log_archive_dest_1='location=D:\arch';
# �л���־�ļ�
alter system switch logfile;
======================================================

restore database;
recover database;
alter database open resetlogs;
