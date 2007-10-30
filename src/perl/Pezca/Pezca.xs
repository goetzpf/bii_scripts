/*
  This software is copyrighted by the BERLINER SPEICHERRING
  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
  The following terms apply to all files assiciated with the software.

  BESSY hereby grants permission to use, copy and modify this
  software and its documentation for non-commercial, educational or
  research purposes provided that existing copyright notices are
  retained in all copies.

  The receiver of the software provides BESSY with all enhancements,
  including complete translations, made by the receiver.

  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN
  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  BESSY SPECIFICALLY DISPLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
  UPDATES, ENHANCEMENTS OF MODIFICTAIONS.
*/

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <ctype.h>  /* toupper */

#include <stdio.h>  /* printf, only for debugging */

#include <tsDefs.h>
#include <cadef.h>
#include <ezca.h>

/* typedef char stringy[80]; */

#define STRINGBUFSIZE 80
/* Buffer size increased by Sergey 2003/07/22 -- according to Mark Rivers */
/* #define LISTBUFSIZE 8192 */
#define LISTBUFSIZE 16000

static int stricmp(char *s1, char *s2)
  { register char c1, c2;

    for(; (*s1!=0) || (*s2!=0); s1++, s2++)
      { c1= toupper(*s1); c2= toupper(*s2);
        if (c1<c2)
          return(-1);
        if (c1>c2)
          return(1);
      };
    return(0);
  };

static int get_type(char *type, int *etype, int *eshift)
  { /* recognized: byte, char, uchar
                   short, ushort,
                   long, ulong, int, uint,
                   float,
                   double,
                   string */
    if (0==stricmp(type, "BYTE"))
      { *etype= ezcaByte;   *eshift=0; return(1); }
    if (0==stricmp(type, "CHAR"))
      { *etype= ezcaByte;   *eshift=0; return(1); }
    if (0==stricmp(type, "UCHAR"))
      { *etype= ezcaByte;   *eshift=0; return(1); }

    if (0==stricmp(type, "SHORT"))
      { *etype= ezcaShort;  *eshift=1; return(1); }
    if (0==stricmp(type, "USHORT"))
      { *etype= ezcaShort;  *eshift=1; return(1); }

    if (0==stricmp(type, "LONG"))
      { *etype= ezcaLong;   *eshift=2; return(1); }
    if (0==stricmp(type, "ULONG"))
      { *etype= ezcaLong;   *eshift=2; return(1); }
    if (0==stricmp(type, "INT"))
      { *etype= ezcaLong;   *eshift=2; return(1); }
    if (0==stricmp(type, "UINT"))
      { *etype= ezcaLong;   *eshift=2; return(1); }

    if (0==stricmp(type, "FLOAT"))
      { *etype= ezcaFloat;  *eshift=2; return(1); }

    if (0==stricmp(type, "DOUBLE"))
      { *etype= ezcaDouble; *eshift=3; return(1); }

    if (0==stricmp(type, "STRING"))
      { *etype= ezcaString; *eshift=0; return(1); }
    
    return(0); /* error: unknown type */
  }


MODULE = Pezca          PACKAGE = Pezca


  # Get: compability with old definition, in the new definition, the
  # error-code comes first in the list

void
GetDouble(channel)
        char* channel
        ALIAS:
          Pezca::Get = 1
        PROTOTYPE: $
        PPCODE:
        double r;
        int    ret;
        ret= ezcaGet(channel,ezcaDouble, 1, &r);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 2);
            if (ix==0) /* function was called by it's original name */
              { PUSHs(sv_2mortal(newSViv(ret)));
                PUSHs(sv_2mortal(newSVnv(r)));
              }
            else       /* function was called as "Pezca::Get(..)" */
              { PUSHs(sv_2mortal(newSVnv(r)));
                PUSHs(sv_2mortal(newSViv(ret)));
              }
          }

void
GetList(channel,type="",no=0)
        char* channel
        char* type
        int   no
        PROTOTYPE: $;$$
        PREINIT:
        char   buf[LISTBUFSIZE];
        int    etype;
        int    eshift;
        int    ret=0;
        int    i;
        PPCODE:
        /* recognized type:
          "byte","char","short","long","int","float","double","string"
           only the first two characters are evaluated (runtime effeciency)*/

        if (!get_type(type, &etype, &eshift))
          { /* unknown type */
            fprintf(stderr, "Pezca: unknown type string: \"%s\"\n",type);
            ret= -1;
            EXTEND(sp, 1); /* room for 1 element on the stack */
            PUSHs(sv_2mortal(newSViv(ret)));
            return;
          }

        if (no==0)
          { ret= ezcaGetNelem(channel, &no);
            if (ret!=0)
              { EXTEND(sp, 1); /* room for 1 element on the stack */
                PUSHs(sv_2mortal(newSViv(ret)));
                return;
              }
          }

        if ((no << eshift)>LISTBUFSIZE)
          no= LISTBUFSIZE >> eshift;

        ret= ezcaGet(channel,etype, no, buf);
        if (ret!=0)
          { EXTEND(sp, 1); /* room for 1 element on the stack */
            PUSHs(sv_2mortal(newSViv(ret)));
            return;
          }

        EXTEND(sp, no+1); /* room for no+1 elements on the stack */
        PUSHs(sv_2mortal(newSViv(ret)));
        switch(etype)
          { case ezcaByte:
                       { char *p= buf;

                         for(i=no;i>0;i--,p++)
                           PUSHs(sv_2mortal(newSViv((int)(*p))));
                         break;
                       }
            case ezcaShort:
                       { short *p= (short*)buf;

                         for(i=no;i>0;i--,p++)
                           PUSHs(sv_2mortal(newSViv((int)(*p))));
                         break;
                       }
            case ezcaLong:
                       { long *p= (long*)buf;

                         for(i=no;i>0;i--,p++)
                           PUSHs(sv_2mortal(newSViv(*p)));
                         break;
                       }
            case ezcaFloat:
                       { float *p= (float*)buf;

                         for(i=no;i>0;i--,p++)
                           PUSHs(sv_2mortal(newSVnv((double)(*p))));
                         break;
                       }
            case ezcaDouble:
                       { double *p= (double*)buf;

                         for(i=no;i>0;i--,p++)
                           PUSHs(sv_2mortal(newSVnv(*p)));
                         break;
                       }
            case ezcaString:
                       { char *p= buf;
                         char *e;

                         for(i=no;i>0;i--,p++)
                           { for(e=p;*e!=0;e++); /* DANGEROUS */
                             PUSHs(sv_2mortal(newSVpv(p,0)));
                             p= e+1;
                           };
                         break;
                       }
          }

  # GetS: compability with old definition, in the new definition, the
  # error-code comes first in the list */

void
GetString(channel)
        char* channel
        ALIAS:
          Pezca::GetS = 1
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        char   st[STRINGBUFSIZE];
        int    ret;
        ret= ezcaGet(channel,ezcaString, 1, st);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 2);
            if (ix==0) /* function was called by it's original name */
              { PUSHs(sv_2mortal(newSViv(ret)));
                PUSHs(sv_2mortal(newSVpv(st,0)));
              }
            else       /* function was called as "Pezca::GetS(..)" */
              { PUSHs(sv_2mortal(newSVpv(st,0)));
                PUSHs(sv_2mortal(newSViv(ret)));
              }
          }

  # Put: compability with the old name

int
PutDouble(channel,val)
        char* channel
        double val
        ALIAS:
          Pezca::Put = 1
        PROTOTYPE: $$
        CODE:
        RETVAL=ezcaPut(channel,ezcaDouble, 1, &val);
        OUTPUT:
        RETVAL

int
PutDoubleOldCa(channel,val)
        char* channel
        double val
        ALIAS:
          Pezca::PutOldCa = 1
        PROTOTYPE: $$
        CODE:
        RETVAL=ezcaPutOldCa(channel,ezcaDouble, 1, &val);
        OUTPUT:
        RETVAL

int
PutList(channel,type,...)
        char*  channel
        char*  type
        PROTOTYPE: $$@
        PREINIT:
        char   buf[LISTBUFSIZE];
        int    etype;
        int    eshift;
        int    no=0;
        int    i;
        CODE:
        /* recognized type:
          "byte","char","short","long","int","float","double"
           only the first two characters are evaluated (runtime effeciency)*/

        if (!get_type(type, &etype, &eshift))
          { fprintf(stderr, "Pezca: unknown type string: \"%s\"\n",type);
            RETVAL= -1; 
          }
        else
          {

            no= items-2;
            if ((no << eshift)>LISTBUFSIZE)
              no= LISTBUFSIZE >> eshift;

            switch(etype)
              { case ezcaByte:
                           { char *p= buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (char)SvIV(ST(i)); }
                             break;
                           }
                case ezcaShort:
                           { short *p= (short*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (short)SvIV(ST(i)); }
                             break;
                           }
                case ezcaLong:
                           { long *p= (long*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (long)SvIV(ST(i)); }
                             break;
                           }
                case ezcaFloat:
                           { float *p= (float*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (float)SvNV(ST(i)); }
                             break;
                           }
                case ezcaDouble:
                           { double *p= (double*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (double)SvNV(ST(i)); }
                             break;
                           }
                /* the following is DANGEROUS, not tested and currently
                   not used */
                case ezcaString:
                           { char *p= buf;

                             for(i=2;i<items;i++)
                               { unsigned len;
                                 char *src= (char*)(SvPV(ST(i),len));
                                 strcpy(p, src);/*DANGEROUS*/
                                 p+= (len+1);
                               }
                             break;
                           }
              };

          }
        RETVAL=ezcaPut(channel,etype, no, buf);
        OUTPUT:
        RETVAL

int
PutListOldCa(channel,type,...)
        char*  channel
        char*  type
        PROTOTYPE: $$@
        PREINIT:
        char   buf[LISTBUFSIZE];
        int    etype;
        int    eshift;
        int    no=0;
        int    i;
        CODE:
        /* recognized type:
          "byte","char","short","long","int","float","double"
           only the first two characters are evaluated (runtime effeciency)*/

        if (!get_type(type, &etype, &eshift))
          { fprintf(stderr, "Pezca: unknown type string: \"%s\"\n",type);
            RETVAL= -1; 
          }
        else
          {

            no= items-2;
            if ((no << eshift)>LISTBUFSIZE)
              no= LISTBUFSIZE >> eshift;

            switch(etype)
              { case ezcaByte:
                           { char *p= buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (char)SvIV(ST(i)); }
                             break;
                           }
                case ezcaShort:
                           { short *p= (short*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (short)SvIV(ST(i)); }
                             break;
                           }
                case ezcaLong:
                           { long *p= (long*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (long)SvIV(ST(i)); }
                             break;
                           }
                case ezcaFloat:
                           { float *p= (float*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (float)SvNV(ST(i)); }
                             break;
                           }
                case ezcaDouble:
                           { double *p= (double*)buf;

                             for(i=2;i<items;i++)
                               { *(p++)= (double)SvNV(ST(i)); }
                             break;
                           }
                /* the following is DANGEROUS, not tested and currently
                   not used */
                case ezcaString:
                           { char *p= buf;

                             for(i=2;i<items;i++)
                               { unsigned len;
                                 char *src= (char*)(SvPV(ST(i),len));
                                 strcpy(p, src);/*DANGEROUS*/
                                 p+= (len+1);
                               }
                             break;
                           }
              };

          }
        RETVAL=ezcaPutOldCa(channel,etype, no, buf);
        OUTPUT:
        RETVAL


  # PutS: compability with the old naming-Scheme

int
PutString(channel,val)
        char* channel
        char* val
        ALIAS:
          Pezca::PutS = 1
        PROTOTYPE: $$
        CODE:
        RETVAL=ezcaPut(channel,ezcaString, 1, val);
        OUTPUT:
        RETVAL

int
PutStringOldCa(channel,val)
        char* channel
        char* val
        ALIAS:
          Pezca::PutSOldCa = 1
        PROTOTYPE: $$
        CODE:
        RETVAL=ezcaPutOldCa(channel,ezcaString, 1, val);
        OUTPUT:
        RETVAL

void
GetControlLimits(channel)
        char *channel
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        int  ret;
        double low,high;
        ret= ezcaGetControlLimits(channel, &low, &high);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 3);
            PUSHs(sv_2mortal(newSViv(ret)));
            PUSHs(sv_2mortal(newSVnv(low)));
            PUSHs(sv_2mortal(newSVnv(high)));
          }

void
GetGraphicLimits(channel)
        char *channel
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        int  ret;
        double low,high;
        ret= ezcaGetGraphicLimits(channel, &low, &high);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 3);
            PUSHs(sv_2mortal(newSViv(ret)));
            PUSHs(sv_2mortal(newSVnv(low)));
            PUSHs(sv_2mortal(newSVnv(high)));
          }

void
GetNelem(channel)
        char *channel
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        int  ret;
        int  val;
        ret= ezcaGetNelem(channel, &val);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 2);
            PUSHs(sv_2mortal(newSViv(ret)));
            PUSHs(sv_2mortal(newSViv(val)));
          }

void
GetPrecision(channel)
        char *channel
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        int   ret;
        short val;
        ret= ezcaGetPrecision(channel, &val);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 2);
            PUSHs(sv_2mortal(newSViv(ret)));
            PUSHs(sv_2mortal(newSViv(val)));
          }

void
GetUnits(channel)
        char *channel
        PROTOTYPE: $
        PPCODE:
        /* errcode comes first ! */
        int   ret;
        char   st[STRINGBUFSIZE];
        ret= ezcaGetUnits(channel, st);
        if (ret!=0)
          { EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSViv(ret)));
          }
        else
          { EXTEND(sp, 2);
            PUSHs(sv_2mortal(newSViv(ret)));
            PUSHs(sv_2mortal(newSVpv(st,0)));
          }

double
GetTimeout()
        PROTOTYPE:
        CODE:
        RETVAL=ezcaGetTimeout();
        OUTPUT:
        RETVAL

int
GetRetryCount()
        PROTOTYPE:
        CODE:
        RETVAL=ezcaGetRetryCount();
        OUTPUT:
        RETVAL

int
SetTimeout(sec)
        double sec;
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaSetTimeout(sec);
        OUTPUT:
        RETVAL

int
SetRetryCount(retry)
        int retry;
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaSetRetryCount(retry);
        OUTPUT:
        RETVAL

void
AutoErrorMessageOn()
        PROTOTYPE:
        CODE:
        ezcaAutoErrorMessageOn();

void
AutoErrorMessageOff()
        PROTOTYPE:
        CODE:
        ezcaAutoErrorMessageOff();

#void
#Test(pvname)
#       stringy pvname;
#       CODE:
#       strcpy(pvname,"TESTESTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT");
#        OUTPUT:
#       pvname

int
SetMonitorDouble(pvname)
        char *pvname;
        PROTOTYPE: $
        ALIAS:
          Pezca::SetMonitor = 1
        CODE:
        RETVAL=ezcaSetMonitor(pvname, ezcaDouble);
        OUTPUT:
        RETVAL

int
SetMonitorString(pvname)
        char *pvname;
        ALIAS:
          Pezca::SetMonitorS = 1
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaSetMonitor(pvname, ezcaString);
        OUTPUT:
        RETVAL


int
ClearMonitorDouble(pvname)
        char *pvname;
        ALIAS:
          Pezca::ClearMonitor = 1
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaClearMonitor(pvname, ezcaDouble);
        OUTPUT:
        RETVAL

int
ClearMonitorString(pvname)
        char *pvname;
        ALIAS:
          Pezca::ClearMonitorS = 1
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaClearMonitor(pvname, ezcaString);
        OUTPUT:
        RETVAL


int
NewMonitorValueDouble(pvname)
        char *pvname;
        ALIAS:
          Pezca::NewMonitorValue = 1
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaNewMonitorValue(pvname, ezcaDouble);
        OUTPUT:
        RETVAL

int
NewMonitorValueString(pvname)
        char *pvname;
        ALIAS:
          Pezca::NewMonitorValueS = 1
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaNewMonitorValue(pvname, ezcaString);
        OUTPUT:
        RETVAL


int
Delay(sec)
        double sec;
        PROTOTYPE: $
        CODE:
        RETVAL=ezcaDelay(sec);
        OUTPUT:
        RETVAL

int
Pend_Event(timeout)
        double timeout;
        PROTOTYPE: $
        CODE:
        RETVAL= ca_pend_event(timeout);
        OUTPUT:
        RETVAL

