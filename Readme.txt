需先配置BackupOracleTools.cfg文件

参数:
    DATABASE: 备份数据库
    ARCHIVELOG: 备份归档日志
    CONTROLFILE: 备份控制文件
    SPFILE: 备份参数文件

======================================================

# 需要设置“备份保留策略”， 推荐“恢复窗口的保留策略”
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
# 设置备份分片
CONFIGURE CHANNEL DEVICE TYPE DISK MAXPIECESIZE 10G;
# 设置并行通道
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
# 设置压缩模式
CONFIGURE COMPRESSION ALGORITHM 'LOW';
======================================================

#设置归档模式
shutdown immediate;
startup mount;
alter database archivelog;
alter database open;

# 查看归档日志设置
archive log list;
# 查看闪回路径
show parameter db_recover;
# 查看闪回使用情况
select name,SPACE_LIMIT,SPACE_USED from v$recovery_file_dest;
# 设置闪回区上限
alter system set db_recovery_file_dest_size=5G;
# 更改归档日志位置
alter system set log_archive_dest_1='location=D:\arch';
# 切换日志文件
alter system switch logfile;
======================================================

restore database;
recover database;
alter database open resetlogs;
