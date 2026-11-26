{ fileio.inc - File loading, WriteOut (^O), and modified-buffer exit prompt }

procedure SanitizeLine(var S: String);
var
  OutS: String;
  I, Spaces, K: Integer;
  C: Char;
begin
  OutS := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C = #9 then
    begin
      Spaces := 4 - (Length(OutS) mod 4);
      for K := 1 to Spaces do
        if Length(OutS) < 255 then
          OutS := OutS + ' ';
    end
    else if (C >= #32) and (C <= #126) then
    begin
      if Length(OutS) < 255 then
        OutS := OutS + C;
    end;
    if Length(OutS) >= 255 then Break;
  end;
  S := OutS;
end;

function TrimSpaces(S: TFileName): TFileName;
var
  A, B: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] = ' ') do Inc(A);
  while (B >= A) and (S[B] = ' ') do Dec(B);
  if A > B then
    TrimSpaces := ''
  else
    TrimSpaces := Copy(S, A, B - A + 1);
end;

procedure LoadFile(Name: TFileName);
var
  F: Text;
  S: String;
  NumS: String[8];
  P: PString;
  Err: Byte;
  Count: Integer;
  Truncated: Boolean;
begin
  FreeAllLines;
  FileName := TrimSpaces(Name);
  if FileName = '' then Exit;

  {$I-}
  Assign(F, FileName);
  Reset(F);
  Err := IOResult;
  {$I+}

  if Err <> 0 then
  begin
    if Err = ErrFileNotFound then
      StatusMsg := '[ New File ]'
    else
    begin
      Str(Err, NumS);
      StatusMsg := '[ Open error #' + NumS + ' (new buffer) ]';
    end;
    Exit;
  end;

  Count := 0;
  Truncated := False;
  while (not Eof(F)) and (Err = 0) do
  begin
    if Count >= MaxLines then
    begin
      Truncated := True;
      StatusMsg := '[ File truncated at line limit ]';
      Break;
    end;

    {$I-}
    ReadLn(F, S);
    Err := IOResult;
    {$I+}
    if Err <> 0 then Break;

    SanitizeLine(S);
    if not AllocStr(S, P) then
    begin
      Truncated := True;
      StatusMsg := '[ Out of memory (file truncated) ]';
      Break;
    end;

    Inc(Count);
    Lines[Count] := P;
  end;

  {$I-}
  Close(F);
  if Err = 0 then Err := IOResult;
  {$I+}

  if Count > 0 then
    TotalLines := Count
  else
    TotalLines := 1;

  CurRow := 1;
  CurCol := 1;
  TopLine := 1;
  ColOffset := 0;
  LoadCurLine;
  Modified := False;

  if Err <> 0 then
  begin
    Str(Err, NumS);
    StatusMsg := '[ Read error #' + NumS + ' ]';
  end
  else if not Truncated then
  begin
    Str(Count, NumS);
    if Count = 1 then
      StatusMsg := '[ Read 1 line ]'
    else
      StatusMsg := '[ Read ' + NumS + ' lines ]';
  end;
end;

function PromptLine(Prompt: String; var Value: TFileName): Boolean;
var
  Ch: Char;
  Ev, MaxLen, VisStart, PromptLen: Integer;
begin
  PromptLen := Length(Prompt);
  MaxLen := VisCols - 1 - PromptLen;
  if MaxLen < 1 then MaxLen := 1;

  while True do
  begin
    CursorOff;
    GotoXY(1, StatusRow);
    SetChromeColors;
    Write(Prompt);
    SetBarColors;
    if Length(Value) > MaxLen then
      VisStart := Length(Value) - MaxLen + 1
    else
      VisStart := 1;
    Write(' ', Copy(Value, VisStart, MaxLen));
    ClrEol;
    GotoXY(PromptLen + 2 + (Length(Value) - VisStart + 1), StatusRow);
    CursorOn;

    Ev := ReadKeyEvent(Ch);
    if (Ev = evEsc) or (Ev = evExit) or (Ev = evCancel) then
    begin
      PromptLine := False;
      Exit;
    end
    else if Ev = evEnter then
    begin
      PromptLine := True;
      Exit;
    end
    else if Ev = evBacksp then
    begin
      if Length(Value) > 0 then
        Delete(Value, Length(Value), 1);
    end
    else if Ev = evChar then
    begin
      if Length(Value) < 64 then
        Value := Value + Ch;
    end;
  end;
end;

function SaveFile(Name: TFileName): Boolean;
var
{$ifdef SYS_AGON}
  R: Registers;
  CName: String[66];
  Buf: array[0..257] of Char;
  H, Ignored: Byte;
  L, Len: Integer;
{$else}
  F: Text;
  CloseErr: Byte;
{$endif}
  NumS: String[8];
  Err: Byte;
  I: Integer;
begin
  if Name = '' then
  begin
    StatusMsg := '[ Cancelled ]';
    SaveFile := False;
    Exit;
  end;

  if not CommitCurLine then
  begin
    SaveFile := False;
    Exit;
  end;

{$ifdef SYS_AGON}
  CName := Name + #0;
  R.HL := Addr(CName) + 1;
  R.BC := $0B;
  H := MOSAPI($0A, R);
  if H = 0 then
  begin
    StatusMsg := '[ Error writing file (#1) ]';
    SaveFile := False;
    Exit;
  end;

  Err := 0;
  for I := 1 to TotalLines do
  begin
    if Lines[I] = nil then
      L := 0
    else
    begin
      L := Length(Lines[I]^);
      if L > 255 then L := 255;
      if L > 0 then
        Move(Lines[I]^[1], Buf[0], L);
    end;
    Buf[L] := #13;
    Buf[L + 1] := #10;
    Len := L + 2;

    R.C := H;
    R.HL := Addr(Buf[0]);
    R.DE := Len;
    Ignored := MOSAPI($1B, R);
    if R.DE <> Len then
    begin
      Err := 1;
      Break;
    end;
  end;

  R.C := H;
  Ignored := MOSAPI($0B, R);
  if Err <> 0 then
  begin
    StatusMsg := '[ Error writing file (#1) ]';
    SaveFile := False;
    Exit;
  end;
{$else}
  {$I-}
  Assign(F, Name);
  Rewrite(F);
  Err := IOResult;
  {$I+}

  if Err <> 0 then
  begin
    Str(Err, NumS);
    StatusMsg := '[ Error writing file (#' + NumS + ') ]';
    SaveFile := False;
    Exit;
  end;

  for I := 1 to TotalLines do
  begin
    {$I-}
    if Lines[I] = nil then
      WriteLn(F, '')
    else
      WriteLn(F, Lines[I]^);
    Err := IOResult;
    {$I+}
    if Err <> 0 then Break;
  end;

  {$I-}
  Close(F);
  CloseErr := IOResult;
  {$I+}
  if Err = 0 then Err := CloseErr;

  if Err <> 0 then
  begin
    Str(Err, NumS);
    StatusMsg := '[ Error writing file (#' + NumS + ') ]';
    SaveFile := False;
    Exit;
  end;
{$endif}

  FileName := Name;
  Modified := False;
  Str(TotalLines, NumS);
  if TotalLines = 1 then
    StatusMsg := '[ Wrote 1 line ]'
  else
    StatusMsg := '[ Wrote ' + NumS + ' lines ]';
  SaveFile := True;
end;

function DoWriteOut: Boolean;
var
  Name: TFileName;
begin
  Name := FileName;
  if not PromptLine('File Name to Write:', Name) then
  begin
    StatusMsg := '[ Cancelled ]';
    DoWriteOut := False;
    Exit;
  end;
  Name := TrimSpaces(Name);
  if Name = '' then
  begin
    StatusMsg := '[ Cancelled ]';
    DoWriteOut := False;
    Exit;
  end;
  DoWriteOut := SaveFile(Name);
end;

procedure ClearIdeState;
var
  F: File;
  Err: Byte;
begin
  {$I-}
  Assign(F, 'PANO.TMP');
  Erase(F);
  Err := IOResult;
  {$I+}
end;

function MakeOutBin(Name: TFileName): TFileName;
var
  I, DotPos: Integer;
begin
  DotPos := 0;
  for I := Length(Name) downto 1 do
  begin
    if Name[I] = '/' then Break;
    if Name[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  end;
  if DotPos > 0 then
    MakeOutBin := Copy(Name, 1, DotPos - 1) +
      {$ifdef SYS_AGON} '.bin' {$else} '.com' {$endif}
  else
    MakeOutBin := Name +
      {$ifdef SYS_AGON} '.bin' {$else} '.com' {$endif};
end;

procedure DoIdeAction(Act: Char);
var
  T: Text;
  Err: Byte;
begin
  if FileName = '' then
  begin
    if not DoWriteOut then Exit;
  end
  else if Modified then
  begin
    if not SaveFile(FileName) then Exit;
  end
  else if not CommitCurLine then
    Exit;

  {$I-}
  Assign(T, 'PANO.TMP');
  Rewrite(T);
  Err := IOResult;
  if Err = 0 then
  begin
    WriteLn(T, Act);
    WriteLn(T, FileName);
    WriteLn(T, MakeOutBin(FileName));
    WriteLn(T, CurRow);
    WriteLn(T, CurCol);
    Close(T);
    Err := IOResult;
  end;
  {$I+}

  if Err <> 0 then
  begin
    StatusMsg := '[ Cannot write PANO.TMP ]';
    Exit;
  end;
  Running := False;
end;

function ParseErrorLine(S: String; var ErrFile: TFileName;
                        var ErrRow, ErrCol: Integer;
                        var ErrMsg: TStatusMsg): Boolean;
var
  LP, Comma, RP, Code: Integer;
  NumS: String[8];
begin
  ParseErrorLine := False;

  { PASTA/80 format: *** Error at <file>(<line>,<col>): <msg> }
  if Copy(S, 1, 13) = '*** Error at ' then
  begin
    Delete(S, 1, 13);
    LP := Pos('(', S);
    if LP = 0 then Exit;
    ErrFile := Copy(S, 1, LP - 1);
    Delete(S, 1, LP);

    Comma := Pos(',', S);
    if Comma = 0 then Exit;
    NumS := Copy(S, 1, Comma - 1);
    Val(NumS, ErrRow, Code);
    if Code <> 0 then ErrRow := 1;
    Delete(S, 1, Comma);

    RP := Pos('): ', S);
    if RP = 0 then Exit;
    NumS := Copy(S, 1, RP - 1);
    Val(NumS, ErrCol, Code);
    if Code <> 0 then ErrCol := 1;
    Delete(S, 1, RP + 2);

    ErrMsg := Copy(S, 1, 76);
    ParseErrorLine := True;
    Exit;
  end;

  { PASTA/80 locationless format: *** Error: <msg> }
  if Copy(S, 1, 11) = '*** Error: ' then
  begin
    ErrFile := '';
    ErrRow := 0;
    ErrCol := 0;
    ErrMsg := Copy(S, 12, 76);
    ParseErrorLine := True;
  end;
end;

procedure ResumeIdeState;
var
  T: Text;
  St, Src, OutB, RowS, ColS, ErrFile: TFileName;
  LineS: String;
  ErrMsg: TStatusMsg;
  Err: Byte;
  R, C, ErrRow, ErrCol, Code: Integer;
  HasErr: Boolean;
begin
  {$I-}
  Assign(T, 'PANO.TMP');
  Reset(T);
  Err := IOResult;
  {$I+}
  if Err <> 0 then Exit;

  {$I-}
  ReadLn(T, St);
  ReadLn(T, Src);
  ReadLn(T, OutB);
  ReadLn(T, RowS);
  ReadLn(T, ColS);
  Close(T);
  Err := IOResult;
  {$I+}
  ClearIdeState;

  if (FileName = '') and (Src <> '') then
    LoadFile(Src);

  HasErr := False;
  ErrMsg := '';
  ErrRow := 0;
  ErrCol := 1;
  ErrFile := '';

  if St = 'ERR' then
  begin
    {$I-}
    Assign(T, 'PANO.ERR');
    Reset(T);
    Err := IOResult;
    if Err = 0 then
    begin
      while (not Eof(T)) and (Err = 0) do
      begin
        ReadLn(T, LineS);
        Err := IOResult;
        if (Err = 0) and (not HasErr) and (LineS <> '') then
          HasErr := ParseErrorLine(LineS, ErrFile, ErrRow, ErrCol, ErrMsg);
      end;
      Close(T);
      Err := IOResult;
    end;
    {$I+}
  end;

  if (St = 'ERR') and HasErr and (ErrRow > 0) then
  begin
    if (ErrFile <> '') and (ErrFile <> FileName) then
      LoadFile(ErrFile);
    R := ErrRow;
    C := ErrCol;
    if R < 1 then R := 1;
    if R > TotalLines then R := TotalLines;
    if C < 1 then C := 1;
    if MoveToRow(R) then
    begin
      CurCol := C;
      ClampCol;
      EnsureVisible;
    end;
    StatusMsg := '[ ' + ErrMsg + ' ]';
    Exit;
  end;

  Val(RowS, R, Code);
  if (Code = 0) and (R >= 1) and (R <= TotalLines) then
    if MoveToRow(R) then
    begin
      Val(ColS, C, Code);
      if Code = 0 then
      begin
        CurCol := C;
        ClampCol;
      end;
      EnsureVisible;
    end;

  if St = 'OK' then
    StatusMsg := '[ Assembled ' + OutB + ' ]'
  else if St = 'ERR' then
  begin
    if HasErr and (ErrMsg <> '') then
      StatusMsg := '[ ' + ErrMsg + ' ]'
    else
      StatusMsg := '[ Assembly failed ]';
  end;
end;

procedure DoExit;
var
  Ch: Char;
  Ev: Integer;
begin
  if not Modified then
  begin
    if HasIdeRunner then ClearIdeState;
    Running := False;
    Exit;
  end;

  CursorOff;
  GotoXY(1, StatusRow);
  SetChromeColors;
  Write('Save modified buffer? (Y/N/ESC)');
  SetBarColors;
  Write(' ');
  ClrEol;
  CursorOn;

  while True do
  begin
    Ev := ReadKeyEvent(Ch);
    if (Ev = evChar) and (UpCase(Ch) = 'Y') then
    begin
      if DoWriteOut then
      begin
        if HasIdeRunner then ClearIdeState;
        Running := False;
      end;
      Exit;
    end
    else if (Ev = evChar) and (UpCase(Ch) = 'N') then
    begin
      if HasIdeRunner then ClearIdeState;
      Running := False;
      Exit;
    end
    else if (Ev = evEsc) or (Ev = evCancel) or
            ((Ev = evChar) and (UpCase(Ch) = 'C')) then
    begin
      StatusMsg := '[ Cancelled ]';
      Exit;
    end;
  end;
end;
