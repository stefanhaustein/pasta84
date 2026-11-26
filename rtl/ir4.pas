(* ===================================================================== *)
(* === IR4th run-time library declarations ============================= *)
(* ===================================================================== *)

const
  LineBreak = #10;

  MaxInt = 32767;
  MinInt = -32768;

  Black   = 0;
  Blue    = 1;
  Red     = 2;
  Magenta = 3;
  Green   = 4;
  Cyan    = 5;
  Yellow  = 6;
  White   = 7;

var
  RandSeed1: Integer absolute '__randseed1';
  RandSeed2: Integer absolute '__randseed2';
  ExitCode: Integer absolute '__exitcode';
  DosExitCode: Byte absolute '__dos_exitcode';
  LastError: Byte absolute '__lasterror';
  AssertPassed: Integer absolute '__assertpassed';
  AssertFailed: Integer absolute '__assertfailed';

function IOResult: Byte; external 'pas_ioresult';
procedure BDosThrow; external 'pas_bdosthrow';

function Sin(X: Real): Real; external 'sin';
function Cos(X: Real): Real; external 'cos';
function ArcTan(X: Real): Real; external 'arctan';
function Sqrt(X: Real): Real; external 'sqrt';
function Ln(X: Real): Real; external 'ln';
function Exp(X: Real): Real; external 'exp';
function Int(X: Real): Real; external 'fint';
function Frac(X: Real): Real; external 'frac';
function Sqr(X: Real): Real; external 'pas_sqr_f';
function Log(X: Real): Real; external 'pas_log10';
function Pi: Real; external 'pas_pi';
function MaxReal: Real; external 'pas_maxreal';
function MinReal: Real; external 'pas_minreal';
function Round(X: Real): Integer; external 'pas_round';
function Trunc(X: Real): Integer; external 'pas_trunc';

function Tan(X: Real): Real; external 'pas_tan';
procedure CheckBreak; external 'pas_noop';
procedure CheckStack; external 'pas_noop';

function ScreenWidth: Integer; external 'termwidth';
function ScreenHeight: Integer; external 'termheight';

procedure ClrScr; external 'pas_clrscr';
procedure ClrEol; external 'pas_clreol';
procedure CursorOff; external 'pas_cursor_off';
procedure CursorOn; external 'pas_cursor_on';
procedure GotoXY(X, Y: Integer); external 'pas_gotoxy';
function WhereX: Integer; external 'pas_wherex';
function WhereY: Integer; external 'pas_wherey';
procedure TextColor(I: Integer); external 'pas_textfg';
procedure TextBackground(I: Integer); external 'pas_textbg';
function ReadKey: Char; external 'pas_readkey';
function KeyPressed: Boolean; external 'pas_keypressed';
procedure Delay(Duration: Integer); external 'syssleep';

function ParamCount: Byte; external 'pas_paramcount';
function ParamStr(I: Byte): String; external 'pas_paramstr';

procedure Plot(X, Y: Integer); external 'pas_plot';
function Point(X, Y: Integer): Boolean; external 'pas_point';
procedure Draw(DX, DY: Integer); external 'pas_draw';
procedure Circle(CX, CY, Radius: Integer); external 'pas_circle';
procedure FloodFill(X, Y: Integer); external 'pas_floodfill';
procedure SetColor(Color: Integer); external 'pas_setcolor';
procedure SetGraphMode(Mode: Integer); external 'pas_setgraphmode';
procedure Border(Color: Integer); external 'pas_border';

function Length(S: String): Integer; external 'pas_strlen';
function Copy(S: String; Start, Count: Integer): String; external 'pas_copy';
function Pos(Sub, S: String): Integer; external 'pas_pos';

(* Sets the length byte of a ShortString (clamped to 0..255).
   Caveats:
   - PASTA/84 accepts String[N] arguments for `var S: String` without checking
     capacity at compile time or runtime; growing Len beyond N is unsafe.
   - Only updates S[0] (ShortString semantics); bytes past the previous length
     are left uninitialized when growing. *)
procedure SetLength(var S: String; Len: Integer); external 'pas_setlength';

procedure GetMem(var P: Pointer; Size: Integer); external 'pas_getmem';
procedure FreeMem(P: Pointer; Size: Integer); external 'pas_freemem';
function MemAvail: Integer; external 'pas_memavail';
function MaxAvail: Integer; external 'pas_maxavail';
procedure DefragMem; external 'pas_noop';
procedure Move(var Source, Dest; Count: Integer); external 'pas_move';

function RandomInt(Range: Integer): Integer; external 'pas_random';
function RandomReal: Real; external 'pas_random_f';

procedure Randomize; external 'pas_randomize';
function Chr(B: Byte): Char; external 'pas_chr';
function Hi(W: Integer): Byte; external 'pas_hi';
function Lo(W: Integer): Byte; external 'pas_lo';
function Swap(W: Integer): Integer; external 'pas_swap';
function UpCase(C: Char): Char; external 'pas_upcase';
function LoCase(C: Char): Char; external 'pas_locase';

procedure BlockAssign(var F: File; S: String); external 'pas_block_assign';
procedure BlockReset(var F: File; RecSize: Integer); external 'pas_block_reset';
procedure BlockRewrite(var F: File; RecSize: Integer); external 'pas_block_rewrite';
procedure BlockClose(var F: File); external 'pas_block_close';
function BlockEof(var F: File): Boolean; external 'pas_block_eof';
procedure BlockBlockRead(var F: File; var Buf; Count: Integer; var Actual: Integer); external 'pas_block_read';
procedure BlockBlockWrite(var F: File; var Buf; Count: Integer; var Actual: Integer); external 'pas_block_write';

procedure BlockErase(var F: File); external 'pas_block_erase';
procedure BlockRename(var F: File; S: String); external 'pas_block_rename';

procedure BlockAppend(var F: File); external 'pas_block_append';

procedure BlockFlush(var F: File); external 'pas_block_flush';
procedure BlockSeek(var F: File; Pos: Integer); external 'pas_block_seek';
function BlockFilePos(var F: File): Integer; external 'pas_block_pos';
function BlockFileSize(var F: File): Integer; external 'pas_block_size';

procedure TextAssign(var T: Text; S: String); external 'pas_text_assign';
procedure TextReset(var T: Text); external 'pas_text_reset';
procedure TextRewrite(var T: Text); external 'pas_text_rewrite';
procedure TextClose(var T: Text); external 'pas_block_close';
function TextEof(var T: Text): Boolean; external 'pas_text_eof';
function TextEoln(var T: Text): Boolean; external 'pas_text_eoln';
procedure TextReadChar(var T: Text; var C: Char); external 'pas_text_readc';
procedure TextReadStr(var T: Text; var S: String; Max: Byte); external 'pas_text_reads';
procedure TextReadInt(var T: Text; var I: Integer); external 'pas_text_readi';
procedure TextReadFloat(var T: Text; var R: Real); external 'pas_text_readf';
procedure TextReadEnum(var T: Text; var E; Tab: Pointer); external 'pas_text_reade';
procedure TextSkipToEoln(var T: Text); external 'pas_text_skipeoln';
procedure TextWriteStr(var T: Text; S: String); external 'pas_text_writes';
procedure TextWriteEoln(var T: Text); external 'pas_text_writeeoln';
procedure TextAppend(var T: Text); external 'pas_text_append';
procedure TextFlush(var T: Text); external 'pas_block_flush';

function TextSeekEof(var T: Text): Boolean; external 'pas_text_eof';
function TextSeekEoln(var T: Text): Boolean; external 'pas_text_eoln';

procedure FileAssign(var F: File; S: String; RecSize: Integer); external 'pas_file_assign';
procedure FileReset(var F: File); external 'pas_file_reset';
procedure FileRewrite(var F: File); external 'pas_file_rewrite';
procedure FileClose(var F: File); external 'pas_block_close';
function FileEof(var F: File): Boolean; external 'pas_block_eof';
procedure FileRead(var F: File; var Buf); external 'pas_file_read';
procedure FileWrite(var F: File; var Buf); external 'pas_file_write';
procedure FileFlush(var F: File); external 'pas_block_flush';
procedure FileSeek(var F: File; Pos: Integer); external 'pas_block_seek';
function FileFilePos(var F: File): Integer; external 'pas_block_pos';
function FileFileSize(var F: File): Integer; external 'pas_block_size';

end.
