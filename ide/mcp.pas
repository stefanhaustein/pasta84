program Mcp;

{$A+,U-}

const
  TmpFile = 'PANO.TMP';
  ErrFile = 'PANO.ERR';

type
  TStr40 = String[40];
  TStr16 = String[15];

var
  SrcFile, OutBin: String;
  RowS, ColS, Act: TStr16;

procedure AppendSub(var Dst, Src: String; Start, Count: Integer);
var
  DL, SL, Avail: Integer;
begin
  SL := Length(Src);
  if (Start < 1) or (Start > SL) or (Count <= 0) then Exit;
  Avail := SL - Start + 1;
  if Count > Avail then Count := Avail;
  DL := Length(Dst);
  if DL + Count > 255 then Count := 255 - DL;
  if Count <= 0 then Exit;
  Move(Src[Start], Dst[DL + 1], Count);
  SetLength(Dst, DL + Count);
end;

procedure AppendVar(var Dst, Src: String);
begin
  AppendSub(Dst, Src, 1, Length(Src));
end;

procedure AppendLit(var Dst: String; Lit: TStr40);
var
  DL, LL: Integer;
begin
  LL := Length(Lit);
  if LL <= 0 then Exit;
  DL := Length(Dst);
  if DL + LL > 255 then LL := 255 - DL;
  if LL <= 0 then Exit;
  Move(Lit[1], Dst[DL + 1], LL);
  SetLength(Dst, DL + LL);
end;

function FileExists(var Name: String): Boolean;
var
  T: Text;
  Err: Byte;
begin
  {$I-}
  Assign(T, Name);
  Reset(T);
  Err := IOResult;
  if Err = 0 then
  begin
    Close(T);
    Err := IOResult;
    FileExists := True;
  end
  else
    FileExists := False;
  {$I+}
end;

procedure DeleteIfExists(Name: String);
var
  T: Text;
  Err: Byte;
begin
  {$I-}
  Assign(T, Name);
  Erase(T);
  Err := IOResult;
  {$I+}
end;

function ReadRequest: Boolean;
var
  T: Text;
  Err: Byte;
begin
  {$I-}
  Assign(T, TmpFile);
  Reset(T);
  Err := IOResult;
  {$I+}
  if Err <> 0 then
  begin
    ReadRequest := False;
    Exit;
  end;

  {$I-}
  ReadLn(T, Act);
  ReadLn(T, SrcFile);
  ReadLn(T, OutBin);
  ReadLn(T, RowS);
  ReadLn(T, ColS);
  Close(T);
  Err := IOResult;
  {$I+}
  ReadRequest := (Err = 0) and (SrcFile <> '');
end;

procedure WriteErrorFile(var Line: String);
var
  T: Text;
  Err: Byte;
begin
  {$I-}
  Assign(T, ErrFile);
  Rewrite(T);
  Err := IOResult;
  if Err = 0 then
  begin
    WriteLn(T, Line);
    Close(T);
    Err := IOResult;
  end;
  {$I+}
end;

procedure WriteResult(Status: TStr16);
var
  T: Text;
  Err: Byte;
begin
  {$I-}
  Assign(T, TmpFile);
  Rewrite(T);
  Err := IOResult;
  if Err = 0 then
  begin
    WriteLn(T, Status);
    WriteLn(T, SrcFile);
    WriteLn(T, OutBin);
    WriteLn(T, RowS);
    WriteLn(T, ColS);
    Close(T);
    Err := IOResult;
  end;
  {$I+}
end;

{$ifdef SYS_IR4}
  {$i mcp_agon.inc}
{$else}
  {$ifdef SYS_AGON}
    {$i mcp_agon.inc}
  {$else}
    {$ifdef SYS_CPM}
      {$i mcp_cpm.inc}
    {$else}
      {$error mcp targets Agon MOSlet or CP/M-80.}
    {$endif}
  {$endif}
{$endif}

begin
  RunIdeLoop;
end.
