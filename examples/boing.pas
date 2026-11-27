program Boing;

{$A+,U-}

const
  AtanLut: array[0..16] of Byte = (
    0, 1, 2, 3, 4, 5, 5, 6, 7, 8, 9, 9, 10, 10, 11, 12, 12
  );

var
  ILatBuf: array[0..4095] of Byte;
  ILonBuf: array[0..4095] of Byte;
  SprBuf: array[0..4095] of Byte;
  BallPal: array[0..1] of Byte;
  ShadowPal: array[0..0] of Byte;
  NumFrames, ShadowSpr, BallSpr: Integer;

procedure DrawLine(X1, Y1, X2, Y2: Integer);
begin
  Plot(X1, Y1);
  Draw(X2 - X1, Y2 - Y1);
end;

procedure DrawGridBg;
begin
  TextBackground(7);
  ClrScr;
end;

procedure DrawHStep(Py: Integer);
var
  Idx, YBot, Dy, Y: Integer;
begin
  if (Py and 3) <> 0 then Exit;
  SetColor(Magenta);
  Idx := Py shr 2;
  YBot := GraphHeight - 24;
  Dy := (YBot - 16) div 10;
  if Idx < 11 then
  begin
    Y := 16 + Idx * Dy;
    DrawLine(40, Y, 280, Y);
  end
  else if Idx = 11 then
  begin
    DrawLine(30, YBot + 3, 290, YBot + 3);
    DrawLine(18, YBot + 7, 302, YBot + 7);
    DrawLine(4, YBot + 12, 316, YBot + 12);
  end;
end;

procedure DrawGridStep(Step: Integer);
var
  YBot, X: Integer;
begin
  SetColor(Magenta);
  YBot := GraphHeight - 24;
  X := 40 + Step * 40;
  if X <= 280 then
  begin
    DrawLine(X, 16, X, YBot);
    DrawLine(X, YBot, 160 + ((X - 160) * 13) div 10, YBot + 12);
    Inc(X, 20);
    if X <= 280 then
    begin
      DrawLine(X, 16, X, YBot);
      DrawLine(X, YBot, 160 + ((X - 160) * 13) div 10, YBot + 12);
    end;
  end;
end;

function ISqrt(N: Integer): Integer;
var
  Res, Bit: Integer;
begin
  if N <= 0 then
  begin
    ISqrt := 0;
    Exit;
  end;
  Res := 0;
  Bit := 16384;
  while Bit > N do
    Bit := Bit shr 2;
  while Bit <> 0 do
  begin
    if N >= Res + Bit then
    begin
      N := N - (Res + Bit);
      Res := (Res shr 1) + Bit;
    end
    else
      Res := Res shr 1;
    Bit := Bit shr 2;
  end;
  ISqrt := Res;
end;

function IAtanHalf(Y, X: Integer): Integer;
var
  Ay, A: Integer;
begin
  if Y < 0 then Ay := -Y else Ay := Y;
  if (X = 0) and (Ay = 0) then
  begin
    IAtanHalf := 0;
    Exit;
  end;
  if Ay <= X then
    A := AtanLut[(Ay shl 4) div X]
  else
    A := 24 - AtanLut[(X shl 4) div Ay];
  if Y < 0 then
    IAtanHalf := -A
  else
    IAtanHalf := A;
end;

procedure PrecomputeSphere;
var
  Idx, Py, Px, Fy, Fx, R2, Fz, Tx, Ty, Ryz: Integer;
begin
  Idx := 0;
  for Py := 0 to 63 do
  begin
    Fy := Py - 32;
    for Px := 0 to 63 do
    begin
      Fx := Px - 32;
      R2 := Fx * Fx + Fy * Fy;
      if R2 >= 1024 then
      begin
        ILatBuf[Idx] := 255;
        ILonBuf[Idx] := 0;
      end
      else
      begin
        Fz := ISqrt((1024 - R2) shl 4);
        Tx := ((Fx * 24 - Fy * 7) shl 2) div 25;
        Ty := ((Fx * 7 + Fy * 24) shl 2) div 25;
        Ryz := ISqrt(16384 - Ty * Ty);
        ILatBuf[Idx] := ((IAtanHalf(Ty, Ryz) + 24) * 6) div 49;
        ILonBuf[Idx] := IAtanHalf(Tx, Fz) + 24;
      end;
      Inc(Idx);
    end;
    DrawHStep(Py);
  end;
end;

procedure UploadBallFrame(Frame: Integer);
var
  Idx, ILat, ILon: Integer;
begin
  for Idx := 0 to 4095 do
  begin
    ILat := ILatBuf[Idx];
    if ILat = 255 then
      SprBuf[Idx] := 0
    else
    begin
      ILon := (ILonBuf[Idx] + (Frame shl 1)) shr 3;
      if ((ILat + ILon) and 1) = 0 then
        SprBuf[Idx] := 2
      else
        SprBuf[Idx] := 1;
    end;
  end;
  if DefineSprite(Frame + 1, 64, 64, SprBuf, BallPal, 2) then
    Inc(NumFrames);
end;

procedure UploadShadow;
var
  Idx, Py, Px, Y, X: Integer;
begin
  Idx := 0;
  for Py := 0 to 63 do
  begin
    Y := Py - 32;
    for Px := 0 to 63 do
    begin
      X := Px - 32;
      if (X * X + Y * Y >= 1024) or (((Px + Py) and 1) <> 0) then
        SprBuf[Idx] := 0
      else
        SprBuf[Idx] := 1;
      Inc(Idx);
    end;
  end;
  if DefineSprite(0, 64, 64, SprBuf, ShadowPal, 1) then
    SetSprite(ShadowSpr, 0);
end;

procedure SetupSprites;
var
  F: Integer;
begin
  NumFrames := 0;
  BallPal[0] := White;
  BallPal[1] := Red;
  ShadowPal[0] := Black;
  PrecomputeSphere;
  UploadShadow;
  DrawGridStep(0);
  for F := 0 to 7 do
  begin
    UploadBallFrame(F);
    DrawGridStep(F + 1);
  end;
end;

var
  X, Y8, Vx, Vy, Tick, F, Floor8: Integer;
begin
  if (SpriteMaxWidth < 64) or (SpriteMaxHeight < 64) or (SpriteCount < 2) then
  begin
    WriteLn('Insufficient sprite size/count (need 64x64, 2 sprites)');
    Halt;
  end;

  ShadowSpr := 1;
  BallSpr := 0;
  SetGraphMode(2);
  DrawGridBg;
  SetupSprites;

  X := 40;
  Y8 := 400;
  Vx := 1;
  Vy := 0;
  Tick := 0;
  F := 1;
  SetSprite(BallSpr, 1);
  MoveSprite(ShadowSpr, X + 10, (Y8 shr 4) - 2);
  MoveSprite(BallSpr, X, Y8 shr 4);
  ShowSprite(ShadowSpr, True);
  ShowSprite(BallSpr, True);

  Floor8 := (GraphHeight - 76) shl 4;
  while not KeyPressed do
  begin
    Inc(X, Vx);
    if X < 30 then
    begin
      X := 30;
      Vx := 1;
      SfxPlay(0, 180, 10, 2, 60);
    end;
    if X > 216 then
    begin
      X := 216;
      Vx := -1;
      SfxPlay(0, 180, 10, 2, 60);
    end;
    Inc(Vy);
    Inc(Y8, Vy);
    if Y8 >= Floor8 then
    begin
      Y8 := Floor8;
      Vy := -54;
      SfxPlay(0, 120, 14, 2, 110);
    end;
    if (Tick and 1) = 0 then
    begin
      if Vx > 0 then
      begin
        if F = 1 then F := NumFrames else Dec(F);
      end
      else
      begin
        if F >= NumFrames then F := 1 else Inc(F);
      end;
      SetSprite(BallSpr, F);
    end;
    MoveSprite(ShadowSpr, X + 10, (Y8 shr 4) - 2);
    MoveSprite(BallSpr, X, Y8 shr 4);
    WaitVSync;
    SfxTick;
    Inc(Tick);
  end;

  SfxStop(0);
  ShowSprite(ShadowSpr, False);
  ShowSprite(BallSpr, False);
  SetGraphMode(0);
end.
