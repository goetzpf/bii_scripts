/* freeListLib.c,v 1.9 1998/09/29 14:55:52 mrk Exp */
/* Author:  Marty Kraimer Date:    04-19-94 */
/*****************************************************************
                          COPYRIGHT NOTIFICATION
*****************************************************************

THE FOLLOWING IS A NOTICE OF COPYRIGHT, AVAILABILITY OF THE CODE,
AND DISCLAIMER WHICH MUST BE INCLUDED IN THE PROLOGUE OF THE CODE
AND IN ALL SOURCE LISTINGS OF THE CODE.
 
(C)  COPYRIGHT 1993 UNIVERSITY OF CHICAGO
 
Argonne National Laboratory (ANL), with facilities in the States of 
Illinois and Idaho, is owned by the United States Government, and
operated by the University of Chicago under provision of a contract
with the Department of Energy.

Portions of this material resulted from work developed under a U.S.
Government contract and are subject to the following license:  For
a period of five years from March 30, 1993, the Government is
granted for itself and others acting on its behalf a paid-up,
nonexclusive, irrevocable worldwide license in this computer
software to reproduce, prepare derivative works, and perform
publicly and display publicly.  With the approval of DOE, this
period may be renewed for two additional five year periods. 
Following the expiration of this period or periods, the Government
is granted for itself and others acting on its behalf, a paid-up,
nonexclusive, irrevocable worldwide license in this computer
software to reproduce, prepare derivative works, distribute copies
to the public, perform publicly and display publicly, and to permit
others to do so.

*****************************************************************
                                DISCLAIMER
*****************************************************************

NEITHER THE UNITED STATES GOVERNMENT NOR ANY AGENCY THEREOF, NOR
THE UNIVERSITY OF CHICAGO, NOR ANY OF THEIR EMPLOYEES OR OFFICERS,
MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL
LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR
USEFULNESS OF ANY INFORMATION, APPARATUS, PRODUCT, OR PROCESS
DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY
OWNED RIGHTS.  

*****************************************************************
LICENSING INQUIRIES MAY BE DIRECTED TO THE INDUSTRIAL TECHNOLOGY
DEVELOPMENT CENTER AT ARGONNE NATIONAL LABORATORY (708-252-2000).
 *
 * Modification Log:
 * -----------------
 * .01  04-19-94	mrk	Initial Implementation
 * .02  03-28-97	joh	added freeListItemAvail() function	
 */

#ifdef vxWorks
#include <vxWorks.h>
#include <taskLib.h>
#include "fast_lock.h"
#endif

#include <string.h>
#include <stdlib.h>
#include <stddef.h>

#define epicsExportSharedSymbols
#include "freeList.h"
#include "adjustment.h"

typedef struct allocMem {
    struct allocMem	*next;
    void		*memory;
}allocMem;
typedef struct {
    int		size;
    int		nmalloc;
    void	*head;
    allocMem	*mallochead;
    size_t	nBlocksAvailable;
#ifdef vxWorks
    FAST_LOCK	lock;
#endif
}FREELISTPVT;

epicsShareFunc void epicsShareAPI 
	freeListInitPvt(void **ppvt,int size,int nmalloc)
{
    FREELISTPVT	*pfl;

    pfl = (void *)calloc((size_t)1,(size_t)sizeof(FREELISTPVT));
    if(!pfl) {
#ifdef vxWorks
	taskSuspend(0);
#else
	abort();
#endif
    }
    pfl->size = adjustToWorstCaseAlignment(size);
    pfl->nmalloc = nmalloc;
    pfl->head = NULL;
    pfl->mallochead = NULL;
    pfl->nBlocksAvailable = 0u;
#ifdef vxWorks
    FASTLOCKINIT(&pfl->lock);
#endif
    *ppvt = (void *)pfl;
    return;
}

epicsShareFunc void * epicsShareAPI freeListCalloc(void *pvt)
{
    FREELISTPVT *pfl = pvt;
    void	*ptemp;

    ptemp = freeListMalloc(pvt);
    if(ptemp) memset((char *)ptemp,0,pfl->size);
    return(ptemp);
}

epicsShareFunc void * epicsShareAPI freeListMalloc(void *pvt)
{
    FREELISTPVT *pfl = pvt;
    void	*ptemp;
    void	**ppnext;
    allocMem	*pallocmem;
    int		i;

#ifdef vxWorks
    FASTLOCK(&pfl->lock);
#endif
    ptemp = pfl->head;
    if(ptemp==0) {
	ptemp = (void *)malloc(pfl->nmalloc*pfl->size);
	if(ptemp==0) {
#ifdef vxWorks
	    FASTUNLOCK(&pfl->lock);
#endif
	    return(0);
	}
	pallocmem = (allocMem *)calloc(1,sizeof(allocMem));
	if(pallocmem==0) {
#ifdef vxWorks
	    FASTUNLOCK(&pfl->lock);
#endif
	    free(ptemp);
	    return(0);
	}
	pallocmem->memory = ptemp;
	if(pfl->mallochead)
	    pallocmem->next = pfl->mallochead;
	pfl->mallochead = pallocmem;
	for(i=0; i<pfl->nmalloc; i++) {
	    ppnext = ptemp;
	    *ppnext = pfl->head;
	    pfl->head = ptemp;
	    ptemp = ((char *)ptemp) + pfl->size;
	}
	ptemp = pfl->head;
        pfl->nBlocksAvailable += pfl->nmalloc;
    }
    ppnext = pfl->head;
    pfl->head = *ppnext;
    pfl->nBlocksAvailable--;
#ifdef vxWorks
    FASTUNLOCK(&pfl->lock);
#endif
    return(ptemp);
}

epicsShareFunc void epicsShareAPI freeListFree(void *pvt,void*pmem)
{
    FREELISTPVT	*pfl = pvt;
    void	**ppnext;

#ifdef vxWorks
    FASTLOCK(&pfl->lock);
#endif
    ppnext = pmem;
    *ppnext = pfl->head;
    pfl->head = pmem;
    pfl->nBlocksAvailable++;
#ifdef vxWorks
    FASTUNLOCK(&pfl->lock);
#endif
}

epicsShareFunc void epicsShareAPI freeListCleanup(void *pvt)
{
    FREELISTPVT *pfl = pvt;
    allocMem	*phead;
    allocMem	*pnext;

    phead = pfl->mallochead;
    while(phead) {
	pnext = phead->next;
	free(phead->memory);
	free(phead);
	phead = pnext;
    }
    free(pvt);
}

epicsShareFunc size_t epicsShareAPI freeListItemsAvail(void *pvt)
{
    FREELISTPVT *pfl = pvt;
    return pfl->nBlocksAvailable;
}

