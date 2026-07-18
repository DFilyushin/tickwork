unit uTypes;

interface

type
  TTaskType = (ttDevelopment, ttAnalysis, ttAdmin, ttMeeting, ttInterview);
  TTaskStatus = (tsPaused, tsActive, tsCompleted);

const
  APP_TITLE = 'Tickwork';

var
  // Зарегистрированное сообщение для активации первого экземпляра приложения
  WM_JTT_ACTIVATE: Cardinal = 0;

function TaskTypeName(AType: TTaskType): string;
function TaskStatusName(AStatus: TTaskStatus): string;
function FormatDuration(ASeconds: Int64): string;
function IsValidJiraKey(const S: string): Boolean;
function DateTimeToIso(const ADT: TDateTime): string;
function IsoToDateTime(const S: string): TDateTime;
function NowIso: string;

implementation

uses
  Winapi.Windows, System.SysUtils, System.RegularExpressions;

function TaskTypeName(AType: TTaskType): string;
const
  Names: array[TTaskType] of string = (
    'Разработка', 'Анализ', 'Административная', 'Созвон', 'Собеседование');
begin
  Result := Names[AType];
end;

function TaskStatusName(AStatus: TTaskStatus): string;
const
  Names: array[TTaskStatus] of string = ('Пауза', 'В работе', 'Завершена');
begin
  Result := Names[AStatus];
end;

function FormatDuration(ASeconds: Int64): string;
begin
  if ASeconds < 0 then
    ASeconds := 0;
  Result := Format('%d:%.2d:%.2d',
    [ASeconds div 3600, (ASeconds mod 3600) div 60, ASeconds mod 60]);
end;

function IsValidJiraKey(const S: string): Boolean;
begin
  Result := TRegEx.IsMatch(S, '^[A-Za-z][A-Za-z0-9_]*-\d+$');
end;

function DateTimeToIso(const ADT: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADT);
end;

function IsoToDateTime(const S: string): TDateTime;
begin
  // Формат фиксированный: 'yyyy-mm-dd hh:nn:ss', разбор не зависит от локали
  Result := EncodeDate(
      StrToInt(Copy(S, 1, 4)), StrToInt(Copy(S, 6, 2)), StrToInt(Copy(S, 9, 2))) +
    EncodeTime(
      StrToInt(Copy(S, 12, 2)), StrToInt(Copy(S, 15, 2)), StrToInt(Copy(S, 18, 2)), 0);
end;

function NowIso: string;
begin
  Result := DateTimeToIso(Now);
end;

initialization
  WM_JTT_ACTIVATE := RegisterWindowMessage('Tickwork.Activate');

end.
