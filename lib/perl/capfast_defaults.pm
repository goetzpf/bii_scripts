package capfast_defaults;

# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


use strict;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.0;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw();
}

use vars      @EXPORT_OK;

# Note: the following hash was generated this way:
#"Sch2db.pl --dump_symfile -s /opt/csr/epics/R3.13.9/support/capfast/1-6/edif\
# > FILE
# the "FILE" was copied here with cut & paste 


our %rec_defaults = (
  'ecalc' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'calc',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'calculation',
    'CALC' => 'A+B+C',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'LOW' => '',
    'INPJ' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'egenSub' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'FTVB' => 'DOUBLE',
    'NOVF' => '1',
    'INPH' => '',
    'PHAS' => '',
    'UFA' => '',
    'INPI' => '',
    'UFVI' => '',
    'OUTH' => '',
    'UFVJ' => '',
    'INPC' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'DISS' => 'NO_ALARM',
    'OUTJ' => '',
    'UFE' => '',
    'INPA' => '',
    'UFVA' => '',
    'SDIS' => '',
    'FTVA' => 'DOUBLE',
    'INPB' => '',
    'OUTI' => '',
    'OUTC' => '',
    'UFVG' => '',
    'FTA' => 'DOUBLE',
    'NOVC' => '1',
    'UFF' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'UFJ' => '',
    'BRSV' => 'NO_ALARM',
    'FTG' => 'DOUBLE',
    'UFVF' => '',
    'FTE' => 'DOUBLE',
    'FTVC' => 'DOUBLE',
    'DESC' => 'General Subroutine Record',
    'FTVG' => 'DOUBLE',
    'FTJ' => 'DOUBLE',
    'FTH' => 'DOUBLE',
    'UFD' => '',
    'FTB' => 'DOUBLE',
    'UFVD' => '',
    'NOD' => '1',
    'NOE' => '1',
    'NOVG' => '1',
    'UFH' => '',
    'OUTE' => '',
    'FTD' => 'DOUBLE',
    'PREC' => '',
    'UFG' => '',
    'FTVF' => 'DOUBLE',
    'PRIO' => 'LOW',
    'OUTG' => '',
    'UFVH' => '',
    'UFVC' => '',
    'NOC' => '1',
    'NOVJ' => '1',
    'NOVA' => '1',
    'UFC' => '',
    'UFVB' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'genSub',
    'OUTD' => '',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'NOF' => '1',
    'FTVH' => 'DOUBLE',
    'NOA' => '1',
    'OUTB' => '',
    'NOG' => '1',
    'INPE' => '',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'NOB' => '1',
    'FTVD' => 'DOUBLE',
    'FLNK' => '',
    'NOVE' => '1',
    'OUTF' => '',
    'NOVH' => '1',
    'UFI' => '',
    'NOI' => '1',
    'NOJ' => '1',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'SNAM' => '',
    'INAM' => '',
    'LFLG' => 'IGNORE',
    'INPJ' => '',
    'OUTA' => '',
    'SUBL' => '',
    'ACKT' => 'YES',
    'NOH' => '1',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'FTI' => 'DOUBLE',
    'INPG' => ''
  },
  'ewaves' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'RARM' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveform',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveform',
    'INP' => ''
  },
  'embbom' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'IVOV' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'DOL' => '',
    'TTVL' => '',
    'OUT' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'IVOA' => 'Continue normally',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary output',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SVST' => '',
    'SIOL' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbo',
    'OMSL' => 'supervisory',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'FFSV' => 'NO_ALARM',
    'UNSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SVSV' => 'NO_ALARM',
    'TEST' => '',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES'
  },
  'ebim' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'binary input',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bi',
    'INP' => ''
  },
  'ecalcout' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'INPI' => '',
    'IVOV' => '',
    'ODLY' => '',
    'INPC' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPB' => '',
    'type' => 'calcout',
    'INPD' => '',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'OEVT' => '',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => '',
    'CALC' => '',
    'OOPT' => 'Every Time',
    'INPK' => '',
    'ADEL' => '',
    'TSEL' => '',
    'INPL' => '',
    'LOW' => '',
    'INPJ' => '',
    'OCAL' => '',
    'DOPT' => 'Use CALC',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'ewait' => {
    'INDP' => 'No',
    'SIOL' => '',
    'INLP' => 'No',
    'INHN' => ' ',
    'INCN' => ' ',
    'ASG' => '',
    'PHAS' => '',
    'ININ' => ' ',
    'INBN' => ' ',
    'PREC' => '',
    'SIMM' => 'NO',
    'INFP' => 'No',
    'INJP' => 'No',
    'INKP' => 'No',
    'ODLY' => '',
    'HOPR' => '',
    'INEP' => 'No',
    'INAP' => 'No',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'INJN' => ' ',
    'SIML' => '',
    'SDIS' => ' 0.000000000000000e+00',
    'MDEL' => '',
    'DOLD' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'INFN' => ' ',
    'type' => 'wait',
    'INIP' => 'No',
    'OUTN' => ' ',
    'INGN' => ' ',
    'INGP' => 'No',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'INDN' => ' ',
    'INCP' => 'No',
    'FLNK' => '',
    'INKN' => ' ',
    'INLN' => ' ',
    'DESC' => 'wait',
    'OOPT' => 'Every Time',
    'CALC' => 'A+B+C',
    'ADEL' => '',
    'INBP' => 'No',
    'INEN' => ' ',
    'SIMS' => 'NO_ALARM',
    'DOPT' => 'Use VAL',
    'INAN' => ' ',
    'ACKT' => 'YES',
    'INHP' => 'No'
  },
  'epals' => {
    'G1' => '0.9',
    'F0' => '0.1',
    'A1' => '0.9',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'C1' => '0.9',
    'L1' => '0.9',
    'PREC' => '',
    'INPI' => '',
    'INPC' => '',
    'J0' => '0.1',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'B1' => '0.9',
    'I0' => '0.1',
    'H1' => '0.9',
    'INPA' => '',
    'SDIS' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'J1' => '0.9',
    'INPD' => '',
    'type' => 'pal',
    'F1' => '0.9',
    'K1' => '0.9',
    'E0' => '0.1',
    'H0' => '0.1',
    'C0' => '0.1',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'E1' => '0.9',
    'JEDF' => 'jedfile',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => 'state',
    'L0' => '0.1',
    'B0' => '0.1',
    'DESC' => 'pal',
    'K0' => '0.1',
    'INPK' => '',
    'D1' => '0.9',
    'INPL' => '',
    'D0' => '0.1',
    'INPJ' => '',
    'ACKT' => 'YES',
    'A0' => '0.1',
    'G0' => '0.1',
    'INPG' => '',
    'I1' => '0.9'
  },
  'egenSubC' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'FTVB' => 'DOUBLE',
    'NOVF' => '1',
    'INPH' => '',
    'FTS' => 'DOUBLE',
    'NON' => '1',
    'PHAS' => '',
    'UFA' => '',
    'FTP' => 'DOUBLE',
    'FTQ' => 'DOUBLE',
    'FTVT' => 'DOUBLE',
    'UFVJ' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'UFE' => '',
    'UFVA' => '',
    'INPB' => '',
    'NOVK' => '1',
    'NOVU' => '1',
    'FTA' => 'DOUBLE',
    'NOVC' => '1',
    'SCAN' => 'Passive',
    'BRSV' => 'NO_ALARM',
    'NOVL' => '1',
    'NOP' => '1',
    'FTG' => 'DOUBLE',
    'FTE' => 'DOUBLE',
    'DESC' => 'General Subroutine Record',
    'FTVG' => 'DOUBLE',
    'UFVS' => '',
    'NOVN' => '1',
    'FTJ' => 'DOUBLE',
    'FTVR' => 'DOUBLE',
    'UFM' => '',
    'UFK' => '',
    'NOL' => '1',
    'UFVN' => '',
    'UFVR' => '',
    'FTB' => 'DOUBLE',
    'UFVO' => '',
    'UFVD' => '',
    'NOVG' => '1',
    'NOE' => '1',
    'PREC' => '',
    'UFG' => '',
    'UFVH' => '',
    'NOU' => '1',
    'NOC' => '1',
    'UFVB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'genSub',
    'FTVM' => 'DOUBLE',
    'UFQ' => '',
    'FTK' => 'DOUBLE',
    'UFVL' => '',
    'NOVO' => '1',
    'NOG' => '1',
    'NOB' => '1',
    'FLNK' => '',
    'FTVD' => 'DOUBLE',
    'UFP' => '',
    'UFS' => '',
    'NOVS' => '1',
    'NOI' => '1',
    'FTVP' => 'DOUBLE',
    'UFI' => '',
    'UFU' => '',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'LFLG' => 'IGNORE',
    'INAM' => '',
    'NOS' => '1',
    'INPJ' => '',
    'ACKT' => 'YES',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'FTI' => 'DOUBLE',
    'FTT' => 'DOUBLE',
    'UFR' => '',
    'NOO' => '1',
    'FTM' => 'DOUBLE',
    'FTVK' => 'DOUBLE',
    'INPT' => '',
    'UFVI' => '',
    'NOVP' => '1',
    'DISS' => 'NO_ALARM',
    'UFN' => '',
    'FTVN' => 'DOUBLE',
    'SDIS' => '',
    'FTVA' => 'DOUBLE',
    'FTVS' => 'DOUBLE',
    'UFL' => '',
    'NOVT' => '1',
    'UFVG' => '',
    'UFF' => '',
    'EVNT' => '',
    'UFJ' => '',
    'NOM' => '1',
    'UFVF' => '',
    'UFVT' => '',
    'NOVM' => '1',
    'FTVC' => 'DOUBLE',
    'INPP' => '',
    'UFVM' => '',
    'INPL' => '',
    'FTO' => 'DOUBLE',
    'FTH' => 'DOUBLE',
    'NOQ' => '1',
    'UFD' => '',
    'NOT' => '1',
    'NOD' => '1',
    'UFVU' => '',
    'UFH' => '',
    'FTD' => 'DOUBLE',
    'FTVL' => 'DOUBLE',
    'FTN' => 'DOUBLE',
    'NOK' => '1',
    'FTVF' => 'DOUBLE',
    'FTVQ' => 'DOUBLE',
    'NOR' => '1',
    'PRIO' => 'LOW',
    'UFVP' => '',
    'UFVC' => '',
    'UFT' => '',
    'NOVJ' => '1',
    'UFC' => '',
    'NOVA' => '1',
    'FTR' => 'DOUBLE',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'FTVU' => 'DOUBLE',
    'NOF' => '1',
    'NOA' => '1',
    'INPN' => '',
    'FTVE' => 'DOUBLE',
    'NOVR' => '1',
    'INPF' => '',
    'INPR' => '',
    'FTL' => 'DOUBLE',
    'NOVE' => '1',
    'NOVH' => '1',
    'NOJ' => '1',
    'FTVO' => 'DOUBLE',
    'UFVK' => '',
    'SNAM' => '',
    'SUBL' => '',
    'UFVQ' => '',
    'NOH' => '1'
  },
  'embbim' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'TTVL' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary input',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SVST' => '',
    'SIOL' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbi',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'INP' => ''
  },
  'ewaveouts' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HEAD' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveout',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveout',
    'OMSL' => 'supervisory'
  },
  'esub' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'sub',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'BRSV' => 'NO_ALARM',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'subroutine',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'SNAM' => '',
    'LOW' => '',
    'INPJ' => '',
    'INAM' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'epcnts' => {
    'CSIZ' => '32 bit',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'SGV' => 'Inactive',
    'SGL' => 'S0',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'GTYP' => 'Hardware',
    'DTYP' => 'Mizar 8310',
    'HGV' => '',
    'CNTE' => 'Rising Edge',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulseCounter',
    'PRIO' => 'LOW',
    'OUT' => '',
    'CNTS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'pulseCounter'
  },
  'epdlys' => {
    'ECS' => '',
    'EVNT' => '',
    'DLY' => '',
    'SCAN' => 'Passive',
    'STV' => 'Disable',
    'LOPR' => '',
    'STL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Mizar-8310',
    'UNIT' => 'Seconds',
    'PREC' => '',
    'HTS' => '',
    'TTYP' => 'Hardware',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulse delay',
    'PRIO' => 'LOW',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'GLNK' => '',
    'ECR' => '',
    'OUT' => '#C0 S0',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'CTYP' => 'Internal',
    'WIDE' => '',
    'type' => 'pulseDelay'
  },
  'etimer' => {
    'DUT4' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Mizar-8310',
    'PTST' => 'low',
    'OPW2' => '',
    'PREC' => '',
    'TIMU' => 'milliseconds',
    'OPW4' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'OUT' => '#C0 S0',
    'DUT3' => '',
    'SDIS' => '',
    'DISV' => '',
    'PINI' => 'NO',
    'type' => 'timer',
    'OPW1' => '',
    'PDLY' => '',
    'EVNT' => '',
    'OPW3' => '',
    'SCAN' => 'Passive',
    'DUT5' => '',
    'TORG' => '',
    'MAIN' => 'YES',
    'TSRC' => 'external',
    'DUT1' => '',
    'DUT2' => '',
    'FLNK' => '',
    'OPW5' => '',
    'DESC' => 'timer',
    'TEVT' => '',
    'ACKT' => 'YES'
  },
  'ebis' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'binary input',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bi',
    'INP' => ''
  },
  'egenSubD' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'FTVB' => 'DOUBLE',
    'NOVF' => '1',
    'INPH' => '',
    'FTS' => 'DOUBLE',
    'NON' => '1',
    'PHAS' => '',
    'UFA' => '',
    'INPQ' => '',
    'FTP' => 'DOUBLE',
    'FTQ' => 'DOUBLE',
    'OUTH' => '',
    'UFVJ' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'UFE' => '',
    'UFVA' => '',
    'INPB' => '',
    'OUTC' => '',
    'FTA' => 'DOUBLE',
    'NOVC' => '1',
    'SCAN' => 'Passive',
    'BRSV' => 'NO_ALARM',
    'NOP' => '1',
    'FTG' => 'DOUBLE',
    'FTE' => 'DOUBLE',
    'DESC' => 'General Subroutine Record',
    'FTVG' => 'DOUBLE',
    'INPM' => '',
    'FTJ' => 'DOUBLE',
    'UFM' => '',
    'UFK' => '',
    'NOL' => '1',
    'FTB' => 'DOUBLE',
    'UFVD' => '',
    'NOVG' => '1',
    'NOE' => '1',
    'OUTE' => '',
    'INPS' => '',
    'PREC' => '',
    'UFG' => '',
    'OUTG' => '',
    'UFVH' => '',
    'NOU' => '1',
    'NOC' => '1',
    'UFVB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'genSub',
    'UFQ' => '',
    'FTK' => 'DOUBLE',
    'INPE' => '',
    'NOG' => '1',
    'NOB' => '1',
    'FLNK' => '',
    'FTVD' => 'DOUBLE',
    'UFS' => '',
    'UFP' => '',
    'UFU' => '',
    'UFI' => '',
    'NOI' => '1',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOS' => '1',
    'LFLG' => 'IGNORE',
    'INAM' => '',
    'INPJ' => '',
    'INPO' => '',
    'ACKT' => 'YES',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'FTI' => 'DOUBLE',
    'INPG' => '',
    'FTT' => 'DOUBLE',
    'UFR' => '',
    'NOO' => '1',
    'FTM' => 'DOUBLE',
    'INPT' => '',
    'INPI' => '',
    'UFVI' => '',
    'INPC' => '',
    'DISS' => 'NO_ALARM',
    'OUTJ' => '',
    'UFN' => '',
    'INPA' => '',
    'SDIS' => '',
    'FTVA' => 'DOUBLE',
    'UFL' => '',
    'OUTI' => '',
    'UFVG' => '',
    'UFF' => '',
    'EVNT' => '',
    'UFJ' => '',
    'NOM' => '1',
    'UFVF' => '',
    'FTVC' => 'DOUBLE',
    'INPP' => '',
    'INPL' => '',
    'FTO' => 'DOUBLE',
    'FTH' => 'DOUBLE',
    'NOQ' => '1',
    'UFD' => '',
    'NOT' => '1',
    'NOD' => '1',
    'UFH' => '',
    'FTD' => 'DOUBLE',
    'FTN' => 'DOUBLE',
    'NOK' => '1',
    'FTVF' => 'DOUBLE',
    'NOR' => '1',
    'PRIO' => 'LOW',
    'UFVC' => '',
    'UFT' => '',
    'NOVJ' => '1',
    'NOVA' => '1',
    'FTR' => 'DOUBLE',
    'UFC' => '',
    'OUTD' => '',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'NOF' => '1',
    'FTVH' => 'DOUBLE',
    'OUTB' => '',
    'NOA' => '1',
    'INPN' => '',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'INPR' => '',
    'FTL' => 'DOUBLE',
    'NOVE' => '1',
    'OUTF' => '',
    'NOVH' => '1',
    'NOJ' => '1',
    'INPK' => '',
    'INPU' => '',
    'SNAM' => '',
    'OUTA' => '',
    'SUBL' => '',
    'NOH' => '1'
  },
  'ecalcouts' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'ODLY' => '',
    'IVOV' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'calcout',
    'INPD' => '',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'OEVT' => '',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => '',
    'OOPT' => 'Every Time',
    'CALC' => 'A+B+C',
    'INPK' => '',
    'ADEL' => '',
    'INPL' => '',
    'TSEL' => '',
    'LOW' => '',
    'INPJ' => '',
    'OCAL' => '',
    'DOPT' => 'Use CALC',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'ecomp' => {
    'IHIL' => '',
    'N' => '',
    'EVNT' => '',
    'NSAM' => '',
    'SCAN' => 'Passive',
    'ILIL' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'PRIO' => 'LOW',
    'DESC' => 'compression',
    'DISS' => 'NO_ALARM',
    'SDIS' => '',
    'ALG' => 'N to 1 Low Value',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'compress',
    'INP' => ''
  },
  'elongoutsim' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DRVH' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'estate' => {
    'DISS' => 'NO_ALARM',
    'DESC' => 'state',
    'PRIO' => 'LOW',
    'EVNT' => '',
    'VAL' => 'value',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'FLNK' => '',
    'type' => 'state'
  },
  'egenSubA' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'FTVB' => 'DOUBLE',
    'NOVF' => '1',
    'INPH' => '',
    'FTS' => 'DOUBLE',
    'NON' => '1',
    'PHAS' => '',
    'UFA' => '',
    'FTP' => 'DOUBLE',
    'FTQ' => 'DOUBLE',
    'OUTH' => '',
    'FTVT' => 'DOUBLE',
    'UFVJ' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'UFE' => '',
    'UFVA' => '',
    'INPB' => '',
    'NOVK' => '1',
    'NOVU' => '1',
    'FTA' => 'DOUBLE',
    'NOVC' => '1',
    'SCAN' => 'Passive',
    'BRSV' => 'NO_ALARM',
    'NOVL' => '1',
    'NOP' => '1',
    'FTG' => 'DOUBLE',
    'FTE' => 'DOUBLE',
    'DESC' => 'General Subroutine Record',
    'FTVG' => 'DOUBLE',
    'UFVS' => '',
    'NOVN' => '1',
    'FTJ' => 'DOUBLE',
    'FTVR' => 'DOUBLE',
    'UFM' => '',
    'UFK' => '',
    'NOL' => '1',
    'UFVN' => '',
    'UFVR' => '',
    'FTB' => 'DOUBLE',
    'UFVO' => '',
    'UFVD' => '',
    'NOVG' => '1',
    'NOE' => '1',
    'OUTP' => '',
    'PREC' => '',
    'UFG' => '',
    'UFVH' => '',
    'NOU' => '1',
    'NOC' => '1',
    'UFVB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'genSub',
    'FTVM' => 'DOUBLE',
    'UFQ' => '',
    'FTK' => 'DOUBLE',
    'OUTN' => '',
    'UFVL' => '',
    'NOVO' => '1',
    'NOG' => '1',
    'NOB' => '1',
    'FLNK' => '',
    'FTVD' => 'DOUBLE',
    'UFP' => '',
    'UFS' => '',
    'NOVS' => '1',
    'NOI' => '1',
    'FTVP' => 'DOUBLE',
    'UFI' => '',
    'UFU' => '',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'LFLG' => 'IGNORE',
    'INAM' => '',
    'NOS' => '1',
    'INPJ' => '',
    'ACKT' => 'YES',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'FTI' => 'DOUBLE',
    'FTT' => 'DOUBLE',
    'UFR' => '',
    'NOO' => '1',
    'FTM' => 'DOUBLE',
    'OUTT' => '',
    'FTVK' => 'DOUBLE',
    'INPT' => '',
    'UFVI' => '',
    'NOVP' => '1',
    'DISS' => 'NO_ALARM',
    'OUTJ' => '',
    'UFN' => '',
    'FTVN' => 'DOUBLE',
    'SDIS' => '',
    'OUTL' => '',
    'FTVA' => 'DOUBLE',
    'FTVS' => 'DOUBLE',
    'UFL' => '',
    'NOVT' => '1',
    'UFVG' => '',
    'UFF' => '',
    'EVNT' => '',
    'UFJ' => '',
    'NOM' => '1',
    'UFVF' => '',
    'UFVT' => '',
    'NOVM' => '1',
    'FTVC' => 'DOUBLE',
    'INPP' => '',
    'UFVM' => '',
    'INPL' => '',
    'FTO' => 'DOUBLE',
    'FTH' => 'DOUBLE',
    'NOQ' => '1',
    'UFD' => '',
    'NOT' => '1',
    'NOD' => '1',
    'UFVU' => '',
    'UFH' => '',
    'FTD' => 'DOUBLE',
    'FTVL' => 'DOUBLE',
    'FTN' => 'DOUBLE',
    'NOK' => '1',
    'FTVF' => 'DOUBLE',
    'FTVQ' => 'DOUBLE',
    'NOR' => '1',
    'PRIO' => 'LOW',
    'UFVC' => '',
    'UFVP' => '',
    'UFT' => '',
    'NOVJ' => '1',
    'UFC' => '',
    'NOVA' => '1',
    'FTR' => 'DOUBLE',
    'INPD' => '',
    'OUTD' => '',
    'FTF' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'FTVU' => 'DOUBLE',
    'NOF' => '1',
    'NOA' => '1',
    'INPN' => '',
    'OUTB' => '',
    'FTVE' => 'DOUBLE',
    'NOVR' => '1',
    'INPF' => '',
    'INPR' => '',
    'OUTR' => '',
    'FTL' => 'DOUBLE',
    'NOVE' => '1',
    'OUTF' => '',
    'NOVH' => '1',
    'NOJ' => '1',
    'FTVO' => 'DOUBLE',
    'UFVK' => '',
    'SNAM' => '',
    'SUBL' => '',
    'UFVQ' => '',
    'NOH' => '1'
  },
  'embbid' => {
    'BC' => '',
    'SIOL' => '',
    'B4' => '',
    'BB' => '',
    'B6' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'B1' => '',
    'NOBT' => '',
    'SDIS' => '',
    'SIML' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'mbbiDirect',
    'BE' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'FLNK' => '',
    'B8' => '',
    'B2' => '',
    'BF' => '',
    'B5' => '',
    'B0' => '',
    'DESC' => 'mbbiDirect',
    'B7' => '',
    'SIMS' => 'NO_ALARM',
    'B9' => '',
    'B3' => '',
    'BA' => '',
    'ACKT' => 'YES',
    'INP' => '',
    'BD' => ''
  },
  'eao' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'LINR' => 'NO CONVERSION',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'OUT' => '',
    'ASLO' => '',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'ao',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'AOFF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUF' => '',
    'EGUL' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'DRVL' => '',
    'OIF' => 'Full',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'ehwlowcals' => {
    'TMO' => '',
    'EVNT' => '',
    'MUX' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'BTYP' => '',
    'DTYP' => 'lowcal',
    'PHAS' => '',
    'CLAS' => '',
    'OBJI' => '',
    'FLNK' => '',
    'INHB' => '',
    'PORT' => '',
    'WNPM' => '',
    'WNPL' => '',
    'UTYP' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => '',
    'ATYP' => '',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'SDIS' => '',
    'OBJO' => '',
    'NELM' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'DLEN' => '',
    'type' => 'hwLowcal'
  },
  'embbi' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'TTVL' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary input',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SVST' => '',
    'SIOL' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbi',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'INP' => ''
  },
  'ewavesim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'RARM' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveform',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveform',
    'INP' => ''
  },
  'edfans' => {
    'LOLO' => '',
    'HIHI' => '',
    'K' => '',
    'E' => '',
    'ASG' => '',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'J' => '',
    'LLSV' => 'NO_ALARM',
    'B' => '',
    'H' => '',
    'SDIS' => '',
    'MDEL' => '',
    'SEL' => '',
    'D' => '',
    'I' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'G' => '',
    'type' => 'dfanout',
    'HSV' => 'NO_ALARM',
    'F' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'C' => '',
    'FLNK' => '',
    'L' => '',
    'EGU' => '',
    'A' => '',
    'DESC' => 'data fanout',
    'ADEL' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'esels' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'sel',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'NVL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'INPF' => '',
    'SELM' => 'Specified',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'selection',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'LOW' => '',
    'INPJ' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'egenSubB' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'FTVB' => 'DOUBLE',
    'NOVF' => '1',
    'INPH' => '',
    'FTS' => 'DOUBLE',
    'NON' => '1',
    'PHAS' => '',
    'UFA' => '',
    'FTP' => 'DOUBLE',
    'FTQ' => 'DOUBLE',
    'OUTH' => '',
    'FTVT' => 'DOUBLE',
    'UFVJ' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'UFE' => '',
    'UFVA' => '',
    'OUTS' => '',
    'INPB' => '',
    'NOVK' => '1',
    'OUTC' => '',
    'NOVU' => '1',
    'FTA' => 'DOUBLE',
    'OUTU' => '',
    'NOVC' => '1',
    'SCAN' => 'Passive',
    'BRSV' => 'NO_ALARM',
    'NOVL' => '1',
    'NOP' => '1',
    'FTG' => 'DOUBLE',
    'FTE' => 'DOUBLE',
    'DESC' => 'General Subroutine Record',
    'FTVG' => 'DOUBLE',
    'NOVN' => '1',
    'UFVS' => '',
    'FTJ' => 'DOUBLE',
    'OUTM' => '',
    'FTVR' => 'DOUBLE',
    'UFM' => '',
    'UFK' => '',
    'NOL' => '1',
    'UFVN' => '',
    'UFVR' => '',
    'FTB' => 'DOUBLE',
    'UFVO' => '',
    'UFVD' => '',
    'NOVG' => '1',
    'NOE' => '1',
    'OUTP' => '',
    'OUTE' => '',
    'PREC' => '',
    'UFG' => '',
    'OUTG' => '',
    'UFVH' => '',
    'NOU' => '1',
    'NOC' => '1',
    'UFVB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'genSub',
    'FTVM' => 'DOUBLE',
    'FTK' => 'DOUBLE',
    'UFQ' => '',
    'UFVL' => '',
    'OUTN' => '',
    'NOVO' => '1',
    'NOG' => '1',
    'NOB' => '1',
    'FTVD' => 'DOUBLE',
    'FLNK' => '',
    'UFP' => '',
    'UFS' => '',
    'NOVS' => '1',
    'NOI' => '1',
    'FTVP' => 'DOUBLE',
    'UFI' => '',
    'UFU' => '',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'LFLG' => 'IGNORE',
    'INAM' => '',
    'NOS' => '1',
    'INPJ' => '',
    'ACKT' => 'YES',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'FTI' => 'DOUBLE',
    'FTT' => 'DOUBLE',
    'UFR' => '',
    'NOO' => '1',
    'FTM' => 'DOUBLE',
    'OUTT' => '',
    'FTVK' => 'DOUBLE',
    'INPT' => '',
    'UFVI' => '',
    'NOVP' => '1',
    'DISS' => 'NO_ALARM',
    'OUTJ' => '',
    'UFN' => '',
    'FTVN' => 'DOUBLE',
    'SDIS' => '',
    'OUTL' => '',
    'FTVA' => 'DOUBLE',
    'FTVS' => 'DOUBLE',
    'UFL' => '',
    'NOVT' => '1',
    'OUTI' => '',
    'UFVG' => '',
    'UFF' => '',
    'EVNT' => '',
    'UFJ' => '',
    'NOM' => '1',
    'UFVF' => '',
    'UFVT' => '',
    'NOVM' => '1',
    'FTVC' => 'DOUBLE',
    'INPP' => '',
    'UFVM' => '',
    'INPL' => '',
    'FTO' => 'DOUBLE',
    'OUTQ' => '',
    'FTH' => 'DOUBLE',
    'NOQ' => '1',
    'UFD' => '',
    'NOT' => '1',
    'NOD' => '1',
    'OUTO' => '',
    'UFH' => '',
    'UFVU' => '',
    'FTD' => 'DOUBLE',
    'FTVL' => 'DOUBLE',
    'FTN' => 'DOUBLE',
    'NOK' => '1',
    'FTVF' => 'DOUBLE',
    'NOR' => '1',
    'FTVQ' => 'DOUBLE',
    'PRIO' => 'LOW',
    'UFVC' => '',
    'UFVP' => '',
    'UFT' => '',
    'NOVJ' => '1',
    'UFC' => '',
    'NOVA' => '1',
    'FTR' => 'DOUBLE',
    'INPD' => '',
    'OUTD' => '',
    'FTF' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'FTVU' => 'DOUBLE',
    'NOF' => '1',
    'NOA' => '1',
    'INPN' => '',
    'OUTB' => '',
    'FTVE' => 'DOUBLE',
    'NOVR' => '1',
    'INPF' => '',
    'INPR' => '',
    'OUTR' => '',
    'FTL' => 'DOUBLE',
    'NOVE' => '1',
    'OUTF' => '',
    'NOVH' => '1',
    'NOJ' => '1',
    'FTVO' => 'DOUBLE',
    'UFVK' => '',
    'SNAM' => '',
    'OUTA' => '',
    'SUBL' => '',
    'UFVQ' => '',
    'NOH' => '1',
    'OUTK' => ''
  },
  'eosc' => {
    'ATN4' => '1',
    'SIOL' => '',
    'CEN3' => '',
    'TLEV' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'OPR1' => '1',
    'PREC' => '',
    'EGUV' => 'Volt',
    'COU1' => 'Off',
    'CMS1' => 'Chan 1',
    'ATN2' => '1',
    'TTIM' => '1',
    'CEN2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'M1TP' => 'None',
    'MSOU' => 'Chan 1',
    'CEN1' => '',
    'COU2' => 'Off',
    'SIML' => '',
    'SDIS' => '',
    'OPR3' => '1',
    'COU3' => 'Off',
    'OPR4' => '1',
    'OPRH' => '1e-3',
    'TDLY' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'osc',
    'EGUH' => 'Second',
    'HCV1' => '',
    'ATN3' => '1',
    'M2TP' => 'None',
    'COU4' => 'Off',
    'ATN1' => '1',
    'EVNT' => '',
    'TSLP' => 'POS',
    'SCAN' => 'Passive',
    'CEN4' => '',
    'FLNK' => '',
    'HCV2' => '',
    'DESC' => 'osc',
    'TSOU' => 'Chan 1',
    'OPR2' => '1',
    'CMS2' => 'Chan 1',
    'SIMS' => 'NO_ALARM',
    'CMTP' => 'None',
    'VCV1' => '',
    'VCV2' => '',
    'ACKT' => 'YES',
    'INP' => ''
  },
  'estringoutsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'IVOV' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string output',
    'DOL' => '',
    'VAL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'stringout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally'
  },
  'ebisim' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'binary input',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bi',
    'INP' => ''
  },
  'ehist' => {
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DESC' => 'histogram',
    'LLIM' => '',
    'SVL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'ULIM' => '',
    'MDEL' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'SDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'histogram'
  },
  'efanouts' => {
    'LNK6' => '',
    'LNK3' => '',
    'EVNT' => '',
    'SELL' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'LNK5' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DESC' => 'fanout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'fanout',
    'LNK1' => ''
  },
  'elongins' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longin',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'estringins' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'eswfsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'RARM' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveform',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'swf',
    'INP' => ''
  },
  'ecomps' => {
    'IHIL' => '',
    'N' => '',
    'EVNT' => '',
    'NSAM' => '',
    'SCAN' => 'Passive',
    'ILIL' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'PRIO' => 'LOW',
    'DESC' => 'compression',
    'DISS' => 'NO_ALARM',
    'SDIS' => '',
    'ALG' => 'N to 1 Low Value',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'compress',
    'INP' => ''
  },
  'eptrns' => {
    'ECS' => '',
    'EVNT' => '',
    'DCY' => '',
    'SCAN' => 'Passive',
    'SGV' => 'Inactive',
    'SGL' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'GTYP' => 'Hardware',
    'HGV' => '',
    'UNIT' => 'Seconds',
    'PREC' => '',
    'PER' => '',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulse train',
    'PRIO' => 'LOW',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'ECR' => '',
    'OUT' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'CTYP' => 'Internal',
    'type' => 'pulseTrain'
  },
  'estep' => {
    'LOLO' => '',
    'MRES' => '',
    'HIHI' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Compumotor 1830',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'MODE' => 'Velocity',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'VELO' => '',
    'DOL' => '',
    'RTRY' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'steppermotor',
    'OMSL' => 'supervisory',
    'HSV' => 'NO_ALARM',
    'ACCL' => '',
    'CMOD' => 'Velocity',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'IALG' => 'No Initialization',
    'ERES' => '',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DIST' => '',
    'HLSV' => 'NO_ALARM',
    'IVAL' => '',
    'DRVH' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'steppermotor',
    'ADEL' => '',
    'RDBL' => '',
    'LOW' => '',
    'DRVL' => '',
    'RDBD' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'ehists' => {
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DESC' => 'histogram',
    'LLIM' => '',
    'SVL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'ULIM' => '',
    'MDEL' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'SDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'histogram'
  },
  'eaom' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'LINR' => 'NO CONVERSION',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'OUT' => '',
    'ASLO' => '',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'ao',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'AOFF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUF' => '',
    'EGUL' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'DRVL' => '',
    'OIF' => 'Full',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'eramps' => {
    'LOLO' => '',
    'BRCT' => '',
    'HIHI' => '',
    'ASG' => '',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'CVL' => '',
    'RACT' => 'NO',
    'IVOV' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'LLIM' => '',
    'CCNT' => '',
    'SDIS' => '',
    'OUTL' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'RALG' => 'Direct',
    'type' => 'ramp',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'STPL' => '',
    'APPR' => 'Above',
    'EVNT' => '',
    'SDLY' => '',
    'SCAN' => 'Passive',
    'IALG' => 'Bumpless',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DBND' => '',
    'HLIM' => '',
    'FLNK' => '',
    'EGU' => 'Amps',
    'OVER' => '',
    'PDNV' => '1',
    'DESC' => 'ramp',
    'IOCV' => '',
    'LRL' => '',
    'ADEL' => '',
    'IFST' => '',
    'SMSL' => 'supervisory',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'IRBA' => 'Continue normally'
  },
  'embbos' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'IVOV' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'DOL' => '',
    'TTVL' => '',
    'OUT' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'IVOA' => 'Continue normally',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary output',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SVST' => '',
    'SIOL' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbo',
    'OMSL' => 'supervisory',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'FFSV' => 'NO_ALARM',
    'UNSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SVSV' => 'NO_ALARM',
    'TEST' => '',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES'
  },
  'eptrn' => {
    'ECS' => '',
    'EVNT' => '',
    'DCY' => '',
    'SCAN' => 'Passive',
    'SGV' => 'Inactive',
    'SGL' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'GTYP' => 'Hardware',
    'HGV' => '',
    'UNIT' => 'Seconds',
    'PREC' => '',
    'PER' => '',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulse train',
    'PRIO' => 'LOW',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'ECR' => '',
    'OUT' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'CTYP' => 'Internal',
    'type' => 'pulseTrain'
  },
  'eai' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'HOPR' => '',
    'LINR' => 'LINEAR',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'ai',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog input',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'eaim' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'HOPR' => '',
    'LINR' => 'LINEAR',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'ai',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog input',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'hwout' => {
    'val(outp)' => '#C0 S0'
  },
  'embbosim' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'IVOV' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'DOL' => '',
    'TTVL' => '',
    'OUT' => '',
    'ELVL' => '',
    'SIML' => '',
    'SDIS' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'IVOA' => 'Continue normally',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary output',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SIOL' => '',
    'SVST' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbo',
    'OMSL' => 'supervisory',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'FFSV' => 'NO_ALARM',
    'UNSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SVSV' => 'NO_ALARM',
    'TEST' => '',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES'
  },
  'esubarray' => {
    'INDX' => '',
    'MALM' => '1',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'TSEL' => '',
    'SDIS' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'subArray',
    'INP' => ''
  },
  'elongin' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longin',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'etimers' => {
    'DUT4' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Mizar-8310',
    'PTST' => 'low',
    'OPW2' => '',
    'PREC' => '',
    'TIMU' => 'milliseconds',
    'OPW4' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'OUT' => '#C0 S0',
    'DUT3' => '',
    'SDIS' => '',
    'DISV' => '',
    'PINI' => 'NO',
    'type' => 'timer',
    'OPW1' => '',
    'PDLY' => '',
    'EVNT' => '',
    'OPW3' => '',
    'SCAN' => 'Passive',
    'DUT5' => '',
    'TORG' => '',
    'MAIN' => 'YES',
    'TSRC' => 'external',
    'DUT1' => '',
    'DUT2' => '',
    'FLNK' => '',
    'OPW5' => '',
    'DESC' => 'timer',
    'TEVT' => '',
    'ACKT' => 'YES'
  },
  'ebo' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'binary output',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bo',
    'OMSL' => 'supervisory',
    'HIGH' => '',
    'IVOA' => 'Continue normally'
  },
  'ebosim' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'binary output',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bo',
    'OMSL' => 'supervisory',
    'HIGH' => '',
    'IVOA' => 'Continue normally'
  },
  'elongout' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DRVH' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'eramp' => {
    'LOLO' => '',
    'BRCT' => '',
    'PDNL' => '',
    'HIHI' => '',
    'ASG' => '',
    'PHAS' => '',
    'CVL' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'RACT' => 'NO',
    'IVOV' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'LLIM' => '',
    'CCNT' => '',
    'SDIS' => '',
    'OUTL' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'RALG' => 'Direct',
    'type' => 'ramp',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'STPL' => '',
    'RMOD' => 'Closed Loop',
    'APPR' => 'Above',
    'EVNT' => '',
    'IALG' => 'Bumpless',
    'SDLY' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DBND' => '',
    'HLIM' => '',
    'FLNK' => '',
    'EGU' => 'Amps',
    'OVER' => '',
    'PDNV' => '1',
    'DESC' => 'ramp',
    'IOCV' => '',
    'LRL' => '',
    'ADEL' => '',
    'IFST' => '',
    'SMSL' => 'supervisory',
    'LOW' => '',
    'MDLT' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'IRBA' => 'Continue normally'
  },
  'estringin' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'embbo' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'FFVL' => '',
    'IVOV' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'FFST' => '',
    'TTVL' => '',
    'OUT' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'IVOA' => 'Continue normally',
    'ELST' => '',
    'EIVL' => '',
    'EIST' => '',
    'ELSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary output',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SIOL' => '',
    'SVST' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'EISV' => 'NO_ALARM',
    'TEVL' => '',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'mbbo',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'FFSV' => 'NO_ALARM',
    'UNSV' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES'
  },
  'epids' => {
    'LOLO' => '',
    'HIHI' => '',
    'KI' => '',
    'ASG' => '',
    'PHAS' => '',
    'CVL' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'SDIS' => '',
    'MDEL' => '',
    'KD' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pid',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'STPL' => '',
    'EVNT' => '',
    'MDT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'KP' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'pid',
    'ODEL' => '',
    'ADEL' => '',
    'SMSL' => 'supervisory',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'elogic' => {
    'I8L' => '',
    'IDL' => '',
    'EVNT' => '',
    'LTID' => 'table',
    'SCAN' => 'Passive',
    'I5L' => '',
    'ASG' => '',
    'PHAS' => '',
    'I0L' => '',
    'I6L' => '',
    'I7L' => '',
    'I9L' => '',
    'IEL' => '',
    'FLNK' => '',
    'I2L' => '',
    'I3L' => '',
    'I4L' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'LOGIC',
    'I1L' => '',
    'ICL' => '',
    'IAL' => '',
    'IBL' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'IFL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'logic'
  },
  'elonginsim' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'LLSV' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longin',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'embbis' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'TTVL' => '',
    'ELVL' => '',
    'SDIS' => '',
    'SIML' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary input',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SVST' => '',
    'SIOL' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbbi',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'INP' => ''
  },
  'embbods' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'mbboDirect',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'NOBT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'OMSL' => 'supervisory',
    'type' => 'mbboDirect',
    'IVOA' => 'Continue normally'
  },
  'estringout' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'IVOV' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string output',
    'DOL' => '',
    'VAL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'stringout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally'
  },
  'ebi' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'binary input',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bi',
    'INP' => ''
  },
  'escan' => {
    'D4PV' => ' ',
    'R3PV' => ' ',
    'MPTS' => '100',
    'R1PV' => ' ',
    'ASG' => '',
    'PHAS' => '',
    'D1PV' => ' ',
    'P1PV' => ' ',
    'PREC' => '2',
    'P2SI' => '0.1',
    'PRIO' => 'HIGH',
    'DISS' => 'NO_ALARM',
    'P1LR' => '',
    'T1PV' => ' ',
    'SDIS' => '',
    'P2SP' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'P1PR' => '1',
    'FFO' => 'Use F-Flags',
    'type' => 'scan',
    'T4PV' => ' ',
    'P1HR' => '',
    'NPTS' => '100',
    'EVNT' => '',
    'R1DL' => '',
    'SCAN' => 'Passive',
    'T3PV' => ' ',
    'PASM' => 'Stay',
    'D3PV' => ' ',
    'P1SP' => '',
    'P2LR' => '',
    'T2PV' => ' ',
    'FLNK' => ' 0.000000000000000e+0',
    'PROC' => '',
    'P4PV' => ' ',
    'R2DL' => '',
    'P2PR' => '1',
    'DESC' => 'scan',
    'FPTS' => 'Freeze',
    'R2PV' => ' ',
    'P1EP' => '',
    'P3PV' => ' ',
    'R4PV' => ' ',
    'P1SI' => '0.1',
    'P2HR' => '',
    'P2PV' => ' ',
    'R3DL' => '',
    'ACKT' => 'YES',
    'P2EP' => '',
    'D2PV' => ' ',
    'R4DL' => ''
  },
  'epulses' => {
    'CLKR' => '1000000',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Camac',
    'MINT' => '',
    'PREC' => '2',
    'SDOF' => '',
    'TVLO' => '',
    'MAXD' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'OUT' => '',
    'ENV' => 'Enable',
    'SDIS' => '',
    'MAXW' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'pulse',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'STL' => '',
    'TLOG' => 'None',
    'UNIT' => 'nSec',
    'TSRC' => 'Hardware',
    'FLNK' => '',
    'DESC' => 'pulse output',
    'ENL' => '',
    'TMOD' => 'Rising Edge',
    'MAXT' => '',
    'ACKT' => 'YES',
    'MIND' => '',
    'MINW' => '',
    'TVHI' => ''
  },
  'esel' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'sel',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'NVL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'INPF' => '',
    'SELM' => 'Specified',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'selection',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'LOW' => '',
    'INPJ' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'emotor' => {
    'LOLO' => '',
    'S' => '',
    'DHLM' => '',
    'MRES' => '',
    'TWV' => '',
    'BVEL' => '',
    'HIHI' => '',
    'DTYP' => 'OMS VME8/44',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'HLM' => '',
    'SBAS' => '',
    'URIP' => 'No',
    'BDST' => '',
    'SBAK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'VELO' => '',
    'DLLM' => '',
    'VBAS' => '',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'RTRY' => '10',
    'RRES' => '',
    'OUT' => '',
    'RLNK' => '',
    'SDIS' => '',
    'FRAC' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'motor',
    'LLM' => '',
    'UEIP' => 'No',
    'ACCL' => '0.2',
    'HSV' => 'NO_ALARM',
    'DIR' => 'Pos',
    'EVNT' => '',
    'DLY' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'ERES' => '',
    'HOMH' => '',
    'HLSV' => 'NO_ALARM',
    'HENC' => '',
    'FLNK' => '',
    'BACC' => '0.5',
    'EGU' => '',
    'DESC' => 'motor record',
    'FOFF' => 'Variable',
    'SREV' => '200',
    'RDBL' => '',
    'LOW' => '',
    'UREV' => '',
    'RDBD' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'OFF' => ''
  },
  'eseq' => {
    'DOL8' => '',
    'SELL' => '',
    'DLYA' => '',
    'ASG' => '',
    'PHAS' => '',
    'LNK5' => '',
    'PREC' => '',
    'DOL1' => '',
    'DLY2' => '',
    'LNK7' => '',
    'LNK4' => '',
    'DOL9' => '',
    'LNK2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL7' => '',
    'DLY3' => '',
    'DLY9' => '',
    'DOL3' => '',
    'LNK8' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'DOL5' => '',
    'type' => 'seq',
    'LNK1' => '',
    'DLY6' => '',
    'DLY7' => '',
    'LNK6' => '',
    'LNK3' => '',
    'DOLA' => '',
    'EVNT' => '',
    'DLY8' => '',
    'SCAN' => 'Passive',
    'DOL2' => '',
    'LNKA' => '',
    'DLY5' => '',
    'SELM' => 'All',
    'LNK9' => '',
    'FLNK' => '',
    'DOL6' => '',
    'DLY1' => '',
    'DESC' => 'sequence',
    'DLY4' => '',
    'DOL4' => '',
    'ACKT' => 'YES'
  },
  'epal' => {
    'G1' => '0.9',
    'F0' => '0.1',
    'A1' => '0.9',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'C1' => '0.9',
    'L1' => '0.9',
    'PREC' => '',
    'INPI' => '',
    'INPC' => '',
    'J0' => '0.1',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'B1' => '0.9',
    'I0' => '0.1',
    'H1' => '0.9',
    'INPA' => '',
    'SDIS' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'J1' => '0.9',
    'INPD' => '',
    'type' => 'pal',
    'F1' => '0.9',
    'K1' => '0.9',
    'E0' => '0.1',
    'H0' => '0.1',
    'C0' => '0.1',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'E1' => '0.9',
    'JEDF' => 'jedfile',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => 'state',
    'L0' => '0.1',
    'B0' => '0.1',
    'DESC' => 'pal',
    'K0' => '0.1',
    'INPK' => '',
    'INPL' => '',
    'D1' => '0.9',
    'D0' => '0.1',
    'INPJ' => '',
    'ACKT' => 'YES',
    'A0' => '0.1',
    'G0' => '0.1',
    'INPG' => '',
    'I1' => '0.9'
  },
  'eaosim' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'LINR' => 'NO CONVERSION',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'OUT' => '',
    'ASLO' => '',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'ao',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'AOFF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUF' => '',
    'EGUL' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'DRVL' => '',
    'OIF' => 'Full',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'epcnt' => {
    'CSIZ' => '32 bit',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'SGV' => 'Inactive',
    'SGL' => 'S0',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'GTYP' => 'Hardware',
    'DTYP' => 'Mizar 8310',
    'HGV' => '',
    'CNTE' => 'Rising Edge',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulseCounter',
    'PRIO' => 'LOW',
    'OUT' => '',
    'CNTS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'pulseCounter'
  },
  'eseqs' => {
    'DOL8' => '',
    'SELL' => '',
    'DLYA' => '',
    'ASG' => '',
    'PHAS' => '',
    'LNK5' => '',
    'PREC' => '',
    'DOL1' => '',
    'DLY2' => '',
    'LNK7' => '',
    'LNK4' => '',
    'DOL9' => '',
    'LNK2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL7' => '',
    'DLY3' => '',
    'DLY9' => '',
    'DOL3' => '',
    'LNK8' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'DOL5' => '',
    'type' => 'seq',
    'LNK1' => '',
    'DLY6' => '',
    'DLY7' => '',
    'LNK6' => '',
    'LNK3' => '',
    'DOLA' => '',
    'EVNT' => '',
    'DLY8' => '',
    'SCAN' => 'Passive',
    'DOL2' => '',
    'LNKA' => '',
    'DLY5' => '',
    'SELM' => 'All',
    'LNK9' => '',
    'FLNK' => '',
    'DOL6' => '',
    'DLY1' => '',
    'DESC' => 'sequence',
    'DLY4' => '',
    'DOL4' => '',
    'ACKT' => 'YES'
  },
  'eaos' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'LINR' => 'NO CONVERSION',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OROC' => '',
    'OUT' => '',
    'ASLO' => '',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'ao',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'AOFF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUF' => '',
    'EGUL' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'DRVL' => '',
    'OIF' => 'Full',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'eevent' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'event',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'ACKT' => 'YES',
    'type' => 'event',
    'INP' => ''
  },
  'emai' => {
    'SIOL' => '',
    'ASG' => '',
    'ASLO4' => '1',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'AOFF3' => '',
    'SMOO3' => '',
    'ASLO1' => '1',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'EGUL1' => '',
    'PINI' => 'NO',
    'LINR4' => 'NO CONVERSION',
    'DISV' => '1',
    'type' => 'mai',
    'EGUL4' => '',
    'SMOO1' => '',
    'AOFF1' => '',
    'AOFF4' => '',
    'ASLO3' => '1',
    'EVNT' => '',
    'LINR3' => 'NO CONVERSION',
    'SCAN' => 'Passive',
    'AOFF2' => '',
    'LINR2' => 'NO CONVERSION',
    'FLNK' => '',
    'EGUL3' => '',
    'DESC' => '',
    'SMOO4' => '',
    'EGUF2' => '',
    'LINR1' => 'NO CONVERSION',
    'EGUF3' => '',
    'TSEL' => '',
    'SIMS' => 'NO_ALARM',
    'ASLO2' => '1',
    'EGUF4' => '',
    'SMOO2' => '',
    'EGUL2' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'EGUF1' => '',
    'INP' => ''
  },
  'ewave' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'RARM' => '',
    'LOPR' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveform',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveform',
    'INP' => ''
  },
  'ewaveout' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HEAD' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveout',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveout',
    'OMSL' => 'supervisory'
  },
  'estates' => {
    'DISS' => 'NO_ALARM',
    'DESC' => 'state',
    'PRIO' => 'LOW',
    'EVNT' => '',
    'VAL' => 'value',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'FLNK' => '',
    'type' => 'state'
  },
  'esteps' => {
    'LOLO' => '',
    'MRES' => '',
    'HIHI' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Compumotor 1830',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'MODE' => 'Velocity',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'VELO' => '',
    'DOL' => '',
    'RTRY' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'steppermotor',
    'OMSL' => 'supervisory',
    'HSV' => 'NO_ALARM',
    'ACCL' => '',
    'CMOD' => 'Velocity',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'IALG' => 'No Initialization',
    'ERES' => '',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DIST' => '',
    'HLSV' => 'NO_ALARM',
    'IVAL' => '',
    'DRVH' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'steppermotor',
    'ADEL' => '',
    'RDBL' => '',
    'LOW' => '',
    'DRVL' => '',
    'RDBD' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'epid' => {
    'LOLO' => '',
    'HIHI' => '',
    'KI' => '',
    'ASG' => '',
    'PHAS' => '',
    'CVL' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'SDIS' => '',
    'MDEL' => '',
    'KD' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pid',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'STPL' => '',
    'EVNT' => '',
    'MDT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'KP' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'pid',
    'ODEL' => '',
    'ADEL' => '',
    'SMSL' => 'supervisory',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'elongouts' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'longout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DRVH' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'epulse' => {
    'CLKR' => '1000000',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Camac',
    'MINT' => '',
    'PREC' => '2',
    'SDOF' => '',
    'TVLO' => '',
    'MAXD' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'OUT' => '',
    'ENV' => 'Enable',
    'SDIS' => '',
    'MAXW' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'pulse',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'STL' => '',
    'TLOG' => 'None',
    'UNIT' => 'nSec',
    'TSRC' => 'Hardware',
    'FLNK' => '',
    'DESC' => 'pulse output',
    'ENL' => '',
    'TMOD' => 'Rising Edge',
    'MAXT' => '',
    'ACKT' => 'YES',
    'MIND' => '',
    'MINW' => '',
    'TVHI' => ''
  },
  'embbod' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'mbboDirect',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'NOBT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'OMSL' => 'supervisory',
    'type' => 'mbboDirect',
    'IVOA' => 'Continue normally'
  },
  'ecalcs' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'calc',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'calculation',
    'CALC' => 'A+B+C',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'LOW' => '',
    'INPJ' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'estringinsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'hwin' => {
    'val(in)' => '#C0 S0'
  },
  'ebos' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'binary output',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bo',
    'OMSL' => 'supervisory',
    'HIGH' => '',
    'IVOA' => 'Continue normally'
  },
  'ewaveoutsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HEAD' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'waveout',
    'OMSL' => 'supervisory'
  },
  'eoscs' => {
    'ATN4' => '1',
    'SIOL' => '',
    'CEN3' => '',
    'TLEV' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'OPR1' => '1',
    'PREC' => '',
    'EGUV' => 'Volt',
    'COU1' => 'Off',
    'CMS1' => 'Chan 1',
    'ATN2' => '1',
    'TTIM' => '1',
    'CEN2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'M1TP' => 'None',
    'MSOU' => 'Chan 1',
    'CEN1' => '',
    'COU2' => 'Off',
    'SIML' => '',
    'SDIS' => '',
    'OPR3' => '1',
    'COU3' => 'Off',
    'OPR4' => '1',
    'OPRH' => '1e-3',
    'TDLY' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'osc',
    'EGUH' => 'Second',
    'HCV1' => '',
    'ATN3' => '1',
    'M2TP' => 'None',
    'COU4' => 'Off',
    'ATN1' => '1',
    'EVNT' => '',
    'TSLP' => 'POS',
    'SCAN' => 'Passive',
    'CEN4' => '',
    'FLNK' => '',
    'HCV2' => '',
    'DESC' => 'osc',
    'TSOU' => 'Chan 1',
    'OPR2' => '1',
    'CMS2' => 'Chan 1',
    'SIMS' => 'NO_ALARM',
    'CMTP' => 'None',
    'VCV1' => '',
    'VCV2' => '',
    'ACKT' => 'YES',
    'INP' => ''
  },
  'efanout' => {
    'LNK6' => '',
    'LNK3' => '',
    'EVNT' => '',
    'SELL' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'LNK5' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DESC' => 'fanout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'fanout',
    'LNK1' => ''
  },
  'ew2mask' => {
    'LOLO' => '',
    'IN7' => '',
    'HIHI' => '',
    'SIOL' => '',
    'IN4' => '',
    'IN2' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'INE' => '',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'INC' => '',
    'IN6' => '',
    'OUT' => '0.000000000000000e+00 ',
    'IN1' => '',
    'INB' => '',
    'BTCH' => '',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'w2mask ',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'IN5' => '',
    'INF' => '',
    'IN9' => '',
    'FLNK' => '',
    'EGU' => '',
    'IN8' => '',
    'DESC' => 'word to mask',
    'FOFF' => '',
    'IN3' => '',
    'INA' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'FON' => '',
    'LOW' => '',
    'IN0' => '',
    'ACKT' => 'YES',
    'IND' => '',
    'HIGH' => ''
  },
  'ew2masks' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'w2mask ',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'word to mask',
    'FOFF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'FON' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => ''
  },
  'ebom' => {
    'SIOL' => '',
    'EVNT' => '',
    'ZSV' => 'NO_ALARM',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ONAM' => 'disabled',
    'FLNK' => '',
    'IVOV' => '',
    'DESC' => 'binary output',
    'ZNAM' => 'enabled',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'OSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'COSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'bo',
    'OMSL' => 'supervisory',
    'HIGH' => '',
    'IVOA' => 'Continue normally'
  },
  'edfan' => {
    'LOLO' => '',
    'HIHI' => '',
    'K' => '',
    'E' => '',
    'ASG' => '',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'J' => '',
    'LLSV' => 'NO_ALARM',
    'B' => '',
    'H' => '',
    'SDIS' => '',
    'MDEL' => '',
    'SEL' => '',
    'D' => '',
    'I' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'G' => '',
    'type' => 'dfanout',
    'HSV' => 'NO_ALARM',
    'F' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'C' => '',
    'FLNK' => '',
    'L' => '',
    'EGU' => '',
    'A' => '',
    'DESC' => 'data fanout',
    'ADEL' => '',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'eperms' => {
    'DISS' => 'NO_ALARM',
    'DESC' => 'permissive',
    'PRIO' => 'LOW',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LABL' => 'label',
    'ASG' => '',
    'PHAS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'FLNK' => '',
    'type' => 'permissive'
  },
  'eais' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'HOPR' => '',
    'LINR' => 'LINEAR',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'ai',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog input',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'eevents' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'event',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'ACKT' => 'YES',
    'type' => 'event',
    'INP' => ''
  },
  'estringouts' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FLNK' => '',
    'IVOV' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string output',
    'DOL' => '',
    'VAL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'stringout',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally'
  },
  'emotors' => {
    'LOLO' => '',
    'S' => '',
    'DHLM' => '',
    'MRES' => '',
    'TWV' => '',
    'BVEL' => '',
    'HIHI' => '',
    'DTYP' => 'OMS VME8/44',
    'PHAS' => '',
    'LSV' => 'NO_ALARM',
    'PREC' => '',
    'HLM' => '',
    'SBAS' => '',
    'URIP' => 'No',
    'BDST' => '',
    'SBAK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'VELO' => '',
    'DLLM' => '',
    'VBAS' => '',
    'DOL' => '',
    'LLSV' => 'NO_ALARM',
    'RTRY' => '10',
    'RRES' => '',
    'OUT' => '',
    'RLNK' => '',
    'SDIS' => '',
    'FRAC' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'motor',
    'LLM' => '',
    'UEIP' => 'No',
    'ACCL' => '0.2',
    'HSV' => 'NO_ALARM',
    'DIR' => 'Pos',
    'EVNT' => '',
    'DLY' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'ERES' => '',
    'HOMH' => '',
    'HLSV' => 'NO_ALARM',
    'HENC' => '',
    'FLNK' => '',
    'BACC' => '0.5',
    'EGU' => '',
    'DESC' => 'motor record',
    'FOFF' => 'Variable',
    'SREV' => '200',
    'RDBL' => '',
    'LOW' => '',
    'UREV' => '',
    'RDBD' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'OFF' => ''
  },
  'embbids' => {
    'BC' => '',
    'SIOL' => '',
    'B4' => '',
    'BB' => '',
    'B6' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'B1' => '',
    'NOBT' => '',
    'SDIS' => '',
    'SIML' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'mbbiDirect',
    'BE' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'FLNK' => '',
    'B8' => '',
    'B2' => '',
    'BF' => '',
    'B5' => '',
    'B0' => '',
    'DESC' => 'mbbiDirect',
    'B7' => '',
    'SIMS' => 'NO_ALARM',
    'B9' => '',
    'B3' => '',
    'BA' => '',
    'ACKT' => 'YES',
    'INP' => '',
    'BD' => ''
  },
  'eaisim' => {
    'LOLO' => '',
    'HIHI' => '',
    'SIOL' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'HOPR' => '',
    'LINR' => 'LINEAR',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'ai',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog input',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INP' => ''
  },
  'epdly' => {
    'ECS' => '',
    'EVNT' => '',
    'DLY' => '',
    'SCAN' => 'Passive',
    'STV' => 'Disable',
    'LOPR' => '',
    'STL' => '',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Mizar-8310',
    'UNIT' => 'Seconds',
    'PREC' => '',
    'HTS' => '',
    'TTYP' => 'Hardware',
    'FLNK' => '',
    'HOPR' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'pulse delay',
    'PRIO' => 'LOW',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'GLNK' => '',
    'ECR' => '',
    'OUT' => '#C0 S0',
    'SDIS' => '',
    'ACKT' => 'YES',
    'PINI' => 'NO',
    'DISV' => '1',
    'CTYP' => 'Internal',
    'WIDE' => '',
    'type' => 'pulseDelay'
  },
  'eperm' => {
    'DISS' => 'NO_ALARM',
    'DESC' => 'permissive',
    'PRIO' => 'LOW',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LABL' => 'label',
    'ASG' => '',
    'PHAS' => '',
    'SDIS' => '',
    'ACKT' => 'YES',
    'DISV' => '1',
    'PINI' => 'NO',
    'FLNK' => '',
    'type' => 'permissive'
  },
  'esubs' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'ASG' => '',
    'PHAS' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'INPI' => '',
    'INPC' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'INPA' => '',
    'SDIS' => '',
    'MDEL' => '',
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'sub',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'INPE' => '',
    'BRSV' => 'NO_ALARM',
    'INPF' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'subroutine',
    'INPK' => '',
    'INPL' => '',
    'ADEL' => '',
    'SNAM' => '',
    'LOW' => '',
    'INPJ' => '',
    'INAM' => '',
    'ACKT' => 'YES',
    'HIGH' => '',
    'INPG' => ''
  },
  'embbisim' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'FVVL' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'ASG' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'FFVL' => '',
    'NIST' => '',
    'DISS' => 'NO_ALARM',
    'FFST' => '',
    'TTVL' => '',
    'ELVL' => '',
    'SIML' => '',
    'SDIS' => '',
    'TTSV' => 'NO_ALARM',
    'THST' => '',
    'ELST' => '',
    'EIVL' => '',
    'ELSV' => 'NO_ALARM',
    'EIST' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ONSV' => 'NO_ALARM',
    'TVSV' => 'NO_ALARM',
    'TWST' => '',
    'TESV' => 'NO_ALARM',
    'FTST' => '',
    'DESC' => 'multibit binary input',
    'THVL' => '',
    'TTST' => '',
    'ZRST' => '',
    'FVST' => '',
    'NIVL' => '',
    'FRVL' => '',
    'TVVL' => '',
    'NISV' => 'NO_ALARM',
    'COSV' => 'NO_ALARM',
    'SIOL' => '',
    'SVST' => '',
    'SVVL' => '',
    'ZRVL' => '',
    'FRST' => '',
    'SXST' => '',
    'FTVL' => '',
    'TEVL' => '',
    'EISV' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'NOBT' => '',
    'TVST' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'mbbi',
    'FVSV' => 'NO_ALARM',
    'FLNK' => '',
    'ONVL' => '',
    'FTSV' => 'NO_ALARM',
    'TWVL' => '',
    'SXVL' => '',
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'ACKT' => 'YES',
    'INP' => ''
  }
);
our %rec_linkable_fields = (
  'ecalc' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'egenSub' => {
    'OUTC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SUBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ewaves' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'embbom' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ebim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ecalcout' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'TSEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ewait' => {
    'INGN' => {
      'dummy' => 1
    },
    'OUTN' => {
      'dummy' => 1
    },
    'INHN' => {
      'dummy' => 1
    },
    'INJN' => {
      'dummy' => 1
    },
    'INCN' => {
      'dummy' => 1
    },
    'INDN' => {
      'dummy' => 1
    },
    'INEN' => {
      'dummy' => 1
    },
    'ININ' => {
      'dummy' => 1
    },
    'INBN' => {
      'dummy' => 1
    },
    'SDIS' => {
      'proc' => ' NPP',
      'dummy' => 1
    },
    'INAN' => {
      'dummy' => 1
    },
    'INFN' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INKN' => {
      'dummy' => 1
    },
    'INLN' => {
      'dummy' => 1
    }
  },
  'epals' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'egenSubC' => {
    'INPP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SUBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ewaveouts' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'esub' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'epcnts' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'epdlys' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'GLNK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'etimer' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'TORG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ebis' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'egenSubD' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPQ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPM' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPU' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SUBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPO' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ecalcouts' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'TSEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ecomp' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'elongoutsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'estate' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'egenSubA' => {
    'OUTN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUTF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SUBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbid' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'eao' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ehwlowcals' => {
    'WNPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'embbi' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ewavesim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'edfans' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'esels' => {
    'NVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'egenSubB' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTO' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTU' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTM' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SUBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTQ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eosc' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'estringoutsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ebisim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ehist' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'efanouts' => {
    'LNK2' => {
      'dummy' => 1
    },
    'LNK6' => {
      'dummy' => 1
    },
    'LNK3' => {
      'dummy' => 1
    },
    'SELL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'LNK5' => {
      'dummy' => 1
    },
    'SDIS' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LNK1' => {
      'dummy' => 1
    },
    'LNK4' => {
      'dummy' => 1
    }
  },
  'elongins' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'estringins' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eswfsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ecomps' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eptrns' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'SGL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'estep' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'RDBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ehists' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'eaom' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eramps' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LRL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbos' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eptrn' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'SGL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eai' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'eaim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'hwout' => {},
  'embbosim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'esubarray' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'TSEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'elongin' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'etimers' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'TORG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ebo' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ebosim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'elongout' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eramp' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'PDNL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LRL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'estringin' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbo' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'epids' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'elogic' => {
    'I8L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'IDL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I5L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I0L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I6L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I7L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'IEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I9L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'I2L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I4L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I3L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I1L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'IAL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'ICL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'IBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'IFL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'elonginsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'embbis' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'embbods' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'estringout' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ebi' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'escan' => {
    'D4PV' => {
      'dummy' => 1
    },
    'R3PV' => {
      'dummy' => 1
    },
    'R1PV' => {
      'dummy' => 1
    },
    'D1PV' => {
      'dummy' => 1
    },
    'T3PV' => {
      'dummy' => 1
    },
    'P1PV' => {
      'dummy' => 1
    },
    'D3PV' => {
      'dummy' => 1
    },
    'T2PV' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'P4PV' => {
      'dummy' => 1
    },
    'R2PV' => {
      'dummy' => 1
    },
    'P3PV' => {
      'dummy' => 1
    },
    'R4PV' => {
      'dummy' => 1
    },
    'T1PV' => {
      'dummy' => 1
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1
    },
    'P2PV' => {
      'dummy' => 1
    },
    'D2PV' => {
      'dummy' => 1
    },
    'T4PV' => {
      'dummy' => 1
    }
  },
  'epulses' => {
    'ENL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'esel' => {
    'NVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'emotor' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'RLNK' => {
      'dummy' => 1
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'RDBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eseq' => {
    'DOL8' => {
      'dummy' => 1
    },
    'LNK6' => {
      'dummy' => 1
    },
    'LNK3' => {
      'dummy' => 1
    },
    'DOLA' => {
      'dummy' => 1
    },
    'SELL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL2' => {
      'dummy' => 1
    },
    'LNKA' => {
      'dummy' => 1
    },
    'LNK5' => {
      'dummy' => 1
    },
    'DOL1' => {
      'dummy' => 1
    },
    'LNK9' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LNK7' => {
      'dummy' => 1
    },
    'LNK4' => {
      'dummy' => 1
    },
    'DOL9' => {
      'dummy' => 1
    },
    'LNK2' => {
      'dummy' => 1
    },
    'DOL6' => {
      'dummy' => 1
    },
    'DOL7' => {
      'dummy' => 1
    },
    'DOL3' => {
      'dummy' => 1
    },
    'LNK8' => {
      'dummy' => 1
    },
    'SDIS' => {
      'dummy' => 1
    },
    'DOL4' => {
      'dummy' => 1
    },
    'DOL5' => {
      'dummy' => 1
    },
    'LNK1' => {
      'dummy' => 1
    }
  },
  'epal' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eaosim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'epcnt' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eseqs' => {
    'DOL8' => {
      'dummy' => 1
    },
    'LNK6' => {
      'dummy' => 1
    },
    'LNK3' => {
      'dummy' => 1
    },
    'DOLA' => {
      'dummy' => 1
    },
    'SELL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL2' => {
      'dummy' => 1
    },
    'LNKA' => {
      'dummy' => 1
    },
    'LNK5' => {
      'dummy' => 1
    },
    'DOL1' => {
      'dummy' => 1
    },
    'LNK9' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LNK7' => {
      'dummy' => 1
    },
    'LNK4' => {
      'dummy' => 1
    },
    'DOL9' => {
      'dummy' => 1
    },
    'LNK2' => {
      'dummy' => 1
    },
    'DOL6' => {
      'dummy' => 1
    },
    'DOL7' => {
      'dummy' => 1
    },
    'DOL3' => {
      'dummy' => 1
    },
    'LNK8' => {
      'dummy' => 1
    },
    'SDIS' => {
      'dummy' => 1
    },
    'DOL4' => {
      'dummy' => 1
    },
    'DOL5' => {
      'dummy' => 1
    },
    'LNK1' => {
      'dummy' => 1
    }
  },
  'eaos' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eevent' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'emai' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'TSEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'ewave' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'ewaveout' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'estates' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'esteps' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'RDBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'epid' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'elongouts' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'epulse' => {
    'ENL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbod' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ecalcs' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'estringinsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'hwin' => {},
  'ebos' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ewaveoutsim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eoscs' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'efanout' => {
    'LNK2' => {
      'dummy' => 1
    },
    'LNK6' => {
      'dummy' => 1
    },
    'LNK3' => {
      'dummy' => 1
    },
    'SELL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'LNK5' => {
      'dummy' => 1
    },
    'SDIS' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'LNK1' => {
      'dummy' => 1
    },
    'LNK4' => {
      'dummy' => 1
    }
  },
  'ew2mask' => {
    'IN7' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN4' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN2' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN5' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'INF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'INE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN9' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'FLNK' => {
      'dummy' => 1
    },
    'IN8' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'DOL' => {
      'dummy' => 1
    },
    'IN3' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'INC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN6' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'INA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN1' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'INB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'BTCH' => {
      'proc' => 'NPP',
      'alrm' => 'NMS '
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IN0' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    },
    'IND' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS '
    }
  },
  'ew2masks' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'ebom' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'edfan' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eperms' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'eais' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'eevents' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'estringouts' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'emotors' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'RLNK' => {
      'dummy' => 1
    },
    'DOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'OUT' => {
      'dummy' => 1
    },
    'RDBL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbids' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'eaisim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  },
  'epdly' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'GLNK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'dummy' => 1
    }
  },
  'eperm' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'esubs' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPK' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPA' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPJ' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPI' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPF' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPC' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbisim' => {
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SIOL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INP' => {
      'dummy' => 1
    }
  }
);

sub record_defaults
  { my($rectype)= @_;

    my $r_h= $rec_defaults{"e$rectype"};
    if (!defined $r_h)
      { warn "warning, recordtype \"$rectype\" not known"; 
        return;
      }
    return($r_h);
  }

1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

capfast_defaults - a Perl module that contains capfast defaults for record-fields

=head1 SYNOPSIS

  use capfast_defaults;

  my $r_h= capfast_defaults::record_defaults("longout");

=head1 DESCRIPTION

=head2 Preface

This module contains all defaults for record-fields as they are defined
in capfast 1.6. 

=head2 global variables:

=over 4

=item *

B<rec_defaults>

  print $capfast_defaults::rec_defaults{"elongout");

This global variable contains the record-defaults hash. This hash 
has one entry for each record-type. Note that the record-types have
the letter "e" prepended as you can see in the example above.

=item *

B<rec_linkable_fields>

  print $capfast_defaults::rec_linkable_fields{"elongout");

This global variable contains the record-defaults hash for link-fields. 
This hash has one entry for each record-type. Note that the record-types have
the letter "e" prepended as you can see in the example above.

=back

=head2 Implemented Functions:

=over 4

=item *

B<record_defaults()>

  my $r_h= capfast_defaults::record_defaults("longout");

This function returns a hash-reference for the given record-type
or <undef> if the record-type is not known. The hash contains
all known fields as hash-keys and the defaults as hash-values.

=back

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


