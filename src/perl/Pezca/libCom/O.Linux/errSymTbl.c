/*
 * status code symbol table
 *
 * CREATED BY makeStatTbl.pl
 *       FROM /amnt/csr/epics/R3.13.1/support/base/3-13-5/src/libCom/O.Linux
 *         ON Tue Sep 25 14:40:19 2001
 */

#ifdef vxWorks
#include "vxWorks.h"
#endif
#include "errMdef.h"
#include "errSymTbl.h"

#ifndef M_dbAccess
#define M_dbAccess (501 <<16) /*Database Access Routines */
#endif /* ifdef M_dbAccess */
#ifndef M_drvSup
#define M_drvSup (503 <<16) /*Driver Support*/
#endif /* ifdef M_drvSup */
#ifndef M_devSup
#define M_devSup (504 <<16) /*Device Support*/
#endif /* ifdef M_devSup */
#ifndef M_recSup
#define M_recSup (505 <<16) /*Record Support*/
#endif /* ifdef M_recSup */
#ifndef M_recType
#define M_recType (506 <<16) /*Record Type*/
#endif /* ifdef M_recType */
#ifndef M_record
#define M_record (507 <<16) /*Database Records*/
#endif /* ifdef M_record */
#ifndef M_ar
#define M_ar (508 <<16) /*Archiver; see arDefs.h*/
#endif /* ifdef M_ar */
#ifndef M_ts
#define M_ts (509 <<16) /*Time Stamp Routines; see tsDefs.h*/
#endif /* ifdef M_ts */
#ifndef M_arAcc
#define M_arAcc (510 <<16) /*Archive Access Library Routines*/
#endif /* ifdef M_arAcc */
#ifndef M_bf
#define M_bf (511 <<16) /*Block File Routines; see bfDefs.h*/
#endif /* ifdef M_bf */
#ifndef M_syd
#define M_syd (512 <<16) /*Sync Data Routines; see sydDefs.h*/
#endif /* ifdef M_syd */
#ifndef M_ppr
#define M_ppr (513 <<16) /*Portable Plot Routines; see pprPlotDefs.h*/
#endif /* ifdef M_ppr */
#ifndef M_env
#define M_env (514 <<16) /*Environment Routines; see envDefs.h*/
#endif /* ifdef M_env */
#ifndef M_gen
#define M_gen (515 <<16) /*General Purpose Routines; see genDefs.h*/
#endif /* ifdef M_gen */
#ifndef M_dbLib
#define M_dbLib (519 <<16) /*Static Database Access */
#endif /* ifdef M_dbLib */
#ifndef M_epvxi
#define M_epvxi (520 <<16) /*VXI Driver*/
#endif /* ifdef M_epvxi */
#ifndef M_devLib
#define M_devLib (521 <<16) /*Device Resource Registration*/
#endif /* ifdef M_devLib */
#ifndef M_asLib
#define M_asLib (522 <<16) /*Access Security		*/
#endif /* ifdef M_asLib */
#ifndef M_cas
#define M_cas (523 <<16) /*CA server*/
#endif /* ifdef M_cas */
#ifndef M_casApp
#define M_casApp (524 <<16) /*CA server application*/
#endif /* ifdef M_casApp */
#ifndef M_bucket
#define M_bucket (525 <<16) /*Bucket Hash*/
#endif /* ifdef M_bucket */
#ifndef M_gddFuncTbl
#define M_gddFuncTbl (526 <<16) /*gdd jump table*/
#endif /* ifdef M_gddFuncTbl */
#define S_asLib_clientsExist 	(M_asLib| 1) /*Client Exists*/
#define S_asLib_noUag 		(M_asLib| 2) /*User Access Group does not exist*/
#define S_asLib_noHag 		(M_asLib| 3) /*Host Access Group does not exist*/
#define S_asLib_noAccess	(M_asLib| 4) /*access security: no access allowed*/
#define S_asLib_noModify	(M_asLib| 5) /*access security: no modification allowed*/
#define S_asLib_badConfig	(M_asLib| 6) /*access security: bad configuration file*/
#define S_asLib_badCalc		(M_asLib| 7) /*access security: bad calculation espression*/
#define S_asLib_dupAsg 		(M_asLib| 8) /*Duplicate Access Security Group */
#define S_asLib_InitFailed 	(M_asLib| 9) /*access security: Init failed*/
#define S_asLib_asNotActive 	(M_asLib|10) /*access security is not active*/
#define S_asLib_badMember 	(M_asLib|11) /*access security: bad ASMEMBERPVT*/
#define S_asLib_badClient 	(M_asLib|12) /*access security: bad ASCLIENTPVT*/
#define S_asLib_badAsg 		(M_asLib|13) /*access security: bad ASG*/
#define S_asLib_noMemory	(M_asLib|14) /*access security: no Memory */
#define S_db_notFound 	(M_dbAccess| 1) /*Process Variable Not Found*/
#define S_db_badDbrtype	(M_dbAccess| 3) /*Illegal Database Request Type*/
#define S_db_noMod 	(M_dbAccess| 5) /*Attempt to modify noMod field*/
#define S_db_badLset 	(M_dbAccess| 7) /*Illegal Lock Set*/
#define S_db_precision 	(M_dbAccess| 9) /*get precision failed */
#define S_db_onlyOne 	(M_dbAccess|11) /*Only one element allowed*/
#define S_db_badChoice 	(M_dbAccess|13) /*Illegal choice*/
#define S_db_badField 	(M_dbAccess|15) /*Illegal field value*/
#define S_db_lsetLogic 	(M_dbAccess|17) /*Logic error generating lock sets*/
#define S_db_noRSET 	(M_dbAccess|31) /*missing record support entry table*/
#define S_db_noSupport 	(M_dbAccess|33) /*RSET routine not defined*/
#define S_db_BadSub 	(M_dbAccess|35) /*Subroutine not found*/
#define S_db_Pending 	(M_dbAccess|37) /*Request is pending*/
#define S_db_Blocked 	(M_dbAccess|39) /*Request is Blocked*/
#define S_db_putDisabled (M_dbAccess|41) /*putFields are disabled*/
#define S_db_bkptSet    (M_dbAccess|53) /*Breakpoint already set*/
#define S_db_bkptNotSet (M_dbAccess|55) /*No breakpoint set in record*/
#define S_db_notStopped (M_dbAccess|57) /*Record not stopped*/
#define S_db_errArg     (M_dbAccess|59) /*Error in argument*/
#define S_db_bkptLogic  (M_dbAccess|61) /*Logic error in breakpoint routine*/
#define S_db_cntSpwn    (M_dbAccess|63) /*Cannot spawn dbContTask*/
#define S_db_cntCont    (M_dbAccess|65) /*Cannot resume dbContTask*/
#define S_dev_vectorInUse (M_devLib| 1) /*Interrupt vector in use*/
#define S_dev_vxWorksVecInstlFail (M_devLib| 2) /*vxWorks interrupt vector install failed*/
#define S_dev_uknIntType (M_devLib| 3) /*Unrecognized interrupt type*/ 
#define S_dev_vectorNotInUse (M_devLib| 4) /*Interrupt vector not in use by caller*/
#define S_dev_badA16 (M_devLib| 5) /*Invalid VME A16 address*/
#define S_dev_badA24 (M_devLib| 6) /*Invalid VME A24 address*/
#define S_dev_badA32 (M_devLib| 7) /*Invalid VME A32 address*/
#define S_dev_uknAddrType (M_devLib| 8) /*Unrecognized address space type*/
#define S_dev_addressOverlap (M_devLib| 9) /*Specified device address overlaps another device*/ 
#define S_dev_identifyOverlap (M_devLib| 10) /*This device already owns the address range*/ 
#define S_dev_vxWorksAddrMapFail (M_devLib| 11) /*vxWorks refused address map*/ 
#define S_dev_intDisconnect (M_devLib| 12) /*Interrupt at vector disconnected from an EPICS device*/ 
#define S_dev_internal (M_devLib| 13) /*Internal failure*/ 
#define S_dev_vxWorksIntEnFail (M_devLib| 14) /*vxWorks interrupt enable failure*/ 
#define S_dev_vxWorksIntDissFail (M_devLib| 15) /*vxWorks interrupt disable failure*/ 
#define S_dev_noMemory (M_devLib| 16) /*Memory allocation failed*/ 
#define S_dev_addressNotFound (M_devLib| 17) /*Specified device address unregistered*/ 
#define S_dev_noDevice (M_devLib| 18) /*No device at specified address*/
#define S_dev_wrongDevice (M_devLib| 19) /*Wrong device type found at specified address*/
#define S_dev_badSignalNumber (M_devLib| 20) /*Signal number (offset) to large*/
#define S_dev_badSignalCount (M_devLib| 21) /*Signal count to large*/
#define S_dev_badRequest (M_devLib| 22) /*Device does not support requested operation*/
#define S_dev_highValue (M_devLib| 23) /*Parameter to high*/
#define S_dev_lowValue (M_devLib| 24) /*Parameter to low*/
#define S_dev_multDevice (M_devLib| 25) /*Specified address is ambiguous (more than one device responds)*/
#define S_dev_badSelfTest (M_devLib| 26) /*Device self test failed*/
#define S_dev_badInit (M_devLib| 27) /*Device failed during initialization*/
#define S_dev_hdwLimit (M_devLib| 28) /*Input exceeds Hardware Limit*/
#define S_dev_deviceDoesNotFit (M_devLib| 29) /*Unable to locate address space for device*/
#define S_dev_deviceTMO (M_devLib| 30) /*device timed out*/
#define S_dev_noDevSup      (M_devSup| 1) /*SDR_DEVSUP: Device support missing*/
#define S_dev_noDSET        (M_devSup| 3) /*Missing device support entry table*/
#define S_dev_missingSup    (M_devSup| 5) /*Missing device support routine*/
#define S_dev_badInpType    (M_devSup| 7) /*Bad INP link type*/
#define S_dev_badOutType    (M_devSup| 9) /*Bad OUT link type*/
#define S_dev_badInitRet    (M_devSup|11) /*Bad init_rec return value */
#define S_dev_badBus        (M_devSup|13) /*Illegal bus type*/
#define S_dev_badCard       (M_devSup|15) /*Illegal or nonexistant module*/
#define S_dev_badSignal     (M_devSup|17) /*Illegal signal*/
#define S_dev_NoInit        (M_devSup|19) /*No init*/
#define S_dev_Conflict      (M_devSup|21) /*Multiple records accessing same signal*/
#define S_drv_noDrvSup   (M_drvSup| 1) /*SDR_DRVSUP: Driver support missing*/
#define S_drv_noDrvet    (M_drvSup| 3) /*Missing driver support entry table*/
#define S_rec_noRSET     (M_recSup| 1) /*Missing record support entry table*/
#define S_rec_noSizeOffset (M_recSup| 2) /*Missing SizeOffset Routine*/
#define S_rec_outMem     (M_recSup| 3) /*Out of Memory*/
#define S_dbLib_recordTypeNotFound (M_dbLib| 1)	/*Record Type does not exist*/
#define S_dbLib_recExists (M_dbLib| 3)		/*Record Already exists*/
#define S_dbLib_recNotFound (M_dbLib| 5)	/*Record Not Found*/
#define S_dbLib_flddesNotFound (M_dbLib| 7)	/*Field Description Not Found*/
#define S_dbLib_fieldNotFound (M_dbLib| 9)	/*Field Not Found*/
#define S_dbLib_badField (M_dbLib|11)		/*Bad Field value*/
#define S_dbLib_menuNotFound (M_dbLib|13)	/*Menu not found*/
#define S_dbLib_badLink (M_dbLib|15)		/*Bad Link Field*/
#define S_dbLib_nameLength (M_dbLib|17)		/*Record Name is too long*/
#define S_dbLib_noRecSup (M_dbLib|19)		/*Record support not found*/
#define S_dbLib_strLen (M_dbLib|21)		/*String is too long*/
#define S_dbLib_noSizeOffset (M_dbLib|23)	/*Missing SizeOffset Routine - No record support?*/
#define S_dbLib_noForm (M_dbLib|25)		/*dbAllocForm was not called*/
#define S_epvxi_noDevice (M_epvxi|1) /*device does not exist*/
#define S_epvxi_notSlotZero (M_epvxi|2) /*not a slot zero devic*/
#define S_epvxi_uknDevice (M_epvxi|3) /*device not supported*/
#define S_epvxi_badTrigger (M_epvxi|4) /*specified trigger does not exist*/
#define S_epvxi_badTrigIO (M_epvxi|5) /*specified trigger io does not exist*/
#define S_epvxi_deviceOpen (M_epvxi|6) /*device already open*/
#define S_epvxi_notOwner (M_epvxi|7) /*device in use by a different driver*/
#define S_epvxi_noMemory (M_epvxi|8) /*memory allocation failed*/
#define S_epvxi_notOpen (M_epvxi|9) /*device not open*/
#define S_epvxi_notMsgDevice (M_epvxi|10) /*operation requires a message based device*/
#define S_epvxi_deviceTMO (M_epvxi|11) /*message based dev timed out*/
#define S_epvxi_msgDeviceFailure (M_epvxi|12) /*message based dev failed*/
#define S_epvxi_badLA (M_epvxi|13) /*logical addr out of range*/
#define S_epvxi_multipleQueries (M_epvxi|14) /*multiple queries serial protocol error*/
#define S_epvxi_unsupportedCmd (M_epvxi|15) /*unsupported cmd serial protocol error*/
#define S_epvxi_dirViolation (M_epvxi|16) /*DIR violation serial protocol error*/
#define S_epvxi_dorViolation (M_epvxi|17) /*DOR violation serial protocol error*/
#define S_epvxi_rrViolation (M_epvxi|18) /*RR violation serial protocol error*/
#define S_epvxi_wrViolation (M_epvxi|19) /*WR violation serial protocol error*/
#define S_epvxi_errFetchFailed (M_epvxi|20) /*unknown serial protocol error*/
#define S_epvxi_selfTestFailed (M_epvxi|21) /*self test failed*/
#define S_epvxi_timeoutToLarge (M_epvxi|22) /*specified timeout to long*/
#define S_epvxi_protocolError (M_epvxi|23) /*protocol error*/
#define S_epvxi_unreadData (M_epvxi|24) /*attempt to write when unread data from a previous command is present (RULE C.3.3)*/
#define S_epvxi_nameMismatch (M_epvxi|25) /*make or model name already registered does not matchi supplied name*/
#define S_epvxi_noMatch (M_epvxi|26) /*no name registered for the supplied make and or model*/
#define S_epvxi_bufferFull (M_epvxi|27) /*read terminated with unread data remaining because the end of the supplied  buffer was reached*/
#define S_epvxi_noResman (M_epvxi|28) /*the VXI resource manager must run first*/
#define S_epvxi_internal (M_epvxi|29) /*VXI internal failure*/
#define S_epvxi_badConfig (M_epvxi|30) /*Incorrect system configuration*/
#define S_epvxi_noCmdr (M_epvxi|31) /*No commander hardware support for message based comm - continuing*/
#define S_epvxi_msgDeviceStatus (M_epvxi|32) /*VXI Message based device reporting error condition*/
#define S_epvxi_slotNotFound (M_epvxi|33) /*VXI device's slot not found- MODID failure?*/
#define S_epvxi_noMODID (M_epvxi|34) /*VXI device does not have MODID capability*/
#define S_BB_ok		(M_bitbus|0| 0<<1) /* success */
#define S_BB_badPrio	(M_bitbus|1| 1<<1) /* Invalid xact request queue priority */
#define S_IB_ok		(M_gpib|0| 0<<1) /* success */
#define S_IB_badPrio	(M_gpib|1| 1<<1) /* invalid xact request queue priority */
#define S_ts_OK		     0 
#define S_ts_sysTimeError    (M_ts|1| 1<<1) /* error getting system time */
#define S_ts_badTextCode     (M_ts|1| 2<<1) /* invalid TS_TEXT_xxx code */
#define S_ts_inputTextError  (M_ts|1| 3<<1) /* error in text date or time */
#define S_ts_timeSkippedDST  (M_ts|1| 4<<1) /* time skipped on switch to DST */
#define S_ts_badRoundInterval (M_ts|1| 5<<1) /* invalid rounding interval */
#define S_cas_success 0
#define S_cas_internal (M_cas| 1) /*Internal failure*/
#define S_cas_noMemory (M_cas| 2) /*Memory allocation failed*/
#define S_cas_bindFail (M_cas| 3) /*Attempt to set server's IP address/port failed*/
#define S_cas_hugeRequest (M_cas | 4) /*Requested op does not fit*/
#define S_cas_sendBlocked (M_cas | 5) /*Blocked for send q space*/
#define S_cas_badElementCount (M_cas | 6) /*Bad element count*/
#define S_cas_noConvert (M_cas | 7) /*No conversion between src & dest types*/
#define S_cas_badWriteType (M_cas | 8) /*Src type inappropriate for write*/
#define S_cas_noContext (M_cas | 11) /*Context parameter is required*/
#define S_cas_disconnect (M_cas | 12) /*Lost connection to server*/
#define S_cas_recvBlocked (M_cas | 13) /*Recv blocked*/
#define S_cas_badType (M_cas | 14) /*Bad data type*/
#define S_cas_timerDoesNotExist (M_cas | 15) /*Timer does not exist*/
#define S_cas_badEventType (M_cas | 16) /*Bad event type*/
#define S_cas_badResourceId (M_cas | 17) /*Bad resource identifier*/
#define S_cas_chanCreateFailed (M_cas | 18) /*Unable to create channel*/
#define S_cas_noRead (M_cas | 19) /*read access denied*/
#define S_cas_noWrite (M_cas | 20) /*write access denied*/
#define S_cas_noEventsSelected (M_cas | 21) /*no events selected*/
#define S_cas_noFD (M_cas | 22) /*no file descriptors available*/
#define S_cas_badProtocol (M_cas | 23) /*protocol from client was invalid*/
#define S_cas_redundantPost (M_cas | 24) /*redundundant io completion post*/
#define S_cas_badPVName (M_cas | 25) /*bad PV name from server tool*/
#define S_cas_badParameter (M_cas | 26) /*bad parameter from server tool*/
#define S_cas_validRequest (M_cas | 27) /*valid request*/
#define S_cas_tooManyEvents (M_cas | 28) /*maximum simult event types exceeded*/
#define S_cas_noInterface (M_cas | 29) /*server isnt attached to a network*/
#define S_cas_badBounds (M_cas | 30) /*server tool changed bounds on request*/
#define S_cas_pvAlreadyAttached (M_cas | 31) /*PV attached to another server*/
#define S_cas_badRequest (M_cas | 32) /*client's request was invalid*/
#define S_casApp_success 0 
#define S_casApp_noMemory (M_casApp | 1) /*Memory allocation failed*/
#define S_casApp_pvNotFound (M_casApp | 2) /*PV not found*/
#define S_casApp_badPVId (M_casApp | 3) /*Unknown PV identifier*/
#define S_casApp_noSupport (M_casApp | 4) /*No application support for op*/
#define S_casApp_asyncCompletion (M_casApp | 5) /*will complete asynchronously*/
#define S_casApp_badDimension (M_casApp | 6) /*bad matrix size in request*/
#define S_casApp_canceledAsyncIO (M_casApp | 7) /*asynchronous io canceled*/
#define S_casApp_outOfBounds (M_casApp | 8) /*operation was out of bounds*/
#define S_casApp_undefined (M_casApp | 9) /*undefined value*/
#define S_casApp_postponeAsyncIO (M_casApp | 10) /*postpone asynchronous IO*/
#define S_gddAppFuncTable_Success 0u
#define S_gddAppFuncTable_badType (M_gddFuncTbl|1u) /*unregisted appl type*/ 
#define S_gddAppFuncTable_gddLimit (M_gddFuncTbl|2u) /*at gdd lib limit*/ 
#define S_gddAppFuncTable_noMemory (M_gddFuncTbl|3u) /*dynamic memory pool exhausted*/ 

LOCAL ERRSYMBOL symbols[] =
{
	{ "Client Exists", (long) S_asLib_clientsExist },
	{ "User Access Group does not exist", (long) S_asLib_noUag },
	{ "Host Access Group does not exist", (long) S_asLib_noHag },
	{ "access security: no access allowed", (long) S_asLib_noAccess },
	{ "access security: no modification allowed", (long) S_asLib_noModify },
	{ "access security: bad configuration file", (long) S_asLib_badConfig },
	{ "access security: bad calculation espression", (long) S_asLib_badCalc },
	{ "Duplicate Access Security Group ", (long) S_asLib_dupAsg },
	{ "access security: Init failed", (long) S_asLib_InitFailed },
	{ "access security is not active", (long) S_asLib_asNotActive },
	{ "access security: bad ASMEMBERPVT", (long) S_asLib_badMember },
	{ "access security: bad ASCLIENTPVT", (long) S_asLib_badClient },
	{ "access security: bad ASG", (long) S_asLib_badAsg },
	{ "access security: no Memory ", (long) S_asLib_noMemory },
	{ "Process Variable Not Found", (long) S_db_notFound },
	{ "Illegal Database Request Type", (long) S_db_badDbrtype },
	{ "Attempt to modify noMod field", (long) S_db_noMod },
	{ "Illegal Lock Set", (long) S_db_badLset },
	{ "get precision failed ", (long) S_db_precision },
	{ "Only one element allowed", (long) S_db_onlyOne },
	{ "Illegal choice", (long) S_db_badChoice },
	{ "Illegal field value", (long) S_db_badField },
	{ "Logic error generating lock sets", (long) S_db_lsetLogic },
	{ "missing record support entry table", (long) S_db_noRSET },
	{ "RSET routine not defined", (long) S_db_noSupport },
	{ "Subroutine not found", (long) S_db_BadSub },
	{ "Request is pending", (long) S_db_Pending },
	{ "Request is Blocked", (long) S_db_Blocked },
	{ "putFields are disabled", (long) S_db_putDisabled },
	{ "Breakpoint already set", (long) S_db_bkptSet },
	{ "No breakpoint set in record", (long) S_db_bkptNotSet },
	{ "Record not stopped", (long) S_db_notStopped },
	{ "Error in argument", (long) S_db_errArg },
	{ "Logic error in breakpoint routine", (long) S_db_bkptLogic },
	{ "Cannot spawn dbContTask", (long) S_db_cntSpwn },
	{ "Cannot resume dbContTask", (long) S_db_cntCont },
	{ "Interrupt vector in use", (long) S_dev_vectorInUse },
	{ "vxWorks interrupt vector install failed", (long) S_dev_vxWorksVecInstlFail },
	{ "Unrecognized interrupt type", (long) S_dev_uknIntType },
	{ "Interrupt vector not in use by caller", (long) S_dev_vectorNotInUse },
	{ "Invalid VME A16 address", (long) S_dev_badA16 },
	{ "Invalid VME A24 address", (long) S_dev_badA24 },
	{ "Invalid VME A32 address", (long) S_dev_badA32 },
	{ "Unrecognized address space type", (long) S_dev_uknAddrType },
	{ "Specified device address overlaps another device", (long) S_dev_addressOverlap },
	{ "This device already owns the address range", (long) S_dev_identifyOverlap },
	{ "vxWorks refused address map", (long) S_dev_vxWorksAddrMapFail },
	{ "Interrupt at vector disconnected from an EPICS device", (long) S_dev_intDisconnect },
	{ "Internal failure", (long) S_dev_internal },
	{ "vxWorks interrupt enable failure", (long) S_dev_vxWorksIntEnFail },
	{ "vxWorks interrupt disable failure", (long) S_dev_vxWorksIntDissFail },
	{ "Memory allocation failed", (long) S_dev_noMemory },
	{ "Specified device address unregistered", (long) S_dev_addressNotFound },
	{ "No device at specified address", (long) S_dev_noDevice },
	{ "Wrong device type found at specified address", (long) S_dev_wrongDevice },
	{ "Signal number (offset) to large", (long) S_dev_badSignalNumber },
	{ "Signal count to large", (long) S_dev_badSignalCount },
	{ "Device does not support requested operation", (long) S_dev_badRequest },
	{ "Parameter to high", (long) S_dev_highValue },
	{ "Parameter to low", (long) S_dev_lowValue },
	{ "Specified address is ambiguous (more than one device responds)", (long) S_dev_multDevice },
	{ "Device self test failed", (long) S_dev_badSelfTest },
	{ "Device failed during initialization", (long) S_dev_badInit },
	{ "Input exceeds Hardware Limit", (long) S_dev_hdwLimit },
	{ "Unable to locate address space for device", (long) S_dev_deviceDoesNotFit },
	{ "device timed out", (long) S_dev_deviceTMO },
	{ "SDR_DEVSUP: Device support missing", (long) S_dev_noDevSup },
	{ "Missing device support entry table", (long) S_dev_noDSET },
	{ "Missing device support routine", (long) S_dev_missingSup },
	{ "Bad INP link type", (long) S_dev_badInpType },
	{ "Bad OUT link type", (long) S_dev_badOutType },
	{ "Bad init_rec return value ", (long) S_dev_badInitRet },
	{ "Illegal bus type", (long) S_dev_badBus },
	{ "Illegal or nonexistant module", (long) S_dev_badCard },
	{ "Illegal signal", (long) S_dev_badSignal },
	{ "No init", (long) S_dev_NoInit },
	{ "Multiple records accessing same signal", (long) S_dev_Conflict },
	{ "SDR_DRVSUP: Driver support missing", (long) S_drv_noDrvSup },
	{ "Missing driver support entry table", (long) S_drv_noDrvet },
	{ "Missing record support entry table", (long) S_rec_noRSET },
	{ "Missing SizeOffset Routine", (long) S_rec_noSizeOffset },
	{ "Out of Memory", (long) S_rec_outMem },
	{ "Record Type does not exist", (long) S_dbLib_recordTypeNotFound },
	{ "Record Already exists", (long) S_dbLib_recExists },
	{ "Record Not Found", (long) S_dbLib_recNotFound },
	{ "Field Description Not Found", (long) S_dbLib_flddesNotFound },
	{ "Field Not Found", (long) S_dbLib_fieldNotFound },
	{ "Bad Field value", (long) S_dbLib_badField },
	{ "Menu not found", (long) S_dbLib_menuNotFound },
	{ "Bad Link Field", (long) S_dbLib_badLink },
	{ "Record Name is too long", (long) S_dbLib_nameLength },
	{ "Record support not found", (long) S_dbLib_noRecSup },
	{ "String is too long", (long) S_dbLib_strLen },
	{ "Missing SizeOffset Routine - No record support?", (long) S_dbLib_noSizeOffset },
	{ "dbAllocForm was not called", (long) S_dbLib_noForm },
	{ "device does not exist", (long) S_epvxi_noDevice },
	{ "not a slot zero devic", (long) S_epvxi_notSlotZero },
	{ "device not supported", (long) S_epvxi_uknDevice },
	{ "specified trigger does not exist", (long) S_epvxi_badTrigger },
	{ "specified trigger io does not exist", (long) S_epvxi_badTrigIO },
	{ "device already open", (long) S_epvxi_deviceOpen },
	{ "device in use by a different driver", (long) S_epvxi_notOwner },
	{ "memory allocation failed", (long) S_epvxi_noMemory },
	{ "device not open", (long) S_epvxi_notOpen },
	{ "operation requires a message based device", (long) S_epvxi_notMsgDevice },
	{ "message based dev timed out", (long) S_epvxi_deviceTMO },
	{ "message based dev failed", (long) S_epvxi_msgDeviceFailure },
	{ "logical addr out of range", (long) S_epvxi_badLA },
	{ "multiple queries serial protocol error", (long) S_epvxi_multipleQueries },
	{ "unsupported cmd serial protocol error", (long) S_epvxi_unsupportedCmd },
	{ "DIR violation serial protocol error", (long) S_epvxi_dirViolation },
	{ "DOR violation serial protocol error", (long) S_epvxi_dorViolation },
	{ "RR violation serial protocol error", (long) S_epvxi_rrViolation },
	{ "WR violation serial protocol error", (long) S_epvxi_wrViolation },
	{ "unknown serial protocol error", (long) S_epvxi_errFetchFailed },
	{ "self test failed", (long) S_epvxi_selfTestFailed },
	{ "specified timeout to long", (long) S_epvxi_timeoutToLarge },
	{ "protocol error", (long) S_epvxi_protocolError },
	{ "attempt to write when unread data from a previous command is present (RULE C.3.3)", (long) S_epvxi_unreadData },
	{ "make or model name already registered does not matchi supplied name", (long) S_epvxi_nameMismatch },
	{ "no name registered for the supplied make and or model", (long) S_epvxi_noMatch },
	{ "read terminated with unread data remaining because the end of the supplied  buffer was reached", (long) S_epvxi_bufferFull },
	{ "the VXI resource manager must run first", (long) S_epvxi_noResman },
	{ "VXI internal failure", (long) S_epvxi_internal },
	{ "Incorrect system configuration", (long) S_epvxi_badConfig },
	{ "No commander hardware support for message based comm - continuing", (long) S_epvxi_noCmdr },
	{ "VXI Message based device reporting error condition", (long) S_epvxi_msgDeviceStatus },
	{ "VXI device's slot not found- MODID failure?", (long) S_epvxi_slotNotFound },
	{ "VXI device does not have MODID capability", (long) S_epvxi_noMODID },
	{ " success ", (long) S_BB_ok },
	{ " Invalid xact request queue priority ", (long) S_BB_badPrio },
	{ " success ", (long) S_IB_ok },
	{ " invalid xact request queue priority ", (long) S_IB_badPrio },
	{ " error getting system time ", (long) S_ts_sysTimeError },
	{ " invalid TS_TEXT_xxx code ", (long) S_ts_badTextCode },
	{ " error in text date or time ", (long) S_ts_inputTextError },
	{ " time skipped on switch to DST ", (long) S_ts_timeSkippedDST },
	{ " invalid rounding interval ", (long) S_ts_badRoundInterval },
	{ "Internal failure", (long) S_cas_internal },
	{ "Memory allocation failed", (long) S_cas_noMemory },
	{ "Attempt to set server's IP address/port failed", (long) S_cas_bindFail },
	{ "Requested op does not fit", (long) S_cas_hugeRequest },
	{ "Blocked for send q space", (long) S_cas_sendBlocked },
	{ "Bad element count", (long) S_cas_badElementCount },
	{ "No conversion between src & dest types", (long) S_cas_noConvert },
	{ "Src type inappropriate for write", (long) S_cas_badWriteType },
	{ "Context parameter is required", (long) S_cas_noContext },
	{ "Lost connection to server", (long) S_cas_disconnect },
	{ "Recv blocked", (long) S_cas_recvBlocked },
	{ "Bad data type", (long) S_cas_badType },
	{ "Timer does not exist", (long) S_cas_timerDoesNotExist },
	{ "Bad event type", (long) S_cas_badEventType },
	{ "Bad resource identifier", (long) S_cas_badResourceId },
	{ "Unable to create channel", (long) S_cas_chanCreateFailed },
	{ "read access denied", (long) S_cas_noRead },
	{ "write access denied", (long) S_cas_noWrite },
	{ "no events selected", (long) S_cas_noEventsSelected },
	{ "no file descriptors available", (long) S_cas_noFD },
	{ "protocol from client was invalid", (long) S_cas_badProtocol },
	{ "redundundant io completion post", (long) S_cas_redundantPost },
	{ "bad PV name from server tool", (long) S_cas_badPVName },
	{ "bad parameter from server tool", (long) S_cas_badParameter },
	{ "valid request", (long) S_cas_validRequest },
	{ "maximum simult event types exceeded", (long) S_cas_tooManyEvents },
	{ "server isnt attached to a network", (long) S_cas_noInterface },
	{ "server tool changed bounds on request", (long) S_cas_badBounds },
	{ "PV attached to another server", (long) S_cas_pvAlreadyAttached },
	{ "client's request was invalid", (long) S_cas_badRequest },
	{ "Memory allocation failed", (long) S_casApp_noMemory },
	{ "PV not found", (long) S_casApp_pvNotFound },
	{ "Unknown PV identifier", (long) S_casApp_badPVId },
	{ "No application support for op", (long) S_casApp_noSupport },
	{ "will complete asynchronously", (long) S_casApp_asyncCompletion },
	{ "bad matrix size in request", (long) S_casApp_badDimension },
	{ "asynchronous io canceled", (long) S_casApp_canceledAsyncIO },
	{ "operation was out of bounds", (long) S_casApp_outOfBounds },
	{ "undefined value", (long) S_casApp_undefined },
	{ "postpone asynchronous IO", (long) S_casApp_postponeAsyncIO },
	{ "unregisted appl type", (long) S_gddAppFuncTable_badType },
	{ "at gdd lib limit", (long) S_gddAppFuncTable_gddLimit },
	{ "dynamic memory pool exhausted", (long) S_gddAppFuncTable_noMemory },
};

LOCAL ERRSYMTAB symTbl =
{
	NELEMENTS(symbols),  /* current number of symbols in table */
	symbols,             /* ptr to symbol array */
};

ERRSYMTAB_ID errSymTbl = &symTbl;

/*	EOF errSymTbl.c */
