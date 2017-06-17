(******************** Turbo Pascal 4.0 Declarations **********************)
unit tpdecl;
{$l tpib}

interface
Const

(* GPIB Commands:                                                            *)

   UNL  =  $3f;                       (* GPIB unlisten command             *)
   UNT  =  $5f;                       (* GPIB untalk command               *)
   GTL  =  $01;                       (* GPIB go to local                  *)
   SDC  =  $04;                       (* GPIB selected device clear        *)
   PPC  =  $05;                       (* GPIB parallel poll configure      *)
   GGET =  $08;                       (* GPIB group execute trigger        *)
   TCT  =  $09;                       (* GPIB take control                 *)
   LLO  =  $11;                       (* GPIB local lock out               *)
   DCL  =  $14;                       (* GPIB device clear                 *)
   PPU  =  $15;                       (* GPIB parallel poll unconfigure    *)
   SPE  =  $18;                       (* GPIB serial poll enable           *)
   SPD  =  $19;   			(* GPIB serial poll disable          *)
   PPE  =  $60;   			(* GPIB parallel poll enable         *)
   PPD  =  $70;   			(* GPIB parallel poll disable        *)

(* GPIB status bit vector:                                                   *)

   ERR   = $8000;			(* Error detected                    *)
   TIMO  = $4000;			(* Timeout                           *)
   UEND  = $2000;			(* EOI or EOS detected               *)
   SRQI  = $1000;			(* SRQ detected by CIC               *)
   RQS   = $800; 			(* Device needs service              *)
   CMPL  = $100; 			(* I/O completed                     *)
   LOK   = $80;  			(* Local lockout state               *)
   REM   = $40;  			(* Remote state                      *)
   CIC   = $20;  			(* Controller-in-Charge              *)
   ATN   = $10;  			(* Attention asserted                *)
   TACS  = $8;   			(* Talker active                     *)
   LACS  = $4;   			(* Listener active                   *)
   DTAS  = $2;   			(* Device trigger state              *)
   DCAS  = $1;   			(* Device clear state                *)

(* Error messages returned in global variable IBERR:                         *)

   EDVR  = 0;                      (* DOS error                              *)
   ECIC  = 1; 		   	   (* Function requires GPIB board to be CIC *)
   ENOL  = 2; 		   	   (* Write function detected no Listeners   *)
   EADR  = 3; 		   	   (* Interface board not addressed correctly*)
   EARG  = 4; 		           (* Invalid argument to function call      *)
   ESAC  = 5; 		   	   (* Function requires GPIB board to be SAC *)
   EABO  = 6; 		   	   (* I/O operation aborted                  *)
   ENEB  = 7; 		   	   (* Non-existent interface board           *)
   EOIP  = 10;		   	   (* I/O operation started before previous  *)
		 		   (* operation completed                    *)
   ECAP  = 11;		   	   (* No capability for intended operation   *)
   EFSO  = 12;		   	   (* File system operation error            *)
   EBUS  = 14;		   	   (* Command error during device call       *)
   ESTB  = 15;		   	   (* Serial poll status byte lost           *)
   ESRQ  = 16;  		   (* SRQ remains asserted                   *)

(* EOS mode bits:                                                            *)

   BIN  = $1000;			(* Eight bit compare                 *)
   XEOS = $800; 			(* Send EOI with EOS byte            *)
   REOS = $400; 			(* Terminate read on EOS             *)


(* Timeout values and meanings:                                              *)

   TNONE    = 0;  			(* Infinite timeout  (disabled)      *)
   T10us    = 1;  			(* Timeout of 10 us  (ideal)         *)
   T30us    = 2;  			(* Timeout of 30 us  (ideal)         *)
   T100us   = 3;  			(* Timeout of 100 us (ideal)         *)
   T300us   = 4;  			(* Timeout of 300 us (ideal)         *)
   T1ms     = 5;  			(* Timeout of 1 ms   (ideal)         *)
   T3ms     = 6;  			(* Timeout of 3 ms   (ideal)         *)
   T10ms    = 7;  			(* Timeout of 10 ms  (ideal)         *)
   T30ms    = 8;  			(* Timeout of 30 ms  (ideal)         *)
   T100ms   = 9;  			(* Timeout of 100 ms (ideal)         *)
   T300ms   = 10; 			(* Timeout of 300 ms (ideal)         *)
   T1s      = 11; 			(* Timeout of 1 s    (ideal)         *)
   T3s      = 12; 			(* Timeout of 3 s    (ideal)         *)
   T10s     = 13; 			(* Timeout of 10 s   (ideal)         *)
   T30s     = 14; 			(* Timeout of 30 s   (ideal)         *)
   T100s    = 15; 			(* Timeout of 100 s  (ideal)         *)
   T300s    = 16; 			(* Timeout of 300 s  (ideal)         *)
   T1000s   = 17; 			(* Timeout of 1000 s (maximum)       *)

(* Miscellaneous:                                                            *)

   S  = $08;   			(* Parallel poll sense bit           *)
   LF = $0A;   			(* ASCII linefeed character          *)

(*****************************************************************************)

     	nbufsize = 7;		(* Length of board/device names -- hard-coded
				  in TPIB *)
	flbufsize = 50;		(* A generous length for filenames -- the
			          minimum allowed by the handler is 32.
				  50 is hard-coded in TPIB *)

(*****************************************************************************)

Type 	nbuf  = array[1..nbufsize]  of char; (*  device/board names   *)
	flbuf = array[1..flbufsize] of char; (*  filenames	    *)

(*****************************************************************************)

(* These three variables are to be accessed directly in application program. *)

var ibsta : word;   		(* status word                       *)
var iberr : word;   		(* GPIB error code                   *)
var ibcnt : word;   		(* number of bytes sent or DOS error *)

(* The following variables may be used directly in your application program. *)
Var
    bname  : nbuf;     			(* board name buffer                 *)
    bdname : nbuf;    			(* board or device name buffer       *)
    flname : flbuf;			(* filename buffer		     *)

   procedure  ibbna  (bd:integer;var bname:nbuf);

   procedure  ibcac  (bd:integer;v:integer);

   procedure  ibclr  (bd:integer); 

   procedure  ibcmd  (bd:integer; var cmd;cnt:integer); 

   procedure  ibcmda (bd:integer; var cmd;cnt:integer); 

   procedure  ibdiag (bd:integer;var rd;cnt:integer);

   procedure  ibdma  (bd:integer;v:integer); 

   procedure  ibeos  (bd:integer;v:integer);
	
   procedure  ibeot  (bd:integer;v:integer); 
	
   function   ibfind (var bdname:nbuf):integer;

   procedure  ibgts  (bd:integer;v:integer); 

   procedure  ibist  (bd:integer;v:integer);

   procedure  ibloc  (bd:integer);

   procedure  ibonl  (bd:integer;v:integer);

   procedure  ibpad  (bd:integer;v:integer);

   procedure  ibpct  (bd:integer);

   procedure  ibppc  (bd:integer;v:integer);

   procedure  ibrd   (bd:integer;var rd;cnt:integer);

   procedure  ibrda  (bd:integer;var rd;cnt:integer);

   procedure  ibrdf  (bd:integer;var flname:flbuf);
		
   procedure  ibrpp  (bd:integer;var ppr);
		
   procedure  ibrsc  (bd:integer;v:integer); 
			
   procedure  ibrsp  (bd:integer;var spr);

   procedure  ibrsv  (bd:integer;v:integer);

   procedure  ibsad  (bd:integer;v:integer); 
		
   procedure  ibsic  (bd:integer);

   procedure  ibsre  (bd:integer;v:integer); 
		
   procedure  ibstop (bd:integer); 

   procedure  ibtmo  (bd:integer;v:integer); 

   procedure  ibtrap (mask:integer;v:integer);

   procedure  ibtrg  (bd:integer); 

   procedure  ibwait (bd:integer;mask:integer);

   procedure  ibwrt  (bd:integer;var wrt;cnt:integer); 

   procedure  ibwrta (bd:integer;var wrt;cnt:integer);

   procedure  ibwrtf (bd:integer;var flname:flbuf);


implementation

var
	found:integer;		(* flag set after first successful ibfind *)
        our_lcv: integer;	(* local loop control variable       *)


(* The GPIB board functions declared public by TPIB.OBJ:                     *)


   procedure  ibbna  (bd:integer;var bname:nbuf); external;

   procedure  ibcac  (bd:integer;v:integer); external;

   procedure  ibclr  (bd:integer); external;

   procedure  ibcmd  (bd:integer; var cmd;cnt:integer); external;

   procedure  ibcmda (bd:integer; var cmd;cnt:integer); external;

   procedure  ibdiag (bd:integer;var rd;cnt:integer); external;

   procedure  ibdma  (bd:integer;v:integer); external;

   procedure  ibeos  (bd:integer;v:integer); external;
	
   procedure  ibeot  (bd:integer;v:integer); external;
	
   function   ibfind (var bdname:nbuf):integer; external;

   procedure  ibgts  (bd:integer;v:integer); external;

   procedure  ibist  (bd:integer;v:integer); external;
			
   procedure  ibloc  (bd:integer); external;

   procedure  ibonl  (bd:integer;v:integer); external;
		
   procedure  ibpad  (bd:integer;v:integer); external;
		
   procedure  ibpct  (bd:integer); external;

   procedure  ibppc  (bd:integer;v:integer); external;

   procedure  ibrd   (bd:integer;var rd;cnt:integer); external;

   procedure  ibrda  (bd:integer;var rd;cnt:integer); external;

   procedure  ibrdf  (bd:integer;var flname:flbuf); external;
		
   procedure  ibrpp  (bd:integer;var ppr); external;
		
   procedure  ibrsc  (bd:integer;v:integer); external;

   procedure  ibrsp  (bd:integer;var spr); external;

   procedure  ibrsv  (bd:integer;v:integer); external;

   procedure  ibsad  (bd:integer;v:integer); external;

   procedure  ibsic  (bd:integer); external;

   procedure  ibsre  (bd:integer;v:integer); external;
		
   procedure  ibstop (bd:integer); external;

   procedure  ibtmo  (bd:integer;v:integer); external;

   procedure  ibtrap (mask:integer;v:integer); external;
		
   procedure  ibtrg  (bd:integer); external;

   procedure  ibwait (bd:integer;mask:integer); external;

   procedure  ibwrt  (bd:integer;var wrt;cnt:integer); external;

   procedure  ibwrta (bd:integer;var wrt;cnt:integer); external;

   procedure  ibwrtf (bd:integer;var flname:flbuf); external;


begin
	found:=0;	(* initialize successful ibfind flag *)
	ibsta:=0;	(*  initialize global status variables *)
	iberr:=0;		
	ibcnt:=0;
	for our_lcv:=1 to nbufsize do	(* blank fill name buffers *)
        begin				
		bname[our_lcv]:=' ';
                bdname[our_lcv]:=' ';
        end;
	for our_lcv:=1 to flbufsize do
		flname[our_lcv]:=' ';
end.
