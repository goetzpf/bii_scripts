/* errSymLib.c,v 1.25 1998/02/27 01:34:10 jhill Exp
 * errSymLib.c
 *      Author:          Marty Kraimer
 *      Date:            6-1-90
 *
 *      Experimental Physics and Industrial Control System (EPICS)
 *
 *      Copyright 1991, the Regents of the University of California,
 *      and the University of Chicago Board of Governors.
 *
 *      This software was produced under  U.S. Government contracts:
 *      (W-7405-ENG-36) at the Los Alamos National Laboratory,
 *      and (W-31-109-ENG-38) at Argonne National Laboratory.
 *
 *      Initial development by:
 *              The Controls and Automation Group (AT-8)
 *              Ground Test Accelerator
 *              Accelerator Technology Division
 *              Los Alamos National Laboratory
 *
 *      Co-developed with
 *              The Controls and Computing Group
 *              Accelerator Systems Division
 *              Advanced Photon Source
 *              Argonne National Laboratory
 *
 * Modification Log: errSymLib.c
 * -----------------
 * .01  mm-dd-yy        rcz     See below for Creation/Merge
 ****	Merged Modification Logs:
 * Modification Log: errMessage.c
 * -----------------
 * .01  10-08-91	mrk	Allow logMsg or printF
 * .02  03-10-93	joh	expanded errMessage() to accept the
 *				same format string and variable
 *				length arguments as printf()	
 *				and renamed it errPrintf()
 * .03  03-11-93        joh     added __FILE__ and __LINE__ to errPrintf()
 *				created macro errMessage() that calls
 *				errPrintf with __FILE__ and __LINE__
 *				as arguments
 * errMessage.c - Handle error messages 
 ***************************************************************************
 * This must ultimately be replaced by a facility that allows remote
 * nodes access to the error messages. A message handling communication
 * task should be written that allows multiple remote nodes to request
 * notification of all error messages.
 * For now lets just print messages and last errno via logMsg or printf
 ***************************************************************************
 * Modification Log: errPrint.c
 * -----------------
 * .01  10-08-91	mrk	Allow logMsg or printf
 * .02  04-29-93	joh 	extra arg for errPrint()	
 * .03  04-29-93	joh 	errPrint() became errPrintStatus()	
 * .04	05-06-93	joh	errPrintStatus() get var args 
 *				for vprintf()
 * .05 	05-02-94	joh	errToLogMsg now defaults to TRUE
 *
 * Modification Log: errSymLib.c
 * -----------------
 * .01  09-04-93        rcz     Merged errMessage.c, errPrint.c, errSymFind.c
 *			rcz	into one file (errSymLib.c) and changed method
 *			rcz	of errSymTable lookup.
 * .02 	01-13-95	joh	call mprintf() instead of logMsg()	
 *				and eliminated errToLogMsg variable
 */

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

#ifdef vxWorks
#include <vxWorks.h>
#include <taskLib.h>
#include <types.h>
#include <symLib.h>
#include <errnoLib.h>

extern SYMTAB_ID  statSymTbl;

#endif

#define epicsExportSharedSymbols
#include "dbDefs.h"
#include "errMdef.h"
#include "errSymTbl.h"


#ifdef __STDC__
static unsigned short errhash(long errNum);
#else /*__STDC__*/
static unsigned short errhash();
#endif /*__STDC__*/


#ifdef vxWorks
#define MYERRNO	(errnoGet()&0xffff)
#else
#define MYERRNO	errno
#endif

typedef struct errnumnode {
    ELLNODE             node;
    long                errNum;
    struct errnumnode *hashnode;
    char               *message;
    long                pad;
} ERRNUMNODE;
#define NHASH 256


static ELLLIST errnumlist;
static ERRNUMNODE **hashtable;
static int initialized = FALSE;
extern ERRSYMTAB_ID errSymTbl;


/*Declare storage for errVerbose( defined in errMdef.h)*/
int errVerbose=0;



/****************************************************************
 * ERRSYMBLD
 *
 * Create the normal ell LIST of sorted error messages nodes
 * Followed by linked hash lists - that link together those
 * ell nodes that have a common hash number.
 *
 ***************************************************************/
int epicsShareAPI errSymBld()
{
    ERRSYMBOL      *errArray = errSymTbl->symbols;
    ELLLIST        *perrnumlist = &errnumlist;
    ERRNUMNODE     *perrNumNode = NULL;
    ERRNUMNODE     *pNextNode = NULL;
    ERRNUMNODE    **phashnode = NULL;
    int             i;
    int             modnum;
    unsigned short  hashInd;

    if(initialized) return(0);
    hashtable = (ERRNUMNODE**)calloc(NHASH, sizeof(ERRNUMNODE*));
    if(!hashtable) {
	printf("errSymBld: Can't allocate storage\n");
#ifdef vxWorks
	taskSuspend(0);
#else
	abort();
#endif
    }
    for (i = 0; i < errSymTbl->nsymbols; i++, errArray++) {
	modnum = errArray->errNum >> 16;
	if (modnum < 501) {
	    printf("errSymBld: ERROR - Module number in errSymTbl < 501 was Module=%lx Name=%s\n",
		errArray->errNum, errArray->name);
	    continue;
	}
	if ((errSymbolAdd(errArray->errNum, errArray->name))  <0 ) {
	    printf("errSymBld: ERROR - errSymbolAdd() failed \n");
	    continue;
	}
    }
    perrNumNode = (ERRNUMNODE *) ellFirst(perrnumlist);
    while (perrNumNode) {
	/* hash each perrNumNode->errNum */
	hashInd = errhash(perrNumNode->errNum);
	phashnode = (ERRNUMNODE**)&hashtable[hashInd];
	pNextNode = (ERRNUMNODE*) *phashnode;
	/* search for last node (NULL) of hashnode linked list */
	while (pNextNode) {
	    phashnode = &pNextNode->hashnode;
	    pNextNode = *phashnode;
	}
	*phashnode = perrNumNode;
	perrNumNode = (ERRNUMNODE *) ellNext((ELLNODE *) perrNumNode);
    }
    initialized = TRUE;
    return(0);
}



/****************************************************************
 * HASH
 * returns the hash index of errNum
****************************************************************/
#ifdef __STDC__
static
unsigned short errhash(long errNum)
#else
static
unsigned short errhash(errNum)
long errNum;
#endif /* __STDC__ */
{
unsigned short modnum;
unsigned short errnum;

	modnum = (unsigned short) (errNum >> 16);
	errnum = (unsigned short) (errNum & 0xffff);
	return((unsigned short)(((modnum - 500) * 20) + errnum) % NHASH);
}

/****************************************************************
 * ERRSYMBOLADD
 * adds symbols to the master errnumlist as compiled from errSymTbl.c
 ***************************************************************/
#ifdef __STDC__
int epicsShareAPI errSymbolAdd (long errNum,char *name)
#else
int epicsShareAPI errSymbolAdd (errNum,name)
long errNum;
char *name;
#endif /* __STDC__ */
{
    ELLLIST        *perrnumlist = &errnumlist;
    ERRNUMNODE     *pNew;

    pNew = (ERRNUMNODE*)calloc(1, sizeof(ERRNUMNODE));
    if(!pNew) {
	printf("errSymbolAdd: Can't allocate storage\n");
#ifdef vxWorks
	taskSuspend(0);
#else
	abort();
#endif
    }
    pNew->errNum = errNum;
    pNew->message = name;
    ellAdd(perrnumlist,(ELLNODE*)pNew);
    return(0);
}

/****************************************************************
 * UNIXSYMFIND
 ***************************************************************/
/* 
 * Use of sys_nerr and sys_errlist in this routine 
 * present portability problems
 *
 * ANSI strerror() provides this functionality 
 * so this is hopefully no longer needed
 * joh 10-02-96
 *
 */
#if 0 
#ifndef vxWorks
#ifdef __STDC__
int epicsShareAPI UnixSymFind(long status, char *pname, long *pvalue)
#else
int epicsShareAPI UnixSymFind(status, pname, pvalue)
    long            status;
    char           *pname;
    long           *pvalue;
#endif /* __STDC__ */
{
    if(!initialized) errSymBld();
    if (status >= sys_nerr || status < 1) {
	*pvalue = -1;
	return(0);
    }
    strcpy(pname, sys_errlist[status]);
    *pvalue = status;
    return(0);
}
#endif
#endif


/****************************************************************
 * MODSYMFIND
 ***************************************************************/
#ifdef __STDC__
int epicsShareAPI ModSymFind(long status, char *pname, long *pvalue)
#else
int epicsShareAPI ModSymFind(status, pname, pvalue)
    long            status;
    char           *pname;
    long           *pvalue;
#endif /* __STDC__ */
{
    unsigned short  modNum;
    unsigned short  hashInd;
    ERRNUMNODE *pNextNode;
    ERRNUMNODE **phashnode = NULL;

    if(!initialized) errSymBld();
    modNum = (unsigned short) (status >> 16);
    if (modNum < 501) {
	*pvalue = -1;
	return(0);
    }
    hashInd = errhash(status);
    phashnode = (ERRNUMNODE**)&hashtable[hashInd];
    pNextNode = *phashnode;
    while (pNextNode) {
        if (pNextNode->errNum == status) {
    	    strcpy(pname, pNextNode->message);
    	    *pvalue = status;
    	    return(0);
        }
	phashnode = &pNextNode->hashnode;
	pNextNode = *phashnode;
    }
    *pname  = 0;
    *pvalue = -1;
    return(0);
}

/****************************************************************
 * ERRSYMFIND
 ***************************************************************/
#ifdef __STDC__
int epicsShareAPI errSymFind(long status, char *name)
#else
/* errSymFind - Locate error symbol */
int epicsShareAPI errSymFind(status, name)
    long            status;
    char           *name;
#endif /* __STDC__ */
{
    long            value;
#ifdef vxWorks
    unsigned char   type;
#endif
    unsigned short  modnum;

    if (!initialized) errSymBld();

    modnum = (unsigned short) (status >> 16);
    if (modnum <= 500)
#ifdef vxWorks
	symFindByValue((SYMTAB_ID)statSymTbl, status, name,(int*) &value, (SYM_TYPE*)&type);
#else
	{
		const char *pStr = strerror(status);
		if (pStr) {
			strcpy(name,strerror(status));
			value = status;
		}
		else {
			sprintf(name,"err = %ld", status);
		}
	}
#endif
    else
	ModSymFind(status, name, &value);
    if (value != status)
	return (-1);
    else
	return (0);
}


/****************************************************************
 * errSymDump
 ***************************************************************/
#ifdef __STDC__
void epicsShareAPI errSymDump()
#else
void epicsShareAPI errSymDump()
#endif /* __STDC__ */
{
ERRNUMNODE    **phashnode = NULL;
ERRNUMNODE     *pNextNode;
int i;
int modnum;
int errnum;
int msgcount;
int firstTime;

	if (!initialized) errSymBld();

	msgcount = 0;
	printf("errSymDump: number of hash slots=%d\n", NHASH);		
	for ( i=0; i < NHASH; i++) {
	    phashnode = &hashtable[i];
	    pNextNode = *phashnode;
	    firstTime=1;
		while (pNextNode) {
		    if (firstTime) {
		        printf("HASHNODE=%d\n", i);		
		        firstTime=0;
		    }
		    modnum = pNextNode->errNum >> 16;
		    errnum = pNextNode->errNum & 0xffff;
		    printf("\tmod %d num %d \"%s\"\n"
			, modnum , errnum , pNextNode->message);
		    msgcount++;
		    phashnode = &pNextNode->hashnode;
		    pNextNode = *phashnode;
		}
	}
	printf("\nerrSymDump: total number of error messages=%d\n", msgcount);		
}


/****************************************************************
 * errSymTestPrint
 ***************************************************************/
#ifdef __STDC__
void epicsShareAPI errSymTestPrint(long errNum)
#else
void epicsShareAPI errSymTestPrint(errNum)
long errNum;
#endif /* __STDC__ */
{
    char            message[256];
    unsigned short modnum;
    unsigned short errnum;

    if (!initialized) errSymBld();

    message[0] = '\0';
    modnum = (unsigned short) (errNum >> 16);
    errnum = (unsigned short) (errNum & 0xffff);
    if (modnum < 501) {
        printf("Usage:  errSymTestPrint(long errNum) \n");
        printf("errSymTestPrint: module number < 501 \n");
        return;
    }
    errSymFind(errNum, message);
    if ( message[0] == '\0' ) return;
    printf("module %hu number %hu message=\"%s\"\n",
		modnum, errnum, message);
    return;
}

/****************************************************************
 * ERRSYMTEST
****************************************************************/
#ifdef __STDC__
void epicsShareAPI errSymTest(unsigned short modnum, unsigned short begErrNum, unsigned short endErrNum)
#else
void epicsShareAPI errSymTest(modnum, begErrNum, endErrNum)
unsigned short modnum;
unsigned short begErrNum;
unsigned short endErrNum;
#endif /* __STDC__ */
{
    long            errNum;
    unsigned short  errnum;

    if(!initialized) errSymBld();
    if (modnum < 501)
	return;

    /* print range of error messages */
    for (errnum = begErrNum; errnum <= endErrNum; errnum++) {
	errNum = modnum << 16;
	errNum |= (errnum & 0xffff);
	errSymTestPrint(errNum);
    }
}
