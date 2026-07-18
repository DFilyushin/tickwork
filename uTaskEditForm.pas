unit uTaskEditForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, uTypes;

type
  TfrmTaskEdit = class(TForm)
    lblTitle: TLabel;
    edtTitle: TEdit;
    lblType: TLabel;
    cbType: TComboBox;
    lblJira: TLabel;
    edtJira: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  public
    class function Execute(var ATitle: string; var AType: TTaskType;
      var AJiraKey: string): Boolean;
  end;

implementation

{$R *.dfm}

procedure TfrmTaskEdit.FormCreate(Sender: TObject);
var
  T: TTaskType;
begin
  Caption := 'Редактирование задачи';
  lblTitle.Caption := 'Название:';
  lblType.Caption := 'Тип задачи:';
  lblJira.Caption := 'Задача Jira (необязательно):';
  btnOK.Caption := 'OK';
  btnCancel.Caption := 'Отмена';
  cbType.Items.Clear;
  for T := Low(TTaskType) to High(TTaskType) do
    cbType.Items.Add(TaskTypeName(T));
  cbType.ItemIndex := 0;
end;

procedure TfrmTaskEdit.btnOKClick(Sender: TObject);
var
  Jira: string;
begin
  if Trim(edtTitle.Text) = '' then
  begin
    MessageDlg('Укажите название задачи.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Jira := Trim(UpperCase(edtJira.Text));
  if (Jira <> '') and not IsValidJiraKey(Jira) then
  begin
    MessageDlg('Неверный номер задачи Jira. Ожидается формат PROJ-123.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

class function TfrmTaskEdit.Execute(var ATitle: string; var AType: TTaskType;
  var AJiraKey: string): Boolean;
var
  Frm: TfrmTaskEdit;
begin
  Frm := TfrmTaskEdit.Create(nil);
  try
    Frm.edtTitle.Text := ATitle;
    Frm.cbType.ItemIndex := Ord(AType);
    Frm.edtJira.Text := AJiraKey;
    Result := Frm.ShowModal = mrOk;
    if Result then
    begin
      ATitle := Trim(Frm.edtTitle.Text);
      AType := TTaskType(Frm.cbType.ItemIndex);
      AJiraKey := Trim(UpperCase(Frm.edtJira.Text));
    end;
  finally
    Frm.Free;
  end;
end;

end.
