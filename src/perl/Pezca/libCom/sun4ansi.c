/* sun4ansi.c,v 1.2 1995/02/21 17:53:22 jba Exp */
/*
 *  To get strtoul and strerror a sunos system must have
 *  /usr/lang/SC2.0.1patch installed. See CONFIG_SITE.Unix.sun4.
 *  Andrew Johnson has created this file named sun4ansi.c containg code
 *  for strtoul and strerror which is available in the base/libCom
 *  directory so that any site that needs it can add it to the Makefile.Unix.
 */


#ifdef SUNOS4

/*
 * sun4ansi.c,v
 * Revision 1.2  1995/02/21 17:53:22  jba
 * Added comments.
 *
 * Revision 1.1  1995/02/17  15:09:56  jba
 * Initial version
 *
 * Revision 1.1  1995/01/11  10:34:21  anj
 * Added sun4ansi.c for those without sun4 ACC.
 *
 * 
 * 
 * Routines which are needed but SunOS 4.x doesn't provide.
 * These definitions obtained from GNU libiberty directory.
 * Note that Sun's Ansi C compiler provides these routines,
 * so there ought to be a way of excluding this file if you
 * have that...
 *
 */

/*
 * strtol : convert a string to long.
 *
 * Andy Wilson, 2-Oct-89.
 */

#include <errno.h>
#include <ctype.h>
#include <stdio.h>
#include <limits.h>

extern int errno;
extern int sys_nerr;
extern char *sys_errlist[];


unsigned long
strtoul(const char *s, char **ptr, int base)
{
  unsigned long total = 0, tmp = 0;
  unsigned digit;
  const char *start=s;
  int did_conversion=0;
  int negate = 0;

  if (s==NULL)
    {
      errno = ERANGE;
      if (!ptr)
	*ptr = (char *)start;
      return 0L;
    }

  while (isspace(*s))
    s++;
  if (*s == '+')
    s++;
  else if (*s == '-')
    s++, negate = 1;
  if (base==0 || base==16) /*  the 'base==16' is for handling 0x */
    {
      /*
       * try to infer base from the string
       */
      if (*s != '0')
        tmp = 10;	/* doesn't start with 0 - assume decimal */
      else if (s[1] == 'X' || s[1] == 'x')
	tmp = 16, s += 2; /* starts with 0x or 0X - hence hex */
      else
	tmp = 8;	/* starts with 0 - hence octal */
      if (base==0)
	base = (int)tmp;
    }

  while ( digit = *s )
    {
      if (digit >= '0' && digit < ('0'+base))
	digit -= '0';
      else
	if (base > 10)
	  {
	    if (digit >= 'a' && digit < ('a'+(base-10)))
	      digit = digit - 'a' + 10;
	    else if (digit >= 'A' && digit < ('A'+(base-10)))
	      digit = digit - 'A' + 10;
	    else
	      break;
	  }
	else
	  break;
      did_conversion = 1;
      tmp = (total * base) + digit;
      if (tmp < total)	/* check overflow */
	{
	  errno = ERANGE;
	  if (ptr != NULL)
	    *ptr = (char *)s;
	  return (ULONG_MAX);
	}
      total = tmp;
      s++;
    }
  if (ptr != NULL)
    *ptr = (char *) ((did_conversion) ? (char *)s : (char *)start);
  return negate ? -total : total;
}

/*
 * strerror
 *
 * convert an error number into a string
 */

char *
strerror (errnoval)
  int errnoval;
{
  char *msg;
  static char buf[32];

  if ((errnoval < 0) || (errnoval >= sys_nerr))
    {
      /* Out of range, just return NULL */
      msg = NULL;
    }
  else if ((sys_errlist == NULL) || (sys_errlist[errnoval] == NULL))
    {
      /* In range, but no sys_errlist or no entry at this index. */
      sprintf (buf, "Error %d", errnoval);
      msg = buf;
    }
  else
    {
      /* In range, and a valid message.  Just return the message. */
      msg = sys_errlist[errnoval];
    }
  
  return (msg);
}

#endif
