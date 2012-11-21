serverscripts
=============

Variety of Centos maintenance scripts and etc.

Most useful scripts in our company

/backup         - Backup scripts
 ./db.node      - Backup scripts running on database node
 ./hardware     - Backup scripts running only on hardware node
 ./pool.node        - Backup scripts running only on database load balancer node (Pgpool)
 ./utils        - Special backup utilities and misc backup scripts

/cluster        - Cluster scripts
 ./ocf          - OCF Resource Agents 

/utils          - Utilities
 ./availability     - Availability workaround scripts
 ./cluster      - useful cluster utilities

/zabbix         - Zabbix scripts
 ./scripts      - Zabbix status scripts for agentd
  ./zabbix_agentd   - Zabbix agent based scripts, used in CUSTOM_PARAMETERS
  ./zabbix_sender   - Zabbix sender based scripts

/temp           - Temporary scripts, or old scripts

