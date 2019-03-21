��������BackupOracleTools.cfg�ļ�

����:
    DATABASE: �������ݿ�
    ARCHIVELOG: ���ݹ鵵��־
    CONTROLFILE: ���ݿ����ļ�
    SPFILE: ���ݲ����ļ�

======================================================

# ��Ҫ���á����ݱ������ԡ��� �Ƽ����ָ����ڵı������ԡ�
configure retention policy to recovery window of 7 days;
# ���ñ��ݷ�Ƭ
configure channel device type disk maxpiecesize 10G;
# ���ò���ͨ��
configure device type disk parallelism 1;
# �Ƽ���ʹ���Զ����ݿ����ļ�
CONFIGURE CONTROLFILE AUTOBACKUP OFF
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
