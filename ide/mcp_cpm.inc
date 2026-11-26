{ mcp_cpm.inc - Native CP/M $$$.SUB step runner for mcp }

const
  SubFile         = 'A:$$$.SUB';
  DefaultCompiler = 'PASTA80';

type
  TSubRec = array[0..127] of Char;

procedure MakeSubRec(Cmd: TStr80; var Rec: TSubRec);
var
  I, L: Integer;
begin
  FillChar(Rec, 128, #0);
  L := Length(Cmd);
  if L > 125 then L := 125;
  Rec[0] := Chr(L);
  for I := 1 to L do
    Rec[I] := UpCase(Cmd[I]);
end;

procedure WriteSub(Cmd1, Cmd2: TStr80);
var
  F: File;
  Rec: TSubRec;
  Err: Byte;
begin
  {$I-}
  Assign(F, SubFile);
  Rewrite(F);
  Err := IOResult;
  if Err = 0 then
  begin
    { CP/M CCP executes A:$$$.SUB records from last to first }
    if Cmd2 <> '' then
    begin
      MakeSubRec(Cmd2, Rec);
      BlockWrite(F, Rec, 1);
    end;
    if Cmd1 <> '' then
    begin
      MakeSubRec(Cmd1, Rec);
      BlockWrite(F, Rec, 1);
    end;
    Close(F);
    Err := IOResult;
  end;
  {$I+}
end;

function StripComExt(Name: TStr80): TStr80;
var
  I: Integer;
begin
  for I := Length(Name) downto 1 do
  begin
    if Name[I] = '.' then
    begin
      StripComExt := Copy(Name, 1, I - 1);
      Exit;
    end;
    if Name[I] = ':' then Break;
  end;
  StripComExt := Name;
end;

function HasExt(Name, Ext: TStr80): Boolean;
var
  L, EL, I: Integer;
begin
  L := Length(Name);
  EL := Length(Ext);
  if L < EL then
  begin
    HasExt := False;
    Exit;
  end;
  for I := 1 to EL do
    if UpCase(Name[L - EL + I]) <> UpCase(Ext[I]) then
    begin
      HasExt := False;
      Exit;
    end;
  HasExt := True;
end;

procedure RunIdeLoop;
var
  BinOk: Boolean;
  BuildCmd: TStr80;
begin
  if not ReadRequest then
  begin
    if ParamCount >= 1 then
    begin
      SrcFile := ParamStr(1);
      WriteSub('PANO ' + SrcFile, 'MCP');
    end
    else
      DeleteIfExists(SubFile);
    Exit;
  end;

  if (Act = 'C') or (Act = 'R') then
  begin
    WriteLn('Building ', SrcFile, ' -> ', OutBin, '...');
    DeleteIfExists(OutBin);
    DeleteIfExists(ErrFile);
    if Act = 'R' then
      WriteResult('BUILDR')
    else
      WriteResult('BUILD');
    if HasExt(SrcFile, '.PAS') then
      BuildCmd := DefaultCompiler + ' ' + SrcFile
    else
      BuildCmd := 'Z80ASM ' + StripComExt(SrcFile) + '/F';
    WriteSub(BuildCmd, 'MCP');
  end
  else if (Act = 'BUILD') or (Act = 'BUILDR') then
  begin
    BinOk := FileExists(OutBin);
    if BinOk then
    begin
      WriteResult('OK');
      if Act = 'BUILDR' then
        WriteSub(StripComExt(OutBin), 'PANO ' + SrcFile)
      else
        WriteSub('PANO ' + SrcFile, '');
    end
    else
    begin
      WriteResult('ERR');
      WriteSub('PANO ' + SrcFile, '');
    end;
  end
  else
  begin
    DeleteIfExists(TmpFile);
    DeleteIfExists(SubFile);
  end;
end;
