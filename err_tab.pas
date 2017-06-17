unit err_tab;
(*
 * Unit defining the data structure of an "error table".
 *)

interface
uses generics;

const 
  max_et_size = 63;

type
  error_type  = string[35];
  error_table = ^et_struct;
  et_node = record
               etn_code : integer;
               etn_mesg : error_type;
            end;
  et_struct = array[0..max_et_size] of et_node;

function create : error_table;
procedure insert (var t:error_table; code:integer; message:error_type);
function lookup (var t:error_table; code:integer) : error_type;

(****************************************************************************)
implementation

function create : error_table;
var 
  i : integer;
  et_handle : error_table;
begin
  new(et_handle);
  for i := 0 to max_et_size do
     with et_handle^[i] do begin
        etn_code := $00;
        etn_mesg := '';
     end;
  create := et_handle;
end;

procedure insert (var t:error_table; code:integer; message:error_type);
var
  i : integer;
begin
  i := 0;
  while (i <= max_et_size) and (t^[i].etn_code <> 0) do i := i + 1;
  if (i < max_et_size) then
     with t^[i] do begin
       etn_code := code;
       etn_mesg := message;
     end;
end;

function lookup (var t:error_table; code:integer) : error_type;
var 
  found : boolean;
  i : integer;
begin
  found := false;
  i := 0;
  while not found and (i < max_et_size) and (t^[i].etn_code <> $00) do
     if (code = t^[i].etn_code) then
        found := true
     else
        i := i + 1;
  lookup := t^[i].etn_mesg;
end;

begin (* preamble *)
end.  (* preamble *)
