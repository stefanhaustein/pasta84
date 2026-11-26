{ plat_cpm.inc - CP/M-80 error codes and VT52/CSI key decoding for pano }

const
  ErrFileNotFound = 255;
  HasIdeRunner    = True;

function ReadKeyEvent(var Ch: Char): Integer;
var
  C1, C2, C3: Char;
begin
  Ch := ReadKey;

  if Ch = #27 then
  begin
    if not KeyPressed then Delay(20);
    if not KeyPressed then
    begin
      ReadKeyEvent := evEsc;
      Exit;
    end;

    C1 := ReadKey;
    case C1 of
      'A': begin ReadKeyEvent := evUp; Exit; end;
      'B': begin ReadKeyEvent := evDown; Exit; end;
      'C': begin ReadKeyEvent := evRight; Exit; end;
      'D': begin ReadKeyEvent := evLeft; Exit; end;
      '[':
        begin
          if not KeyPressed then Delay(20);
          if KeyPressed then
          begin
            C2 := ReadKey;
            case C2 of
              'A': begin ReadKeyEvent := evUp; Exit; end;
              'B': begin ReadKeyEvent := evDown; Exit; end;
              'C': begin ReadKeyEvent := evRight; Exit; end;
              'D': begin ReadKeyEvent := evLeft; Exit; end;
              'H': begin ReadKeyEvent := evHome; Exit; end;
              'F': begin ReadKeyEvent := evEnd; Exit; end;
              '3', '5', '6':
                begin
                  if not KeyPressed then Delay(20);
                  if KeyPressed then C3 := ReadKey else C3 := #0;
                  if C3 = '~' then
                  begin
                    if C2 = '3' then begin ReadKeyEvent := evDel; Exit; end;
                    if C2 = '5' then begin ReadKeyEvent := evPgUp; Exit; end;
                    if C2 = '6' then begin ReadKeyEvent := evPgDn; Exit; end;
                  end;
                end;
            end;
          end;
        end;
    end;
    ReadKeyEvent := evNone;
    Exit;
  end;

  if Ch = #2 then
    ReadKeyEvent := evCompile
  else if Ch = #18 then
    ReadKeyEvent := evRun
  else
    ReadKeyEvent := DecodeCommonKey(Ch);
end;
