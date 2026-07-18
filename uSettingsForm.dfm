object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 248
  ClientWidth = 424
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object lblUrl: TLabel
    Left = 16
    Top = 12
    Width = 40
    Height = 13
    Caption = 'Jira URL'
  end
  object lblToken: TLabel
    Left = 16
    Top = 60
    Width = 40
    Height = 13
    Caption = 'Token'
  end
  object edtUrl: TEdit
    Left = 16
    Top = 28
    Width = 393
    Height = 21
    TabOrder = 0
  end
  object edtToken: TEdit
    Left = 16
    Top = 76
    Width = 393
    Height = 21
    PasswordChar = '*'
    TabOrder = 1
  end
  object btnTest: TButton
    Left = 16
    Top = 108
    Width = 161
    Height = 25
    Caption = 'Test'
    TabOrder = 2
    OnClick = btnTestClick
  end
  object chkAutostart: TCheckBox
    Left = 16
    Top = 148
    Width = 393
    Height = 17
    Caption = 'Autostart'
    TabOrder = 3
  end
  object chkAutoPause: TCheckBox
    Left = 16
    Top = 172
    Width = 393
    Height = 17
    Caption = 'Autopause'
    TabOrder = 4
  end
  object btnOK: TButton
    Left = 240
    Top = 208
    Width = 81
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 5
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 328
    Top = 208
    Width = 81
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 6
  end
end
