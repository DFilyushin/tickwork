object frmReport: TfrmReport
  Left = 0
  Top = 0
  Caption = 'Report'
  ClientHeight = 520
  ClientWidth = 760
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
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblFrom: TLabel
      Left = 8
      Top = 12
      Width = 16
      Height = 13
      Caption = 'From'
    end
    object lblTo: TLabel
      Left = 152
      Top = 12
      Width = 16
      Height = 13
      Caption = 'To'
    end
    object dtpFrom: TDateTimePicker
      Left = 32
      Top = 8
      Width = 105
      Height = 21
      Date = 43466.000000000000000000
      Time = 43466.000000000000000000
      TabOrder = 0
    end
    object dtpTo: TDateTimePicker
      Left = 176
      Top = 8
      Width = 105
      Height = 21
      Date = 43466.000000000000000000
      Time = 43466.000000000000000000
      TabOrder = 1
    end
    object btnToday: TButton
      Left = 296
      Top = 7
      Width = 65
      Height = 25
      Caption = 'Today'
      TabOrder = 2
      OnClick = btnTodayClick
    end
    object btnWeek: TButton
      Left = 364
      Top = 7
      Width = 65
      Height = 25
      Caption = 'Week'
      TabOrder = 3
      OnClick = btnWeekClick
    end
    object btnMonth: TButton
      Left = 432
      Top = 7
      Width = 65
      Height = 25
      Caption = 'Month'
      TabOrder = 4
      OnClick = btnMonthClick
    end
    object btnRefresh: TButton
      Left = 512
      Top = 7
      Width = 105
      Height = 25
      Caption = 'Refresh'
      TabOrder = 5
      OnClick = btnRefreshClick
    end
    object btnHtml: TButton
      Left = 624
      Top = 7
      Width = 105
      Height = 25
      Caption = 'HTML'
      TabOrder = 6
      OnClick = btnHtmlClick
    end
  end
  object lvDetail: TListView
    Left = 0
    Top = 41
    Width = 760
    Height = 287
    Align = alClient
    Columns = <
      item
        Caption = 'Task'
        Width = 280
      end
      item
        Caption = 'Type'
        Width = 120
      end
      item
        Caption = 'Jira'
        Width = 90
      end
      item
        Caption = 'Time'
        Width = 80
      end
      item
        Caption = 'Status'
        Width = 90
      end
      item
        Caption = 'Synced'
        Width = 80
      end>
    ColumnClick = False
    GridLines = True
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 328
    Width = 760
    Height = 192
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblTotal: TLabel
      Left = 8
      Top = 168
      Width = 40
      Height = 13
      Caption = 'Total'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lvSummary: TListView
      Left = 0
      Top = 0
      Width = 760
      Height = 160
      Align = alTop
      Columns = <
        item
          Caption = 'Type'
          Width = 240
        end
        item
          Caption = 'Time'
          Width = 120
        end>
      ColumnClick = False
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
    end
  end
end
