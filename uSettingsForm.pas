unit uSettingsForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, uTypes;

type
  TfrmSettings = class(TForm)
    lblUrl: TLabel;
    edtUrl: TEdit;
    lblToken: TLabel;
    edtToken: TEdit;
    btnTest: TButton;
    chkAutostart: TCheckBox;
    chkAutoPause: TCheckBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  public
    class function Execute: Boolean;
  end;

implementation

uses
  uAppSettings, uJiraClient;

{$R *.dfm}

procedure TfrmSettings.FormCreate(Sender: TObject);
begin
  Caption := 'Настройки';
  lblUrl.Caption := 'Адрес Jira (например, https://jira.company.ru):';
  lblToken.Caption := 'Personal Access Token:';
  btnTest.Caption := 'Проверить соединение';
  chkAutostart.Caption := 'Запускать при старте Windows';
  chkAutoPause.Caption := 'Пауза при блокировке компьютера';
  btnOK.Caption := 'OK';
  btnCancel.Caption := 'Отмена';
end;

procedure TfrmSettings.FormShow(Sender: TObject);
begin
  edtUrl.Text := TAppSettings.JiraUrl;
  edtToken.Text := TAppSettings.JiraToken;
  chkAutostart.Checked := TAppSettings.AutostartEnabled;
  chkAutoPause.Checked := TAppSettings.AutoPauseOnLock;
end;

procedure TfrmSettings.btnTestClick(Sender: TObject);
var
  Client: TJiraClient;
  Name, Err: string;
begin
  if (Trim(edtUrl.Text) = '') or (Trim(edtToken.Text) = '') then
  begin
    MessageDlg('Укажите адрес Jira и токен.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    Client := TJiraClient.Create(Trim(edtUrl.Text), Trim(edtToken.Text));
    try
      if Client.TestConnection(Name, Err) then
        MessageDlg('Соединение установлено. Пользователь: ' + Name,
          mtInformation, [mbOK], 0)
      else
        MessageDlg('Ошибка соединения: ' + Err, mtError, [mbOK], 0);
    finally
      Client.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmSettings.btnOKClick(Sender: TObject);
begin
  TAppSettings.SetJiraUrl(edtUrl.Text);
  TAppSettings.SetJiraToken(edtToken.Text);
  TAppSettings.SetAutoPauseOnLock(chkAutoPause.Checked);
  TAppSettings.SetAutostartEnabled(chkAutostart.Checked);
  ModalResult := mrOk;
end;

class function TfrmSettings.Execute: Boolean;
var
  Frm: TfrmSettings;
begin
  Frm := TfrmSettings.Create(nil);
  try
    Result := Frm.ShowModal = mrOk;
  finally
    Frm.Free;
  end;
end;

end.
