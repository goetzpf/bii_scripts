use Carp;
use unpackHashRef;

sub driverInit {
  local ($DESC, $CMD);
  &unpackHashRef;
  return <<EOF;
# ${DESC}
${CMD}
EOF
}

sub SUBST {
  $subst = shift @_;
  croak "SUBST needs to be called with a hash reference" if not ref $subst eq 'HASH';
  return '"' . join(",",map("$_=$subst->{$_}",keys(%$subst))) . '"';
}

sub restore {
  local ($SAV, $PASS, $SUBST);
  &unpackHashRef;
  $SUBST = ", " . SUBST($SUBST) if ref $SUBST eq 'HASH';
  return <<EOF;
# Restore channels for ${SAV} during pass ${PASS}
set_pass${PASS}_restoreFile("${SAV}.sav"${SUBST})
EOF
}

sub loadRecords {
  local ($DESC, $DB, $SUBST);
  &unpackHashRef;
  croak "SUBST needs to be a hash reference" if defined $SUBST and not ref $SUBST eq 'HASH';
  $SUBST = ", " . SUBST($SUBST) if ref $SUBST eq 'HASH';
  return <<EOF;
# Load ${DESC} database (flat)
dbLoadRecords("${DB}.db"${SUBST})
EOF
}

sub seq {
  local ($DESC, $ST, $SUBST);
  &unpackHashRef;
  croak "SUBST needs to be a hash reference" if defined $SUBST and not ref $SUBST eq 'HASH';
  $SUBST = ", " . SUBST($SUBST) if ref $SUBST eq 'HASH';
  return <<EOF;
# ${DESC} State Machine
seq &${ST}${SUBST}
EOF
}

sub request {
  local ($REQ, $RATE, $SUBST);
  &unpackHashRef;
  croak "SUBST needs to be a hash reference" if defined $SUBST and not ref $SUBST eq 'HASH';
  $SUBST = ", " . SUBST($SUBST) if ref $SUBST eq 'HASH';
  return <<EOF;
# Auto-save channels for ${REQ} every ${RATE} seconds
create_monitor_set("${REQ}.req", ${RATE}${SUBST})
EOF
}

sub nfs {
  local ($HOST, $UID, $GID);
  &unpackHashRef;
  if ($HOST) {
    return <<EOF;
# Add NFS host entry
hostAdd "nfshost", "${HOST}"
nfsAuthUnixSet "nfshost", ${UID}, ${GID}, 0, 0

# Mount "/opt/epics", "/opt/IOC" and "/opt/IOC/log" explicitly
nfsMount "nfshost", "/opt/IOC", "/opt/IOC"
nfsMount "nfshost", "/srv/IOC_log", "/srv/IOC_log"

cd index(getcwd(malloc(128),128),':')+1
EOF
  } else {
    return <<EOF;
# NFS not configured
EOF
  }
}

sub stcmd {
  local (
    $IOC,
    $FILEMODE,
    $DOMAIN,
    $DB_LOG_DIR,
    $SUPPORT,
    $LOG_DISABLE,
    $ASCF,
    $nfs,
    $version,
    $driverInit,
    $autosave,
    $loadRecords,
    $restore,
    $seq,
    $caPutLog,
    $request,
  );
  &unpackHashRef;
  $nfs = nfs($nfs);
  return <<EOF;
# vxWorks Startup File for ${IOC}
#
# This file was generated and should NOT be modified by hand!!!
#
############################################################# Network Settings

# Enable route to trs
routeAdd "192.168.31.0", "${ROUTER}"

${nfs}
# Log Servers
putenv "EPICS_IOC_LOG_INET=$iocLog->{HOST}"
$caPutLog->{USE}putenv "EPICS_CA_PUT_LOG_INET=$caPutLog->{HOST}"

################################################################# Version Info

pwd >${DB_LOG_DIR}/${IOC}.pwd
$version->{USE}copy "../version", "${DB_LOG_DIR}/${IOC}.version"

pwd
$version->{USE}copy "../version"

################################################################ Load Binaries

# Change dir to TOP/bin/<target_arch>
cd "../../bin"
cd epicsUsrOsTargetName()

ld < ${SUPPORT}

######################################################## Driver Initialization

${driverInit}
################################################ AutoSaveRestore Configuration

# Set directory for request files
set_requestfile_path("$autosave->{REQ_DIR}")

# Set directory for restore files
set_savefile_path("$autosave->{SAV_DIR}")

# Should dated backups of restore files be created?
save_restoreSet_DatedBackupFiles($autosave->{CREATE_DATED_BACKUPS})

# Do not use status PVs
save_restoreUseStatusPVs = 0

#################################################### Load Database Definitions

cd "../../dbd"

dbLoadDatabase("${IOC}.dbd")
${IOC}_registerRecordDeviceDriver(pdbbase)

############################################################### Load Databases

cd "../db"

${loadRecords}
############################################################# Autosave Restore

${restore}
########################################################### Configure IOC Core

# IOC Log Server Connection (0=enabled, 1=disabled)
iocLogDisable=$iocLog->{DISABLE}

# Set Access Security
asSetFilename("${ASCF}")

################################################################## Ignition...

# Initialize EPICS Core
iocInit

# Report Installed and Configured I/O-Hardware Information
dbior 0, 1 > ${DB_LOG_DIR}/${IOC}.dbior
dbhcr      > ${DB_LOG_DIR}/${IOC}.dbhcr
dbl        > ${DB_LOG_DIR}/${IOC}.dbl

############################################################### State Machines

${seq}
#################################################################### Post Init

# Start caPutLogging
$caPutLog->{USE}caPutLogInit(getenv("EPICS_CA_PUT_LOG_INET"), 1)

############################################################# Autosave Request

${request}
EOF
}
1;
