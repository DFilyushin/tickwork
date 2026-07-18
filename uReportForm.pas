unit uReportForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls,
  uTypes, uDM;

type
  TfrmReport = class(TForm)
    pnlTop: TPanel;
    lblFrom: TLabel;
    dtpFrom: TDateTimePicker;
    lblTo: TLabel;
    dtpTo: TDateTimePicker;
    btnToday: TButton;
    btnWeek: TButton;
    btnMonth: TButton;
    btnRefresh: TButton;
    btnHtml: TButton;
    lvDetail: TListView;
    pnlBottom: TPanel;
    lvSummary: TListView;
    lblTotal: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnTodayClick(Sender: TObject);
    procedure btnWeekClick(Sender: TObject);
    procedure btnMonthClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnHtmlClick(Sender: TObject);
  private
    FRows: TArray<TReportRow>;
    FTypeTotals: array[TTaskType] of Int64;
    FGrandTotal: Int64;
    procedure BuildReport;
    function BuildHtml: string;
  public
    class procedure Execute;
  end;

implementation

uses
  System.DateUtils, System.IOUtils, Winapi.ShellAPI;

{$R *.dfm}

class procedure TfrmReport.Execute;
var
  Frm: TfrmReport;
begin
  Frm := TfrmReport.Create(nil);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TfrmReport.FormCreate(Sender: TObject);
begin
  Caption := 'Отчёт по отработанному времени';
  lblFrom.Caption := 'С:';
  lblTo.Caption := 'По:';
  btnToday.Caption := 'Сегодня';
  btnWeek.Caption := 'Неделя';
  btnMonth.Caption := 'Месяц';
  btnRefresh.Caption := 'Сформировать';
  btnHtml.Caption := 'Открыть HTML';
  lvDetail.Columns[0].Caption := 'Задача';
  lvDetail.Columns[1].Caption := 'Тип';
  lvDetail.Columns[2].Caption := 'Jira';
  lvDetail.Columns[3].Caption := 'Время';
  lvDetail.Columns[4].Caption := 'Статус';
  lvDetail.Columns[5].Caption := 'В Jira';
  lvSummary.Columns[0].Caption := 'Тип задачи';
  lvSummary.Columns[1].Caption := 'Время';
  dtpFrom.Date := StartOfTheWeek(Date);
  dtpTo.Date := Date;
  BuildReport;
end;

procedure TfrmReport.btnTodayClick(Sender: TObject);
begin
  dtpFrom.Date := Date;
  dtpTo.Date := Date;
  BuildReport;
end;

procedure TfrmReport.btnWeekClick(Sender: TObject);
begin
  dtpFrom.Date := StartOfTheWeek(Date);
  dtpTo.Date := Date;
  BuildReport;
end;

procedure TfrmReport.btnMonthClick(Sender: TObject);
begin
  dtpFrom.Date := StartOfTheMonth(Date);
  dtpTo.Date := Date;
  BuildReport;
end;

procedure TfrmReport.btnRefreshClick(Sender: TObject);
begin
  BuildReport;
end;

procedure TfrmReport.BuildReport;
var
  R: TReportRow;
  Item: TListItem;
  T: TTaskType;
  SyncMark: string;
begin
  FRows := DB.GetReportRows(DateOf(dtpFrom.Date), DateOf(dtpTo.Date) + 1);
  for T := Low(TTaskType) to High(TTaskType) do
    FTypeTotals[T] := 0;
  FGrandTotal := 0;

  lvDetail.Items.BeginUpdate;
  try
    lvDetail.Items.Clear;
    for R in FRows do
    begin
      Item := lvDetail.Items.Add;
      Item.Caption := R.Title;
      Item.SubItems.Add(TaskTypeName(R.TaskType));
      Item.SubItems.Add(R.JiraKey);
      Item.SubItems.Add(FormatDuration(R.Seconds));
      Item.SubItems.Add(TaskStatusName(R.Status));
      if R.JiraKey = '' then
        SyncMark := '—'
      else if R.Synced then
        SyncMark := 'передано'
      else
        SyncMark := 'нет';
      Item.SubItems.Add(SyncMark);
      Inc(FTypeTotals[R.TaskType], R.Seconds);
      Inc(FGrandTotal, R.Seconds);
    end;
  finally
    lvDetail.Items.EndUpdate;
  end;

  lvSummary.Items.BeginUpdate;
  try
    lvSummary.Items.Clear;
    for T := Low(TTaskType) to High(TTaskType) do
      if FTypeTotals[T] > 0 then
      begin
        Item := lvSummary.Items.Add;
        Item.Caption := TaskTypeName(T);
        Item.SubItems.Add(FormatDuration(FTypeTotals[T]));
      end;
  finally
    lvSummary.Items.EndUpdate;
  end;

  lblTotal.Caption := 'Итого за период: ' + FormatDuration(FGrandTotal);
end;

function TfrmReport.BuildHtml: string;

  function Esc(const S: string): string;
  begin
    Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;');
  end;

var
  SB: TStringBuilder;
  R: TReportRow;
  T: TTaskType;
  SyncMark: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html><html><head><meta charset="utf-8">');
    SB.AppendLine('<title>Отчёт по времени</title><style>');
    SB.AppendLine('body{font-family:Segoe UI,Tahoma,sans-serif;margin:24px;}');
    SB.AppendLine('table{border-collapse:collapse;margin-bottom:24px;}');
    SB.AppendLine('th,td{border:1px solid #999;padding:4px 10px;text-align:left;}');
    SB.AppendLine('th{background:#eee;} .num{text-align:right;}');
    SB.AppendLine('</style></head><body>');
    SB.AppendFormat('<h2>Отчёт по отработанному времени: %s — %s</h2>',
      [FormatDateTime('dd.mm.yyyy', dtpFrom.Date),
       FormatDateTime('dd.mm.yyyy', dtpTo.Date)]);
    SB.AppendLine('');
    SB.AppendLine('<h3>Детализация по задачам</h3>');
    SB.AppendLine('<table><tr><th>Задача</th><th>Тип</th><th>Jira</th>' +
      '<th>Время</th><th>Статус</th><th>В Jira</th></tr>');
    for R in FRows do
    begin
      if R.JiraKey = '' then
        SyncMark := '&mdash;'
      else if R.Synced then
        SyncMark := 'передано'
      else
        SyncMark := 'нет';
      SB.AppendFormat('<tr><td>%s</td><td>%s</td><td>%s</td>' +
        '<td class="num">%s</td><td>%s</td><td>%s</td></tr>' + sLineBreak,
        [Esc(R.Title), TaskTypeName(R.TaskType), Esc(R.JiraKey),
         FormatDuration(R.Seconds), TaskStatusName(R.Status), SyncMark]);
    end;
    SB.AppendLine('</table>');
    SB.AppendLine('<h3>Итоги по типам задач</h3>');
    SB.AppendLine('<table><tr><th>Тип задачи</th><th>Время</th></tr>');
    for T := Low(TTaskType) to High(TTaskType) do
      if FTypeTotals[T] > 0 then
        SB.AppendFormat('<tr><td>%s</td><td class="num">%s</td></tr>' + sLineBreak,
          [TaskTypeName(T), FormatDuration(FTypeTotals[T])]);
    SB.AppendFormat('<tr><th>Итого</th><th class="num">%s</th></tr>',
      [FormatDuration(FGrandTotal)]);
    SB.AppendLine('</table></body></html>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TfrmReport.btnHtmlClick(Sender: TObject);
var
  FileName: string;
begin
  BuildReport;
  FileName := TPath.Combine(TPath.GetTempPath, 'Tickwork_report.html');
  TFile.WriteAllText(FileName, BuildHtml, TEncoding.UTF8);
  ShellExecute(0, 'open', PChar(FileName), nil, nil, SW_SHOWNORMAL);
end;

end.
