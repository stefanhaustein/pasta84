(* -------------------------------------------------------------------------- *)
(* --- Pascal Compiler ------------------------------------------------------ *)
(* -------------------------------------------------------------------------- *)

program Pasta;

{$ifndef SYS_IR4}
{$mode delphi}

uses
  {$ifdef darwin} BaseUnix, {$endif} SysUtils, Dos, Math, Process;
{$else}
{$i dos.pas}
{$i sysutils.pas}
{$endif}

const
  Version = '1.00';

(* -------------------------------------------------------------------------- *)
(* --- Utility functions ---------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

function ReplaceChar(S: String; C, D: Char): String;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if S[I] = C then S[I] := D;

  ReplaceChar := S;
end;

(**
 * Converts the given string to upper case.
 *)
function UpperStr(S: String): String;
var
  I: Integer;
begin
  for I := 1 to Length(S) do S[I] := UpCase(S[I]);
  UpperStr := S;
end;

(**
 * Converts the given string to lower case.
 *)
function LowerStr(S: String): String;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if (S[I] >= 'A') and (S[I] <= 'Z') then
      S[I] := Chr(Ord(S[I]) + 32);
  LowerStr := S;
end;

function IsAlpha(C: Char): Boolean;
begin
  if (C >= 'a') and (C <= 'z') then
    IsAlpha := True
  else if (C >= 'A') and (C <= 'Z') then
    IsAlpha := True
  else
    IsAlpha := False;
end;

(**
 * Converts the given integer to a string.
 *)
function IntToStr(I: Integer): String;
const
  N = 0;
var
  S: String;
begin
  Str(I, S);
  IntToStr := S;
end;

(**
 * Converts the given integer to a hex number of the given length.
 *)
function IntToHex(Value, Digits: Integer): String;
var
  S: String;
  D: Integer;
begin
  S := '';

  while (Value <> 0) or (Digits > 0) do
  begin
    D := Value and 15;
    if D < 10 then
      S := Chr(Ord('0') + D) + S
    else
      S := Chr(Ord('A') - 10 + D) + S;
    Value := Value shr 4;
    Digits := Digits - 1;
  end;

  IntToHex := S;
end;

(**
 * Pads the string with spaces at the end, so it has at least the given number
 * of characters.
 *)
function PadStr(S: String; N: Integer): String;
const
  Spaces = '                ';
begin
  if Length(S) >= Abs(N) then
    PadStr := S
  else
  begin
    while Length(S) < N do
      S := S + Spaces;
    PadStr := Copy(S, 1, N);
  end
end;

(**
 * Trims the given string by removing all characters <= ' ' from left and right
 * sides.
 *)
function TrimStr(S: String): String;
var
  I, J: Integer;
begin
  I := 1;
  while ((I <= Length(S)) and (S[I] <= ' ')) do
    I := I + 1;
  J := Length(S) + 1;
  while ((J > I) and (S[J-1] <= ' ')) do
    J := J - 1;
  TrimStr := Copy(S, I, J - I);
end;

(**
 * Checks if the given string starts with the given substring.
 *)
function StartsWith(Str, SubStr: String): Boolean;
begin
  if Length(Str) < Length(SubStr) then
  begin
    StartsWith := False;
    Exit;
  end;

  SetLength(Str, Length(SubStr));
  StartsWith := Str = SubStr;
end;

(**
 * Checks if the given string starts with the given substring.
 *)
function EndsWith(Str, SubStr: String): Boolean;
begin
  if Length(Str) < Length(SubStr) then
  begin
    EndsWith := False;
    Exit;
  end;

  EndsWith := Copy(Str, Length(Str) - Length(SubStr) + 1, 255) = SubStr;
end;

(**
 * Checks whether the given floating-point literal is one the Real type and
 * the run-time conversion (Val, Read) accept. The rules are those of CNVN
 * in math48, so that a literal and the same text passed to Val agree: the
 * exponent has to be in -38..37, there may be no more than 38 decimals, and
 * the value has to stay below 2^127 (about 1.7E+38). A value too small to
 * represent is not an error, it becomes zero.
 *
 * CNVN scales the digits by the power of ten with a single FPMUL, which
 * reports an overflow as soon as the two binary exponents add up to more
 * than 127, even where the normalized product would still fit. This is why
 * 15E37 is fine and 16E37 is not, in TP3 as well, and why the same test is
 * made here.
 *)
{$ifndef SYS_IR4}
function RealInRange(S: String): Boolean;
var
  Number, Mantissa: Extended;
  P, Dot, Exponent, Code, E1, E2: Integer;
begin
  P := Pos('E', UpperStr(S));
  if P = 0 then P := Length(S) + 1;

  Dot := Pos('.', S);
  if (Dot <> 0) and (P - Dot - 1 > 38) then Exit(False);

  Val(Copy(S, 1, P - 1), Number, Code);
  if (Code <> 0) or (Number >= 1.7014118346046923E38) then Exit(False);

  if P > Length(S) then Exit(True);

  if Length(S) - P > 4 then Exit(False);
  Val(Copy(S, P + 1, 255), Exponent, Code);
  if (Code <> 0) or (Exponent < -38) or (Exponent > 37) then Exit(False);

  if (Number = 0) or (Exponent <= 0) then Exit(True);

  FRExp(Number, Mantissa, E1);
  FRExp(IntPower(10.0, Exponent), Mantissa, E2);
  RealInRange := E1 + E2 <= 127;
end;
{$else}
function RealInRange(S: String): Boolean;
var
  Number: Real;
  Code: Integer;
begin
  Val(S, Number, Code);
  RealInRange := Code = 0;
end;
{$endif}

function NativeToPosix(Native: String): String;
begin
  {$ifdef windows}
  NativeToPosix := ReplaceChar(Native, '\', '/');
  {$else}
  NativeToPosix := Native;
  {$endif}
end;

function PosixToNative(Posix : string): string;
begin
  {$ifdef windows}
  PosixToNative := ReplaceChar(Posix, '/', '\');
  {$else}
  PosixToNative := Posix;
  {$endif}
end;

(**
 * Returns the parent directory of the given directory.
 *)
function ParentDir(DirName: String): String;
var
  I: Integer;
begin
  I := Length(DirName);
  while (I > 0) and (DirName[I] <> '/') do
    I := I - 1;

  ParentDir := Copy(DirName, 1, I - 1);
end;

(**
 * Returns the name part of a path only.
 *)
function NameOnly(Path: String): String;
var
  I: Integer;
begin
  I := Length(Path);
  while (I > 0) and (Path[I] <> '/') do
    I := I - 1;

  NameOnly := Copy(Path, I + 1, 255);
end;

(**
 * Changes the extension of the given filename to a new one (or appends it, if
 * there is no file extension at all. The new extension is supposed to start
 * with a dot.
 *)
function ChangeExt(FileName, NewExt: String): String;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '.') and (FileName[I] <> '/') do
    I := I - 1;

  if (I = 0) or (FileName[I] = '/') then
    ChangeExt := FileName + NewExt
  else
    ChangeExt := Copy(FileName, 1, I - 1) + NewExt;
end;

(**
 *
 *)
function FAbsolute(Name: String): String;
begin
  FAbsolute := NativeToPosix(FExpand(Name));
end;

(**
 * Returns a given file name as a relative file name based on the current
 * directory if that it possible (i.e. if is contained in that directory).
 * Otherwise it stays unchanged.
 *)
function FRelative(Name: String): String;
var
  Dir: String;
begin
  Dir := FAbsolute('.') + '/';
  if Copy(Name, 1, Length(Dir)) = Dir then
    FRelative := Copy(Name, Length(Dir) + 1, 255)
  else
    FRelative := Name;
end;

function IsRelative(Path: String): Boolean;
begin
  IsRelative := False;

  if Length(Path) >= 1 then
  begin
    if Path[1] = '/' then Exit;

    if Length(Path) >= 2 then
    begin
      if IsAlpha(Path[1]) and (Path[2] = ':') then
      begin
        if (Length(Path) >= 3) and (Path[3] = '/') then Exit;
        WriteLn('Warning: "', Path, '" can lead to trouble.');
      end;
    end;
  end;

  IsRelative := True;
end;

(**
 * Returns the size of the given file, or -1 if the file does not exist.
 *)
function FSize(Name: String): Integer;
var
  F: File;
  {$ifndef SYS_IR4}
  SaveMode: Integer;
  {$endif}
begin
  {$ifndef SYS_IR4}
  SaveMode := FileMode;
  FileMode := 0;
  {$endif}

  {$I-}
  Assign(F, PosixToNative(Name));
  Reset(F, 1);
  if IOResult = 0 then
  begin
    FSize := FileSize(F);
    Close(F);
  end
  else FSize := -1;
  {$I+}

  {$ifndef SYS_IR4}
  FileMode := SaveMode;
  {$endif}
end;

{$ifndef SYS_IR4}
{$ifdef darwin}
function ResolveLink(const APath: string): string;
var
  Buf: array[0..255] of char;
  Len: Integer;
begin
  Len := fpReadLink(PChar(APath), Buf, SizeOf(Buf));
  if Len = -1 then
    Result := APath
  else
    SetString(Result, Buf, Len);
end;
{$endif}
{$endif}

(**
 * Returns the compiler's home directory (where it is installed).
 *)
function GetHomeDir: String;
begin
  {$ifndef SYS_IR4}
  {$ifdef darwin}
  Result := ParentDir(ParamStr(0));
  if Result = '' then
  begin
    RunCommand('which', [ParamStr(0)], Result);
    Result := ParentDir(ResolveLink(TrimStr(Result)));
  end
  else Result := FAbsolute(Result);
  {$else}
  Result := ParentDir(FAbsolute(NativeToPosix(ParamStr(0))));
  if Result = '' then Result := FAbsolute('.');
  {$endif}
  {$else}
  GetHomeDir := ParentDir(FAbsolute(NativeToPosix(ParamStr(0))));
  if GetHomeDir = '' then GetHomeDir := FAbsolute('.');
  {$endif}
end;

(**
 * Returns the user's home directory (where we expect the config).
 *)
function GetUserDir: String;
begin
  {$ifdef windows}
  GetUserDir := NativeToPosix(GetEnv('USERPROFILE'));
  {$else}
  GetUserDir := NativeToPosix(GetEnv('HOME'));
  {$endif}
end;

(* -------------------------------------------------------------------------- *)
(* --- Config handling ------------------------------------------------------ *)
(* -------------------------------------------------------------------------- *)

type
  TIR4Tuple = record
    C, I, A, F: Integer;
  end;

  PIR4Chunk = ^TIR4Chunk;
  TIR4Chunk = record
    Text: String;
    Next: PIR4Chunk;
  end;

var
  Release: Boolean;
  IR4LineOpen: Boolean;
  IR4Buffering: Boolean;
  IR4Head: PIR4Chunk;
  IR4Tail: PIR4Chunk;
  IR4FnSig: String;
  IR4Frame: TIR4Tuple;
  IR4BaseFrame: TIR4Tuple;
  IR4MaxFrame: TIR4Tuple;
  SavedIR4Frames: array[0..7] of TIR4Tuple;
  IR4CaseTemp: String;

var
  HomeDir: String;
  SrcFile, AsmFile: String;

(**
 * Tries to setup the compiler's home directory and optional config overrides.
 *)
procedure LoadConfig;
var
  T: Text;
  UserDir, S, Key, Value: String;
  P: Integer;
begin
  HomeDir := GetHomeDir;
  UserDir := GetUserDir;

  {$I-}
  Assign(T, UserDir + '/.pasta80.cfg');
  Reset(T);
  if IOResult = 0 then
  begin
    while not Eof(T) do
    begin
      ReadLn(T, S);
      if not StartsWith(S, '#') and (Length(S) <> 0) then
      begin
        P := Pos('=', S);
        if P <> 0 then
        begin
          Key := LowerStr(TrimStr(Copy(S, 1, P - 1)));
          Value := NativeToPosix(TrimStr(Copy(S, P + 1, 255)));

          if StartsWith(Value, '~') then
            Value := UserDir + Copy(Value, 2, 255);

          if (Key = 'home') or (Key = 'pasta') then
            HomeDir := Value;
        end;
      end;
    end;
    Close(T);
  end;
  {$I+}
end;

procedure Emit(Tag, Instruction, Comment: String); forward;
procedure EmitI(S: String); forward;
procedure Error(Message: String); forward;
procedure SetLibrary(FileName: String); forward;

(* -------------------------------------------------------------------------- *)
(* --- Input ---------------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

type
  (**
   * Represents a source file being processed. We maintain a linked list of such
   * sources that we treat like a stack to deal with (potentially nested)
   * includes.
   *)
  PSource = ^TSource;
  TSource = record
    Name: String;
    Input:  Text;
    Buffer: String;
    Line:   Integer;
    Column: Integer;
    Next: PSource;
  end;

var
  (**
   * The pointer to the current source file.
   *)
  Source: PSource;

(**
 * Open the given input file. The same procedure is called for the initial
 * input file and for all nested includes.
 *)
procedure OpenInput(FileName: String);
var
  Tmp: PSource;
  Cand: String;
begin
  if (Source <> nil) and IsRelative(FileName) then
  begin
    Cand := ParentDir(FAbsolute(Source^.Name)) + '/' + FileName;
    if FSize(Cand) <> -1 then
      FileName := Cand
    else if FSize(HomeDir + '/rtl/' + FileName) <> -1 then
      FileName := FAbsolute(HomeDir + '/rtl/' + FileName)
    else if FSize(HomeDir + '/../pasta84/rtl/' + FileName) <> -1 then
      FileName := FAbsolute(HomeDir + '/../pasta84/rtl/' + FileName)
    else
      FileName := Cand;
  end;

  Tmp := Source;
  while Tmp <> nil do
  begin
    if Tmp^.Name = FileName then Error('Cyclic include');
    Tmp := Tmp^.Next;
  end;

  New(Tmp);

  with Tmp^ do
  begin
    Name := FileName;
    {$I-}
    Assign(Input, FileName);
    Reset(Input);
    if IOResult <> 0 then
    begin
      Dispose(Tmp);
      Error('File "' + PosixToNative(FileName) + '" not found');
    end;
    {$I+}
    Buffer := '';
    Line := 0;
    Column := 1;
    Next := Source;
  end;

  Source := Tmp;
end;

(**
 * Closes the current input file and resumes scanning/parsing of the enclosing
 * input file (if one exists).
 *)
procedure CloseInput;
var
  Tmp: PSource;
begin
  Tmp := Source;
  Source := Tmp^.Next;
  Close(Tmp^.Input);
  Dispose(Tmp);
end;

procedure EmitC(S: String); forward;

(**
 * Returns (and consumes) the next input character. This function is called
 * routinely by the scanner.
 *)
function GetChar: Char;
begin
  with Source^ do
  begin
    if Column > Length(Buffer) then
    begin
      if Eof(Input) then
      begin
        if Next <> nil then
        begin
          CloseInput;
          GetChar := ' ';
          Exit;
        end
        else Error('Unexpected end of source');
      end;

      ReadLn(Input, Buffer);
      EmitC('[' + IntToStr(Line) + '] ' + Buffer); // TODO Make this configurable?
      Buffer := Buffer + #13;
      Line := Line + 1;
      Column := 1;
    end;

    GetChar := Buffer[Column];
    Inc(Column);
  end;
end;

(**
 * Pushes back a single character. This - admittedly slightly ugly - procedure
 * is called by the scanner. It must not be called at the beginning of a line
 * or source code file, but this never happens.
 *)
procedure UngetChar;
begin
  Source^.Column := Source^.Column - 1;
end;

(* -------------------------------------------------------------------------- *)
(* --- String table --------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

function GetLabel(Prefix: String): String; forward;

type
  (**
   * A linked list of string constants used in the program. No duplicates. The
   * strings are written at the end of parsing each overlay and at the end of
   * the main program.
   *
   * TODO Make this a hash table in case we want to run on 8 bit.
   * TODO Add something similar for Real constants and maybe for set constants.
   *)
  PStringLiteral = ^TStringLiteral;
  TStringLiteral = record
    Tag: String;
    Value: String;
    Next: PStringLiteral;
  end;

var
  (**
   * The head of our list.
   *)
  Strings: PStringLiteral;

(**
 * Adds a string to the list and returns a label under which it is accessible
 * for assembly code. If the string is already part of the list the existing
 * label will be returned.
 *)
function AddString(S: String): String;
var
  Temp: PStringLiteral;
begin
  Temp := Strings;
  while Temp <> nil do
  begin
    if Temp^.Value = S then
    begin
      AddString := Temp^.Tag;
      Exit;
    end;
    Temp := Temp^.Next;
  end;

  New(Temp);
  Temp^.Tag := GetLabel('string');
  Temp^.Value := S;
  Temp^.Next := Strings;
  Strings := Temp;
  AddString := Strings^.Tag;
end;

procedure ClearStrings;
var
  Tmp: PStringLiteral;
begin
  while Strings <> nil do
  begin
    Tmp := Strings;
    Strings := Tmp^.Next;
    Dispose(Tmp);
  end;
end;

(* -------------------------------------------------------------------------- *)
(* --- Symbol table --------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

type
  TSymbolClass = (scConst, scType, scArrayType, scRecordType, scEnumType,
                  scStringType, scSetType, scSubrangeType, scPointerType,
                  scFileType, scAliasType, scVar, scLabel, scProc, scFunc,
                  scScope);

  // Flags: Forward, External, Register, Magic, Reference, Writable, Relative, Sizable, Addressable

  (**
   * Represents an entry in our symbol table. The symbol table is a linked list
   * that operates a bit like a stack: New identifiers are put at the front and
   * may shadow existing ones. Identifiers are removed in reverse order once
   * they fall out of scope. Not all fields are used by all kinds of symbols,
   * some have a different meaning depending on the symbol they are used for.
   * "Value", for instance, can be the integer value of a constant, but also the
   * size of a type. This, although working, is slightly ugly and maybe worth a
   * clean-up.
   *)
  PSymbol = ^TSymbol;
  TSymbol = record
    Name: String;                       // Name of the symbol
    Kind: TSymbolClass;                 // Kind of the symbol
    DataType: PSymbol;                  // Data type, array type or return type
    ArgTypes: array[0..15] of PSymbol;  // Procedure/function parameter types
    ArgIsRef: array[0..15] of Boolean;  // Procedure/function "var" parameters
    Level: Integer;                     // Level of procedure/function, 0=global
    Value, Value2: Integer;             // Value(s) or size(s) of symbol
    Tag: String;                        // External label or address of symbol
    IndexType: PSymbol;                 // Index type of arrays
    Low, High: Integer;                 // Values of a range or an array index
    Prev, Next: PSymbol;                // Previous and next in linked list
    IsMagic: Boolean;                   // Magics are built into the compiler
    IsRef: Boolean;                     // Symbol is a reference (var param)
    IsParam: Boolean;                   // Symbol is a procedure/function param
    IsForward: Boolean;                 // Forward-declared procedure/function
    IsExternal: Boolean;                // External, to be resolved later
    SavedParams: PSymbol;               // Original parameters, forward-case only
    IrC, IrI, IrA, IrF: Integer;
    WithC, WithI, WithA, WithF: Integer;
  end;

var
  (**
   * The head (aka newest entry) of our symbol table. Searches for an identifier
   * usually start from here.
   *)
  SymbolTable: PSymbol;

  (**
   * The most recent scope marker.
   *)
  CurrentScope: PSymbol;

  (**
   * The last built-in identifier.
   *)
  LastBuiltIn: PSymbol;

  (**
   * Nesting level. Maintained by compiler.
   *)
  Level: Integer;

  (**
   * Pointers to several important built-in base types.
   *)
  dtInteger, dtBoolean, dtChar, dtByte, dtString, dtReal, dtPointer, dtFile,
  dtText, dtUnknown: PSymbol;

  (**
   * Pointer to the built-in Mem[] pseudo-array.
   *)
  MemArray: PSymbol;

  (**
   * Pointers to a whole lot of built-in procedures and functions that are
   * considered "magic" and cannot be defined in Pascal. This is mostly because
   * their number or type of parameters is not fixed.
   *)
  AssertProc, BreakProc, ContProc, ExitProc, HaltProc, StrProc, ReadProc,
  ReadLnProc, WriteProc, WriteLnProc, EraseProc, RenameProc, AssignProc,
  ResetProc, RewriteProc, AppendProc, FlushProc, CloseProc, SeekProc,
  SeekEofFunc, SeekEolnFunc, BlockReadProc, BlockWriteProc, FilePosFunc,
  FileSizeFunc, EolFunc, EofFunc, AbsFunc, AddrFunc, DisposeProc, EvenFunc,
  HighFunc, LowFunc, NewProc, OddFunc, OrdFunc, PredFunc, FillProc, IncProc,
  DecProc, ConcatFunc, ValProc, IncludeProc, ExcludeProc, PtrFunc, SizeFunc,
  SuccFunc, DebugProc, RandomFunc,
  InsertProc, DeleteProc: PSymbol;

(**
 * Disposes a single symbol table entry and rewires Sym to its predecessor
 * (Sym^.Prev), so it can be used to walk and free a whole chain in a loop.
 * Also frees any side chain the symbol exclusively owns but that is not
 * reachable through the main symbol table list (record field lists, saved
 * forward-declaration parameters), recursively applying the same logic.
 *)
procedure FreeAndNilSymbol(var Sym: PSymbol);
var
  Tmp: PSymbol;
begin
  Tmp := Sym^.Prev;

  if Sym^.Kind = scRecordType then
    while Sym^.DataType <> nil do
      FreeAndNilSymbol(Sym^.DataType);

  if (Sym^.Kind in [scProc, scFunc]) and (Sym^.SavedParams <> nil) then
    while Sym^.SavedParams <> nil do
      FreeAndNilSymbol(Sym^.SavedParams);

  Dispose(Sym);

  Sym := Tmp;
end;

(**
 * Opens a scope, which mainly adds a new scope marker at the front of the
 * symbol table. If AdjustLevel is true (which is the case for procedures and
 * functions, especially nested ones) level and variable offset are affected,
 * too.
 *)
procedure OpenScope(AdjustLevel: Boolean);
var
  Sym: PSymbol;
begin
  New(Sym);
  FillChar(Sym^, SizeOf(TSymbol), 0);

  Sym^.Kind := scScope;
  Sym^.Prev := SymbolTable;
  Sym^.DataType := CurrentScope;
  if SymbolTable <> nil then SymbolTable^.Next := Sym;
  SymbolTable := Sym;
  CurrentScope := Sym;

  if AdjustLevel then
  begin
    if Level = 7 then Error('Nesting too deep.');

    SavedIR4Frames[Level] := IR4Frame;
    Level := Level + 1;
    IR4Frame.C := 0;
    IR4Frame.I := 0;
    IR4Frame.A := 1; { Slot 0 reserved for saved __display[Level] }
    IR4Frame.F := 0;
  end;
end;

(**
 * Closes a scope, removing all symbols up to and including the most recent
 * scope marker. Adjusts level, if requested. Will also detect unimplemented
 * forward procedures/functions in that scope and raise errors if any are
 * found.
 *)
procedure CloseScope(AdjustLevel: Boolean);
var
  Kind: TSymbolClass;
begin
  while SymbolTable <> CurrentScope do
  begin
    Kind := SymbolTable^.Kind;

    if ((Kind = scProc) or (Kind = scFunc)) and SymbolTable^.IsForward then
      Error('Unresolved forward declaration "' + SymbolTable^.Name + '"');

    FreeAndNilSymbol(SymbolTable);
  end;

  CurrentScope := SymbolTable^.DataType;

  if AdjustLevel then
  begin
    Level := Level - 1;
    IR4Frame := SavedIR4Frames[Level];
  end;

  FreeAndNilSymbol(SymbolTable);
end;
(**
 * Searches the symbol table for the given identifier. Returns the symbol or
 * nil if it does not exist. The search starts and stops at the given symbols,
 * so passing the current scope as the second symbol would perform a local
 * search, while passing nil would perform a global one. Runtime is O(n) due
 * to the fact that we use a linked list for the symbol table (but modern
 * machines are so fast we don't notice).
 *)
function Lookup(Name: string; Start, Stop: PSymbol): PSymbol;
var
  Sym: PSymbol;
begin
  Name := UpperStr(Name);
  Sym := Start;
  while Sym <> Stop do
  begin
    if UpperStr(Sym^.Name) = Name then
    begin
      Lookup := Sym;
      Exit;
    end;
    Sym := Sym^.Prev;
  end;

  Lookup := nil;
end;

(**
 * Searches the local scope for the given identifier and returns the
 * corresponding symbol. Throws an error if the symbol cannot be found.
 *)
function LookupLocalOrFail(Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := Lookup(Name, SymbolTable, CurrentScope);
  if Sym = nil then Error('Unknown identifier "' + Name + '"');
  LookupLocalOrFail := Sym;
end;

(**
 * Searches the global scope for the given identifier and returns the
 * corresponding symbol. Throws an error if the symbol cannot be found.
 *)
function LookupGlobalOrFail(Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := Lookup(Name, SymbolTable, nil);
  if Sym = nil then Error('Unknown identifier "' + Name + '"');
  LookupGlobalOrFail := Sym;
end;

(**
 * Searches the built-ins for the given identifier and returns the
 * corresponding symbol. Throws an error if the symbol cannot be found.
 *)
function LookupBuiltInOrFail(Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := Lookup(Name, LastBuiltIn, nil);
  if Sym = nil then Error('Not supported.');
  LookupBuiltInOrFail := Sym;
end;

(**
 * This procedure is called when a procedure or function header is fully
 * parsed. It records the parameter count and parameter metadata on the
 * procedure/function symbol.
 *)
procedure AdjustOffsets;
var
  Sym, Sym2: PSymbol;
  I: Integer;
begin
  Sym := SymbolTable;
  I := 0;
  while (Sym^.Kind<>scProc) and (Sym^.Kind<>scFunc) do
  begin
    if Sym^.Kind = scVar then
      I := I + 1;
    Sym := Sym^.Prev;
  end;
  if Sym^.Kind = scFunc then
    I := I - 1;
  Sym^.Value := I;

  Sym2 := SymbolTable;
  while I > 0 do
  begin
    if Sym2^.Kind = scVar then
    begin
      Sym^.ArgTypes[I-1] := Sym2^.DataType;
      Sym^.ArgIsRef[I-1] := Sym2^.IsRef;
      I := I - 1;
    end;
    Sym2 := Sym2^.Prev;
  end;
end;

(**
 * Creates a new symbol of the given kind. Makes sure the given name (if any)
 * is unique within the local scope.
 *)
function CreateSymbol(Kind: TSymbolClass; Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  if (Length(Name) <> 0) and (Lookup(Name, SymbolTable, CurrentScope) <> nil) then
    Error('Duplicate symbol "' + Name + '"');

  New(Sym);
  FillChar(Sym^, SizeOf(TSymbol), 0);
  Sym^.Kind := Kind;
  Sym^.Name := Name;
  Sym^.Level := Level;
  Sym^.Prev := SymbolTable;
  Sym^.Tag := '';

  SymbolTable^.Next := Sym;
  SymbolTable := Sym;

  CreateSymbol := Sym;
end;

(**
 * Sets the data type of a variable or parameter. This is also the moment when
 * the offset of the symbol on the stack will be assigned (although, for
 * parameters, it will be adjusted later once all parameters are known).
 *)
procedure SetDataType(Sym: PSymbol; DataType: PSymbol; IsParam: Boolean);
begin
  Sym^.DataType := DataType;
  Sym^.IsParam := IsParam;

  if not ((Level = 0) and (Sym^.Tag = '')) then
  begin
    Sym^.IrC := IR4Frame.C;
    Sym^.IrI := IR4Frame.I;
    Sym^.IrA := IR4Frame.A;
    Sym^.IrF := IR4Frame.F;
    if Sym^.IsRef then
      Inc(IR4Frame.A)
    else
    begin
      Inc(IR4Frame.C, DataType^.IrC);
      Inc(IR4Frame.I, DataType^.IrI);
      Inc(IR4Frame.A, DataType^.IrA);
      Inc(IR4Frame.F, DataType^.IrF);
    end;
  end;
end;

// TODO Do we really need this?
function RegisterType(Name: String; Size: Integer): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := CreateSymbol(scType, Name);
  Sym^.Value := Size;

  RegisterType := Sym;
end;

// TODO Do we really need this?
function NewEnumType(Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := CreateSymbol(scEnumType, Name);
  Sym^.Value := 1;
  NewEnumType := Sym;
end;

// TODO Do we really need this?
function NewConst(Name: String; DataType: PSymbol; Value: Integer): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := CreateSymbol(scConst, Name);
  Sym^.DataType := DataType;
  Sym^.Value := Value;
  NewConst := Sym;
end;

(**
 * Registers a new magic symbol of the given type and with the given name.
 * Magic symbols are those that get their own parsing, usually because
 * they have a variable parameter list.
 *)
function RegisterMagic(Kind: TSymbolClass; Name: String): PSymbol;
var
  Sym: PSymbol;
begin
  Sym := CreateSymbol(Kind, Name);
  Sym^.IsMagic := True;
  RegisterMagic := Sym;
end;

function TypeName(Symbol: PSymbol): String;
var
  S: String;
begin
  S := Symbol^.Name;

  if S = '' then
  begin
    case Symbol^.Kind of
      scAliasType:    S := ' alias';
      scArrayType:    S := ' array';
      scEnumType:     S := ' enum';
      scFileType:     S := ' file';
      scPointerType:  S := ' pointer';
      scRecordType:   S := ' record';
      scSetType:      S := ' set';
      scStringType:   S := ' string';
      scSubrangeType: S := ' subrange';
    end;

    S := 'anonymous' + S + ' type';
  end;

  TypeName := S;
end;

(**
 * Tells whether the given type is an ordinal one, that is, whether its values
 * can be counted and thus incremented or decremented. Note that callers
 * interested in how wide such a value is must look at its Value (size), not at
 * the type itself: a subrange carries dtInteger as its base type but may well
 * occupy a single byte.
 *)
function IsOrdinal(DataType: PSymbol): Boolean;
begin
  IsOrdinal := (DataType = dtInteger) or (DataType = dtByte) or (DataType = dtChar)
            or (DataType^.Kind = scEnumType) or (DataType^.Kind = scSubrangeType);
end;

(**
 * Registers all symbols that must be baked into the compiler and cannot be
 * defined by means of Pascal source code.
 *)
procedure RegisterAllBuiltIns;
begin
  dtInteger := RegisterType('Integer', 2);
  dtInteger^.Low := -32768;
  dtInteger^.High := 32767;
  dtInteger^.IrI := 1;

  dtBoolean := NewEnumType('Boolean');
  dtBoolean^.Low := 0;
  dtBoolean^.High := 1;
  dtBoolean^.Tag := '__boolean_enum';
  dtBoolean^.IrC := 1;
  NewConst('False', dtBoolean, 0);
  NewConst('True', dtBoolean, 1);

  dtChar := RegisterType('Char', 1);
  dtChar^.Low := 0;
  dtChar^.High := 255;
  dtChar^.Value := 1;
  dtChar^.IrC := 1;
  dtByte := RegisterType('Byte', 1);
  dtByte^.Low := 0;
  dtByte^.High := 255;
  dtByte^.Value := 1;
  dtByte^.IrC := 1;

  dtString := CreateSymbol(scStringType, 'String');
  dtString^.Value := 256;
  dtString^.IrC := 256;

  (* Placeholder sizes. The real ones depend on the platform's
     FileControlBlock and are only known once the RTL has been parsed;
     ParseProgram patches these from FileRec/TextRec at that point. *)
  dtFile := CreateSymbol(scFileType, 'File');
  dtFile^.Value := 256;
  dtFile^.IrC := 256;

  dtText := CreateSymbol(scFileType, 'Text');
  dtText^.Value := 256;
  dtText^.IrC := 256;

  dtReal := CreateSymbol(scType, 'Real');
  dtReal^.Value := 6;
  dtReal^.IrF := 1;

  dtPointer := CreateSymbol(scPointerType, 'Pointer');
  dtPointer^.Value := 2;
  dtPointer^.IrA := 1;

  dtUnknown := CreateSymbol(scType, '<unknown>');
  dtUnknown^.Value := 0;

  MemArray := CreateSymbol(scVar, 'Mem');
  MemArray^.DataType := dtByte;
  MemArray^.IsMagic := True;

  AssertProc := RegisterMagic(scProc, 'Assert');
  DebugProc := RegisterMagic(scProc, 'Debug');
  BreakProc := RegisterMagic(scProc, 'Break');
  ContProc := RegisterMagic(scProc, 'Continue');
  DisposeProc := RegisterMagic(scProc, 'Dispose');
  ExitProc := RegisterMagic(scProc, 'Exit');
  HaltProc := RegisterMagic(scProc, 'Halt');
  NewProc := RegisterMagic(scProc, 'New');
  StrProc := RegisterMagic(scProc, 'Str');
  ReadProc := RegisterMagic(scProc, 'Read');
  ReadLnProc := RegisterMagic(scProc, 'ReadLn');
  WriteProc := RegisterMagic(scProc, 'Write');
  WriteLnProc := RegisterMagic(scProc, 'WriteLn');

  EraseProc := RegisterMagic(scProc, 'Erase');
  RenameProc := RegisterMagic(scProc, 'Rename');

  AssignProc := RegisterMagic(scProc, 'Assign');
  ResetProc := RegisterMagic(scProc, 'Reset');
  RewriteProc := RegisterMagic(scProc, 'Rewrite');
  AppendProc := RegisterMagic(scProc, 'Append');
  CloseProc := RegisterMagic(scProc, 'Close');
  FlushProc := RegisterMagic(scProc, 'Flush');
  SeekProc := RegisterMagic(scProc, 'Seek');
  SeekEofFunc := RegisterMagic(scFunc, 'SeekEof');
  SeekEolnFunc := RegisterMagic(scFunc, 'SeekEoln');

  BlockReadProc := RegisterMagic(scProc, 'BlockRead');
  BlockWriteProc := RegisterMagic(scProc, 'BlockWrite');

  FilePosFunc := RegisterMagic(scFunc, 'FilePos');
  FileSizeFunc := RegisterMagic(scFunc, 'FileSize');
  EolFunc := RegisterMagic(scFunc, 'Eoln');
  EofFunc := RegisterMagic(scFunc, 'Eof');

  IncProc := RegisterMagic(scProc, 'Inc');
  DecProc := RegisterMagic(scProc, 'Dec');

  ConcatFunc := RegisterMagic(scFunc, 'Concat');
  ValProc := RegisterMagic(scProc, 'Val');

  IncludeProc := RegisterMagic(scProc, 'Include');
  ExcludeProc := RegisterMagic(scProc, 'Exclude');

  InsertProc := RegisterMagic(scProc, 'Insert');
  DeleteProc := RegisterMagic(scProc, 'Delete');

  FillProc := RegisterMagic(scProc, 'FillChar');

  AbsFunc := RegisterMagic(scFunc, 'Abs');
  AddrFunc := RegisterMagic(scFunc, 'Addr');
  EvenFunc := RegisterMagic(scFunc, 'Even');
  HighFunc := RegisterMagic(scFunc, 'High');
  LowFunc := RegisterMagic(scFunc, 'Low');
  OddFunc := RegisterMagic(scFunc, 'Odd');
  OrdFunc := RegisterMagic(scFunc, 'Ord');
  PredFunc := RegisterMagic(scFunc, 'Pred');
  PtrFunc := RegisterMagic(scFunc, 'Ptr');
  SizeFunc := RegisterMagic(scFunc, 'SizeOf');
  SuccFunc := RegisterMagic(scFunc, 'Succ');
  RandomFunc := RegisterMagic(scFunc, 'Random');
end;

(* --------------------------------------------------------------------- *)
(* --- Preprocessor ---------------------------------------------------- *)
(* --------------------------------------------------------------------- *)

type
  (**
   * A conditional definition (i.e. a symbol handled by $IFDEF etc.). We
   * don't ever delete those that get undefined, but rather change their
   * value to False.
   *)
  PDefine = ^TDefine;
  TDefine = record
    Key: String;
    Value: Boolean;
    Next: PDefine;
  end;

var
  Defines: PDefine;                     // The head of the definition list
  IfDefStack: array[0..15] of Boolean;  // The stack for nested $IFDEFs
  IfDefLevel: Integer;                  // Index in that stack
  ScannerMuted: Boolean;                // Whether the scanner is muted

  IOMode: Boolean;                      // Controls IO checking

(**
 * Clears all defines. Needed for multiple compiler runs in IDE.
 *)
procedure ClearDefines;
var
  P: PDefine;
begin
  while Defines <> nil do
  begin
    P := Defines^.Next;
    Dispose(Defines);
    Defines := P;
  end;
end;

(**
 * Searches for a conditional definition. Returns either the pointer, if
 * found, or nil otherwise.
 *)
function FindDefine(S: String): PDefine;
var
  P: PDefine;
begin
  P := Defines;
  while P <> nil do
  begin
    if P^.Key = S then Exit(P);
    P := P^.Next;
  end;

  Exit(nil);
end;

(**
 * Returns the value of a conditional definition, or False if that
 * definition does not exist.
 *)
function GetDefine(S: String): Boolean;
var
  P: PDefine;
begin
  P := FindDefine(UpperStr(S));
  if P = nil then
    Exit(False)
  else
    Exit(P^.Value);
end;

(**
 * Sets the value of the given conditional definition.
 *)
procedure SetDefine(S: String; B: Boolean);
var
  P: PDefine;
begin
  S := UpperStr(S);

  P := FindDefine(S);
  if P = nil then
  begin
    New(P);
    P^.Key := S;
    P^.Value := B;
    P^.Next := Defines;
    Defines := P;
  end
  else P^.Value := B;
end;

(**
 * Pushes the current state of the preprocessor to the stack. This happens
 * whenever we encounter an $IFDEF or $IFNDEF.
 *)
procedure PushIfDefState;
begin
  if IfDefLevel = High(IfDefStack) then Error('Too many $ifdefs');
  Inc(IfDefLevel);
  IfDefStack[IfDefLevel] := ScannerMuted;
end;

(**
 * Pops the previous state of the preprocessor off the stack. This happens
 * whenever we encounter an $ENDIF.
 *)
procedure PopIfDefState;
begin
  if IfDefLevel = -1 then Error('Missing $ifdef');
  ScannerMuted := IfDefStack[IfDefLevel];
  Dec(IfDefLevel);
end;

(**
 * Queries the previous state of the preprocessor without actually popping
 * if off the stack. This is used for handling $ELSE.
 *)
function TopIfDefState: Boolean;
begin
  if IfDefLevel = -1 then Error('Missing $ifdef');
  TopIfDefState := IfDefStack[IfDefLevel];
end;

(**
 * Handles the given directive. Directives are Pascal's way of dealing with
 * conditional compilation, compiler switches, and things like includes.
 * New directives should be added here.
 *)
procedure HandleDirective(C: String);
var
  S, T: String;
  P: Integer;

  (**
   * Throws an error.
   *)
  procedure Invalid;
  begin
    Error('Invalid directive: ' + S);
  end;

  (**
   * Handles one or more switches. Multiple switches must be separated by commas
   * and not repeat the initial dollar sign.
   *)
  procedure Switches;
  var
    I: Byte;
    C: Char;
    B: Boolean;
  begin
    I := 1;
    repeat
      if I + 2 > Length(S) then
        Invalid;

      C := S[I + 1];

      case S[I + 2] of
        '+': B := True;
        '-': B := False;
      else
        Invalid;
      end;

      case C of
        'a', 'k', 'u': ;
        'i': IOMode := B;
      else
        Invalid;
      end;

      Inc(I, 3);
      if (I <= Length(S)) and (S[I] <> ',') then
        Invalid;
    until I > Length(S);
  end;

begin
  P := Pos(' ', C);
  if P = 0 then
  begin
    S := LowerStr(C);
    T := '';
  end
  else
  begin
    S := LowerStr(TrimStr(Copy(C, 1, P - 1)));
    T := TrimStr(Copy(C, P + 1, 255));
  end;

  if S = '$ifdef' then
  begin
    PushIfDefState;
    ScannerMuted := ScannerMuted or not GetDefine(T);
  end
  else if S = '$ifndef' then
  begin
    PushIfDefState;
    ScannerMuted := ScannerMuted or GetDefine(T);
  end
  else if S = '$else' then
  begin
    if not TopIfDefState then ScannerMuted := not ScannerMuted;
  end
  else if S = '$endif' then
    PopIfDefState
  else if not ScannerMuted then
  begin
    if S = '$define' then
      SetDefine(T, True)
    else if S = '$undef' then
      SetDefine(T, False)
    else if S = '$error' then
      Error(T)
    else if S = '$i' then
      OpenInput(NativeToPosix(T))
    else if S = '$l' then
      SetLibrary(NativeToPosix(T))
    else if S = '$m' then
      begin end
    else
      Switches;
  end;
end;

(* --------------------------------------------------------------------- *)
(* --- Scanner --------------------------------------------------------- *)
(* --------------------------------------------------------------------- *)

type
  (**
   * An enumeration type containing all possible tokens. The order is
   * significant and must not be changed without changing the TokenStr array
   * accordingly. Also all tokens representing keywords are in one large,
   * alphabetically sorted block.
   *)
  TToken = (toNone, toComment,
            toIdent, toNumber, toString, toFloat, toAdd, toSub, toMul, toDiv,
            toEq, toNeq, toLt, toLeq, toGt, toGeq, toLParen, toRParen, toLBrack, toRBrack,
            toBecomes, toComma, toColon, toSemicolon, toPeriod, toCaret, toRange,
            toAbsolute, toAnd, toArray, toBegin, toCase, toConst, toDivKw, toDo, toDownto, toElse, toEnd,
            toExternal, toFile, toFor, toForward, toFunction, toGoto, toIf, toIn, toInline, toLabel, toMod,
            toNil, toNot, toOf, toOr, toOverlay, toPacked, toProcedure, toProgram, toRecord, toRepeat, toSet,
            toShl, toShr, toStringKw, toThen, toTo, toType, toUntil, toVar, toWhile, toWith, toXor,
            toEof);

  (**
   * Describes the state of our scanner, basically the last generated token.
   * TODO Eliminate this type. We only ever need a single one.
   *)
  TScanner = record
    Token:    TToken;
    StrValue: String;
    NumValue: Integer;
  end;

const
  (**
   * An array containing textual representations of all possible tokens. The
   * order is significant and must not be changed without changing the TToken
   * type accordingly. Also all tokens representing keywords are in one large,
   * alphabetically sorted block.
   *)
  TokenStr: array[TToken] of String =
           ('<nul>', '{...}',
            'Identifier', 'Number', 'String', 'Real', '+', '-', '*', '/',
            '=', '#', '<', '<=', '>', '>=', '(', ')', '[', ']',
            ':=', ',', ':', ';', '.', '^', '..',
            'absolute', 'and', 'array', 'begin', 'case', 'const', 'div', 'do', 'downto', 'else', 'end',
            'external', 'file', 'for', 'forward', 'function', 'goto', 'if', 'in', 'inline', 'label', 'mod',
            'nil', 'not', 'of', 'or', 'overlay', 'packed', 'procedure', 'program', 'record', 'repeat', 'set',
            'shl', 'shr', 'string', 'then', 'to', 'type', 'until', 'var', 'while', 'with', 'xor',
            '<eof>');

  (**
   * Indices of the first and last keywords. Required for keyword detection.
   *)
  FirstKeyword = toAbsolute;
  LastKeyword = toXor;

var
  (**
   * The state of our scanner. Basically the lookahead token, i.e. the next
   * token to process.
   *)
  Scanner: TScanner;

  (**
   * The line and column of the current token.
   *)
  TokenLine, TokenColumn: Integer;

(**
 * Returns True if the given character is a valid Pascal identifier head.
 *)
function IsIdentHead(C: Char): Boolean;
begin
  IsIdentHead := (C >= 'A') and (C <= 'Z') or (C >= 'a') and (C <= 'z') or (C = '_');
end;

(**
 * Returns True if the given character is a valid Pascal identifier tail.
 *)
function IsIdentTail(C: Char): Boolean;
begin
  IsIdentTail := IsIdentHead(C) or (C >= '0') and (C <= '9');
end;

(**
 * Returns True if the given character is a decimal digit.
 *)
function IsDecDigit(C: Char): Boolean;
begin
  IsDecDigit := (C >= '0') and (C <= '9');
end;

(**
 * Returns True if the given character is a valid hexadecimal digit.
 *)
function IsHexDigit(C: Char): Boolean;
begin
  IsHexDigit := IsDecDigit(C) or (C >= 'A') and (C <= 'F') or (C >= 'a') and (C <= 'f');
end;

(**
 * Returns True if the given character is a valid binary digit.
 *)
function IsBinDigit(C: Char): Boolean;
begin
  IsBinDigit := (C = '0') or (C = '1');
end;

(**
 * Looks up a keyword and returns its token. Returns toIdent if the string is
 * an ordinary identifier.
 *
 * TODO Make this a binary search or use hashing.
 *)
function LookupKeyword(Ident: String): TToken;
var
  T: TToken;
begin
  Ident := LowerStr(Ident);

  for T := FirstKeyword to LastKeyword do
    if TokenStr[T] = Ident then
    begin
      LookupKeyword := T;
      Exit;
    end;

  LookupKeyword := toIdent;
end;

var
  (**
   * The lookahead character, i.e. the next character to process.
   *)
  C: Char;

(**
 * Scans the input and generates the next token. A bit lengthy, but it does the
 * job.
 *
 * TODO Pull a couple of longer blocks into their own procedures.
 *)
procedure NextToken;

  function DecDigit(C: Char): Integer;
  begin
    if C in ['0'..'9'] then
      DecDigit := Ord(C) - Ord('0')
    else
      Error('Decimal digit expected.');
  end;

  function HexDigit(C: Char): Integer;
  begin
    case C of
      '0'..'9': HexDigit := Ord(C) - Ord('0');
      'A'..'F': HexDigit := Ord(C) - Ord('A') + 10;
      'a'..'f': HexDigit := Ord(C) - Ord('a') + 10;
    else
      Error('Hexadecimal digit expected');
    end;
  end;

var
  I: Integer;
begin
  repeat
    repeat
      // Ignore whitespace
      while (C <= ' ') do
      begin
        C := GetChar;
      end;

      with Scanner do
      begin
        // Start a new token
        Token := toNone;
        StrValue := '';
        NumValue := 0;
        TokenLine := Source^.Line;
        TokenColumn := Source^.Column - 1;

        if IsIdentHead(C) then
        begin
          // Identifier
          StrValue := C;
          C := GetChar;
          while IsIdentTail(C) do
          begin
            StrValue := StrValue + C;
            C := GetChar;
          end;
          Token := LookupKeyword(StrValue);
        end
        else if IsDecDigit(C) then
        begin
          // Let's start with an integer number
          Token := toNumber;
          repeat
            StrValue := StrValue + C;
            NumValue := 10 * NumValue + DecDigit(C);
            C := GetChar;
          until not IsDecDigit(C);

          // Might turn out to be floating point
          if C = '.' then
          begin
            C := GetChar;
            if C = '.' then
            begin
              UngetChar;
              Break;
            end;

            Token := toFloat;
            StrValue := StrValue + '.';

            while IsDecDigit(C) do
            begin
              StrValue := StrValue + C;
              C := GetChar;
            end;
          end;

          // And even have an exponential part
          if (C = 'E') or (C = 'e') then
          begin
            Token := toFloat;

            StrValue := StrValue + C;
            C := GetChar;

            if (C = '+') or (C = '-') then
            begin
              StrValue := StrValue + C;
              C := GetChar;
            end;

            repeat
              StrValue := StrValue + C;
              DecDigit(C);
              C := GetChar;
            until not IsDecDigit(C);
          end;

          if (Token = toFloat) and not ScannerMuted and not RealInRange(StrValue) then
            Error('Real constant out of range');
        end
        else if C = '$' then
        begin
          // Hex numbers are numbers, too.
          Token := toNumber;
          StrValue := '$';
          C := GetChar;

          repeat
            StrValue := StrValue + C;
            NumValue := (NumValue shl 4) + HexDigit(C);
            C := GetChar;
          until not IsHexDigit(C);
        end
        else if C = '%' then
        begin
          // Binary numbers are numbers, too.
          Token := toNumber;
          StrValue := '%';
          C := GetChar;

          if not IsBinDigit(C) then Error('Binary digit expected');

          repeat
            StrValue := StrValue + C;
            NumValue := (NumValue shl 1);
            if C = '1' then NumValue := NumValue + 1;
            C := GetChar;
          until not IsBinDigit(C);
        end
        else if (C = '''') or (C = '#') then
        begin
          // Strings come in various forms
          Token := toString;

          repeat
            if C = '''' then
            begin
              // Standard string delimited by apostrophes
              C := GetChar;
              while True do
              begin
                while (C <> '''') and (C <> #26) do
                begin
                  StrValue := StrValue + C;
                  C := GetChar;
                end;

                if C = #26 then Error('Unterminated String') else C := GetChar; (* ??? *)

                if C = '''' then
                begin
                  StrValue := StrValue + '''';
                  C := GetChar;
                end
                else Break;
              end;
            end
            else
            begin
              // Hash sign followed by an ASCII code (decimal or hex)
              C := GetChar;
              I := 0;
              if C = '$' then
              begin
                C := GetChar;
                repeat
                  I := (I shl 4) + HexDigit(C);
                  C := GetChar;
                until not IsHexDigit(C);
              end
              else
              begin
                repeat
                  I := I * 10 + DecDigit(C);
                  C := GetChar;
                until not IsDecDigit(C);
              end;
              StrValue := StrValue + Char(I);
            end;
          until (C <> '''') and (C <> '#');
        end
        else if C = '{' then
        begin
          // Standard Pascal comments
          StrValue := '{';
          repeat
            C := GetChar;
            StrValue := StrValue + C;
          until C = '}';

          // Handle directives before reading the next character, so that an
          // include is already open when we do (the character must come from
          // the included file, not from the rest of the current line).
          StrValue := Copy(StrValue, 2, Length(StrValue) - 2);
          Token := toComment;
          if (StrValue <> '') and (StrValue[1] = '$') then
            HandleDirective(StrValue);

          C := GetChar;
        end
        else
        begin
          // Various Single-character tokens
          case C of
            '+': Token := toAdd;
            '-': Token := toSub;
            '*': Token := toMul;
            '/': Token := toDiv;
            '=': Token := toEq;
            '<': Token := toLt;
            '>': Token := toGt;
            '(': Token := toLParen;
            ')': Token := toRParen;
            '[': Token := toLBrack;
            ']': Token := toRBrack;
            ':': Token := toColon;
            ',': Token := toComma;
            ';': Token := toSemicolon;
            '.': Token := toPeriod;
            '^': Token := toCaret;
            else Error('Invalid character "' + C + '"');
          end;

          C := GetChar;

          // These might turn out to be multi-character tokens
          case Token of
            toDiv:
              if C = '/' then               // C-style one-line comment
              begin
                Source^.Column := Length(Source^.Buffer) + 1;
                C := GetChar;
                Token := toComment;
              end;
            toLt:
              if C = '>' then               // Not equal
              begin
                Token := toNeq;
                C := GetChar;
              end
              else if C = '=' then          // Less than or equal
              begin
                Token := toLeq;
                C := GetChar;
              end;

            toGt:
              if C = '=' then               // Greater than or equal
              begin
                Token := toGeq;
                C := GetChar;
              end;

            toLParen:
              if C = '.' then               // Alternative notation for [
              begin
                Token := toLBrack;
                C := GetChar;
              end
              else if C = '*' then          // Alternative notation for comments
              begin
                C := GetChar;
                StrValue := '(*' + C;
                repeat
                  while C <> '*' do
                  begin
                    C := GetChar;
                    StrValue := StrValue + C;
                  end;
                  C := GetChar;
                  StrValue := StrValue + C;
                until C = ')';

                // See above: Directives first, then the next character.
                StrValue := Copy(StrValue, 3, Length(StrValue) - 4);
                Token := toComment;
                if (StrValue <> '') and (StrValue[1] = '$') then
                  HandleDirective(StrValue);

                C := GetChar;
              end;

            toColon:
              if C = '=' then               // Assignment operator
              begin
                Token := toBecomes;
                C := GetChar;
              end;

            toPeriod:
              if C = ')' then               // Alternative notation for ]
              begin
                Token := toRBrack;
                C := GetChar;
              end
              else if C = '.' then          // Double dot for ranges
              begin
                Token := toRange;
                C := GetChar;
              end;
          end;
        end;
      end;
    until Scanner.Token <> toComment;
  until not ScannerMuted;
end;

(**
 * Returns a control character. Called if the previous character was a '^'.
 *)
function GetCtrlChar: Integer;
begin
  if not (C in [' '..'~']) then
    Error('Invalid control character ^' + C);
  GetCtrlChar := Ord(UpCase(C)) xor $40;
  C := GetChar;
end;

(**
 * Parses one or more adjacent string and control-character fragments (e.g.
 * 'AB'^C'DE') into a single compile-time string. Assumes the caller has
 * already established that a string value is expected here, i.e. that
 * neither a pointer type nor a dereference can be meant by '^' at this
 * point.
 *)
function ParseStringLiteral: String;
var
  S: String;
begin
  S := '';
  while Scanner.Token in [toString, toCaret] do
  begin
    if Scanner.Token = toString then
    begin
      S := S + Scanner.StrValue;
      NextToken;
    end
    else
    begin
      S := S + Chr(GetCtrlChar);
      NextToken;
    end;
  end;
  ParseStringLiteral := S;
end;

(**
 * Throws an error if the current (lookahead) token type is not the expected
 * one.
 *)
procedure Expect(Token: TToken);
begin
  if Scanner.Token <> Token then
    Error('Expected "' + TokenStr[Token] + '", but got "' + TokenStr[Scanner.Token] + '"');
end;

(* -------------------------------------------------------------------------- *)
(* --- Error handling ------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

{$ifndef SYS_IR4}
type
  (**
   * Raised by Error to unwind the parser back to the point where parsing was
   * started, running normal Pascal stack unwinding (and hence finalization
   * of local managed-type variables, mainly AnsiStrings in our case) along the
   * way. We don't want to refine this any further (including error info, for
   * instance) because ultimately we will not be using it as it is not a Turbo
   * Pascal 3-5 feature. It's just a replacement for SetJmp/LongJmp, which,
   * unfortunately, leak memory.
   *)
  ECompileError = class(TObject)
  end;

var
  (**
   * Whether a try/except block is currently in place to catch ECompileError,
   * i.e. whether Error should raise it or just halt directly.
   *)
  HasStoredState: Boolean;
  {$endif}

(**
 * Reports an error and raises ECompileError to unwind back to the point
 * where parsing was started.
 *)
procedure Error;
var
  I: Integer;
begin
  WriteLn;

  if Source <> nil then
  begin
    WriteLn(Source^.Buffer);
    for I := 1 to TokenColumn - 1 do Write(' ');
    WriteLn('^');
    WriteLn('*** Error at ', PosixToNative(FRelative(Source^.Name)), '(', TokenLine, ',', TokenColumn, '): ', Message);
  end
  else
    WriteLn('*** Error: ', Message);

  {$ifndef SYS_IR4}
  if HasStoredState then
    raise ECompileError.Create
  else
  {$endif}
  begin
    WriteLn;
    Halt(1);
  end;
end;

(* -------------------------------------------------------------------------- *)
(* --- Emitter -------------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

var
  (**
   * The text file we are writing IR4 code to.
   *)
  Target: Text;

  (**
   * The index of the next label we will generate.
   *)
  NextLabel: Integer;

  (**
   * Contains the current jump target for the Exit statement.
   *
   * TODO Should this be elsewhere, maybe together with Break/Continue?
   *)
  ExitTarget: String;

  Muted: Integer;

procedure MuteEmitter;
begin
  Inc(Muted);
end;

procedure UnmuteEmitter;
begin
  Dec(Muted);
end;

(**
 * Opens the target file.
 *)
procedure OpenTarget(Filename: String);
begin
  Assign(Target, Filename);
  Rewrite(Target);
end;

(**
 * Generates a new, unique label with the given prefix.
 *
 * TODO Is this in the right place?
 *)
function GetLabel;
begin
  GetLabel := Prefix + IntToStr(NextLabel);
  NextLabel := NextLabel + 1;
end;

// Emit(Col1, Col2, Col3, Col4)

procedure ClearIR4Chunks;
var
  Tmp: PIR4Chunk;
begin
  while IR4Head <> nil do
  begin
    Tmp := IR4Head^.Next;
    Dispose(IR4Head);
    IR4Head := Tmp;
  end;
  IR4Tail := nil;
  IR4Buffering := False;
end;

procedure FlushIR4Chunks;
var
  Tmp: PIR4Chunk;
begin
  while IR4Head <> nil do
  begin
    Write(Target, IR4Head^.Text);
    Tmp := IR4Head^.Next;
    Dispose(IR4Head);
    IR4Head := Tmp;
  end;
  IR4Tail := nil;
end;

procedure IR4Out((* const *) S: String);
var
  Chunk: PIR4Chunk;
begin
  if Length(S) = 0 then Exit;
  if not IR4Buffering then
  begin
    Write(Target, S);
    Exit;
  end;
  if (IR4Tail <> nil) and (Length(IR4Tail^.Text) + Length(S) <= 255) then
    IR4Tail^.Text := IR4Tail^.Text + S
  else
  begin
    New(Chunk);
    Chunk^.Text := S;
    Chunk^.Next := nil;
    if IR4Tail <> nil then
      IR4Tail^.Next := Chunk
    else
      IR4Head := Chunk;
    IR4Tail := Chunk;
  end;
end;

procedure IR4OutLn((* const *) S: String);
begin
  IR4Out(S);
  IR4Out(#10);
end;

function IR4MaxBytes(C, I, A, F: Integer): Integer;
var
  Res: Integer;
begin
  Res := C + 8 * (I + A + F);
  if Res < 1 then Res := 1;
  IR4MaxBytes := Res;
end;

function IR4TupleExprStr(C, I, A, F: Integer): String;
var
  S: String;
  Has: Boolean;
  procedure AppendTerm((* const *) T: String);
  begin
    if not Has then
    begin
      S := T;
      Has := True;
    end
    else
      S := S + ' ' + T + ' +';
  end;
begin
  S := '0';
  Has := False;
  if C <> 0 then AppendTerm(IntToStr(C));
  if I <> 0 then
  begin
    if I = 1 then AppendTerm('size_i')
    else AppendTerm('size_i ' + IntToStr(I) + ' *');
  end;
  if A <> 0 then
  begin
    if A = 1 then AppendTerm('size_a')
    else AppendTerm('size_a ' + IntToStr(A) + ' *');
  end;
  if F <> 0 then
  begin
    if F = 1 then AppendTerm('size_f')
    else AppendTerm('size_f ' + IntToStr(F) + ' *');
  end;
  IR4TupleExprStr := S;
end;

function IsIR4ScalarType(DataType: PSymbol): Boolean;
begin
  if DataType = nil then begin IsIR4ScalarType := False; Exit; end;
  while DataType^.Kind = scAliasType do DataType := DataType^.DataType;
  IsIR4ScalarType := (DataType = dtInteger) or (DataType = dtReal) or
                     (DataType^.Kind = scPointerType) or
                     ((DataType^.Kind = scSubrangeType) and (DataType^.IrI > 0));
end;

function IsIR4IntType(DataType: PSymbol): Boolean;
begin
  while (DataType <> nil) and (DataType^.Kind = scAliasType) do
    DataType := DataType^.DataType;
  IsIR4IntType := (DataType = dtInteger) or
                  ((DataType <> nil) and (DataType^.Kind = scSubrangeType) and (DataType^.IrI > 0));
end;

function AllocIR4TempTuple(C, I, A, F: Integer): String;
var
  Cur: TIR4Tuple;
begin
  Cur := IR4Frame;
  Inc(IR4Frame.C, C);
  Inc(IR4Frame.I, I);
  Inc(IR4Frame.A, A);
  Inc(IR4Frame.F, F);
  if IR4Frame.C > IR4MaxFrame.C then IR4MaxFrame.C := IR4Frame.C;
  if IR4Frame.I > IR4MaxFrame.I then IR4MaxFrame.I := IR4Frame.I;
  if IR4Frame.A > IR4MaxFrame.A then IR4MaxFrame.A := IR4Frame.A;
  if IR4Frame.F > IR4MaxFrame.F then IR4MaxFrame.F := IR4Frame.F;
  if (Cur.C = 0) and (Cur.I = 0) and (Cur.A = 0) and (Cur.F = 0) then
    AllocIR4TempTuple := '_locals'
  else
    AllocIR4TempTuple := '_locals ' + IR4TupleExprStr(Cur.C, Cur.I, Cur.A, Cur.F) + ' a+';
end;

function AllocIR4Temp(Size: Integer): String;
begin
  AllocIR4Temp := AllocIR4TempTuple(Size, 0, 0, 0);
end;

procedure Emit;
begin
  if Muted > 0 then Exit;
  if (Tag = '') and (Instruction = '') and (Comment <> '') then
  begin
    if IR4LineOpen then begin IR4OutLn(''); IR4LineOpen := False; end;
    IR4OutLn('\ ' + Comment);
    Exit;
  end;
  if Tag <> '' then
  begin
    if IR4LineOpen then begin IR4OutLn(''); IR4LineOpen := False; end;
    IR4OutLn(':: ' + Tag);
  end;
  if Instruction <> '' then
  begin
    if (Copy(Instruction, 1, 3) = 'fn ') or
       (Copy(Instruction, 1, 4) = 'fwd ') or
       (Copy(Instruction, 1, 4) = 'var ') or
       (Copy(Instruction, 1, 5) = 'data ') or
       (Copy(Instruction, 1, 6) = 'const ') or
       (Copy(Instruction, 1, 8) = 'require ') or
       (Instruction = 'init') or
       (Instruction = 'end') then
    begin
      if IR4LineOpen then begin IR4OutLn(''); IR4LineOpen := False; end;
      IR4OutLn(Instruction);
    end
    else
    begin
      if not IR4LineOpen then
      begin
        IR4Out('  ' + Instruction);
        IR4LineOpen := True;
      end
      else
        IR4Out(' ' + Instruction);
      if Comment <> '' then
      begin
        IR4OutLn(' \ ' + Comment);
        IR4LineOpen := False;
      end;
    end;
  end
  else if (Tag = '') and (Comment = '') then
  begin
    if IR4LineOpen then begin IR4OutLn(''); IR4LineOpen := False; end;
    IR4OutLn('');
  end;
end;

procedure SetLibrary;
begin
  if LowerStr(Copy(FileName, Length(FileName) - 3, 4)) = '.ir4' then
  begin
    Emit('', 'require "' + FileName + '"', '');
    Exit;
  end;
  Error('Assembly include not supported in IR4 mode: ' + FileName);
end;

procedure EmitI;
begin
  Emit('', S, '');
end;

procedure EmitC;
begin
  Emit('', '', S)
  //Flush;
  //WriteLn(Target, '; ', S);
end;

procedure EmitInclude(S: String);
begin
  if LowerStr(Copy(S, Length(S) - 3, 4)) = '.ir4' then
    EmitI('require "' + S + '"')
  else
    Error('Assembly include not supported in IR4 mode: ' + S);
end;

procedure EmitCall(Sym: PSymbol);
begin
  EmitI(Sym^.Tag);
end;

(**
 * Emits the file header.
 *)
procedure EmitHeader(Home: String; SrcFile: String);
begin
  SetDefine('PASTA', True);
  SetDefine('SYS_IR4', True);
  EmitC('program ' + SrcFile);
  EmitI('require "system_p.ir4"');
  EmitI('');
end;

(**
 * Emits the file footer.
 *)
procedure EmitFooter;
begin
  if IR4LineOpen then begin IR4OutLn(''); IR4LineOpen := False; end;
  IR4Buffering := False;
  FlushIR4Chunks;
end;

(**
 * Emits all strings collected in the string list as db items, disposing them on
 * the way. Stops at the given entry, which may be nil to emit the whole list.
 * Called once after each overlay (with the value of the list pointer immediately
 * before the overlay) and once at the end of the whole program (with nil).
 *)
function EncodeIR4Str((* const *) S: String): String;
var
  T: String;
  I: Integer;
  C: Char;
  InQ: Boolean;
begin
  if Length(S) = 0 then
  begin
    EncodeIR4Str := '0 :i8 0 :i8';
    Exit;
  end;
  T := IntToStr(Length(S)) + ' :i8';
  InQ := False;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C >= #32) and (C <= #126) then
    begin
      if not InQ then begin T := T + ' "'; InQ := True; end;
      if C = '"' then T := T + '\"'
      else if C = '\' then T := T + '\\'
      else T := T + C;
    end
    else
    begin
      if InQ then begin T := T + '"'; InQ := False; end;
      if C = #10 then T := T + ' "\n"'
      else if C = #13 then T := T + ' "\r"'
      else if C = #9 then T := T + ' "\t"'
      else T := T + ' ' + IntToStr(Ord(C)) + ' :i8';
    end;
  end;
  if InQ then T := T + '"';
  EncodeIR4Str := T + ' 0 :i8';
end;

procedure EmitStrings(Stop: PStringLiteral);
var
  Temp: PStringLiteral;
begin
  while Strings <> Stop do
  begin
    EmitI('data ' + Strings^.Tag);
    EmitI(EncodeIR4Str(Strings^.Value));
    EmitI('end');
    Temp := Strings^.Next;
    Dispose(Strings);
    Strings := Temp;
  end;
end;

(*
 * Emits the prologue for a procedure or function.
 * calling convention. The stack frame looks like this:
 *
 * +------------------+
 * | result (if any)  |
 * | 1st argument     |
 * | ...              |
 * | nth argument     |
 * | return addr      |
 * | old base pointer | <-- frame pointer
 * | 1st local        |
 * | ...              |
 * | nth local        | <-- stack pointer
 * +------------------+
 *
 * All access to local variables that are stored on the stack happens via the
 * frame pointer. The frame pointer is kept in the display entry matching the
 * nesting level of the procedure of function. It is not kept in a register
 * pair. The old frame pointer for that nesting level is stored on the stack.
 * Arguments are cleanup up by the caller.
 *)
procedure EmitPrologue(Sym: PSymbol);
var
  Sig, LAddr: String;
  P: PSymbol;
  I, ParamIdx: Integer;
  Params: array[0..15] of PSymbol;
  ParamCount: Integer;
begin
  if Sym = Nil then
  begin
    IR4Frame.C := 0; IR4Frame.I := 0; IR4Frame.A := 0; IR4Frame.F := 0;
    IR4BaseFrame := IR4Frame;
    IR4MaxFrame := IR4Frame;
    IR4FnSig := 'fn main ( -> :i )';
    IR4Buffering := True;
    Exit;
  end;

  ParamCount := 0;
  P := SymbolTable;
  while (P <> nil) and (P <> Sym) do
  begin
    if (P^.Kind = scVar) and (P^.Tag <> 'RESULT') and P^.IsParam and (ParamCount < 16) then
    begin
      Params[ParamCount] := P;
      Inc(ParamCount);
    end;
    P := P^.Prev;
  end;

  IR4BaseFrame := IR4Frame;
  IR4MaxFrame := IR4Frame;
  Sig := 'fn ' + Sym^.Tag + ' (';
  for I := ParamCount - 1 downto 0 do
  begin
    ParamIdx := ParamCount - 1 - I;
    if Params[I]^.DataType = dtReal then
      Sig := Sig + ' p' + IntToStr(ParamIdx) + ' :f'
    else if (Params[I]^.DataType^.Kind in [scPointerType, scStringType, scSetType, scArrayType, scRecordType]) or Params[I]^.IsRef then
      Sig := Sig + ' p' + IntToStr(ParamIdx) + ' :a'
    else
      Sig := Sig + ' p' + IntToStr(ParamIdx) + ' :i';
  end;
  if (Sym^.Kind = scFunc) and (Sym^.DataType^.Kind in [scStringType, scSetType, scArrayType, scRecordType]) then
    Sig := Sig + ' p_sret :a';
  if Sym^.Kind = scFunc then
  begin
    if Sym^.DataType = dtReal then
      Sig := Sig + ' -> :f'
    else if Sym^.DataType^.Kind in [scPointerType, scStringType, scSetType, scArrayType, scRecordType] then
      Sig := Sig + ' -> :a'
    else
      Sig := Sig + ' -> :i';
  end;
  Sig := Sig + ' )';
  IR4FnSig := Sig;
  IR4Buffering := True;

  if Sym^.Level < 7 then
  begin
    EmitI('__display ' + IntToStr(Sym^.Level + 1) + ' size_a * a+ a@ _locals a!');
    EmitI('_locals __display ' + IntToStr(Sym^.Level + 1) + ' size_a * a+ a!');
  end;

  for I := ParamCount - 1 downto 0 do
  begin
    ParamIdx := ParamCount - 1 - I;
    LAddr := '_locals';
    if (Params[I]^.IrC <> 0) or (Params[I]^.IrI <> 0) or (Params[I]^.IrA <> 0) or (Params[I]^.IrF <> 0) then
      LAddr := '_locals ' + IR4TupleExprStr(Params[I]^.IrC, Params[I]^.IrI, Params[I]^.IrA, Params[I]^.IrF) + ' a+';
    if (Params[I]^.DataType^.Kind = scStringType) and not Params[I]^.IsRef then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' ' + IntToStr(Params[I]^.DataType^.Value - 1) + ' pas_strcopy_clamp drop')
    else if (Params[I]^.DataType^.Kind = scSetType) and not Params[I]^.IsRef then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' 32 memcpy')
    else if (Params[I]^.DataType^.Kind in [scArrayType, scRecordType]) and not Params[I]^.IsRef then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' ' + IR4TupleExprStr(Params[I]^.DataType^.IrC, Params[I]^.DataType^.IrI, Params[I]^.DataType^.IrA, Params[I]^.DataType^.IrF) + ' memcpy')
    else if (Params[I]^.DataType^.Kind = scPointerType) or Params[I]^.IsRef then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' swap a!')
    else if Params[I]^.DataType = dtReal then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' swap f!')
    else if IsIR4IntType(Params[I]^.DataType) then
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' swap !')
    else
      EmitI(LAddr + ' p' + IntToStr(ParamIdx) + ' swap i8!');
  end;
end;

(**
 * Emits the epilogue to a procedure or function that uses standard calling
 * convention. Restores the old frame pointer.
 *)
procedure EmitEpilogue(Sym: PSymbol);
var
  P: PSymbol;
  Total: Integer;
  RAddr: String;
begin
  Emit(ExitTarget, '', '');
  if Sym = nil then
    EmitI('__exitcode')
  else
  begin
    if Sym^.Kind = scFunc then
    begin
      P := SymbolTable;
      while (P <> nil) and ((P^.Kind <> scVar) or (P^.Tag <> 'RESULT')) do
        P := P^.Prev;
      if P <> nil then
      begin
        RAddr := '_locals';
        if (P^.IrC <> 0) or (P^.IrI <> 0) or (P^.IrA <> 0) or (P^.IrF <> 0) then
          RAddr := '_locals ' + IR4TupleExprStr(P^.IrC, P^.IrI, P^.IrA, P^.IrF) + ' a+';
        if P^.DataType = dtReal then
          EmitI(RAddr + ' f@')
        else if P^.DataType^.Kind = scStringType then
          EmitI('p_sret ' + RAddr + ' ' + IntToStr(P^.DataType^.Value - 1) + ' pas_strcopy_clamp drop p_sret')
        else if P^.DataType^.Kind = scSetType then
          EmitI('p_sret ' + RAddr + ' 32 memcpy p_sret')
        else if P^.DataType^.Kind in [scArrayType, scRecordType] then
          EmitI('p_sret ' + RAddr + ' ' + IR4TupleExprStr(P^.DataType^.IrC, P^.DataType^.IrI, P^.DataType^.IrA, P^.DataType^.IrF) + ' memcpy p_sret')
        else if P^.DataType^.Kind = scPointerType then
          EmitI(RAddr + ' a@')
        else if IsIR4IntType(P^.DataType) then
          EmitI(RAddr + ' @')
        else
          EmitI(RAddr + ' u8@');
      end;
    end;
    if Sym^.Level < 7 then
      EmitI('_locals a@ __display ' + IntToStr(Sym^.Level + 1) + ' size_a * a+ a!');
  end;
  EmitI('end');
  IR4Buffering := False;
  EmitStrings(nil);
  IR4OutLn(IR4FnSig);
  if (IR4MaxFrame.C <> 0) or (IR4MaxFrame.I <> 0) or (IR4MaxFrame.A <> 0) or (IR4MaxFrame.F <> 0) then
  begin
    Total := IR4MaxBytes(IR4MaxFrame.C, IR4MaxFrame.I, IR4MaxFrame.A, IR4MaxFrame.F);
    IR4OutLn('  var _locals :bytes ' + IntToStr(Total));
  end;
  FlushIR4Chunks;
end;

(**
 * Emits code that puts the address of the given symbol on the stack. Takes into
 * account the addressing mode (global vs. local), indirection and a possible
 * offset.
 *)
procedure EmitAddress(Sym: PSymbol);
begin
  with Sym^ do
  begin
    if (Tag <> '') and (Tag <> 'RESULT') then
    begin
      if Tag[1] in ['0'..'9', '-'] then
        EmitI(Tag + ' i>a')
      else if IsIR4ScalarType(DataType) and (Value2 = 0) and (WithC = 0) and (WithI = 0) and (WithA = 0) and (WithF = 0) and not IsRef then
        EmitI('& ' + Tag)
      else
        EmitI(Tag);
    end
    else
    begin
      if (Sym^.Level > 0) and (Sym^.Level <> Level) then
        EmitI('__display ' + IntToStr(Sym^.Level) + ' size_a * a+ a@')
      else
        EmitI('_locals');
      if (IrC <> 0) or (IrI <> 0) or (IrA <> 0) or (IrF <> 0) then
        EmitI(IR4TupleExprStr(IrC, IrI, IrA, IrF) + ' a+');
    end;
    if IsRef then
      EmitI('a@');
    if (WithC <> 0) or (WithI <> 0) or (WithA <> 0) or (WithF <> 0) then
      EmitI(IR4TupleExprStr(WithC, WithI, WithA, WithF) + ' a+')
    else if Value2 <> 0 then
      EmitI(IntToStr(Value2) + ' a+');
  end;
end;

(**
 * Emits code that pops an address off the stack and pushes data located at
 * that address on the stack. Takes into account the given datatype (mostly
 * for the size)
 *)
procedure EmitLoad(DataType: PSymbol);
begin
  if DataType = dtUnknown then
    Error('Cannot read through untyped pointer');

  while DataType^.Kind = scAliasType do DataType := DataType^.DataType;
  if IsIR4IntType(DataType) then
    EmitI('@')
  else if DataType = dtReal then
    EmitI('f@')
  else if DataType^.Kind = scPointerType then
    EmitI('a@')
  else if DataType^.Kind in [scStringType, scSetType, scArrayType, scRecordType] then
    { Composite values stay as :a addresses }
  else if DataType^.Value = 1 then
    EmitI('u8@')
  else
    Error('IR4 load unsupported size: ' + IntToStr(DataType^.Value));
end;

(**
 * Emits code that pops an address off the stack and pushes data located at
 * that address on the stack. Takes into account the given datatype (mostly
 * for the size)
 *)
procedure EmitStore(DataType: PSymbol);
begin
  while DataType^.Kind = scAliasType do DataType := DataType^.DataType;
  if IsIR4IntType(DataType) then
    EmitI('swap !')
  else if DataType = dtReal then
    EmitI('swap f!')
  else if DataType^.Kind = scPointerType then
    EmitI('swap a!')
  else if DataType^.Kind = scStringType then
    EmitI(IntToStr(DataType^.Value - 1) + ' pas_strcopy_clamp drop')
  else if DataType^.Kind = scSetType then
    EmitI('32 memcpy')
  else if DataType^.Kind in [scArrayType, scRecordType] then
    EmitI(IR4TupleExprStr(DataType^.IrC, DataType^.IrI, DataType^.IrA, DataType^.IrF) + ' memcpy')
  else if DataType^.Value = 1 then
    EmitI('swap i8!')
  else
    Error('IR4 store unsupported size: ' + IntToStr(DataType^.Value));
end;

procedure EmitLiteral(Value: Integer);
begin
  EmitI(IntToStr(Value));
end;

(**
 * Emits code implementing the given relational operator for integers.
 *)
procedure EmitRelOp(Op: TToken);
begin
  case Op of
    toEq:  EmitI('=');
    toNeq: EmitI('<>');
    toLt:  EmitI('<');
    toGt:  EmitI('>');
    toLeq: EmitI('<=');
    toGeq: EmitI('>=');
  end;
end;

(**
 * Emits code implementing the given relational operator for pointers.
 *)
procedure EmitPtrOp(Op: TToken);
begin
  case Op of
    toEq:  EmitI('a=');
    toNeq: EmitI('a<>');
    toLt:  EmitI('a<');
    toGt:  EmitI('a>');
    toLeq: EmitI('a> 0 =');
    toGeq: EmitI('a< 0 =');
  end;
end;

procedure EmitUnOp(Op: TToken; DataType: PSymbol); forward;

(**
 * Emits code implementing the given relational operator for strings.
 *)
procedure EmitStrOp(Op: TToken);
begin
  case Op of
    toEq:  EmitI('pas_streq');
    toNeq: EmitI('pas_streq 0 =');
    toLt:  EmitI('pas_strcmp 0 <');
    toLeq: EmitI('pas_strcmp 0 <=');
    toGt:  EmitI('pas_strcmp 0 >');
    toGeq: EmitI('pas_strcmp 0 >=');
  end;
end;

procedure EmitNeg(DataType: PSymbol); forward;

(**
 * Emits the given set operation.
 *)
procedure EmitSetOp(Op: TToken);
begin
  case Op of
    toIn:  EmitI('pas_set_in');
    toAdd: EmitI(AllocIR4Temp(32) + ' pas_set_add');
    toSub: EmitI(AllocIR4Temp(32) + ' pas_set_sub');
    toMul: EmitI(AllocIR4Temp(32) + ' pas_set_mul');
    toEq:  EmitI('pas_set_eq');
    toNeq: EmitI('pas_set_eq 0 =');
    toLeq: EmitI('pas_set_leq');
    toGeq: EmitI('pas_set_geq');
  end;
end;

(**
 * Emits code implementing the given mathematic operation for floats.
 *)
procedure EmitFloatOp(Op: TToken);
begin
  case Op of
    toAdd: EmitI('f+');
    toSub: EmitI('f-');
    toMul: EmitI('f*');
    toDiv: EmitI('f/');
    toEq:  EmitI('f=');
    toNeq: EmitI('f<>');
    toLt:  EmitI('f<');
    toGt:  EmitI('f>');
    toLeq: EmitI('f> 0 =');
    toGeq: EmitI('f< 0 =');
  else
    Error(TokenStr[Op] + ' not allowed for Real');
  end;
end;

(**
 * Emits code that performs an unconditional jump to the given target.
 *)
procedure EmitJump(Target: String);
begin
  EmitI('jmp ' + Target);
end;

(**
 * Emits code that performs a conditional jump to the given target.
 *)
procedure EmitJumpIf(When: Boolean; Target: String);
begin
  if When then
    EmitI('0 = jz ' + Target)
  else
    EmitI('jz ' + Target);
end;

(**
 * Emits code the performs the given math or bit binary operation on integers.
 * Data type is also passed as a parameter because some 8 bit cases can be
 * implemented by shorter code.
 *)
procedure EmitBinOp(Op: TToken; DataType: PSymbol);
begin
  case Op of
    toAdd:   EmitI('+');
    toSub:   EmitI('-');
    toMul:   EmitI('*');
    toDivKW: EmitI('/');
    toMod:   EmitI('mod');
    toAnd:   EmitI('and');
    toOr:    EmitI('or');
    toXor:   EmitI('xor');
    toShl:   EmitI('<<');
    toShr:   EmitI('>>');
  end;
end;

(**
 * Emits code the performs the given math or bit unary operation on integers.
 * Data type is also passed as a parameter because some 8 bit cases can be
 * implemented by shorter code.
 *)
procedure EmitUnOp;
begin
  if Op = toNot then
  begin
    if DataType = dtBoolean then
      EmitI('0 =')
    else
      EmitI('-1 xor');
  end;
end;

(**
 * Emits code that implements negation for the data type passed as a parameter.
 *)
procedure EmitNeg;
begin
  if (DataType = dtInteger) or (DataType = dtByte) then
    EmitI('0 swap -')
  else if DataType = dtReal then
    EmitI('fnegate')
  else
    Error('Invalid type ' + TypeName(DataType));
end;

(**
 * Emits code that performs increment-by-one for the given data type (basically
 * 8 or 16 bit integer).
 *)
procedure EmitInc(DataType: PSymbol);
begin
  if IsIR4IntType(DataType) then
    EmitI('dup @ 1 + swap !')
  else
    EmitI('dup u8@ 1 + swap i8!');
end;

(**
 * Emits code that performs decrement-by-one for the given data type (basically
 * 8 or 16 bit integer).
 *)
procedure EmitDec(DataType: PSymbol);
begin
  if IsIR4IntType(DataType) then
    EmitI('dup @ 1 - swap !')
  else
    EmitI('dup u8@ 1 - swap i8!');
end;

(**
 * Emits code that performs shift-left-by-one for the given data type (basically
 * 8 or 16 bit integer).
 *)
procedure EmitShl;
begin
  EmitI('1 <<');
end;

(**
 * Emits the Str(V, S) statement with zero format specifiers. Type of value
 * and string variable are given as parameters. All values are on the stack.
 *)
procedure EmitStr(DataType, VarType: PSymbol);
begin
  while DataType^.Kind = scSubrangeType do
    DataType := DataType^.DataType;

  if (DataType = dtInteger) or (DataType = dtByte) then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_int')
  else if DataType = dtChar then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_char')
  else if DataType^.Kind = scStringType then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_str')
  else if DataType = dtReal then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_float')
  else if DataType^.Kind = scEnumType then
    EmitI(DataType^.Tag + ' ' + IntToStr(VarType^.Value - 1) + ' pas_str_enum')
  else Error('Unprintable type: ' + TypeName(DataType));
end;

(**
 * Emits the Str(V, S) statement with one format specifier. Type of value
 * and string variable are given as parameters. All values are on the stack.
 *)
procedure EmitStr1(DataType, VarType: PSymbol);
begin
  while DataType^.Kind = scSubrangeType do
    DataType := DataType^.DataType;

  if (DataType = dtInteger) or (DataType = dtByte) then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_int_w')
  else if DataType = dtChar then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_char_w')
  else if DataType^.Kind = scStringType then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_str_w')
  else if DataType = dtReal then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_float_exp')
  else if DataType^.Kind = scEnumType then
    EmitI(DataType^.Tag + ' ' + IntToStr(VarType^.Value - 1) + ' pas_str_enum_w')
  else Error('Unprintable type: ' + TypeName(DataType));
end;

(**
 * Emits the Str(V, S) statement with two format specifiers. Type of value
 * and string variable are given as parameters. All values are on the stack.
 *)
procedure EmitStr2(DataType, VarType: PSymbol);
begin
  if DataType = dtReal then
    EmitI(IntToStr(VarType^.Value - 1) + ' pas_str_float_fix')
  else Error('Unprintable type: ' + TypeName(DataType));
end;

(**
 * Emits the console Write statement with zero format specifiers. The type of
 * the value is given as parameter. The value resides on the stack.
 *
 * TODO Merge with or leverage code from EmitStr?
 *)
procedure EmitWrite(DataType: PSymbol);
begin
  while DataType^.Kind = scSubrangeType do
    DataType := DataType^.DataType;

  if (DataType = dtInteger) or (DataType = dtByte) then
    EmitI('typei')
  else if DataType = dtChar then
    EmitI('xemit')
  else if DataType^.Kind = scStringType then
    EmitI('pas_prints')
  else if DataType = dtReal then
    EmitI('16 pas_putf_exp')
  else if DataType^.Kind = scEnumType then
    EmitI(DataType^.Tag + ' pas_print_enum')
  else
    Error('Unprintable IR4 type: ' + TypeName(DataType));
end;

(**
 * Emits the console Write statement with one format specifier. The type of
 * the value is given as parameter. All values reside on the stack.
 *
 * TODO Merge with or leverage code from EmitStr1?
 *)
procedure EmitWrite1(DataType: PSymbol);
begin
  while DataType^.Kind = scSubrangeType do
    DataType := DataType^.DataType;

  if (DataType = dtInteger) or (DataType = dtByte) then
    EmitI('typeiw')
  else if DataType = dtChar then
    EmitI('pas_printc_w')
  else if DataType^.Kind = scStringType then
    EmitI('pas_prints_w')
  else if DataType = dtReal then
    EmitI('pas_putf_exp')
  else if DataType^.Kind = scEnumType then
    EmitI(DataType^.Tag + ' swap pas_print_enum_w')
  else
    Error('Unprintable IR4 type: ' + TypeName(DataType));
end;

(**
 * Emits the console Write statement with two format specifiers. The type of
 * the value is given as parameter. All values reside on the stack.
 *
 * TODO Merge with or leverage code from EmitStr2?
 *)
procedure EmitWrite2(DataType: PSymbol);
begin
  if DataType <> dtReal then Error('Unprintable type for format 2: ' + TypeName(DataType));

  EmitI('pas_putf_fix');
end;

(**
 * Closes the assembly target file.
 *)
procedure CloseTarget;
begin
  Close(Target);
end;

(**
 * Emits a promotion from a single character to a string.
 *)
procedure EmitCharToString;
begin
  EmitI(AllocIR4Temp(256) + ' pas_char2str');
end;

(* -------------------------------------------------------------------------- *)
(* --- Type checker --------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

type
  (**
   * The types of type check we can perform.
   *
   * TODO Check whether this distinction still makes sense.
   *)
  TTypeCheck = (tcExact, tcAssign, tcExpr);

(**
 * Reduces an ordinal type to the type it is compatible with: aliases and
 * subranges to their base type, and Byte to Integer.
 *)
function OrdinalBase(T: PSymbol): PSymbol;
begin
  while T^.Kind in [scAliasType, scSubrangeType] do T := T^.DataType;
  if T = dtByte then T := dtInteger;
  OrdinalBase := T;
end;

(**
 * Checks that T is a scalar (ordinal) type and returns it unchanged.
 *)
function CheckScalar(T: PSymbol): PSymbol;
begin
  if not (T^.Kind in [scType, scEnumType, scSubrangeType, scAliasType])
    or (OrdinalBase(T) = dtReal) or (OrdinalBase(T) = dtUnknown) then
      Error('Scalar expected');
  CheckScalar := T;
end;

(**
 * Checks that the scalar type T is compatible with the element type Elem
 * (of a set, or of a case selector) and returns T unchanged. A nil on either
 * side, as produced by the empty set, is compatible with everything.
 *)
function CheckElement(Elem, T: PSymbol): PSymbol;
begin
  if (Elem <> nil) and (T <> nil) and (OrdinalBase(Elem) <> OrdinalBase(T)) then
    Error('Incompatible types');
  CheckElement := T;
end;

(**
 * Performs assignment type check. Might promote either type to the other
 * depending on the kind of check.
 *)
function TypeCheck(Left, Right: PSymbol; Check: TTypeCheck): PSymbol;
begin
  if Left = nil then Error('Error in TypeCheck: Left = nil');
  if Right = nil then Error('Error in TypeCheck: Right = nil');

  if Left^.Kind = scSubrangeType then Left := Left^.DataType;
  if Right^.Kind = scSubrangeType then Right := Right^.DataType;

  if Left = Right then
  begin
    TypeCheck := Left;
    Exit;
  end;

  (* The empty set has no element type and is compatible with every set. *)
  if (Left^.Kind = scSetType) and (Right^.Kind = scSetType) then
  begin
    CheckElement(Left^.DataType, Right^.DataType);
    if Left^.DataType = nil then TypeCheck := Right else TypeCheck := Left;
    Exit;
  end;

  if (Left^.Kind = scPointerType) and (Right^.Kind = scPointerType) then
  begin
    if (Left^.DataType <> nil) and (Right^.DataType <> nil) and (Left^.DataType <> Right^.DataType) then
      Error('Incompatible pointer types');

    TypeCheck := Left;
    Exit;
  end;

  if (Left = dtReal) and ((Right = dtInteger) or (Right = dtByte)) then
  begin
    EmitI('i>f');
    TypeCheck := dtReal;
    Exit;
  end;

  if ((Left = dtInteger) or (Left = dtByte)) and (Right = dtReal) and (Check <> tcAssign) then
  begin
    EmitI('swap i>f swap');
    TypeCheck := dtReal;
    Exit;
  end;

  if Check = tcExpr then
  begin
    if (Left^.Kind = scStringType) and (Right^.Kind = scStringType) then
    begin
      TypeCheck := dtString;
      Exit;
    end;

    if (Left = dtInteger) and (Right = dtByte) or (Left = dtByte) and (Right = dtInteger) then
    begin
      TypeCheck := dtInteger;
      Exit;
    end;
  end
  else if Check = tcAssign then
  begin
    if (Left^.Kind = scStringType) and (Right^.Kind = scStringType) then
    begin
      (* Clamp the length byte of the string on the stack to the target type's
         maximum length, so that value parameters and assignments to shorter
         string types never carry oversized data into the callee's frame. *)
      if Left^.Value < Right^.Value then
        EmitI(AllocIR4Temp(Left^.Value) + ' swap ' + IntToStr(Left^.Value - 1) + ' pas_strcopy_clamp');
      TypeCheck := Left;
      Exit;
    end;

    if (Left = dtInteger) and (Right = dtByte) then
    begin
      TypeCheck := dtInteger;
      Exit;
    end
    else if (Left = dtByte) and (Right = dtInteger) then
    begin
      TypeCheck := dtByte;
      Exit;
    end
  end;

  if (Left^.Kind = scStringType) and (Right = dtChar) then
  begin
    EmitCharToString;
    TypeCheck := dtString;
    Exit;
  end;

  if Check = tcExact then
  begin
    if (Left^.Kind = scStringType) and (Right^.Kind = scStringType) then
    begin
      TypeCheck := dtString;
      Exit;
    end;
  end;

  Error('Type error, expected ' + TypeName(Left) + ', got ' + TypeName(Right));
end;

(* -------------------------------------------------------------------------- *)
(* --- Parser --------------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

(**
 * Expects a certain token then consumes it. Shorthand for a very frequent
 * statement sequence. Saves a line of code here and there.
 *)
procedure ParseToken(T: TToken);
begin
  Expect(T);
  NextToken;
end;

function ParseExpression: PSymbol; forward;

(**
 * Parses a (potentially empty) chain of Pascal selectors, that is, array
 * indexing ([]), field selection (.), and pointer dereference (^). Used by
 * ParseVariableAccess (coming from a variable) and ParseVariableChain (coming
 * from an expression). Variable and Offset implement deferred global-address
 * optimisation:
 * - When Offset >= 0 the base address has not been emitted yet
 *   and will be folded with constant field offsets at compile time
 * - When Offset = -1 the address is already on the stack and Variable is
 *   unused.
 *)
function ParseSelectorChain(Variable, DataType: PSymbol; Offset: Integer): PSymbol;
var
  Field: PSymbol;
  IrOffC, IrOffI, IrOffA, IrOffF: Integer;

  procedure DelayedEmitAddr;
  begin
    if Offset >= 0 then
    begin
      if (Length(Variable^.Tag) > 0) and (Variable^.Tag[1] in ['0'..'9', '-']) then
        EmitI(Variable^.Tag + ' i>a')
      else if (Offset = 0) and (IrOffC = 0) and (IrOffI = 0) and (IrOffA = 0) and (IrOffF = 0) and
         IsIR4ScalarType(Variable^.DataType) and not Variable^.IsRef then
        EmitI('& ' + Variable^.Tag)
      else
        EmitI(Variable^.Tag);
      if (IrOffC <> 0) or (IrOffI <> 0) or (IrOffA <> 0) or (IrOffF <> 0) then
        EmitI(IR4TupleExprStr(IrOffC, IrOffI, IrOffA, IrOffF) + ' a+');
      Offset := -1;
      IrOffC := 0; IrOffI := 0; IrOffA := 0; IrOffF := 0;
    end;
  end;

begin
  IrOffC := 0; IrOffI := 0; IrOffA := 0; IrOffF := 0;
  while Scanner.Token in [toLBrack, toPeriod, toCaret] do
  begin
    if Scanner.Token = toLBrack then
    begin
      DelayedEmitAddr;

      repeat
        NextToken;
        if DataType^.Kind = scArrayType then
        begin
          TypeCheck(DataType^.IndexType, ParseExpression, tcExpr);

          if DataType^.IndexType^.Low <> 0 then
          begin
            EmitLiteral(DataType^.IndexType^.Low);
            EmitBinOp(toSub, dtInteger);
          end;

          DataType := DataType^.DataType;

          if (DataType^.IrC <> 1) or (DataType^.IrI <> 0) or (DataType^.IrA <> 0) or (DataType^.IrF <> 0) then
            EmitI(IR4TupleExprStr(DataType^.IrC, DataType^.IrI, DataType^.IrA, DataType^.IrF) + ' *');
          EmitI('a+');
        end
        else if DataType^.Kind = scStringType then
        begin
          TypeCheck(dtInteger, ParseExpression, tcExpr);
          DataType := dtChar;
          EmitI('a+');
        end
        else Error('Not an array or a string');
      until Scanner.Token <> toComma;

      Expect(toRBrack);
      NextToken;
    end
    else if Scanner.Token = toPeriod then
    begin
      if DataType^.Kind <> scRecordType then
        Error('Not a record');

      NextToken;
      Expect(toIdent);
      Field := Lookup(Scanner.StrValue, DataType^.DataType, nil);
      if Field = nil then Error('Unknown field "' + Scanner.StrValue + '"');

      DataType := Field^.DataType;

      if Offset >= 0 then
      begin
        Inc(Offset, Field^.Value);
        Inc(IrOffC, Field^.IrC);
        Inc(IrOffI, Field^.IrI);
        Inc(IrOffA, Field^.IrA);
        Inc(IrOffF, Field^.IrF);
      end
      else
      begin
        if (Field^.IrC <> 0) or (Field^.IrI <> 0) or (Field^.IrA <> 0) or (Field^.IrF <> 0) then
          EmitI(IR4TupleExprStr(Field^.IrC, Field^.IrI, Field^.IrA, Field^.IrF) + ' a+');
      end;

      NextToken;
    end
    else
    begin
      DelayedEmitAddr;

      if DataType^.Kind <> scPointerType then
        Error('Not a pointer');

      NextToken;

      EmitI('a@');

      if DataType = dtPointer then
        DataType := dtUnknown
      else
        DataType := DataType^.DataType;
    end;
  end;

  DelayedEmitAddr;
  ParseSelectorChain := DataType;
end;

(**
 * Parses access to a variable, result in the final address being on the stack.
 * Defers emitting the base address for globals so the assembler can fold
 * constant field offsets at compile time.
 *)
function ParseVariableAccess(Symbol: PSymbol): PSymbol;
var
  Offset: Integer;
begin
  if (Symbol^.Tag <> '') and (Symbol^.Tag <> 'RESULT') then
    Offset := 0
  else
  begin
    EmitAddress(Symbol);
    Offset := -1;
  end;
  ParseVariableAccess := ParseSelectorChain(Symbol, Symbol^.DataType, Offset);
end;

(**
 * Continues variable access when the address is already on the stack. Used
 * when a pointer expression (rather than a variable) is the var-param root.
 *)
function ParseVariableChain(DataType: PSymbol): PSymbol;
begin
  ParseVariableChain := ParseSelectorChain(nil, DataType, -1);
end;

(**
 * Parses a single actual argument for a procedure or function call.
 *)
procedure ParseArgument(Sym: PSymbol; I: Integer);
var
  Sym2, T: PSymbol;
begin
  if Sym^.ArgIsRef[I] then
  begin
    Expect(toIdent);
    Sym2 := LookupGlobalOrFail(Scanner.StrValue);
    if Sym2^.Kind = scVar then
    begin
      NextToken;
      T := ParseVariableAccess(Sym2);
    end
    else
    begin
      T := ParseExpression;
      if T^.Kind <> scPointerType then
        Error('Variable or pointer dereference expected');
      Expect(toCaret);
      NextToken;
      if T = dtPointer then T := dtUnknown else T := T^.DataType;
      T := ParseVariableChain(T);
    end;
    if Sym^.ArgTypes[I] <> nil then
      TypeCheck(Sym^.ArgTypes[I], T, tcAssign);
  end
  else
    TypeCheck(Sym^.ArgTypes[I], ParseExpression, tcAssign);
end;

(**
 * Parses the list of actual arguments for a procedure or function call.
 *)
procedure ParseArguments(Sym: PSymbol);
var
  I, J: Integer;
begin
  I := 0;
  J := Sym^.Value;

  if J <> 0 then
  begin
    Expect(toLParen);
    NextToken;

    ParseArgument(Sym, I);
    I := I + 1;

    while I < Sym^.Value do
    begin
      Expect(toComma);
      NextToken;
      ParseArgument(Sym, I);
      I := I + 1;
    end;

    Expect(toRParen);
    NextToken;
  end
  else if Scanner.Token = toLParen then Error('Arguments not allowed here')
end;

(**
 * Parses a reference to a variable or pointer dereference for use as a var
 * parameter. Accepts either a plain variable (possibly with field/index/deref
 * access) or any pointer expression followed by at least one ^, so that e.g.
 * FillChar(GetDisplayFile^, ...) and FillChar(BytePtr(16384)^, ...) work.
 *)
function ParseVariableRef: PSymbol;
var
  Sym: PSymbol;
  T: PSymbol;
begin
  Expect(toIdent);
  Sym := LookupGlobalOrFail(Scanner.StrValue);
  if Sym^.Kind = scVar then
  begin
    NextToken;
    ParseVariableRef := ParseVariableAccess(Sym);
  end
  else
  begin
    T := ParseExpression;
    if T^.Kind <> scPointerType then
      Error('Variable or pointer dereference expected');
    Expect(toCaret);
    NextToken;
    if T = dtPointer then T := dtUnknown else T := T^.DataType;
    ParseVariableRef := ParseVariableChain(T);
  end;
end;

(**
 * Parses read access to a "magic" built-in variable. Currently only used for
 * Mem[].
 *)
function ParseBuiltInVarRead(Sym: PSymbol): PSymbol;
begin
  if Sym = MemArray then
  begin
    ParseToken(toLBrack);
    TypeCheck(dtInteger, ParseExpression, tcAssign);
    ParseToken(toRBrack);

    EmitI('i>a u8@');
  end
  else Error('Invalid magic var: ' + Sym^.Name);

  ParseBuiltInVarRead := dtByte;
end;

(**
 * Parses write access to a "magic" built-in variable. Currently only used for
 * Mem[].
 *)
procedure ParseBuiltInVarWrite(Sym: PSymbol);
begin
  if Sym = MemArray then
  begin
    ParseToken(toLBrack);
    TypeCheck(dtInteger, ParseExpression, tcAssign);
    ParseToken(toRBrack);
    ParseToken(toBecomes);
    TypeCheck(dtByte, ParseExpression, tcAssign);

    EmitI('swap i>a i8!');
  end
  else Error('Invalid magic var: ' + Sym^.Name);
end;

(**
 * Parses a built-in function, which is basically every pre-defined function
 * that does not have a fixed syntax (variable parameters, for instance).
 *
 * TODO Split this into multiple procedures?
 *)
function ParseBuiltInFunction(Func: PSymbol): PSymbol;
var
  T, Sym: PSymbol;
begin
  if Func^.Kind <> scFunc then
    Error('Not a built-in function: ' + Func^.Name);

  if Func = RandomFunc then
  begin
    NextToken;

    if Scanner.Token = toLParen then
      Sym := LookupBuiltInOrFail('RandomInt')
    else
      Sym := LookupBuiltInOrFail('RandomReal');

    ParseArguments(Sym);
    EmitCall(Sym);

    ParseBuiltInFunction := Sym^.DataType;

    Exit;
  end;

  NextToken; Expect(toLParen); NextToken;

  if Func = AbsFunc then
  begin
    Sym := ParseExpression;

    if (Sym = dtInteger) or (Sym = dtByte) then
    begin
      EmitI('pas_abs');
      ParseBuiltInFunction := dtInteger;
    end
    else if Sym = dtReal then
    begin
      EmitI('fabs');
      ParseBuiltInFunction := dtReal;
    end
    else Error('Integer or Real expected');
  end
  else if Func = AddrFunc then
  begin
    Expect(toIdent);
    Sym := LookupGlobalOrFail(Scanner.StrValue);
    NextToken;
    ParseVariableAccess(Sym);
    EmitI('a>i');
    ParseBuiltInFunction := dtInteger;
  end
  else if Func = PtrFunc then
  begin
    TypeCheck(dtInteger, ParseExpression, tcAssign);
    EmitI('i>a');
    ParseBuiltInFunction := dtPointer;
  end
  else if Func = SizeFunc then
  begin
    Expect(toIdent);
    Sym := LookupGlobalOrFail(Scanner.StrValue);
    NextToken;

    if Sym^.Kind = scVar then
    begin
      MuteEmitter;
      Sym := ParseVariableAccess(Sym);
      UnmuteEmitter;
    end;

    if Sym^.Kind in [scType, scArrayType, scRecordType, scEnumType, scStringType,
                     scFileType, scSubrangeType, scSetType, scPointerType] then
      EmitI(IR4TupleExprStr(Sym^.IrC, Sym^.IrI, Sym^.IrA, Sym^.IrF))
    else
      Error('Cannot apply SizeOf to ' + Sym^.Name);

    ParseBuiltInFunction := dtInteger;
  end
  else if Func = OrdFunc then
  begin
    T := ParseExpression;
    if T^.Kind <> scPointerType then CheckScalar(T)
    else EmitI('a>i');
    ParseBuiltInFunction := dtInteger;
  end
  else if Func = OddFunc then
  begin
    CheckScalar(ParseExpression);
    EmitI('1 and 0 <>');
    ParseBuiltInFunction := dtBoolean;
  end
  else if Func = EvenFunc then
  begin
    CheckScalar(ParseExpression);
    EmitI('1 and 0 =');
    ParseBuiltInFunction := dtBoolean;
  end
  else if Func = PredFunc then
  begin
    ParseBuiltInFunction := CheckScalar(ParseExpression);
    EmitI('1 -');
  end
  else if Func = SuccFunc then
  begin
    ParseBuiltInFunction := CheckScalar(ParseExpression);
    EmitI('1 +');
  end
  else if (Func = HighFunc) or (Func = LowFunc) then
  begin
    Expect(toIdent);
    Sym := LookupGlobalOrFail(Scanner.StrValue);
    NextToken;
    if Sym^.Kind = scVar then
    begin
      MuteEmitter;
      Sym := ParseVariableAccess(Sym);
      UnmuteEmitter;
    end;
    if Sym^.Kind = scArrayType then Sym := Sym^.IndexType;
    if Sym^.Kind = scSetType then Sym := Sym^.DataType;
    if Sym = nil then Error('Eeek!');
    if Func = HighFunc then EmitLiteral(Sym^.High) else EmitLiteral(Sym^.Low);

    if Sym^.Kind = scSubrangeType then Sym := Sym^.DataType;

    ParseBuiltInFunction := Sym;
  end
  else if Func = ConcatFunc then
  begin
    TypeCheck(dtString, ParseExpression, tcExact);

    while Scanner.Token = toComma do
    begin
      NextToken;
      TypeCheck(dtString, ParseExpression, tcExact);
      EmitI(AllocIR4Temp(256) + ' pas_stradd');
    end;

    ParseBuiltInFunction := dtString;
  end
  else if (Func = FilePosFunc) or (Func = FileSizeFunc) or (Func = EolFunc) or (Func = EofFunc) or (Func = SeekEofFunc) or (Func = SeekEolnFunc) then
  begin
    T := ParseVariableRef;
    if T^.Kind <> scFileType then Error('File type expected');

    if (T = dtFile) or (T^.DataType = dtFile) then
      Sym := LookupBuiltInOrFail('Block' + Func^.Name)
    else if T = dtText then
      Sym := LookupBuiltInOrFail('Text' + Func^.Name)
    else
      Sym := LookupBuiltInOrFail('File' + Func^.Name);

    EmitCall(Sym);
    ParseBuiltInFunction := Sym^.DataType;
  end
  else
    Error('Cannot handle: ' + Func^.Name);

    Expect(toRParen); NextToken;
end;

(**
 * Parses a format specifier (used in Write, WriteLn and Str statements)
 * and puts the results on the stack.
 *)
function ParseFormat: Integer;
begin
  if Scanner.Token = toColon then
  begin
    NextToken;
    TypeCheck(dtInteger, ParseExpression, tcExpr);
    if Scanner.Token = toColon then
    begin
      NextToken;
      TypeCheck(dtInteger, ParseExpression, tcExpr);
      ParseFormat := 2;
    end
    else ParseFormat := 1;
  end
  else ParseFormat := 0;
end;

(**
 * Emits a console read for the given data type.
 *)
procedure EmitReadConsole(T: PSymbol);
begin
  while T^.Kind = scSubrangeType do
    T := T^.DataType;

  if (T = dtInteger) or (T = dtByte) then
  begin
    EmitI('pas_get_i');
    EmitStore(T);
  end
  else if T = dtChar then
  begin
    EmitI('pas_get_c');
    EmitStore(T);
  end
  else if T = dtReal then
  begin
    EmitI('pas_get_f');
    EmitStore(T);
  end
  else if T^.Kind = scEnumType then
  begin
    EmitI(T^.Tag + ' pas_get_e');
    EmitStore(T);
  end
  else if T^.Kind = scStringType then
    EmitI(IntToStr(T^.Value - 1) + ' pas_get_s')
  else Error('Unreadable type');
end;

(**
 * Parses a built-in procedure, which is basically every pre-defined procedure
 * that does not have a fixed syntax (variable parameters, for instance).
 *
 * TODO Split this into multiple procedures?
 *)
procedure ParseBuiltInProcedure(Proc: PSymbol; BreakTarget, ContTarget: String);
var
  Sym, T, TT, V, U, ExprType: PSymbol;
  F: Integer;
begin
  if Proc^.Kind <> scProc then
    Error('Not a built-in procedure: ' + Proc^.Name);

  if Proc = AssertProc then
  begin
    if Release then MuteEmitter;

    NextToken; Expect(toLParen); NextToken;

    TypeCheck(dtBoolean, ParseExpression, tcExact);

    EmitI(AddString(Source^.Name) + ' ' + IntToStr(Source^.Line) + ' pas_assert');

    Expect(toRParen); NextToken;

    if Release then UnmuteEmitter;
  end
  else if Proc = DebugProc then
  begin
    if Release then MuteEmitter;

    NextToken;

    if Scanner.Token = toLParen then
    begin
      NextToken;

      TypeCheck(dtBoolean, ParseExpression, tcExact);
      EmitI('drop');

      Expect(toRParen); NextToken;
    end;

    if Release then UnmuteEmitter;
  end
  else if Proc = BreakProc then
  begin
    if BreakTarget = '' then Error('Not in loop');
    EmitJump(BreakTarget);
    NextToken;
  end
  else if Proc = ContProc then
  begin
    if ContTarget = '' then Error('Not in loop');
    EmitJump(ContTarget);
    NextToken;
  end
  else if Proc = ExitProc then
  begin
    NextToken;
    if Scanner.Token = toLParen then
    begin
      (* Find the result variable (tagged 'RESULT') in the symbol table *)
      Sym := SymbolTable;
      while (Sym <> nil) and ((Sym^.Kind <> scVar) or (Sym^.Tag <> 'RESULT')) do
        Sym := Sym^.Prev;
      if Sym = nil then Error('Exit with value only allowed in functions');

      NextToken;
      EmitAddress(Sym);
      T := TypeCheck(Sym^.DataType, ParseExpression, tcAssign);
      EmitStore(T);
      Expect(toRParen);
      NextToken;
    end;
    EmitJump(ExitTarget);
  end
  else if Proc = HaltProc then
  begin
    NextToken;
    if Scanner.Token = toLParen then
    begin
      NextToken;
      TypeCheck(dtByte, ParseExpression, tcExpr);
      EmitI('pas_halt');
      Expect(toRParen);
      NextToken;
    end
    else
      EmitI('0 pas_halt');
  end
  else if (Proc = IncludeProc) or (Proc = ExcludeProc) then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    V := ParseVariableRef;

    if V^.Kind <> scSetType then Error('Set variable expected');

    Expect(toComma);
    NextToken;

    CheckElement(V^.DataType, CheckScalar(ParseExpression));

    Expect(toRParen);
    NextToken;

    if Proc = IncludeProc then
      EmitI('pas_set_incl drop')
    else
      EmitI('pas_set_excl drop');
  end
  else if Proc = InsertProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    (* TypeCheck also accepts (and promotes) single characters. *)
    TypeCheck(dtString, ParseExpression, tcAssign);

    Expect(toComma);
    NextToken;

    V := ParseVariableRef;
    if V^.Kind <> scStringType then Error('String variable expected');

    Expect(toComma);
    NextToken;

    TypeCheck(dtInteger, ParseExpression, tcAssign);

    Expect(toRParen);
    NextToken;

    EmitI(IntToStr(V^.Value - 1) + ' pas_str_insert');
  end
  else if Proc = DeleteProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    V := ParseVariableRef;
    if V^.Kind <> scStringType then Error('String variable expected');

    Expect(toComma);
    NextToken;

    TypeCheck(dtInteger, ParseExpression, tcAssign);

    Expect(toComma);
    NextToken;

    TypeCheck(dtInteger, ParseExpression, tcAssign);

    Expect(toRParen);
    NextToken;

    EmitI('pas_str_delete');
  end
  else if (Proc = ReadProc) or (Proc = ReadLnProc) then
  begin
    NextToken;

    if Scanner.Token = toLParen then
    begin
      NextToken;
      T := ParseVariableRef;

      if T = dtText then
      begin
        EmitI('-> __cur_file');

        while Scanner.Token = toComma do
        begin
          NextToken;
          EmitI('__cur_file');

          T := ParseVariableRef;

          if T^.Kind = scStringType then
          begin
            EmitLiteral(T^.Value - 1);  (* Declared capacity of S *)
            EmitCall(LookupBuiltInOrFail('TextReadStr'));
          end
          else if T = dtChar then
            EmitCall(LookupBuiltInOrFail('TextReadChar'))
          else if T = dtInteger then
            EmitCall(LookupBuiltInOrFail('TextReadInt'))
          else if T = dtReal then
            EmitCall(LookupBuiltInOrFail('TextReadFloat'))
          else if T^.Kind = scEnumType then
          begin
            EmitI(T^.Tag);
            EmitCall(LookupBuiltInOrFail('TextReadEnum'));
          end
          else
            Error('Unreadable type');

          (* A malformed number is reported through LastError like any other
             I/O error, so it needs the same {$i+} check every other file
             operation gets. This also picks up genuine read errors, which
             used to sit in LastError unnoticed until the next operation. *)
          if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
        end;

        if (Proc = ReadLnProc) and (T^.Kind <> scStringType) then
        begin
          EmitI('__cur_file');
          EmitCall(LookupBuiltInOrFail('TextSkipToEoln'));
        end;
      end
      else if T^.Kind = scFileType then
      begin
        EmitI('-> __cur_file');

        while Scanner.Token = toComma do
        begin
          NextToken;
          EmitI('__cur_file');

          TT := ParseVariableRef;
          if TT <> T^.DataType then Error('Type mismatch');

          EmitCall(LookupBuiltInOrFail('FileRead'));
        end;
      end
      else
      begin
        EmitI('pas_getline');
        EmitReadConsole(T);
        if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
        while Scanner.Token = toComma do
        begin
          NextToken;
          T := ParseVariableRef;
          EmitReadConsole(T);
          if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
        end;
      end;

      Expect(toRParen);
      NextToken;
    end
    else
      EmitI('pas_getline');
  end
  else if (Proc = WriteProc) or (Proc = WriteLnProc) then
  begin
    NextToken;

    if Scanner.Token = toLParen then
    begin
      NextToken;

      T := ParseExpression;

      if T = dtText then
      begin
        EmitI('-> __cur_file');

        while Scanner.Token = toComma do
        begin
          NextToken;

          T := ParseExpression;
          F := ParseFormat;

          EmitI('__text_buf');

          V := dtString;

          case F of
            0: EmitStr(T, V);
            1: EmitStr1(T, V); (* Broken? *)
            2: EmitStr2(T, V); (* Broken? *)
          end;

          EmitI('__cur_file __text_buf');
          EmitCall(LookupBuiltInOrFail('TextWriteStr'));
        end;

        if Proc = WriteLnProc then
        begin
          EmitI('__cur_file');
          EmitCall(LookupBuiltInOrFail('TextWriteEoln'));
        end;
      end
      else if T^.Kind = scFileType then
      begin
        EmitI('-> __cur_file');

        while Scanner.Token = toComma do
        begin
          NextToken;
          EmitI('__cur_file');

          TT := ParseVariableRef;
          if TT <> T^.DataType then Error('Type mismatch');

          EmitCall(LookupBuiltInOrFail('FileWrite'));
        end;

        if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
      end
      else
      begin
        case ParseFormat of
          0: EmitWrite(T);
          1: EmitWrite1(T);
          2: EmitWrite2(T);
        end;

        while Scanner.Token = toComma do
        begin
          NextToken;
          T := ParseExpression;
          case ParseFormat of
            0: EmitWrite(T);
            1: EmitWrite1(T);
            2: EmitWrite2(T);
          end;
        end;

        if Proc = WriteLnProc then EmitI('cr');
      end;

      Expect(toRParen);
      NextToken;
    end
    else if Proc = WriteLnProc then
      EmitI('cr');
  end
  else if Proc = IncProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;
    V := ParseVariableRef;
    if V^.Kind = scPointerType then
    begin
      if Scanner.Token = toComma then
      begin
        NextToken;
        TypeCheck(dtInteger, ParseExpression, tcExpr);
      end
      else EmitLiteral(1);
      if V <> dtPointer then
        EmitI(IR4TupleExprStr(V^.DataType^.IrC, V^.DataType^.IrI, V^.DataType^.IrA, V^.DataType^.IrF) + ' *');
      EmitI('pas_inc_a');
    end
    else if IsOrdinal(V) then
    begin
      if Scanner.Token = toComma then
      begin
        NextToken;
        TypeCheck(dtInteger, ParseExpression, tcExpr);
        if IsIR4IntType(V) then EmitI('pas_inc_i') else EmitI('pas_inc_b');
      end
      else EmitInc(V);
    end
    else Error('Ordinal or pointer type expected');
    Expect(toRParen);
    NextToken;
  end
  else if Proc = DecProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;
    V := ParseVariableRef;
    if V^.Kind = scPointerType then
    begin
      if Scanner.Token = toComma then
      begin
        NextToken;
        TypeCheck(dtInteger, ParseExpression, tcExpr);
      end
      else EmitLiteral(1);
      if V <> dtPointer then
        EmitI(IR4TupleExprStr(V^.DataType^.IrC, V^.DataType^.IrI, V^.DataType^.IrA, V^.DataType^.IrF) + ' *');
      EmitI('0 swap - pas_inc_a');
    end
    else if IsOrdinal(V) then
    begin
      if Scanner.Token = toComma then
      begin
        NextToken;
        TypeCheck(dtInteger, ParseExpression, tcExpr);
        EmitI('0 swap -');
        if IsIR4IntType(V) then EmitI('pas_inc_i') else EmitI('pas_inc_b');
      end
      else EmitDec(V);
    end
    else Error('Ordinal or pointer type expected');
    Expect(toRParen);
    NextToken;
  end
  else if Proc = StrProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    T := ParseExpression;
    F := ParseFormat;

    Expect(toComma);
    NextToken;

    V := ParseVariableRef;

    case F of
      0: EmitStr(T, V);
      1: EmitStr1(T, V);
      2: EmitStr2(T, V);
    end;

    Expect(toRParen);
    NextToken;
  end
  else if Proc = ValProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    ExprType := ParseExpression;
    if ExprType^.Kind <> scStringType then Error('String expected');

    Expect(toComma);
    NextToken;

    T := ParseVariableRef;
    if (T <> dtInteger) and (T <> dtReal) and (T^.Kind <> scEnumType) then Error('Numeric variable expected');

    if Scanner.Token = toComma then
    begin
      NextToken;

      U := ParseVariableRef;
      if U <> dtInteger then Error('Integer variable expected');
    end
    else
    begin
      EmitI(AllocIR4TempTuple(0, 1, 0, 0));
      U := nil;
    end;

    if T = dtInteger then
      EmitI('pas_val_int')
    else if T^.Kind = scEnumType then
      EmitI(T^.Tag + ' pas_val_enum')
    else
      EmitI('pas_val_float');

    Expect(toRParen);
    NextToken;
  end
  else if Proc = NewProc then
  begin
    NextToken; Expect(toLParen); NextToken;

    Expect(toIdent);
    Sym := LookupGlobalOrFail(Scanner.StrValue);
    NextToken;
    T := ParseVariableAccess(Sym);

    EmitI(IR4TupleExprStr(T^.DataType^.IrC, T^.DataType^.IrI, T^.DataType^.IrA, T^.DataType^.IrF));
    EmitI('heapalloc swap a!');

    Expect(toRParen); NextToken;
  end
  else if Proc = DisposeProc then
  begin
    NextToken; Expect(toLParen); NextToken;

    T := ParseExpression;
    if T^.Kind <> scPointerType then Error('Pointer type needed');

    EmitI('heapfree');

    Expect(toRParen); NextToken;
  end
  else if Proc = FillProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;

    T := ParseVariableRef;

    Expect(toComma);
    NextToken;

    T := ParseExpression;
    if OrdinalBase(T) <> dtInteger then Error('Integer expr expected');

    Expect(toComma);
    NextToken;

    CheckScalar(ParseExpression);

    Expect(toRParen);
    NextToken;

    EmitI('memfill');
  end
  else if Proc = AssignProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;
    T := ParseVariableRef;
    if T^.Kind <> scFileType then Error('File type expected');
    Expect(toComma);
    NextToken;
    ExprType := ParseExpression;
    if ExprType^.Kind <> scStringType then Error('String expected');
    Expect(toRParen);
    NextToken;

    if (T = dtFile) or (T^.DataType = dtFile) then
      EmitCall(LookupBuiltInOrFail('BlockAssign'))
    else if T = dtText then
      EmitCall(LookupBuiltInOrFail('TextAssign'))
    else
    begin
      EmitI(IR4TupleExprStr(T^.DataType^.IrC, T^.DataType^.IrI, T^.DataType^.IrA, T^.DataType^.IrF));
      EmitCall(LookupBuiltInOrFail('FileAssign'));
    end;
  end
  else if  (Proc = EraseProc) or  (Proc = RenameProc) or (Proc = ResetProc) or (Proc = RewriteProc) or (Proc = AppendProc) or (Proc = CloseProc) or (Proc = FlushProc) then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;
    T := ParseVariableRef;
    if T^.Kind <> scFileType then Error('File type expected');

    { Rename takes a second parameter (new filename) }
    if Proc = RenameProc then
    begin
      Expect(toComma);
      NextToken;
      ExprType := ParseExpression;
    if ExprType^.Kind <> scStringType then Error('String expected');
    end
    else if ((Proc = ResetProc) or (Proc = RewriteProc)) and ((T = dtFile) or (T^.DataType = dtFile)) then
    begin
      if Scanner.Token = toComma then
      begin
        NextToken;
        if OrdinalBase(ParseExpression) <> dtInteger then Error('Integer expected');
      end
      else
        EmitI('128');
    end;

    Expect(toRParen);
    NextToken;

    if (T = dtFile) or (T^.DataType = dtFile) or (Proc = EraseProc) or (Proc = RenameProc) then
      Sym := LookupBuiltInOrFail('Block' + Proc^.Name)
    else if T = dtText then
      Sym := LookupBuiltInOrFail('Text' + Proc^.Name)
    else
      Sym := LookupBuiltInOrFail('File' + Proc^.Name);

    EmitCall(Sym);

    if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
  end
  else if Proc = SeekProc then
  begin
    NextToken;
    Expect(toLParen);
    NextToken;
    T := ParseVariableRef;
    if T^.Kind <> scFileType then Error('File type expected');

    Expect(toComma);
    NextToken;

    if OrdinalBase(ParseExpression) <> dtInteger then Error('Integer expected');

    Expect(toRParen);
    NextToken;

    if (T = dtFile) or (T^.DataType = dtFile) then
      EmitCall(LookupBuiltInOrFail('BlockSeek'))
    else if T <> dtText then
      EmitCall(LookupBuiltInOrFail('FileSeek'))
    else
      Error('Not allowed.');

    if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));
  end
  else if (Proc = BlockReadProc) or (Proc = BlockWriteProc) then
  begin
    NextToken;

    Expect(toLParen);
    NextToken;

    T := ParseVariableRef;
    if T^.Kind <> scFileType then Error('File type expected');

    Expect(toComma);
    NextToken;

    ParseVariableRef; (* Src or dest *)

    Expect(toComma);
    NextToken;

    TypeCheck(dtInteger, ParseExpression, tcExpr);

    if Scanner.Token = toComma then
    begin
      NextToken;
      ParseVariableRef; (* Actual bytes, check for integer!? *)
    end
    else
      EmitI('0 i>a');

    Expect(toRParen);
    NextToken;

    EmitCall(LookupBuiltInOrFail('Block' + Proc^.Name));
    if IOMode then EmitCall(LookupBuiltInOrFail('BDosThrow'));

    // By Name umlenken auf Implementierung.
  end
  else
    Error('Cannot handle: ' + Proc^.Name);
end;

(**
 * Parses a scalar constant, storing the Value, and returns its type. Performs
 * various checks and throws errors accordingly.
 *)
function ParseScalar(var Value: Integer): PSymbol;
var
  AType, CoSym: PSymbol;
  Neg: Boolean;
begin
  if Scanner.Token = toSub then
  begin
    Neg := True;
    NextToken;
  end
  else Neg := False;

  if Scanner.Token = toNumber then
  begin
    AType := dtInteger;
    Value := Scanner.NumValue;
  end
  else if (Scanner.Token = toString) and not Neg then
  begin
    if Length(Scanner.StrValue) <> 1 then Error('Invalid type');

    AType := dtChar;
    Value := Ord(Scanner.StrValue[1]);
  end
  else if (Scanner.Token = toCaret) and not Neg then
  begin
    AType := dtChar;
    Value := GetCtrlChar;
  end
  else if Scanner.Token = toIdent then
  begin
    CoSym := LookupGlobalOrFail(Scanner.StrValue);
    AType := CoSym^.DataType;
    Value := CoSym^.Value;

    if (CoSym^.Kind <> scConst) then
      Error('Not a constant');
    CheckScalar(AType);
  end
  else Error('Invalid type');

  if Neg then
  begin
    if AType <> dtInteger then Error('Integer expected');
    Value := -Value;
  end;

  NextToken;

  ParseScalar := AType;
end;

(**
 * Parses a scalar range, storing the First and Last values, and returns its
 * type. Performs various checks and throws errors accordingly. The range may
 * be "degenerate" (i.e. just one value, not dots), in which case First and
 * Last are equal.
 *)
function ParseScalarRange(var First, Last: Integer): PSymbol;
var
  AType: PSymbol;
begin
  AType := ParseScalar(First);

  if Scanner.Token = toRange then
  begin
    NextToken;
    if ParseScalar(Last) <> AType then Error('Incompatible types');
  end
  else Last := First;

  ParseScalarRange := AType;
end;

(**
 * Parses a set constant and generates a 32 byte block containing the proper
 * bits.
 *
 * TODO Can we keep set constants in a table similar to strings, ensure
 * uniqueness and write them later in one go?
 *)
function ParseSetConstant: PSymbol;
var
  I, First, Last: Integer;
  Sym, AType, BType: PSymbol;
  S: string;
  Bits: array[0..31] of Byte;
begin
  for I := 0 to 31 do Bits[I] := 0;

  AType := nil;
  while Scanner.Token <> toRBrack do
  begin
    BType := CheckElement(AType, ParseScalarRange(First, Last));
    if (First < 0) or (First > 255) or (Last < 0) or (Last > 255) then
      Error('Value out of range');
    if (Last < First) then
      Error('Invalid range');

    AType := BType;

    for I := First to Last do
    begin
      Bits[I shr 3] := Bits[I shr 3] or (1 shl (I and 7));
    end;
    if Scanner.Token = toComma then NextToken;
  end;

  S := '0x' + IntToHex(Bits[0], 2) + ' :i8';
  for I := 1 to 31 do S := S + ' 0x' + IntToHex(Bits[I], 2) + ' :i8';
  EmitI(S);

  Sym := CreateSymbol(scSetType, '');
  Sym^.Value := 32;
  Sym^.DataType := AType;

  ParseSetConstant := Sym;
end;

(**
 * Parses a set expression and generates a 32 byte block containing the proper
 * bits on the stack.
 *
 * TODO Can we detect the constant case and generate the bits at compile-time?
 *)
function ParseSet: PSymbol;
var
  Sym, AType, BType: PSymbol;
begin
  EmitI(AllocIR4Temp(32) + ' pas_set_empty');

  AType := nil;
  while Scanner.Token <> toRBrack do
  begin
    BType := CheckElement(AType, CheckScalar(ParseExpression));
    //if (First < 0) or (First > 255) or (Last < 0) or (Last > 255) then
    //  Error('Value out of range');
    //if (Last < First) then
    //  Error('Invalid range');

    if Scanner.Token = toRange then
    begin
      NextToken;
      CheckElement(BType, CheckScalar(ParseExpression));

      EmitI('pas_set_range');
    end
    else
    begin
      EmitI('pas_set_incl');
    end;

    AType := BType;

    if Scanner.Token = toComma then NextToken;
  end;

  Sym := CreateSymbol(scSetType, '');
  Sym^.Value := 32;
  Sym^.DataType := AType;

  ParseSet := Sym;
end;

(**
 * Parses a factor, which is the smallest building block of an expression. A
 * factor can be a constant, a variable, a function call or a literal number,
 * string, set or pointer. We also handle unary operators on this level.
 *)
function ParseFactor: PSymbol;
var
  Sym: PSymbol; T: PSymbol;
  Op: TToken;
  Tag, S: String;
begin
  if Scanner.Token = toIdent then
  begin
    Sym := LookupGlobalOrFail(Scanner.StrValue);

    (* A function's return variable shares its name; skip past it to find the
       actual function symbol for recursive calls (including forward funcs). *)
    while (Sym <> nil) and (Sym^.Kind = scVar) and (Sym^.Tag = 'RESULT') do
      Sym := Lookup(Sym^.Name, Sym^.Prev, nil);

    if (Sym^.Kind = scVar) and (Sym^.IsMagic) then
    begin
      NextToken;
      T := ParseBuiltInVarRead(Sym);
    end
    else if Sym^.Kind = scVar then
    begin
      NextToken;
      T := ParseVariableAccess(Sym);

      // if not (T^.Kind in [scType, scEnumType]) then Error('" ' + Sym^.Name + '" is not a simple type.');
      (* File types are never communicated by value, only by reference. *)
      if (T^.Kind <> scFileType) and (T <> dtText) then EmitLoad(T);
    end
    else if Sym^.Kind = scConst then
    begin
      T := Sym^.DataType;
      if T = dtReal then
        EmitI(Sym^.Tag)
      else
      begin
        if Sym^.Tag <> '' then
          EmitI(Sym^.Tag)
        else
          EmitLiteral(Sym^.Value);
      end;
      NextToken;
    end
    else if (Sym^.Kind = scFunc) and (Sym^.IsMagic) then
    begin
      T := ParseBuiltInFunction(Sym);
    end
    else if Sym^.Kind = scFunc then
    begin
      T := Sym^.DataType; (* Type = Type(func) *)
      NextToken;
      ParseArguments(Sym);
      if T^.Kind in [scStringType, scSetType, scArrayType, scRecordType] then
        EmitI(AllocIR4TempTuple(T^.IrC, T^.IrI, T^.IrA, T^.IrF));
      EmitCall(Sym);
    end
    else if Sym^.Kind in [scType,scEnumType] then
    begin
      NextToken;
      Expect(toLParen);
      NextToken;
      CheckScalar(ParseExpression);
      Expect(toRParen);
      NextToken;

      T := Sym;
    end
    else
    begin
      Error('"' + Scanner.StrValue + '" cannot be used in expressions.');
    end;
  end
  else if Scanner.Token in [toString, toCaret] then
  begin
    S := ParseStringLiteral;
    if Length(S) = 1 then
    begin
      T := dtChar;
      EmitLiteral(Ord(S[1]));
    end
    else
    begin
      T := dtString;
      Tag := AddString(S);
      EmitI(Tag);
    end;
  end
  else if Scanner.Token = toFloat then
  begin
    T := dtReal;
    EmitI(Scanner.StrValue);
    NextToken;
  end
  else if Scanner.Token = toNumber then
  begin
    T := dtInteger;
    EmitLiteral(Scanner.NumValue);
    NextToken;
  end
  else if Scanner.Token = toNil then
  begin
    T := dtPointer;
    EmitI('0 i>a');
    NextToken;
  end
  (* true false + String constants *)
  else if Scanner.Token = toLParen then
  begin
    NextToken; T := ParseExpression; Expect(toRParen); NextToken;
  end
  else if Scanner.Token = toLBrack then
  begin
    NextToken;

    T := ParseSet;

    Expect(toRBrack);
    NextToken;
  end
  else if Scanner.Token in [toAdd, toSub, toNot] then
  begin
    Op := Scanner.Token;
    NextToken;
    T := ParseFactor;

    (* Like the binary operators, compute anything integral in 16 bit. Turbo
       Pascal 3 does the same: not B for a Byte B = 1 yields -2, not 254. *)
    if T^.Kind = scSubrangeType then T := T^.DataType;
    if T = dtByte then T := dtInteger;

    if T = dtChar then Error('not only applicable to Integer, Byte, Real or Boolean');
    case Op of
      toAdd: begin (* Nop *) end;
      toSub: EmitNeg(T);
      toNot: EmitUnOp(toNot, T);
    end;
  end
  else Error('Factor expected');

  ParseFactor := T;
end;

(**
 * Parses a term, which can be a factor or any number of factors connected by
 * multiplicative, dividing or bitshifting operators.
 *)
function ParseTerm: PSymbol;
var
  Op: TToken;
  T: PSymbol;
begin
  T := ParseFactor;

  if T^.Kind = scSubrangeType then T := T^.DataType;

  if (T = dtInteger) or (T = dtByte) then
    while Scanner.Token in [toMul, toDiv, toDivKW, toMod, toAnd, toShl, toShr] do
    begin
      Op := Scanner.Token;
      NextToken;
      if Op = toDiv then T := TypeCheck(dtReal, T, tcExpr);
      T := TypeCheck(T, ParseFactor, tcExpr);
      if T = dtReal then EmitFloatOp(Op) else EmitBinOp(Op, T);
    end
  else if T = dtBoolean then
    while Scanner.Token = toAnd do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseFactor, tcExact);
      EmitBinOp(Op, T);
    end
  else if T = dtReal then
    while Scanner.Token in [toMul, toDiv, toMod] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseFactor, tcExpr);
      EmitFloatOp(Op);
    end
  else if T^.Kind = scSetType then
    while Scanner.Token in [toMul] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseFactor, tcExpr);
      EmitSetOp(Op);
    end;

  ParseTerm := T;
end;

(**
 * Parses a simple expression, which can be a term or any number of terms
 * connected by additive or subtrative operators.
 *)
function ParseSimpleExpression: PSymbol;
var
  Op: TToken;
  T: PSymbol;
begin
  T := ParseTerm;

  if T^.Kind = scSubrangeType then T := T^.DataType;

  if (T = dtInteger) or (T = dtByte) then
    while Scanner.Token in [toAdd, toSub, toOr, toXor] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseTerm, tcExpr);
      if T = dtReal then EmitFloatOp(Op) else EmitBinOp(Op, T);
    end
  else if T = dtBoolean then
    while Scanner.Token in [toOr, toXor] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseTerm, tcExact);
      EmitBinOp(Op, T);
    end
  else if (T = dtChar) or (T^.Kind = scStringType) then
  begin
    while Scanner.Token = toAdd do
    begin
      T := TypeCheck(dtString, T, tcExact);
      NextToken;
      T := TypeCheck(dtString, ParseTerm, tcExact);
      EmitI(AllocIR4Temp(256) + ' pas_stradd');
    end
  end
  else if T = dtReal then
    while Scanner.Token in [toAdd, toSub] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseTerm, tcExpr);
      EmitFloatOp(Op);
    end
  else if T^.Kind = scSetType then
    while Scanner.Token in [toAdd, toSub] do
    begin
      Op := Scanner.Token;
      NextToken;
      T := TypeCheck(T, ParseTerm, tcExpr);
      EmitSetOp(Op);
    end;


  (* WriteLn('Type of SimpleExpression is ', T); *)

  ParseSimpleExpression := T;
end;

(**
 * Parses an expression, which can be one simple expression or two simple
 * expressions connected by a relational operator.
 *)
function ParseExpression;
var
  Op: TToken;
  T, U: PSymbol;
begin
  T := ParseSimpleExpression;
  if Scanner.Token = toIn then
  begin
    CheckScalar(T);

    NextToken;
    U := ParseExpression;
    if U^.Kind <> scSetType then Error('Set needed');
    CheckElement(U^.DataType, T);

    EmitSetOp(toIn);

    T := dtBoolean;
  end
  else if (T^.Kind = scSetType) and (Scanner.Token in [toEq, toNeq, toLeq, toGeq]) then
  begin
    Op := Scanner.Token;
    //WriteLn(Op);
    NextToken;

    U := ParseExpression;
    if U^.Kind <> scSetType then Error('Set needed');
    CheckElement(T^.DataType, U^.DataType);

    EmitSetOp(Op);

    T := dtBoolean;
  end
  else if (Scanner.Token >= toEq) and (Scanner.Token <= toGeq) then
  begin
    Op := Scanner.Token;
    NextToken;
    (*
      * ii ib bi bb zz cc
      *)
    T := TypeCheck(T, ParseSimpleExpression, tcExpr);
    if T^.Kind = scStringType then
      EmitStrOp(Op)
    else if T = dtReal then
      EmitFloatOp(Op)
    else if T^.Kind = scPointerType then
      EmitPtrOp(Op)
    else
      EmitRelOp(Op);
    T := dtBoolean;                       // We know it will be Boolean.
  end;

  (* WriteLn('Type of Expression is ', T); *)

  ParseExpression := T;
end;

(**
 * Parses an assignment.
 *)
procedure ParseAssignment(Sym: PSymbol);
var
  T: PSymbol;
begin
  if Sym^.Kind <> scVar then Error('"' + Scanner.StrValue + '" not a var.');
  NextToken;

  T := ParseVariableAccess(Sym);

  Expect(toBecomes);
  NextToken;

  (* Check against the target type, but store with it, not with whatever the
     check returns: TypeCheck reduces a subrange to its base type, and storing
     with that would write two bytes into a one byte variable. *)
  TypeCheck(T, ParseExpression, tcAssign);
  EmitStore(T);
end;

procedure ParseStatement(ContTarget, BreakTarget: String); forward;

(**
 * Parses a single "with" variable, which must be of a record type. Creates
 * "proxy" variables for all fields contained in the record.
 *
 * TODO Should we simply create a scope instead of this "stunt" using anonymous
 * variables?
 *)
procedure ParseWithVar;
var
  Sym, Field, FieldRef, DataType: PSymbol;
  Slot: TIR4Tuple;
begin
  Expect(toIdent);
  Sym := LookupGlobalOrFail(Scanner.StrValue);
  if Sym^.Kind <> scVar then Error('Variable expected');
  NextToken;

  Slot := IR4Frame;
  Inc(IR4Frame.A);
  if IR4Frame.A > IR4MaxFrame.A then IR4MaxFrame.A := IR4Frame.A;
  DataType := ParseVariableAccess(Sym);
  if DataType^.Kind <> scRecordType then Error('Record type expected');
  if (Slot.C = 0) and (Slot.I = 0) and (Slot.A = 0) and (Slot.F = 0) then
    EmitI('_locals a!')
  else
    EmitI('_locals ' + IR4TupleExprStr(Slot.C, Slot.I, Slot.A, Slot.F) + ' a+ a!');
  Field := DataType^.DataType;
  while Field <> nil do
  begin
    FieldRef := CreateSymbol(scVar, '');
    FieldRef^.Name := Field^.Name;
    FieldRef^.DataType := Field^.DataType;
    FieldRef^.IrC := Slot.C;
    FieldRef^.IrI := Slot.I;
    FieldRef^.IrA := Slot.A;
    FieldRef^.IrF := Slot.F;
    FieldRef^.WithC := Field^.IrC;
    FieldRef^.WithI := Field^.IrI;
    FieldRef^.WithA := Field^.IrA;
    FieldRef^.WithF := Field^.IrF;
    FieldRef^.IsRef := True;
    FieldRef^.Level := Level;
    Field := Field^.Prev;
  end;
end;

(**
 * Parses a "with" statement, "opening" the scopes of a single record variable
 * or a list of such variables and making the contained fields directly
 * accessible as variables.
 *)
procedure ParseWith(ContTarget, BreakTarget: String);
var
  OldSymbols: PSymbol;
  OldBase, SavedFrame: TIR4Tuple;
begin
  OldSymbols := SymbolTable;
  SavedFrame := IR4Frame;
  OldBase := IR4BaseFrame;

  ParseWithVar;

  while Scanner.Token = toComma do
  begin
    NextToken;
    ParseWithVar;
  end;

  Expect(toDo);
  NextToken;

  IR4BaseFrame := IR4Frame;

  ParseStatement(ContTarget, BreakTarget);

  IR4BaseFrame := OldBase;
  IR4Frame := SavedFrame;

  while SymbolTable <> OldSymbols do
    FreeAndNilSymbol(SymbolTable);
end;

procedure ParseCaseLabel(T: PSymbol; OfTarget: String);
var
  Low, High: Integer;
begin
  CheckElement(T, ParseScalarRange(Low, High));

  if High = Low then
    EmitI(IR4CaseTemp + ' @ ' + IntToStr(High) + ' = 0 = jz ' + OfTarget)
  else
    EmitI(IR4CaseTemp + ' @ ' + IntToStr(Low) + ' >= ' +
          IR4CaseTemp + ' @ ' + IntToStr(High) + ' <= and 0 = jz ' + OfTarget);
end;

procedure ParseStatementList(ContTarget, BreakTarget: String); forward;

procedure ParseCaseStatement(ContTarget, BreakTarget: String);
var
  T: PSymbol;
  OfTarget, NextTest, EndTarget, SavedCase: String;
  OldBase, SavedFrame: TIR4Tuple;
begin
  EndTarget := GetLabel('end');

  NextToken;
  T := CheckScalar(ParseExpression);

  SavedFrame := IR4Frame;
  OldBase := IR4BaseFrame;
  SavedCase := IR4CaseTemp;
  IR4CaseTemp := AllocIR4TempTuple(0, 1, 0, 0);
  IR4BaseFrame := IR4Frame;
  EmitI(IR4CaseTemp + ' !');

  Expect(toOf);
  NextToken;

  while Scanner.Token in [toSub, toIdent, toNumber, toString, toCaret] do
  begin
    OfTarget := GetLabel('case');
    NextTest := GetLabel('test');

    ParseCaseLabel(T, OfTarget);
    while Scanner.Token = toComma do
    begin
      NextToken;
      ParseCaseLabel(T, OfTarget);
    end;

    Expect(toColon);
    NextToken;

    EmitJump(NextTest);

    Emit(OfTarget, '', '');

    ParseStatement(ContTarget, BreakTarget);
    EmitJump(EndTarget);
    Emit(NextTest, '', '');

    if Scanner.Token <> toSemicolon then Break;
    NextToken;
  end;

  if Scanner.Token = toElse then
  begin
    NextToken;
    ParseStatementList(ContTarget, BreakTarget);
  end;

  Emit(EndTarget, '', '');

  IR4CaseTemp := SavedCase;
  IR4BaseFrame := OldBase;
  IR4Frame := SavedFrame;

  Expect(toEnd);
  NextToken;
end;

(**
 * Parses a statement, which can be an atomic statement like a procedure call,
 * an assignment, a label or a piece of inline assembly, or a compound statement
 * like if/while/repeat/for or a begin..end block.
 *)
procedure ParseStatement;
var
  Sym: PSymbol;
  Tag, Tag2, Tag3, Tag4: String;
  StartTmp, CntTmp: String;
  OldBase, SavedFrame: TIR4Tuple;
  Delta: Integer;
  T: PSymbol;
begin

  if Scanner.Token = toNumber then
  begin
    Sym := LookupGlobalOrFail(IntToStr(Scanner.NumValue));

    if Sym^.Kind = scLabel then
    begin
      NextToken;
      Expect(toColon);
      NextToken;
      Emit(Sym^.Tag, '', '');
    end;
  end
  else if Scanner.Token = toIdent then
  begin
    Sym := LookupGlobalOrFail(Scanner.StrValue);

    if Sym^.Kind = scLabel then
    begin
      NextToken;
      Expect(toColon);
      NextToken;
      Emit(Sym^.Tag, '', '');
    end;
  end;

  if Scanner.Token = toIdent then
  begin
    Sym := LookupGlobalOrFail(Scanner.StrValue);

    if (Sym^.Kind = scProc) and (Sym^.IsMagic) then
    begin
      ParseBuiltInProcedure(Sym, BreakTarget, ContTarget);
    end
    else if Sym^.Kind = scProc then
    begin
      NextToken;
      if Scanner.Token = toBecomes then Error('"' + Sym^.Name + '" not a var.');

      ParseArguments(Sym);

      EmitCall(Sym);
    end
    else if (Sym^.Kind = scFunc) and (Sym^.IsMagic) then
    begin
      T := ParseBuiltInFunction(Sym);
      EmitI('drop');
    end
    else if Sym^.Kind = scFunc then
    begin
      T := Sym^.DataType;
      NextToken;
      ParseArguments(Sym);
      if T^.Kind in [scStringType, scSetType, scArrayType, scRecordType] then
        EmitI(AllocIR4TempTuple(T^.IrC, T^.IrI, T^.IrA, T^.IrF));
      EmitCall(Sym);
      EmitI('drop');
    end
    else if (Sym^.Kind = scVar) and (Sym^.IsMagic) then
    begin
      NextToken;
      ParseBuiltInVarWrite(Sym);
    end
    else
    begin
      ParseAssignment(Sym);
    end;
  end
  else if Scanner.Token = toBegin then
  begin
    NextToken; ParseStatement(ContTarget, BreakTarget);
    while Scanner.Token = toSemicolon do
    begin
      NextToken;
      ParseStatement(ContTarget, BreakTarget);
    end;
    Expect(toEnd); NextToken;
  end
  else if Scanner.Token = toIf then
  begin
    NextToken; TypeCheck(dtBoolean, ParseExpression, tcExact); Expect(toThen); NextToken;

    Tag := GetLabel('false');

    EmitJumpIf(False, Tag);

    ParseStatement(ContTarget, BreakTarget);

    if Scanner.Token = toElse then
    begin
      Tag2 := GetLabel('endif');
      EmitJump(Tag2);

      Emit(Tag, '', '');

      NextToken;
      ParseStatement(ContTarget, BreakTarget);

      Emit(Tag2, '', '');
    end
    else
    begin
      Emit(Tag, '', '');
    end;

  end
  else if Scanner.Token = toWhile then
  begin
    (* Break would jump to false *)

    Tag := GetLabel('while');
    Tag2 := GetLabel('false');

    Emit(Tag, '', '');

    NextToken; TypeCheck(dtBoolean, ParseExpression, tcExact); Expect(toDo); NextToken;

    EmitJumpIf(False, Tag2);

    ParseStatement(Tag, Tag2);

    EmitJump(Tag);         (* TODO Move this elsewhere. *)
    Emit(Tag2, '', '');
  end
  else if Scanner.Token = toRepeat then
  begin
    Tag := GetLabel('repeat');
    Tag2 := GetLabel('break');

    (* break would jump to label after until *)

    Emit(Tag, '', '');

    NextToken; ParseStatement(Tag, Tag2);
    while Scanner.Token = toSemicolon do
    begin
      NextToken;
      ParseStatement(Tag, Tag2);
    end;
    Expect(toUntil); NextToken;

    TypeCheck(dtBoolean, ParseExpression, tcExact);

    EmitJumpIf(False, Tag);
    Emit(Tag2, '', '');
  end
  else if Scanner.Token = toFor then
  begin
    (* break would jump to cleanup after for *)

    NextToken;
    Expect(toIdent);

    Sym := LookupGlobalOrFail(Scanner.StrValue);
    if Sym^.Kind <> scVar then Error('Identifier "' + Scanner.StrValue + '" not a var.');

    (* Like Turbo Pascal 3, we compute the number of iterations up front, in
       16 bit and from the untruncated start value. The loop then counts down
       to zero, while the loop variable follows along and may wrap around if
       it is only a byte wide. *)

    EmitAddress(Sym);
    NextToken; Expect(toBecomes); NextToken; TypeCheck(Sym^.DataType, ParseExpression, tcAssign);

    SavedFrame := IR4Frame;
    OldBase := IR4BaseFrame;
    StartTmp := AllocIR4TempTuple(0, 1, 0, 0);
    CntTmp := AllocIR4TempTuple(0, 1, 0, 0);
    IR4BaseFrame := IR4Frame;
    EmitI('dup ' + StartTmp + ' !');
    EmitStore(Sym^.DataType);
    if Scanner.Token = toTo then Delta := 1
    else if Scanner.Token = toDownTo then Delta := -1
    else Error('"to" or "downto" expected.');
    NextToken; TypeCheck(Sym^.DataType, ParseExpression, tcAssign); Expect(toDo);
    EmitI(CntTmp + ' !');
    Tag := GetLabel('forloop');
    Tag3 := GetLabel('forbreak');
    Tag4 := GetLabel('fornext');
    EmitI(StartTmp + ' @ ' + CntTmp + ' @');
    if Delta = 1 then EmitI('<=') else EmitI('>=');
    EmitJumpIf(False, Tag3);
    if Delta = 1 then
      EmitI(CntTmp + ' @ ' + StartTmp + ' @ - ' + CntTmp + ' !')
    else
      EmitI(StartTmp + ' @ ' + CntTmp + ' @ - ' + CntTmp + ' !');
    Emit(Tag, '', '');
    NextToken;
    ParseStatement(Tag4, Tag3);
    Emit(Tag4, '', '');
    EmitI(CntTmp + ' @ 0 <>');
    EmitJumpIf(False, Tag3);
    EmitI(CntTmp + ' @ 1 - ' + CntTmp + ' !');
    EmitAddress(Sym);
    if Delta = 1 then EmitInc(Sym^.DataType) else EmitDec(Sym^.DataType);
    EmitJump(Tag);
    Emit(Tag3, '', '');
    IR4BaseFrame := OldBase;
    IR4Frame := SavedFrame;
  end
  else if Scanner.Token = toCase then
  begin
    ParseCaseStatement(ContTarget, BreakTarget);
  end
  else if Scanner.Token = toWith then
  begin
    NextToken;
    ParseWith(ContTarget, BreakTarget);
  end
  else if Scanner.Token = toInline then
    Error('Inline assembly not supported')
  else if Scanner.Token = toGoto then
  begin
    NextToken;

    if Scanner.Token = toIdent then
    begin
      Sym := LookupLocalOrFail(Scanner.StrValue);
      // ...
      EmitJump(Sym^.Tag);
    end
    else if Scanner.Token = toNumber then
    begin
      Sym := LookupLocalOrFail(IntToStr(Scanner.NumValue));
      // ...
      EmitJump(Sym^.Tag);
    end
    else Error('Ident or number expected');

    NextToken;
  end;
end;

function ParseTypeDef: PSymbol; forward;

(**
 * Parses a constant declaration, which can either be a real constant or a
 * so-called typed constant, which is basically an initialized variable.
 *)
procedure EmitIR4GlobalDecl((* const *) Tag: String; DataType: PSymbol);
begin
  while DataType^.Kind = scAliasType do DataType := DataType^.DataType;
  if IsIR4IntType(DataType) then
    EmitI('var ' + Tag + ' :i')
  else if DataType = dtReal then
    EmitI('var ' + Tag + ' :f')
  else if DataType^.Kind = scPointerType then
    EmitI('var ' + Tag + ' :a')
  else
    EmitI('var ' + Tag + ' :bytes ' + IntToStr(IR4MaxBytes(DataType^.IrC, DataType^.IrI, DataType^.IrA, DataType^.IrF)));
end;

procedure EmitIR4ConstAddr((* const *) BaseExpr: String; C, I, A, F: Integer);
begin
  if (C = 0) and (I = 0) and (A = 0) and (F = 0) then
    EmitI(BaseExpr)
  else
    EmitI(BaseExpr + ' ' + IR4TupleExprStr(C, I, A, F) + ' a+');
end;

procedure ParseIR4ConstInit((* const *) BaseExpr: String; DataType: PSymbol; C, I, A, F: Integer);
var
  Idx, K, Value, First, Last, RC, RI, RA, RF: Integer;
  Sym, T, ElemT, BType: PSymbol;
  Test: Boolean;
  S, ValStr: String;
  Bits: array[0..31] of Byte;
begin
  while DataType^.Kind = scAliasType do DataType := DataType^.DataType;
  if (DataType^.Kind = scArrayType) and (DataType^.DataType = dtChar) and (Scanner.Token in [toString, toCaret]) then
  begin
    S := ParseStringLiteral;
    if Length(S) <> DataType^.IndexType^.High - DataType^.IndexType^.Low + 1 then
      Error('String length mismatch');
    for K := 1 to Length(S) do
    begin
      EmitI(IntToStr(Ord(S[K])));
      EmitIR4ConstAddr(BaseExpr, C + K - 1, I, A, F);
      EmitI('i8!');
    end;
  end
  else if DataType^.Kind = scArrayType then
  begin
    Expect(toLParen);
    NextToken;
    ElemT := DataType^.DataType;
    RC := C; RI := I; RA := A; RF := F;
    for Idx := DataType^.IndexType^.Low to DataType^.IndexType^.High - 1 do
    begin
      ParseIR4ConstInit(BaseExpr, ElemT, RC, RI, RA, RF);
      Inc(RC, ElemT^.IrC); Inc(RI, ElemT^.IrI); Inc(RA, ElemT^.IrA); Inc(RF, ElemT^.IrF);
      Expect(toComma);
      NextToken;
    end;
    ParseIR4ConstInit(BaseExpr, ElemT, RC, RI, RA, RF);
    Expect(toRParen);
    NextToken;
  end
  else if DataType^.Kind = scRecordType then
  begin
    Expect(toLParen);
    NextToken;
    Test := True;
    while Test do
    begin
      Test := False;
      if Scanner.Token = toIdent then
      begin
        Sym := Lookup(Scanner.StrValue, DataType^.DataType, nil);
        if Sym = nil then Error('Unknown field "' + Scanner.StrValue + '"');
        NextToken;
        Expect(toColon);
        NextToken;
        ParseIR4ConstInit(BaseExpr, Sym^.DataType, C + Sym^.IrC, I + Sym^.IrI, A + Sym^.IrA, F + Sym^.IrF);
      end;
      if Scanner.Token = toSemicolon then
      begin
        Test := True;
        NextToken;
      end;
    end;
    Expect(toRParen);
    NextToken;
  end
  else if DataType = dtReal then
  begin
    ValStr := '';
    if Scanner.Token = toSub then
    begin
      ValStr := '-';
      NextToken;
    end;
    if Scanner.Token = toNumber then
      ValStr := ValStr + IntToStr(Scanner.NumValue) + '.0'
    else
    begin
      Expect(toFloat);
      ValStr := ValStr + Scanner.StrValue;
    end;
    NextToken;
    EmitI(ValStr);
    if Copy(BaseExpr, 1, 3) = '-> ' then
      EmitI(BaseExpr)
    else
    begin
      EmitIR4ConstAddr(BaseExpr, C, I, A, F);
      EmitI('f!');
    end;
  end
  else if DataType^.Kind = scStringType then
  begin
    S := ParseStringLiteral;
    EmitIR4ConstAddr(BaseExpr, C, I, A, F);
    EmitI(AddString(S) + ' ' + IntToStr(DataType^.Value - 1) + ' pas_strcopy_clamp drop');
  end
  else if DataType^.Kind = scSetType then
  begin
    Expect(toLBrack);
    NextToken;
    for K := 0 to 31 do Bits[K] := 0;
    BType := nil;
    while Scanner.Token <> toRBrack do
    begin
      T := CheckElement(BType, ParseScalarRange(First, Last));
      if (First < 0) or (First > 255) or (Last < 0) or (Last > 255) then
        Error('Value out of range');
      if Last < First then Error('Invalid range');
      BType := T;
      for K := First to Last do
        Bits[K shr 3] := Bits[K shr 3] or (1 shl (K and 7));
      if Scanner.Token = toComma then NextToken;
    end;
    if BType <> nil then CheckElement(DataType^.DataType, BType);
    for K := 0 to 31 do
      if Bits[K] <> 0 then
      begin
        EmitI(IntToStr(Bits[K]));
        EmitIR4ConstAddr(BaseExpr, C + K, I, A, F);
        EmitI('i8!');
      end;
    Expect(toRBrack);
    NextToken;
  end
  else
  begin
    T := ParseScalar(Value);
    while DataType^.Kind in [scAliasType, scSubrangeType] do
      DataType := DataType^.DataType;
    if not ((DataType = T) or (DataType = dtByte) and (T = dtInteger)) then
      Error('Type error');
    EmitI(IntToStr(Value));
    if Copy(BaseExpr, 1, 3) = '-> ' then
      EmitI(BaseExpr)
    else
    begin
      EmitIR4ConstAddr(BaseExpr, C, I, A, F);
      if IsIR4IntType(DataType) then
        EmitI('!')
      else
      begin
        if (Value < 0) or (Value > 255) then Error('Type error');
        EmitI('i8!');
      end;
    end;
  end;
end;

procedure ParseConst;
var
  Name, S, BaseExpr: String;
  Sym, Sym2: PSymbol;
  Sign: Integer;
begin
  Expect(toIdent);
  Name := Scanner.StrValue;
  NextToken;

  if Scanner.Token = toColon then
  begin
    NextToken;

    Sym := CreateSymbol(scVar, Name);
    Sym^.DataType := ParseTypeDef;
    Sym^.Tag := GetLabel('const');
    Sym^.Level := 0; (* Force global *)

    Expect(toEq);
    NextToken;

    EmitIR4GlobalDecl(Sym^.Tag, Sym^.DataType);
    IR4Buffering := True;
    EmitI('init');
    if IsIR4ScalarType(Sym^.DataType) then
      BaseExpr := '-> ' + Sym^.Tag
    else
      BaseExpr := Sym^.Tag;
    ParseIR4ConstInit(BaseExpr, Sym^.DataType, 0, 0, 0, 0);
    EmitI('end');
    IR4Buffering := False;
    EmitStrings(nil);
    FlushIR4Chunks;
  end
  else
  begin
    Sym := CreateSymbol(scConst, Name);

    Expect(toEq);
    NextToken;

    if Scanner.Token in [toString, toCaret] then
    begin
      S := ParseStringLiteral;
      if Length(S) = 1 then
      begin
        Sym^.DataType := dtChar;
        Sym^.Value := Ord(S[1]);
      end
      else
      begin
        Sym^.DataType := dtString;
        Sym^.Tag := AddString(S);
      end;
      Exit;
    end
    else if Scanner.Token = toIdent then
    begin
      Sym2 := LookupGlobalOrFail(Scanner.StrValue);
      if Sym2^.Kind <> scConst then Error('Not a constant: ' + Scanner.StrValue);

      Sym^.DataType := Sym2^.DataType;
      Sym^.Value := Sym2^.Value;
      Sym^.Tag := Sym2^.Tag;
    end
    else
    begin
      if Scanner.Token = toSub then
      begin
        Sign := -1;
        NextToken;
      end
      else Sign := 1;

      if Scanner.Token = toFloat then
      begin
        Sym^.DataType := dtReal;
        if Sign = -1 then
          Sym^.Tag := '-' + Scanner.StrValue
        else
          Sym^.Tag := Scanner.StrValue;
      end
      else
      begin
        Sym^.Value := Sign * Scanner.NumValue;
        Sym^.DataType := dtInteger;
      end;
    end;

    NextToken;
  end;
end;

(**
 * Parses a single record field name (just the name, no type).
 *)
procedure ParseField(var Fields: PSymbol);
var
  Sym: PSymbol;
begin
  Expect(toIdent);
  if Lookup(Scanner.StrValue, Fields, nil) <> nil then Error('Duplicate field "' + Scanner.StrValue + '"');

  New(Sym);
  FillChar(Sym^, SizeOf(TSymbol), 0);
  Sym^.Kind := scVar;
  Sym^.Name := Scanner.StrValue;
  Sym^.Prev := Fields;
  Fields := Sym;

  NextToken;
end;

(**
 * Parses a field group, that is, a comma-separated list of record field names
 * with a single type specification.
 *)
procedure ParseFieldGroup(var Fields: PSymbol; var Offset: Integer; var RC, RI, RA, RF: Integer);
var
  Sym, Typ: PSymbol;
  Len, I: Integer;
begin
  ParseField(Fields);
  Len := 1;

  while Scanner.Token = toComma do
  begin
    NextToken;
    ParseField(Fields);
    Len := Len + 1;
  end;

  Expect(toColon);
  NextToken;
  Typ := ParseTypeDef;

  Offset := Offset + Len * Typ^.Value;
  RC := RC + Len * Typ^.IrC;
  RI := RI + Len * Typ^.IrI;
  RA := RA + Len * Typ^.IrA;
  RF := RF + Len * Typ^.IrF;
  Sym := Fields;

  for I := 1 to Len do
  begin
    Sym^.DataType := Typ;
    Sym^.Value := Offset - I * Typ^.Value;
    Sym^.IrC := RC - I * Typ^.IrC;
    Sym^.IrI := RI - I * Typ^.IrI;
    Sym^.IrA := RA - I * Typ^.IrA;
    Sym^.IrF := RF - I * Typ^.IrF;
    Sym := Sym^.Prev;
  end;
end;

(**
 * Parses a record type definition including a potentially variant part.
 *)
procedure ParseRecord(RecSym: PSymbol);
var
  Sym, CaseType: PSymbol;
  FixedSize, VariantSize, Dummy: Integer;
  FixC, FixI, FixA, FixF: Integer;
  VarC, VarI, VarA, VarF: Integer;
  Ident: String;
begin
  while Scanner.Token = toIdent do
  begin
    ParseFieldGroup(RecSym^.DataType, RecSym^.Value, RecSym^.IrC, RecSym^.IrI, RecSym^.IrA, RecSym^.IrF);
    if Scanner.Token <> toSemicolon then Break;
    NextToken;
  end;

  if Scanner.Token = toCase then
  begin
    NextToken;
    Expect(toIdent);
    Ident := Scanner.StrValue;
    NextToken;
    if Scanner.Token = toColon then
    begin
      NextToken;
      Expect(toIdent);
      CaseType := LookupGlobalOrFail(Scanner.StrValue);

      New(Sym);
      FillChar(Sym^, SizeOf(TSymbol), 0);
      Sym^.Kind := scVar;
      Sym^.Name := Ident;
      Sym^.DataType := CaseType;
      Sym^.Value := RecSym^.Value;
      Sym^.IrC := RecSym^.IrC;
      Sym^.IrI := RecSym^.IrI;
      Sym^.IrA := RecSym^.IrA;
      Sym^.IrF := RecSym^.IrF;
      Sym^.Prev := RecSym^.DataType;
      RecSym^.DataType := Sym;

      RecSym^.Value := RecSym^.Value + CaseType^.Value;
      RecSym^.IrC := RecSym^.IrC + CaseType^.IrC;
      RecSym^.IrI := RecSym^.IrI + CaseType^.IrI;
      RecSym^.IrA := RecSym^.IrA + CaseType^.IrA;
      RecSym^.IrF := RecSym^.IrF + CaseType^.IrF;

      NextToken;
    end
    else
    begin
      CaseType := LookupGlobalOrFail(Ident);
    end;

    FixedSize := RecSym^.Value;
    VariantSize := FixedSize;
    FixC := RecSym^.IrC; FixI := RecSym^.IrI; FixA := RecSym^.IrA; FixF := RecSym^.IrF;
    VarC := FixC; VarI := FixI; VarA := FixA; VarF := FixF;

    Expect(toOf);
    NextToken;

    while Scanner.Token in [toSub, toIdent, toNumber, toString, toCaret] do
    begin
      CheckElement(CaseType, ParseScalar(Dummy));
      while Scanner.Token = toComma do
      begin
        NextToken;
        CheckElement(CaseType, ParseScalar(Dummy));
      end;

      Expect(toColon);
      NextToken;

      Expect(toLParen);
      NextToken;

      ParseRecord(RecSym);
      if RecSym^.Value > VariantSize then VariantSize := RecSym^.Value;
      if RecSym^.IrC > VarC then VarC := RecSym^.IrC;
      if RecSym^.IrI > VarI then VarI := RecSym^.IrI;
      if RecSym^.IrA > VarA then VarA := RecSym^.IrA;
      if RecSym^.IrF > VarF then VarF := RecSym^.IrF;
      RecSym^.Value := FixedSize;
      RecSym^.IrC := FixC; RecSym^.IrI := FixI; RecSym^.IrA := FixA; RecSym^.IrF := FixF;

      Expect(toRParen);
      NextToken;

      Expect(toSemicolon);
      NextToken;
    end;

    RecSym^.Value := VariantSize;
    RecSym^.IrC := VarC; RecSym^.IrI := VarI; RecSym^.IrA := VarA; RecSym^.IrF := VarF;
  end;
end;

(**
 * Parses an array type definition. We support the standard form (array of
 * array) and the alternative shorthand form (one pair of brackets overall,
 * comma-separated dimensions specifiers).
 *
 * TODO Allow C-style array sizes with array[n] meaning array[0..n-1]?
 *)
procedure ParseArray(DataType: PSymbol; First: Boolean);
var
  Count: Integer;
begin
  if First then
  begin
    Expect(toLBrack);
    NextToken;
  end;

  DataType^.IndexType := ParseTypeDef;
  if not (DataType^.IndexType^.Kind in [scType, scEnumType, scSubrangeType]) then
    Error('Not an ordinal type');

  if Scanner.Token = toComma then
  begin
    NextToken;
    DataType^.DataType := CreateSymbol(scArrayType, '');
    ParseArray(DataType^.DataType, False);
  end
  else
  begin
    Expect(toRBrack);
    NextToken;

    Expect(toOf);
    NextToken;

    DataType^.DataType := ParseTypeDef;
  end;

  Count := DataType^.IndexType^.High - DataType^.IndexType^.Low + 1;
  DataType^.Value := Count * DataType^.DataType^.Value;
  DataType^.IrC := Count * DataType^.DataType^.IrC;
  DataType^.IrI := Count * DataType^.DataType^.IrI;
  DataType^.IrA := Count * DataType^.DataType^.IrA;
  DataType^.IrF := Count * DataType^.DataType^.IrF;
end;

(**
 * Parses a type definition, which can be an array, a string, a file, a record,
 * a pointer, a set, a range, or a reference to an existing type (and
 * potentially nested, of course).
 *)
function ParseTypeDef;
var
  DataType, Sym: PSymbol;
  I, K: Integer;
  EnumStrs: array[0..255] of String[31];
begin
  if Scanner.Token = toArray then
  begin
    DataType := CreateSymbol(scArrayType, '');
    NextToken;

    ParseArray(DataType, True);
  end
  else if Scanner.Token = toStringKW then
  begin
    NextToken;

    DataType := CreateSymbol(scStringType, '');

    if Scanner.Token = toLBrack then
    begin
      NextToken;
      if Scanner.Token = toIdent then
      begin
        Sym := LookupGlobalOrFail(Scanner.StrValue);
        if Sym^.Kind <> scConst then Error('Not a constant: ' + Scanner.StrValue);
        TypeCheck(dtInteger, Sym^.DataType, tcAssign);
        DataType^.Value := Sym^.Value + 1;
      end
      else
      begin
        Expect(toNumber);
        DataType^.Value := Scanner.NumValue + 1;
      end;
      NextToken;
      Expect(toRBrack);
      NextToken;
    end
    else DataType^.Value := 256;
    DataType^.IrC := DataType^.Value;
  end
  else if Scanner.Token = toFile then
  begin
    NextToken;

    if Scanner.Token = toOf then
    begin
      DataType := CreateSymbol(scFileType, '');
      NextToken;
      DataType^.DataType := ParseTypeDef;
      (* Same FileRec layout as an untyped file: the component size and
         count are fields inside it, not extra storage. *)
      DataType^.Value := dtFile^.Value;
      DataType^.IrC := dtFile^.IrC;
    end
    else DataType := dtFile;
  end
  else if Scanner.Token = toRecord then
  begin
    DataType := CreateSymbol(scRecordType, '');
    NextToken;

    ParseRecord(DataType);
    Expect(toEnd);
    NextToken;
  end
  else if Scanner.Token = toSet then
  begin
    NextToken;
    Expect(toOf);
    NextToken;

    DataType := CreateSymbol(scSetType, '');
    DataType^.DataType := ParseTypeDef;

    if not (DataType^.DataType^.Kind in [scType, scEnumType, scSubrangeType]) then
      Error('Scalar type required');

    if DataType^.DataType^.Value > 1 then
      Error('Base type too large');

    DataType^.Value := 32;
    DataType^.IrC := 32;
  end
  else if Scanner.Token = toCaret then
  begin
    DataType := CreateSymbol(scPointerType, '');
    DataType^.Value := 2;
    DataType^.IrA := 1;
    NextToken;

    if Scanner.Token = toIdent then
    begin
      DataType^.DataType := Lookup(Scanner.StrValue, SymbolTable, nil);
      if DataType^.DataType = nil then DataType^.Tag := Scanner.StrValue;
      NextToken;
    end
    else DataType^.DataType := ParseTypeDef;
  end
  else if Scanner.Token = toLParen then
  begin
    DataType := CreateSymbol(scEnumType, '');
    DataType^.Tag := GetLabel('enumlit');
    DataType^.Value := 1;
    DataType^.IrC := 1;
    I := 0;

    repeat
      NextToken;
      Expect(toIdent);

      Sym := CreateSymbol(scConst, Scanner.StrValue);
      Sym^.Value := I;

      if I < 256 then EnumStrs[I] := AddString(Sym^.Name);

      Sym^.DataType := DataType;
      I := I + 1;
      NextToken;
    until Scanner.Token <> toComma;

    EmitStrings(nil);
    EmitI('data ' + DataType^.Tag);
    EmitI(IntToStr(I));
    for K := 0 to I - 1 do
      EmitI('& ' + EnumStrs[K]);
    EmitI('end');

    DataType^.Low := 0;
    DataType^.High := I - 1;

    Expect(toRParen);
    NextToken;
  end
  else if (Scanner.Token = toNumber) or (Scanner.Token = toSub) then
  begin
    DataType := CreateSymbol(scSubrangeType, '');
    DataType^.DataType := dtInteger;

    ParseScalar(I);
    DataType^.Low := I;
    Expect(toRange);
    NextToken;

    if Scanner.Token = toIdent then
    begin
      Sym := LookupGlobalOrFail(Scanner.StrValue);

      if Sym^.Kind <> scConst then Error('Not a constant');
      if (Sym^.DataType <> dtInteger) and (Sym^.DataType^.Kind <> scEnumType) then Error('Not an integer or enum');

      DataType^.High := Sym^.Value;

      (* A negative lower bound needs the full 16 bit: loading a byte sized
         variable zero-extends, which would turn -100 into 156. *)
      if (DataType^.Low >= 0) and (DataType^.High < 256) then
      begin
        DataType^.Value := 1;
        DataType^.IrC := 1;
      end
      else
      begin
        DataType^.Value := 2;
        DataType^.IrI := 1;
      end;

      NextToken;
    end
    else
    begin
      if not ((Scanner.Token = toNumber) or (Scanner.Token = toSub)) then
        Expect(toNumber);
      ParseScalar(I);
      DataType^.High := I;

      (* A negative lower bound needs the full 16 bit: loading a byte sized
         variable zero-extends, which would turn -100 into 156. *)
      if (DataType^.Low >= 0) and (DataType^.High < 256) then
      begin
        DataType^.Value := 1;
        DataType^.IrC := 1;
      end
      else
      begin
        DataType^.Value := 2;
        DataType^.IrI := 1;
      end;
    end;
  end
  else if Scanner.Token = toString then
  begin
    if Length(Scanner.StrValue) <> 1 then Error('Char expected');

    DataType := CreateSymbol(scSubrangeType, '');
    DataType^.DataType := dtChar;

    DataType^.Low := Ord(Scanner.StrValue[1]);
    NextToken;
    Expect(toRange);
    NextToken;
    Expect(toString);
    if Length(Scanner.StrValue) <> 1 then Error('Char expected');
    DataType^.High := Ord(Scanner.StrValue[1]);

    DataType^.Value := 1;
    DataType^.IrC := 1;

    NextToken;
  end
  else begin
    Expect(toIdent);

    Sym := LookupGlobalOrFail(Scanner.StrValue);

    if Sym^.Kind = scConst then
    begin
      DataType := CreateSymbol(scSubrangeType, '');
      DataType^.DataType := Sym^.DataType;
      DataType^.Value := 1;
      DataType^.IrC := 1;

      Sym := LookupGlobalOrFail(Scanner.StrValue);
      DataType^.Low := Sym^.Value;
      NextToken;
      Expect(toRange);
      NextToken;

      if Scanner.Token = toIdent then
      begin
        Sym := LookupGlobalOrFail(Scanner.StrValue);

        if Sym^.Kind <> scConst then Error('Not a constant');
        if (Sym^.DataType <> dtInteger) and (Sym^.DataType^.Kind <> scEnumType) then Error('Not an integer or enum');

        DataType^.High := Sym^.Value;

        (* A negative lower bound needs the full 16 bit: loading a byte sized
           variable zero-extends, which would turn -100 into 156. *)
        if (DataType^.Low >= 0) and (DataType^.High < 256) then
        begin
          DataType^.Value := 1;
          DataType^.IrC := 1; DataType^.IrI := 0;
        end
        else
        begin
          DataType^.Value := 2;
          DataType^.IrC := 0; DataType^.IrI := 1;
        end;
      end
      else
      begin
        Expect(toNumber);
        DataType^.High := Scanner.NumValue;

        (* A negative lower bound needs the full 16 bit: loading a byte sized
           variable zero-extends, which would turn -100 into 156. *)
        if (DataType^.Low >= 0) and (DataType^.High < 256) then
        begin
          DataType^.Value := 1;
          DataType^.IrC := 1; DataType^.IrI := 0;
        end
        else
        begin
          DataType^.Value := 2;
          DataType^.IrC := 0; DataType^.IrI := 1;
        end;
      end;

      NextToken;
    end
    else
    begin
      while Sym^.Kind = scAliasType do Sym := Sym^.DataType;

      if not (Sym^.Kind in [scType, scArrayType, scRecordType, scEnumType, scStringType, scSetType, scPointerType, scSubrangeType, scFileType]) then
        Error('Not a type: ' + Scanner.StrValue);

      DataType := Sym;
      NextToken;
    end;
  end;

  ParseTypeDef := DataType;
end;

(**
 * Parses a type reference, which is basically the name of a built-in or
 * user-defined type. Needed for parameters. These are not allowed to come
 * up with new (and hence anonymous) types.
 *)
function ParseTypeRef: PSymbol;
var
  DataType: PSymbol;
begin
  if Scanner.Token = toStringKW then
    DataType := dtString
  else if Scanner.Token = toFile then
    DataType := dtFile
  else
  begin
    Expect(toIdent);
    DataType := LookupGlobalOrFail(Scanner.StrValue);

    while DataType^.Kind = scAliasType do
      DataType := DataType^.DataType;

    if not (DataType^.Kind in [scType, scArrayType, scRecordType, scEnumType, scStringType, scSetType, scSubrangeType, scPointerType, scFileType]) then Error('Type expected');
  end;

  NextToken;

  ParseTypeRef := DataType;
end;

(**
 * Parses a single variable or parameter name.
 *
 * TODO Is this worth its own procedure? Only used by variable and parameter lists.
 *)
procedure ParseVar;
var
  Name: String;
begin
  Expect(toIdent);
  Name := Scanner.StrValue;
  NextToken;

  CreateSymbol(scVar, Name);
  (*
  if Sym^.Level = 0 then
  begin
    Sym^.Tag := GetLabel('global');
    Emit0(Sym^.Tag, 'ds ' + IntToStr(Sym^.Bounds * 2), 'Global ' + Sym^.Name);
  end;
  *)
end;

(**
 * Parses a variable list (actually this should probably be called a variable
 * group), that is, a comma separated list of variable identifiers followed by a
 * type name or definition.
 *)
procedure ParseVarList;
var
  Old: PSymbol;
  DataType, Sym: PSymbol;
  Multi, IsAbs: Boolean;
  Tag: String;
begin
  Multi := False;
  IsAbs := False;

  Old := SymbolTable;
  ParseVar;
  while Scanner.Token = toComma do
  begin
    Multi := True;
    NextToken; ParseVar;
  end;

  Expect(toColon);
  NextToken;

  DataType := ParseTypeDef;

    // WriteLn('Var type is ', DataType^.Name);
    // if DataType^.Kind = scArrayType then WriteLn(' of ', DataType^.DataType^.Name);

  if Scanner.Token = toAbsolute then
  begin
    if Multi then Error('"absolute" only allowed for single variables');

    NextToken;
    if Scanner.Token = toNumber then
      Tag := IntToStr(Scanner.NumValue)
    else if Scanner.Token = toString then
      Tag := Scanner.StrValue
    else if Scanner.Token = toIdent then
    begin
      Sym := LookupGlobalOrFail(Scanner.StrValue);
      if Sym^.Tag = '' then Error('Not addressable');
      Tag := Sym^.Tag;
    end
    else Error('Address expected');

    NextToken;
    IsAbs := True;
  end;

  while Old<>SymbolTable do
  begin
    Old := Old^.Next;
    if Old^.Kind = scVar then
    begin
      SetDataType(Old, DataType, False);
      if IsAbs then Old^.Tag := Tag
      else if Old^.Level = 0 then
      begin
        Old^.Tag := GetLabel('global');
        EmitIR4GlobalDecl(Old^.Tag, Old^.DataType);
      end;
    end;

//    Tmp^.DataType := DataType;
    //if High >= Low then Tmp^.Bounds := High - Low + 1;
//    Tmp := Tmp^.Prev;
    //Offset := Offset + (High - Low + 1) * 2 - 2;
  end;
end;

(**
 * Parses a parameter list (actually this should probably be called a parameter
 * group), that is, a comma-separated list of variable names followed by a
 * single type reference. Whether these are "var" parameters or not is being
 * passed as a parameter.
 *)
procedure ParseParamList(IsRef: Boolean);
var
  Old: PSymbol;
  DataType: PSymbol;
begin
  Old := SymbolTable;
  ParseVar;
  SymbolTable^.IsRef := IsRef;
  while Scanner.Token = toComma do
  begin
    NextToken; ParseVar;
    SymbolTable^.IsRef := IsRef;
  end;

  if not IsRef or (Scanner.Token = toColon) then
  begin
    Expect(toColon);
    NextToken;
    DataType := ParseTypeRef;
    if (DataType^.Kind = scFileType) and not IsRef then
      Error('File types must be passed by reference.');
  end
  else DataType := nil;

  (*if (DataType^.Kind in [scArrayType, scRecordType]) and not isRef then
    Error('Structured parameters must be passed by reference');*)

  while Old<>SymbolTable do
  begin
    Old := Old^.Next;
    if Old^.Kind = scVar then
      SetDataType(Old, DataType, True);
  end;
end;

(**
 * Parses a label definition, which can be numeric or alphanimeric.
 *)
procedure ParseLabelDef;
var
  S: PSymbol;
begin
  if Scanner.Token = toIdent then
  begin
    S := CreateSymbol(scLabel, Scanner.StrValue);
  end
  else if Scanner.Token = toNumber then
  begin
    S := CreateSymbol(scLabel, IntToStr(Scanner.NumValue));
  end
  else Error('Identifier or number expected');

  S^.Tag := GetLabel('label');
  NextToken;
end;

procedure ParseBlock(Sym: PSymbol); forward;

(**
 * Parses a procedure or function declaration. It can be either a forward
 * declaration or the actual implementation, in which case the corresponding
 * block is parsed, too.
 *)
procedure ParseProcFunc(Sym: PSymbol);
var
  NewSym, ResVar, FwdSym, P: PSymbol;
  Token: TToken;
  S: String;
  I: Integer;
  IsRef: Boolean;
begin
  Token := Scanner.Token;
  NextToken; Expect(toIdent);

  FwdSym := Lookup(Scanner.StrValue, SymbolTable, CurrentScope);
  if (FwdSym <> nil) and (FwdSym^.IsForward) then
  begin
    if ((Token = toProcedure) and (FwdSym^.Kind <> scProc)) or
       ((Token = toFunction) and (FwdSym^.Kind <> scFunc)) then
      Error('Proc/Func mismatch');

    FwdSym^.IsForward := False;

    OpenScope(True);
    IR4Frame.C := FwdSym^.IrC;
    IR4Frame.I := FwdSym^.IrI;
    IR4Frame.A := FwdSym^.IrA;
    IR4Frame.F := FwdSym^.IrF;

    if FwdSym^.SavedParams <> nil then
    begin
      P := FwdSym^.SavedParams;
      while P^.Prev <> nil do
      begin
        P := P^.Prev;
      end;
      P^.Prev := SymbolTable;
      SymbolTable^.Next := P;
      SymbolTable := FwdSym^.SavedParams;
      FwdSym^.SavedParams := nil;
    end;

    NextToken;
    Expect(toSemicolon);
    NextToken;

    NewSym := FwdSym;
  end
  else
  begin
    if Token = toProcedure then
    begin
      NewSym := CreateSymbol(scProc, Scanner.StrValue);
      NewSym^.Tag := GetLabel('__' + NewSym^.Name);
    end
    else
    begin
      NewSym := CreateSymbol(scFunc, Scanner.StrValue);
      NewSym^.Tag := GetLabel('__' + NewSym^.Name);
    end;

    OpenScope(True);
  end;

  if FwdSym = nil then
  begin
    if Token = toFunction then
    begin
      ResVar := CreateSymbol(scVar, Scanner.StrValue);
      ResVar^.Tag := 'RESULT';
    end;
    NextToken;

    if Scanner.Token = toLParen then
    begin
      NextToken;

      IsRef := False;
      if Scanner.Token = toVar then
      begin
        IsRef := True;
        NextToken;
      end;

      ParseParamList(IsRef);
      while Scanner.Token = toSemicolon do
      begin
        NextToken;

        IsRef := False;
        if Scanner.Token = toVar then
        begin
          IsRef := True;
          NextToken;
        end;

        ParseParamList(IsRef); (* ParamGroup *)
      end;
      Expect(toRParen);
      NextToken;
    end;

    if NewSym^.Kind = scFunc then
    begin
      Expect(toColon);
      NextToken;

      NewSym^.DataType := ParseTypeRef;
      ResVar^.DataType := NewSym^.DataType;

      if NewSym^.DataType^.Kind = scFileType then Error('Files types not allowed as return values.');

      ResVar^.IrC := IR4Frame.C;
      ResVar^.IrI := IR4Frame.I;
      ResVar^.IrA := IR4Frame.A;
      ResVar^.IrF := IR4Frame.F;
      Inc(IR4Frame.C, ResVar^.DataType^.IrC);
      Inc(IR4Frame.I, ResVar^.DataType^.IrI);
      Inc(IR4Frame.A, ResVar^.DataType^.IrA);
      Inc(IR4Frame.F, ResVar^.DataType^.IrF);
    end;

    AdjustOffsets;

    Expect(toSemicolon);
    NextToken;

    while Scanner.Token in [toExternal,toForward,toIdent] do
    begin
      if Scanner.Token = toExternal then
      begin
        NextToken;
        NewSym^.IsExternal := True;
        if Scanner.Token = toString then
        begin
          NewSym^.Tag := Scanner.StrValue;
          NextToken;
        end
        else
          NewSym^.Tag := '__' + LowerStr(NewSym^.Name);
      end
      else if Scanner.Token = toForward then
      begin
        NewSym^.IsForward := True;
        NextToken;
        S := 'fwd ' + NewSym^.Tag + ' (';
        for I := 0 to NewSym^.Value - 1 do
        begin
          if NewSym^.ArgIsRef[I] then
            S := S + ' p' + IntToStr(I) + ' :a'
          else if NewSym^.ArgTypes[I] = dtReal then
            S := S + ' p' + IntToStr(I) + ' :f'
          else if NewSym^.ArgTypes[I]^.Kind in [scPointerType, scStringType, scSetType, scArrayType, scRecordType] then
            S := S + ' p' + IntToStr(I) + ' :a'
          else
            S := S + ' p' + IntToStr(I) + ' :i';
        end;
        if NewSym^.Kind = scFunc then
        begin
          if NewSym^.DataType^.Kind in [scStringType, scSetType, scArrayType, scRecordType] then
            S := S + ' p_sret :a';
          if NewSym^.DataType = dtReal then
            S := S + ' -> :f'
          else if NewSym^.DataType^.Kind in [scPointerType, scStringType, scSetType, scArrayType, scRecordType] then
            S := S + ' -> :a'
          else
            S := S + ' -> :i';
        end;
        S := S + ' )';
        EmitI(S);
      end
      else
      begin
        S := LowerStr(Scanner.StrValue);
        if (S <> 'stdcall') and (S <> 'register') then
          Error('Unknown modifier ' + S);

        NextToken;
      end;

      Expect(toSemicolon);
      NextToken;
    end;

    if NewSym^.IsForward then
    begin
      NewSym^.IrC := IR4Frame.C;
      NewSym^.IrI := IR4Frame.I;
      NewSym^.IrA := IR4Frame.A;
      NewSym^.IrF := IR4Frame.F;
      if SymbolTable^.Kind = scScope then
      begin
        NewSym^.SavedParams := nil
      end
      else
      begin
        NewSym^.SavedParams := SymbolTable;
        NewSym^.Next^.Next^.Prev := nil;
        NewSym^.Next^.Next := nil;
        SymbolTable := NewSym^.Next;
      end;
    end
  end;

  if not NewSym^.IsExternal and not NewSym^.IsForward then
  begin
    if Scanner.Token = toInline then
      Error('Inline assembly not supported')
    else
    begin
      ParseBlock(NewSym);
      Expect(toSemicolon);
      NextToken;
    end;
  end;

  CloseScope(True);

  EmitC('');
end;

(**
 * Parses a declaration part, which can contain the following elements any
 * number of times and in any order: constants, types, variables, labels,
 * procedures, and functions.
 *)
procedure ParseDeclarations(Sym: PSymbol);
var
  OldSyms, P, T: PSymbol;
  Name: String;
begin
  while Scanner.Token in [toConst, toType, toVar, toLabel, toProcedure, toFunction] do
  begin
    if Scanner.Token = toConst then
    begin
      NextToken;
      repeat
        ParseConst;
        while Scanner.Token = toComma do
        begin
          NextToken; ParseConst;
        end;
        Expect(toSemicolon);
        NextToken;
      until Scanner.Token <> toIdent;
    end

    else if Scanner.Token = toType then
    begin
      OldSyms := SymbolTable;

      NextToken;
      Expect(toIdent);

      repeat
        Name := Scanner.StrValue;

        if Lookup(Name, SymbolTable, CurrentScope) <> nil then
          Error('Duplicate identifier "' + Name + '"');

        NextToken;
        Expect(toEq);
        NextToken;

        T := ParseTypeDef;
        if T^.Name <> '' then
        begin
          P := CreateSymbol(scAliasType, Name);
          P^.DataType := T;
        end
        else T^.Name := Name;

        Expect(toSemicolon);
        NextToken;
      until Scanner.Token <> toIdent;

      P := SymbolTable;
      while P <> OldSyms do
      begin
        if (P^.Kind = scPointerType) and (P^.DataType = nil) then
        begin
          P^.DataType := Lookup(P^.Tag, SymbolTable, CurrentScope);
          if P^.DataType = nil then Error('Unresolved forward declaration "' + P^.Name + '"');
          P^.Tag := '';
        end;

        P := P^.Prev;
      end;
    end

    else if Scanner.Token = toVar then
    begin
      NextToken;
      repeat
        parseVarList;
        Expect(toSemicolon);
        NextToken;
      until Scanner.Token <> toIdent;
    end

    else if Scanner.Token = toLabel then
    begin
      NextToken;
      parseLabelDef;
      while Scanner.Token = toComma do
      begin
        NextToken;
        parseLabelDef;
      end;
      Expect(toSemicolon);
      NextToken;
    end

    else if (Scanner.Token = toProcedure) or (Scanner.Token = toFunction) then
      ParseProcFunc(Sym);
  end;
end;

(**
 * Parses a statement list, which is a (possibly empty) list of statements
 * separated by semicolons.
 *)
procedure ParseStatementList;
begin
  ParseStatement(ContTarget, BreakTarget);
  IR4Frame := IR4BaseFrame;
  while Scanner.Token = toSemicolon do
  begin
    NextToken;
    ParseStatement(ContTarget, BreakTarget);
    IR4Frame := IR4BaseFrame;
  end;
end;

(**
 * Parses a block, which is a set of declarations followed by a statement list
 * enclose in "begin" and "end".
 *)
procedure ParseBlock;
begin
  ParseDeclarations(Sym);

  ExitTarget := GetLabel('exit');
  EmitPrologue(Sym);

  Expect(toBegin);
  NextToken;

  ParseStatementList('', '');

  Expect(toEnd);
  NextToken;

  EmitEpilogue(Sym);
end;

(**
 * Parses the main program. This includes automatic inclusion of the correct
 * system library (which needs its own "end." so we know when exactly the actual
 * program code starts).
 *)
procedure ParseProgram;
var
  Sym, BuiltInSym: PSymbol;
begin
  OpenScope(False);
  RegisterAllBuiltIns;

  if FSize(HomeDir + '/rtl/ir4.pas') <> -1 then
    OpenInput(HomeDir + '/rtl/ir4.pas')
  else if FSize(HomeDir + '/../pasta84/rtl/ir4.pas') <> -1 then
    OpenInput(HomeDir + '/../pasta84/rtl/ir4.pas')
  else
  begin
    NewConst('ScreenWidth', dtInteger, 40);
    NewConst('ScreenHeight', dtInteger, 25);
    NextToken;
    LastBuiltIn := SymbolTable;
    Sym := nil;
  end;
  if FSize(HomeDir + '/rtl/ir4.pas') <> -1 then
  begin
    NextToken;
    ParseDeclarations(nil);
    Expect(toEnd);
    NextToken;
    Expect(toPeriod);
    NextToken;
  end
  else if FSize(HomeDir + '/../pasta84/rtl/ir4.pas') <> -1 then
  begin
    NextToken;
    ParseDeclarations(nil);
    Expect(toEnd);
    NextToken;
    Expect(toPeriod);
    NextToken;
  end;

  LastBuiltIn := SymbolTable;

  Sym := Lookup('FileRec', LastBuiltIn, nil);
  if Sym <> nil then
  begin
    BuiltInSym := LookupBuiltInOrFail('File');
    BuiltInSym^.Value := Sym^.Value;
  end;

  Sym := Lookup('TextRec', LastBuiltIn, nil);
  if Sym <> nil then
  begin
    BuiltInSym := LookupBuiltInOrFail('Text');
    BuiltInSym^.Value := Sym^.Value;
  end;

  OpenScope(False);
  if Scanner.Token = toProgram then
  begin
    NextToken;
    Expect(toIdent);
    NextToken;
    Expect(toSemicolon);
    NextToken;
  end;
  parseBlock(nil);
  Expect(toPeriod);
  EmitStrings(nil);

  CloseScope(False);
  CloseScope(False);
end;

(**
 * Resets the compiler to its initial state, allowing for another compilation.
 *)
procedure ResetCompiler;
begin
  ClearIR4Chunks;
  IR4FnSig := '';
  IR4LineOpen := False;
  IR4Frame.C := 0; IR4Frame.I := 0; IR4Frame.A := 0; IR4Frame.F := 0;
  IR4BaseFrame := IR4Frame;
  IR4MaxFrame := IR4Frame;
  IR4CaseTemp := '';
  // Cannot use CloseScope because that might
  // trigger "unresolved forward" errors.
  while SymbolTable <> nil do
    FreeAndNilSymbol(SymbolTable);

  C := #0;

  Level := 0;
  Scanner.Token := toNone;
  CurrentScope := nil;
  LastBuiltIn := nil;

  ClearStrings;
  ClearDefines;

  Source := nil;

  IOMode := True;
  Muted := 0;

  IfDefLevel := -1;
  ScannerMuted := False;
  NextLabel := 0;

  AsmFile := '';
  ExitTarget := '';
end;

(**
 * Compiles the given source file to IR4 code.
 *)
function Build: Integer;
var
  StartTime: {$ifndef SYS_IR4} Int64 {$else} Integer {$endif};
  Duration: Real;
begin
  StartTime := GetMSCount;

  Build := 1;

  ResetCompiler;

  AsmFile := ChangeExt(SrcFile, '.ir4');

  {$ifndef SYS_IR4}
  HasStoredState := True;

  try
  {$endif}
    if FSize(SrcFile) = -1 then
      Error('File "' + PosixToNative(FRelative(SrcFile)) + '" not found');

    Build := 2;

    WriteLn('Compiling...');
    WriteLn('  ', PosixToNative(FRelative(SrcFile)),
            ' -> ', PosixToNative(FRelative(AsmFile)));

    OpenInput(SrcFile);
    OpenTarget(AsmFile);

    EmitHeader(HomeDir, SrcFile);
    ParseProgram;
    EmitFooter;

    CloseTarget;
    while Source <> nil do CloseInput;

    Duration := (GetMSCount - StartTime) / 1000.0;

    WriteLn;
    if Release then Write('Release') else Write('Debug');
    WriteLn(' build finished (', Duration:0:3, 's).');

    Build := 0;
  {$ifndef SYS_IR4}
  except
    on E: ECompileError do ;
  end;

  if Result = 2 then
  begin
    CloseTarget;
    while Source <> nil do CloseInput;
  end;

  HasStoredState := False;
  {$endif}
end;

(**
 * Shows the copyright header.
 *)
procedure Copyright;
begin
  WriteLn('----------------------------------------');
  WriteLn('PASTA/84 Pascal System', 'Version ' + Version:18);
  WriteLn('IR4th backend':40);
  WriteLn;
  WriteLn('Copyright (C) 2020-26 by  Joerg Pleumann');
  WriteLn('----------------------------------------');
  WriteLn;
end;

(**
 * Processes command-line parameters and compiles the input file.
 *)
procedure Parameters;
var
  I: Integer;
begin
  if ParamCount = 0 then
  begin
    Copyright;

    WriteLn('Usage:');
    WriteLn('  pasta84 { <option> } <input>');
    WriteLn;
    WriteLn('Options:');
    WriteLn('  --release      ignores assertions and breakpoints');
    WriteLn('  --keep[int]    accepted for compatibility (no-op)');
    WriteLn('  --ir4          accepted for compatibility (no-op)');
    WriteLn('  --version      shows just the version number');
    WriteLn;
    Halt(1);
  end;

  I := 1;
  SrcFile := ParamStr(I);
  while Copy(SrcFile, 1, 2) = '--' do
  begin
    if SrcFile = '--release' then
      Release := True
    else if (SrcFile = '--keepint') or (SrcFile = '--keep') or (SrcFile = '--ir4') then
      begin end
    else
      Error('Invalid option: ' + SrcFile);

    I := I + 1;
    SrcFile := ParamStr(I);
  end;

  if SrcFile = '' then
    Error('No input file');

  SrcFile := FAbsolute(NativeToPosix(SrcFile));
  if Pos('.', SrcFile) = 0 then SrcFile := SrcFile + '.pas';
  AsmFile := ChangeExt(SrcFile, '.ir4');

  Copyright;
  I := Build;
  WriteLn;
  Halt(I);
end;

(* -------------------------------------------------------------------------- *)
(* --- Main program --------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

begin
  Release := False;
  IR4LineOpen := False;
  IR4Buffering := False;
  IR4Head := nil;
  IR4Tail := nil;
  IR4FnSig := '';
  IR4CaseTemp := '';
  SymbolTable := nil;
  CurrentScope := nil;
  LastBuiltIn := nil;
  Defines := nil;
  IfDefLevel := -1;
  ScannerMuted := False;
  IOMode := True;
  Muted := 0;

  if ParamStr(1) = '--version' then
  begin
    WriteLn(Version);
    Halt;
  end;

  LoadConfig;

  Parameters;
end.
