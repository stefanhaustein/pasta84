{ mcp_agon.inc - Agon MOSlet resident IDE runner for mcp }

{$ifdef SYS_IR4}
{$l agon_p.ir4}
{$endif}
{$i err_asm.inc}
{$ifndef SYS_IR4}
{$l mcposcli.asm}
{$endif}

var
  Dummy: Char;

{$ifdef SYS_IR4}
function McpOscli(CmdAddr: Integer): Byte; external 'pas_mos_oscli';
{$else}
function McpOscli(CmdAddr: Integer): Byte; register; external '__mcp_oscli';
{$endif}

procedure McpExec(Command, Params: TStr80);
var
  Temp: String;
begin
  if Params = '' then
    Temp := Command + #00
  else
    Temp := Command + ' ' + Params + #00;
  DosExitCode := McpOscli(Addr(Temp) + 1);
end;

procedure RunBin(Path, Fallback, Params: TStr80);
begin
  McpExec('load', Path + ' 0x40000');
  if (DosExitCode <> 0) and (Fallback <> '') then
    McpExec('load', Fallback + ' 0x40000');
  if DosExitCode <> 0 then Exit;

  if Params <> '' then
    McpExec('run', '0x40000 ' + Params)
  else
    McpExec('run', '0x40000');
end;

function HasExt(Name, Ext: TStr80): Boolean;
var
  I, LName, LExt: Integer;
  C1, C2: Char;
begin
  LName := Length(Name);
  LExt := Length(Ext);
  if LName < LExt then
  begin
    HasExt := False;
    Exit;
  end;
  for I := 1 to LExt do
  begin
    C1 := Name[LName - LExt + I];
    C2 := Ext[I];
    if (C1 >= 'A') and (C1 <= 'Z') then C1 := Chr(Ord(C1) + 32);
    if (C2 >= 'A') and (C2 <= 'Z') then C2 := Chr(Ord(C2) + 32);
    if C1 <> C2 then
    begin
      HasExt := False;
      Exit;
    end;
  end;
  HasExt := True;
end;

function ReplaceExt(Name, NewExt: TStr80): TStr80;
var
  I: Integer;
begin
  I := Length(Name);
  while (I > 0) and (Name[I] <> '.') and (Name[I] <> '/') do
    Dec(I);
  if (I > 0) and (Name[I] = '.') then
    ReplaceExt := Copy(Name, 1, I - 1) + NewExt
  else
    ReplaceExt := Name + NewExt;
end;

procedure RunTool(Name, Params: TStr80);
begin
  RunBin('/bin/' + Name, Name, Params);
end;

function RunIr4c(InFile: TStr80): Boolean;
begin
  WriteLn('Compiling ', InFile, ' -> ', OutBin, '...');
  RunTool('ir4c.bin', '-t agon -I /pasta84/rtl -I /lib -o ' + OutBin + ' ' + InFile);
  RunIr4c := (DosExitCode = 0) and FileExists(OutBin);
end;

procedure RunIdeLoop;
var
  BinOk: Boolean;
  ErrEntry: String;
  Ir4File: TStr80;
begin
  if ParamCount >= 1 then
    SrcFile := ParamStr(1)
  else
    SrcFile := '';

  while True do
  begin
    RunTool('pano.bin', SrcFile);
    if DosExitCode <> 0 then
    begin
      WriteLn('Error launching pano.bin (code ', DosExitCode, ')');
      Break;
    end;

    if not ReadRequest then
      Break;

    Write(#12);
    DeleteIfExists(OutBin);
    DeleteIfExists(ErrFile);
    WriteLn('Building ', SrcFile, '...');

    if HasExt(SrcFile, '.pas') then
    begin
      Ir4File := ReplaceExt(SrcFile, '.ir4');
      DeleteIfExists(Ir4File);
      RunTool('pasta84.bin', SrcFile);
      BinOk := (DosExitCode = 0) and FileExists(Ir4File);
      if BinOk then
        BinOk := RunIr4c(Ir4File);
    end
    else if HasExt(SrcFile, '.ir4') then
    begin
      BinOk := RunIr4c(SrcFile);
    end
    else
    begin
      RunTool('ez80asm.bin', SrcFile + ' ' + OutBin + ' -c');
      BinOk := (DosExitCode = 0) and FileExists(OutBin);
    end;

    if BinOk then
    begin
      WriteResult('OK');
      if Act = 'R' then
      begin
        WriteLn;
        WriteLn('Running ', OutBin, '...');
        RunBin(OutBin, '', '');
        WriteLn;
        Write('Press any key to return to pano...');
        Dummy := ReadKey;
      end;
    end
    else
    begin
      CaptureAsmErrors(ErrEntry);
      if ErrEntry <> '' then
        WriteErrorFile(ErrEntry);
      WriteResult('ERR');
      WriteLn;
      WriteLn('Assembly failed.');
    end;
  end;
end;
