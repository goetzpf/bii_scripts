/************************************************************************/
/* iocinf.c,v 1.84.4.2 2001/03/06 00:32:45 jhill Exp									*/
/*									*/
/*	        	      L O S  A L A M O S			*/
/*		        Los Alamos National Laboratory			*/
/*		         Los Alamos, New Mexico 87545			*/
/*									*/
/*	Copyright, 1986, The Regents of the University of California.	*/
/*									*/
/*									*/
/*	History								*/
/*	-------								*/
/*	xx0887	joh	Init Release					*/
/*	021291 	joh	Fixed vxWorks task name creation bug		*/
/*	032291	joh	source cleanup					*/
/*	041591	joh	added channel exsits routine			*/
/*	060591	joh	delinting					*/
/*	060691	joh	removed 4 byte count from the beginning of	*/
/*			each message					*/
/*	071291	joh	no longer sends id at TCP connect		*/
/*	082791	joh	split send_msg() into two subroutines		*/
/*	110491	joh	mark all channels disconnected prior to		*/
/*			calling the first connection handler on		*/
/*			disconnect					*/
/*	110491	joh	allow cac_send_msg() to be called recursively	*/
/*	110691	joh	call recv_msg to free up deadlock prior to 	*/
/*			each send until a better solution is found	*/
/*			(checking only when the socket blocks causes	*/
/*			does not leave enough margin to fix the		*/
/*			problem once it is detected)			*/
/*	120991	joh	better quit when unable to broadcast		*/
/*	022692	joh	better prefix on messages			*/
/*	031892	joh	initial rebroadcast delay is now a #define	*/
/*	042892	joh	made local routines static			*/
/*      050492 	joh  	dont call cac_send_msg() until all messages     */
/*                      have been processed to support batching         */
/*	050492	joh	added new fd array to select			*/
/*	072392	joh	use SO_REUSEADDR when testing to see		*/
/*			if the repeater has been started		*/
/*	072792	joh	better messages					*/
/*	101692	joh	defensive coding against unexpected errno's	*/
/*      120992	GeG	support  VMS/UCX		                */
/*	091493	joh	init send retry count when each recv and at	*/
/*			at connect					*/
/*	102993	joh	toggle set sock opt to set			*/
/*	021794	joh	turn on SO_REUSEADDR only after the test for	*/
/*			address in use so that test works on UNIX	*/
/*			kernels that support multicast			*/
/*
 * iocinf.c,v
 * Revision 1.84.4.2  2001/03/06 00:32:45  jhill
 * fixed R3.13 for Linux's new socklen_t
 *
 * Revision 1.84.4.1  1999/07/15 20:50:23  jhill
 * fixed infinite loop when ENOBUFS returned by sendto()
 *
 * Revision 1.85  1999/07/15 20:15:30  jhill
 * fixed infinite loop when ENOBUFS returned by sendto()
 *
 * Revision 1.84  1998/11/10 21:57:20  jhill
 * reduced socket buf sizes
 *
 * Revision 1.83  1998/10/07 14:32:51  jba
 * Modified log message.
 *
 * Revision 1.82  1998/09/24 21:22:53  jhill
 *  subtle changes related to efficency when checking connection timers
 *
 * Revision 1.81  1998/07/07 23:04:00  jhill
 * cosmetic changes
 *
 * Revision 1.80  1998/06/18 00:07:12  jhill
 * use ipAddrToA
 *
 * Revision 1.79  1998/06/17 00:39:05  jhill
 * fixed problem where beta 12 briefly didnt communicate with old CA repeaters
 *
 * Revision 1.78  1998/06/16 01:16:09  jhill
 * allow saturated clients to poll/use new consolodated IP address routines in libCom/clean up when a server and client delete the PV simultaneously
 *
 * Revision 1.77  1998/05/29 00:03:19  jhill
 * allow CA to run systems w/o local interface query capabilities (ie cygwin32)
 *
 * Revision 1.76  1998/04/14 00:39:49  jhill
 * cosmetic
 *
 * Revision 1.75  1998/03/12 20:39:09  jhill
 * fixed problem where 3.13.beta11 unable to connect to 3.11 with correct native type
 *
 * Revision 1.74  1998/02/05 22:29:42  jhill
 * use osiSock macros
 *
 * Revision 1.73  1997/08/04 23:37:09  jhill
 * added beacon anomaly flag init/allow ip 255.255.255.255
 *
 * Revision 1.71  1997/06/13 09:14:19  jhill
 * connect/search proto changes
 *
 * Revision 1.70  1997/05/05 04:44:39  jhill
 * socket buf matches CA buf size, and pushPending flag added
 *
 * Revision 1.69  1997/04/23 17:05:05  jhill
 * pc port changes
 *
 * Revision 1.68  1997/04/10 19:26:14  jhill
 * asynch connect, faster connect, ...
 *
 * Revision 1.67  1997/01/08 22:48:42  jhill
 * improved message
 *
 * Revision 1.66  1996/11/02 00:50:53  jhill
 * many pc port, const in API, and other changes
 *
 * Revision 1.65  1996/09/16 16:37:02  jhill
 * o dont print disconnect message when the last channel on a connection is
 * 	deleted and the conn goes away
 * o local exceptions => exception handler
 *
 * Revision 1.64  1996/08/13 23:15:36  jhill
 * fixed warning
 *
 * Revision 1.63  1996/07/09 22:41:28  jhill
 * silence gcc warning
 *
 * Revision 1.62  1996/06/19 17:59:06  jhill
 * many 3.13 beta changes
 *
 * Revision 1.61  1995/12/19  19:33:02  jhill
 * function prototype changes
 *
 * Revision 1.60  1995/11/29  19:26:01  jhill
 * cleaned up interface to recv() and send()
 *								*/
/*									*/
/*_begin								*/
/************************************************************************/
/*									*/
/*	Title:	IOC socket interface module				*/
/*	File:	share/src/ca/iocinf.c					*/
/*									*/
/*	Purpose								*/
/*	-------								*/
/*									*/
/*	ioc socket interface module					*/
/*									*/
/*									*/
/*	Special comments						*/
/*	------- --------						*/
/* 	NOTE: Wallangong select does not return early if IO is 		*/
/*	present prior to the timeout expiration.			*/
/*									*/
/************************************************************************/
/*_end									*/

static char *sccsId = "@(#) iocinf.c,v 1.84.4.2 2001/03/06 00:32:45 jhill Exp";


/*	Allocate storage for global variables in this module		*/
#define		CA_GLBLSOURCE
#include	"iocinf.h"
#include	"net_convert.h"
#include	"bsdSocketResource.h"

LOCAL void 	tcp_recv_msg(struct ioc_in_use *piiu);
LOCAL void 	cac_connect_iiu(struct ioc_in_use *piiu);
LOCAL void 	cac_set_iiu_non_blocking (struct ioc_in_use *piiu);
LOCAL void 	cac_tcp_send_msg_piiu(struct ioc_in_use *piiu);
LOCAL void 	cac_udp_send_msg_piiu(struct ioc_in_use *piiu);
LOCAL void 	udp_recv_msg(struct ioc_in_use *piiu);
LOCAL void	ca_process_tcp(struct ioc_in_use *piiu);
LOCAL void	ca_process_udp(struct ioc_in_use *piiu);
LOCAL void 	cacRingBufferInit(struct ca_buffer *pBuf, 
				unsigned long size);
LOCAL char 	*getToken(const char **ppString, char *pBuf, 
				unsigned bufSize);





/*
 *	ALLOC_IOC()
 *
 * 	allocate and initialize an IOC info block for unallocated IOC
 *
 */
int alloc_ioc(
const struct sockaddr_in	*pina,
struct ioc_in_use		**ppiiu
)
{
  	int			status;
	bhe			*pBHE;

	/*
	 * look for an existing connection
	 */
	LOCK;
	pBHE = lookupBeaconInetAddr(pina);
	if(!pBHE){
		pBHE = createBeaconHashEntry(pina, FALSE);
		if(!pBHE){
			UNLOCK;
			return ECA_ALLOCMEM;
		}
	}

	if(pBHE->piiu){
		if (pBHE->piiu->state!=iiu_disconnected) {
			*ppiiu = pBHE->piiu;
			status = ECA_NORMAL;
		}
		else {
			status = ECA_DISCONN;
		}
	}
	else{
  		status = create_net_chan(
				ppiiu, 
				pina,
				IPPROTO_TCP);
		if(status == ECA_NORMAL){
			pBHE->piiu = *ppiiu;
		}
	}

	UNLOCK;

  	return status;
}


/*
 *	CREATE_NET_CHAN()
 *
 */
int create_net_chan(
struct ioc_in_use 		**ppiiu,
const struct sockaddr_in	*pina, /* only used by TCP connections */
int				net_proto
)
{
	struct ioc_in_use	*piiu;
  	int			status;
  	SOCKET			sock;
  	int			true = TRUE;
	caAddrNode		*pNode;

	LOCK;

	piiu = (IIU *) calloc(1, sizeof(*piiu));
	if(!piiu){
		UNLOCK;
		return ECA_ALLOCMEM;
	}

	piiu->pcas = ca_static;
	ellInit(&piiu->chidlist);
	ellInit(&piiu->destAddr);

  	piiu->sock_proto = net_proto;

	/*
	 * set the minor version ukn until the server
	 * updates the client 
	 */
	piiu->minor_version_number = CA_UKN_MINOR_VERSION;

	/*
	 * initially there are no claim messages pending
	 */
	piiu->claimsPending = FALSE;
	piiu->recvPending = FALSE;
	piiu->pushPending = FALSE;
	piiu->beaconAnomaly = FALSE;

  	switch(piiu->sock_proto)
  	{
	case	IPPROTO_TCP:

		pNode = (caAddrNode *)calloc(1,sizeof(*pNode));
		if(!pNode){
			free(piiu);
			UNLOCK;
			return ECA_ALLOCMEM;
		}
		memset((char *)&pNode->destAddr,0,sizeof(pNode->destAddr));

		pNode->destAddr.in = *pina;
		ellAdd(&piiu->destAddr, &pNode->node);
		piiu->recvBytes = tcp_recv_msg; 
		piiu->sendBytes = cac_connect_iiu; 
		piiu->procInput = ca_process_tcp; 
		piiu->minfreespace = 1;	

		/* 	allocate a socket	*/
		sock = socket(	AF_INET,	/* domain	*/
						SOCK_STREAM,	/* type		*/
						0);		/* deflt proto	*/
		if(sock == INVALID_SOCKET){
			free(pNode);
			free(piiu);
			UNLOCK;
			return ECA_SOCK;
		}

		piiu->sock_chan = sock;

		/*
		 * see TCP(4P) this seems to make unsollicited single events
		 * much faster. I take care of queue up as load increases.
		 */
		status = setsockopt(
					sock,
					IPPROTO_TCP,
					TCP_NODELAY,
					(char *)&true,
					sizeof(true));
		if(status < 0){
			free(pNode);
			free(piiu);
			status = socket_close(sock);
			if(status<0){
				SEVCHK(ECA_INTERNAL,NULL);
			}
			UNLOCK;
			return ECA_SOCK;
		}

		/*
		 * This should cause the connection to be checked
		 * periodically and an error to be returned if it is lost?
		 * 
		 * In practice the conn is checked very infrequently.
		 */

		status = setsockopt(
			sock,
			SOL_SOCKET,
			SO_KEEPALIVE,
			(char *)&true,
			sizeof true);
		if(status < 0){
			free(pNode);
			free(piiu);
				status = socket_close(sock);
			if(status<0){
				SEVCHK(ECA_INTERNAL,NULL);
			}
			UNLOCK;
			return ECA_SOCK;
		}

#ifdef JUNKYARD
		{
			struct linger 	linger;
			int		linger_size = sizeof linger;
      			status = getsockopt(
				sock,
				SOL_SOCKET,
				SO_LINGER,
				&linger,
				&linger_size);
      			assert(status >= 0);
			ca_printf(	"CAC: linger was on:%d linger:%d\n", 
				linger.l_onoff, 
				linger.l_linger);
		}
#endif

		/*
		 * some concern that vxWorks will run out of mBuf's
		 * if this change is made
		 *
		 * joh 11-10-98
		 */
#if 0
		{
			int i;

			/* set TCP buffer sizes */
			i = MAX_MSG_SIZE;
			status = setsockopt(
					sock,
					SOL_SOCKET,
					SO_SNDBUF,
					(char *)&i,
					sizeof(i));
			if(status < 0){
				free(pNode);
				free(piiu);
				socket_close(sock);
				UNLOCK;
				return ECA_SOCK;
			}
			i = MAX_MSG_SIZE;
			status = setsockopt(
					sock,
					SOL_SOCKET,
					SO_RCVBUF,
					(char *)&i,
					sizeof(i));
			if(status < 0){
				free(pNode);
				free(piiu);
				socket_close(sock);
				UNLOCK;
				return ECA_SOCK;
			}
		}
#endif

		cacRingBufferInit(&piiu->recv, sizeof(piiu->recv.buf));
		cacRingBufferInit(&piiu->send, sizeof(piiu->send.buf));

		cac_gettimeval (&piiu->timeAtLastRecv);

		/*
		 * Save the Host name for efficient access in the
		 * future.
		 */
		ipAddrToA (&pNode->destAddr.in, piiu->host_name_str, 
			sizeof(piiu->host_name_str));
			
		/*
		 * TCP starts out in the connecting state and later transitions
		 * to the connected state 
		 */
		piiu->state = iiu_connecting;

		cac_set_iiu_non_blocking (piiu);

		/*
		 * initiate connect sequence
		 */
		cac_connect_iiu (piiu);

		break;

	case	IPPROTO_UDP:
	
		piiu->recvBytes = udp_recv_msg; 
		piiu->sendBytes = cac_udp_send_msg_piiu; 
		piiu->procInput = ca_process_udp; 
		piiu->minfreespace = ETHERNET_MAX_UDP+2*sizeof(struct udpmsglog);	

		/* 	allocate a socket			*/
		sock = socket(	AF_INET,	/* domain	*/
			SOCK_DGRAM,	/* type		*/
			0);		/* deflt proto	*/
		if(sock == INVALID_SOCKET){
			free (piiu);
			UNLOCK;
			return ECA_SOCK;
		}

      	piiu->sock_chan = sock;

		/*
		 * The following only needed on BSD 4.3 machines
		 */
		status = setsockopt(
			sock,
			SOL_SOCKET,
			SO_BROADCAST,
			(char *)&true,
			sizeof(true));
		if(status<0){
			free(piiu);
			ca_printf("CAC: sso (err=\"%s\")\n",
			SOCKERRSTR);
			status = socket_close(sock);
			if(status < 0){
				SEVCHK(ECA_INTERNAL,NULL);
			}
			UNLOCK;
			return ECA_CONN;
		}

		/*
		 * some concern that vxWorks will run out of mBuf's
		 * if this change is made
		 *
		 * joh 11-10-98
		 */
#if 0
		/*
		 * bump up the UDP recv buffer
		 */
		{
			/*
			 *
			 * this allows for faster connects by queuing
			 * additional incomming UDP search response frames
			 *
			 * this allocates a 32k buffer
			 * (uses a power of two)
			 */
			int size = 1u<<15u;
			status = setsockopt(
					sock,
					SOL_SOCKET,
					SO_RCVBUF,
					(char *)&size,
					sizeof(size));
			if (status<0) {
        			ca_printf("CAC: setsockopt SO_RCVBUF (err=%s)\n",
					SOCKERRSTR);
			}
		}
#endif

#if 0
		memset((char *)&saddr,0,sizeof(saddr));
		saddr.sin_family = AF_INET;
		/* 
		 * let slib pick lcl addr 
		 */
		saddr.sin_addr.s_addr = htonl(INADDR_ANY); 
		saddr.sin_port = htons(0U);	

		status = bind(	sock, 
			(struct sockaddr *) &saddr, 
			sizeof(saddr));
		if(status<0){
			ca_printf("CAC: bind (err=%s)\n",SOCKERRSTR);
			genLocalExcep (ECA_INTERNAL,"bind failed");
		}
#endif

		/*
		 * load user and auto configured
		 * broadcast address list
		 */
		caSetupBCastAddrList(
			&piiu->destAddr, 
			sock, 
			ca_static->ca_server_port);


		cacRingBufferInit(&piiu->recv, sizeof(piiu->recv.buf));
		cacRingBufferInit(&piiu->send, min(MAX_UDP, 
			sizeof(piiu->send.buf)));

		/*
		 * UDP isnt connection oriented so we tag the piiu
		 * as up immediately
		 */
		piiu->state = iiu_connected;

		strncpy(
			piiu->host_name_str, 
			"<<unknown host>>", 
			sizeof(piiu->host_name_str)-1);

		cac_set_iiu_non_blocking (piiu);

      	break;

	default:
		free(piiu);
      	genLocalExcep (ECA_INTERNAL,"create_net_chan: ukn protocol");
		/*
		 * turn off gcc warnings
		 */
		UNLOCK;
		return ECA_INTERNAL;
  	}


  	if (fd_register_func) {
		(*fd_register_func)((void *)fd_register_arg, sock, TRUE);
	}

	/*
	 * add to the list of active IOCs
	 */
	ellAdd(&iiuList, &piiu->node);

	*ppiiu = piiu;

	UNLOCK;

  	return ECA_NORMAL;
}

/*
 * cac_set_iiu_non_blocking()
 */
LOCAL void cac_set_iiu_non_blocking (struct ioc_in_use *piiu)
{
  	osiSockIoctl_t value = TRUE;
	int	status;

	/*	
	 * Set non blocking IO  
	 * to prevent dead locks	
	 */
	status = socket_ioctl(
			piiu->sock_chan,
			FIONBIO,
			&value);
	if(status<0){
		ca_printf(
			"CAC: failed to set non-blocking because \"%s\"\n",
			SOCKERRSTR);
	}
}

/*
 * cac_connect_iiu()
 */
LOCAL void cac_connect_iiu (struct ioc_in_use *piiu)
{
	caAddrNode *pNode;
	int status;

	if (piiu->state==iiu_connected) {
		ca_printf("CAC: redundant connect() attempt?\n");
		return;
	}

	if (piiu->state==iiu_disconnected) {
		ca_printf("CAC: connecting when disconnected?\n");
		return;
	}
		
	LOCK;

	assert (ellCount(&piiu->destAddr)==1u);
	pNode = (caAddrNode *) ellFirst(&piiu->destAddr);

	/* 
	 * attempt to connect to a CA server
	 */
	while (1) {
		int errnoCpy;

		status = connect(	
				piiu->sock_chan,
				&pNode->destAddr.sa,
				sizeof(pNode->destAddr.sa));
		if (status == 0) {
			break;
		}

		errnoCpy = SOCKERRNO;
		if (errnoCpy==SOCK_EISCONN) {
			/*
			 * called connect after we are already connected 
			 * (this appears to be how they provide 
			 * connect completion notification)
			 */
			break;
		}
		else if (
			errnoCpy==SOCK_EINPROGRESS ||
			errnoCpy==SOCK_EWOULDBLOCK /* for WINSOCK */
			) {
			/*
			 * The  socket  is   non-blocking   and   a
			 * connection attempt has been initiated,
			 * but not completed.
			 */
			UNLOCK;
			return;
		}
		else if (errnoCpy==SOCK_EALREADY) {
			UNLOCK;
			return;	
		}
#ifdef _WIN32
		/*
		 * including this with vxWorks appears to
		 * cause trouble
		 */
		else if (errnoCpy==SOCK_EINVAL) { /* a SOCK_EALREADY alias used by early WINSOCK */
			UNLOCK;
			return;	
		}
#endif
		else if(errnoCpy==SOCK_EINTR) {
			/*
			 * restart the system call if interrupted
			 */
			continue;
		}
		else {	
			TAG_CONN_DOWN(piiu);
			UNLOCK;
			ca_printf(
	"CAC: Unable to connect port %d on \"%s\" because %d=\"%s\"\n", 
				ntohs(pNode->destAddr.in.sin_port), 
				piiu->host_name_str, errnoCpy, 
				SOCKERRSTR);
			return;
		}
	}

	/*
	 * put the iiu into the connected state
	 */
	piiu->state = iiu_connected;

	piiu->sendBytes = cac_tcp_send_msg_piiu; 

	cac_gettimeval (&piiu->timeAtLastRecv);

	/* 
	 * When we are done connecting and there are
	 * IOC_CLAIM_CHANNEL requests outstanding
	 * then add them to the outgoing message buffer
	 */
	if (piiu->claimsPending) {
		retryPendingClaims (piiu);
	}
	UNLOCK;
}


/*
 * caSetupBCastAddrList()
 */
void caSetupBCastAddrList (ELLLIST *pList, SOCKET sock, unsigned short port)
{
	char			*pstr;
	char			yesno[32u];
	int			yes;

	/*
	 * dont load the list twice
	 */
	assert (ellCount(pList)==0);

	/*
	 * Check to see if the user has disabled
	 * initializing the search b-cast list
	 * from the interfaces found.
	 */
	yes = TRUE;
	pstr = envGetConfigParam (
			&EPICS_CA_AUTO_ADDR_LIST,		
			sizeof(yesno),
			yesno);
	if (pstr) {
			if (strstr(pstr,"no")||strstr(pstr,"NO")) {
			yes = FALSE;
		}
	}

	/*
	 * LOCK is for piiu->destAddr list
	 * (lock outside because this is used by the server also)
	 */
	if (yes) {
		struct in_addr addr;
		addr.s_addr = htonl(INADDR_ANY);
		caDiscoverInterfaces(
			pList,
			sock,
			port,
			addr);
	}

	caAddConfiguredAddr(
		pList, 
		&EPICS_CA_ADDR_LIST,
		sock,
		port);

	if (ellCount(pList)==0) {
		genLocalExcep (ECA_NOSEARCHADDR, NULL);
	}
}


/*
 *	NOTIFY_CA_REPEATER()
 *
 *	tell the cast repeater that another client needs fan out
 *
 *	NOTES:
 *	1)	local communication only (no LAN traffic)
 *
 */
void notify_ca_repeater()
{
	caHdr msg;
	struct sockaddr_in saddr;
	int status;
	static int once = FALSE;
	int len;

	if (ca_static->ca_repeater_contacted) {
		return;
	}

	if (!piiuCast) {
		return;
	}

	if (piiuCast->state!=iiu_connected) {
		return;
	}

	if (ca_static->ca_repeater_tries>N_REPEATER_TRIES_PRIOR_TO_MSG){
		if (!once) {
			ca_printf(
		"Unable to contact CA repeater after %d tries\n",
			N_REPEATER_TRIES_PRIOR_TO_MSG);
			ca_printf(
		"Silence this message by starting a CA repeater daemon\n");
			once = TRUE;
		}
	}

	/*
	 * In 3.13 beta 11 and before the CA repeater calls local_addr() 
	 * to determine a local address and does not allow registration 
	 * messages originating from other addresses. In these 
	 * releases local_addr() returned the address of the first enabled
	 * interface found, and this address may or may not have been the loop
	 * back address. Starting with 3.13 beta 12 local_addr() was
	 * changed to always return the address of the first enabled 
	 * non-loopback interface because a valid non-loopback local
	 * address is required in the beacon messages. Therefore, to 
	 * guarantee compatibility with past versions of the repeater
	 * we alternate between the address returned by local_addr()
	 * and the loopback address here.
	 *
	 * CA repeaters in R3.13 beta 12 and higher allow
	 * either the loopback address or the address returned
	 * by local address (the first non-loopback address found)
	 */
	if (ca_static->ca_repeater_tries&1) {
		status = local_addr (piiuCast->sock_chan, &saddr);
		if (status<0) {
			/*
			 * use the loop back address to communicate with the CA repeater
			 * if this os does not have interface query capabilities
			 *
			 * this will only work with 3.13 beta 12 CA repeaters or later
			 */
			saddr.sin_family = AF_INET;
			saddr.sin_addr.s_addr = htonl (INADDR_LOOPBACK);
		}
	}
	else {
		saddr.sin_family = AF_INET;
		saddr.sin_addr.s_addr = htonl (INADDR_LOOPBACK);
	}

	LOCK; /*MULTINET TCP/IP routines are not reentrant*/

	memset((char *)&msg, 0, sizeof(msg));
	msg.m_cmmd = htons(REPEATER_REGISTER);
	msg.m_available = saddr.sin_addr.s_addr;
	saddr.sin_port = htons (ca_static->ca_repeater_port);	

	/*
	 * Intentionally sending a zero length message here
	 * until most CA repeater daemons have been restarted
	 * (and only then will accept the above protocol)
	 * (repeaters began accepting this protocol
	 * starting with EPICS 3.12)
	 *
	 * SOLARIS will not accept a zero length message
	 * and we are just porting there for 3.12 so
	 * we will use the new protocol for 3.12
	 *
	 * recent versions of UCX will not accept a zero 
	 * length message and we will assume that folks
	 * using newer versions of UCX have rebooted (and
	 * therefore restarted the CA repeater - and therefore
	 * moved it to an EPICS release that accepts this protocol)
	 */
#	if defined(SOLARIS) || defined(UCX)
		len = sizeof(msg);
#	else /* SOLARIS */
		len = 0;
#	endif /* SOLARIS */

	status = sendto (piiuCast->sock_chan, (char *)&msg, len,  
						0, (struct sockaddr *)&saddr, sizeof(saddr));
	if (status < 0) {
		if(	SOCKERRNO != SOCK_EINTR && 
			/* SOCKERRNO != SOCK_ENOBUFS && */
			SOCKERRNO != SOCK_EWOULDBLOCK &&
			/*
			 * This is returned from Linux when
			 * the repeater isnt running
			 */
			SOCKERRNO != SOCK_ECONNREFUSED 
			) {
			ca_printf(
				"CAC: error sending to repeater was \"%s\"\n", 
				SOCKERRSTR);
		}
	}
	ca_static->ca_repeater_tries++;

	UNLOCK;
}



/*
 *	CAC_UDP_SEND_MSG_PIIU()
 *
 */
LOCAL void cac_udp_send_msg_piiu(struct ioc_in_use *piiu)
{
	caAddrNode	*pNode;
	unsigned long	sendCnt;
  	int		status;

	/*
	 * check for shutdown in progress
	 */
	if(piiu->state!=iiu_connected){
		return;
	}

	LOCK;

	sendCnt = cacRingBufferReadSize(&piiu->send, TRUE);

	assert(sendCnt<=piiu->send.max_msg);

	/*
	 * return if nothing to send
	 */
	if(sendCnt == 0){
		UNLOCK;
		return;
	}

	pNode = (caAddrNode *) piiu->destAddr.node.next;
	while (pNode) {
		unsigned long	actualSendCnt;

		status = sendto(
				piiu->sock_chan,
				&piiu->send.buf[piiu->send.rdix],	
				(int) sendCnt,
				0,
				&pNode->destAddr.sa,
				sizeof(pNode->destAddr.sa));
		if(status>=0){
			actualSendCnt = (unsigned long) status;
			assert (actualSendCnt == sendCnt);
		}
		else {
			int	localErrno;

			localErrno = SOCKERRNO;

			if(	localErrno != SOCK_EWOULDBLOCK && 
				/* localErrno != SOCK_ENOBUFS && */
				localErrno != SOCK_EINTR){
                char buf[64];

                ipAddrToA (&pNode->destAddr.in, buf, sizeof(buf));

				ca_printf(
					"CAC: error = \"%s\" sending UDP msg to %s\n",
					SOCKERRSTR, buf);
			}
		}
		pNode = (caAddrNode *) pNode->node.next;
	}

	/*
	 * forces UDP send buffer to be a 
	 * queue instead of a ring buffer
	 * (solves ring boundary problems)
	 */
	cacRingBufferInit(
			&piiu->send, 
			min(MAX_UDP, sizeof(piiu->send.buf)));
	piiu->pushPending = FALSE;
	UNLOCK;
	return;
}


/*
 *	CAC_TCP_SEND_MSG_PIIU()
 *
 */
LOCAL void cac_tcp_send_msg_piiu(struct ioc_in_use *piiu)
{
	unsigned long	sendCnt;
  	int		status;
	int		localError;

	/*
	 * check for shutdown in progress
	 */
	if(piiu->state!=iiu_connected){
		return;
	}

	LOCK;

	/*
	 * Check at least twice to see if there is anything
	 * in the ring buffer (in case the block of messages
	 * isnt continuous). Always return if the send was 
	 * less bytes than requested.
	 */
	while (TRUE) {
		sendCnt = cacRingBufferReadSize(&piiu->send, TRUE);
		assert(sendCnt<=piiu->send.max_msg);

		/*
		 * return if nothing to send
		 */
		if(sendCnt == 0){
			piiu->sendPending = FALSE;
			piiu->pushPending = FALSE;
			UNLOCK;

			/* 
			 * If we cleared out some send backlog and there are
			 * IOC_CLAIM_CHANNEL requests outstanding
			 * then add them to the outgoing message buffer
			 */
			if (piiu->claimsPending) {
				retryPendingClaims(piiu);
			}
			return;
		}

		assert (sendCnt<=INT_MAX);

		status = send(
				piiu->sock_chan,
				&piiu->send.buf[piiu->send.rdix],	
				(int) sendCnt,
				0);
		if (status<=0) {
			break;
		}

		CAC_RING_BUFFER_READ_ADVANCE(&piiu->send, status);

	}

	if (status==0) {
		TAG_CONN_DOWN(piiu);
		UNLOCK;
		return;
	}

	localError = SOCKERRNO;

	if(	localError == SOCK_EWOULDBLOCK ||
		localError == SOCK_EINTR){
			UNLOCK;
			return;
	}

	if(	localError != SOCK_EPIPE && 
		localError != SOCK_ECONNRESET &&
		localError != SOCK_ETIMEDOUT){
		ca_printf(	
			"CAC: error on socket send() %s\n",
			SOCKERRSTR);
	}

	TAG_CONN_DOWN(piiu);
	UNLOCK;
	return;
}


/*
 * ca_process_input_queue()
 */
void ca_process_input_queue()
{
	struct ioc_in_use 	*piiu;

	LOCK;

	/*
	 * dont allow recursion
	 */
	if(post_msg_active){
		UNLOCK;
		return;
	}

	for(piiu=(IIU *)iiuList.node.next;
		piiu; piiu=(IIU *)piiu->node.next){

		if(piiu->state!=iiu_connected){
			continue;
		}

		(*piiu->procInput)(piiu);
	}

	UNLOCK;
}



/*
 * TCP_RECV_MSG()
 *
 */
LOCAL void tcp_recv_msg(struct ioc_in_use *piiu)
{
	unsigned long	writeSpace;
  	int		status;

	if(piiu->state!=iiu_connected){
		return;
	}

	LOCK;

        /*
         * Check at least twice to see if there is ana space left
         * in the ring buffer (in case the messages block
         * isnt continuous). Always return if the send was
         * less bytes than requested.
         */
        while (TRUE) {

		writeSpace = cacRingBufferWriteSize(&piiu->recv, TRUE);
		if(writeSpace == 0){
			break;
		}

		assert (writeSpace<=INT_MAX);

		status = recv(	piiu->sock_chan,
				&piiu->recv.buf[piiu->recv.wtix],
				(int) writeSpace,
				0);
		if(status == 0){
			TAG_CONN_DOWN(piiu);
			break;
		}
		else if(status <0){
			/* try again on status of -1 and no luck this time */
			if(SOCKERRNO == SOCK_EWOULDBLOCK || SOCKERRNO == SOCK_EINTR){
				break;
			}

			if(	SOCKERRNO != SOCK_EPIPE && 
				SOCKERRNO != SOCK_ECONNRESET &&
				SOCKERRNO != SOCK_ETIMEDOUT){
				ca_printf(	
					"CAC: unexpected TCP recv error (err=%s)\n",
					SOCKERRSTR);
			}
			TAG_CONN_DOWN(piiu);
			break;
		}

		assert (((unsigned long)status)<=writeSpace);

		CAC_RING_BUFFER_WRITE_ADVANCE(&piiu->recv, status);

		/*
		 * Record the time whenever we receive a message 
		 * from this IOC
		 */
		piiu->timeAtLastRecv = ca_static->currentTime;
	}

	UNLOCK;
	return;
}


/*
 * ca_process_tcp()
 *
 */
LOCAL void ca_process_tcp(struct ioc_in_use *piiu)
{
	caAddrNode *pNode;
	int status;
	long bytesToProcess;
	unsigned countDown;

	LOCK;

	/*
	 * dont allow recursion
	 */
	if(post_msg_active){
		UNLOCK;
		return;
	}

	post_msg_active = TRUE;

	pNode = (caAddrNode *) piiu->destAddr.node.next;

	/*
	 * Dont loop forever here if the server floods a slow
	 * client with monitors and there is a flush call in
	 * an event routine. This code was specifically added
	 * to allow a client to get out of an infinite loop 
	 * occurring when the client does a put/flush in a
	 * monitor call back to the same PV that is being
	 * monitored
	 *
	 * it should be sufficent to read two sections from the
	 * ring buffer in case the populated space is split
	 */
	countDown = 3;
	while (--countDown) {
		bytesToProcess = cacRingBufferReadSize(&piiu->recv, TRUE);
		if(bytesToProcess == 0){
			break;
		}

  		/* post message to the user */
  		status = post_msg(
				piiu, 
				&pNode->destAddr.in,
				&piiu->recv.buf[piiu->recv.rdix],
				bytesToProcess);
		if(status != OK){
			TAG_CONN_DOWN(piiu);
			post_msg_active = FALSE;
			UNLOCK;
			return;
		}
		CAC_RING_BUFFER_READ_ADVANCE(
				&piiu->recv,
				bytesToProcess);
	}

	post_msg_active = FALSE;
	UNLOCK;

 	return;
}



/*
 *	UDP_RECV_MSG()
 *
 */
LOCAL void udp_recv_msg(struct ioc_in_use *piiu)
{
  	int status;
  	osiSocklen_t reply_size;
	struct udpmsglog *pmsglog;
	unsigned long bytesAvailable;
	
	if(piiu->state!=iiu_connected){
		return;
	}

	LOCK;

	bytesAvailable = cacRingBufferWriteSize(&piiu->recv, TRUE);
	assert(bytesAvailable >= ETHERNET_MAX_UDP+2*sizeof(*pmsglog));
	pmsglog = (struct udpmsglog *) &piiu->recv.buf[piiu->recv.wtix];

  	reply_size = sizeof(pmsglog->addr);
    	status = recvfrom(	
			piiu->sock_chan,
			(char *)(pmsglog+1),
			bytesAvailable-2*sizeof(*pmsglog), /* was MAX_UDP before 8-5-97 */
			0,
			(struct sockaddr *)&pmsglog->addr, 
			&reply_size);
    	if(status < 0){
		/*
		 * op would block which is ok to ignore till ready
		 * later
		 */
      		if(SOCKERRNO == SOCK_EWOULDBLOCK || SOCKERRNO == SOCK_EINTR){
			UNLOCK;
       			return;
		}
#               ifdef linux
			/*
			 * Avoid spurious ECONNREFUSED bug
			 * in linux
			 */
			if (SOCKERRNO==SOCK_ECONNREFUSED) {
				UNLOCK;
       				return;
			}
#               endif
		ca_printf("Unexpected UDP failure %s\n", SOCKERRSTR);
    	}
	else if(status > 0){
		unsigned long		bytesActual;

		/*	
	 	 * log the msg size
		 * and advance the ring index
	 	 */
		pmsglog->nbytes = status;
		pmsglog->valid = TRUE;
		bytesActual = status + sizeof(*pmsglog);
		CAC_RING_BUFFER_WRITE_ADVANCE(&piiu->recv, bytesActual);
		/*
		 * if there isnt enough room at the end advance
		 * to the beginning of the ring
		 */
		bytesAvailable = cacRingBufferWriteSize(&piiu->recv, TRUE);
		if( bytesAvailable < ETHERNET_MAX_UDP+2*sizeof(*pmsglog) ){
			assert(bytesAvailable>=sizeof(*pmsglog));
			pmsglog = (struct udpmsglog *) 
				&piiu->recv.buf[piiu->recv.wtix];
			pmsglog->valid = FALSE;	
			pmsglog->nbytes = bytesAvailable - sizeof(*pmsglog); 
			CAC_RING_BUFFER_WRITE_ADVANCE(
				&piiu->recv, bytesAvailable);
		}
#		ifdef DEBUG
      			ca_printf(
				"%s: udp reply of %d bytes\n",
				__FILE__,
				status);
#		endif
	}

	UNLOCK;

	return;
}



/*
 *	CA_PROCESS_UDP()
 *
 */
LOCAL void ca_process_udp(struct ioc_in_use *piiu)
{
  	int			status;
	struct udpmsglog	*pmsglog;
	char			*pBuf;
	unsigned long		bytesAvailable;

	LOCK;

	/*
	 * dont allow recursion
	 */
	if(post_msg_active){
		UNLOCK;
		return;
	}

	post_msg_active = TRUE;

	while(TRUE){

		bytesAvailable = cacRingBufferReadSize(&piiu->recv, TRUE);
		if(bytesAvailable == 0){
			break;
		}

		assert(bytesAvailable>=sizeof(*pmsglog));

		pBuf = &piiu->recv.buf[piiu->recv.rdix];
		while(pBuf<&piiu->recv.buf[piiu->recv.rdix]+bytesAvailable){
			pmsglog = (struct udpmsglog *) pBuf;

  			/* post message to the user */
			if(pmsglog->valid){

  				status = post_msg(
					piiu,
					&pmsglog->addr,
					(char *)(pmsglog+1),
					pmsglog->nbytes);
				if(status != OK || piiu->curMsgBytes){
					char buf[64];

					ipAddrToA (&pmsglog->addr, buf, sizeof(buf));

					ca_printf("%s: bad UDP msg from %s\n", __FILE__, buf);

					/*
					 * resync the ring buffer
					 * (discard existing messages)
					 */
					cacRingBufferInit(
						&piiu->recv, 
						sizeof(piiu->recv.buf));
					piiu->curMsgBytes = 0;
					piiu->curDataBytes = 0;
					post_msg_active = FALSE;
					UNLOCK;
					return;
				}
			}
			pBuf += sizeof(*pmsglog)+pmsglog->nbytes;
		}
		CAC_RING_BUFFER_READ_ADVANCE(
				&piiu->recv,
				bytesAvailable);
  	}

	post_msg_active = FALSE;
	UNLOCK;

  	return; 
}


/*
 *	cac_close_ioc ()
 *	(free resources associated with a client connection)
 *
 */
void cac_close_ioc (IIU *piiu)
{
	caAddrNode	*pNode;
  	ciu		chix;
	int		status;
	unsigned	chanDisconnectCount;

	/*
	 * dont close twice
	 */
  	assert (piiu->sock_chan!=INVALID_SOCKET);

	LOCK;

	ellDelete (&iiuList, &piiu->node);

	/*
	 * attempt to clear out messages in recv queue
	 */
	(*piiu->procInput) (piiu);


	if (piiu == piiuCast) {
		piiuCast = NULL;
		chanDisconnectCount = 0u;
	}
	else {
		ciu	pNext;

		chanDisconnectCount = ellCount(&piiu->chidlist);

		/*
		 * remove IOC from the beacon hash table
		 */
		pNode = (caAddrNode *) piiu->destAddr.node.next;
		assert (pNode);
		removeBeaconInetAddr (&pNode->destAddr.in);

		chix = (ciu) ellFirst(&piiu->chidlist);
		while (chix) {
			pNext = (ciu) ellNext(&chix->node);
			cacDisconnectChannel (chix);
			chix = pNext;
		}
	}

  	if (fd_register_func) {
		(*fd_register_func) ((void *)fd_register_arg, piiu->sock_chan, FALSE);
	}

  	status = socket_close (piiu->sock_chan);
	assert (status == 0);

	/*
	 * free message body cache
	 */
	if (piiu->pCurData) {
		free (piiu->pCurData);
		piiu->pCurData = NULL;
		piiu->curDataMax = 0;
	}

  	piiu->sock_chan = INVALID_SOCKET;

	ellFree (&piiu->destAddr);

	if (chanDisconnectCount) {
		genLocalExcep (ECA_DISCONN, piiu->host_name_str);
	}

	free (piiu);

	UNLOCK;
}


/*
 * cacDisconnectChannel()
 */
void cacDisconnectChannel(ciu chix)
{
	LOCK;

	/*
	 * if a client initiated channel delete is pending then we will 
	 * never get a delete confirm message from this server, and will therefore
	 * need to take care of freeing the remaing channel resources here
	 */
	if (chix->state == cs_closed) {
		clearChannelResources (chix->cid);
		UNLOCK;
		return;
	}

	chix->privType = TYPENOTCONN;
	chix->privCount = 0u;
	chix->id.sid = ~0u;
	chix->ar.read_access = FALSE;
	chix->ar.write_access = FALSE;

	/*
	 * call their connection handler as required
	 */
	if (chix->state==cs_conn) {
		miu monix, next;

		chix->state = cs_prev_conn;

		/*
		 * clear outstanding get call backs 
		 */
		caIOBlockListFree (&pend_read_list, chix, 
				TRUE, ECA_DISCONN);

		/*
		 * clear outstanding put call backs 
		 */
		caIOBlockListFree (&pend_write_list, chix, 
				TRUE, ECA_DISCONN);

		/*
		 * look for events that have an event cancel in progress
		 */
		for (monix = (miu) ellFirst (&chix->eventq);
				monix; monix = next) {
			
			next = (miu) ellNext (&monix->node);
			
			/*
			 * if there is an event cancel in progress
			 * delete the event - we will never receive
			 * an event cancel confirm from this server
			 */
			if (monix->usr_func == NULL) {
				ellDelete (&chix->eventq, &monix->node);
				caIOBlockFree (monix);
			}
		}

		if (chix->pConnFunc) {
			struct connection_handler_args 	args;

			args.chid = chix;
			args.op = CA_OP_CONN_DOWN;
			(*chix->pConnFunc) (args);
		}
		if (chix->pAccessRightsFunc) {
			struct access_rights_handler_args 	args;

			args.chid = chix;
			args.ar = chix->ar;
			(*chix->pAccessRightsFunc) (args);
		}
	}
	removeFromChanList(chix);
	/*
	 * try to reconnect
	 */
	assert (piiuCast);
	addToChanList(chix, piiuCast);
	cacSetRetryInterval(0u);
	UNLOCK;
}


/*
 *	REPEATER_INSTALLED()
 *
 *	Test for the repeater already installed
 *
 *	NOTE: potential race condition here can result
 *	in two copies of the repeater being spawned
 *	however the repeater detects this, prints a message,
 *	and lets the other task start the repeater.
 *
 *	QUESTION: is there a better way to test for a port in use? 
 *	ANSWER: none that I can find.
 *
 *	Problems with checking for the repeater installed
 *	by attempting to bind a socket to its address
 *	and port.
 *
 *	1) Closed socket may not release the bound port
 *	before the repeater wakes up and tries to grab it.
 *	Attempting to bind the open socket to another port
 *	also does not work.
 *
 * 	072392 - problem solved by using SO_REUSEADDR
 */
int repeater_installed()
{
  	int			status;
  	SOCKET			sock;
  	struct sockaddr_in	bd;
	int			true = 1;
	int 			installed = FALSE;

	LOCK;

     	/* 	allocate a socket			*/
	sock = socket(	AF_INET,	/* domain	*/
		SOCK_DGRAM,	/* type		*/
		0);		/* deflt proto	*/
	if(sock == INVALID_SOCKET) {
		UNLOCK;
		return installed;
	}

	memset((char *)&bd,0,sizeof bd);
	bd.sin_family = AF_INET;
	bd.sin_addr.s_addr = htonl(INADDR_ANY);	
	bd.sin_port = htons(ca_static->ca_repeater_port);	
	status = bind(	sock, 
		(struct sockaddr *) &bd, 
		sizeof bd);
     	if(status<0){
		if(SOCKERRNO == SOCK_EADDRINUSE){
			installed = TRUE;
		}
	}

	/*
	 * turn on reuse only after the test so that
	 * this works on kernels that support multicast
	 */
	status = setsockopt(	sock,
				SOL_SOCKET,
				SO_REUSEADDR,
				(char *)&true,
				sizeof true);
	if(status<0){
		ca_printf(      "CAC: set socket option reuseaddr failed\n");
	}

	status = socket_close(sock);
	if(status<0){
		SEVCHK(ECA_INTERNAL,NULL);
	}
		
	UNLOCK;

	return installed;
}



/*
 * cacRingBufferRead()
 *
 * returns the number of bytes read which may be less than
 * the number requested.
 */
unsigned long cacRingBufferRead(
struct ca_buffer	*pRing,
void			*pBuf,
unsigned long		nBytes)
{
	unsigned long	potentialBytes;
	unsigned long	actualBytes;
	char		*pCharBuf;

	actualBytes = 0u;
	pCharBuf = pBuf;
	while(TRUE){
		potentialBytes = cacRingBufferReadSize(pRing, TRUE);
		if(potentialBytes == 0u){
			return actualBytes;
		}
		potentialBytes = min(potentialBytes, nBytes-actualBytes);
		memcpy(pCharBuf, &pRing->buf[pRing->rdix], potentialBytes);
		CAC_RING_BUFFER_READ_ADVANCE(pRing, potentialBytes);
		pCharBuf += potentialBytes;
		actualBytes += potentialBytes;	
		if(nBytes <= actualBytes){
			return actualBytes;
		}
	}
}


/*
 * cacRingBufferWrite()
 *
 * returns the number of bytes written which may be less than
 * the number requested.
 */
unsigned long cacRingBufferWrite(
struct ca_buffer	*pRing,
const void		*pBuf,
unsigned long		nBytes)
{
	unsigned long	potentialBytes;
	unsigned long	actualBytes;
	const char	*pCharBuf;

	actualBytes = 0u;
	pCharBuf = pBuf;
	while(TRUE){
		potentialBytes = cacRingBufferWriteSize(pRing, TRUE);
		if(potentialBytes == 0u){
			return actualBytes;
		}
		potentialBytes = min(potentialBytes, nBytes-actualBytes);
		memcpy(pRing->buf+pRing->wtix, pCharBuf, potentialBytes);
		CAC_RING_BUFFER_WRITE_ADVANCE(pRing, potentialBytes);
		pCharBuf += potentialBytes;
		actualBytes += potentialBytes;	
		if(nBytes <= actualBytes){
			return actualBytes;
		}
	}
}



/*
 * cacRingBufferInit()
 *
 */
LOCAL void cacRingBufferInit(struct ca_buffer *pBuf, unsigned long size)
{
	assert(size<=sizeof(pBuf->buf));
	pBuf->max_msg = size;
	pBuf->rdix = 0u;
	pBuf->wtix = 0u;
	pBuf->readLast = TRUE;
}


/*
 * cacRingBufferReadSize()
 *
 * returns N bytes available
 * (not nec contiguous)
 */
unsigned long cacRingBufferReadSize(struct ca_buffer *pBuf, int contiguous)
{
	unsigned long 	count;
	
	if(pBuf->wtix < pBuf->rdix){
		count = pBuf->max_msg - pBuf->rdix;
		if(!contiguous){
			count += pBuf->wtix;
		}
	}
	else if(pBuf->wtix > pBuf->rdix){
		count = pBuf->wtix - pBuf->rdix;
	}
	else if(pBuf->readLast){
		count = 0u;
	}
	else{
		if(contiguous){
			count = pBuf->max_msg - pBuf->rdix;
		}
		else{
			count = pBuf->max_msg;
		}
	}

#if 0
	printf("%d bytes available for reading \n", count);
#endif

	return count;
}


/*
 * cacRingBufferWriteSize()
 *
 * returns N bytes available
 * (not nec contiguous)
 */
unsigned long cacRingBufferWriteSize(struct ca_buffer *pBuf, int contiguous)
{
	unsigned long 	count;

	if(pBuf->wtix < pBuf->rdix){
		count = pBuf->rdix - pBuf->wtix;
	}
	else if(pBuf->wtix > pBuf->rdix){
		count = pBuf->max_msg - pBuf->wtix;
		if(!contiguous){
			count += pBuf->rdix;
		}
	}
	else if(pBuf->readLast){
		if(contiguous){
			count = pBuf->max_msg - pBuf->wtix;
		}
		else{
			count = pBuf->max_msg;
		}
	}
	else{
		count = 0u;
	}

	return count;
}



/*
 * localHostName()
 *
 * o Indicates failure by setting ptr to nill
 *
 * o Calls non posix gethostbyname() so that we get DNS style names
 *      (gethostbyname() should be available with most BSD sock libs)
 *
 * vxWorks user will need to configure a DNS format name for the
 * host name if they wish to be cnsistent with UNIX and VMS hosts.
 *
 * this needs to attempt to determine if the process is a remote 
 * login - hard to do under UNIX
 */
char *localHostName()
{
	int     size;
	int     status;
	char    pName[MAXHOSTNAMELEN];
	char	*pTmp;

	status = gethostname(pName, sizeof(pName));
	if(status){
		return NULL;
	}

	size = strlen(pName)+1;
	pTmp = malloc(size);
	if(!pTmp){
		return pTmp;
	}

	strncpy(pTmp, pName, size-1);
	pTmp[size-1] = '\0';

	return pTmp;
}


/*
 * caAddConfiguredAddr()
 */
void epicsShareAPI caAddConfiguredAddr(ELLLIST *pList, const ENV_PARAM *pEnv, 
	SOCKET socket, unsigned short port)
{
	caAddrNode *pNode;
	const char *pStr;
	const char *pToken;
	caAddr addr;
	caAddr localAddr;
	char buf[32u]; /* large enough to hold an IP address */
	int status;

	pStr = envGetConfigParamPtr(pEnv);
	if(!pStr){
		return;
	}

	/*
	 * obtain a local non-loopback address
	 *
	 * It has proven to be difficult to determine which
	 * of the local addresses is the correct server address
	 * to be embedded in beacons from a multi-inteface host
	 * when the user supplies the beacon destination
	 * due to routing complexities (a local ip address is 
	 * supplied in the beacon message so that
	 * we can allow beacon repeaters). I have tried using 
	 * connect() and getsockname() to obtain this information 
	 * without success. For now we are using the local
	 * host address of the first non-loopback interface found
	 * for this.
	 */
	status = local_addr(socket, &localAddr.in);
	if (status) {
		/*
		 * some hosts do not provide local interface query 
		 * capabilities. In this situation we default to
		 * zero and the clients will obtain the beacon's
		 * address from the UDP header. In this situation
		 * beacon repeaters will be required to detect 
		 * the address INADDR_ANY in the beacon message
		 * and replace it with the correct address of the
		 * server.
		 */
		localAddr.in.sin_family = AF_INET;
		localAddr.in.sin_addr.s_addr = htonl(INADDR_ANY);
		localAddr.in.sin_port = htons(0);
	}

	while( (pToken = getToken(&pStr, buf, sizeof(buf))) ){
		status = aToIPAddr(pToken, port, &addr.in);
		if (status<0) {
			ca_printf("%s: Parsing '%s'\n", __FILE__, pEnv->name);
			ca_printf("\tBad internet address or host name: '%s'\n", pToken);
			continue;
		}
		pNode = (caAddrNode *) calloc (1, sizeof(*pNode));
		if (pNode) {
			pNode->destAddr = addr;
			pNode->srcAddr = localAddr;
			ellAdd (pList, &pNode->node);
		}
	}

	return;
}



/*
 * getToken()
 */
LOCAL char *getToken(const char **ppString, char *pBuf, unsigned bufSIze)
{
	const char *pToken;
	unsigned i;

	pToken = *ppString;
	while(isspace(*pToken)&&*pToken){
		pToken++;
	}

	for (i=0u; i<bufSIze; i++) {
		if (isspace(pToken[i]) || pToken[i]=='\0') {
			pBuf[i] = '\0';
			break;
		}
		pBuf[i] = pToken[i];
	}

	*ppString = &pToken[i];

	if(*pToken){
		return pBuf;
	}
	else{
		return NULL;
	}
}


/*
 * caPrintAddrList()
 */
void caPrintAddrList(ELLLIST *pList)
{
        caAddrNode              *pNode;

        printf("Channel Access Address List\n");
        pNode = (caAddrNode *) ellFirst(pList);
        while(pNode){
				char buf[64];
                if(pNode->destAddr.sa.sa_family != AF_INET){
                        printf("<addr entry not in internet format>");
                        continue;
                }
				ipAddrToA (&pNode->destAddr.in, buf, sizeof(buf));
                printf(	"%s\n", buf);

                pNode = (caAddrNode *) ellNext(&pNode->node);
        }
}


/*
 * caFetchPortConfig()
 */
unsigned short epicsShareAPI caFetchPortConfig
	(const ENV_PARAM *pEnv, unsigned short defaultPort)
{
	long		longStatus;
	long		epicsParam;
	int 		port;

	longStatus = envGetLongConfigParam(pEnv, &epicsParam);
	if (longStatus!=0) {
		epicsParam = (long) defaultPort;
		ca_printf ("EPICS \"%s\" integer fetch failed\n", pEnv->name);
		ca_printf ("setting \"%s\" = %ld\n", pEnv->name, epicsParam);
	}

	/*
	 * This must be a server port that will fit in an unsigned
	 * short
	 */
	if (epicsParam<=IPPORT_USERRESERVED || epicsParam>USHRT_MAX) {
		ca_printf ("EPICS \"%s\" out of range\n", pEnv->name);
		/*
		 * Quit if the port is wrong due CA coding error
		 */
		assert (epicsParam != (long) defaultPort);
		epicsParam = (long) defaultPort;
		ca_printf ("Setting \"%s\" = %ld\n", pEnv->name, epicsParam);
	}

	/*
	 * ok to clip to unsigned short here because we checked the range
	 */
	port = (unsigned short) epicsParam;

	return port;
}


/*
 *      CAC_MUX_IO()
 */
void cac_mux_io(struct timeval  *ptimeout, unsigned iocCloseAllowed)
{
	int                     count;
	struct timeval          timeout;
	unsigned				countDown;

	/*
	 * first check for pending recv's with a zero time out so that
	 * 1) flow control works correctly (and)
	 * 2) we queue up sends resulting from recvs properly
	 *	(this results in improved max throughput)
	 *
	 * ... but dont allow this to go on forever if a fast
	 * server is flooding a slow client with monitors ...
	 */
	countDown = 512u;
    while (--countDown) {
		CLR_CA_TIME (&timeout);
		/*
		 * NOTE cac_select_io() will set the
		 * send flag for a particular iiu irregradless
		 * of what is requested here if piiu->pushPending
		 * is set
		 */
		count = cac_select_io(&timeout, CA_DO_RECVS);
		if (count<=0) {
			break;
		}
		ca_process_input_queue();
    }

	/*
	 * manage search timers and detect disconnects
	 */
	manage_conn();

	/*
	 * next check for pending writes's with the specified time out 
	 *
	 * ... but dont allow this to go on forever if a fast
	 * server is flooding a slow client with monitors ...
	 */
	countDown = 512u;
    timeout = *ptimeout;
    while (TRUE) {
		count = cac_select_io(&timeout, CA_DO_RECVS|CA_DO_SENDS);
		countDown--;
		if (count<=0 || countDown==0u) {
			/*
			 * if its a flush then loop until all
			 * of the send buffers are empty
			 */
			if (ca_static->ca_flush_pending) {
				/*
				 * complete flush is postponed if we are 
				 * inside an event routine 
				 */
				if (EVENTLOCKTEST) {
					break;
				}
				else {
					if (caSendMsgPending()) {
						countDown = 512u;
						LD_CA_TIME (cac_fetch_poll_period(), &timeout);
					}
					else {
						ca_static->ca_flush_pending = FALSE;
						break;
					}
				}
			}
			else {
				break;
			}
		}
		else {
			CLR_CA_TIME (&timeout);
		}
		ca_process_input_queue();

    }

	checkConnWatchdogs(iocCloseAllowed);
}


/*
 * caSendMsgPending()
 */
int caSendMsgPending()
{
	int                     pending = FALSE;
	unsigned long           bytesPending;
	struct ioc_in_use       *piiu;
	
	LOCK;
	for (piiu = (IIU *) ellFirst(&iiuList);
		piiu; piiu = (IIU *) ellNext(&piiu->node)){
		
		if(piiu == piiuCast){
			continue;
		}
		
		if (piiu->state == iiu_connected) {
			bytesPending = cacRingBufferReadSize(&piiu->send, FALSE);
			if(bytesPending > 0u){
				pending = TRUE;
			}
		}
	}
	UNLOCK;
	
	return pending;
}

