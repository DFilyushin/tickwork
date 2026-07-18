unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Generics.Collections, System.UITypes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Menus, uTypes, uDM;

const
  WM_WTSSESSION_CHANGE = $02B1;
  WTS_SESSION_LOCK = $7;
  WTS_SESSION_UNLOCK = $8;
  NOTIFY_FOR_THIS_SESSION = 0;

type
  TfrmMain = class(TForm)
    pnlNew: TPanel;
    lblNewTitle: TLabel;
    edtTitle: TEdit;
    lblNewType: TLabel;
    cbType: TComboBox;
    lblNewJira: TLabel;
    edtJira: TEdit;
    chkStartNow: TCheckBox;
    btnCreate: TButton;
    lvTasks: TListView;
    pnlBottom: TPanel;
    btnStartPause: TButton;
    btnComplete: TButton;
    btnReports: TButton;
    btnSettings: TButton;
    lblUnsynced: TLabel;
    btnResend: TButton;
    trayIcon: TTrayIcon;
    pmTray: TPopupMenu;
    miOpen: TMenuItem;
    miTraySep1: TMenuItem;
    miPause: TMenuItem;
    miResume: TMenuItem;
    miSwitch: TMenuItem;
    miTraySep2: TMenuItem;
    miTraySettings: TMenuItem;
    miTrayReports: TMenuItem;
    miTraySep3: TMenuItem;
    miExit: TMenuItem;
    pmTasks: TPopupMenu;
    miTaskStartPause: TMenuItem;
    miTaskComplete: TMenuItem;
    miTaskEdit: TMenuItem;
    miTaskAddTime: TMenuItem;
    miTaskSep: TMenuItem;
    miTaskDelete: TMenuItem;
    tmrUI: TTimer;
    tmrHeartbeat: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnCreateClick(Sender: TObject);
    procedure btnStartPauseClick(Sender: TObject);
    procedure btnCompleteClick(Sender: TObject);
    procedure btnReportsClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnResendClick(Sender: TObject);
    procedure lvTasksSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure lvTasksDblClick(Sender: TObject);
    procedure tmrUITimer(Sender: TObject);
    procedure tmrHeartbeatTimer(Sender: TObject);
    procedure trayIconDblClick(Sender: TObject);
    procedure pmTrayPopup(Sender: TObject);
    procedure miOpenClick(Sender: TObject);
    procedure miPauseClick(Sender: TObject);
    procedure miResumeClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure pmTasksPopup(Sender: TObject);
    procedure miTaskEditClick(Sender: TObject);
    procedure miTaskAddTimeClick(Sender: TObject);
    procedure miTaskDeleteClick(Sender: TObject);
  private
    FAllowExit: Boolean;
    FAutoPausedTaskId: Int64;
    FLastActiveTaskId: Int64;
    FSyncing: TList<Int64>;
    FTrayInited: Boolean;
    FTrayActive: Boolean;
    procedure ApplyCaptions;
    procedure RefreshTasks;
    procedure RefreshUnsynced;
    procedure UpdateButtons;
    procedure UpdateTrayState;
    procedure UpdateActiveTime;
    function SelectedTaskId: Int64;
    function FindItemByTaskId(AId: Int64): TListItem;
    procedure StartOrPause(AId: Int64);
    procedure CompleteSelected;
    procedure SyncTask(const ATask: TTaskRec);
    procedure ResyncAll(ASilent: Boolean);
    procedure ShowMainWindow;
    procedure Balloon(const AMsg: string; AFlags: TBalloonFlags);
    procedure SwitchMenuClick(Sender: TObject);
    procedure WMQueryEndSession(var Msg: TWMQueryEndSession);
      message WM_QUERYENDSESSION;
    procedure WMWtsSessionChange(var Msg: TMessage);
      message WM_WTSSESSION_CHANGE;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TMessage); override;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  System.Threading, System.DateUtils, System.Math,
  uAppSettings, uJiraClient, uSettingsForm, uReportForm, uTaskEditForm;

{$R *.dfm}

function WTSRegisterSessionNotification(hWnd: HWND; dwFlags: DWORD): BOOL;
  stdcall; external 'wtsapi32.dll';
function WTSUnRegisterSessionNotification(hWnd: HWND): BOOL;
  stdcall; external 'wtsapi32.dll';

{ Иконка трея рисуется в рантайме: цветной круг (зелёный — идёт учёт) }
function MakeTrayIconHandle(AColor: TColor): HICON;
var
  ColorBmp, MaskBmp: TBitmap;
  Info: TIconInfo;
begin
  ColorBmp := TBitmap.Create;
  MaskBmp := TBitmap.Create;
  try
    ColorBmp.SetSize(16, 16);
    ColorBmp.Canvas.Brush.Color := clBlack;
    ColorBmp.Canvas.FillRect(Rect(0, 0, 16, 16));
    ColorBmp.Canvas.Brush.Color := AColor;
    ColorBmp.Canvas.Pen.Color := AColor;
    ColorBmp.Canvas.Ellipse(1, 1, 15, 15);

    MaskBmp.Monochrome := True;
    MaskBmp.SetSize(16, 16);
    MaskBmp.Canvas.Brush.Color := clWhite;
    MaskBmp.Canvas.FillRect(Rect(0, 0, 16, 16));
    MaskBmp.Canvas.Brush.Color := clBlack;
    MaskBmp.Canvas.Pen.Color := clBlack;
    MaskBmp.Canvas.Ellipse(1, 1, 15, 15);

    Info.fIcon := True;
    Info.xHotspot := 0;
    Info.yHotspot := 0;
    Info.hbmMask := MaskBmp.Handle;
    Info.hbmColor := ColorBmp.Handle;
    Result := CreateIconIndirect(Info);
  finally
    MaskBmp.Free;
    ColorBmp.Free;
  end;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Recovered: Integer;
begin
  FSyncing := TList<Int64>.Create;
  ApplyCaptions;
  DB := TTrackerDB.Create;
  Recovered := DB.RecoverAtStartup;
  RefreshTasks;
  RefreshUnsynced;
  UpdateTrayState;
  if Recovered > 0 then
    Balloon('Обнаружен незакрытый интервал работы (сбой или выключение). ' +
      'Время учтено по последней отметке, задача поставлена на паузу.',
      bfWarning);
  ResyncAll(True);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(DB);
  FSyncing.Free;
end;

procedure TfrmMain.ApplyCaptions;
var
  T: TTaskType;
begin
  Caption := APP_TITLE;
  lblNewTitle.Caption := 'Название задачи:';
  lblNewType.Caption := 'Тип задачи:';
  lblNewJira.Caption := 'Задача Jira:';
  chkStartNow.Caption := 'Начать работу сразу';
  btnCreate.Caption := 'Создать задачу';
  btnStartPause.Caption := 'Старт';
  btnComplete.Caption := 'Завершить';
  btnReports.Caption := 'Отчёты';
  btnSettings.Caption := 'Настройки';
  btnResend.Caption := 'Отправить в Jira';
  lblUnsynced.Caption := '';
  lvTasks.Columns[0].Caption := 'Задача';
  lvTasks.Columns[1].Caption := 'Тип';
  lvTasks.Columns[2].Caption := 'Jira';
  lvTasks.Columns[3].Caption := 'Статус';
  lvTasks.Columns[4].Caption := 'Время';
  miOpen.Caption := 'Открыть';
  miPause.Caption := 'Пауза';
  miResume.Caption := 'Продолжить';
  miSwitch.Caption := 'Переключиться на задачу';
  miTraySettings.Caption := 'Настройки';
  miTrayReports.Caption := 'Отчёты';
  miExit.Caption := 'Выход';
  miTaskStartPause.Caption := 'Старт / Пауза';
  miTaskComplete.Caption := 'Завершить';
  miTaskEdit.Caption := 'Редактировать...';
  miTaskAddTime.Caption := 'Добавить время вручную...';
  miTaskDelete.Caption := 'Удалить';
  cbType.Items.Clear;
  for T := Low(TTaskType) to High(TTaskType) do
    cbType.Items.Add(TaskTypeName(T));
  cbType.ItemIndex := 0;
  trayIcon.Hint := APP_TITLE;
end;

{ Список задач }

procedure TfrmMain.RefreshTasks;
var
  Tasks: TArray<TTaskRec>;
  R: TTaskRec;
  Item: TListItem;
  SelId: Int64;
begin
  SelId := SelectedTaskId;
  lvTasks.Items.BeginUpdate;
  try
    lvTasks.Items.Clear;
    Tasks := DB.GetOpenTasks;
    for R in Tasks do
    begin
      Item := lvTasks.Items.Add;
      Item.Caption := R.Title;
      Item.Data := Pointer(NativeInt(R.Id));
      Item.SubItems.Add(TaskTypeName(R.TaskType));
      Item.SubItems.Add(R.JiraKey);
      Item.SubItems.Add(TaskStatusName(R.Status));
      Item.SubItems.Add(FormatDuration(R.TotalSeconds));
      if R.Status = tsActive then
        FLastActiveTaskId := R.Id;
      if R.Id = SelId then
        Item.Selected := True;
    end;
  finally
    lvTasks.Items.EndUpdate;
  end;
  UpdateButtons;
  UpdateTrayState;
end;

procedure TfrmMain.RefreshUnsynced;
var
  N: Integer;
begin
  N := Length(DB.GetUnsyncedCompleted);
  btnResend.Visible := N > 0;
  if N > 0 then
    lblUnsynced.Caption := Format('Не передано в Jira: %d', [N])
  else
    lblUnsynced.Caption := '';
end;

function TfrmMain.SelectedTaskId: Int64;
begin
  if lvTasks.Selected <> nil then
    Result := NativeInt(lvTasks.Selected.Data)
  else
    Result := 0;
end;

function TfrmMain.FindItemByTaskId(AId: Int64): TListItem;
var
  I: Integer;
begin
  for I := 0 to lvTasks.Items.Count - 1 do
    if NativeInt(lvTasks.Items[I].Data) = AId then
      Exit(lvTasks.Items[I]);
  Result := nil;
end;

procedure TfrmMain.UpdateButtons;
var
  Id: Int64;
begin
  Id := SelectedTaskId;
  btnStartPause.Enabled := Id <> 0;
  btnComplete.Enabled := Id <> 0;
  if (Id <> 0) and (Id = DB.GetActiveTaskId) then
    btnStartPause.Caption := 'Пауза'
  else
    btnStartPause.Caption := 'Старт';
end;

{ Создание и управление задачами }

procedure TfrmMain.btnCreateClick(Sender: TObject);
var
  Title, Jira: string;
  Id: Int64;
begin
  Title := Trim(edtTitle.Text);
  if Title = '' then
  begin
    MessageDlg('Укажите название задачи.', mtWarning, [mbOK], 0);
    edtTitle.SetFocus;
    Exit;
  end;
  Jira := Trim(UpperCase(edtJira.Text));
  if (Jira <> '') and not IsValidJiraKey(Jira) then
  begin
    MessageDlg('Неверный номер задачи Jira. Ожидается формат PROJ-123.',
      mtWarning, [mbOK], 0);
    edtJira.SetFocus;
    Exit;
  end;
  Id := DB.CreateTask(Title, TTaskType(cbType.ItemIndex), Jira);
  if chkStartNow.Checked then
  begin
    DB.StartTask(Id);
    FLastActiveTaskId := Id;
  end;
  edtTitle.Text := '';
  edtJira.Text := '';
  edtTitle.SetFocus;
  RefreshTasks;
end;

procedure TfrmMain.StartOrPause(AId: Int64);
begin
  if AId = 0 then
    Exit;
  if AId = DB.GetActiveTaskId then
    DB.PauseTask(AId)
  else
    DB.StartTask(AId);
  FLastActiveTaskId := AId;
  RefreshTasks;
end;

procedure TfrmMain.btnStartPauseClick(Sender: TObject);
begin
  StartOrPause(SelectedTaskId);
end;

procedure TfrmMain.lvTasksDblClick(Sender: TObject);
begin
  StartOrPause(SelectedTaskId);
end;

procedure TfrmMain.lvTasksSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  UpdateButtons;
end;

procedure TfrmMain.CompleteSelected;
var
  Id: Int64;
  R: TTaskRec;
begin
  Id := SelectedTaskId;
  if Id = 0 then
    Exit;
  R := DB.GetTask(Id);
  if MessageDlg(Format('Завершить задачу "%s"?%sОтработано: %s',
    [R.Title, sLineBreak, FormatDuration(R.TotalSeconds)]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  DB.CompleteTask(Id);
  if FLastActiveTaskId = Id then
    FLastActiveTaskId := 0;
  RefreshTasks;
  RefreshUnsynced;
  if R.JiraKey <> '' then
  begin
    if TAppSettings.JiraConfigured then
      SyncTask(DB.GetTask(Id))
    else
      Balloon('Jira не настроена: время по ' + R.JiraKey +
        ' сохранено локально и будет отправлено позже.', bfWarning);
  end;
end;

procedure TfrmMain.btnCompleteClick(Sender: TObject);
begin
  CompleteSelected;
end;

procedure TfrmMain.pmTasksPopup(Sender: TObject);
var
  HasSel: Boolean;
begin
  HasSel := SelectedTaskId <> 0;
  miTaskStartPause.Enabled := HasSel;
  miTaskComplete.Enabled := HasSel;
  miTaskEdit.Enabled := HasSel;
  miTaskAddTime.Enabled := HasSel;
  miTaskDelete.Enabled := HasSel;
end;

procedure TfrmMain.miTaskEditClick(Sender: TObject);
var
  Id: Int64;
  R: TTaskRec;
  Title, Jira: string;
  TaskType: TTaskType;
begin
  Id := SelectedTaskId;
  if Id = 0 then
    Exit;
  R := DB.GetTask(Id);
  Title := R.Title;
  TaskType := R.TaskType;
  Jira := R.JiraKey;
  if TfrmTaskEdit.Execute(Title, TaskType, Jira) then
  begin
    DB.UpdateTask(Id, Title, TaskType, Jira);
    RefreshTasks;
  end;
end;

procedure TfrmMain.miTaskAddTimeClick(Sender: TObject);
var
  Id: Int64;
  S: string;
  Minutes: Integer;
begin
  Id := SelectedTaskId;
  if Id = 0 then
    Exit;
  S := InputBox('Добавить время вручную',
    'Сколько минут добавить к задаче:', '30');
  if S = '' then
    Exit;
  if not TryStrToInt(Trim(S), Minutes) or (Minutes <= 0) or (Minutes > 24 * 60) then
  begin
    MessageDlg('Укажите число минут от 1 до 1440.', mtWarning, [mbOK], 0);
    Exit;
  end;
  DB.AddManualInterval(Id, IncMinute(Now, -Minutes), Now);
  RefreshTasks;
end;

procedure TfrmMain.miTaskDeleteClick(Sender: TObject);
var
  Id: Int64;
  R: TTaskRec;
begin
  Id := SelectedTaskId;
  if Id = 0 then
    Exit;
  R := DB.GetTask(Id);
  if MessageDlg(Format('Удалить задачу "%s" вместе с учтённым временем (%s)?',
    [R.Title, FormatDuration(R.TotalSeconds)]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  DB.DeleteTask(Id);
  if FLastActiveTaskId = Id then
    FLastActiveTaskId := 0;
  RefreshTasks;
end;

{ Синхронизация с Jira }

procedure TfrmMain.SyncTask(const ATask: TTaskRec);
var
  Id, Seconds: Int64;
  Key, Title, Url, Token: string;
  Started: TDateTime;
begin
  if FSyncing.Contains(ATask.Id) then
    Exit;
  FSyncing.Add(ATask.Id);
  Id := ATask.Id;
  Key := ATask.JiraKey;
  Title := ATask.Title;
  Seconds := DB.GetTaskSeconds(Id);
  Started := DB.GetTaskFirstStart(Id);
  Url := TAppSettings.JiraUrl;
  Token := TAppSettings.JiraToken;
  TTask.Run(
    procedure
    var
      Client: TJiraClient;
      Ok: Boolean;
      WorklogId, Err: string;
    begin
      Client := TJiraClient.Create(Url, Token);
      try
        Ok := Client.AddWorklog(Key, Started, Seconds, Title, WorklogId, Err);
      finally
        Client.Free;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if DB = nil then
            Exit;
          FSyncing.Remove(Id);
          if Ok then
          begin
            DB.MarkSynced(Id, WorklogId);
            Balloon(Format('Время передано в Jira: %s (%s)',
              [Key, FormatDuration(Seconds)]), bfInfo);
          end
          else
          begin
            DB.MarkSyncError(Id, Err);
            Balloon(Format('Ошибка передачи в Jira (%s): %s', [Key, Err]),
              bfError);
          end;
          RefreshUnsynced;
        end);
    end);
end;

procedure TfrmMain.ResyncAll(ASilent: Boolean);
var
  Tasks: TArray<TTaskRec>;
  R: TTaskRec;
begin
  if not TAppSettings.JiraConfigured then
  begin
    if not ASilent then
      MessageDlg('Укажите адрес Jira и токен в настройках.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Tasks := DB.GetUnsyncedCompleted;
  for R in Tasks do
    SyncTask(R);
end;

procedure TfrmMain.btnResendClick(Sender: TObject);
begin
  ResyncAll(False);
end;

{ Настройки и отчёты }

procedure TfrmMain.btnSettingsClick(Sender: TObject);
begin
  TfrmSettings.Execute;
end;

procedure TfrmMain.btnReportsClick(Sender: TObject);
begin
  TfrmReport.Execute;
end;

{ Таймеры }

procedure TfrmMain.tmrUITimer(Sender: TObject);
begin
  if DB <> nil then
    UpdateActiveTime;
end;

procedure TfrmMain.tmrHeartbeatTimer(Sender: TObject);
begin
  if DB <> nil then
    DB.Heartbeat;
end;

procedure TfrmMain.UpdateActiveTime;
var
  ActiveId: Int64;
  Item: TListItem;
  Secs: Int64;
  R: TTaskRec;
begin
  ActiveId := DB.GetActiveTaskId;
  if ActiveId = 0 then
    Exit;
  Secs := DB.GetTaskSeconds(ActiveId);
  if Visible then
  begin
    Item := FindItemByTaskId(ActiveId);
    if Item <> nil then
      Item.SubItems[3] := FormatDuration(Secs);
  end;
  R := DB.GetTask(ActiveId);
  trayIcon.Hint := APP_TITLE + ': ' + R.Title + ' — ' + FormatDuration(Secs);
end;

{ Трей }

procedure TfrmMain.UpdateTrayState;
var
  ActiveId: Int64;
  R: TTaskRec;
  IsActive: Boolean;
const
  COLOR_ACTIVE = TColor($2FA84F);  // зелёный
  COLOR_PAUSED = TColor($808080);  // серый
begin
  ActiveId := DB.GetActiveTaskId;
  IsActive := ActiveId <> 0;
  if IsActive then
  begin
    R := DB.GetTask(ActiveId);
    trayIcon.Hint := APP_TITLE + ': ' + R.Title + ' — ' +
      FormatDuration(R.TotalSeconds);
  end
  else
    trayIcon.Hint := APP_TITLE + ': нет активной задачи';
  if (not FTrayInited) or (FTrayActive <> IsActive) then
  begin
    if IsActive then
      trayIcon.Icon.Handle := MakeTrayIconHandle(COLOR_ACTIVE)
    else
      trayIcon.Icon.Handle := MakeTrayIconHandle(COLOR_PAUSED);
    FTrayInited := True;
    FTrayActive := IsActive;
  end;
end;

procedure TfrmMain.Balloon(const AMsg: string; AFlags: TBalloonFlags);
begin
  trayIcon.BalloonTitle := APP_TITLE;
  trayIcon.BalloonHint := AMsg;
  trayIcon.BalloonFlags := AFlags;
  trayIcon.ShowBalloonHint;
end;

procedure TfrmMain.ShowMainWindow;
begin
  Show;
  WindowState := wsNormal;
  Application.BringToFront;
  SetForegroundWindow(Handle);
end;

procedure TfrmMain.trayIconDblClick(Sender: TObject);
begin
  ShowMainWindow;
end;

procedure TfrmMain.miOpenClick(Sender: TObject);
begin
  ShowMainWindow;
end;

procedure TfrmMain.pmTrayPopup(Sender: TObject);
var
  ActiveId: Int64;
  Tasks: TArray<TTaskRec>;
  R: TTaskRec;
  MI: TMenuItem;
begin
  ActiveId := DB.GetActiveTaskId;
  Tasks := DB.GetOpenTasks;
  miPause.Enabled := ActiveId <> 0;
  miResume.Enabled := (ActiveId = 0) and (Length(Tasks) > 0);
  miSwitch.Clear;
  miSwitch.Enabled := Length(Tasks) > 0;
  for R in Tasks do
  begin
    MI := TMenuItem.Create(pmTray);
    MI.Caption := StringReplace(R.Title, '&', '&&', [rfReplaceAll]);
    MI.Tag := NativeInt(R.Id);
    MI.Checked := R.Status = tsActive;
    MI.OnClick := SwitchMenuClick;
    miSwitch.Add(MI);
  end;
end;

procedure TfrmMain.SwitchMenuClick(Sender: TObject);
var
  Id: Int64;
begin
  Id := (Sender as TMenuItem).Tag;
  if Id <> DB.GetActiveTaskId then
  begin
    DB.StartTask(Id);
    FLastActiveTaskId := Id;
    RefreshTasks;
  end;
end;

procedure TfrmMain.miPauseClick(Sender: TObject);
begin
  DB.PauseActiveTask;
  RefreshTasks;
end;

procedure TfrmMain.miResumeClick(Sender: TObject);
var
  Tasks: TArray<TTaskRec>;
  R: TTaskRec;
begin
  Tasks := DB.GetOpenTasks;
  if Length(Tasks) = 0 then
    Exit;
  // Возобновляем последнюю активную задачу, если она ещё не завершена
  for R in Tasks do
    if R.Id = FLastActiveTaskId then
    begin
      DB.StartTask(R.Id);
      RefreshTasks;
      Exit;
    end;
  DB.StartTask(Tasks[0].Id);
  FLastActiveTaskId := Tasks[0].Id;
  RefreshTasks;
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  FAllowExit := True;
  Close;
end;

{ Жизненный цикл окна }

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not FAllowExit then
  begin
    CanClose := False;
    Hide;
  end;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Выход из приложения: закрываем открытый интервал
  if DB <> nil then
    DB.PauseActiveTask;
end;

procedure TfrmMain.WMQueryEndSession(var Msg: TWMQueryEndSession);
begin
  if DB <> nil then
    DB.PauseActiveTask;
  FAllowExit := True;
  Msg.Result := 1;
end;

procedure TfrmMain.WMWtsSessionChange(var Msg: TMessage);
begin
  if DB = nil then
    Exit;
  case Msg.WParam of
    WTS_SESSION_LOCK:
      if TAppSettings.AutoPauseOnLock then
      begin
        FAutoPausedTaskId := DB.GetActiveTaskId;
        if FAutoPausedTaskId <> 0 then
        begin
          DB.PauseTask(FAutoPausedTaskId);
          RefreshTasks;
        end;
      end;
    WTS_SESSION_UNLOCK:
      if FAutoPausedTaskId <> 0 then
      begin
        DB.StartTask(FAutoPausedTaskId);
        FLastActiveTaskId := FAutoPausedTaskId;
        FAutoPausedTaskId := 0;
        RefreshTasks;
      end;
  end;
end;

procedure TfrmMain.CreateWnd;
begin
  inherited;
  WTSRegisterSessionNotification(Handle, NOTIFY_FOR_THIS_SESSION);
end;

procedure TfrmMain.DestroyWnd;
begin
  WTSUnRegisterSessionNotification(Handle);
  inherited;
end;

procedure TfrmMain.WndProc(var Message: TMessage);
begin
  // Второй экземпляр приложения просит показать окно первого
  if (WM_JTT_ACTIVATE <> 0) and (Message.Msg = WM_JTT_ACTIVATE) then
  begin
    ShowMainWindow;
    Message.Result := 1;
  end
  else
    inherited;
end;

end.
