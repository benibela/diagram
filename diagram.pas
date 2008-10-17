unit diagram;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,math,FPimage,IntfGraphics,LCLType;

type
  TDiagram=class;
  TAxis=class;
  TValueTranslateEvent=procedure (sender: TAxis; i: float; var translated: string) of object;
  TLegend=record
    visible: boolean;
    width,height: longint;
    color:TCOlor;
    auto: boolean;
  end;

  { TAxis }

  TAxis=class
  protected
    function doTranslate(const i:float): string;
  public
    title: string;
    min,max,resolution: float;
    auto: boolean;
    valueTranslate: TValueTranslateEvent;
    showLine: boolean;
    lineColor: TColor;
    
    function translate(const i:float): string;inline;
    procedure autoResolution(imageSize: longint);
  end;
  TDataPoint=record
    x,y:float;
  end;

  { TDataList }

  TDataList=class
  protected
    owner: TDiagram;
    points: array of TDataPoint;
    pointCount: longint;
  public
    color: TColor;
    title:string;
    //function getPoint(x:longint): longint;
    procedure clear;
    function count:longint;
    procedure addPoint(x,y:float); overload;
    procedure addPoint(y:float); overload;
  end;
  TDiagramKind=(dkLines);

  { TDiagram }

  TDiagram=class
  protected
    FKind: TDiagramKind;
  public
    updateAxisEveryBitmapUpdate:boolean;
    
    valueAreaX,valueAreaY,valueAreaWidth,valueAreaHeight,valueAreaRight,valueAreaBottom: longint;
    DataLists: TFPList;
    XAxis,YAxis: TAxis;
    Diagram: TBitmap;


    backColor: TColor;
    dataBackColor: TColor;

    legend:TLegend;

    filled: boolean;

    constructor create;
    destructor destroy;override;

    procedure clear;
    function addDataList: TDataList;

    procedure updateAxis(xaxisMove: longint=0);
    function update(xaxisMove: longint=0): TBitmap;

    function posXToDataX(x:longint):float;

    //procedure XAxisReduce();

    property kind: TDiagramKind read FKind write FKind;
  end;

implementation

function TAxis.doTranslate(const i:float): string;
begin
  if frac(i)<1e-16 then result:=inttostr(round(i))
  else if resolution>1 then result:=inttostr(round(i))
  else result:=format('%.2g',[i]);
  if assigned(valueTranslate) then
    valueTranslate(self,i,result);
end;

function TAxis.translate(const i: float): string;inline;
begin
  result:=doTranslate(i);
end;

procedure TAxis.autoResolution(imageSize: longint);
begin
    {if max-min<imageSize then begin
      case imageSize div (max-min) of
        0..9: resolution:=10;
        else resolution:=1;
      end;
    end else begin
      case (max-min) div imageSize of
        0..9: resolution:=1;
        10..99: resolution:=10;
        100..999: resolution:=100;
        1000..9999: resolution:=1000;
      end;
    end;}
    //Count of intervals: (max-min) / resolution
    //Size   "     "    : imageSize / Count
    if abs(max-min)<1e-16 then resolution:=1
    else if imageSize / (max-min)>20 then resolution:=1
    else if imageSize / (max-min)>0 then resolution:=(max-min)*30 / imageSize
    else resolution:=(max-min)*30 / imageSize;

end;

procedure TDataList.clear;
begin
  setlength(points,0);
  pointCount:=0;
end;

function TDataList.count: longint;
begin
  result:=pointCount;
end;

procedure TDataList.addPoint(x,y:float);
var i:integer;
begin
  if pointCount=0 then begin
    setlength(points,1);
    pointCount:=1;
    points[0].x:=x;
    points[0].y:=y;
    exit;
  end;
  if (points[pointCount-1].x>=x) then begin
    i:=0;
    while i<pointCount do begin
      if points[i].x=x then begin
        points[i].y:=y;
        exit;
      end else if points[i].x>x then break;
      inc(i);
    end;
    setLength(points,length(points)+1);
    Move(points[i],points[i+1],sizeof(points[0])*(pointCount-i));
    inc(pointCount);
  end else begin
    setLength(points,length(points)+1);
    inc(pointCount);
    i:=pointCount-1;
  end;
  points[i].x:=x;
  points[i].y:=y;
end;
procedure TDataList.addPoint(y:float);
begin
  if pointCount=0 then addPoint(0,y)
  else addPoint(points[pointCount-1].x+1,y);
end;


constructor TDiagram.create;
begin
  XAxis:=TAxis.Create;
  YAxis:=TAxis.Create;
  XAxis.auto:=true;
  YAxis.auto:=true;
  XAxis.showLine:=false;
  YAxis.showLine:=true;
  XAxis.lineColor:=clGray;
  YAxis.lineColor:=clGray;
  Diagram:=TBitmap.Create;
  Diagram.width:=300;
  Diagram.height:=300;
  backColor:=clBtnFace;
  dataBackColor:=clSilver;
  DataLists:=TFPList.Create;
  legend.auto:=true;
  legend.visible:=true;
  legend.color:=clBtnFace;
  updateAxisEveryBitmapUpdate:=true;
end;

destructor TDiagram.destroy;
begin
  XAxis.free;
  YAxis.free;
  Diagram.free;
  clear;
  DataLists.free;
  inherited;
end;

procedure TDiagram.clear;
var i:integer;
begin
  for i:=0 to DataLists.Count-1 do
    TDataList(DataLists[i]).free;
  DataLists.Count:=0;
end;

function TDiagram.addDataList: TDataList;
const colors:array[0..7] of TColor=(clBlue,clRed,clGreen,clMaroon,clFuchsia,clTeal,clNavy,clBlack);
begin
  Result:=TDataList.Create;
  Result.owner:=Self;
  result.color:=colors[DataLists.Count and $7];
  DataLists.Add(Result);
end;

procedure TDiagram.updateAxis(xaxisMove: longint);

var i,j,pos,textHeightC,legendX:longint;
    p:float;
    xaxisOldMin: float;
    list:TDataList;
    temp,caption,captionOld:string;
begin
  if XAxis.auto then begin
    XAxis.min:=1e1000;
    XAxis.max:=-1e1000;
    XAxis.resolution:=1;
  end;
  if YAxis.auto then begin
    YAxis.min:=1e1000;
    YAxis.max:=-1e1000;
    YAxis.resolution:=1;
  end;
  for i:=0 to DataLists.count-1 do begin
    list:=TDataList(DataLists[i]);
    if list.pointCount=0 then continue;
    if XAxis.auto and (list.points[0].x<XAxis.min) then XAxis.min:=list.points[0].x;
    if XAxis.auto and (list.points[list.pointCount-1].x>XAxis.max) then XAxis.max:=list.points[list.pointCount-1].x;
    if YAxis.auto then
      for j:=0 to list.pointcount-1 do begin
        if (list.points[j].y<YAxis.min) then YAxis.min:=list.points[j].y;
        if (list.points[j].y>YAxis.max) then YAxis.max:=list.points[j].y;
      end;
  end;
 { if xaxis.min=1 then xaxis.min:=0;
  if yaxis.min=1 then yaxis.min:=0;}
  if xaxis.max<=xaxis.min then xaxis.max:=xaxis.min+5;
  if yaxis.max<=yaxis.min then yaxis.max:=yaxis.min+5;
  textHeightC:=Diagram.Canvas.TextHeight(',gqpHTMIT');
  if legend.auto then begin
    legend.width:=0;
    for i:=0 to DataLists.count-1 do begin
      j:=Diagram.Canvas.TextWidth(TDataList(DataLists[i]).title);
      if j>legend.width then legend.width:=j;
    end;
    legend.width:=legend.width+20;
    legend.height:=(textHeightC+5)*DataLists.count+10;
  end;
  valueAreaX:=20;
  valueAreaY:=5;
  valueAreaWidth:=Diagram.Width-valueAreaX;
  if legend.visible then dec(valueAreaWidth,6+legend.width);
  valueAreaHeight:=Diagram.Height-25;
  valueAreaRight:=valueAreaX+valueAreaWidth;
  valueAreaBottom:=valueAreaY+valueAreaHeight;
  xaxisOldMin:=xaxis.min;
  xaxis.min:=xaxis.min+xaxisMove;
  if XAxis.auto then XAxis.autoResolution(valueAreaWidth);
  if YAxis.auto then YAxis.autoResolution(valueAreaHeight);

end;

function TDiagram.update(xaxisMove: longint=0): TBitmap;

var i,j,pos,textHeightC,legendX:longint;
    p:float;
    xaxisOldMin: float;
    list:TDataList;
    temp,caption,captionOld:string;
    currentColor,fpbackcolor,fplinecolor:tfpcolor;
    tempLazImage:TLazIntfImage;
    bitmap,maskbitmap: HBITMAP;
begin

  textHeightC:=Diagram.Canvas.TextHeight(',gqpHTMIT');
  if updateAxisEveryBitmapUpdate then updateAxis(xaxisMove);
  with Diagram.Canvas do begin
    brush.style:=bsSolid;
    brush.color:=backColor;
    FillRect(0,0,Diagram.Width,Diagram.Height);
    brush.color:=dataBackColor;//eaX+valueAreaWidth,valueAreaY+valueAreaHeight);
    brush.style:=bsSolid;
    brush.color:=dataBackColor;
    FillRect(valueAreaX,valueAreaY,valueAreaX+valueAreaWidth,valueAreaY+valueAreaHeight);
    brush.style:=bsClear;
    //Draw axis
    pen.style:=psSolid;
    pen.color:=clBlack;
    MoveTo(valueAreaX-1,valueAreaY);
    LineTo(valueAreaX-1,valueAreaBottom+1);
    LineTo(valueAreaX+valueAreaWidth,valueAreaBottom+1);
    captionOld:='';
    p:=XAxis.min;
    while p<=XAxis.max do begin
      caption:=XAxis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=round((p-XAxis.min)*valueAreaWidth / (XAxis.max-XAxis.min)+valueAreaX);
        if XAxis.showLine then begin
          pen.color:=XAxis.lineColor;
          MoveTo(pos,valueAreaY);
          LineTo(pos,valueAreaBottom);
          pen.color:=clBlack;
        end;
        MoveTo((pos),valueAreaBottom-2);
        LineTo((pos),valueAreaBottom+3);
        TextOut((pos)-textwidth(caption) div 2,valueAreaBottom+4,caption);
      end;
      p:=p+XAxis.resolution;
    end;
    pen.color:=clBlack;
    p:=YAxis.min;
    while p<=YAxis.max do begin
      caption:=YAxis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=round(valueAreaBottom-(p-YAxis.min)*valueAreaHeight / (YAxis.max-YAxis.min));
        if YAxis.showLine then begin
          pen.color:=YAxis.lineColor;
          MoveTo(valueAreaX,pos);
          LineTo(valueAreaRight,pos);
          pen.color:=clBlack;
        end;
        MoveTo(valueAreaX-3,pos);
        LineTo(valueAreaX+2,pos);
      end;
      TextOut(valueAreaX-3-TextWidth(caption),pos-textHeightC div 2, caption);
      p:=p+YAxis.resolution;
    end;

    //Draw Values
    for i:=0 to DataLists.Count-1 do begin
      list:=TDataList(DataLists[i]);
      if list.pointCount=0 then continue;
      Pen.Color:=list.Color;
      MoveTo(round((list.points[0].x-XAxis.min)*valueAreaWidth / (XAxis.max-XAxis.min)+valueAreaX),
             round(valueAreaBottom-(list.points[0].y-YAxis.min)*valueAreaHeight / (YAxis.max-YAxis.min)));
      for j:=0 to list.pointCount-1 do
        LineTo(round((list.points[j].x-XAxis.min)*valueAreaWidth / (XAxis.max-XAxis.min)+valueAreaX),
               round(valueAreaBottom-(list.points[j].y-YAxis.min)*valueAreaHeight / (YAxis.max-YAxis.min)));
    end;
    
    //fill values
    //TODO: problem, this overrides y-lines, this could run in dataLines*dataPoints*log dataPoints
    if filled then begin
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(Diagram.Handle,0);
      fpbackcolor:=TColorToFPColor(dataBackColor);
      fplinecolor:=TColorToFPColor(XAxis.lineColor);
      for i:=valueAreaX+3 to valueAreaRight do begin //start after horz-axis-segments
        currentColor:=fpbackcolor;
        for j:=valueAreaY to valueAreaBottom do
          if (tempLazImage.Colors[i,j]<>fplinecolor) then begin
            if tempLazImage.colors[i,j]=fpbackcolor then
              tempLazImage.Colors[i,j]:=currentColor
            else
              currentColor:=tempLazImage.Colors[i,j];
          end;
      end;

      tempLazImage.CreateBitmaps(bitmap,maskbitmap,true);
      Diagram.Handle:=bitmap;
      tempLazImage.Free;
    end;

    //draw legend
    if legend.visible then begin
      brush.style:=bsSolid;
      brush.Color:=legend.color;
      pen.color:=clBlack;
      legendX:=valueAreaX+valueAreaWidth+5;
      Rectangle(legendX,(Diagram.Height -legend.height) div 2,
                legendX+legend.width,(Diagram.Height + legend.height) div 2);
      pos:=(Diagram.Height -legend.height) div 2+5;
      for i:=0 to DataLists.Count-1 do begin
        list:=TDataList(DataLists[i]);
        brush.style:=bsSolid;
        brush.color:=list.color;
        Rectangle(legendX+5,pos,legendX+10,pos+TextHeightC);
        brush.style:=bsClear;
        TextOut(legendX+15,pos,list.title);
        inc(pos,TextHeightC+5);
      end;
    end;
  end;
  
  //xaxis.min:=xaxisOldMin;
  Result:=Diagram;
end;

function TDiagram.posXToDataX(x: longint): float;
begin
  //umgekehrt:  (i-XAxis.min)*valueAreaWidth div (XAxis.max-XAxis.min)+valueAreaX
  if valueAreaWidth=0 then exit(0);
   result:=round((x-valueAreaX)*(XAxis.max-XAxis.min) / valueAreaWidth + XAxis.min);
end;


{procedure TDiagram.XAxisReduce();
begin

end;}

end.

