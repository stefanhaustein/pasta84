{ ui.inc - Screen rendering, viewport scrolling, and shared key decoding for pano }

procedure SetEditorColors;
begin
  TextColor(Yellow);
  TextBackground(Blue);
end;

procedure SetChromeColors;
begin
  TextColor(Black);
  TextBackground(Cyan);
end;

procedure SetBarColors;
begin
  TextColor(White);
  TextBackground(Black);
end;

function IntWidth(V: Integer): Integer;
var
  W: Integer;
begin
  if V < 0 then
  begin
    W := 2;
    V := -V;
  end
  else
    W := 1;
  while V >= 10 do
  begin
    V := V div 10;
    Inc(W);
  end;
  IntWidth := W;
end;

procedure WriteSpaces(Count: Integer);
var
  I: Integer;
begin
  for I := 1 to Count do
    Write(' ');
end;

{ Fill the header bar across all ScrCols without calling ClrEol: on Agon with
  scroll protection, writing column 80 sets a pending newline that ClrEol's
  trailing space would execute onto row 2; the next GotoXY cancels it safely. }
procedure DrawHeader;
var
  RightWidth, TitleLen, MaxTitleLen, Gap: Integer;
begin
  RightWidth := IntWidth(CurRow) + 1 + IntWidth(CurCol) + 1 + IntWidth(TotalLines);
  if Modified then
    Inc(RightWidth, 2);

  if FileName = '' then
    TitleLen := 12
  else
    TitleLen := Length(FileName);

  MaxTitleLen := VisCols - 10 - RightWidth;
  if MaxTitleLen < 0 then MaxTitleLen := 0;
  if TitleLen > MaxTitleLen then
    TitleLen := MaxTitleLen;

  Gap := VisCols - 9 - TitleLen - RightWidth;
  if Gap < 1 then Gap := 1;

  GotoXY(1, 1);
  SetChromeColors;
  Write('  pano   ');
  if FileName = '' then
  begin
    if TitleLen >= 12 then
      Write('[New Buffer]')
    else
      Write(Copy('[New Buffer]', 1, TitleLen));
  end
  else if Length(FileName) > TitleLen then
    Write(Copy(FileName, 1, TitleLen))
  else
    Write(FileName);
  WriteSpaces(Gap);
  if Modified then
    Write('* ');
  Write(CurRow, ':', CurCol, '/', TotalLines, ' ');
  SetBarColors;
end;

procedure DrawStatus;
begin
  GotoXY(1, StatusRow);
  SetBarColors;
  if Length(StatusMsg) > VisCols then
    Write(Copy(StatusMsg, 1, VisCols))
  else
    Write(StatusMsg);
  ClrEol;
end;

procedure WriteBadge(KeyText, LabelText: String; var Col: Integer);
var
  Need: Integer;
begin
  Need := Length(KeyText) + 1 + Length(LabelText) + 2;
  if Col + Need > VisCols then Exit;
  SetChromeColors;
  Write(KeyText);
  SetBarColors;
  Write(' ', LabelText, '  ');
  Inc(Col, Need);
end;

procedure DrawShortcuts;
var
  Col: Integer;
begin
  GotoXY(1, HelpRow1);
  SetBarColors;
  Col := 0;
  WriteBadge('^O', 'WriteOut', Col);
  WriteBadge('^K', 'Cut     ', Col);
  WriteBadge('^Y', 'PrevPg  ', Col);
  WriteBadge('^A', 'BeginLn ', Col);
  WriteBadge('^D', 'DelChar ', Col);
  if HasIdeRunner then
    WriteBadge('^B', 'Build   ', Col);
  ClrEol;

  GotoXY(1, HelpRow2);
  SetBarColors;
  Col := 0;
  WriteBadge('^X', 'Exit    ', Col);
  WriteBadge('^U', 'Uncut   ', Col);
  WriteBadge('^V', 'NextPg  ', Col);
  WriteBadge('^E', 'EndLn   ', Col);
  if HasIdeRunner and (Col + 13 <= VisCols) then
  begin
    WriteSpaces(13);
    Inc(Col, 13);
    WriteBadge('^R', 'Run     ', Col);
  end;
  ClrEol;
end;

procedure WriteSlice(var S: String);
var
  I, EndCol: Integer;
begin
  if ColOffset < Length(S) then
  begin
    EndCol := ColOffset + VisCols;
    if EndCol > Length(S) then
      EndCol := Length(S);
    for I := ColOffset + 1 to EndCol do
      Write(S[I]);
  end;
end;

procedure DrawViewportRow(ScreenRow, FileRow: Integer);
begin
  GotoXY(1, ScreenRow);
  SetEditorColors;
  if FileRow = CurRow then
    WriteSlice(CurLine)
  else if (FileRow >= 1) and (FileRow <= TotalLines) and (Lines[FileRow] <> nil) then
    WriteSlice(Lines[FileRow]^);
  ClrEol;
end;

procedure DrawViewport;
var
  I: Integer;
begin
  for I := 0 to ViewRows - 1 do
    DrawViewportRow(ViewTop + I, TopLine + I);
end;

procedure PlaceCursor;
var
  ScrX, ScrY: Integer;
begin
  ScrY := ViewTop + (CurRow - TopLine);
  ScrX := CurCol - ColOffset;
  if ScrX < 1 then ScrX := 1;
  if ScrX > ScrCols then ScrX := ScrCols;
  if ScrY < ViewTop then ScrY := ViewTop;
  if ScrY > ViewTop + ViewRows - 1 then ScrY := ViewTop + ViewRows - 1;
  GotoXY(ScrX, ScrY);
end;

procedure DrawAll;
begin
  CursorOff;
  ClrScr;
  DrawHeader;
  DrawViewport;
  DrawStatus;
  DrawShortcuts;
  PlaceCursor;
  CursorOn;
end;

function EnsureVisible: Boolean;
var
  MaxTop: Integer;
  OldTop, OldColOff: Integer;
begin
  OldTop := TopLine;
  OldColOff := ColOffset;

  MaxTop := TotalLines - ViewRows + 1;
  if MaxTop < 1 then MaxTop := 1;

  if CurRow < TopLine then
  begin
    if CurRow >= TopLine - HalfPage then
      TopLine := TopLine - HalfPage
    else
      TopLine := CurRow - HalfPage;
    if TopLine < 1 then TopLine := 1;
  end
  else if CurRow >= TopLine + ViewRows then
  begin
    if CurRow < TopLine + ViewRows + HalfPage then
      TopLine := TopLine + HalfPage
    else
      TopLine := CurRow - HalfPage;
    if TopLine > MaxTop then TopLine := MaxTop;
  end
  else if TopLine > MaxTop then
    TopLine := MaxTop;

  if CurCol <= ColOffset then
  begin
    ColOffset := ((CurCol - 1) div HorizStep) * HorizStep;
    if ColOffset < 0 then ColOffset := 0;
  end
  else if CurCol > ColOffset + VisCols then
  begin
    ColOffset := ((CurCol - 1) div HorizStep) * HorizStep - (VisCols - HorizStep);
    if ColOffset < 0 then ColOffset := 0;
  end;

  EnsureVisible := (TopLine <> OldTop) or (ColOffset <> OldColOff);
end;
