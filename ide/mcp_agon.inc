{ mcp_agon.inc - Agon MOSlet resident IDE runner for mcp }

{$l agon_p.ir4}
{$i err_asm.inc}

var
  Dummy: Char;

function McpOscli(CmdAddr: Integer): Byte; external 'pas_mos_oscli';

procedure McpExec(Command: TStr16; var Params: String);
var
  CmdBuf: String;
  L: Integer;
begin
  CmdBuf := Command;
  if Length(Params) > 0 then
  begin
    AppendLit(CmdBuf, ' ');
    AppendVar(CmdBuf, Params);
  end;
  L := Length(CmdBuf);
  if L = 255 then L := 254;
  CmdBuf[L + 1] := #0;
  DosExitCode := McpOscli(Addr(CmdBuf) + 1);
end;

procedure RunBin(var Path: String; Fallback: TStr16; var Params: String);
var
  Arg: String;
begin
  Arg := Path;
  AppendLit(Arg, ' 0x40000');
  McpExec('load', Arg);
  if (DosExitCode <> 0) and (Fallback <> '') then
  begin
    Arg := Fallback;
    AppendLit(Arg, ' 0x40000');
    McpExec('load', Arg);
  end;
  if DosExitCode <> 0 then Exit;

  Arg := '0x40000';
  if Length(Params) > 0 then
  begin
    AppendLit(Arg, ' ');
    AppendVar(Arg, Params);
  end;
  McpExec('run', Arg);
end;

function HasExt(var Name: String; Ext: TStr16): Boolean;
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

procedure ReplaceExt(var Name: String; NewExt: TStr16; var OutName: String);
var
  I: Integer;
begin
  I := Length(Name);
  while (I > 0) and (Name[I] <> '.') and (Name[I] <> '/') do
    Dec(I);
  OutName := Name;
  if (I > 0) and (Name[I] = '.') then
    SetLength(OutName, I - 1);
  AppendLit(OutName, NewExt);
end;

procedure RunTool(Name: TStr16; var Params: String);
var
  Path: String;
begin
  Path := '/bin/';
  AppendLit(Path, Name);
  RunBin(Path, Name, Params);
end;

function RunIr4c(var InFile: String): Boolean;
var
  Params: String;
begin
  WriteLn('Compiling ', InFile, ' -> ', OutBin, '...');
  Params := '-t agon -I /pasta84/rtl -I /lib -o ';
  AppendVar(Params, OutBin);
  AppendLit(Params, ' ');
  AppendVar(Params, InFile);
  RunTool('ir4c.bin', Params);
  RunIr4c := (DosExitCode = 0) and FileExists(OutBin);
end;

procedure RunIdeLoop;
var
  BinOk: Boolean;
  ErrEntry, Ir4File, Params: String;
begin
  if ParamCount >= 1 then
    SrcFile := ParamStr(1)
  else
    SetLength(SrcFile, 0);

  WriteLn('Loading pano...');

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
    WriteLn('I wish I could get eZ80 support in Spectrum Next for Christmas...');
    WriteLn;
    DeleteIfExists(OutBin);
    DeleteIfExists(ErrFile);
    WriteLn('Building ', SrcFile, '...');

    if HasExt(SrcFile, '.pas') then
    begin
      ReplaceExt(SrcFile, '.ir4', Ir4File);
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
      Params := SrcFile;
      AppendLit(Params, ' ');
      AppendVar(Params, OutBin);
      AppendLit(Params, ' -c');
      RunTool('ez80asm.bin', Params);
      BinOk := (DosExitCode = 0) and FileExists(OutBin);
    end;

    if BinOk then
    begin
      WriteResult('OK');
      if Act = 'R' then
      begin
        WriteLn;
        WriteLn('Running ', OutBin, '...');
        SetLength(Params, 0);
        RunBin(OutBin, '', Params);
        WriteLn;
        Write('Press any key to return to pano...');
        Dummy := ReadKey;
        WriteLn(' Returning to pano...');
      end
      else
        WriteLn('Returning to pano...');
    end
    else
    begin
      CaptureAsmErrors(ErrEntry);
      if Length(ErrEntry) > 0 then
        WriteErrorFile(ErrEntry);
      WriteResult('ERR');
      WriteLn;
      WriteLn('Build failed. Returning to pano...');
    end;
  end;
end;
