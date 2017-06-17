unit values;
(*
 * This unit defines the data type "value".
 * It is used to be able to conveniently switch between integers, shortints,
 * doubles, singles, etc.
 *)

interface
const
  max_points = 512;
  max_params = 16;
type
  index = integer;
  value = real;
  param = value;
  valarr = array[1..max_points] of value;
  valarrarr = array[1..max_params] of valarr;
  idxarr = array[1..max_params] of index;
  pararr = array[1..max_params] of param;

(****************************************************************************)
implementation
begin (* preamble *)
end.  (* preamble *)
