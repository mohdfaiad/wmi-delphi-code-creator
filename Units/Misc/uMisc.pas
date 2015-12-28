//**************************************************************************************************
//
// Unit uMisc
// unit for the WMI Delphi Code Creator
// https://github.com/RRUZ/wmi-delphi-code-creator
//
// The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy of the
// License at http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF
// ANY KIND, either express or implied. See the License for the specific language governing rights
// and limitations under the License.
//
// The Original Code is uMisc.pas.
//
// The Initial Developer of the Original Code is Rodrigo Ruz V.
// Portions created by Rodrigo Ruz V. are Copyright (C) 2011-2015 Rodrigo Ruz V.
// All Rights Reserved.
//
//**************************************************************************************************


unit uMisc;

interface

uses
 Vcl.DBGrids,
 System.Win.ComObj,
 System.SysUtils,
 WinApi.Windows,
 Vcl.Forms,
 Vcl.Graphics,
 System.Classes;

type
  TProcLog    = procedure (const  Log : string) of object;

  procedure CaptureConsoleOutput(const lpCommandLine: string; OutPutList: TStrings);
  procedure MsgWarning(const Msg: string);
  procedure MsgInformation(const Msg: string);
  function  MsgQuestion(const Msg: string):Boolean;
  function  GetFileVersion(const FileName: string): string;
  function  GetTempDirectory: string;
  function  GetWindowsDirectory : string;
  function  GetSpecialFolder(const CSIDL: integer) : string;
  function  IsWow64: boolean;
  function  CopyDir(const fromDir, toDir: string): boolean;
  procedure SetGridColumnWidths(DbGrid: TDBGrid);
  function  Ping(const Address:string;Retries,BufferSize:Word;Log : TStrings) : Boolean;

  procedure ScaleImage32(const SourceBitmap, ResizedBitmap: TBitmap; const ScaleAmount: Double);
  procedure ExtractIconFile(Icon: TIcon; const Filename: string;IconType : Cardinal);
  procedure ExtractBitmapFile(Bmp: TBitmap; const Filename: string;IconType : Cardinal);
  procedure ExtractBitmapFile32(Bmp: TBitmap; const Filename: string;IconType : Cardinal);

implementation

Uses
 Vcl.ComCtrls,
 Vcl.StdCtrls,
 Vcl.Themes,
 Winapi.ActiveX,
 System.UITypes,
 System.Variants,
 Winapi.ShlObj,
 Winapi.ShellAPi,
 Vcl.Controls,
 Vcl.Dialogs;


procedure ExtractIconFile(Icon: TIcon; const Filename: string;IconType : Cardinal);
var
  FileInfo: TShFileInfo;
begin
  if FileExists(Filename) then
  begin
    FillChar(FileInfo, SizeOf(FileInfo), 0);
    SHGetFileInfo(PChar(Filename), 0, FileInfo, SizeOf(FileInfo),
      SHGFI_ICON or IconType);
    if FileInfo.hIcon <> 0 then
      Icon.Handle:=FileInfo.hIcon;
  end;
end;

procedure ExtractBitmapFile(Bmp: TBitmap; const Filename: string;IconType : Cardinal);
var
 Icon: TIcon;
begin
  Icon:=TIcon.Create;
  try
    ExtractIconFile(Icon, Filename, SHGFI_SMALLICON);
    Bmp.PixelFormat:=pf24bit;
    Bmp.Width := Icon.Width;
    Bmp.Height := Icon.Height;
    Bmp.Canvas.Draw(0, 0, Icon);
  finally
    Icon.Free;
  end;

end;


procedure ExtractBitmapFile32(Bmp: TBitmap; const Filename: string;IconType : Cardinal);
var
 Icon: TIcon;
begin
  Icon:=TIcon.Create;
  try
    ExtractIconFile(Icon, Filename, SHGFI_SMALLICON);
    Bmp.PixelFormat:=pf32bit;  {
    Bmp.Width := Icon.Width;
    Bmp.Height := Icon.Height;
    Bmp.Canvas.Draw(0, 0, Icon);
    }
    Bmp.Assign(Icon);
  finally
    Icon.Free;
  end;

end;

procedure ShrinkImage32(const SourceBitmap, StretchedBitmap: TBitmap;
  Scale: Double);
var
  ScanLines: array of PByteArray;
  DestLine: PByteArray;
  CurrentLine: PByteArray;
  DestX, DestY: Integer;
  DestA, DestR, DestB, DestG: Integer;
  SourceYStart, SourceXStart: Integer;
  SourceYEnd, SourceXEnd: Integer;
  AvgX, AvgY: Integer;
  ActualX: Integer;
  PixelsUsed: Integer;
  DestWidth, DestHeight: Integer;
begin
  DestWidth := StretchedBitmap.Width;
  DestHeight := StretchedBitmap.Height;
  SetLength(ScanLines, SourceBitmap.Height);
  for DestY := 0 to DestHeight - 1 do
  begin
    SourceYStart := Round(DestY / Scale);
    SourceYEnd := Round((DestY + 1) / Scale) - 1;

    if SourceYEnd >= SourceBitmap.Height then
      SourceYEnd := SourceBitmap.Height - 1;

    { Grab the destination pixels }
    DestLine := StretchedBitmap.ScanLine[DestY];
    for DestX := 0 to DestWidth - 1 do
    begin
      { Calculate the RGB value at this destination pixel }
      SourceXStart := Round(DestX / Scale);
      SourceXEnd := Round((DestX + 1) / Scale) - 1;

      DestR := 0;
      DestB := 0;
      DestG := 0;
      DestA := 0;

      PixelsUsed := 0;
      if SourceXEnd >= SourceBitmap.Width then
        SourceXEnd := SourceBitmap.Width - 1;
      for AvgY := SourceYStart to SourceYEnd do
      begin
        if ScanLines[AvgY] = nil then
          ScanLines[AvgY] := SourceBitmap.ScanLine[AvgY];
        CurrentLine := ScanLines[AvgY];
        for AvgX := SourceXStart to SourceXEnd do
        begin
          ActualX := AvgX*4; { 4 bytes per pixel }
          DestR := DestR + CurrentLine[ActualX];
          DestB := DestB + CurrentLine[ActualX+1];
          DestG := DestG + CurrentLine[ActualX+2];
          DestA := DestA + CurrentLine[ActualX+3];
          Inc(PixelsUsed);
        end;
      end;

      { pf32bit = 4 bytes per pixel }
      ActualX := DestX*4;
      DestLine[ActualX]   := Round(DestR / PixelsUsed);
      DestLine[ActualX+1] := Round(DestB / PixelsUsed);
      DestLine[ActualX+2] := Round(DestG / PixelsUsed);
      DestLine[ActualX+3] := Round(DestA / PixelsUsed);
    end;
  end;
end;


procedure EnlargeImage32(const SourceBitmap, StretchedBitmap: TBitmap;
  Scale: Double);
var
  ScanLines: array of PByteArray;
  DestLine: PByteArray;
  CurrentLine: PByteArray;
  DestX, DestY: Integer;
  DestA, DestR, DestB, DestG: Double;
  SourceYStart, SourceXStart: Integer;
  SourceYPos: Integer;
  AvgX, AvgY: Integer;
  ActualX: Integer;
  { Use a 4 pixels for enlarging }
  XWeights, YWeights: array[0..1] of Double;
  PixelWeight: Double;
  DistFromStart: Double;
  DestWidth, DestHeight: Integer;
begin
  DestWidth := StretchedBitmap.Width;
  DestHeight := StretchedBitmap.Height;
  Scale := StretchedBitmap.Width / SourceBitmap.Width;
  SetLength(ScanLines, SourceBitmap.Height);
  for DestY := 0 to DestHeight - 1 do
  begin
    DistFromStart := DestY / Scale;
    SourceYStart := Round(DistFromSTart);
    YWeights[1] := DistFromStart - SourceYStart;
    if YWeights[1] < 0 then
      YWeights[1] := 0;
    YWeights[0] := 1 - YWeights[1];

    DestLine := StretchedBitmap.ScanLine[DestY];
    for DestX := 0 to DestWidth - 1 do
    begin
      { Calculate the RGB value at this destination pixel }
      DistFromStart := DestX / Scale;
      if DistFromStart > (SourceBitmap.Width - 1) then
        DistFromStart := SourceBitmap.Width - 1;
      SourceXStart := Round(DistFromStart);
      XWeights[1] := DistFromStart - SourceXStart;
      if XWeights[1] < 0 then
        XWeights[1] := 0;
      XWeights[0] := 1 - XWeights[1];

      { Average the four nearest pixels from the source mapped point }
      DestR := 0;
      DestB := 0;
      DestG := 0;
      DestA := 0;
      for AvgY := 0 to 1 do
      begin
        SourceYPos := SourceYStart + AvgY;
        if SourceYPos >= SourceBitmap.Height then
          SourceYPos := SourceBitmap.Height - 1;
        if ScanLines[SourceYPos] = nil then
          ScanLines[SourceYPos] := SourceBitmap.ScanLine[SourceYPos];
            CurrentLine := ScanLines[SourceYPos];

        for AvgX := 0 to 1 do
        begin
          if SourceXStart + AvgX >= SourceBitmap.Width then
            SourceXStart := SourceBitmap.Width - 1;

          ActualX := (SourceXStart + AvgX) * 4; { 4 bytes per pixel }

          { Calculate how heavy this pixel is based on how far away
            it is from the mapped pixel }
          PixelWeight := XWeights[AvgX] * YWeights[AvgY];
          DestR := DestR + CurrentLine[ActualX] * PixelWeight;
          DestB := DestB + CurrentLine[ActualX+1] * PixelWeight;
          DestG := DestG + CurrentLine[ActualX+2] * PixelWeight;
          DestA := DestA + CurrentLine[ActualX+3] * PixelWeight;
        end;
      end;

      ActualX := DestX * 4; { 4 bytes per pixel }
      DestLine[ActualX] := Round(DestR);
      DestLine[ActualX+1] := Round(DestB);
      DestLine[ActualX+2] := Round(DestG);
      DestLine[ActualX+3] := Round(DestA);
    end;
  end;
end;

procedure ScaleImage32(const SourceBitmap, ResizedBitmap: TBitmap;
  const ScaleAmount: Double);
var
  DestWidth, DestHeight: Integer;
begin
  DestWidth := Round(SourceBitmap.Width * ScaleAmount);
  DestHeight := Round(SourceBitmap.Height * ScaleAmount);
  SourceBitmap.PixelFormat := pf32bit;

  ResizedBitmap.Width := DestWidth;
  ResizedBitmap.Height := DestHeight;
  //ResizedBitmap.Canvas.Brush.Color := Vcl.Graphics.clNone;
  //ResizedBitmap.Canvas.FillRect(Rect(0, 0, DestWidth, DestHeight));
  ResizedBitmap.PixelFormat := pf32bit;

  if ResizedBitmap.Width < SourceBitmap.Width then
    ShrinkImage32(SourceBitmap, ResizedBitmap, ScaleAmount)
  else
    EnlargeImage32(SourceBitmap, ResizedBitmap, ScaleAmount);
end;

procedure SetGridColumnWidths(DbGrid: TDBGrid);
const
  BorderWidth = 10;
  MaxWidth=150;
var
  LWidth, LIndex: integer;
  LColumnsW: Array of integer;
begin
  with DbGrid do
  begin
    Canvas.Font := Font;
    SetLength(LColumnsW, Columns.Count);
    for LIndex := 0 to Columns.Count - 1 do
    begin
      LColumnsW[LIndex] := Canvas.TextWidth(Fields[LIndex].FieldName) + BorderWidth;
      if LColumnsW[LIndex]>MaxWidth then
      LColumnsW[LIndex]:=MaxWidth;
    end;

    DataSource.DataSet.First;
    while not DataSource.DataSet.Eof do
    begin
      for LIndex := 0 to Columns.Count - 1 do
      begin
        LWidth := Canvas.TextWidth(trim(Columns[LIndex]. Field.DisplayText)) + BorderWidth;
        //LWidth := Canvas.TextWidth(trim(TDBGridH(DbGrid).GetColField(Index).DisplayText)) + BorderWidth;
        if (LWidth > LColumnsW[LIndex]) and (LWidth<MaxWidth) then
          LColumnsW[LIndex] := LWidth;
      end;
      DataSource.DataSet.Next;
    end;
    DataSource.DataSet.First;
    for LIndex := 0 to Columns.Count - 1 do
      if LColumnsW[LIndex] > 0 then
        Columns[LIndex].Width := LColumnsW[LIndex];

    SetLength(LColumnsW, 0);
  end;
end;


function CopyDir(const fromDir, toDir: string): boolean;
var
  lpFileOp: TSHFileOpStruct;
begin
  ZeroMemory(@lpFileOp, SizeOf(lpFileOp));
  with lpFileOp do
  begin
    wFunc  := FO_COPY;
    fFlags := FOF_NOCONFIRMMKDIR or FOF_NOCONFIRMATION;
    pFrom  := PChar(fromDir + #0);
    pTo    := PChar(toDir);
  end;
  Result := (ShFileOperation(lpFileOp) = S_OK);
end;


function IsWow64: boolean;
type
  TIsWow64Process = function(Handle: WinApi.Windows.THandle;
      var Res: WinApi.Windows.BOOL): WinApi.Windows.BOOL; stdcall;
var
  IsWow64Result:  WinApi.Windows.BOOL;
  IsWow64Process: TIsWow64Process;
begin
  IsWow64Process := WinApi.Windows.GetProcAddress(WinApi.Windows.GetModuleHandle('kernel32.dll'), 'IsWow64Process');
  if Assigned(IsWow64Process) then
  begin
    if not IsWow64Process(WinApi.Windows.GetCurrentProcess, IsWow64Result) then
      Result := False
    else
      Result := IsWow64Result;
  end
  else
    Result := False;
end;

function GetTempDirectory: string;
var
  lpBuffer: array[0..MAX_PATH] of Char;
begin
  GetTempPath(MAX_PATH, @lpBuffer);
  Result := StrPas(lpBuffer);
end;

function GetWindowsDirectory : string;
var
  lpBuffer: array[0..MAX_PATH] of Char;
begin
  WinApi.Windows.GetWindowsDirectory(@lpBuffer, MAX_PATH);
  Result := StrPas(lpBuffer);
end;

function GetSpecialFolder(const CSIDL: integer) : string;
var
  lpszPath : PWideChar;
begin
  lpszPath := StrAlloc(MAX_PATH);
  try
     ZeroMemory(lpszPath, MAX_PATH);
    if SHGetSpecialFolderPath(0, lpszPath, CSIDL, False)  then
      Result := lpszPath
    else
      Result := '';
  finally
    StrDispose(lpszPath);
  end;
end;

function GetFileVersion(const FileName: string): string;
var
  FSO  : OleVariant;
begin
  FSO    := CreateOleObject('Scripting.FileSystemObject');
  Result := FSO.GetFileVersion(FileName);
end;

procedure MsgWarning(const Msg: string);
begin
  MessageDlg(Msg, mtWarning ,[mbOK], 0);
end;

procedure MsgInformation(const Msg: string);
begin
  MessageDlg(Msg,  mtInformation ,[mbOK], 0);
end;

function  MsgQuestion(const Msg: string):Boolean;
begin
  Result:= MessageDlg(Msg, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure CaptureConsoleOutput(const lpCommandLine: string; OutPutList: TStrings);
const
  ReadBuffer = 1024*1024;
var
  lpPipeAttributes      : TSecurityAttributes;
  ReadPipe              : THandle;
  WritePipe             : THandle;
  lpStartupInfo         : TStartUpInfo;
  lpProcessInformation  : TProcessInformation;
  Buffer                : PAnsiChar;
  TotalBytesRead        : DWORD;
  BytesRead             : DWORD;
  Apprunning            : integer;
  n                     : integer;
  BytesLeftThisMessage  : integer;
  TotalBytesAvail       : integer;
begin
  with lpPipeAttributes do
  begin
    nlength := SizeOf(TSecurityAttributes);
    binherithandle := True;
    lpsecuritydescriptor := nil;
  end;

  if not CreatePipe(ReadPipe, WritePipe, @lpPipeAttributes, 0) then
    exit;
  try
    Buffer := AllocMem(ReadBuffer + 1);
    try
      ZeroMemory(@lpStartupInfo, Sizeof(lpStartupInfo));
      lpStartupInfo.cb      := SizeOf(lpStartupInfo);
      lpStartupInfo.hStdOutput := WritePipe;
      lpStartupInfo.hStdInput := ReadPipe;
      lpStartupInfo.dwFlags := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW;
      lpStartupInfo.wShowWindow := SW_HIDE;

      OutPutList.Add(lpCommandLine);
      if CreateProcess(nil, PChar(lpCommandLine), @lpPipeAttributes,
        @lpPipeAttributes, True, CREATE_NO_WINDOW or NORMAL_PRIORITY_CLASS, nil,
        nil, lpStartupInfo, lpProcessInformation) then
      begin
        try
          n := 0;
          TotalBytesRead := 0;
          repeat
            Inc(n);
            Apprunning := WaitForSingleObject(lpProcessInformation.hProcess, 100);
            Application.ProcessMessages;
            if not PeekNamedPipe(ReadPipe, @Buffer[TotalBytesRead],
              ReadBuffer, @BytesRead, @TotalBytesAvail, @BytesLeftThisMessage) then
              break
            else
            if BytesRead > 0 then
              ReadFile(ReadPipe, Buffer[TotalBytesRead], BytesRead, BytesRead, nil);

            //Inc(TotalBytesRead, BytesRead);

            Buffer[BytesRead] := #0;
            OemToAnsi(Buffer, Buffer);
            OutPutList.Text := OutPutList.Text + String(Buffer);

          until (Apprunning <> WAIT_TIMEOUT) or (n > 150);

            {
          Buffer[TotalBytesRead] := #0;
          OemToAnsi(Buffer, Buffer);
          OutPutList.Text := OutPutList.Text + String(Buffer);
            }
        finally
          CloseHandle(lpProcessInformation.hProcess);
          CloseHandle(lpProcessInformation.hThread);
        end;
      end;
    finally
      FreeMem(Buffer);
    end;
  finally
    CloseHandle(ReadPipe);
    CloseHandle(WritePipe);
  end;
end;

function GetStatusCodeStr(statusCode:integer) : string;
begin
  case statusCode of
    0     : Result:='Success';
    11001 : Result:='Buffer Too Small';
    11002 : Result:='Destination Net Unreachable';
    11003 : Result:='Destination Host Unreachable';
    11004 : Result:='Destination Protocol Unreachable';
    11005 : Result:='Destination Port Unreachable';
    11006 : Result:='No Resources';
    11007 : Result:='Bad Option';
    11008 : Result:='Hardware Error';
    11009 : Result:='Packet Too Big';
    11010 : Result:='Request Timed Out';
    11011 : Result:='Bad Request';
    11012 : Result:='Bad Route';
    11013 : Result:='TimeToLive Expired Transit';
    11014 : Result:='TimeToLive Expired Reassembly';
    11015 : Result:='Parameter Problem';
    11016 : Result:='Source Quench';
    11017 : Result:='Option Too Big';
    11018 : Result:='Bad Destination';
    11032 : Result:='Negotiating IPSEC';
    11050 : Result:='General Failure'
    else
    result:='Unknow';
  end;
end;

function  Ping(const Address:string;Retries,BufferSize:Word;Log : TStrings) : Boolean;
var
  FSWbemLocator : OLEVariant;
  FWMIService   : OLEVariant;
  FWbemObjectSet: OLEVariant;
  FWbemObject   : OLEVariant;
  oEnum         : IEnumvariant;
  iValue        : LongWord;
  i             : Integer;

  PacketsReceived : Integer;
  Minimum         : Integer;
  Maximum         : Integer;
  Average         : Integer;
begin;
  Result:=False;
  PacketsReceived:=0;
  Minimum        :=0;
  Maximum        :=0;
  Average        :=0;
  Log.Add('');
  Log.Add(Format('Pinging %s with %d bytes of data:',[Address,BufferSize]));
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService   := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', '');
  //FWMIService   := FSWbemLocator.ConnectServer('192.168.52.130', 'root\CIMV2', 'user', 'password');
  for i := 0 to Retries-1 do
  begin
    FWbemObjectSet:= FWMIService.ExecQuery(Format('SELECT * FROM Win32_PingStatus where Address=%s AND BufferSize=%d',[QuotedStr(Address),BufferSize]),'WQL',0);
    oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
    if oEnum.Next(1, FWbemObject, iValue) = 0 then
    begin
      if FWbemObject.StatusCode=0 then
      begin
        if FWbemObject.ResponseTime>0 then
          Log.Add(Format('Reply from %s: bytes=%s time=%sms TTL=%s',[FWbemObject.ProtocolAddress,FWbemObject.ReplySize,FWbemObject.ResponseTime,FWbemObject.TimeToLive]))
        else
          Log.Add(Format('Reply from %s: bytes=%s time=<1ms TTL=%s',[FWbemObject.ProtocolAddress,FWbemObject.ReplySize,FWbemObject.TimeToLive]));

        Inc(PacketsReceived);

        if FWbemObject.ResponseTime>Maximum then
        Maximum:=FWbemObject.ResponseTime;

        if Minimum=0 then
        Minimum:=Maximum;

        if FWbemObject.ResponseTime<Minimum then
        Minimum:=FWbemObject.ResponseTime;

        Average:=Average+FWbemObject.ResponseTime;
      end
      else
      if not VarIsNull(FWbemObject.StatusCode) then
        Log.Add(Format('Reply from %s: %s',[FWbemObject.ProtocolAddress,GetStatusCodeStr(FWbemObject.StatusCode)]))
      else
        Log.Add(Format('Reply from %s: %s',[Address,'Error processing request']));
    end;
    FWbemObject:=Unassigned;
    FWbemObjectSet:=Unassigned;
    //Sleep(500);
  end;

  Log.Add('');
  Log.Add(Format('Ping statistics for %s:',[Address]));
  Log.Add(Format('    Packets: Sent = %d, Received = %d, Lost = %d (%d%% loss),',[Retries,PacketsReceived,Retries-PacketsReceived,Round((Retries-PacketsReceived)*100/Retries)]));
  if PacketsReceived>0 then
  begin
   Log.Add('Approximate round trip times in milli-seconds:');
   Log.Add(Format('    Minimum = %dms, Maximum = %dms, Average = %dms',[Minimum,Maximum,Round(Average/PacketsReceived)]));
   Result:=(Retries=PacketsReceived);
  end;
end;
end.
