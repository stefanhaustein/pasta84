{ err_asm.inc - Scan compiler/assembler console output via VDP and format error lines }

function ScrChar(X, Y: Integer): Char; external 'pas_scrchar';

procedure ReadScreenRow(Row, MaxCols: Integer; var S: String);
var
  Col, Spaces, Len, LastNonSpace: Integer;
  Ch: Char;
begin
  Ch := ScrChar(0, Row);
  if (Ch = ' ') or (Ch = #0) then
  begin
    SetLength(S, 0);
    Exit;
  end;

  Len := 0;
  LastNonSpace := 0;
  Spaces := 0;
  for Col := 0 to MaxCols - 1 do
  begin
    if Col > 0 then Ch := ScrChar(Col, Row);
    if Ch = #0 then Ch := ' ';
    if Ch = ' ' then
    begin
      Inc(Spaces);
      if Spaces > 3 then Break;
    end
    else
      Spaces := 0;
    if Len < 80 then
    begin
      Inc(Len);
      S[Len] := Ch;
      if Ch <> ' ' then
        LastNonSpace := Len;
    end;
  end;
  SetLength(S, LastNonSpace);
end;

function FormatEz80AsmError(var LineStr: String; var OutErr: String): Boolean;
var
  P, Q, FileEnd, LineStart, LineLen, MsgStart: Integer;
begin
  FormatEz80AsmError := False;
  SetLength(OutErr, 0);

  { PASTA/84 native format: *** Error at <file>(<line>,<col>): <msg> or *** Error: <msg> }
  if (Pos('*** Error at ', LineStr) = 1) or
     (Pos('*** Error: ', LineStr) = 1) then
  begin
    OutErr := LineStr;
    FormatEz80AsmError := True;
    Exit;
  end;

  { ir4c format: error: <msg> or ir4c: <msg> }
  if Pos('error: ', LineStr) = 1 then
  begin
    OutErr := '*** Error: ';
    AppendSub(OutErr, LineStr, 8, 255);
    FormatEz80AsmError := True;
    Exit;
  end;
  if Pos('ir4c: ', LineStr) = 1 then
  begin
    OutErr := '*** Error: ';
    AppendSub(OutErr, LineStr, 7, 255);
    FormatEz80AsmError := True;
    Exit;
  end;

  { ir4c location format: <file>:<line>: error: <msg> }
  P := Pos(': error: ', LineStr);
  if P > 0 then
  begin
    Q := P - 1;
    while (Q > 0) and (LineStr[Q] >= '0') and (LineStr[Q] <= '9') do
      Dec(Q);
    if (Q > 1) and (Q < P - 1) and (LineStr[Q] = ':') then
    begin
      OutErr := '*** Error at ';
      AppendSub(OutErr, LineStr, 1, Q - 1);
      AppendLit(OutErr, '(');
      AppendSub(OutErr, LineStr, Q + 1, P - 1 - Q);
      AppendLit(OutErr, ',1): ');
      AppendSub(OutErr, LineStr, P + 9, 255);
    end
    else
    begin
      OutErr := '*** Error: ';
      AppendSub(OutErr, LineStr, P + 9, 255);
    end;
    FormatEz80AsmError := True;
    Exit;
  end;

  { Expected ez80asm format: File "<name>" line <num> - <msg> }
  if Pos('File "', LineStr) = 1 then
  begin
    FileEnd := 7;
    while (FileEnd <= Length(LineStr)) and (LineStr[FileEnd] <> '"') do
      Inc(FileEnd);
    if FileEnd > Length(LineStr) then Exit;

    P := Pos('line ', LineStr);
    if P <= FileEnd then Exit;
    LineStart := P + 5;
    LineLen := 0;
    while (LineStart + LineLen <= Length(LineStr)) and
          (LineStr[LineStart + LineLen] >= '0') and
          (LineStr[LineStart + LineLen] <= '9') do
      Inc(LineLen);
    if LineLen = 0 then Exit;

    P := Pos(' - ', LineStr);
    if P >= LineStart + LineLen then
      MsgStart := P + 3
    else
      MsgStart := LineStart + LineLen;

    OutErr := '*** Error at ';
    AppendSub(OutErr, LineStr, 7, FileEnd - 7);
    AppendLit(OutErr, '(');
    AppendSub(OutErr, LineStr, LineStart, LineLen);
    AppendLit(OutErr, ',1): ');
    AppendSub(OutErr, LineStr, MsgStart, 255);
    FormatEz80AsmError := True;
    Exit;
  end;

  if Pos('Error', LineStr) = 1 then
  begin
    OutErr := '*** Error: ';
    AppendVar(OutErr, LineStr);
    FormatEz80AsmError := True;
  end;
end;

procedure CaptureAsmErrors(var ErrEntry: String);
var
  Row, LastRow: Integer;
  LineStr, Parsed, Fallback: String;
begin
  SetLength(ErrEntry, 0);
  SetLength(Fallback, 0);
  LastRow := WhereY - 1;
  if LastRow < 0 then Exit;
  if LastRow > 59 then LastRow := 59;

  for Row := LastRow downto 0 do
  begin
    ReadScreenRow(Row, 80, LineStr);
    if Length(LineStr) > 0 then
    begin
      if FormatEz80AsmError(LineStr, Parsed) then
      begin
        if Pos('*** Error at ', Parsed) = 1 then
        begin
          ErrEntry := Parsed;
          Exit;
        end
        else if Length(Fallback) = 0 then
          Fallback := Parsed;
      end;
    end;
  end;
  ErrEntry := Fallback;
end;
