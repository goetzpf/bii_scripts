/* macUtil.c,v 1.3.8.2 1999/12/15 21:28:35 jba Exp
 *
 * Implementation of utility macro substitution library (macLib)
 *
 * William Lupton, W. M. Keck Observatory
 */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define epicsExportSharedSymbols
#include "macLib.h"

/*
 * Parse macros definitions in "a=xxx,b=yyy" format and convert them to
 * a contiguously allocated array pointers to names and values, and the
 * name and value strings, terminated with two NULL pointers. Quotes
 * and escapes are honored but only removed from macro names (not
 * values)
 *
 * Doesn't yet use handle (so uses default special characters)
 */
long				/* #defns encountered; <0 = ERROR */
epicsShareAPI macParseDefns(
    MAC_HANDLE	*handle,	/* opaque handle; can be NULL if default */
				/* special characters are to be used */

    char	*defns,		/* macro definitions in "a=xxx,b=yyy" */
				/* format */

    char	**pairs[] )	/* address of variable to receive pointer */
				/* to NULL-terminated array of {name, */
				/* value} pair strings; all storage is */
				/* allocated contiguously */
{
    long i;
    long num;
    long quote;
    long escape;
    long nbytes;
    char **ptr;
    char **end;
    long *del;
    char *memCp, **memCpp;
    char *c, *s, *d, **p;
    enum { preName, inName, preValue, inValue } state;

    /* debug output */
    if ( handle->debug & 1 )
	printf( "macParseDefns( %s )\n", defns );

    /* allocate temporary pointer arrays; in worst case they need to have
       as many entries as the length of the defns string */
    ptr = ( char ** ) malloc( strlen( defns ) * sizeof( char * ) );
    end = ( char ** ) malloc( strlen( defns ) * sizeof( char * ) );
    del = ( long *  ) malloc( strlen( defns ) * sizeof( long   ) );
    if ( ptr == NULL || end == NULL  || del == NULL ) goto error;

    /* go through definitions, noting pointers to starts and ends of macro
       names and values; honor quotes and escapes; ignore white space
       around assignment and separator characters */
    num    = 0;
    del[0] = FALSE;
    quote  = 0;
    state  = preName;
    for ( c = defns; *c != '\0'; c++ ) {

	/* handle quotes */
	if ( quote )
	    quote = ( *c == quote ) ? 0 : quote;
	else if ( *c == '\'' || *c == '"' )
	    quote = *c;

	/* handle escapes (pointer incremented below) */
	escape = ( *c == '\\' && *( c + 1 ) != '\0' );

	switch ( state ) {
	  case preName:
	    if ( !quote && !escape && ( isspace( *c ) || *c == ',' ) ) break;
	    ptr[num] = c;
	    state = inName;
	    /* fall through (may be empty name) */

	  case inName:
	    if ( quote || escape || ( *c != '=' && *c != ',' ) ) break;
	    end[num] = c;
	    while ( end[num] > ptr[num] && isspace( *( end[num] - 1 ) ) )
		end[num]--;
	    num++;
	    del[num] = FALSE;
	    state = preValue;
	    if ( *c != ',' ) break;
	    del[num] = TRUE;
	    /* fall through (','; will delete) */

	  case preValue:
	    if ( !quote && !escape && isspace( *c ) ) break;
	    ptr[num] = c;
	    state = inValue;
	    /* fall through (may be empty value) */

	  case inValue:
	    if ( quote || escape || *c != ',' ) break;
	    end[num] = c;
	    while ( end[num] > ptr[num] && isspace( *( end[num] - 1 ) ) )
		end[num]--;
	    num++;
	    del[num] = FALSE;
	    state = preName;
	    break;
	}

	/* if this was escape, increment pointer now (couldn't do
	   before because could have ignored escape at start of name
	   or value) */
	if ( escape ) c++;
    }

    /* tidy up from state at end of string */
    switch ( state ) {
      case preName:
	break;
      case inName:
	end[num] = c;
	while ( end[num] > ptr[num] && isspace( *( end[num] - 1 ) ) )
	    end[num]--;
	num++;
	del[num] = TRUE;
      case preValue:
	ptr[num] = c;
      case inValue:
	end[num] = c;
	while ( end[num] > ptr[num] && isspace( *( end[num] - 1 ) ) )
	    end[num]--;
	num++;
	del[num] = FALSE;
    }

    /* debug output */
    if ( handle != NULL && handle->debug & 4 )
	for ( i = 0; i < num; i += 2 )
	    printf( "[%ld] %.*s = [%ld] %.*s (%s) (%s)\n",
		    (long) (end[i+0] - ptr[i+0]), (int) (end[i+0] - ptr[i+0]), ptr[i+0],
		    (long) (end[i+1] - ptr[i+1]), (int) (end[i+1] - ptr[i+1]), ptr[i+1],
		    del[i+0] ? "del" : "nodel",
		    del[i+1] ? "del" : "nodel" );

    /* calculate how much memory to allocate: pointers followed by
       strings */
    nbytes = ( num + 2 ) * sizeof( char * );
    for ( i = 0; i < num; i++ )
	nbytes += end[i] - ptr[i] + 1;

    /* allocate memory and set returned pairs pointer */
    memCp = malloc( nbytes );
    if ( memCp == NULL ) goto error;
    memCpp = ( char ** ) memCp;
    *pairs = memCpp;

    /* copy pointers and strings (memCpp accesses the pointer section
       and memCp accesses the string section) */
    memCp += ( num + 2 ) * sizeof( char * );
    for ( i = 0; i < num; i++ ) {

	/* if no '=' followed the name, macro will be deleted */
	if ( del[i] )
	    *memCpp++ = NULL;
	else
	    *memCpp++ = memCp;

	/* copy value regardless of the above */
	strncpy( memCp, ptr[i], end[i] - ptr[i] );
	memCp += end[i] - ptr[i];
	*memCp++ = '\0';
    }

    /* add two NULL pointers */
    *memCpp++ = NULL;
    *memCpp++ = NULL;

    /* remove quotes and escapes from names in place (unlike values, they
       will not be re-parsed) */
    for ( p = *pairs; *p != NULL; p += 2 ) {
	quote = 0;
	for ( s = d = *p; *s != '\0'; s++ ) {

	    /* quotes are not copied */
	    if ( quote ) {
		if ( *s == quote ) {
		    quote = 0;
		    continue;
		}
	    }
	    else if ( *s == '\'' || *s == '"' ) {
		quote = *s;
		continue;
	    }

	    /* escapes are not copied but next character is */
	    if ( *s == '\\' && *( s + 1 ) != '\0' )
		s++;

	    /* others are copied */
	    *d++ = *s;
	}

	/* need to terminate destination */
	*d++ = '\0';
    }

    /* free workspace */
    free( ptr );
    free( end );
    free( ( char * ) del );

    /* debug output */
    if ( handle->debug & 1 )
	printf( "macParseDefns() -> %ld\n", num / 2 );

    /* success exit; return number of definitions */
    return num / 2;

    /* error exit */
error:
    macErrMessage0( -1, "macParseDefns: failed to allocate memory" );
    if ( ptr != NULL ) free( ptr );
    if ( end != NULL ) free( end );
    if ( del != NULL ) free( ( char * ) del );
    *pairs = NULL;
    return -1;
}

/*
 * Install an array of name / value pairs as macro definitions. The
 * array should have an even number of elements followed by at least
 * one (preferably two) NULL pointers 
 */
long				/* #macros defined; <0 = ERROR */
epicsShareAPI macInstallMacros(
    MAC_HANDLE	*handle,	/* opaque handle */

    char	*pairs[] )	/* pointer to NULL-terminated array of */
				/* {name,value} pair strings; a NULL */
				/* value implies undefined; a NULL */
				/* argument implies no macros */
{
    long n;
    char **p;

    /* debug output */
    if ( handle->debug & 1 )
	printf( "macInstallMacros( %s, %s, ... )\n",
		pairs && pairs[0] ? pairs[0] : "NULL",
		pairs && pairs[1] ? pairs[1] : "NULL" );

    /* go through array defining macros */
    for ( n = 0, p = pairs; p != NULL && p[0] != NULL; n++, p += 2 ) {
	if ( macPutValue( handle, p[0], p[1] ) < 0 )
	    return -1;
    }

    /* debug output */
    if ( handle->debug & 1 )
	printf( "macInstallMacros() -> %ld\n", n );

    /* return number of macros defined */
    return n;
}

/*
 * macUtil.c,v
 * Revision 1.3.8.2  1999/12/15 21:28:35  jba
 * Second try at fixing cvs log comments.
 *
 * Revision 1.3.8.1  1999/12/15 21:13:32  jba
 * Fixed cvs comments.
 *
 * Revision 1.3  1997/05/01 19:57:35  jhill
 * updated dll keywords
 *
 * Revision 1.2  1996/09/16 21:07:11  jhill
 * fixed warnings
 *
 * Revision 1.1  1996/07/10 14:49:55  mrk
 * added macLib
 *
 * Revision 1.6  1996/06/26  09:43:19  wlupton
 * first released version
 *
 */
