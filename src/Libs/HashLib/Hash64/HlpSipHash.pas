unit HlpSipHash;

{$I ..\Include\HashLib.inc}

interface

uses

{$IFDEF DELPHI2010}
  SysUtils, // to get rid of compiler hint "not inlined" on Delphi 2010.
{$ENDIF DELPHI2010}
  HlpHashLibTypes,
  HlpConverters,
  HlpIHashInfo,
  HlpNullable,
  HlpHash,
  HlpIHash,
  HlpHashResult,
  HlpIHashResult,
  HlpBits;

resourcestring
  SInvalidKeyLength = 'KeyLength Must Be Equal to %d';

type
  TSipHash = class abstract(THash, IHash64, IHashWithKey, ITransformBlock)

  strict private

{$REGION 'Consts'}
  const
    V0 = UInt64($736F6D6570736575);
    V1 = UInt64($646F72616E646F6D);
    V2 = UInt64($6C7967656E657261);
    V3 = UInt64($7465646279746573);
    KEY0 = UInt64($0706050403020100);
    KEY1 = UInt64($0F0E0D0C0B0A0908);

{$ENDREGION}
    procedure Compress(); inline;
    procedure CompressTimes(ATimes: Int32); inline;
    procedure ProcessBlock(ABlock: UInt64); inline;
    procedure ByteUpdate(AByte: Byte); inline;
    procedure Finish();

    function GetKeyLength(): TNullableInteger;
    function GetKey: THashLibByteArray;
    procedure SetKey(const AValue: THashLibByteArray);

  strict protected
  var
    FV0, FV1, FV2, FV3, FKey0, FKey1, FTotalLength: UInt64;
    FCompressionRounds, FFinalizationRounds, FIdx: Int32;
    FBuffer: THashLibByteArray;

  public
    constructor Create(ACompressionRounds: Int32 = 2;
      AFinalizationRounds: Int32 = 4);
    procedure Initialize(); override;
    procedure TransformBytes(const AData: THashLibByteArray;
      AIndex, ALength: Int32); override;
    function TransformFinal: IHashResult; override;
    property KeyLength: TNullableInteger read GetKeyLength;
    property Key: THashLibByteArray read GetKey write SetKey;

  end;

type
  /// <summary>
  /// SipHash 2 - 4 algorithm.
  /// <summary>
  TSipHash2_4 = class sealed(TSipHash)

  public

    constructor Create();
    function Clone(): IHash; override;

  end;

implementation

{ TSipHash2_4 }

function TSipHash2_4.Clone(): IHash;
var
  LHashInstance: TSipHash2_4;
begin
  LHashInstance := TSipHash2_4.Create();
  LHashInstance.FV0 := FV0;
  LHashInstance.FV1 := FV1;
  LHashInstance.FV2 := FV2;
  LHashInstance.FV3 := FV3;
  LHashInstance.FKey0 := FKey0;
  LHashInstance.FKey1 := FKey1;
  LHashInstance.FTotalLength := FTotalLength;
  LHashInstance.FCompressionRounds := FCompressionRounds;
  LHashInstance.FFinalizationRounds := FFinalizationRounds;
  LHashInstance.FIdx := FIdx;
  LHashInstance.FBuffer := System.Copy(FBuffer);
  result := LHashInstance as IHash;
  result.BufferSize := BufferSize;
end;

constructor TSipHash2_4.Create;
begin
  Inherited Create(2, 4);

end;

{ TSipHash }

procedure TSipHash.Compress;
begin
  FV0 := FV0 + FV1;
  FV2 := FV2 + FV3;
  FV1 := TBits.RotateLeft64(FV1, 13);
  FV3 := TBits.RotateLeft64(FV3, 16);
  FV1 := FV1 xor FV0;
  FV3 := FV3 xor FV2;
  FV0 := TBits.RotateLeft64(FV0, 32);
  FV2 := FV2 + FV1;
  FV0 := FV0 + FV3;
  FV1 := TBits.RotateLeft64(FV1, 17);
  FV3 := TBits.RotateLeft64(FV3, 21);
  FV1 := FV1 xor FV2;
  FV3 := FV3 xor FV0;
  FV2 := TBits.RotateLeft64(FV2, 32);
end;

procedure TSipHash.CompressTimes(ATimes: Int32);
var
  LIdx: Int32;
begin
  LIdx := 0;
  while LIdx < ATimes do
  begin
    Compress();
    System.Inc(LIdx);
  end;
end;

procedure TSipHash.ProcessBlock(ABlock: UInt64);
begin
  FV3 := FV3 xor ABlock;
  CompressTimes(FCompressionRounds);
  FV0 := FV0 xor ABlock;
end;

procedure TSipHash.ByteUpdate(AByte: Byte);
var
  LPtrBuffer: PByte;
  LBlock: UInt64;
begin
  FBuffer[FIdx] := AByte;
  System.Inc(FIdx);
  if FIdx >= 8 then
  begin
    LPtrBuffer := PByte(FBuffer);
    LBlock := TConverters.ReadBytesAsUInt64LE(LPtrBuffer, 0);
    ProcessBlock(LBlock);
    FIdx := 0;
  end;
end;

constructor TSipHash.Create(ACompressionRounds, AFinalizationRounds: Int32);
begin
  Inherited Create(8, 8);
  FKey0 := KEY0;
  FKey1 := KEY1;
  FCompressionRounds := ACompressionRounds;
  FFinalizationRounds := AFinalizationRounds;
  System.SetLength(FBuffer, 8);
end;

procedure TSipHash.Finish;
var
  LFinalBlock: UInt64;
begin
  LFinalBlock := UInt64(FTotalLength and $FF) shl 56;

  if (FIdx <> 0) then
  begin
    case (FIdx) of

      7:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[6]) shl 48);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[5]) shl 40);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[4]) shl 32);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[3]) shl 24);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[2]) shl 16);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;
      6:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[5]) shl 40);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[4]) shl 32);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[3]) shl 24);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[2]) shl 16);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;
      5:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[4]) shl 32);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[3]) shl 24);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[2]) shl 16);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;

      4:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[3]) shl 24);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[2]) shl 16);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;

      3:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[2]) shl 16);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;

      2:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[1]) shl 8);
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;

      1:
        begin
          LFinalBlock := LFinalBlock or (UInt64(FBuffer[0]));
        end;
    end;
  end;

  FV3 := FV3 xor LFinalBlock;
  CompressTimes(FCompressionRounds);
  FV0 := FV0 xor LFinalBlock;
  FV2 := FV2 xor $FF;
  CompressTimes(FFinalizationRounds);
end;

function TSipHash.GetKey: THashLibByteArray;
var
  LKey: THashLibByteArray;
begin
  System.SetLength(LKey, KeyLength.value);

  TConverters.ReadUInt64AsBytesLE(FKey0, LKey, 0);
  TConverters.ReadUInt64AsBytesLE(FKey1, LKey, 8);

  result := LKey;
end;

function TSipHash.GetKeyLength: TNullableInteger;
begin
  result := 16;
end;

procedure TSipHash.Initialize;
begin
  FV0 := V0;
  FV1 := V1;
  FV2 := V2;
  FV3 := V3;
  FTotalLength := 0;
  FIdx := 0;

  FV3 := FV3 xor FKey1;
  FV2 := FV2 xor FKey0;
  FV1 := FV1 xor FKey1;
  FV0 := FV0 xor FKey0;

end;

procedure TSipHash.SetKey(const AValue: THashLibByteArray);
begin
  if (AValue = Nil) then
  begin
    FKey0 := KEY0;
    FKey1 := KEY1;
  end
  else
  begin
    if System.Length(AValue) <> KeyLength.value then
    begin
      raise EArgumentHashLibException.CreateResFmt(@SInvalidKeyLength,
        [KeyLength.value]);
    end;

    FKey0 := TConverters.ReadBytesAsUInt64LE(PByte(AValue), 0);
    FKey1 := TConverters.ReadBytesAsUInt64LE(PByte(AValue), 8);
  end;
end;

procedure TSipHash.TransformBytes(const AData: THashLibByteArray;
  AIndex, ALength: Int32);
var
  LIdx, LLength, LBlockCount, LOffset: Int32;
  LPtrData, LPtrBuffer: PByte;
  LBlock: UInt64;
begin
{$IFDEF DEBUG}
  System.Assert(AIndex >= 0);
  System.Assert(ALength >= 0);
  System.Assert(AIndex + ALength <= System.Length(AData));
{$ENDIF DEBUG}
  LLength := ALength;
  LIdx := AIndex;

  LPtrData := PByte(AData);
  System.Inc(FTotalLength, LLength);

  // consume last pending bytes

  if ((FIdx <> 0) and (ALength <> 0)) then
  begin
{$IFDEF DEBUG}
    System.Assert(AIndex = 0); // nothing would work anyways if AIndex is !=0
{$ENDIF DEBUG}
    while ((FIdx < 8) and (LLength <> 0)) do
    begin
      FBuffer[FIdx] := (LPtrData + AIndex)^;
      System.Inc(FIdx);
      System.Inc(AIndex);
      System.Dec(LLength);
    end;
    if (FIdx = 8) then
    begin
      LPtrBuffer := PByte(FBuffer);
      LBlock := TConverters.ReadBytesAsUInt64LE(LPtrBuffer, 0);
      ProcessBlock(LBlock);
      FIdx := 0;
    end;
  end
  else
  begin
    LIdx := 0;
  end;

  LBlockCount := LLength shr 3;

  // body

  while LIdx < LBlockCount do
  begin
    LBlock := TConverters.ReadBytesAsUInt64LE(LPtrData, AIndex + (LIdx * 8));
    ProcessBlock(LBlock);
    System.Inc(LIdx);
  end;

  // save pending end bytes
  LOffset := AIndex + (LIdx * 8);

  while LOffset < (LLength + AIndex) do
  begin
    ByteUpdate(AData[LOffset]);
    System.Inc(LOffset);
  end;
end;

function TSipHash.TransformFinal: IHashResult;
begin
  Finish();
  result := THashResult.Create(FV0 xor FV1 xor FV2 xor FV3);
  Initialize();
end;

end.
