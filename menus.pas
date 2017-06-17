unit menus;
(*
 * Menus module for MOS.  The menus are defined here because putting them
 * in the main program files clutters it, and makes the code segment very
 * large.
 *)
interface
uses crt, parser;

const
  CMD_DIR	= $0010;
  CMD_SAVE	= $0011;
  CMD_PLOT	= $0012;
  CMD_NX	= $0013;
  CMD_NP	= $0014;
  CMD_YMAX	= $0015;
  CMD_YMIN	= $0016;
  CMD_DO	= $0017;
  CMD_X1	= $0019;
  CMD_X2	= $001A;
  CMD_P1	= $001B;
  CMD_P2	= $001C;
  CMD_ZERO	= $001D;
  CMD_SWEEP	= $001E;
  CMD_COMMENT	= $001F;

  CMD_IV4140	= $0020;
  CMD_CV4140	= $0021;
  CMD_CV4192	= $0022;
  CMD_READ	= $0023;
  CMD_XLABEL	= $0024;
  CMD_YLABEL	= $0025;
  CMD_PLABEL	= $0026;
  CMD_CHDIR	= $0027;
  CMD_MODIFY	= $0028;
  CMD_SRC	= $0029;
  CMD_GIV	= $002A;
  CMD_DEEPCV	= $002B;

  CMD_THOLD	= $0100;
  CMD_TSTEP	= $0101;

  CMD_OL	= $0206;

  CMD_DYDX	= $0300;
  CMD_DYDP	= $0301;
  CMD_MULT	= $0302;
  CMD_LOG	= $0303;
  CMD_LN	= $0304;
  CMD_EXP	= $0305;
  CMD_RECIP	= $0306;
  CMD_POW	= $0307;
  CMD_ADD	= $0308;
  CMD_DIV	= $0309;
  CMD_SMOOTH    = $030A;
  CMD_DOPING	= $030B;
  CMD_VTH	= $030C;

  CMD_SETX	= $0400;
  CMD_SETP	= $0401;
  CMD_SETGND	= $0402;
  CMD_SETBIAS	= $0403;
  CMD_BIAS	= $0404;

var
  IV_menu : cmd_table;
  QCV_menu : cmd_table;
  ACV_menu : cmd_table;
  DCV_menu : cmd_table;
  modify_menu : cmd_table;
  top_level : cmd_table;
  GIV_menu : cmd_table;

(****************************************************************************)
implementation
const
  noop_action:cmd_node =
     (tags:('','');
      code:CMD_NOOP;
      doc:'');
  help_action:cmd_node =
     (tags:('help','?');
      code:CMD_HELP;
      doc:'brief help [on COMMAND]');
  quit_action:cmd_node =
     (tags:('quit','q');
      code:CMD_QUIT;
      doc:'return to previous menu');
  save_action:cmd_node =
     (tags:('save','sv');
      code:CMD_SAVE;
      doc:'save data set [in FILE]');
  plot_action:cmd_node =
     (tags:('plot','pt');
      code:CMD_PLOT;
      doc:'plot data set');
  xlabel_action:cmd_node =
     (tags:('x_label','xl');
      code:CMD_XLABEL;
      doc:'set x label to be STRING');
  ylabel_action:cmd_node =
     (tags:('y_label','yl');
      code:CMD_YLABEL;
      doc:'set y label to be STRING');
  plabel_action:cmd_node =
     (tags:('p_label','pl');
      code:CMD_PLABEL;
      doc:'set p label to be STRING');
  comment_action:cmd_node =
     (tags:('remark','rem');
      code:CMD_COMMENT;
      doc:'set remark N to be STRING');
  zero_action:cmd_node =
     (tags:('zero','z');
      code:CMD_ZERO;
      doc:'zero instrument');
  src_action:cmd_node =
     (tags:('macro','do');
      code:CMD_SRC;
      doc:'read commands [from FILE]');
  do_action:cmd_node =
     (tags:('go','g');
      code:CMD_DO;
      doc:'perform measurement');
  x1_action:cmd_node =
     (tags:('x_start','x1');
      code:CMD_X1;
      doc:'set start value of X variable');
  x2_action:cmd_node =
     (tags:('x_stop','x2');
      code:CMD_X2;
      doc:'set stop value of X variable');
  nx_action:cmd_node =
     (tags:('x_step','dx');
      code:CMD_NX;
      doc:'set step size on X variable');
  p1_action:cmd_node =
     (tags:('p_start','p1');
      code:CMD_P1;
      doc:'set start value of P parameter');
  p2_action:cmd_node =
     (tags:('p_stop','p2');
      code:CMD_P2;
      doc:'set stop value of P parameter');
  np_action:cmd_node =
     (tags:('p_step','dp');
      code:CMD_NP;
      doc:'set step size on P parameter');
  tstep_action:cmd_node =
     (tags:('t_step','ts');
      code:CMD_TSTEP;
      doc:'set step delay time in staircase');
  thold_action:cmd_node =
     (tags:('t_hold','th');
      code:CMD_THOLD;
      doc:'set hold time prior to sweep');
  ymin_action:cmd_node =
     (tags:('min_y','y-');
      code:CMD_YMIN;
      doc:'set min expected Y value');
  ymax_action:cmd_node =
     (tags:('max_y','y+');
      code:CMD_YMAX;
      doc:'set max expected Y value');
  ol_action:cmd_node =
     (tags:('osc_level','ol');
      code:CMD_OL;
      doc:'set AC oscillator amplitude');
  va_action:cmd_node =
     (tags:('v_accum','va');
      code:CMD_SETBIAS;
      doc:'set deep depletion base voltage');
  add_action:cmd_node =
     (tags:('add', '+');
      code:CMD_ADD;
      doc:'shift ARRAY by adding NUMBER to it');
  mult_action:cmd_node =
     (tags:('mul','*');
      code:CMD_MULT;
      doc:'multiply ARRAY by NUMBER');
  div_action:cmd_node =
     (tags:('div','/');
      code:CMD_DIV;
      doc:'divide ARRAY by NUMBER');
  recip_action:cmd_node =
     (tags:('recip','1/');
      code:CMD_RECIP;
      doc:'convert ARRAY to 1/ARRAY');
  log_action:cmd_node =
     (tags:('log10', 'log');
      code:CMD_LOG;
      doc:'convert ARRAY to log10(ARRAY)');
  ln_action:cmd_node =
     (tags:('loge','ln');
      code:CMD_LN;
      doc:'convert ARRAY to ln(ARRAY)');
  exp_action:cmd_node =
     (tags:('exp','e');
      code:CMD_EXP;
      doc:'exponentiate ARRAY');
  pow_action:cmd_node =
     (tags:('power','pow');
      code:CMD_POW;
      doc:'raise ARRAY to POWER');
  doping_action:cmd_node =
     (tags:('doping','dop');
      code:CMD_DOPING;
      doc:'extract substrate doping from C-V');
  dydx_action:cmd_node =
     (tags:('dydx','dx');
      code:CMD_DYDX;
      doc:'convert y into dy/dx (over N pts)');
  dydp_action:cmd_node =
     (tags:('dydp','dp');
      code:CMD_DYDP;
      doc:'convert y into dy/dp (over N pts)');
  smooth_action:cmd_node =
     (tags:('smooth','sm');
      code:CMD_SMOOTH;
      doc:'smooth Y along X (over N pts)');
  vth_action:cmd_node =
     (tags:('thresh','vth');
      code:CMD_VTH;
      doc:'measure threshold voltages');
  dir_action:cmd_node =
     (tags:('dir', 'ls');
      code:CMD_DIR;
      doc:'list contents of working dir');
  chdir_action:cmd_node =
     (tags:('chdir','cd');
      code:CMD_CHDIR;
      doc:'change directory to DIR');
  read_action:cmd_node =
     (tags:('read','rd');
      code:CMD_READ;
      doc:'read data set from disk [from FILE]');
  giv_action:cmd_node =
     (tags:('mp_iv','iv4');
      code:CMD_GIV;
      doc:'I-V curves with D/A voltages');
  iv4140_action:cmd_node =
     (tags:('hp_iv','iv');
      code:CMD_IV4140;
      doc:'I-V curves with HP4140B (Va, Vb)');
  cv4140_action:cmd_node =
     (tags:('qs_cv','cvr');
      code:CMD_CV4140;
      doc:'ramped C-V curves, ramp rate parameter');
  cv4192_action:cmd_node =
     (tags:('ac_cv','cvf');
      code:CMD_CV4192;
      doc:'AC C-V curves, osc. freq. parameter');
  deepcv_action:cmd_node =
     (tags:('deep_cv','dcv');
      code:CMD_DEEPCV;
      doc:'Deep Depletion C-V curves, freq. parameter');
  modify_action:cmd_node =
     (tags:('modify','mod');
      code:CMD_MODIFY;
      doc:'manipulate data set mathematically');
  setx_action:cmd_node =
     (tags:('asgn_x','asx');
      code:CMD_SETX;
      doc:'assign TERMINAL as the X voltage');
  setp_action:cmd_node =
     (tags:('asgn_p','asp');
      code:CMD_SETP;
      doc:'assign TERMINAL as the P voltage');
  setgnd_action:cmd_node =
     (tags:('asgn_g','asg');
      code:CMD_SETGND;
      doc:'assign TERMINAL as the ground node');
  setbias_action:cmd_node =
     (tags:('asgn_b','asb');
      code:CMD_SETBIAS;
      doc:'assign TERMINAL as the bias node');
  bias_action:cmd_node =
     (tags:('bias','bv');
      code:CMD_BIAS;
      doc:'set bias voltage');
  sweep_action:cmd_node =
     (tags:('sweep','sw');
      code:CMD_SWEEP;
      doc:'toggle uni/bidirectional sweep mode');

begin (* preamble *)
   with IV_menu do begin
      name := 'I-V curves: HP 4140B is ammeter & voltmeter';
      tint := LightMagenta;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @xlabel_action;
      list[ 6] := @ylabel_action;
      list[ 7] := @plabel_action;
      list[ 8] := @comment_action;
      list[ 9] := @x1_action;
      list[10] := @x2_action;
      list[11] := @nx_action;
      list[12] := @tstep_action;
      list[13] := @p1_action;
      list[14] := @p2_action;
      list[15] := @np_action;
      list[16] := @thold_action;
      list[17] := @ymin_action;
      list[18] := @ymax_action;
      list[19] := @zero_action;
      list[20] := @do_action;
      list[21] := @sweep_action;
      list[22] := @src_action;
      list[23] := nil;
      list[24] := nil;
   end;
   with QCV_menu do begin
      name := 'Quasi-Static C-V curves: ramp rate is parameter';
      tint := LightGreen;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @xlabel_action;
      list[ 6] := @ylabel_action;
      list[ 7] := @plabel_action;
      list[ 8] := @comment_action;
      list[ 9] := @x1_action;
      list[10] := @x2_action;
      list[11] := @nx_action;
      list[12] := @noop_action;
      list[13] := @p1_action;
      list[14] := @p2_action;
      list[15] := @np_action;
      list[16] := @thold_action;
      list[17] := @ymin_action;
      list[18] := @ymax_action;
      list[19] := @zero_action;
      list[20] := @do_action;
      list[21] := @sweep_action;
      list[22] := @src_action;
      list[23] := nil;
      list[24] := nil;
   end;
   with ACV_menu do begin
      name := 'AC C-V curves on HP 4192A: frequency is parameter';
      tint := LightCyan;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @xlabel_action;
      list[ 6] := @ylabel_action;
      list[ 7] := @plabel_action;
      list[ 8] := @comment_action;
      list[ 9] := @x1_action;
      list[10] := @x2_action;
      list[11] := @nx_action;
      list[12] := @tstep_action;
      list[13] := @p1_action;
      list[14] := @p2_action;
      list[15] := @np_action;
      list[16] := @thold_action;
      list[17] := @ymin_action;
      list[18] := @ymax_action;
      list[19] := @ol_action;
      list[20] := @zero_action;
      list[21] := @do_action;
      list[22] := @src_action;
      list[23] := nil;
      list[24] := nil;
   end;
   with DCV_menu do begin
      name := 'Deep Depletion C-V curves: frequency is parameter';
      tint := LightGray;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @xlabel_action;
      list[ 6] := @ylabel_action;
      list[ 7] := @plabel_action;
      list[ 8] := @comment_action;
      list[ 9] := @x1_action;
      list[10] := @x2_action;
      list[11] := @nx_action;
      list[12] := @tstep_action;
      list[13] := @p1_action;
      list[14] := @p2_action;
      list[15] := @np_action;
      list[16] := @thold_action;
      list[17] := @ymin_action;
      list[18] := @ymax_action;
      list[19] := @ol_action;
      list[20] := @va_action;
      list[21] := @zero_action;
      list[22] := @do_action;
      list[23] := @src_action;
      list[24] := nil;
   end;
   with modify_menu do begin
      name := 'Data Set Modification';
      tint := LightRed;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @xlabel_action;
      list[ 6] := @ylabel_action;
      list[ 7] := @plabel_action;
      list[ 8] := @comment_action;
      list[ 9] := @add_action;
      list[10] := @mult_action;
      list[11] := @div_action;
      list[12] := @recip_action;
      list[13] := @log_action;
      list[14] := @ln_action;
      list[15] := @exp_action;
      list[16] := @pow_action;
      list[17] := @dydx_action;
      list[18] := @dydp_action;
      list[19] := @vth_action;
      list[20] := @doping_action;
      list[21] := @smooth_action;
      list[22] := @src_action;
      list[23] := nil;
      list[24] := nil;
   end;
   with top_level do begin
      name := 'Top Level';
      tint := Yellow;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @dir_action;
      list[ 4] := @chdir_action;
      list[ 5] := @src_action;
      list[ 6] := @save_action;
      list[ 7] := @read_action;
      list[ 8] := @plot_action;
      list[ 9] := @xlabel_action;
      list[10] := @ylabel_action;
      list[11] := @plabel_action;
      list[12] := @comment_action;
      list[13] := @giv_action;
      list[14] := @iv4140_action;
      list[15] := @cv4140_action;
      list[16] := @cv4192_action;
      list[17] := @deepcv_action;
      list[18] := @modify_action;
      list[19] := nil;
      list[20] := nil;
      list[21] := nil;
      list[22] := nil;
      list[23] := nil;
      list[24] := nil;
   end;
   with GIV_menu do begin
      name := 'I-V curves: HP 4140B is ammeter, D/A are voltages';
      tint := White;
      list[ 1] := @help_action;
      list[ 2] := @quit_action;
      list[ 3] := @save_action;
      list[ 4] := @plot_action;
      list[ 5] := @x1_action;
      list[ 6] := @x2_action;
      list[ 7] := @nx_action;
      list[ 8] := @tstep_action;
      list[ 9] := @p1_action;
      list[10] := @p2_action;
      list[11] := @np_action;
      list[12] := @thold_action;
      list[13] := @ymin_action;
      list[14] := @ymax_action;
      list[15] := @zero_action;
      list[16] := @do_action;
      list[17] := @setx_action;
      list[18] := @setp_action;
      list[19] := @setgnd_action;
      list[20] := @setbias_action;
      list[21] := @bias_action;
      list[22] := @sweep_action;
      list[23] := @comment_action;
      list[24] := @src_action;
   end;
end.  (* preamble *)
