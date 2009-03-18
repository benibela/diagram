unit diagram;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,math,FPimage,IntfGraphics,LCLType;

type
  TAxis=class;
  TValueTranslateEvent=procedure (sender: TAxis; i: float; var translated: string) of object;
  TLegend=record
    visible: boolean;
    width,height: longint;
    color:TCOlor;
    auto: boolean;
  end;

  { TAxis }

  TRangePolicy = (rpModelControlled, rpApplicationControlled);
  TAxis=class
  protected
    function doTranslate(const i:float): string;
  public
    title: string;
    min,max,resolution: float;
    rangePolicy: TRangePolicy;
    valueTranslate: TValueTranslateEvent;
    showLine: boolean;
    lineColor: TColor;
    
    function translate(const i:float): string;inline;
    procedure autoResolution(imageSize: longint);
  end;
  TDataPoint=record
    x,y:float;
  end;

  TDiagramKind=(dkLines);

  { TAbstractDiagramModel }

  {** This is the abstract class you have to implement for custom data
  }
  TAbstractDiagramModel = class
  private
    fmodified: boolean;
    fmodifiedEvent: TNotifyEvent;
  protected
    procedure modified; //**<Call when ever the model data has been changed
  public
    //**This setups the axis for a given size (it uses a reasonable default)
    procedure setupAxis(xAxis, yAxis: TAxis; areaWidth, areaHeight: longint);virtual;

    //**This returns the number of data rows (override if you use more than 1)
    function dataCount: longint; virtual;
    //**This returns the title of every data row for the legend
    function dataTitle(i:longint):string; virtual;
    //**This setups the canvas (override it to set the color, set pen and brush to the same)
    procedure setupCanvasForData(i:longint; c: TCanvas); virtual;
    //**This returns the actual data (you must override it)
    function data(i:longint; const x:float):float; virtual;abstract;

    //**returns the minimum x (default 0, you should override it)
    function minX(i:longint):float; virtual;
    //**returns the maximum x (default 100, you should override it)
    function maxX(i:longint):float; virtual;
    //**returns the minimum value (default scans all values)
    function minY(i:longint):float; virtual;
    //**returns the maximum value (default scans all values)
    function maxY(i:longint):float; virtual;
    //**returns the next x where data exists, or maxX+1 if this is the last point
    //**The default implementation returns x+1, override it if you have non integer x-position
    //**You can return x for contiguous draw (only x, not e.g. x+0.5-0.5, the binary representation mustn't change)
    function nextX(i:longint; const x:float):float; virtual;

    function minX:float;
    function maxX:float;
    function minY:float;
    function maxY:float;
  end;

  //**This class draws the data model into a TBitmap

  { TDiagramDrawer }

  TDiagramDrawer = class
  private
    FKind: TDiagramKind;
    FModel: TAbstractDiagramModel;
    FModelOwnership: boolean;
    fvalueAreaX,FValueAreaY,FValueAreaWidth,FValueAreaHeight,FValueAreaRight,FValueAreaBottom: longint;
    FDiagram: TBitmap;
    FXAxis,FYAxis: TAxis;
    procedure SetModel(const AValue: TAbstractDiagramModel);
  public
    backColor: TColor;
    dataBackColor: TColor;
    legend:TLegend;

    filled: boolean;

    constructor create;
    function update(): TBitmap;
    destructor destroy;override;

    //**Sets the model to be drawn, if takeOwnership is true, then the model is freed automatically by the drawer, otherwise you have to free it yourself
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);

    function posToDataX(x: longint): float;

    property Diagram: TBitmap read FDiagram;
    property XAxis: TAxis read FXAxis;
    property YAxis: TAxis read FYAxis;
    property Kind: TDiagramKind read FKind write FKind;
    property Model: TAbstractDiagramModel read FModel write SetModel;
  end;


  { TDiagramView }

  TDiagramView = class (TCustomControl)
  private
    FDrawer: TDiagramDrawer;
    FModel: TAbstractDiagramModel;
    procedure modelChanged(sender:Tobject);
    procedure DoOnResize;override;
    procedure SetModel(const AValue: TAbstractDiagramModel);
  public
    constructor create(aowner:TComponent);override;
    destructor destroy;override;
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);
    procedure paint;override;
    property Drawer: TDiagramDrawer read FDrawer;
    property Model: TAbstractDiagramModel read FModel write SetModel;
  end;
//https://ssl.planet-hosting.de/cis.php?sub=domains&act=Edit&Domain=kindesunwohl-brd.de&Ziel=/-kindesunwohl-brd&sid=99d5d798b6d3e2be1ce6b30758a538d3
  { TDataList }

  TDataList=class
  protected
    maxX,minX,maxY,minY:float;
    owner: TAbstractDiagramModel;
    points: array of TDataPoint;
    pointCount: longint;
    lastRead: longint; //**<last point returned by nextX (needed for O(1) index lookup)
  public
    constructor create(aowner:TAbstractDiagramModel; acolor: TColor);
    color: TColor;
    title:string;
    //function getPoint(x:longint): longint;
    procedure clear(keepMemory: boolean=false); //**<removes all points, if keepMemory is true, the memory of the points is not freed
    function count:longint;
    //**adds a point at position (x,y) in the sorted list, removing duplicates on same x. (possible moving all existing points => O(1) if called in right order, O(n) if the inserted point belongs to the beginnning).
    //**It does use an intelligent growth strategy (size *2 if < 512, size+=512 otherwise, starting at 8)
    procedure addPoint(x,y:float); overload;
    //**adds a point at position (x+1,y) in the sorted list. (possible moving all existing points).
    //**It does use an intelligent growth strategy
    procedure addPoint(y:float); overload;

    function data(const x: float):float; //**<returns the data at position x (O(1) if called in left-to-right order, O(n) if called in right-to-left order)
    function nextX(const x: float):float; //**<returns the position of the next data point (O(1) if called in left-to-right order , O(n) if called in right-to-left order)
  end;

  { TDiagramDataListModel }

  TDiagramDataListModel = class (TAbstractDiagramModel)
  private
    FLists: TFPList;
    function getDataList(i:Integer): TDataList;
  public
    constructor create;
    destructor destroy;override;

    //**delete all lists
    procedure deleteLists;virtual;

    //**Set the count of data lists
    procedure setDataCount(c:longint);
    function addDataList:TDataList;
    //**This returns the number of data lists
    function dataCount: longint; override;
    //**This returns the title of every data list for the legend
    function dataTitle(i:longint):string; override;
    //**This set the color to the data list color
    procedure setupCanvasForData(i:longint; c: TCanvas); override;
    //**This returns the actual data (amortized O(1) if called in correct order)
    function data(i:longint; const x:float):float; override;
    //**returns the next x where data exists (amortized O(1) if called in correct order)
    function nextX(i:longint; const x:float):float; override;

    //**returns the minimum x
    function minX(i:longint):float; override;overload;
    //**returns the maximum x
    function maxX(i:longint):float; override;overload;
    //**returns the minimum value (O(1))
    function minY(i:longint):float; override;overload;
    //**returns the maximum value (O(1))
    function maxY(i:longint):float; override;overload;

    property lists[i:Integer]: TDataList read getDataList; default;
  end;
implementation
const PInfinity=Infinity;
      MInfinity=NegInfinity;
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
    if IsInfinite(min) or IsInfinite(max) or IsNan(min) or IsNan(max) then begin
      resolution:=NaN;
      exit;
    end;
    if abs(max-min)<1e-16 then resolution:=1
    else if imageSize / (max-min)>20 then resolution:=1
    else if imageSize / (max-min)>0 then resolution:=(max-min)*30 / imageSize
    else resolution:=(max-min)*30 / imageSize;

end;

function TDataList.data(const x: float): float;
var i:longint;
begin
  if pointCount=0 then result:=maxX+1;
  if (lastRead>=0) and (lastRead<pointCount) then
    if points[lastRead].x = x then exit(points[lastRead].y);
  for i:=0 to high(points) do
    if points[i].x=x then begin
      lastRead:=i;
      exit(points[i].y);
    end;
  exit(NaN);
end;

function TDataList.nextX(const x: float): float;
var i:longint;
begin
  if pointCount=0 then result:=maxX+1;
  if (lastRead>=0) and (lastRead<pointCount) then
    if points[LastRead].x = x then begin
      lastRead+=1;
      if lastRead<pointCount then exit(points[lastRead].x)
      else exit(maxX+1);
    end;
  for i:=0 to high(points)-1 do
    if points[i].x=x then begin
      lastRead:=i+1;
      exit(points[i+1].x);
    end;
  exit(maxX+1);
end;

constructor TDataList.create(aowner: TAbstractDiagramModel; acolor: TColor);
begin
  owner:=aowner;
  color:=acolor;
  maxX:=MInfinity;
  minX:=PInfinity;
  maxY:=MInfinity;
  minY:=PInfinity;
  title:='data row';
end;

procedure TDataList.clear(keepMemory: boolean=false);
begin
  if not keepMemory then setlength(points,0);
  pointCount:=0;
  maxX:=MInfinity;
  minX:=PInfinity;
  maxY:=MInfinity;
  minY:=PInfinity;
  if assigned(owner) then owner.modified;
end;

function TDataList.count: longint;
begin
  result:=pointCount;
end;

procedure TDataList.addPoint(x,y:float);
var i:integer;
begin
  if x<minX then minX:=x;
  if x>maxX then maxX:=x;
  if y<minY then minY:=y;
  if y>maxY then maxY:=y;
  if pointCount=0 then begin
    setlength(points,8);
    pointCount:=1;
    points[0].x:=x;
    points[0].y:=y;
    if assigned(owner) then owner.modified;
    exit;
  end;
  if pointCount=length(points) then begin //resize
    if pointCount<512 then setlength(points,length(points)*2)
    else setlength(points,length(points)+512);
  end;
  if (points[pointCount-1].x>=x) then begin
    i:=0;
    while i<pointCount do begin
      if points[i].x=x then begin
        if points[i].y<>y then begin
          points[i].y:=y;    //this could break the minY/maxY
          if assigned(owner) then owner.modified;
        end;
        exit;
      end else if points[i].x>x then break;
      inc(i);
    end;
    Move(points[i],points[i+1],sizeof(points[0])*(pointCount-i));
    inc(pointCount);
  end else begin
    i:=pointCount;
    inc(pointCount);
  end;
  points[i].x:=x;
  points[i].y:=y;
  if assigned(owner) then owner.modified;
end;
procedure TDataList.addPoint(y:float);
begin
  if pointCount=0 then addPoint(0,y)
  else addPoint(points[pointCount-1].x+1,y);
end;

//==================================================================================

procedure TDiagramDrawer.SetModel(const AValue: TAbstractDiagramModel);
begin
  SetModel(AValue,false);
end;

constructor TDiagramDrawer.create;
begin
  FXAxis:=TAxis.Create;
  FYAxis:=TAxis.Create;
  FXAxis.rangePolicy:=rpModelControlled;
  FYAxis.rangePolicy:=rpModelControlled;
  FXAxis.showLine:=false;
  FYAxis.showLine:=true;
  FXAxis.lineColor:=clGray;
  FYAxis.lineColor:=clGray;
  FDiagram:=TBitmap.Create;
  FDiagram.width:=300;
  FDiagram.height:=300;
  backColor:=clBtnFace;
  dataBackColor:=clSilver;
  legend.auto:=true;
  legend.visible:=true;
  legend.color:=clBtnFace;
end;

destructor TDiagramDrawer.destroy;
begin
  FXAxis.free;
  FYAxis.free;
  FDiagram.free;
  SetModel(nil);
  inherited;
end;


procedure TDiagramDrawer.SetModel(amodel: TAbstractDiagramModel;
  takeOwnership: boolean);
begin
  if assigned(FModel) and FModelOwnership then FreeAndNil(FModel);
  FModel:=amodel;
  FModelOwnership:=takeOwnership;
end;





function TDiagramDrawer.update(): TBitmap;

var i,j,pos,textHeightC,legendX:longint;
    p:float;
    maxx,x,nextX: float;
    xstart,ystart,xfactor,xfactorinv, yfactor,xend,yend: float; //copied from axis
    drawx:longint;
    caption,captionOld:string;
    currentColor,fpbackcolor,fplinecolor:tfpcolor;
    tempLazImage:TLazIntfImage;
    bitmap,maskbitmap: HBITMAP;
begin
  result:=Diagram;
  if not assigned(FMOdel) then exit;

  textHeightC:=result.Canvas.TextHeight(',gqpHTMIT');
  //setup legend
  if legend.auto then begin
    legend.width:=0;
    for i:=0 to FModel.dataCount-1 do begin
      j:=result.Canvas.TextWidth(FModel.dataTitle(i));
      if j>legend.width then legend.width:=j;
    end;
    legend.width:=legend.width+20;
    legend.height:=(textHeightC+5)*FModel.dataCount()+10;
  end;
  //setup output area
  FValueAreaX:=20;
  FValueAreaY:=5;
  FValueAreaWidth:=result.Width-FValueAreaX;
  if legend.visible then dec(FValueAreaWidth,6+legend.width);
  FValueAreaHeight:=result.Height-25;
  FValueAreaRight:=FValueAreaX+FValueAreaWidth;
  FValueAreaBottom:=FValueAreaY+FValueAreaHeight;
  //setup axis
  FModel.setupAxis(XAxis,YAxis, FValueAreaWidth, FValueAreaHeight);

  with result.Canvas do begin
    brush.style:=bsSolid;
    brush.color:=backColor;
    FillRect(0,0,result.Width,result.Height);
    brush.color:=dataBackColor;//eaX+FValueAreaWidth,FValueAreaY+FValueAreaHeight);
    brush.style:=bsSolid;
    brush.color:=dataBackColor;
    FillRect(FValueAreaX,FValueAreaY,FValueAreaX+FValueAreaWidth,FValueAreaY+FValueAreaHeight);
    brush.style:=bsClear;
    //Draw axis
    pen.style:=psSolid;
    pen.color:=clBlack;
    MoveTo(FValueAreaX-1,FValueAreaY);
    LineTo(FValueAreaX-1,FValueAreaBottom+1);
    LineTo(FValueAreaX+FValueAreaWidth,FValueAreaBottom+1);
    captionOld:='';
    if IsNan(XAxis.min) or IsInfinite(XAxis.min) or IsNan(XAxis.max) or IsInfinite(XAxis.max) then begin
      //can't use axis, fall back to default
      xstart:=0;
      xend:=100;
    end else begin
      xstart:=XAxis.min;
      xend:=XAxis.max;
    end;
    xfactor:=FValueAreaWidth / (xend-xstart);
    p:=xstart;
    while p<=xend do begin
      caption:=XAxis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=FValueAreaX+round((p-xstart)*xfactor);
        if XAxis.showLine then begin
          pen.color:=XAxis.lineColor;
          MoveTo(pos,FValueAreaY);
          LineTo(pos,FValueAreaBottom);
          pen.color:=clBlack;
        end;
        MoveTo((pos),FValueAreaBottom-2);
        LineTo((pos),FValueAreaBottom+3);
        TextOut((pos)-textwidth(caption) div 2,FValueAreaBottom+4,caption);
      end;
      if IsNan(XAxis.resolution) or IsInfinite(XAxis.resolution) then p+=round((xend-xstart) / 10)
      else p+=XAxis.resolution;
    end;


    if IsNan(YAxis.min) or IsInfinite(YAxis.min) or IsNan(YAxis.max) or IsInfinite(YAxis.max) then begin
      //can't use axis, fall back to default
      ystart:=0;
      yend:=100;
    end else begin
      ystart:=YAxis.min;
      yend:=YAxis.max;
    end;
    yfactor:=FValueAreaHeight / (yend-ystart);
    p:=ystart;
    pen.color:=clBlack;
    while p<=yend do begin
      caption:=YAxis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=FValueAreaBottom-round((p-ystart)*yfactor);
        if YAxis.showLine then begin
          pen.color:=YAxis.lineColor;
          MoveTo(FValueAreaX,pos);
          LineTo(FValueAreaRight,pos);
          pen.color:=clBlack;
        end;
        MoveTo(FValueAreaX-3,pos);
        LineTo(FValueAreaX+2,pos);
      end;
      TextOut(FValueAreaX-3-TextWidth(caption),pos-textHeightC div 2, caption);
      if IsNan(YAxis.resolution) or IsInfinite(YAxis.resolution) then p+=round((yend-ystart) / 10)
      else p+=YAxis.resolution;
    end;

    //Draw Values
    if xfactor<>0 then xfactorinv:=1/xfactor
    else xfactorinv:=1;
    for i:=0 to FModel.dataCount-1 do begin
      x:=FModel.minX(i);
      maxx:=FModel.maxX(i);
      if (maxx<x) or IsNan(x) or IsInfinite(x) or IsNan(maxx) or IsInfinite(maxx) then continue;
      FModel.setupCanvasForData(i,result.canvas);
      MoveTo(FValueAreaX+round((x-xstart)*xfactor),
             FValueAreaBottom-round((FModel.data(i,x)-ystart)*yfactor));
      x:=FModel.nextX(i,x);
      while x<=maxx do begin
        drawx:=FValueAreaX+round((x-xstart)*xfactor);
        LineTo( drawx,
                FValueAreaBottom-round((FModel.data(i,x)-ystart)*yfactor));
        nextX:=FModel.nextX(i,x);
        if x=nextX then //one pixel further
          x:=(drawx+1) *xfactorinv + xstart
         else
          x:=nextx;
      end;
    end;

    //fill values
    //TODO: problem, this overrides y-lines, this could run in dataLines*dataPoints*log dataPoints
    if filled then begin
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(result.Handle,0);
      fpbackcolor:=TColorToFPColor(dataBackColor);
      fplinecolor:=TColorToFPColor(XAxis.lineColor);
      for i:=FValueAreaX+3 to FValueAreaRight do begin //start after horz-axis-segments
        currentColor:=fpbackcolor;
        for j:=FValueAreaY to FValueAreaBottom do
          if (tempLazImage.Colors[i,j]<>fplinecolor) then begin
            if tempLazImage.colors[i,j]=fpbackcolor then
              tempLazImage.Colors[i,j]:=currentColor
            else
              currentColor:=tempLazImage.Colors[i,j];
          end;
      end;

      tempLazImage.CreateBitmaps(bitmap,maskbitmap,true);
      result.Handle:=bitmap;
      tempLazImage.Free;
    end;

    //draw legend
    if legend.visible then begin
      brush.style:=bsSolid;
      brush.Color:=legend.color;
      pen.color:=clBlack;
      legendX:=FValueAreaX+FValueAreaWidth+5;
      Rectangle(legendX,(result.Height -legend.height) div 2,
                legendX+legend.width,(result.Height + legend.height) div 2);
      pos:=(result.Height -legend.height) div 2+5;
      for i:=0 to FModel.dataCount-1 do begin
        brush.style:=bsSolid;
        fmodel.setupCanvasForData(i,Result.Canvas);
        Rectangle(legendX+5,pos,legendX+10,pos+TextHeightC);
        brush.style:=bsClear;
        TextOut(legendX+15,pos,fmodel.dataTitle(i));
        inc(pos,TextHeightC+5);
      end;
    end;
  end;

  //xaxis.min:=xaxisOldMin;
  Result:=result;
end;

function TDiagramDrawer.posToDataX(x: longint): float;
begin
  //umgekehrt:  (i-XAxis.min)*FValueAreaWidth div (XAxis.max-XAxis.min)+FValueAreaX
  if FValueAreaWidth=0 then exit(0);
   result:=round((x-FValueAreaX)*(XAxis.max-XAxis.min) / FValueAreaWidth + XAxis.min);
end;

{ TAbstractDiagramModel }

procedure TAbstractDiagramModel.setupAxis(xAxis, yAxis: TAxis; areaWidth, areaHeight: longint);
begin
  if XAxis.rangePolicy=rpModelControlled then begin
    if dataCount>0 then begin
      XAxis.min:=minX;
      XAxis.max:=maxX;
      if xaxis.max<=xaxis.min then xaxis.max:=xaxis.min+5;
      XAxis.autoResolution(areaWidth);
    end else begin
      XAxis.min:=0;
      XAxis.max:=50;
      XAxis.autoResolution(areaWidth);
    end;
  end;
  if YAxis.rangePolicy=rpModelControlled then begin
    if dataCount>0 then begin
      YAxis.min:=miny;
      YAxis.max:=maxY;
      if yaxis.max<=yaxis.min then yaxis.max:=yaxis.min+5;
      YAxis.autoResolution(areaHeight);
    end else begin
      YAxis.min:=0;
      YAxis.max:=50;
      YAxis.autoResolution(areaHeight);
    end;
  end;
end;

procedure TAbstractDiagramModel.modified;
begin
  fmodified:=true;
  if assigned(fmodifiedEvent) then fmodifiedEvent(self);
end;

function TAbstractDiagramModel.dataCount: longint;
begin
  result:=1;
end;

function TAbstractDiagramModel.dataTitle(i: longint): string;
begin
  result:='data';
end;

procedure TAbstractDiagramModel.setupCanvasForData(i: longint; c: TCanvas);
begin
end;


function TAbstractDiagramModel.minX(i: longint): float;
begin
  result:=0;
end;

function TAbstractDiagramModel.maxX(i: longint): float;
begin
  result:=100;
end;

function TAbstractDiagramModel.minY(i: longint): float;
var x,m,nx:float;
begin
  result:=PInfinity;
  x:=minX(i);
  m:=maxX(i);
  if IsNan(x) or IsInfinite(x) or IsNan(m) or IsInfinite(m) then exit;
  while x<=m do begin
    result:=min(x,data(i,x));
    nx:=nextx(i,x);
    if nx=x then x:=x+0.1
    else x:=nx;
  end;
end;

function TAbstractDiagramModel.maxY(i: longint): float;
var x,m,nx:float;
begin
  result:=-1e1000;
  x:=minX(i);
  m:=maxX(i);
  if IsNan(x) or IsInfinite(x) or IsNan(m) or IsInfinite(m) then exit;
  while x<=m do begin
    result:=max(x,data(i,x));
    nx:=nextx(i,x);
    if nx=x then x:=x+0.1
    else x:=nx;
  end;
end;

function TAbstractDiagramModel.nextX(i: longint; const x: float): float;
begin
  result:=x+1;
end;

function TAbstractDiagramModel.minX: float;
var i:longint;
begin
  result:=PInfinity;
  for i:=0 to dataCount-1 do
    result:=min(result,minX(i));
end;

function TAbstractDiagramModel.maxX: float;
var i:longint;
begin
  result:=MInfinity;
  for i:=0 to dataCount-1 do
    result:=max(result,maxX(i));
end;

function TAbstractDiagramModel.minY: float;
var i:longint;
begin
  result:=PInfinity;
  for i:=0 to dataCount-1 do
    result:=min(result,minY(i));
end;

function TAbstractDiagramModel.maxY: float;
var i:longint;
begin
  result:=MInfinity;
  for i:=0 to dataCount-1 do
    result:=max(result,maxY(i));
end;

{ TDiagramDataListModel }

function TDiagramDataListModel.getDataList(i:Integer): TDataList;
begin
  result:=TDataList(FLists[i]);
end;

constructor TDiagramDataListModel.create;
begin
  FLists:=TFPList.Create;
end;

destructor TDiagramDataListModel.destroy;
begin
  FLists.free;
  inherited destroy;
end;

procedure TDiagramDataListModel.deleteLists;
var i:longint;
begin
  for i:=0 to FLists.count-1 do TDataList(flists[i]).free;
  flists.clear;
end;

procedure TDiagramDataListModel.setDataCount(c: longint);
const colors:array[0..7] of TColor=(clBlue,clRed,clGreen,clMaroon,clFuchsia,clTeal,clNavy,clBlack);
var i:longint;
begin
  if flists.count<c then begin
    i:=flists.count;
    flists.count:=c;
    for i:=i to c-1 do
      flists[i]:=TDataList.Create(self,colors[i and $7]);
  end else if flists.count>c then begin
    for i:=c to flists.count-1 do
      TDataList(flists[i]).free;
    FLists.Count:=c;
  end;
end;

function TDiagramDataListModel.addDataList:TDataList;
const colors:array[0..7] of TColor=(clBlue,clRed,clGreen,clMaroon,clFuchsia,clTeal,clNavy,clBlack);
begin
  Result:=TDataList.Create(self,colors[FLists.Count and $7]);
  FLists.Add(Result);
end;

function TDiagramDataListModel.dataCount: longint;
begin
  Result:=FLists.Count;
end;

function TDiagramDataListModel.dataTitle(i: longint): string;
begin
  if (i>=0) and (i<FLists.Count) then Result:=lists[i].title
  else result:='';
end;

procedure TDiagramDataListModel.setupCanvasForData(i: longint; c: TCanvas);
begin
  if (i>=0) and (i<FLists.Count) then begin
    c.pen.Color:=lists[i].color;
    c.brush.Color:=lists[i].color;
  end;
end;

function TDiagramDataListModel.data(i: longint; const x: float): float;
begin
  if (i>=0) and (i<FLists.Count) then result:=lists[i].data(x)
  else result:=nan;
end;

function TDiagramDataListModel.minX(i: longint): float;
begin
  if (i>=0) and (i<FLists.Count) then exit(lists[i].minX)
  else exit(NaN);
end;

function TDiagramDataListModel.maxX(i: longint): float;
begin
  if (i>=0) and (i<FLists.Count) then exit(lists[i].maxX)
  else exit(NaN);
end;

function TDiagramDataListModel.minY(i: longint): float;
begin
  if (i>=0) and (i<FLists.Count) then exit(lists[i].minY)
  else exit(NaN);
end;

function TDiagramDataListModel.maxY(i: longint): float;
begin
  if (i>=0) and (i<FLists.Count) then exit(lists[i].maxY)
  else exit(NaN);
end;

function TDiagramDataListModel.nextX(i: longint; const x: float): float;
begin
  if (i>=0) and (i<FLists.Count) then result:=lists[i].nextX(x)
  else result:=maxX()+1;
end;

{ TDiagramView }

procedure TDiagramView.modelChanged(sender:Tobject);
begin
  Invalidate;
end;

procedure TDiagramView.DoOnResize;
begin
  FDrawer.Diagram.Width:=width;
  FDrawer.Diagram.Height:=Height;
  if assigned(fmodel) then FModel.fmodified:=true;
  inherited DoOnResize;
end;

procedure TDiagramView.SetModel(const AValue: TAbstractDiagramModel);
begin
  SetModel(AValue,false);
end;

constructor TDiagramView.create(aowner:TComponent);
begin
  inherited;
  FDrawer:=TDiagramDrawer.create;
  FDrawer.Diagram.width:=Width;
  FDrawer.Diagram.height:=height;
end;

destructor TDiagramView.destroy;
begin
  FDrawer.Free;
  inherited destroy;
end;

procedure TDiagramView.SetModel(amodel: TAbstractDiagramModel;
  takeOwnership: boolean);
begin
  if assigned(fmodel) then FModel.fmodifiedEvent:=nil;
  FDrawer.SetModel(amodel,takeOwnership);
  FModel:=amodel;
  if assigned(fmodel) then begin
    FModel.fmodifiedEvent:=@modelChanged;
    if assigned(fmodel) then FModel.fmodified:=true;
  end;
end;

procedure TDiagramView.paint;
begin
  if not assigned(FDrawer.FModel) then exit;
  if FModel.fmodified then
    FDrawer.update();
  canvas.Draw(0,0,FDrawer.Diagram);
  FModel.fmodified:=false;
end;

end.

