/* epicsAssert.h,v 1.4.10.2 2000/11/08 20:24:17 jhill Exp
 *      
 *	EPICS assert  
 *
 *      Author:         Jeffrey O. Hill 
 *      Date:           022795 
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
 * Modification Log:
 * -----------------
 */

#ifndef assertEPICS 
#define assertEPICS 

#ifdef __cplusplus
extern "C" {
#endif

#include "shareLib.h"

#undef assert

#ifdef NDEBUG
#	define assert(ignore)  ((void) 0)
#else /* NDEBUG */

#if defined(__STDC__) || defined(__cplusplus)

epicsShareFunc extern void epicsShareAPI 
	epicsAssert (const char *pFile, const unsigned line, 
			const char *pMsg, const char *pAuthorName);

#else /*__STDC__ or __cplusplus*/

	epicsShareFunc extern void epicsShareAPI epicsAssert ();

#endif /*__STDC__ or __cplusplus*/

#if (defined(__STDC__) || defined(__cplusplus)) && !defined(VAXC)

#ifdef epicsAssertAuthor
#define assert(exp) \
( (exp) ? ( void ) 0 : epicsAssert( __FILE__, __LINE__, #exp, epicsAssertAuthor ) )
#else /* epicsAssertAuthor */
#define assert(exp) \
( (exp) ? ( void ) 0 : epicsAssert( __FILE__, __LINE__, #exp, 0 ) )
#endif /* epicsAssertAuthor */

#else /*__STDC__ or __cplusplus*/


#ifdef epicsAssertAuthor
#define assert(exp) \
( (exp) ? ( void ) : epicsAssert( __FILE__, __LINE__, "", epicsAssertAuthor ) )
#else /* epicsAssertAuthor */
#define assert(exp) \
( (exp) ? ( void ) : epicsAssert( __FILE__, __LINE__, "", 0 ) )
#endif /* epicsAssertAuthor */

#endif /* (__STDC__ or __cplusplus) and not VAXC */

#endif  /* NDEBUG */

#ifdef __cplusplus
}
#endif


#endif /* assertEPICS */

