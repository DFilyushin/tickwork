unit uDM;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Stan.Param, FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.ConsoleUI.Wait, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.Comp.UI,
  uTypes;

type
  TTaskRec = record
    Id: Int64;
    Title: string;
    TaskType: TTaskType;
    JiraKey: string;
    Status: TTaskStatus;
    CreatedAt: TDateTime;
    Synced: Boolean;
    SyncError: string;
    TotalSeconds: Int64;
  end;

  TReportRow = record
    TaskId: Int64;
    Title: string;
    TaskType: TTaskType;
    JiraKey: string;
    Status: TTaskStatus;
    Synced: Boolean;
    Seconds: Int64;
  end;

  TTrackerDB = class
  private
    FDriverLink: TFDPhysSQLiteDriverLink;
    FWaitCursor: TFDGUIxWaitCursor;
    FConn: TFDConnection;
    procedure CreateSchema;
    procedure CloseOpenIntervals(ATaskId: Int64);
    function QueryTasks(const AWhere: string): TArray<TTaskRec>;
  public
    constructor Create;
    destructor Destroy; override;
    class function DataDir: string;

    { Задачи }
    function CreateTask(const ATitle: string; AType: TTaskType;
      const AJiraKey: string): Int64;
    procedure UpdateTask(AId: Int64; const ATitle: string; AType: TTaskType;
      const AJiraKey: string);
    procedure DeleteTask(AId: Int64);
    function GetTask(AId: Int64): TTaskRec;
    function GetOpenTasks: TArray<TTaskRec>;
    function GetUnsyncedCompleted: TArray<TTaskRec>;
    function GetActiveTaskId: Int64;

    { Учёт времени }
    procedure StartTask(AId: Int64);
    procedure PauseTask(AId: Int64);
    procedure PauseActiveTask;
    procedure CompleteTask(AId: Int64);
    procedure AddManualInterval(ATaskId: Int64; const AStart, AStop: TDateTime);
    function GetTaskSeconds(AId: Int64): Int64;
    function GetTaskFirstStart(AId: Int64): TDateTime;
    procedure Heartbeat;
    function RecoverAtStartup: Integer;

    { Синхронизация с Jira }
    procedure MarkSynced(AId: Int64; const AWorklogId: string);
    procedure MarkSyncError(AId: Int64; const AError: string);

    { Настройки }
    function GetSetting(const AKey, ADefault: string): string;
    procedure SetSetting(const AKey, AValue: string);

    { Отчёты }
    function GetReportRows(const AFrom, ATo: TDateTime): TArray<TReportRow>;
  end;

var
  DB: TTrackerDB = nil;

implementation

uses
  System.Variants, System.IOUtils, System.Math;

{ TTrackerDB }

class function TTrackerDB.DataDir: string;
begin
  Result := TPath.Combine(TPath.GetHomePath, 'Tickwork');
end;

constructor TTrackerDB.Create;
var
  LegacyDir: string;
begin
  inherited Create;
  // Миграция данных со старого имени проекта (JiraTimeTracker)
  LegacyDir := TPath.Combine(TPath.GetHomePath, 'JiraTimeTracker');
  if (not TDirectory.Exists(DataDir)) and TDirectory.Exists(LegacyDir) then
  try
    TDirectory.Move(LegacyDir, DataDir);
  except
    // не удалось перенести — продолжаем с новой пустой базой
  end;
  ForceDirectories(DataDir);
  // «Тихий» курсор ожидания: без него FireDAC мигает песочными часами
  // на каждый запрос (UI-таймер опрашивает БД раз в секунду)
  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
  FDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  FConn := TFDConnection.Create(nil);
  FConn.Params.DriverID := 'SQLite';
  FConn.Params.Database := TPath.Combine(DataDir, 'tracker.db');
  FConn.Params.Add('JournalMode=WAL');
  FConn.Params.Add('LockingMode=Normal');
  FConn.LoginPrompt := False;
  FConn.Connected := True;
  CreateSchema;
end;

destructor TTrackerDB.Destroy;
begin
  FConn.Free;
  FDriverLink.Free;
  FWaitCursor.Free;
  inherited;
end;

procedure TTrackerDB.CreateSchema;
begin
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS tasks (' +
    '  id              INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  title           TEXT NOT NULL,' +
    '  task_type       INTEGER NOT NULL,' +
    '  jira_key        TEXT,' +
    '  status          INTEGER NOT NULL DEFAULT 0,' +
    '  created_at      TEXT NOT NULL,' +
    '  completed_at    TEXT,' +
    '  synced          INTEGER NOT NULL DEFAULT 0,' +
    '  synced_at       TEXT,' +
    '  jira_worklog_id TEXT,' +
    '  sync_error      TEXT)');
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS work_intervals (' +
    '  id           INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  task_id      INTEGER NOT NULL REFERENCES tasks(id),' +
    '  started_at   TEXT NOT NULL,' +
    '  stopped_at   TEXT,' +
    '  heartbeat_at TEXT)');
  FConn.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_intervals_task ON work_intervals(task_id)');
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)');
  FConn.ExecSQL(
    'INSERT OR IGNORE INTO settings (key, value) VALUES (''schema_version'', ''1'')');
end;

function TTrackerDB.CreateTask(const ATitle: string; AType: TTaskType;
  const AJiraKey: string): Int64;
begin
  FConn.ExecSQL(
    'INSERT INTO tasks (title, task_type, jira_key, status, created_at) ' +
    'VALUES (:t, :ty, NULLIF(:j, ''''), 0, :c)',
    [ATitle, Ord(AType), AJiraKey, NowIso]);
  Result := FConn.GetLastAutoGenValue('');
end;

procedure TTrackerDB.UpdateTask(AId: Int64; const ATitle: string;
  AType: TTaskType; const AJiraKey: string);
begin
  FConn.ExecSQL(
    'UPDATE tasks SET title = :t, task_type = :ty, jira_key = NULLIF(:j, '''') ' +
    'WHERE id = :id',
    [ATitle, Ord(AType), AJiraKey, AId]);
end;

procedure TTrackerDB.DeleteTask(AId: Int64);
begin
  FConn.StartTransaction;
  try
    FConn.ExecSQL('DELETE FROM work_intervals WHERE task_id = :id', [AId]);
    FConn.ExecSQL('DELETE FROM tasks WHERE id = :id', [AId]);
    FConn.Commit;
  except
    FConn.Rollback;
    raise;
  end;
end;

function TTrackerDB.QueryTasks(const AWhere: string): TArray<TTaskRec>;
var
  Q: TFDQuery;
  L: TList<TTaskRec>;
  R: TTaskRec;
begin
  Q := TFDQuery.Create(nil);
  L := TList<TTaskRec>.Create;
  try
    Q.Connection := FConn;
    Q.SQL.Text :=
      'SELECT t.id, t.title, t.task_type, t.jira_key, t.status, t.created_at, ' +
      '       t.synced, t.sync_error, ' +
      '  IFNULL((SELECT SUM(strftime(''%s'', IFNULL(wi.stopped_at, :n)) - ' +
      '                     strftime(''%s'', wi.started_at)) ' +
      '          FROM work_intervals wi WHERE wi.task_id = t.id), 0) AS total_sec ' +
      'FROM tasks t WHERE ' + AWhere + ' ORDER BY t.created_at, t.id';
    Q.ParamByName('n').AsString := NowIso;
    Q.Open;
    while not Q.Eof do
    begin
      R.Id := Q.FieldByName('id').AsLargeInt;
      R.Title := Q.FieldByName('title').AsString;
      R.TaskType := TTaskType(Q.FieldByName('task_type').AsInteger);
      R.JiraKey := Q.FieldByName('jira_key').AsString;
      R.Status := TTaskStatus(Q.FieldByName('status').AsInteger);
      R.CreatedAt := IsoToDateTime(Q.FieldByName('created_at').AsString);
      R.Synced := Q.FieldByName('synced').AsInteger <> 0;
      R.SyncError := Q.FieldByName('sync_error').AsString;
      R.TotalSeconds := Q.FieldByName('total_sec').AsLargeInt;
      L.Add(R);
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    L.Free;
    Q.Free;
  end;
end;

function TTrackerDB.GetTask(AId: Int64): TTaskRec;
var
  Arr: TArray<TTaskRec>;
begin
  Arr := QueryTasks('t.id = ' + IntToStr(AId));
  if Length(Arr) = 0 then
    raise Exception.CreateFmt('Задача %d не найдена', [AId]);
  Result := Arr[0];
end;

function TTrackerDB.GetOpenTasks: TArray<TTaskRec>;
begin
  Result := QueryTasks('t.status IN (0, 1)');
end;

function TTrackerDB.GetUnsyncedCompleted: TArray<TTaskRec>;
begin
  Result := QueryTasks(
    't.status = 2 AND t.synced = 0 AND t.jira_key IS NOT NULL AND t.jira_key <> ''''');
end;

function TTrackerDB.GetActiveTaskId: Int64;
var
  V: Variant;
begin
  V := FConn.ExecSQLScalar('SELECT id FROM tasks WHERE status = 1 LIMIT 1');
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := 0
  else
    Result := V;
end;

procedure TTrackerDB.CloseOpenIntervals(ATaskId: Int64);
begin
  if ATaskId = 0 then
    FConn.ExecSQL(
      'UPDATE work_intervals SET stopped_at = :n WHERE stopped_at IS NULL',
      [NowIso])
  else
    FConn.ExecSQL(
      'UPDATE work_intervals SET stopped_at = :n ' +
      'WHERE stopped_at IS NULL AND task_id = :id',
      [NowIso, ATaskId]);
end;

procedure TTrackerDB.StartTask(AId: Int64);
var
  Ts: string;
begin
  FConn.StartTransaction;
  try
    // Активной может быть только одна задача: текущую ставим на паузу
    CloseOpenIntervals(0);
    FConn.ExecSQL('UPDATE tasks SET status = 0 WHERE status = 1');
    Ts := NowIso;
    FConn.ExecSQL('UPDATE tasks SET status = 1 WHERE id = :id', [AId]);
    FConn.ExecSQL(
      'INSERT INTO work_intervals (task_id, started_at, heartbeat_at) ' +
      'VALUES (:id, :s, :h)', [AId, Ts, Ts]);
    FConn.Commit;
  except
    FConn.Rollback;
    raise;
  end;
end;

procedure TTrackerDB.PauseTask(AId: Int64);
begin
  FConn.StartTransaction;
  try
    CloseOpenIntervals(AId);
    FConn.ExecSQL('UPDATE tasks SET status = 0 WHERE id = :id AND status = 1', [AId]);
    FConn.Commit;
  except
    FConn.Rollback;
    raise;
  end;
end;

procedure TTrackerDB.PauseActiveTask;
var
  Id: Int64;
begin
  Id := GetActiveTaskId;
  if Id <> 0 then
    PauseTask(Id);
end;

procedure TTrackerDB.CompleteTask(AId: Int64);
begin
  FConn.StartTransaction;
  try
    CloseOpenIntervals(AId);
    FConn.ExecSQL(
      'UPDATE tasks SET status = 2, completed_at = :c WHERE id = :id',
      [NowIso, AId]);
    FConn.Commit;
  except
    FConn.Rollback;
    raise;
  end;
end;

procedure TTrackerDB.AddManualInterval(ATaskId: Int64;
  const AStart, AStop: TDateTime);
begin
  FConn.ExecSQL(
    'INSERT INTO work_intervals (task_id, started_at, stopped_at) ' +
    'VALUES (:id, :s, :e)',
    [ATaskId, DateTimeToIso(AStart), DateTimeToIso(AStop)]);
end;

function TTrackerDB.GetTaskSeconds(AId: Int64): Int64;
var
  V: Variant;
begin
  V := FConn.ExecSQLScalar(
    'SELECT IFNULL(SUM(strftime(''%s'', IFNULL(stopped_at, :n)) - ' +
    '               strftime(''%s'', started_at)), 0) ' +
    'FROM work_intervals WHERE task_id = :id',
    [NowIso, AId]);
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := 0
  else
    Result := V;
end;

function TTrackerDB.GetTaskFirstStart(AId: Int64): TDateTime;
var
  V: Variant;
begin
  V := FConn.ExecSQLScalar(
    'SELECT MIN(started_at) FROM work_intervals WHERE task_id = :id', [AId]);
  if VarIsNull(V) or VarIsEmpty(V) or (VarToStr(V) = '') then
  begin
    V := FConn.ExecSQLScalar('SELECT created_at FROM tasks WHERE id = :id', [AId]);
    if VarIsNull(V) or VarIsEmpty(V) then
      Exit(Now);
  end;
  Result := IsoToDateTime(VarToStr(V));
end;

procedure TTrackerDB.Heartbeat;
begin
  FConn.ExecSQL(
    'UPDATE work_intervals SET heartbeat_at = :n WHERE stopped_at IS NULL',
    [NowIso]);
end;

function TTrackerDB.RecoverAtStartup: Integer;
begin
  // Незакрытые интервалы (крэш, выключение) закрываем по последнему heartbeat
  Result := FConn.ExecSQL(
    'UPDATE work_intervals SET stopped_at = COALESCE(heartbeat_at, started_at) ' +
    'WHERE stopped_at IS NULL');
  FConn.ExecSQL('UPDATE tasks SET status = 0 WHERE status = 1');
end;

procedure TTrackerDB.MarkSynced(AId: Int64; const AWorklogId: string);
begin
  FConn.ExecSQL(
    'UPDATE tasks SET synced = 1, synced_at = :s, jira_worklog_id = :w, ' +
    'sync_error = NULL WHERE id = :id',
    [NowIso, AWorklogId, AId]);
end;

procedure TTrackerDB.MarkSyncError(AId: Int64; const AError: string);
begin
  FConn.ExecSQL('UPDATE tasks SET sync_error = :e WHERE id = :id', [AError, AId]);
end;

function TTrackerDB.GetSetting(const AKey, ADefault: string): string;
var
  V: Variant;
begin
  V := FConn.ExecSQLScalar('SELECT value FROM settings WHERE key = :k', [AKey]);
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := ADefault
  else
    Result := VarToStr(V);
end;

procedure TTrackerDB.SetSetting(const AKey, AValue: string);
begin
  FConn.ExecSQL(
    'INSERT OR REPLACE INTO settings (key, value) VALUES (:k, :v)',
    [AKey, AValue]);
end;

function TTrackerDB.GetReportRows(const AFrom, ATo: TDateTime): TArray<TReportRow>;
var
  Q: TFDQuery;
  L: TList<TReportRow>;
  Idx: TDictionary<Int64, Integer>;
  R: TReportRow;
  TaskId: Int64;
  S, E: TDateTime;
  Sec: Int64;
  I: Integer;
begin
  Q := TFDQuery.Create(nil);
  L := TList<TReportRow>.Create;
  Idx := TDictionary<Int64, Integer>.Create;
  try
    Q.Connection := FConn;
    Q.SQL.Text :=
      'SELECT t.id, t.title, t.task_type, t.jira_key, t.status, t.synced, ' +
      '       wi.started_at, IFNULL(wi.stopped_at, :n) AS sto ' +
      'FROM work_intervals wi JOIN tasks t ON t.id = wi.task_id ' +
      'WHERE wi.started_at < :pto AND IFNULL(wi.stopped_at, :n) > :pfrom ' +
      'ORDER BY t.created_at, t.id';
    Q.ParamByName('n').AsString := NowIso;
    Q.ParamByName('pfrom').AsString := DateTimeToIso(AFrom);
    Q.ParamByName('pto').AsString := DateTimeToIso(ATo);
    Q.Open;
    while not Q.Eof do
    begin
      TaskId := Q.FieldByName('id').AsLargeInt;
      // Интервал обрезается по границам периода
      S := Max(IsoToDateTime(Q.FieldByName('started_at').AsString), AFrom);
      E := Min(IsoToDateTime(Q.FieldByName('sto').AsString), ATo);
      Sec := Round((E - S) * SecsPerDay);
      if Sec > 0 then
      begin
        if Idx.TryGetValue(TaskId, I) then
        begin
          R := L[I];
          R.Seconds := R.Seconds + Sec;
          L[I] := R;
        end
        else
        begin
          R.TaskId := TaskId;
          R.Title := Q.FieldByName('title').AsString;
          R.TaskType := TTaskType(Q.FieldByName('task_type').AsInteger);
          R.JiraKey := Q.FieldByName('jira_key').AsString;
          R.Status := TTaskStatus(Q.FieldByName('status').AsInteger);
          R.Synced := Q.FieldByName('synced').AsInteger <> 0;
          R.Seconds := Sec;
          Idx.Add(TaskId, L.Add(R));
        end;
      end;
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    Idx.Free;
    L.Free;
    Q.Free;
  end;
end;

end.
