{ plat_agon.inc - Agon MOS error codes and key decoding for pano }

{ Agon's ReadKey returns only sysvar_keyascii, where arrow keys collide with
  Backspace (#8), ^K Cut (#11), and ^U Uncut (#21), and Home/End/PgUp/PgDn/Del
  report keyascii = 0. Reading sysvar_vkeycode alongside sysvar_keyascii via
  agonkey.asm disambiguates hardware navigation keys from Ctrl shortcuts. }

const
  ErrFileNotFound = 1;
  HasIdeRunner    = True;

function AgonReadKey: Integer; external 'key';

function ReadKeyEvent(var Ch: Char): Integer;
var
  W, Ev: Integer;
begin
  repeat
    W := AgonReadKey;
    Ch := Chr(Lo(W));
    case Hi(W) of
      $96: Ev := evUp;
      $98: Ev := evDown;
      $9A: Ev := evLeft;
      $9C: Ev := evRight;
      $85: Ev := evHome;
      $87: Ev := evEnd;
      $92: Ev := evPgUp;
      $94: Ev := evPgDn;
      $82: Ev := evDel;
    else
      if Ch = #27 then
        Ev := evEsc
      else if Ch = #2 then
        Ev := evCompile
      else if Ch = #18 then
        Ev := evRun
      else
        Ev := DecodeCommonKey(Ch);
    end;
  until Ev <> evNone;
  ReadKeyEvent := Ev;
end;
