unit rt_error;
(*
 * Run-time error message implementation
 * 	problem returns the run-time error message for a code
 *	complain prints out a generic error message for a given code.
 *)

interface
uses 
  generics, err_tab;

function problem (code:integer) : error_type;
procedure complain (code:integer; caller:string31; message:string63);

(****************************************************************************)
implementation
var
  rt_et : error_table;

function problem (code:integer) : error_type;
begin
  problem := err_tab.lookup(rt_et, code);
end;

procedure complain (code:integer; caller:string31; message:string63);
begin
  writeln(caller,': ', message, ': ', problem(code));
end;

begin
  rt_et := err_tab.create;
  err_tab.insert (rt_et,   2, 'file not found.');
  err_tab.insert (rt_et,   3, 'path not found.');
  err_tab.insert (rt_et,   4, 'too many open files.');
  err_tab.insert (rt_et,   5, 'file access denied.');
  err_tab.insert (rt_et,   6, 'invalid file handle.');
  err_tab.insert (rt_et,  12, 'invalid file access code.');
  err_tab.insert (rt_et,  15, 'invalid drive number.');
  err_tab.insert (rt_et,  16, 'cannot remove current directory.');
  err_tab.insert (rt_et,  17, 'cannot rename across drives.');
  err_tab.insert (rt_et, 100, 'disk read error.');
  err_tab.insert (rt_et, 101, 'disk write error.');
  err_tab.insert (rt_et, 102, 'file not assigned.');
  err_tab.insert (rt_et, 103, 'file not open.');
  err_tab.insert (rt_et, 104, 'file not open for input.');
  err_tab.insert (rt_et, 105, 'file not open for output.');
  err_tab.insert (rt_et, 106, 'invalid numeric format.');
  err_tab.insert (rt_et, 150, 'disk is write-protected.');
  err_tab.insert (rt_et, 151, 'unknown unit.');
  err_tab.insert (rt_et, 152, 'drive not ready.');
  err_tab.insert (rt_et, 153, 'unknown command.');
  err_tab.insert (rt_et, 154, 'CRC error in data.');
  err_tab.insert (rt_et, 155, 'bad drive request structure length.');
  err_tab.insert (rt_et, 156, 'disk seek error.');
  err_tab.insert (rt_et, 157, 'unknown media type.');
  err_tab.insert (rt_et, 158, 'sector not found.');
  err_tab.insert (rt_et, 159, 'printer out of paper.');
  err_tab.insert (rt_et, 160, 'device write fault.');
  err_tab.insert (rt_et, 161, 'device read fault.');
  err_tab.insert (rt_et, 162, 'hardware failure.');
  err_tab.insert (rt_et, 200, 'division by zero.');
  err_tab.insert (rt_et, 201, 'range check error.');
  err_tab.insert (rt_et, 202, 'stack overflow error.');
  err_tab.insert (rt_et, 203, 'heap overflow error.');
  err_tab.insert (rt_et, 204, 'invalid pointer operation.');
  err_tab.insert (rt_et, 205, 'floating point overflow.');
  err_tab.insert (rt_et, 206, 'floating point underflow.');
  err_tab.insert (rt_et, 207, 'invalid floating point operation.');
end.
