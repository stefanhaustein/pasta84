{ err_asm.inc - Scan ez80asm console output via VDP and format standardized error lines }

{$ifdef SYS_IR4}
function ScrChar(X, Y: Integer): Char; external 'pas_scrchar';
{$else}
{$l scrchar.asm}

function ScrChar(X, Y: Integer): Char; register; external '__scrchar';
{$endif}

procedure ReadScreenRow(Row, MaxCols: Integer; var S: String);
var
  Col, Spaces: Integer;
  Ch: Char;
begin
  Ch := ScrChar(0, Row);
  if (Ch = ' ') or (Ch = #0) then
  begin
    S := '';
    Exit;
  end;

  S := '';
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
    if Length(S) < 80 then
      S := S + Ch;
  end;

  while (Length(S) > 0) and (S[Length(S)] = ' ') do
    Delete(S, Length(S), 1);
end;

function FormatEz80AsmError(var LineStr: String; var OutErr: String): Boolean;
var
  P, Q, LineNumEnd: Integer;
  ErrFile, LineNumS, ErrMsg: String;
begin
  FormatEz80AsmError := False;
  OutErr := '';
  ErrFile := '';

  { PASTA/84 native format: *** Error at <file>(<line>,<col>): <msg> or *** Error: <msg> }
  if (Copy(LineStr, 1, 13) = '*** Error at ') or
     (Copy(LineStr, 1, 11) = '*** Error: ') then
  begin
    OutErr := LineStr;
    FormatEz80AsmError := True;
    Exit;
  end;

  { ir4c format: <file>:<line>: error: <msg> or error: <msg> }
  if Copy(LineStr, 1, 7) = 'error: ' then
  begin
    OutErr := '*** Error: ' + Copy(LineStr, 8, 255);
    FormatEz80AsmError := True;
    Exit;
  end;
  P := Pos(': error: ', LineStr);
  if P > 0 then
  begin
    ErrMsg := Copy(LineStr, P + 9, 255);
    ErrFile := Copy(LineStr, 1, P - 1);
    Q := Length(ErrFile);
    while (Q > 0) and (ErrFile[Q] >= '0') and (ErrFile[Q] <= '9') do
      Dec(Q);
    if (Q > 1) and (Q < Length(ErrFile)) and (ErrFile[Q] = ':') then
    begin
      LineNumS := Copy(ErrFile, Q + 1, 255);
      ErrFile := Copy(ErrFile, 1, Q - 1);
    end
    else
      ErrFile := '';
  end
  { Expected ez80asm format: File "<name>" line <num> - <msg> }
  else if Copy(LineStr, 1, 6) = 'File "' then
  begin
    Delete(LineStr, 1, 6);
    Q := Pos('"', LineStr);
    if Q = 0 then Exit;
    ErrFile := Copy(LineStr, 1, Q - 1);
    Delete(LineStr, 1, Q);

    P := Pos('line ', LineStr);
    if P = 0 then Exit;
    Delete(LineStr, 1, P + 4);

    LineNumEnd := 1;
    while (LineNumEnd <= Length(LineStr)) and
          (LineStr[LineNumEnd] >= '0') and (LineStr[LineNumEnd] <= '9') do
      Inc(LineNumEnd);
    if LineNumEnd = 1 then Exit;
    LineNumS := Copy(LineStr, 1, LineNumEnd - 1);

    P := Pos(' - ', LineStr);
    if P > 0 then
      ErrMsg := Copy(LineStr, P + 3, 255)
    else
      ErrMsg := Copy(LineStr, LineNumEnd, 255);
  end;

  if ErrFile <> '' then
  begin
    OutErr := '*** Error at ' + ErrFile + '(' + LineNumS + ',1): ' + ErrMsg;
    FormatEz80AsmError := True;
    Exit;
  end;

  if Copy(LineStr, 1, 5) = 'Error' then
  begin
    OutErr := '*** Error: ' + LineStr;
    FormatEz80AsmError := True;
  end;
end;

procedure CaptureAsmErrors(var ErrEntry: String);
var
  Row, LastRow: Integer;
  LineStr, Parsed, Fallback: String;
begin
  ErrEntry := '';
  Fallback := '';
  LastRow := WhereY - 1;
  if LastRow < 0 then Exit;
  if LastRow > 59 then LastRow := 59;

  for Row := LastRow downto 0 do
  begin
    ReadScreenRow(Row, 80, LineStr);
    if LineStr <> '' then
    begin
      if FormatEz80AsmError(LineStr, Parsed) then
      begin
        if Copy(Parsed, 1, 13) = '*** Error at ' then
        begin
          ErrEntry := Parsed;
          Exit;
        end
        else if Fallback = '' then
          Fallback := Parsed;
      end;
    end;
  end;
  ErrEntry := Fallback;
end;
