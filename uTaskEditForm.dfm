object frmTaskEdit: TfrmTaskEdit
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Task'
  ClientHeight = 208
  ClientWidth = 384
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lblTitle: TLabel
    Left = 16
    Top = 12
    Width = 32
    Height = 13
    Caption = 'Title'
  end
  object lblType: TLabel
    Left = 16
    Top = 60
    Width = 32
    Height = 13
    Caption = 'Type'
  end
  object lblJira: TLabel
    Left = 16
    Top = 108
    Width = 32
    Height = 13
    Caption = 'Jira'
  end
  object edtTitle: TEdit
    Left = 16
    Top = 28
    Width = 353
    Height = 21
    TabOrder = 0
  end
  object cbType: TComboBox
    Left = 16
    Top = 76
    Width = 201
    Height = 21
    Style = csDropDownList
    TabOrder = 1
  end
  object edtJira: TEdit
    Left = 16
    Top = 124
    Width = 153
    Height = 21
    CharCase = ecUpperCase
    TabOrder = 2
  end
  object btnOK: TButton
    Left = 200
    Top = 168
    Width = 81
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 3
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 288
    Top = 168
    Width = 81
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
end
