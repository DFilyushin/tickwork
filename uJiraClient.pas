unit uJiraClient;

interface

type
  TJiraClient = class
  private
    FBaseUrl: string;
    FToken: string;
    function BuildUrl(const APath: string): string;
    function AuthHeaderValue: string;
  public
    constructor Create(const ABaseUrl, AToken: string);
    { GET /rest/api/2/myself — проверка адреса и токена }
    function TestConnection(out ADisplayName, AError: string): Boolean;
    { POST /rest/api/2/issue/<key>/worklog — фиксация отработанного времени }
    function AddWorklog(const AIssueKey: string; const AStarted: TDateTime;
      ASpentSeconds: Int64; const AComment: string;
      out AWorklogId, AError: string): Boolean;
  end;

function JiraStartedStr(const ADT: TDateTime): string;

implementation

uses
  System.SysUtils, System.Classes, System.JSON, System.Math, System.DateUtils,
  System.TimeSpan, System.Net.HttpClient, System.Net.URLClient, System.NetConsts;

const
  HTTP_CONNECT_TIMEOUT = 10000;
  HTTP_RESPONSE_TIMEOUT = 20000;

function JiraStartedStr(const ADT: TDateTime): string;
var
  Off: TTimeSpan;
  Sign: Char;
begin
  Off := TTimeZone.Local.GetUtcOffset(ADT);
  if Off.Ticks < 0 then
    Sign := '-'
  else
    Sign := '+';
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss".000"', ADT) +
    Sign + Format('%.2d%.2d', [Abs(Off.Hours), Abs(Off.Minutes)]);
end;

{ TJiraClient }

constructor TJiraClient.Create(const ABaseUrl, AToken: string);
begin
  inherited Create;
  FBaseUrl := Trim(ABaseUrl);
  while FBaseUrl.EndsWith('/') do
    Delete(FBaseUrl, Length(FBaseUrl), 1);
  FToken := AToken;
end;

function TJiraClient.BuildUrl(const APath: string): string;
begin
  Result := FBaseUrl + APath;
end;

function TJiraClient.AuthHeaderValue: string;
begin
  Result := 'Bearer ' + FToken;
end;

function TJiraClient.TestConnection(out ADisplayName, AError: string): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  J: TJSONValue;
begin
  Result := False;
  ADisplayName := '';
  AError := '';
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := HTTP_CONNECT_TIMEOUT;
    Client.ResponseTimeout := HTTP_RESPONSE_TIMEOUT;
    try
      Resp := Client.Get(BuildUrl('/rest/api/2/myself'), nil,
        [TNetHeader.Create('Authorization', AuthHeaderValue)]);
      if Resp.StatusCode = 200 then
      begin
        J := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
        try
          if J <> nil then
            ADisplayName := J.GetValue<string>('displayName', '');
        finally
          J.Free;
        end;
        Result := True;
      end
      else
        AError := Format('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Client.Free;
  end;
end;

function TJiraClient.AddWorklog(const AIssueKey: string;
  const AStarted: TDateTime; ASpentSeconds: Int64; const AComment: string;
  out AWorklogId, AError: string): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  Body: TJSONObject;
  J: TJSONValue;
  Src: TStringStream;
  Spent: Int64;
  Content: string;
begin
  Result := False;
  AWorklogId := '';
  AError := '';
  // Jira не принимает worklog меньше минуты; округляем вверх до минуты
  Spent := System.Math.Max(Int64(60), ((ASpentSeconds + 59) div 60) * 60);
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := HTTP_CONNECT_TIMEOUT;
    Client.ResponseTimeout := HTTP_RESPONSE_TIMEOUT;
    Client.ContentType := 'application/json';
    Body := TJSONObject.Create;
    try
      Body.AddPair('timeSpentSeconds', TJSONNumber.Create(Spent));
      Body.AddPair('started', JiraStartedStr(AStarted));
      if AComment <> '' then
        Body.AddPair('comment', AComment);
      Src := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
    finally
      Body.Free;
    end;
    try
      try
        Resp := Client.Post(
          BuildUrl('/rest/api/2/issue/' + AIssueKey + '/worklog'), Src, nil,
          [TNetHeader.Create('Authorization', AuthHeaderValue)]);
        if Resp.StatusCode in [200, 201] then
        begin
          J := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
          try
            if J <> nil then
              AWorklogId := J.GetValue<string>('id', '');
          finally
            J.Free;
          end;
          Result := True;
        end
        else
        begin
          Content := Resp.ContentAsString(TEncoding.UTF8);
          if Length(Content) > 300 then
            Content := Copy(Content, 1, 300) + '...';
          AError := Format('HTTP %d %s. %s',
            [Resp.StatusCode, Resp.StatusText, Content]);
        end;
      except
        on E: Exception do
          AError := E.Message;
      end;
    finally
      Src.Free;
    end;
  finally
    Client.Free;
  end;
end;

end.
