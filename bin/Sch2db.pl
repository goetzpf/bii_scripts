eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# ---------------------------------------------------------------------
# sch2db.p
# converts capfast (*.sch) files to epics database (*.db) format.
# 
# author:                 Goetz Pfeiffer
# mail:                   pfeiffer@mail.bessy.de
# last modification date: 2002-06-13
# copyright:             
#
#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files assiciated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OF MODIFICTAIONS.


# ---------------------------------------------------------------------


use strict;
use File::Basename;
use Getopt::Long;
use Data::Dumper;

use vars qw($opt_help $opt_summary $opt_file $opt_out $opt_sympath 
           $opt_warn_miss $opt_warn_double $opt_no_defaults
	   $opt_dump_symfile $opt_internal_syms
	   $opt_name_to_desc
	   );

# ------------------------------------------------------------------------
# constants

my $version= "1.5";

$opt_sympath= "/home/controls/epics/R3.13.1/support/capfast/1-2/edif";

# ------------------------------------------------------------------------
# global variables
my %struc;    # this will contain the records
my %wires;    # this will contain the wires
my %fields;   # needed to handle connections between record-fields

my %symbols;  # list of used capfast symbols

my %aliases;  # store aliases like : 'username(U0):LOPR'

my %gl_nlist; # contains things like: n#402

# ------------------------------------------------------------------------
# internal symbol data

# symbol-defaults:
my %rec_defaults = (
  'ecalc' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'calc',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'egenSub' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'INPH' => '',
    'NOVF' => '1',
    'FTVB' => 'DOUBLE',
    'UFA' => '',
    'PHAS' => '',
    'INPI' => '',
    'OUTH' => '',
    'UFVI' => '',
    'UFVJ' => '',
    'INPC' => '',
    'NOVD' => '1',
    'UFVE' => '',
    'DISS' => 'NO_ALARM',
    'OUTJ' => '',
    'INPA' => '',
    'UFE' => '',
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
    'OUTD' => '',
    'INPD' => '',
    'type' => 'genSub',
    'FTF' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'NOF' => '1',
    'OUTB' => '',
    'NOA' => '1',
    'INPE' => '',
    'NOG' => '1',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'NOB' => '1',
    'FLNK' => '',
    'FTVD' => 'DOUBLE',
    'OUTF' => '',
    'NOVE' => '1',
    'NOVH' => '1',
    'NOI' => '1',
    'UFI' => '',
    'NOJ' => '1',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'SNAM' => '',
    'INPJ' => '',
    'LFLG' => 'IGNORE',
    'INAM' => '',
    'SUBL' => '',
    'OUTA' => '',
    'FTC' => 'DOUBLE',
    'NOH' => '1',
    'NOVI' => '1',
    'INPG' => '',
    'FTI' => 'DOUBLE'
  },
  'ewaves' => {
    'SIOL' => '',
    'EVNT' => '',
    'RARM' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveform',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'waveform',
    'INP' => ''
  },
  'embbom' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM'
  },
  'ebim' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'bi',
    'INP' => ''
  },
  'ewait' => {
    'SIOL' => '',
    'INDP' => 'No',
    'INHN' => ' ',
    'INLP' => 'No',
    'INCN' => ' ',
    'ININ' => ' ',
    'PHAS' => '',
    'ASG' => '',
    'INBN' => ' ',
    'SIMM' => 'NO',
    'PREC' => '',
    'INJP' => 'No',
    'INFP' => 'No',
    'ODLY' => '',
    'INKP' => 'No',
    'INEP' => 'No',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'INAP' => 'No',
    'INJN' => ' ',
    'SDIS' => ' 0.000000000000000e+00',
    'SIML' => '',
    'MDEL' => '',
    'DOLD' => '',
    'INFN' => ' ',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'wait',
    'INIP' => 'No',
    'OUTN' => ' ',
    'INGN' => ' ',
    'INGP' => 'No',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'INDN' => ' ',
    'LOPR' => '',
    'INCP' => 'No',
    'INLN' => ' ',
    'INKN' => ' ',
    'FLNK' => '',
    'DESC' => 'wait',
    'CALC' => 'A+B+C',
    'OOPT' => 'Every Time',
    'INEN' => ' ',
    'INBP' => 'No',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'INAN' => ' ',
    'DOPT' => 'Use VAL',
    'INHP' => 'No'
  },
  'epals' => {
    'G1' => '0.9',
    'F0' => '0.1',
    'A1' => '0.9',
    'INPH' => '',
    'L1' => '0.9',
    'C1' => '0.9',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'INPI' => '',
    'J0' => '0.1',
    'INPC' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'I0' => '0.1',
    'H1' => '0.9',
    'B1' => '0.9',
    'INPA' => '',
    'SDIS' => '',
    'J1' => '0.9',
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'K1' => '0.9',
    'F1' => '0.9',
    'type' => 'pal',
    'INPD' => '',
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
    'K0' => '0.1',
    'DESC' => 'pal',
    'B0' => '0.1',
    'INPK' => '',
    'INPL' => '',
    'D1' => '0.9',
    'D0' => '0.1',
    'INPJ' => '',
    'A0' => '0.1',
    'G0' => '0.1',
    'I1' => '0.9',
    'INPG' => ''
  },
  'egenSubC' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'INPH' => '',
    'NOVF' => '1',
    'FTVB' => 'DOUBLE',
    'FTS' => 'DOUBLE',
    'UFA' => '',
    'PHAS' => '',
    'NON' => '1',
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
    'UFS' => '',
    'UFP' => '',
    'NOVS' => '1',
    'UFU' => '',
    'UFI' => '',
    'FTVP' => 'DOUBLE',
    'NOI' => '1',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'INPJ' => '',
    'NOS' => '1',
    'INAM' => '',
    'LFLG' => 'IGNORE',
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
    'FTR' => 'DOUBLE',
    'NOVA' => '1',
    'UFC' => '',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'NOF' => '1',
    'FTVU' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'INPN' => '',
    'NOA' => '1',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'NOVR' => '1',
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
  'ecalcout' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'INPB' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'INPD' => '',
    'type' => 'calcout',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'OOPT' => 'Every Time',
    'CALC' => '',
    'INPK' => '',
    'INPL' => '',
    'TSEL' => '',
    'ADEL' => '',
    'INPJ' => '',
    'LOW' => '',
    'OCAL' => '',
    'DOPT' => 'Use CALC',
    'HIGH' => '',
    'INPG' => ''
  },
  'ewaveouts' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HEAD' => '',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveout',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'waveout'
  },
  'embbim' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'INP' => ''
  },
  'esub' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'sub',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'SNAM' => '',
    'INAM' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'etimer' => {
    'DUT4' => '',
    'OPW2' => '',
    'PTST' => 'low',
    'DTYP' => 'Mizar-8310',
    'PHAS' => '',
    'ASG' => '',
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
    'TEVT' => ''
  },
  'epdlys' => {
    'ECS' => '',
    'DLY' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'STL' => '',
    'LOPR' => '',
    'STV' => 'Disable',
    'DTYP' => 'Mizar-8310',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'UNIT' => 'Seconds',
    'HTS' => '',
    'FLNK' => '',
    'TTYP' => 'Hardware',
    'HOPR' => '',
    'DESC' => 'pulse delay',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLOW' => 'Logic Low=0',
    'GLNK' => '',
    'CEDG' => 'Rising Edge',
    'OUT' => '#C0 S0',
    'ECR' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseDelay',
    'WIDE' => '',
    'CTYP' => 'Internal'
  },
  'epcnts' => {
    'CSIZ' => '32 bit',
    'EVNT' => '',
    'SGL' => 'S0',
    'SGV' => 'Inactive',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Mizar 8310',
    'GTYP' => 'Hardware',
    'PHAS' => '',
    'ASG' => '',
    'HGV' => '',
    'CNTE' => 'Rising Edge',
    'FLNK' => '',
    'HOPR' => '',
    'DESC' => 'pulseCounter',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'OUT' => '',
    'CNTS' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseCounter'
  },
  'egenSubD' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'INPH' => '',
    'NOVF' => '1',
    'FTVB' => 'DOUBLE',
    'FTS' => 'DOUBLE',
    'INPQ' => '',
    'UFA' => '',
    'PHAS' => '',
    'NON' => '1',
    'FTP' => 'DOUBLE',
    'OUTH' => '',
    'FTQ' => 'DOUBLE',
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
    'INPJ' => '',
    'INAM' => '',
    'LFLG' => 'IGNORE',
    'NOS' => '1',
    'INPO' => '',
    'FTC' => 'DOUBLE',
    'NOVI' => '1',
    'INPG' => '',
    'FTI' => 'DOUBLE',
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
    'OUTF' => '',
    'NOVE' => '1',
    'NOVH' => '1',
    'NOJ' => '1',
    'INPK' => '',
    'INPU' => '',
    'SNAM' => '',
    'SUBL' => '',
    'OUTA' => '',
    'NOH' => '1'
  },
  'ebis' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'bi',
    'INP' => ''
  },
  'ecomp' => {
    'IHIL' => '',
    'N' => '',
    'NSAM' => '',
    'EVNT' => '',
    'ILIL' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DESC' => 'compression',
    'DISS' => 'NO_ALARM',
    'SDIS' => '',
    'ALG' => 'N to 1 Low Value',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'compress',
    'INP' => ''
  },
  'ecalcouts' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'INPB' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'INPD' => '',
    'type' => 'calcout',
    'IVOA' => 'Continue normally',
    'HSV' => 'NO_ALARM',
    'HYST' => '',
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
    'CALC' => 'A+B+C',
    'OOPT' => 'Every Time',
    'INPK' => '',
    'TSEL' => '',
    'INPL' => '',
    'ADEL' => '',
    'INPJ' => '',
    'LOW' => '',
    'OCAL' => '',
    'DOPT' => 'Use CALC',
    'HIGH' => '',
    'INPG' => ''
  },
  'estate' => {
    'PRIO' => 'LOW',
    'DESC' => 'state',
    'DISS' => 'NO_ALARM',
    'VAL' => 'value',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'SDIS' => '',
    'FLNK' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'state'
  },
  'elongoutsim' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'longout',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'HIGH' => ''
  },
  'egenSubA' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'INPH' => '',
    'NOVF' => '1',
    'FTVB' => 'DOUBLE',
    'FTS' => 'DOUBLE',
    'UFA' => '',
    'PHAS' => '',
    'NON' => '1',
    'FTP' => 'DOUBLE',
    'OUTH' => '',
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
    'UFS' => '',
    'UFP' => '',
    'NOVS' => '1',
    'UFU' => '',
    'UFI' => '',
    'FTVP' => 'DOUBLE',
    'NOI' => '1',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'INPJ' => '',
    'NOS' => '1',
    'INAM' => '',
    'LFLG' => 'IGNORE',
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
    'UFVP' => '',
    'UFVC' => '',
    'UFT' => '',
    'NOVJ' => '1',
    'FTR' => 'DOUBLE',
    'NOVA' => '1',
    'UFC' => '',
    'OUTD' => '',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'NOF' => '1',
    'FTVU' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'OUTB' => '',
    'INPN' => '',
    'NOA' => '1',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'NOVR' => '1',
    'OUTR' => '',
    'INPR' => '',
    'FTL' => 'DOUBLE',
    'OUTF' => '',
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
  'embbid' => {
    'SIOL' => '',
    'BC' => '',
    'BB' => '',
    'B4' => '',
    'B6' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
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
    'INP' => '',
    'BD' => ''
  },
  'ewavesim' => {
    'SIOL' => '',
    'EVNT' => '',
    'RARM' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveform',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'waveform',
    'INP' => ''
  },
  'embbi' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'INP' => ''
  },
  'ehwlowcals' => {
    'TMO' => '',
    'MUX' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'DTYP' => 'lowcal',
    'BTYP' => '',
    'ASG' => '',
    'CLAS' => '',
    'OBJI' => '',
    'FLNK' => '',
    'WNPM' => '',
    'PORT' => '',
    'INHB' => '',
    'WNPL' => '',
    'UTYP' => '',
    'PRIO' => 'LOW',
    'ATYP' => '',
    'DESC' => '',
    'DISS' => 'NO_ALARM',
    'NOBT' => '',
    'SDIS' => '',
    'NELM' => '',
    'OBJO' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'hwLowcal',
    'DLEN' => ''
  },
  'eao' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'LINR' => 'NO CONVERSION',
    'HOPR' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ao',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'OIF' => 'Full',
    'HIGH' => ''
  },
  'esels' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'sel',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'edfans' => {
    'LOLO' => '',
    'HIHI' => '',
    'K' => '',
    'E' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'D' => '',
    'SEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'I' => '',
    'type' => 'dfanout',
    'G' => '',
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
    'HIGH' => '',
    'INP' => ''
  },
  'estringoutsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'OMSL' => 'supervisory',
    'type' => 'stringout',
    'IVOA' => 'Continue normally'
  },
  'eosc' => {
    'ATN4' => '1',
    'CEN3' => '',
    'SIOL' => '',
    'TLEV' => '',
    'OPR1' => '1',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'CMS1' => 'Chan 1',
    'COU1' => 'Off',
    'EGUV' => 'Volt',
    'ATN2' => '1',
    'TTIM' => '1',
    'CEN2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'M1TP' => 'None',
    'MSOU' => 'Chan 1',
    'CEN1' => '',
    'COU2' => 'Off',
    'OPR3' => '1',
    'SDIS' => '',
    'SIML' => '',
    'TDLY' => '',
    'OPRH' => '1e-3',
    'OPR4' => '1',
    'COU3' => 'Off',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'osc',
    'EGUH' => 'Second',
    'HCV1' => '',
    'ATN3' => '1',
    'M2TP' => 'None',
    'TSLP' => 'POS',
    'EVNT' => '',
    'ATN1' => '1',
    'COU4' => 'Off',
    'SCAN' => 'Passive',
    'CEN4' => '',
    'FLNK' => '',
    'HCV2' => '',
    'TSOU' => 'Chan 1',
    'DESC' => 'osc',
    'OPR2' => '1',
    'CMS2' => 'Chan 1',
    'SIMS' => 'NO_ALARM',
    'VCV1' => '',
    'CMTP' => 'None',
    'VCV2' => '',
    'INP' => ''
  },
  'egenSubB' => {
    'EFLG' => 'ALWAYS',
    'FTVJ' => 'DOUBLE',
    'UFO' => '',
    'INPH' => '',
    'NOVF' => '1',
    'FTVB' => 'DOUBLE',
    'FTS' => 'DOUBLE',
    'UFA' => '',
    'PHAS' => '',
    'NON' => '1',
    'FTP' => 'DOUBLE',
    'OUTH' => '',
    'FTQ' => 'DOUBLE',
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
    'UFVS' => '',
    'NOVN' => '1',
    'OUTM' => '',
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
    'UFQ' => '',
    'FTK' => 'DOUBLE',
    'OUTN' => '',
    'UFVL' => '',
    'NOVO' => '1',
    'NOG' => '1',
    'NOB' => '1',
    'FLNK' => '',
    'FTVD' => 'DOUBLE',
    'UFS' => '',
    'UFP' => '',
    'NOVS' => '1',
    'UFU' => '',
    'UFI' => '',
    'FTVP' => 'DOUBLE',
    'NOI' => '1',
    'FTU' => 'DOUBLE',
    'UFB' => '',
    'NOVB' => '1',
    'FTVI' => 'DOUBLE',
    'NOVQ' => '1',
    'INPJ' => '',
    'NOS' => '1',
    'INAM' => '',
    'LFLG' => 'IGNORE',
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
    'OUTO' => '',
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
    'FTR' => 'DOUBLE',
    'NOVA' => '1',
    'UFC' => '',
    'OUTD' => '',
    'INPD' => '',
    'FTF' => 'DOUBLE',
    'NOF' => '1',
    'FTVU' => 'DOUBLE',
    'FTVH' => 'DOUBLE',
    'OUTB' => '',
    'INPN' => '',
    'NOA' => '1',
    'FTVE' => 'DOUBLE',
    'INPF' => '',
    'NOVR' => '1',
    'OUTR' => '',
    'INPR' => '',
    'FTL' => 'DOUBLE',
    'OUTF' => '',
    'NOVE' => '1',
    'NOVH' => '1',
    'NOJ' => '1',
    'FTVO' => 'DOUBLE',
    'UFVK' => '',
    'SNAM' => '',
    'SUBL' => '',
    'OUTA' => '',
    'UFVQ' => '',
    'NOH' => '1',
    'OUTK' => ''
  },
  'ebisim' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'bi',
    'INP' => ''
  },
  'ehist' => {
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'SDEL' => '',
    'type' => 'histogram'
  },
  'elongins' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'LSV' => 'NO_ALARM',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'LOW' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'longin',
    'HIGH' => '',
    'INP' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM'
  },
  'efanouts' => {
    'LNK6' => '',
    'LNK3' => '',
    'SELL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'LNK5' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DESC' => 'fanout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SDIS' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'fanout',
    'LNK1' => ''
  },
  'estringins' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'eswfsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'RARM' => '',
    'LOPR' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'DESC' => 'waveform',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'swf',
    'INP' => ''
  },
  'ecomps' => {
    'IHIL' => '',
    'N' => '',
    'NSAM' => '',
    'EVNT' => '',
    'ILIL' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FLNK' => '',
    'EGU' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DESC' => 'compression',
    'DISS' => 'NO_ALARM',
    'SDIS' => '',
    'ALG' => 'N to 1 Low Value',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'compress',
    'INP' => ''
  },
  'estep' => {
    'LOLO' => '',
    'MRES' => '',
    'HIHI' => '',
    'DTYP' => 'Compumotor 1830',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'MODE' => 'Velocity',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'VELO' => '',
    'DOL' => '',
    'RTRY' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'steppermotor',
    'CMOD' => 'Velocity',
    'ACCL' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'IALG' => 'No Initialization',
    'ERES' => '',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DIST' => '',
    'HLSV' => 'NO_ALARM',
    'DRVH' => '',
    'IVAL' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'steppermotor',
    'ADEL' => '',
    'RDBL' => '',
    'DRVL' => '',
    'LOW' => '',
    'RDBD' => '',
    'HIGH' => ''
  },
  'eptrns' => {
    'ECS' => '',
    'DCY' => '',
    'EVNT' => '',
    'SGL' => '',
    'SGV' => 'Inactive',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'GTYP' => 'Hardware',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'HGV' => '',
    'PREC' => '',
    'UNIT' => 'Seconds',
    'PER' => '',
    'FLNK' => '',
    'HOPR' => '',
    'DESC' => 'pulse train',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'OUT' => '',
    'ECR' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseTrain',
    'CTYP' => 'Internal'
  },
  'ehists' => {
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'SDEL' => '',
    'type' => 'histogram'
  },
  'eramps' => {
    'BRCT' => '',
    'LOLO' => '',
    'HIHI' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'OUTL' => '',
    'SDIS' => '',
    'MDEL' => '',
    'RALG' => 'Direct',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ramp',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'STPL' => '',
    'APPR' => 'Above',
    'EVNT' => '',
    'SDLY' => '',
    'SCAN' => 'Passive',
    'IALG' => 'Bumpless',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DBND' => '',
    'HLIM' => '',
    'FLNK' => '',
    'EGU' => 'Amps',
    'PDNV' => '1',
    'OVER' => '',
    'DESC' => 'ramp',
    'IOCV' => '',
    'LRL' => '',
    'ADEL' => '',
    'IFST' => '',
    'LOW' => '',
    'SMSL' => 'supervisory',
    'HIGH' => '',
    'IRBA' => 'Continue normally'
  },
  'eaom' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'LINR' => 'NO CONVERSION',
    'HOPR' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ao',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'OIF' => 'Full',
    'HIGH' => ''
  },
  'embbos' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM'
  },
  'eptrn' => {
    'ECS' => '',
    'DCY' => '',
    'EVNT' => '',
    'SGL' => '',
    'SGV' => 'Inactive',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'GTYP' => 'Hardware',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'HGV' => '',
    'PREC' => '',
    'UNIT' => 'Seconds',
    'PER' => '',
    'FLNK' => '',
    'HOPR' => '',
    'DESC' => 'pulse train',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLOW' => 'Logic Low=0',
    'CEDG' => 'Rising Edge',
    'OUT' => '',
    'ECR' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseTrain',
    'CTYP' => 'Internal'
  },
  'eai' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'LINR' => 'LINEAR',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ai',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'HIGH' => '',
    'INP' => ''
  },
  'hwout' => {
    'val(outp)' => '#C0 S0'
  },
  'eaim' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'LINR' => 'LINEAR',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ai',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'HIGH' => '',
    'INP' => ''
  },
  'esubarray' => {
    'INDX' => '',
    'MALM' => '1',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'PHAS' => '',
    'ASG' => '',
    'DTYP' => 'Soft Channel',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'TSEL' => '',
    'SDIS' => '',
    'NELM' => '1',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'subArray',
    'INP' => ''
  },
  'embbosim' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM'
  },
  'etimers' => {
    'DUT4' => '',
    'OPW2' => '',
    'PTST' => 'low',
    'DTYP' => 'Mizar-8310',
    'PHAS' => '',
    'ASG' => '',
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
    'TEVT' => ''
  },
  'elongin' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'LSV' => 'NO_ALARM',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'LOW' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'longin',
    'HIGH' => '',
    'INP' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM'
  },
  'elongout' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'longout',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'HIGH' => ''
  },
  'ebosim' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'HIGH' => '',
    'OMSL' => 'supervisory',
    'type' => 'bo',
    'IVOA' => 'Continue normally'
  },
  'ebo' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'HIGH' => '',
    'OMSL' => 'supervisory',
    'type' => 'bo',
    'IVOA' => 'Continue normally'
  },
  'estringin' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'eramp' => {
    'PDNL' => '',
    'BRCT' => '',
    'LOLO' => '',
    'HIHI' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'OUTL' => '',
    'SDIS' => '',
    'MDEL' => '',
    'RALG' => 'Direct',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ramp',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'STPL' => '',
    'RMOD' => 'Closed Loop',
    'APPR' => 'Above',
    'EVNT' => '',
    'SDLY' => '',
    'SCAN' => 'Passive',
    'IALG' => 'Bumpless',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DBND' => '',
    'HLIM' => '',
    'FLNK' => '',
    'EGU' => 'Amps',
    'PDNV' => '1',
    'OVER' => '',
    'DESC' => 'ramp',
    'IOCV' => '',
    'LRL' => '',
    'ADEL' => '',
    'IFST' => '',
    'MDLT' => '',
    'LOW' => '',
    'SMSL' => 'supervisory',
    'HIGH' => '',
    'IRBA' => 'Continue normally'
  },
  'epids' => {
    'LOLO' => '',
    'HIHI' => '',
    'KI' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'LOW' => '',
    'SMSL' => 'supervisory',
    'HIGH' => ''
  },
  'embbo' => {
    'TWSV' => 'NO_ALARM',
    'SXSV' => 'NO_ALARM',
    'ONST' => '',
    'ZRSV' => 'NO_ALARM',
    'THSV' => 'NO_ALARM',
    'FVVL' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'UNSV' => 'NO_ALARM',
    'FFSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SVSV' => 'NO_ALARM',
    'TEST' => '',
    'FRSV' => 'NO_ALARM'
  },
  'elogic' => {
    'I8L' => '',
    'IDL' => '',
    'LTID' => 'table',
    'EVNT' => '',
    'I5L' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'I0L' => '',
    'I6L' => '',
    'I7L' => '',
    'IEL' => '',
    'I9L' => '',
    'FLNK' => '',
    'I2L' => '',
    'I4L' => '',
    'I3L' => '',
    'DESC' => 'LOGIC',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'I1L' => '',
    'IAL' => '',
    'ICL' => '',
    'IBL' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'IFL' => '',
    'type' => 'logic'
  },
  'elonginsim' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'LSV' => 'NO_ALARM',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'long input',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'LOW' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'longin',
    'HIGH' => '',
    'INP' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM'
  },
  'embbis' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'INP' => ''
  },
  'estringout' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'OMSL' => 'supervisory',
    'type' => 'stringout',
    'IVOA' => 'Continue normally'
  },
  'embbods' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbboDirect',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally'
  },
  'ebi' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'bi',
    'INP' => ''
  },
  'escan' => {
    'D4PV' => ' ',
    'R3PV' => ' ',
    'MPTS' => '100',
    'R1PV' => ' ',
    'D1PV' => ' ',
    'PHAS' => '',
    'ASG' => '',
    'P1PV' => ' ',
    'PREC' => '2',
    'P2SI' => '0.1',
    'PRIO' => 'HIGH',
    'DISS' => 'NO_ALARM',
    'P1LR' => '',
    'T1PV' => ' ',
    'SDIS' => '',
    'P2SP' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'scan',
    'FFO' => 'Use F-Flags',
    'P1PR' => '1',
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
    'P4PV' => ' ',
    'PROC' => '',
    'R2DL' => '',
    'P2PR' => '1',
    'DESC' => 'scan',
    'R2PV' => ' ',
    'FPTS' => 'Freeze',
    'P3PV' => ' ',
    'P1EP' => '',
    'R4PV' => ' ',
    'P1SI' => '0.1',
    'P2PV' => ' ',
    'P2HR' => '',
    'R3DL' => '',
    'D2PV' => ' ',
    'P2EP' => '',
    'R4DL' => ''
  },
  'epulses' => {
    'CLKR' => '1000000',
    'MINT' => '',
    'DTYP' => 'Camac',
    'PHAS' => '',
    'ASG' => '',
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
    'MIND' => '',
    'MINW' => '',
    'TVHI' => ''
  },
  'esel' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'sel',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'eseq' => {
    'DOL8' => '',
    'DLYA' => '',
    'SELL' => '',
    'PHAS' => '',
    'ASG' => '',
    'LNK5' => '',
    'PREC' => '',
    'DOL1' => '',
    'DLY2' => '',
    'LNK7' => '',
    'DOL9' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DLY9' => '',
    'DLY3' => '',
    'DOL7' => '',
    'LNK8' => '',
    'DOL3' => '',
    'SDIS' => '',
    'DOL5' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'seq',
    'DLY6' => '',
    'LNK1' => '',
    'DLY7' => '',
    'LNK6' => '',
    'LNK3' => '',
    'DOLA' => '',
    'DLY8' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LNKA' => '',
    'DOL2' => '',
    'DLY5' => '',
    'LNK9' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'DOL6' => '',
    'DLY4' => '',
    'DESC' => 'sequence',
    'DLY1' => '',
    'DOL4' => ''
  },
  'emotor' => {
    'S' => '',
    'LOLO' => '',
    'MRES' => '',
    'DHLM' => '',
    'TWV' => '',
    'HIHI' => '',
    'BVEL' => '',
    'PHAS' => '',
    'DTYP' => 'OMS VME8/44',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HLM' => '',
    'URIP' => 'No',
    'SBAS' => '',
    'BDST' => '',
    'SBAK' => '',
    'VELO' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'VBAS' => '',
    'DLLM' => '',
    'RTRY' => '10',
    'LLSV' => 'NO_ALARM',
    'RRES' => '',
    'OUT' => '',
    'SDIS' => '',
    'RLNK' => '',
    'FRAC' => '1',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'motor',
    'OMSL' => 'supervisory',
    'UEIP' => 'No',
    'LLM' => '',
    'HSV' => 'NO_ALARM',
    'ACCL' => '0.2',
    'DIR' => 'Pos',
    'DLY' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ERES' => '',
    'HHSV' => 'NO_ALARM',
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
    'UREV' => '',
    'LOW' => '',
    'RDBD' => '',
    'HIGH' => '',
    'OFF' => ''
  },
  'epal' => {
    'G1' => '0.9',
    'F0' => '0.1',
    'A1' => '0.9',
    'INPH' => '',
    'L1' => '0.9',
    'C1' => '0.9',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'INPI' => '',
    'J0' => '0.1',
    'INPC' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'I0' => '0.1',
    'H1' => '0.9',
    'B1' => '0.9',
    'INPA' => '',
    'SDIS' => '',
    'J1' => '0.9',
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'K1' => '0.9',
    'F1' => '0.9',
    'type' => 'pal',
    'INPD' => '',
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
    'K0' => '0.1',
    'DESC' => 'pal',
    'B0' => '0.1',
    'INPK' => '',
    'D1' => '0.9',
    'INPL' => '',
    'D0' => '0.1',
    'INPJ' => '',
    'A0' => '0.1',
    'G0' => '0.1',
    'I1' => '0.9',
    'INPG' => ''
  },
  'eaosim' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'LINR' => 'NO CONVERSION',
    'HOPR' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ao',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'OIF' => 'Full',
    'HIGH' => ''
  },
  'epcnt' => {
    'CSIZ' => '32 bit',
    'EVNT' => '',
    'SGL' => 'S0',
    'SGV' => 'Inactive',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Mizar 8310',
    'GTYP' => 'Hardware',
    'PHAS' => '',
    'ASG' => '',
    'HGV' => '',
    'CNTE' => 'Rising Edge',
    'FLNK' => '',
    'HOPR' => '',
    'DESC' => 'pulseCounter',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'OUT' => '',
    'CNTS' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseCounter'
  },
  'eseqs' => {
    'DOL8' => '',
    'DLYA' => '',
    'SELL' => '',
    'PHAS' => '',
    'ASG' => '',
    'LNK5' => '',
    'PREC' => '',
    'DOL1' => '',
    'DLY2' => '',
    'LNK7' => '',
    'DOL9' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DLY9' => '',
    'DLY3' => '',
    'DOL7' => '',
    'LNK8' => '',
    'DOL3' => '',
    'SDIS' => '',
    'DOL5' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'seq',
    'DLY6' => '',
    'LNK1' => '',
    'DLY7' => '',
    'LNK6' => '',
    'LNK3' => '',
    'DOLA' => '',
    'DLY8' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LNKA' => '',
    'DOL2' => '',
    'DLY5' => '',
    'LNK9' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'DOL6' => '',
    'DLY4' => '',
    'DESC' => 'sequence',
    'DLY1' => '',
    'DOL4' => ''
  },
  'eaos' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'IVOV' => '',
    'LINR' => 'NO CONVERSION',
    'HOPR' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ao',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HHSV' => 'NO_ALARM',
    'LOPR' => '',
    'DRVH' => '',
    'FLNK' => '',
    'AOFF' => '',
    'EGU' => '',
    'DESC' => 'analog output',
    'EGUL' => '',
    'EGUF' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'DRVL' => '',
    'LOW' => '',
    'OIF' => 'Full',
    'HIGH' => ''
  },
  'eevent' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'event',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'event',
    'INP' => ''
  },
  'emai' => {
    'SIOL' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASLO4' => '1',
    'ASG' => '',
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
    'ASLO2' => '1',
    'SIMS' => 'NO_ALARM',
    'SMOO2' => '',
    'EGUF4' => '',
    'EGUL2' => '',
    'NELM' => '1',
    'EGUF1' => '',
    'INP' => ''
  },
  'ewave' => {
    'SIOL' => '',
    'EVNT' => '',
    'RARM' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveform',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'waveform',
    'INP' => ''
  },
  'ewaveout' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HEAD' => '',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveout',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'waveout'
  },
  'estates' => {
    'PRIO' => 'LOW',
    'DESC' => 'state',
    'DISS' => 'NO_ALARM',
    'VAL' => 'value',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'SDIS' => '',
    'FLNK' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'state'
  },
  'esteps' => {
    'LOLO' => '',
    'MRES' => '',
    'HIHI' => '',
    'DTYP' => 'Compumotor 1830',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'MODE' => 'Velocity',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'VELO' => '',
    'DOL' => '',
    'RTRY' => '',
    'LLSV' => 'NO_ALARM',
    'OUT' => '',
    'SDIS' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'steppermotor',
    'CMOD' => 'Velocity',
    'ACCL' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'IALG' => 'No Initialization',
    'ERES' => '',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'DIST' => '',
    'HLSV' => 'NO_ALARM',
    'DRVH' => '',
    'IVAL' => '',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'steppermotor',
    'ADEL' => '',
    'RDBL' => '',
    'DRVL' => '',
    'LOW' => '',
    'RDBD' => '',
    'HIGH' => ''
  },
  'epid' => {
    'LOLO' => '',
    'HIHI' => '',
    'KI' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'LOW' => '',
    'SMSL' => 'supervisory',
    'HIGH' => ''
  },
  'epulse' => {
    'CLKR' => '1000000',
    'MINT' => '',
    'DTYP' => 'Camac',
    'PHAS' => '',
    'ASG' => '',
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
    'MIND' => '',
    'MINW' => '',
    'TVHI' => ''
  },
  'elongouts' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'longout',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'FLNK' => '',
    'EGU' => '',
    'DESC' => 'long output',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'HIGH' => ''
  },
  'embbod' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'mbboDirect',
    'OMSL' => 'supervisory',
    'IVOA' => 'Continue normally'
  },
  'estringinsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DESC' => 'string input',
    'VAL' => '',
    'SIMS' => 'NO_ALARM',
    'SDIS' => '',
    'SIML' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'stringin',
    'INP' => ''
  },
  'ecalcs' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'calc',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'hwin' => {
    'val(in)' => '#C0 S0'
  },
  'ewaveoutsim' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'HEAD' => '',
    'LOPR' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'FTVL' => 'STRING',
    'FLNK' => '',
    'HOPR' => '',
    'EGU' => '',
    'DESC' => 'waveout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'DOL' => '',
    'OUT' => '',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'NELM' => '1',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'waveout'
  },
  'ebos' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'HIGH' => '',
    'OMSL' => 'supervisory',
    'type' => 'bo',
    'IVOA' => 'Continue normally'
  },
  'eoscs' => {
    'ATN4' => '1',
    'CEN3' => '',
    'SIOL' => '',
    'TLEV' => '',
    'OPR1' => '1',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'CMS1' => 'Chan 1',
    'COU1' => 'Off',
    'EGUV' => 'Volt',
    'ATN2' => '1',
    'TTIM' => '1',
    'CEN2' => '',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'M1TP' => 'None',
    'MSOU' => 'Chan 1',
    'CEN1' => '',
    'COU2' => 'Off',
    'OPR3' => '1',
    'SDIS' => '',
    'SIML' => '',
    'TDLY' => '',
    'OPRH' => '1e-3',
    'OPR4' => '1',
    'COU3' => 'Off',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'osc',
    'EGUH' => 'Second',
    'HCV1' => '',
    'ATN3' => '1',
    'M2TP' => 'None',
    'TSLP' => 'POS',
    'EVNT' => '',
    'ATN1' => '1',
    'COU4' => 'Off',
    'SCAN' => 'Passive',
    'CEN4' => '',
    'FLNK' => '',
    'HCV2' => '',
    'TSOU' => 'Chan 1',
    'DESC' => 'osc',
    'OPR2' => '1',
    'CMS2' => 'Chan 1',
    'SIMS' => 'NO_ALARM',
    'VCV1' => '',
    'CMTP' => 'None',
    'VCV2' => '',
    'INP' => ''
  },
  'efanout' => {
    'LNK6' => '',
    'LNK3' => '',
    'SELL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'LNK5' => '',
    'SELM' => 'All',
    'FLNK' => '',
    'LNK4' => '',
    'LNK2' => '',
    'DESC' => 'fanout',
    'DISS' => 'NO_ALARM',
    'PRIO' => 'LOW',
    'SDIS' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'fanout',
    'LNK1' => ''
  },
  'ew2masks' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'w2mask ',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'LOW' => '',
    'FON' => '',
    'HIGH' => ''
  },
  'ew2mask' => {
    'LOLO' => '',
    'IN7' => '',
    'SIOL' => '',
    'HIHI' => '',
    'IN4' => '',
    'IN2' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'LSV' => 'NO_ALARM',
    'INE' => '',
    'IVOV' => '',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'INC' => '',
    'LLSV' => 'NO_ALARM',
    'IN6' => '',
    'INB' => '',
    'IN1' => '',
    'OUT' => '0.000000000000000e+00 ',
    'BTCH' => '',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'OMSL' => 'supervisory',
    'type' => 'w2mask ',
    'IVOA' => 'Continue normally',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'LOPR' => '',
    'HHSV' => 'NO_ALARM',
    'IN5' => '',
    'INF' => '',
    'IN9' => '',
    'FLNK' => '',
    'IN8' => '',
    'EGU' => '',
    'DESC' => 'word to mask',
    'FOFF' => '',
    'IN3' => '',
    'INA' => '',
    'ADEL' => '',
    'SIMS' => 'NO_ALARM',
    'LOW' => '',
    'FON' => '',
    'IN0' => '',
    'IND' => '',
    'HIGH' => ''
  },
  'ebom' => {
    'SIOL' => '',
    'ZSV' => 'NO_ALARM',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'HIGH' => '',
    'OMSL' => 'supervisory',
    'type' => 'bo',
    'IVOA' => 'Continue normally'
  },
  'eperms' => {
    'PRIO' => 'LOW',
    'DESC' => 'permissive',
    'DISS' => 'NO_ALARM',
    'EVNT' => '',
    'LABL' => 'label',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'SDIS' => '',
    'FLNK' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'permissive'
  },
  'edfan' => {
    'LOLO' => '',
    'HIHI' => '',
    'K' => '',
    'E' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'D' => '',
    'SEL' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'I' => '',
    'type' => 'dfanout',
    'G' => '',
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
    'HIGH' => '',
    'INP' => ''
  },
  'eais' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'LINR' => 'LINEAR',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SDIS' => '',
    'SIML' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ai',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'HIGH' => '',
    'INP' => ''
  },
  'eevents' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
    'FLNK' => '',
    'DISS' => 'NO_ALARM',
    'DESC' => 'event',
    'PRIO' => 'LOW',
    'SIMS' => 'NO_ALARM',
    'SIML' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'event',
    'INP' => ''
  },
  'estringouts' => {
    'SIOL' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'PINI' => 'NO',
    'DISV' => '1',
    'OMSL' => 'supervisory',
    'type' => 'stringout',
    'IVOA' => 'Continue normally'
  },
  'embbids' => {
    'SIOL' => '',
    'BC' => '',
    'BB' => '',
    'B4' => '',
    'B6' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
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
    'INP' => '',
    'BD' => ''
  },
  'emotors' => {
    'S' => '',
    'LOLO' => '',
    'MRES' => '',
    'DHLM' => '',
    'TWV' => '',
    'HIHI' => '',
    'BVEL' => '',
    'PHAS' => '',
    'DTYP' => 'OMS VME8/44',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'HLM' => '',
    'URIP' => 'No',
    'SBAS' => '',
    'BDST' => '',
    'SBAK' => '',
    'VELO' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'DOL' => '',
    'VBAS' => '',
    'DLLM' => '',
    'RTRY' => '10',
    'LLSV' => 'NO_ALARM',
    'RRES' => '',
    'OUT' => '',
    'SDIS' => '',
    'RLNK' => '',
    'FRAC' => '1',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'motor',
    'OMSL' => 'supervisory',
    'UEIP' => 'No',
    'LLM' => '',
    'HSV' => 'NO_ALARM',
    'ACCL' => '0.2',
    'DIR' => 'Pos',
    'DLY' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'ERES' => '',
    'HHSV' => 'NO_ALARM',
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
    'UREV' => '',
    'LOW' => '',
    'RDBD' => '',
    'HIGH' => '',
    'OFF' => ''
  },
  'epdly' => {
    'ECS' => '',
    'DLY' => '',
    'EVNT' => '',
    'SCAN' => 'Passive',
    'STL' => '',
    'LOPR' => '',
    'STV' => 'Disable',
    'DTYP' => 'Mizar-8310',
    'PHAS' => '',
    'ASG' => '',
    'PREC' => '',
    'UNIT' => 'Seconds',
    'HTS' => '',
    'FLNK' => '',
    'TTYP' => 'Hardware',
    'HOPR' => '',
    'DESC' => 'pulse delay',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLOW' => 'Logic Low=0',
    'GLNK' => '',
    'CEDG' => 'Rising Edge',
    'OUT' => '#C0 S0',
    'ECR' => '',
    'SDIS' => '',
    'DISV' => '1',
    'PINI' => 'NO',
    'type' => 'pulseDelay',
    'WIDE' => '',
    'CTYP' => 'Internal'
  },
  'eaisim' => {
    'LOLO' => '',
    'SIOL' => '',
    'HIHI' => '',
    'PHAS' => '',
    'DTYP' => 'Soft Channel',
    'ASG' => '',
    'PREC' => '',
    'LSV' => 'NO_ALARM',
    'SMOO' => '',
    'LINR' => 'LINEAR',
    'HOPR' => '',
    'PRIO' => 'LOW',
    'DISS' => 'NO_ALARM',
    'LLSV' => 'NO_ALARM',
    'ASLO' => '1',
    'SIML' => '',
    'SDIS' => '',
    'MDEL' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'ai',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'HIGH' => '',
    'INP' => ''
  },
  'eperm' => {
    'PRIO' => 'LOW',
    'DESC' => 'permissive',
    'DISS' => 'NO_ALARM',
    'EVNT' => '',
    'LABL' => 'label',
    'SCAN' => 'Passive',
    'PHAS' => '',
    'ASG' => '',
    'SDIS' => '',
    'FLNK' => '',
    'PINI' => 'NO',
    'DISV' => '1',
    'type' => 'permissive'
  },
  'esubs' => {
    'LOLO' => '',
    'HIHI' => '',
    'INPH' => '',
    'PHAS' => '',
    'ASG' => '',
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
    'DISV' => '1',
    'PINI' => 'NO',
    'INPB' => '',
    'type' => 'sub',
    'INPD' => '',
    'HYST' => '',
    'HSV' => 'NO_ALARM',
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
    'ADEL' => '',
    'INPL' => '',
    'SNAM' => '',
    'INAM' => '',
    'INPJ' => '',
    'LOW' => '',
    'HIGH' => '',
    'INPG' => ''
  },
  'embbisim' => {
    'SXSV' => 'NO_ALARM',
    'TWSV' => 'NO_ALARM',
    'ONST' => '',
    'THSV' => 'NO_ALARM',
    'ZRSV' => 'NO_ALARM',
    'FVVL' => '',
    'DTYP' => 'Soft Channel',
    'PHAS' => '',
    'ASG' => '',
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
    'TTST' => '',
    'THVL' => '',
    'ZRST' => '',
    'FVST' => '',
    'FRVL' => '',
    'NIVL' => '',
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
    'TEST' => '',
    'SVSV' => 'NO_ALARM',
    'SIMS' => 'NO_ALARM',
    'FRSV' => 'NO_ALARM',
    'INP' => ''
  }
);


# defaults for record-links:

my %rec_linkable_fields = (
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
    'FLNK' => {
      'dummy' => 1
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
    'INPG' => {
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
  'ewait' => {
    'OUTN' => {
      'dummy' => 1
    },
    'INGN' => {
      'dummy' => 1
    },
    'INJN' => {
      'dummy' => 1
    },
    'INHN' => {
      'dummy' => 1
    },
    'INEN' => {
      'dummy' => 1
    },
    'INDN' => {
      'dummy' => 1
    },
    'INCN' => {
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
    'INLN' => {
      'dummy' => 1
    },
    'INKN' => {
      'dummy' => 1
    },
    'FLNK' => {
      'dummy' => 1
    },
    'INFN' => {
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
    'FLNK' => {
      'dummy' => 1
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
    'INPN' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPL' => {
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
    'FLNK' => {
      'dummy' => 1
    },
    'INPR' => {
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
    }
  },
  'ecalcout' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
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
    'FLNK' => {
      'dummy' => 1
    },
    'INPC' => {
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
    'OUT' => {
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
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
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
    'FLNK' => {
      'dummy' => 1
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
    'OUT' => {
      'dummy' => 1
    },
    'STL' => {
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
    'OUTA' => {
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
  'ecalcouts' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPE' => {
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
    'FLNK' => {
      'dummy' => 1
    },
    'INPC' => {
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
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'TSEL' => {
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
    'INPG' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
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
  'elongoutsim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'OUTB' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'INPN' => {
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
    'FLNK' => {
      'dummy' => 1
    },
    'OUTR' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
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
    'OUTL' => {
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
    'INPD' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTD' => {
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
  'ewavesim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'FLNK' => {
      'dummy' => 1
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
  'estringoutsim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
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
  'egenSubB' => {
    'INPH' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTO' => {
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
  'ebisim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
  'eramps' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
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
  'hwout' => {},
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
  'esubarray' => {
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
    },
    'TSEL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'embbosim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
  'ebosim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
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
  'eramp' => {
    'PDNL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUTL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
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
  'epids' => {
    'STPL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
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
    'I3L' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'I4L' => {
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
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'T3PV' => {
      'dummy' => 1
    },
    'D1PV' => {
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
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
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
    'FLNK' => {
      'dummy' => 1
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
  'eseq' => {
    'DOL8' => {
      'dummy' => 1
    },
    'LNK6' => {
      'dummy' => 1
    },
    'DOLA' => {
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
    'LNKA' => {
      'dummy' => 1
    },
    'DOL2' => {
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
    'DOL9' => {
      'dummy' => 1
    },
    'LNK4' => {
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
    'LNK8' => {
      'dummy' => 1
    },
    'DOL3' => {
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
  'emotor' => {
    'RLNK' => {
      'dummy' => 1
    },
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
    'FLNK' => {
      'dummy' => 1
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
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
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
    'DOLA' => {
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
    'LNKA' => {
      'dummy' => 1
    },
    'DOL2' => {
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
    'DOL9' => {
      'dummy' => 1
    },
    'LNK4' => {
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
    'LNK8' => {
      'dummy' => 1
    },
    'DOL3' => {
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
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'SDIS' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'CVL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'FLNK' => {
      'dummy' => 1
    }
  },
  'epulse' => {
    'ENL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'OUT' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
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
  'estringinsim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'FLNK' => {
      'dummy' => 1
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
  'hwin' => {},
  'ewaveoutsim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
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
  'emotors' => {
    'RLNK' => {
      'dummy' => 1
    },
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
    'OUT' => {
      'dummy' => 1
    },
    'STL' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    }
  },
  'eaisim' => {
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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
    'FLNK' => {
      'dummy' => 1
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
    'SIML' => {
      'proc' => 'NPP',
      'dummy' => 1,
      'alrm' => 'NMS'
    },
    'SDIS' => {
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


# ------------------------------------------------------------------------
# command line options processing:

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","file|f=s","out|o=s",
               "warn_miss|m:s","warn_double|d",
                "sympath|s=s", "no_defaults|n",
		"dump_symfile",
		"internal_syms|S",
		"name_to_desc|D",
		
		))
  { die "parameter error, use \"$0 -h\" to display the online-help\n"; };

if ($opt_help)
  { print_help();
    exit;
  };  

if ($opt_summary)
  { print_summary();
    exit;
  };  

if ($opt_dump_symfile)
  {
    scan_symbols($opt_sympath,\%rec_defaults,
        	 \%rec_linkable_fields);
    
    $Data::Dumper::Indent= 1;
    print Data::Dumper->Dump([\%rec_defaults, \%rec_linkable_fields], 
                             [qw(*rec_defaults *rec_linkable_fields)]);
    
    #hdump("scanned link defaults:","rec_linkable_fields",
    #      \%rec_linkable_fields); 
    #hdump("scanned symbols:","rec_defaults",\%rec_defaults);   
    exit(0);
  }


scan_sch($opt_file,\%gl_nlist,\%wires,\%struc,\%symbols);          

#       hdump("after scan_sch():","gl_nlist",\%gl_nlist); exit(1);
#       hdump("after scan_sch():","wires",\%wires);       exit(1);
#       hdump("after scan_sch():","struc",\%struc);       exit(1);
#       hdump("after scan_sch():","aliases",\%aliases);   exit(1);
#       hdump("after scan_sch():","symbols",\%symbols);   exit(1);


if (!$opt_internal_syms)
  {
    %rec_defaults= undef;
    %rec_linkable_fields= undef;

    scan_symbols($opt_sympath,\%rec_defaults,
        	 \%rec_linkable_fields, keys %symbols);
    #       hdump("scanned link defaults:","rec_linkable_fields",
    #             \%rec_linkable_fields); exit(1);
    #       hdump("scanned symbols:","rec_defaults",\%rec_defaults);     exit(1);
  };

# resolve aliases:
resolve_aliases(\%aliases, \%wires);
#       hdump("after resolve_aliases():","wires",\%wires);  exit(1);
   
    
# resolve junctions:
resolve_junctions(\%gl_nlist, \%wires);
#       hdump("after resolve_junctions():","wires",\%wires);  exit(1);
#       hdump("after resolve_junctions():","struc",\%struc);  exit(1);
 
	
# resolve wires:
resolve_wires(\%wires, \%fields);
#       hdump("after resolve_wires():","fields",\%fields);  exit(1);
#       hdump("after resolve_wires():","struc",\%struc);    exit(1);

resolve_connections(\%struc, \%fields);
#       hdump("after resolve_connections():","struc",\%struc);  exit(1);

db_prepare($opt_file,$opt_out,\%struc, $opt_name_to_desc); 
db_print($opt_out,\%struc); exit(0);

# scanning ---------------------------------------

sub scan_sch
  { my($filename,$r_gl_wirelists,$r_wires,$r_struc,$r_used_symbols)= @_;
    local *F;

    my $part;
    my $segment;
    my $lineno=0;
    my $type;
    
    if (defined $filename)
      { open(F,$filename) || die "unable to open $filename\n"; }
    else
      { *F= *STDIN; };
    
    my $line;
    while($line=<F>)
      { $lineno++;
	chomp($line);

	if ($line=~ /^\[([^\]]+)\]/)
	  { $segment= $1; next; };

	if ($segment eq 'detail')
	  { my @f= split(" ",$line);

            next if ($f[0] eq 's');
            next if ($f[0] eq 'f');
            next if ($f[0] eq 'p');

	    if ($f[0] ne 'w') # unexpected: no wire definition
	      { my $st;
	        $st= "file $filename: " if (defined $filename);
	        warn $st . "unexpected format in line-number $lineno:\n" .
	             "\"$line\"\n"; 
	        next; 
	      };


	    my $id= $f[5];
	    die if ($id=~ /^\s*$/); # assertion

	    # make wire-name unique
	    my $no;
	    for($no=0; exists $wires{"$id.$no"} ;$no++) { };
	    my $name= "$id.$no";

	    my($from_type,$from)= wire_dest($f[6]);
	    my($to_type  ,$to  )= wire_dest($f[-1]);

	    if ((!defined $from) || (!defined $to))
	      { die "line $lineno unrecognized!"; };

	    push @{$r_gl_wirelists->{$id}},$name;

	    $r_wires->{$name}->{to}  =  $to;
	    $r_wires->{$name}->{from}=  $from;
	    $r_wires->{$name}->{id}  =  $id;

            next;
	  };


	if ($segment eq 'cell use')
	  {
	    my @f= split(" ",$line);

            if ($f[0] eq 'use')
	      { # a "frame" has nothing to do with epics, ignore it:
	        next if ($f[6] eq 'frame');
	      
	        $part= $f[6]; # official part-name
		die if ($part=~ /^\s*$/);
		
		$type= $f[1];
		
		# the epics-symbol type, e.g "elongouts"
		$r_struc->{$part}->{symbol_type}= $type;
		# memorize that we need to read the symbol-data file for
		# this symbol later
		$r_used_symbols->{$type}= 1;
		next;
              };

            if ($f[0] eq 'xform')
	      { next; };

            if ($f[0] eq 'p')
	      { 
		my $st= join(" ",@f[6..$#f]); # join field 6 with the rest
		my ($field,$val)=  ($st=~ /^([^:]+):(.*)/);

		next if ($field eq 'Type');
		next if ($field eq 'primitive');

		if ($field=~ /^username\(([^\)]+)\)$/)
		  { # things like $field=username(U0)  $val=LOPR
		    $aliases{$part}->{$1}= $val;
		    next;
		  }
		
		$r_struc->{$part}->{$field}= $val;
		next;
	      };

	  };

	}; # while       

    if (defined $filename)
      { close(F) || die "unable to close $filename\n"; };

  }

sub wire_dest
  { my($field)= @_;
    
    return(undef,$field) if ($field eq 'junction');
    return(undef,$field) if ($field eq 'free');
    return($field =~ /^([^\.]+)\.(.*)/);
  }   

# resolving --------------------------------------

sub resolve_aliases
  { my($r_aliases,$r_wires)= @_;
   
    foreach my $wire (keys %$r_wires)
    # ^^^ test each wire
      { my $r_wire= $r_wires->{$wire};
        foreach my $tag ('from','to')
        # ^^^ do it for the 'from' and the 'to' tag
          { 
	    if (exists $r_wire->{$tag})
	    # ^^^ if the tag exists
              { 
	        my($rec,$field)= ($r_wire->{$tag} =~ /^([^\.]+)\.(.+)/);
		# ^^^ extract record and field-name
		if (defined $field)
		# ^^^ if they were found, then...
		  { my $alias= $r_aliases->{$rec}->{$field};
		    # ^^^ lookup the alias (if it exists)
	            $r_wire->{$tag}= "$rec.$alias" if (defined $alias);
		    # ^^^ change the field-name, if an alias exists
		  };
	      };
          };
      };	 
  }

sub resolve_wires
  { my($r_wires,$r_fields)= @_;
  
    # foreach wire definition:
    foreach my $key (keys %$r_wires)
      { 
	# extract the "to" and "from" field:
	my $from= $r_wires->{$key}->{from};
	my $to  = $r_wires->{$key}->{to};
	
	# do nothing if $to or $from is equal to 'free':
	next if (($from eq 'free') || ($to eq 'free'));

	# in the "connections" list of the field, add the 
	# other connected field:
	push @{ $r_fields->{$from}->{connections} }, $to;
	push @{ $r_fields->{$to}  ->{connections} }, $from;
      };
  }

sub resolve_junctions
  { my($r_nodelist, $r_wires)= @_;
    
    # foreach global wire-key
    foreach my $gkey (keys %$r_nodelist)
      { 
        # take a reference to the list of wires for that global wire-key:
        my $r_wlist= $r_nodelist->{$gkey};

	# do nothing, if there is only one wire in the set:
	next if ($#$r_wlist==0); # not a junction

        my $junction_found;
	my $count;

	# now collect all connected fields (nodes):    
	my @nodelist;
	foreach my $wire (@$r_wlist)
	  { $count++;
	    foreach my $st ($r_wires->{$wire}->{from},$r_wires->{$wire}->{to})
	      { next if ($st eq 'free');
	        if ($st eq 'junction')
		  { $junction_found=1;
		    next;
		  };
		# if it's not 'junction' or 'free' :
		push @nodelist, $st; 
              };
	    # now remove the wire
	    delete $r_wires->{$wire};
	  };

	if (!$junction_found)
	  { print_junction_error('junction',$gkey,$count); }; # fatal
	
	my $count=0;
	# re-create the wires, so that all fields are connected to each
	# other with a direct wire:

	while($#nodelist>0)
	  { my $first= shift(@nodelist);
            foreach my $n (@nodelist)
	      { my $name= $gkey . '.' . ($count++);
		$r_wires->{$name}->{from}=  $first;
		$r_wires->{$name}->{to}  =  $n;
	      };
	  };	  
      };


  }


sub resolve_connections
# look at the list of connections in the "fields" array and 
# put the appropriate values in the field of the corresponding record
  { my($r_struc, $r_fields) = @_;
  
    foreach my $key (keys %$r_fields)
      { 
      
	my($recname,$field)= ($key=~ /^([^\.]+)\.(.*)/); 
	next if (!defined $field);
        
	# get the record field-definitions (a hash-reference):
	my $rec_data= $r_struc->{$recname};
	next if (!defined $rec_data);
	
        # this is the record-type:
	my $rec_type= $rec_data->{type};

        # this is the symbol-type:
	my $sym_type= $rec_data->{symbol_type};

	next if (!exists $rec_linkable_fields{$sym_type}->{$field});
	# ^^^ things like: "BaseCmdCalc.VAL" connected to 
	#     BaseCmdSel.INPC
	# a link-entry cannot be put to the "VAL" field

        next if (!exists $r_fields->{$key}->{connections});
	# ^^^ the field has no connection-entries at all
        
	my @conn= @{$r_fields->{$key}->{connections}};
	# ^^^ the list with all other fields connected to THIS field ($key)

	my($pv,$conn,$conn_type);

	foreach my $c (@conn)
	# scan the list of possible connections, only one is the REAL one
	  { 
	  
            my($cname,$cfield)= ($c=~ /^([^\.]+)\.(.*)/); 

	    next if (!defined $cfield);
	    # ^^^ next if the "AAA.BBB" naming scheme is not found
	    
	    
	    next if (!exists $r_struc->{$cname});
	    # otherwise the following statement would CREATE a
	    # hash-entry if there is not already one
	    
	    # this is the record-type:
	    my $c_type= $r_struc->{$cname}->{type};

            # this is the symbol-type:
	    my $c_sym_type= $r_struc->{$cname}->{symbol_type};

	    next if (exists $rec_linkable_fields{$c_sym_type}->{$cfield});
	    # ^^^ ignore linkable fields where we cannot put an
	    # link-entry into
            
	    if (defined $conn) # assertion, shouldn't happen ! 
	      { # after testing all possible connections, exactly one REAL
	        # connection should be found
		print_junction_error('many_ports',$recname,$field);
		# fatal error here 
	      }; 


	    # store "PV" field:
	    $pv= $r_struc->{$cname}->{PV};
	    $conn= $c;
	    $conn_type= $c_sym_type;
	  }; # foreach

        # now: connection is in $conn, PV-field content in $pv


	# if $conn is empty, just put the "" string into the 
	# field of the record and proceed with the next
	if ($conn=~ /^\s*$/)
	  { $rec_data->{$field}= ""; 
	    next;
	  };

        # hwin and hwout must be handled separately:
	if (($conn_type eq 'hwin') || ($conn_type eq 'hwout'))
	  { 
	    my($cname,$cfield)= ($conn=~ /^([^\.]+)\.(.*)/); 

	    my $key= 'val(' . $cfield . ')';
	    # ^^^ $key is usually 'val(in)' or 'val(outp)'
	  
	    my $val= $r_struc->{$cname}->{$key};
	    if (!defined $val)
	      { # if not specified, take the default value:
	        $val= $rec_defaults{$conn_type}->{$key}; 
	      };
	      
            # store the value in the field:
	    $rec_data->{$field}= $val;
	    # just in case, delete any "def().." entries, these are 
	    # overwritten by the hwout - link:
	    delete $rec_data->{"def($field)"};

	  }
	else
	  { # it's no "hwout" and no "hwin":
	  
	    # pproc and palrm defaults:
	    
            my $proc;
	    my $alrm;
	    
            # now take the link default-properties from the 
	    # rec_linkable_fields hash:
	    my $r_link_defaults= $rec_linkable_fields{$sym_type}->{$field};
	    if (defined $r_link_defaults)
	      { $proc= $r_link_defaults->{proc};
	        $alrm= $r_link_defaults->{alrm};
	      };	

	    # read pproc, if defined, and overwrite $proc:
	    my $st= "pproc($field)";
	    if (exists $rec_data->{$st})
	      { $proc= $rec_data->{$st}; 
	        delete $rec_data->{$st}; 
	      };
	    # read palrm, if defined, and overwrite $alrm:
	    my $st= "palrm($field)";
	    if (exists $rec_data->{$st})
	      { $alrm= $rec_data->{$st}; 
		delete $rec_data->{$st}; 
	      };
	      
	    # ensure that $conn ends with a space:  
            if ($conn!~ /\s$/)
	      { $conn.= ' '; };

	    # prepend "." to $proc and $alrm, if defined:
	    $proc= ".$proc" if (defined($proc));
	    $alrm= ".$alrm" if (defined($alrm));


	    # if field is not FLNK, LNK or pproc or palrm was defined: 
	    # add $proc and $alrm
	    $conn.= $proc if (defined($proc)); 
	      
	    $conn.= $alrm if (defined($alrm));
	    
            # finally, store the link to the field $field within
	    # the record
	    $rec_data->{$field}= "$pv$conn"; 

	    # delete a "def" definition for the field, if it exists
	    delete $rec_data->{"def($field)"}; # if it exists!
	  };

      };
  }

# printing ---------------------------------------

sub db_prepare
  { my($in_file,$filename, $r_h, $name_to_desc)= @_;
    my($r_rec,$sym_type);
    
    my $prefix;
    
    if (defined $in_file)
      { $prefix= $in_file;
	$prefix=~ s/^.*\///;
	$prefix=~ s/\..*?$//;
	$prefix.= ':';
      };
    
    foreach my $recname (keys %$r_h)
      { 
        # handle macros in record-names:
	if ($recname=~ /VAR\(/)
	  { my $old= $recname;
	    $recname=~ s/VAR\(([^\)]*)\)/\$\($1\)/g;
            $r_h->{$recname}= $r_h->{$old};
	    delete $r_h->{$old};
	  };  

      
        $r_rec= $r_h->{$recname};
        $sym_type= $r_rec->{symbol_type};

        # delete hwin- and hwout entries:
	if (($sym_type eq 'hwin') || ($sym_type eq 'hwout'))
          { delete $r_h->{$recname};
	    next;
	  }; 
	
        handle_misc($r_rec,$recname);	
        handle_defaults($r_rec,$sym_type);

	my $pv= $r_rec->{PV};
	if (defined $pv)
	  { $r_rec->{name} = $pv . $recname;
	    delete $r_rec->{PV};
	  }
	else
	  { if (defined $prefix)
	      { $r_rec->{name} = $prefix . $recname; }
	    else
	      { my $r= $recname;
	        $r=~ s/\$\(([^\)]*)\)/VAR\($1\)/g;
	        warn "\"PV\" not defined in record \"$r\"," .
	             "this is incompatible with pipe-mode\n" .
		     "since I need to know the NAME of the input-file " .
		     "in this case.\n";
		$r_rec->{name}= $recname;
	      };
	  };      	     
	if ($name_to_desc)
	  { $r_rec->{DESC}= $r_rec->{name};
	    # quote dollar-signs in order to
	    # leave them unchanged:
	    $r_rec->{DESC}=~ s/\$/VAR/g;
	  };      
	
      };	
  }  

sub db_print 
  { my($filename, $r_h)= @_;
    local *F;
    
    my $oldfh;
    if (defined $filename)
      { open(F,">$filename") || die "unable to write to $filename\n"; 
        $oldfh= select(F);
      };
  
    foreach my $recname (sort keys %$r_h)
      { 
        my $r_rec= $r_h->{$recname};
        
	print  "record(",$r_rec->{type},",\"",$r_rec->{name},"\") {\n";
	foreach my $f (sort keys %$r_rec)
	  { next if ($f eq 'type');
	    next if ($f eq 'symbol_type');
	    next if ($f eq 'name');
	    
	    print  "    field($f,\"",$r_rec->{$f},"\")\n";
	  };
	print  "}\n";  
      };
    if (defined $filename)
      { select($oldfh);
        close(F) || die "unable to close $filename\n"; 
        
      };
  }  

    
sub handle_misc
  { my($r_rec,$recname)= @_;

    my $recdef= $rec_defaults{$r_rec->{symbol_type}};

    foreach my $key (keys %$r_rec)
      { # replace VAR(...) with $(...)

        if ($r_rec->{$key} =~ /\$\(/)
	  { my $st= 'warning:';
   	    $st.= " file \"$opt_file\"," if (defined $opt_file);
     	    $st.= " record \"$recname\": \n";
	    $st.= "possibly wrong field definition: \n";
	    $st.= "  \"$key = $r_rec->{$key}\"\n";
	    $st.= "use VAR(...) instead of \$(...) otherwise sch2edif " .
		  "ignores this \nfield definition\n\n";
	    warn($st);
	    next;
	  };

        $r_rec->{$key}=~ s/VAR\(([^\)]*)\)/\$\($1\)/g;
      
        if ($key=~/^def\(([^\)]+)\)/)
          { $r_rec->{$1}= $r_rec->{$key};
	    delete $r_rec->{$key};
            next;
	  }; 
      
	$r_rec->{$key}=~ s/\.SLNK\b/\.VAL/;
        
	if ($key =~ /^(typ|username)\(/)
          { delete $r_rec->{$key}; next;	  
	  };
	if ($key=~ /^(pproc|palrm)\(/)
          { delete $r_rec->{$key}; next; 	  
	  };

        next if (!defined $opt_warn_miss);
	
	# check for fields that are missing in the definitions in the
	# record's symbol file:

        # skip the 2 special fields 'PV' and 'symbol_type':	
        next if ($key eq 'PV');
        next if ($key eq 'symbol_type');
	
	next if (exists $recdef->{$key});
	if ($opt_warn_miss!=2)
	  { my $st= 'warning:';
	    $st.= " file \"$opt_file\"," if (defined $opt_file);
	    $st.= " record \"$recname\": \n";
	    $st.= "field $key is not defined in the symbol-file ";
	    $st.= $r_rec->{symbol_type} . ".sym\n\n";
	    warn($st); 
	  };
	  
	if ($opt_warn_miss>0)
	  { delete $r_rec->{$key}; };
	  
      };
  };

sub handle_defaults
  { my($r_rec,$sym_type)= @_;

    my $r_def= $rec_defaults{$sym_type};
    return if (!defined $r_def);
    
    if (defined $opt_no_defaults)
      { # just take the default for 'type':
        $r_rec->{type}= $r_def->{type} if (!exists $r_rec->{type});
	return;
      };
    
    foreach my $field (keys %$r_def)
      { $r_rec->{$field}= $r_def->{$field} if (!exists $r_rec->{$field});
      };
  };


# scan symbol files ---------------------------------------

sub scan_symbols
  { my($path,$r_defaults,$r_link_defaults,@symbol_list)= @_;
    # if symbol-list is empty, scan all 
    
    if (!-d $path)
      { die "error: \"$path\" is not a directory\n"; };

    my @files;
    if ($#symbol_list < 0)
      { @files= glob("$path/*.sym"); 
        if ($#files<0)
          { die "error: no symbol files found in \"$path\"\n"; };
      }
    else
      { my $p;
        foreach my $sym (@symbol_list)
          { $p= "$path/$sym.sym";
	    if (-r $p)
              { push @files,$p;
	      }
	    else
	      { warn "no symbol data found for \"$sym\""; };
	  };    
      };
    
    foreach my $file (@files)
      { 
        scan_sym_file($file,$r_defaults,$r_link_defaults);
      };
  }
  
  
  
sub scan_sym_file
  { my($file,$r_defaults,$r_link_defaults)= @_;
    local *F;
    my $emsg= "warning: symbol-file $file, double entry:\n";
    
    my $symname= basename($file);
    $symname=~ s/^(.*)\..*$/$1/;

    
    if (!exists $r_defaults->{$symname})
      { $r_defaults->{$symname}= {}; };
    my $r_rec_defaults= $r_defaults->{$symname};
    
    if (!exists $r_link_defaults->{$symname})
      { $r_link_defaults->{$symname}= {}; };
    my $r_rec_link_defaults= $r_link_defaults->{$symname};

    my $segment;
    my $lineno=0;

    open(F, $file) || die;
    my $line;
    my $st;
    my ($flag,$field,$val);
    while($line= <F>)
      { $lineno++;

	if ($line=~ /^\[([^\]]+)\]/)
          { $segment= $1; next; };
	 
	next if ($segment ne 'attributes'); 
	  
        # here we are in the "attributes" section	

	# chomp($line);
	
	($flag,$field,$val)= 
	       ($line=~ /(\S+)\s+                       # 1st character
	                 \S+\s+\S+\s+\S+\s+\S+\s+\S+\s+ # 5 dummies 
	                 ([^:]+):(.*)
		        /x);
	

        if ($flag ne 'p')
	  { 
	    # warn "warning: $file: line $lineno has an unknown format";
	    next;
	  };

	next if ($field eq 'primitive');
	# what is 'gensubA..D ??? 
	next if ($field eq 'name');

	$val= "" if (!defined $val);

	if ($field eq 'Type')
	  { # store the EPICS record-type:
	    if ($opt_warn_double)
	      { warn $emsg . "Type\n\n" if (exists $r_rec_defaults->{type}); };
	    $r_rec_defaults->{type}= $val;
	    # ^^^ this is put later into the record by handle_defaults() 
	    next;
	  };

	if ($field =~ /(\w+)\(([^\)]+)\)/)
	  { if ($1 eq 'val')
	      { # store things like "val(outp):#C0 S0" as they are
	        # found in hwout.sym and hwin.sym:
	        if ($opt_warn_double)
		  { warn $emsg . "$field\n\n" 
		         if (exists $r_rec_defaults->{$field});
		  };	
	        $r_rec_defaults->{$field} = $val;
	        next;
              };
	  
	    if ($1 eq 'typ')
	      { next if ($val ne 'path');
	        $r_rec_link_defaults->{$2}->{dummy} = 1; 
		next;
	      };
            if ($1 eq 'def')
	      { $r_rec_defaults->{$2}= $val; 
	        next;
	      };
            if ($1 eq 'pproc')
	      { $r_rec_link_defaults->{$2}->{proc}= $val; 
	        next;
	      };
            if ($1 eq 'palrm')
	      { $r_rec_link_defaults->{$2}->{alrm}= $val; 
	        next;
	      };
	    next;
	  };

	if ($opt_warn_double)
	  { warn $emsg . "$field\n\n" 
	         if (exists $r_rec_defaults->{$field});
	  };	 
	$r_rec_defaults->{$field}= $val; 

      };
    close(F);
  }

# debugging---------------------------------------

sub hdump
  { my($message,$hash_name,$r_h)= @_;
    my $st= "contents of hash \"$hash_name\":";
    my $ul= '_' x length($st);
    
    print "=" x 70,"\n";
    printf("%-12s%s\n","comment:",$message);
    print "-" x 70,"\n";
    printf("%-12s%s\n","hash:",$hash_name);
    print "-" x 70,"\n\n";
    
    
    print_meta_hash($r_h);
    print "=" x 70,"\n";
  }  

sub print_meta_hash
  { my($r_h)= @_;
  
    foreach my $key (sort keys %$r_h)
      { my $val= $r_h->{$key};
	if (!ref($val))
	  { print $key,'=>',$val,"\n"; 
	    next;
	  };
	
        if (ref($val) eq 'ARRAY')
	  { print "$key",'=> [',join(",",@$val),"]\n";
	    next;
	  };

        if (ref($val) eq 'HASH')
          { print "$key:\n---------------------\n";
	    print_hash( $val );
	    print "\n";
	    next;
	  };
	die "unsupported reference-type:" . ref($val) . "!";
      };
  }  


sub print_hash
  { my($r_h)= @_;
  
    foreach my $key (sort keys %$r_h)
      { my $val= $r_h->{$key};
        print "$key: ";
	if (!ref($val))
	  { print "$val\n"; next; }
	if (ref($val) eq 'ARRAY')
	  { print join("|",@$val),"\n"; next; };
	if (ref($val) eq 'HASH')
	  { foreach my $k (sort keys %$val)
	      { print $k,'=>',$val->{$k},' '; };
	    print "\n";
	    next;
	  }
	else
	  { die "unsupported ref encountered !"; };
      };
  };    

sub print_junction_error
  { my($type) = shift;
  
    my($wire,$count  )= (@_[0..1]);
    my($record,$field)= (@_[0..1]);
    
    my $p= $0;
    $p=~ s/.*?([^\/]+)$/$1/;
    my $file= (defined $opt_file) ? " in file \"$opt_file\"" : "";

    my $error_junction= <<END
Error with wire "$wire"$file. 
There is more than one wire with this name ($count to be exact) 
although they do not seem to belong to a junction. 
END
;

    my $error_many_ports= <<END
Error in field "$record.$field"$file.
There was more that one possible input-port found that is connected to
that output-port. A possible explanation is:
END
;    
    
    my $explain= <<END
Capfast sometimes produces wires that are not connected to each other 
but do have the same name. You have to rename these wires to have a unique 
name for each of them. You can do this by two ways:

1) edit the capfast (*.sch) file
   Look for "[detail]", then search for all occurences of the wire-name in 
   this section. Replace the number in the wire-name with a new, unique 
   number. 
   
2) using capfast
   select the wire, then select "text" and "relabel" and give the 
   wire a new name. The name should always be something like "n#xxxx" where 
   'xxxx' is a new, unique number. 
END
;
    
    if ($type eq 'many_ports')
      { die $error_many_ports . $explain; };
      
    if ($type eq 'junction')
      { die $error_junction . $explain; };
    
    die; # perl shouldn't reach this place
  }   
 
sub print_summary
  { my($p)= ($0=~ /([^\/\\]+)$/);
    printf("%-20s: a better sch to db converter\n",$p);
  }

sub print_help
  { my $p= $0;
    $p=~ s/.*?([^\/]+)$/$1/;
    print <<END
************* $p $version *****************
usage: $p {options} 
options:
  -h : this help
  -f [file]: read from the given file. Otherwise $p reads from STDIN 
  -o [file]: write to file. Otherwise write to stdout
  -s [symbol-file-path] read symbol files from the given path.
     Note: the default-path is:
     $opt_sympath 
  -m [par]: warn when fields of a record are used that are missing in 
      corresponding symbol-file. When [par] is '1' these fields
      are removed from the output. With '2' remove them, but do not warn
  -d : warn if multiple definitions for the same field are found in
      a symbol-file
  -n : no defaults, add no default values to the records
       this shows just the fields that are set by the capfast file
  --dump_symfile: scan and dump symbol files
  -S : use internal symbol data instead of reading symbol files
  --name_to_desc -D : patch the DESC field in order to be equal 
    to the record-name
END
  }
