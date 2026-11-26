program Pano;

{$A+,U-}

const
  MaxLines   = 1000;
  ViewTop    = 2;
  HorizStep  = 20;

  evNone   = 0;
  evChar   = 1;
  evUp     = 2;
  evDown   = 3;
  evLeft   = 4;
  evRight  = 5;
  evHome   = 6;
  evEnd    = 7;
  evPgUp   = 8;
  evPgDn   = 9;
  evEnter  = 10;
  evBacksp = 11;
  evDel    = 12;
  evExit   = 13;
  evWrite  = 14;
  evCut    = 15;
  evUncut  = 16;
  evTab     = 17;
  evEsc     = 18;
  evCancel  = 19;
  evCompile = 20;
  evRun     = 21;

type
  PString    = ^String;
  TFileName  = String[64];
  TStatusMsg = String[80];

var
  ScrCols, ScrRows, VisCols: Integer;
  ViewRows, HalfPage: Integer;
  StatusRow, HelpRow1, HelpRow2: Integer;
  Lines: array[1..MaxLines] of PString;
  FileName: TFileName;
  CurLine: String;
  CurLineDirty: Boolean;
  CutLine: String;
  HasCut: Boolean;
  CurRow, CurCol: Integer;
  TopLine, ColOffset: Integer;
  TotalLines: Integer;
  Modified: Boolean;
  StatusMsg: TStatusMsg;
  Running: Boolean;

function DecodeCommonKey(Ch: Char): Integer;
begin
  case Ch of
    #1:   DecodeCommonKey := evHome;
    #3:   DecodeCommonKey := evCancel;
    #4:   DecodeCommonKey := evDel;
    #5:   DecodeCommonKey := evEnd;
    #8:   DecodeCommonKey := evBacksp;
    #9:   DecodeCommonKey := evTab;
    #11:  DecodeCommonKey := evCut;
    #13:  DecodeCommonKey := evEnter;
    #15:  DecodeCommonKey := evWrite;
    #21:  DecodeCommonKey := evUncut;
    #22:  DecodeCommonKey := evPgDn;
    #24:  DecodeCommonKey := evExit;
    #25:  DecodeCommonKey := evPgUp;
    #127: DecodeCommonKey := evBacksp;
  else
    if (Ch >= #32) and (Ch <= #126) then
      DecodeCommonKey := evChar
    else
      DecodeCommonKey := evNone;
  end;
end;

{$ifdef SYS_IR4}
  {$i plat_agon.inc}
{$else}
  {$ifdef SYS_AGON}
    {$i plat_agon.inc}
  {$else}
    {$ifdef SYS_CPM}
      {$i plat_cpm.inc}
    {$else}
      {$error pano targets Agon or CP/M-80.}
    {$endif}
  {$endif}
{$endif}
{$i buffer.inc}
{$i ui.inc}
{$i fileio.inc}

procedure HandleEvent(Ev: Integer; Ch: Char);
var
  NeedViewport, NeedRow, Joined: Boolean;
  Spaces, K: Integer;
begin
  NeedViewport := False;
  NeedRow := False;
  StatusMsg := '';

  case Ev of
    evUp:
      if (CurRow > 1) and MoveToRow(CurRow - 1) then
        ClampCol;
    evDown:
      if (CurRow < TotalLines) and MoveToRow(CurRow + 1) then
        ClampCol;
    evLeft:
      if CurCol > 1 then
        Dec(CurCol)
      else if (CurRow > 1) and MoveToRow(CurRow - 1) then
        CurCol := Length(CurLine) + 1;
    evRight:
      if CurCol <= Length(CurLine) then
        Inc(CurCol)
      else if (CurRow < TotalLines) and MoveToRow(CurRow + 1) then
        CurCol := 1;
    evHome:
      CurCol := 1;
    evEnd:
      CurCol := Length(CurLine) + 1;
    evPgUp:
      begin
        if CurRow > 1 then
        begin
          if CurRow - (ViewRows - 2) >= 1 then
          begin
            if MoveToRow(CurRow - (ViewRows - 2)) then ClampCol;
          end
          else if MoveToRow(1) then
            ClampCol;
        end;
      end;
    evPgDn:
      begin
        if CurRow < TotalLines then
        begin
          if CurRow + (ViewRows - 2) <= TotalLines then
          begin
            if MoveToRow(CurRow + (ViewRows - 2)) then ClampCol;
          end
          else if MoveToRow(TotalLines) then
            ClampCol;
        end;
      end;
    evChar:
      if InsertChar(Ch) then
        NeedRow := True;
    evTab:
      begin
        Spaces := 4 - ((CurCol - 1) mod 4);
        for K := 1 to Spaces do
          if InsertChar(' ') then NeedRow := True else Break;
      end;
    evEnter:
      if SplitLine then
        NeedViewport := True;
    evBacksp:
      if DeleteCharBefore(Joined) then
      begin
        if Joined then NeedViewport := True else NeedRow := True;
      end;
    evDel:
      if DeleteCharAt(Joined) then
      begin
        if Joined then NeedViewport := True else NeedRow := True;
      end;
    evCut:
      begin
        CutCurrentLine;
        NeedViewport := True;
      end;
    evUncut:
      if UncutLine then
        NeedViewport := True;
    evWrite:
      DoWriteOut;
    evCompile:
      if HasIdeRunner then DoIdeAction('C');
    evRun:
      if HasIdeRunner then DoIdeAction('R');
    evExit:
      begin
        DoExit;
        if not Running then Exit;
      end;
  end;

  if EnsureVisible then
    NeedViewport := True;

  CursorOff;
  if NeedViewport then
    DrawViewport
  else if NeedRow then
    DrawViewportRow(ViewTop + (CurRow - TopLine), CurRow);
  DrawHeader;
  DrawStatus;
  PlaceCursor;
  CursorOn;
end;

procedure InitEditor;
begin
  ScrCols := ScreenWidth;
  ScrRows := ScreenHeight;
  if ScrCols < 20 then ScrCols := 20;
  if ScrRows < 6 then ScrRows := 6;
  VisCols := ScrCols - 1;
  ViewRows := ScrRows - 4;
  HalfPage := ViewRows div 2;
  if HalfPage < 1 then HalfPage := 1;
  StatusRow := ScrRows - 2;
  HelpRow1 := ScrRows - 1;
  HelpRow2 := ScrRows;

  InitBuffer;
  FileName := '';
  Running := True;
  StatusMsg := '';

  if ParamCount >= 1 then
    LoadFile(ParamStr(1));
  if HasIdeRunner then
    ResumeIdeState;
end;

var
  Ev: Integer;
  Ch: Char;

begin
  InitEditor;
  DrawAll;
  while Running do
  begin
    Ev := ReadKeyEvent(Ch);
    HandleEvent(Ev, Ch);
  end;
  FreeAllLines;
  TextColor(White);
  TextBackground(Black);
  ClrScr;
  CursorOn;
end.
