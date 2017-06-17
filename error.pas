unit error;
(*
 * Unit defining the data structure of an "error table".
 * Rewritten to include the run-time error table, and for OOP (TP5.5).
 *)

interface
uses generics;

const 
  max_et_size = 47;

type
  error_type  = string[35];
  error_ptr   = ^error_node;
  error_node  = record
  		   code : integer;
		   mesg : error_type;
		   next : error_ptr;
  		end;
  error_table = object
  		  table : error_ptr;
	          constructor init;
		  destructor done;
		  procedure add (code:integer; message:error_type);
		  function lookup (code:integer) : error_type;
		  procedure complain (code:integer; caller,message:string63);
	        end;


(*
 * Specific error tables
 *)
var
  runtime : error_table;

(****************************************************************************)
implementation

constructor error_table.init;
var 
  i : integer;
begin
  table := nil;
end;

destructor error_table.done;
var
  np : error_ptr;
begin
  while (table <> nil) do begin
    np := table^.next;
    dispose(table);
    table := np;
  end;
end;

procedure error_table.add (code:integer; message:error_type);
var
  np : error_ptr;
begin
  new(np);
  np^.code := code;
  np^.mesg := message;
  np^.next := table;
  table := np;
end;

function error_table.lookup (code:integer) : error_type;
var 
  found : boolean;
  np : error_ptr;
begin
  found := FALSE;
  np := table;
  while (not found) and (np <> nil) do
     if (code = np^.code) then
        found := TRUE
     else
        np := np^.next;
  if (found) then
     lookup := np^.mesg
  else
     lookup := '';
end;

procedure error_table.complain (code:integer; caller,message:string63);
begin
  writeln(caller,': ', message, ': ', lookup(code));
end;

begin (* preamble *)
  runtime.init;
  (*
   * DOS errors
   *)
  runtime.add(  2, 'file not found');
  runtime.add(  3, 'path not found');
  runtime.add(  4, 'too many open files');
  runtime.add(  5, 'file access denied');
  runtime.add(  6, 'invalid file handle');
  runtime.add( 12, 'invalid file access code');
  runtime.add( 15, 'invalid drive number');
  runtime.add( 16, 'cannot remove current directory');
  runtime.add( 17, 'cannot rename across drives');
  (*
   * I/O errors
   *)
  runtime.add(100, 'disk read error');
  runtime.add(101, 'disk write error');
  runtime.add(102, 'file not assigned');
  runtime.add(103, 'file not open');
  runtime.add(104, 'file not open for input');
  runtime.add(105, 'file not open for output');
  runtime.add(106, 'invalid numeric format');
  (*
   * Critical errors
   *)
  runtime.add(150, 'disk is write-protected');
  runtime.add(151, 'unknown unit');
  runtime.add(152, 'drive not ready');
  runtime.add(153, 'unknown command');
  runtime.add(154, 'CRC error in data');
  runtime.add(155, 'bad drive request structure length');
  runtime.add(156, 'disk seek error');
  runtime.add(157, 'unknown media type');
  runtime.add(158, 'sector not found');
  runtime.add(159, 'printer out of paper');
  runtime.add(160, 'device write fault');
  runtime.add(161, 'device read fault');
  runtime.add(162, 'hardware failure');
  (*
   * Fatal errors
   *)
  runtime.add(200, 'division by zero');
  runtime.add(201, 'range check error');
  runtime.add(202, 'stack overflow error');
  runtime.add(203, 'heap overflow error');
  runtime.add(204, 'invalid pointer operation');
  runtime.add(205, 'floating point overflow');
  runtime.add(206, 'floating point underflow');
  runtime.add(207, 'invalid floating point operation');
end.  (* preamble *)
