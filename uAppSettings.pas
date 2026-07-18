unit uAppSettings;

interface

type
  TAppSettings = class
  public
    class function JiraUrl: string;
    class procedure SetJiraUrl(const AValue: string);
    class function JiraToken: string;
    class procedure SetJiraToken(const AValue: string);
    class function JiraConfigured: Boolean;
    class function AutoPauseOnLock: Boolean;
    class procedure SetAutoPauseOnLock(AValue: Boolean);
    class function AutostartEnabled: Boolean;
    class procedure SetAutostartEnabled(AValue: Boolean);
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.NetEncoding,
  System.Win.Registry, uDM;

const
  REG_RUN_KEY = 'Software\Microsoft\Windows\CurrentVersion\Run';
  REG_RUN_VALUE = 'Tickwork';
  REG_RUN_VALUE_LEGACY = 'JiraTimeTracker';

  SET_JIRA_URL = 'jira_url';
  SET_JIRA_TOKEN = 'jira_token';
  SET_AUTOPAUSE = 'autopause_on_lock';

{ DPAPI: шифрование токена под учётной записью текущего пользователя }

type
  DATA_BLOB = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDATA_BLOB = ^DATA_BLOB;

function CryptProtectData(pDataIn: PDATA_BLOB; szDataDescr: PWideChar;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall; external 'crypt32.dll';

function CryptUnprotectData(pDataIn: PDATA_BLOB; ppszDataDescr: Pointer;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall; external 'crypt32.dll';

function ProtectString(const S: string): string;
var
  InBlob, OutBlob: DATA_BLOB;
  Bytes, OutBytes: TBytes;
begin
  Result := '';
  if S = '' then
    Exit;
  Bytes := TEncoding.UTF8.GetBytes(S);
  InBlob.cbData := Length(Bytes);
  InBlob.pbData := @Bytes[0];
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
  try
    SetLength(OutBytes, OutBlob.cbData);
    Move(OutBlob.pbData^, OutBytes[0], OutBlob.cbData);
    Result := TNetEncoding.Base64.EncodeBytesToString(OutBytes);
    Result := Result.Replace(#13, '').Replace(#10, '');
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
end;

function UnprotectString(const S: string): string;
var
  InBlob, OutBlob: DATA_BLOB;
  Bytes, OutBytes: TBytes;
begin
  Result := '';
  if S = '' then
    Exit;
  try
    Bytes := TNetEncoding.Base64.DecodeStringToBytes(S);
  except
    Exit;
  end;
  if Length(Bytes) = 0 then
    Exit;
  InBlob.cbData := Length(Bytes);
  InBlob.pbData := @Bytes[0];
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    Exit;
  try
    SetLength(OutBytes, OutBlob.cbData);
    Move(OutBlob.pbData^, OutBytes[0], OutBlob.cbData);
    Result := TEncoding.UTF8.GetString(OutBytes);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
end;

{ TAppSettings }

class function TAppSettings.JiraUrl: string;
begin
  Result := Trim(DB.GetSetting(SET_JIRA_URL, ''));
  while Result.EndsWith('/') do
    Delete(Result, Length(Result), 1);
end;

class procedure TAppSettings.SetJiraUrl(const AValue: string);
begin
  DB.SetSetting(SET_JIRA_URL, Trim(AValue));
end;

class function TAppSettings.JiraToken: string;
begin
  Result := UnprotectString(DB.GetSetting(SET_JIRA_TOKEN, ''));
end;

class procedure TAppSettings.SetJiraToken(const AValue: string);
begin
  DB.SetSetting(SET_JIRA_TOKEN, ProtectString(Trim(AValue)));
end;

class function TAppSettings.JiraConfigured: Boolean;
begin
  Result := (JiraUrl <> '') and (JiraToken <> '');
end;

class function TAppSettings.AutoPauseOnLock: Boolean;
begin
  Result := DB.GetSetting(SET_AUTOPAUSE, '1') = '1';
end;

class procedure TAppSettings.SetAutoPauseOnLock(AValue: Boolean);
const
  Vals: array[Boolean] of string = ('0', '1');
begin
  DB.SetSetting(SET_AUTOPAUSE, Vals[AValue]);
end;

class function TAppSettings.AutostartEnabled: Boolean;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    Result := Reg.OpenKeyReadOnly(REG_RUN_KEY) and Reg.ValueExists(REG_RUN_VALUE);
  finally
    Reg.Free;
  end;
end;

class procedure TAppSettings.SetAutostartEnabled(AValue: Boolean);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_RUN_KEY, True) then
    begin
      if AValue then
        Reg.WriteString(REG_RUN_VALUE, '"' + ParamStr(0) + '" /autostart')
      else if Reg.ValueExists(REG_RUN_VALUE) then
        Reg.DeleteValue(REG_RUN_VALUE);
    end;
  finally
    Reg.Free;
  end;
end;

{ Автозапуск, настроенный под старым именем проекта, переносится на новое }
procedure MigrateLegacyAutostart;
var
  Reg: TRegistry;
begin
  try
    Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey(REG_RUN_KEY, False) and Reg.ValueExists(REG_RUN_VALUE_LEGACY) then
      begin
        Reg.DeleteValue(REG_RUN_VALUE_LEGACY);
        Reg.WriteString(REG_RUN_VALUE, '"' + ParamStr(0) + '" /autostart');
      end;
    finally
      Reg.Free;
    end;
  except
    // проблемы с реестром не должны мешать запуску приложения
  end;
end;

initialization
  MigrateLegacyAutostart;

end.
