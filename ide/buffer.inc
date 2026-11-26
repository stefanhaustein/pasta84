{ buffer.inc - Active-line scratch buffer and packed heap line array for pano }

function GetLineLen(Row: Integer): Integer;
begin
  if Row = CurRow then
    GetLineLen := Length(CurLine)
  else if (Row >= 1) and (Row <= TotalLines) and (Lines[Row] <> nil) then
    GetLineLen := Length(Lines[Row]^)
  else
    GetLineLen := 0;
end;

procedure ClampCol;
var
  L: Integer;
begin
  L := Length(CurLine);
  if CurCol > L + 1 then CurCol := L + 1;
  if CurCol < 1 then CurCol := 1;
end;

procedure FreeStr(var P: PString);
begin
  if P <> nil then
  begin
    FreeMem(P, Length(P^) + 1);
    P := nil;
  end;
end;

function AllocStr(S: String; var P: PString): Boolean;
var
  Need, NeedChk: Integer;
begin
  if S = '' then
  begin
    P := nil;
    AllocStr := True;
    Exit;
  end;

  Need := Length(S) + 1;
  NeedChk := Need;
  if NeedChk < 4 then NeedChk := 4;

  if MaxAvail < NeedChk then
  begin
    DefragMem;
    if MaxAvail < NeedChk then
    begin
      StatusMsg := '[ Out of memory ]';
      AllocStr := False;
      Exit;
    end;
  end;

  GetMem(P, Need);
  Move(S, P^, Need);
  AllocStr := True;
end;

procedure LoadCurLine;
begin
  if Lines[CurRow] = nil then
    CurLine := ''
  else
    CurLine := Lines[CurRow]^;
  CurLineDirty := False;
end;

function CommitCurLine: Boolean;
var
  NewP: PString;
begin
  if not CurLineDirty then
  begin
    CommitCurLine := True;
    Exit;
  end;

  if CurLine = '' then
  begin
    FreeStr(Lines[CurRow]);
    CurLineDirty := False;
    CommitCurLine := True;
    Exit;
  end;

  if not AllocStr(CurLine, NewP) then
  begin
    CommitCurLine := False;
    Exit;
  end;

  FreeStr(Lines[CurRow]);
  Lines[CurRow] := NewP;
  CurLineDirty := False;
  CommitCurLine := True;
end;

function MoveToRow(NewRow: Integer): Boolean;
begin
  if NewRow = CurRow then
  begin
    MoveToRow := True;
    Exit;
  end;
  if not CommitCurLine then
  begin
    MoveToRow := False;
    Exit;
  end;
  CurRow := NewRow;
  LoadCurLine;
  MoveToRow := True;
end;

procedure InitBuffer;
var
  I: Integer;
begin
  for I := 1 to MaxLines do
    Lines[I] := nil;
  TotalLines := 1;
  CurRow := 1;
  CurCol := 1;
  TopLine := 1;
  ColOffset := 0;
  CurLine := '';
  CurLineDirty := False;
  CutLine := '';
  HasCut := False;
  Modified := False;
end;

procedure FreeAllLines;
var
  I: Integer;
begin
  for I := 1 to MaxLines do
    FreeStr(Lines[I]);
  TotalLines := 1;
  CurRow := 1;
  CurCol := 1;
  TopLine := 1;
  ColOffset := 0;
  CurLine := '';
  CurLineDirty := False;
  Modified := False;
end;

function InsertChar(Ch: Char): Boolean;
var
  S: String;
begin
  if Length(CurLine) >= 255 then
  begin
    StatusMsg := '[ Line limit (255 chars) reached ]';
    InsertChar := False;
    Exit;
  end;
  S := Ch;
  Insert(S, CurLine, CurCol);
  Inc(CurCol);
  CurLineDirty := True;
  Modified := True;
  InsertChar := True;
end;

function DeleteCharBefore(var Joined: Boolean): Boolean;
var
  PrevLen: Integer;
  Merged: String;
  I: Integer;
begin
  Joined := False;
  if CurCol > 1 then
  begin
    Delete(CurLine, CurCol - 1, 1);
    Dec(CurCol);
    CurLineDirty := True;
    Modified := True;
    DeleteCharBefore := True;
    Exit;
  end;

  if CurRow <= 1 then
  begin
    DeleteCharBefore := False;
    Exit;
  end;

  PrevLen := GetLineLen(CurRow - 1);
  if PrevLen + Length(CurLine) > 255 then
  begin
    StatusMsg := '[ Joined line would exceed 255 chars ]';
    DeleteCharBefore := False;
    Exit;
  end;

  if Lines[CurRow - 1] <> nil then
    Merged := Lines[CurRow - 1]^ + CurLine
  else
    Merged := CurLine;

  FreeStr(Lines[CurRow]);
  for I := CurRow to TotalLines - 1 do
    Lines[I] := Lines[I + 1];
  Lines[TotalLines] := nil;
  Dec(TotalLines);

  Dec(CurRow);
  CurLine := Merged;
  CurLineDirty := True;
  CurCol := PrevLen + 1;
  Modified := True;
  Joined := True;
  DeleteCharBefore := True;
end;

function DeleteCharAt(var Joined: Boolean): Boolean;
var
  NextText: String;
  I: Integer;
begin
  Joined := False;
  if CurCol <= Length(CurLine) then
  begin
    Delete(CurLine, CurCol, 1);
    CurLineDirty := True;
    Modified := True;
    DeleteCharAt := True;
    Exit;
  end;

  if CurRow >= TotalLines then
  begin
    DeleteCharAt := False;
    Exit;
  end;

  if Lines[CurRow + 1] <> nil then
    NextText := Lines[CurRow + 1]^
  else
    NextText := '';

  if Length(CurLine) + Length(NextText) > 255 then
  begin
    StatusMsg := '[ Joined line would exceed 255 chars ]';
    DeleteCharAt := False;
    Exit;
  end;

  CurLine := CurLine + NextText;
  CurLineDirty := True;

  FreeStr(Lines[CurRow + 1]);
  for I := CurRow + 1 to TotalLines - 1 do
    Lines[I] := Lines[I + 1];
  Lines[TotalLines] := nil;
  Dec(TotalLines);

  Modified := True;
  Joined := True;
  DeleteCharAt := True;
end;

function SplitLine: Boolean;
var
  Head, Tail: String;
  HeadP: PString;
  I: Integer;
begin
  if TotalLines >= MaxLines then
  begin
    StatusMsg := '[ Max lines reached ]';
    SplitLine := False;
    Exit;
  end;

  Head := Copy(CurLine, 1, CurCol - 1);
  if CurCol <= Length(CurLine) then
    Tail := Copy(CurLine, CurCol, Length(CurLine) - CurCol + 1)
  else
    Tail := '';

  if not AllocStr(Head, HeadP) then
  begin
    SplitLine := False;
    Exit;
  end;

  FreeStr(Lines[CurRow]);
  Lines[CurRow] := HeadP;

  for I := TotalLines downto CurRow + 1 do
    Lines[I + 1] := Lines[I];
  Inc(TotalLines);

  Inc(CurRow);
  Lines[CurRow] := nil;
  CurLine := Tail;
  CurLineDirty := (Tail <> '');
  CurCol := 1;
  Modified := True;
  SplitLine := True;
end;

procedure CutCurrentLine;
var
  I: Integer;
begin
  CutLine := CurLine;
  HasCut := True;

  if TotalLines = 1 then
  begin
    FreeStr(Lines[1]);
    CurLine := '';
    CurLineDirty := False;
    CurCol := 1;
  end
  else
  begin
    FreeStr(Lines[CurRow]);
    for I := CurRow to TotalLines - 1 do
      Lines[I] := Lines[I + 1];
    Lines[TotalLines] := nil;
    Dec(TotalLines);
    if CurRow > TotalLines then
      CurRow := TotalLines;
    LoadCurLine;
    ClampCol;
  end;
  Modified := True;
end;

function UncutLine: Boolean;
var
  P: PString;
  I: Integer;
begin
  if not HasCut then
  begin
    StatusMsg := '[ Cut buffer is empty ]';
    UncutLine := False;
    Exit;
  end;
  if TotalLines >= MaxLines then
  begin
    StatusMsg := '[ Max lines reached ]';
    UncutLine := False;
    Exit;
  end;
  if not CommitCurLine then
  begin
    UncutLine := False;
    Exit;
  end;
  if not AllocStr(CutLine, P) then
  begin
    UncutLine := False;
    Exit;
  end;

  for I := TotalLines downto CurRow do
    Lines[I + 1] := Lines[I];
  Lines[CurRow] := P;
  Inc(TotalLines);

  Inc(CurRow);
  LoadCurLine;
  ClampCol;
  Modified := True;
  UncutLine := True;
end;
