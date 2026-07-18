program Tickwork;

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  Vcl.Forms,
  uTypes in 'uTypes.pas',
  uDM in 'uDM.pas',
  uAppSettings in 'uAppSettings.pas',
  uJiraClient in 'uJiraClient.pas',
  uMain in 'uMain.pas' {frmMain},
  uTaskEditForm in 'uTaskEditForm.pas' {frmTaskEdit},
  uSettingsForm in 'uSettingsForm.pas' {frmSettings},
  uReportForm in 'uReportForm.pas' {frmReport};

{$R *.res}

begin
  // Единственный экземпляр: повторный запуск активирует окно первого
  CreateMutex(nil, True, 'Tickwork.SingleInstance');
  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    PostMessage(HWND_BROADCAST, WM_JTT_ACTIVATE, 0, 0);
    Exit;
  end;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := APP_TITLE;
  // При автозапуске с Windows стартуем свёрнутыми в трей
  if FindCmdLineSwitch('autostart', True) then
    Application.ShowMainForm := False;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
