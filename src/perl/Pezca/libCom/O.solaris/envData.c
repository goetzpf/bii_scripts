/*	envData.c
 *
 *	created by bldEnvData.pl
 *
 *	from:
 *	../envDefs.h
 *	/net/csr/csr/epics/R3.13.1/support/base/3-13-3/config/CONFIG_ENV
 *	/net/csr/csr/epics/R3.13.1/support/base/3-13-3/config/CONFIG_SITE_ENV
 *
 *	Fri Jul 21 18:01:28 2000
 *
 */

#define epicsExportSharedSymbols
#include "envDefs.h"

epicsShareDef READONLY ENV_PARAM EPICS_AR_PORT = { "EPICS_AR_PORT", "7002" };
epicsShareDef READONLY ENV_PARAM EPICS_CAS_BEACON_ADDR_LIST = { "EPICS_CAS_BEACON_ADDR_LIST", "" };
epicsShareDef READONLY ENV_PARAM EPICS_CAS_INTF_ADDR_LIST = { "EPICS_CAS_INTF_ADDR_LIST", "" };
epicsShareDef READONLY ENV_PARAM EPICS_CAS_SERVER_PORT = { "EPICS_CAS_SERVER_PORT", "" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_ADDR_LIST = { "EPICS_CA_ADDR_LIST", "" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_AUTO_ADDR_LIST = { "EPICS_CA_AUTO_ADDR_LIST", "YES" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_BEACON_PERIOD = { "EPICS_CA_BEACON_PERIOD", "15.0" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_CONN_TMO = { "EPICS_CA_CONN_TMO", "30.0" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_REPEATER_PORT = { "EPICS_CA_REPEATER_PORT", "5065" };
epicsShareDef READONLY ENV_PARAM EPICS_CA_SERVER_PORT = { "EPICS_CA_SERVER_PORT", "5064" };
epicsShareDef READONLY ENV_PARAM EPICS_CMD_PROTO_PORT = { "EPICS_CMD_PROTO_PORT", "" };
epicsShareDef READONLY ENV_PARAM EPICS_IOC_LOG_FILE_COMMAND = { "EPICS_IOC_LOG_FILE_COMMAND", "" };
epicsShareDef READONLY ENV_PARAM EPICS_IOC_LOG_FILE_LIMIT = { "EPICS_IOC_LOG_FILE_LIMIT", "1000000" };
epicsShareDef READONLY ENV_PARAM EPICS_IOC_LOG_FILE_NAME = { "EPICS_IOC_LOG_FILE_NAME", "" };
epicsShareDef READONLY ENV_PARAM EPICS_IOC_LOG_INET = { "EPICS_IOC_LOG_INET", "" };
epicsShareDef READONLY ENV_PARAM EPICS_IOC_LOG_PORT = { "EPICS_IOC_LOG_PORT", "7004" };
epicsShareDef READONLY ENV_PARAM EPICS_TS_MIN_WEST = { "EPICS_TS_MIN_WEST", "360" };
epicsShareDef READONLY ENV_PARAM EPICS_TS_NTP_INET = { "EPICS_TS_NTP_INET", "" };

epicsShareDef READONLY ENV_PARAM* env_param_list[EPICS_ENV_VARIABLE_COUNT+1] =
{
	&EPICS_AR_PORT,
	&EPICS_CAS_BEACON_ADDR_LIST,
	&EPICS_CAS_INTF_ADDR_LIST,
	&EPICS_CAS_SERVER_PORT,
	&EPICS_CA_ADDR_LIST,
	&EPICS_CA_AUTO_ADDR_LIST,
	&EPICS_CA_BEACON_PERIOD,
	&EPICS_CA_CONN_TMO,
	&EPICS_CA_REPEATER_PORT,
	&EPICS_CA_SERVER_PORT,
	&EPICS_CMD_PROTO_PORT,
	&EPICS_IOC_LOG_FILE_COMMAND,
	&EPICS_IOC_LOG_FILE_LIMIT,
	&EPICS_IOC_LOG_FILE_NAME,
	&EPICS_IOC_LOG_INET,
	&EPICS_IOC_LOG_PORT,
	&EPICS_TS_MIN_WEST,
	&EPICS_TS_NTP_INET,
	0
};

/*	EOF envData.c */
