unit diagram;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,math,FPimage,IntfGraphics,LCLType;

type
  TAxis=class;
  TValueTranslateEvent=procedure (sender: TAxis; i: float; var translated: string) of object;

  { TLegend }

  TLegend=class(TPersistent)
  private
    Fauto: boolean;
    FColor: TColor;
    FHeight: longint;
    Fvisible: boolean;
    FWidth: longint;
    FModifiedEvent: TNotifyEvent;
    procedure doModified;
    procedure Setauto(const AValue: boolean);
    procedure SetColor(const AValue: TColor);
    procedure SetHeight(const AValue: longint);
    procedure Setvisible(const AValue: boolean);
    procedure SetWidth(const AValue: longint);
  published
    property visible: boolean read Fvisible write Setvisible ;
    property Width:longint read FWidth write SetWidth ;
    property Height: longint read FHeight write SetHeight;
    property Color:TColor read FColor write SetColor;
    property auto: boolean read Fauto write Setauto ;
  end;

  { TAxis }

  TRangePolicy = (rpModelControlled, rpApplicationControlled);
  TAxis=class(TPersistent)
  private
    FGridLinePen: TPen;
    FLinePen: TPen;
    Fmax: float;
    Fmin: float;
    FModifiedEvent: TNotifyEvent;
    FrangePolicy: TRangePolicy;
    Fresolution: float;
    FvalueTranslate: TValueTranslateEvent;
    procedure doModified(sender:tobject);
    procedure SetGridLinePen(const AValue: TPen);
    procedure SetLinePen(const AValue: TPen);
    procedure Setmax(const AValue: float);
    procedure Setmin(const AValue: float);
    procedure SetrangePolicy(const AValue: TRangePolicy);
    procedure Setresolution(const AValue: float);
    procedure SetvalueTranslate(const AValue: TValueTranslateEvent);
  protected
    function doTranslate(const i:float): string;
  public
    constructor create();
    destructor destroy();override;

    //title: string;

    function translate(const i:float): string;inline;
    procedure autoResolution(imageSize: longint);
  published
    property gridLinePen: TPen read FGridLinePen write SetGridLinePen;
    property linePen: TPen read FLinePen write SetLinePen;
    property min: float read Fmin write Setmin;
    property max: float read Fmax write Setmax;
    property resolution: float read Fresolution write Setresolution;
    property rangePolicy: TRangePolicy read FrangePolicy write SetrangePolicy;
    property valueTranslate: TValueTranslateEvent read FvalueTranslate write SetvalueTranslate;
  end;
  TDataPoint=record
    x,y:float;
  end;

  TLineStyle=(lsNone, lsLinear);
  TPointStyle = (psNone, psPixel, psCircle, psRectangle, psPlus, psCross);

  { TAbstractDiagramModel }

  {** This is the abstract class you have to implement for custom data
  }
  TAbstractDiagramModel = class(TPersistent)
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
    //**Returns the count of data points in a given row
    function dataPoints(i:longint):longint; virtual;abstract;
    //**This returns the actual data (you must override it), j from 0 to dataPoints(i)-1, the must be in sorted order (x[i]<x[i+1])
    procedure data(i,j:longint; out x,y:float); virtual;abstract;

    //**returns the minimum x (default 0, you should override it)
    function minX(i:longint):float; virtual;
    //**returns the maximum x (default 100, you should override it)
    function maxX(i:longint):float; virtual;
    //**returns the minimum value (default scans all values)
    function minY(i:longint):float; virtual;
    //**returns the maximum value (default scans all values)
    function maxY(i:longint):float; virtual;

    function dataX(i,j:longint):float; //**<returns x of point i,j, calls data
    function dataY(i,j:longint):float; //**<returns y of point i,j, calls data

    function minX:float;
    function maxX:float;
    function minY:float;
    function maxY:float;
  end;

  //**This class draws the data model into a TBitmap

  { TDiagramDrawer }

  TDiagramDrawer = class(TPersistent)
  private
    FBackColor: TColor;
    FDataBackColor: TColor;
    FLayoutModified: Boolean;
    FLineStyle: TLineStyle;
    FModifiedEvent: TNotifyEvent;
    FFilled: boolean;
    Flegend: TLegend;
    FModel: TAbstractDiagramModel;
    FModelOwnership: boolean;
    FPointSize: longint;
    FPointStyle: TPointStyle;
    fvalueAreaX,FValueAreaY,FValueAreaWidth,FValueAreaHeight,FValueAreaRight,FValueAreaBottom: longint;
    FDiagram: TBitmap;
    FXAxis,FYAxis: TAxis;
    procedure doModified;
    procedure SetBackColor(const AValue: TColor);
    procedure SetDataBackColor(const AValue: TColor);
    procedure SetFilled(const AValue: boolean);
    procedure SetLineStyle(const AValue: TLineStyle);
    procedure SetModel(const AValue: TAbstractDiagramModel);
    procedure SetPointSize(const AValue: longint);
    procedure SetPointStyle(const AValue: TPointStyle);
  public
    constructor create;
    function update(): TBitmap;
    destructor destroy;override;

    //**Sets the model to be drawn, if takeOwnership is true, then the model is freed automatically by the drawer, otherwise you have to free it yourself
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);

    function posToDataX(x: longint): float;

    property Diagram: TBitmap read FDiagram;

  published
    property legend:TLegend read Flegend;
    property XAxis: TAxis read FXAxis;
    property YAxis: TAxis read FYAxis;
    property LineStyle: TLineStyle read FLineStyle write SetLineStyle;
    property PointStyle: TPointStyle read FPointStyle write SetPointStyle;
    property PointSize: longint read FPointSize write SetPointSize;
    property Filled: boolean read FFilled write SetFilled;
    property Model: TAbstractDiagramModel read FModel write SetModel;
    property BackColor: TColor read FBackColor write SetBackColor;
    property DataBackColor: TColor read FDataBackColor write SetDataBackColor;
  end;


  { TDiagramView }

  TDiagramView = class (TCustomControl)
  private
    FDrawer: TDiagramDrawer;
    FModel: TAbstractDiagramModel;
    procedure modelChanged(sender:Tobject);
    procedure layoutChanged(sender:Tobject);
    procedure DoOnResize;override;
    procedure SetModel(const AValue: TAbstractDiagramModel);
  public
    constructor create(aowner:TComponent);override;
    destructor destroy;override;
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);
    procedure paint;override;
  published
    property Drawer: TDiagramDrawer read FDrawer;
    property Model: TAbstractDiagramModel read FModel write SetModel;
  end;

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

    procedure data(i:longint; out x,y: float); //**<returns the data at position i
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
    //**This returns the number of data points in a given lists
    function dataPoints(i:longint): longint; override;
    //**This returns the actual data (amortized O(1) if called in correct order)
    procedure data(i,j:longint; out x,y:float); override;

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

procedure TAxis.doModified(sender:tobject);
begin
  if assigned(FModifiedEvent) then FModifiedEvent(self);
end;

procedure TAxis.SetGridLinePen(const AValue: TPen);
begin
  if FGridLinePen=AValue then exit;
  FGridLinePen.Assign(AValue);
  domodified(self);
end;

procedure TAxis.SetLinePen(const AValue: TPen);
begin
  if FLinePen=AValue then exit;
  FLinePen.Assign(AValue);
  domodified(self);
end;

procedure TAxis.Setmax(const AValue: float);
begin
  if Fmax=AValue then exit;
  Fmax:=AValue;
  doModified(self);
end;

procedure TAxis.Setmin(const AValue: float);
begin
  if Fmin=AValue then exit;
  Fmin:=AValue;
  doModified(self);
end;

procedure TAxis.SetrangePolicy(const AValue: TRangePolicy);
begin
  if FrangePolicy=AValue then exit;
  FrangePolicy:=AValue;
  doModified(self);
end;

procedure TAxis.Setresolution(const AValue: float);
begin
  if AValue<=0 then exit;
  if Fresolution=AValue then exit;
  Fresolution:=AValue;
  doModified(self);
end;

procedure TAxis.SetvalueTranslate(const AValue: TValueTranslateEvent);
begin
  if FvalueTranslate=AValue then exit;
  FvalueTranslate:=AValue;
  doModified(self);
end;

function TAxis.doTranslate(const i:float): string;
begin
  if frac(i)<1e-16 then result:=inttostr(round(i))
  else if resolution>1 then result:=inttostr(round(i))
  else result:=format('%.2g',[i]);
  if assigned(valueTranslate) then
    valueTranslate(self,i,result);
end;

constructor TAxis.create();
begin
  FGridLinePen:=TPen.Create;
  FLinePen:=TPen.Create;
  FGridLinePen.OnChange:=@doModified;
  FLinePen.OnChange:=@doModified;
end;

destructor TAxis.destroy();
begin
  inherited destroy();
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

procedure TDataList.data(i: longint; out x, y: float);
begin
  if (i<0) or (i>=pointCount) then begin
    x:=nan;
    y:=nan;
    exit;
  end;
  x:=points[i].x;
  y:=points[i].y;
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

procedure TDiagramDrawer.SetPointSize(const AValue: longint);
begin
  if FPointSize=AValue then exit;
  FPointSize:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetPointStyle(const AValue: TPointStyle);
begin
  if FPointStyle=AValue then exit;
  FPointStyle:=AValue;
  doModified;
end;

procedure TDiagramDrawer.doModified;
begin
  FLayoutModified:=true;
  if Assigned(FModifiedEvent) then FModifiedEvent(self);
end;

procedure TDiagramDrawer.SetBackColor(const AValue: TColor);
begin
  if FBackColor=AValue then exit;
  FBackColor:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetDataBackColor(const AValue: TColor);
begin
  if FDataBackColor=AValue then exit;
  FDataBackColor:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetFilled(const AValue: boolean);
begin
  if FFilled=AValue then exit;
  FFilled:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetLineStyle(const AValue: TLineStyle);
begin
  if FLineStyle=AValue then exit;
  FLineStyle:=AValue;
  doModified;
end;

constructor TDiagramDrawer.create;
begin
  FXAxis:=TAxis.Create;
  FYAxis:=TAxis.Create;
  FXAxis.rangePolicy:=rpModelControlled;
  FYAxis.rangePolicy:=rpModelControlled;
  FXAxis.gridLinePen.Style:=psClear;
  FXAxis.gridLinePen.Color:=clGray;
  FYAxis.gridLinepen.Color:=clGray;
  FXAxis.linePen.Color:=clBlack;
  FYAxis.linepen.Color:=clBlack;
  FDiagram:=TBitmap.Create;
  FDiagram.width:=300;
  FDiagram.height:=300;
  fbackColor:=clBtnFace;
  fdataBackColor:=clSilver;
  flegend:=TLegend.Create;
  flegend.auto:=true;
  flegend.visible:=true;
  flegend.color:=clBtnFace;
  fLineStyle:=lsLinear;
  FPointSize:=3;
end;

destructor TDiagramDrawer.destroy;
begin
  FXAxis.free;
  FYAxis.free;
  FDiagram.free;
  legend.free;
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
var xstart,ystart,xfactor,yfactor,xend,yend: float; //copied from axis

  procedure translate(const x,y:float; out px,py:longint);inline;
  begin
    px:=FValueAreaX+round((x-xstart)*xfactor);
    py:=FValueAreaBottom-round((y-ystart)*yfactor);
  end;
  procedure getRPos(const i,j:longint; out px,py:longint);inline;
  var x,y:float;
  begin
    FModel.data(i,j,x,y);
    translate(x,y,px,py);
  end;

var
    canvas: TCanvas;

  procedure drawLinearLines(id:longint);
  var i,x,y:longint;
  begin
    getRPos(id,0,x,y);
    canvas.MoveTo(x,y);
    for i:=1 to fModel.dataPoints(id)-1 do begin
      getRPos(id,i,x,y);
      canvas.LineTo(x,y);
    end;
  end;
  procedure drawPoints(id: longint);
  var i:longint;
      x,y: longint;
  begin
    for i:=0 to fModel.dataPoints(id)-1 do begin
      getRPos(id,i,x,y);
      case PointStyle of
        psPixel: Canvas.Pixels[x,y]:=canvas.Pen.Color;
        psCircle: canvas.EllipseC(x,y,pointSize,pointSize);
        psRectangle: canvas.Rectangle(x-PointSize,y-PointSize,x+pointSize,y+pointSize);
        psPlus: begin
          canvas.Line(x-PointSize,y,x+PointSize+1,y);
          canvas.Line(x,y-PointSize,x,y+PointSize+1);
        end;
        psCross: begin
          canvas.Line(x-PointSize,y-PointSize,x+PointSize+1,y+PointSize+1);
          canvas.Line(x+PointSize,y-PointSize,x-PointSize-1,y+PointSize+1);
        end;
      end;
    end;
  end;

var i,j,pos,textHeightC,legendX:longint;
    p:float;
    caption,captionOld:string;
    currentColor,fpbackcolor,fplinecolor:tfpcolor;
    tempLazImage:TLazIntfImage;
    bitmap,maskbitmap: HBITMAP;
begin
  result:=Diagram;
  canvas:=result.canvas;
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
    legend.height:=(textHeightC+5)*FModel.dataCount()+5;
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
        if XAxis.gridLinePen.Style<>psClear then begin
          pen:=XAxis.gridLinePen;
          MoveTo(pos,FValueAreaY);
          LineTo(pos,FValueAreaBottom);
          pen:=XAxis.linePen;
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
        if YAxis.gridLinePen.Style<>psClear then begin
          pen:=YAxis.gridLinePen;
          MoveTo(FValueAreaX,pos);
          LineTo(FValueAreaRight,pos);
          pen:=YAxis.linePen;
        end;
        MoveTo(FValueAreaX-3,pos);
        LineTo(FValueAreaX+2,pos);
      end;
      TextOut(FValueAreaX-3-TextWidth(caption),pos-textHeightC div 2, caption);
      if IsNan(YAxis.resolution) or IsInfinite(YAxis.resolution) then p+=round((yend-ystart) / 10)
      else p+=YAxis.resolution;
    end;

    //Draw Values
    for i:=0 to FModel.dataCount-1 do begin
      if fModel.dataPoints(i)=0 then continue;
      FModel.setupCanvasForData(i,canvas);
      case LineStyle of
        lsLinear: drawLinearLines(i);
      end;
      if PointStyle<>psNone then drawPoints(i);
    end;

    //fill values
    //TODO: problem, this overrides y-lines, this could run in dataLines*dataPoints*log dataPoints
    if filled then begin
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(result.Handle,0);
      fpbackcolor:=TColorToFPColor(dataBackColor);
      if YAxis.gridLinePen.Style<>psClear then fplinecolor:=TColorToFPColor(YAxis.gridLinePen.Color)
      else fplinecolor:=TColorToFPColor(clNone);
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
  if dataPoints(i)>0 then result:=dataX(i,0)
  else result:=0;
end;

function TAbstractDiagramModel.maxX(i: longint): float;
begin
  if dataPoints(i)>0 then result:=dataX(i,dataPoints(i)-1)
  else result:=0;
end;

function TAbstractDiagramModel.minY(i: longint): float;
var j:longint;
begin
  result:=PInfinity;
  for j:=0 to dataPoints(i)-1 do
    result:=min(result,dataY(i,j));
end;

function TAbstractDiagramModel.maxY(i: longint): float;
var j:longint;
begin
  result:=PInfinity;
  for j:=0 to dataPoints(i)-1 do
    result:=max(result,dataY(i,j));
end;

function TAbstractDiagramModel.dataX(i, j: longint): float;
var t:float;
begin
  data(i,j,result,t);
end;

function TAbstractDiagramModel.dataY(i, j: longint): float;
var t:float;
begin
  data(i,j,result,t);
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

function TDiagramDataListModel.dataPoints(i: longint): longint;
begin
  if (i>=0) and (i<FLists.Count) then result:=lists[i].pointCount
  else result:=0;
end;

procedure TDiagramDataListModel.data(i, j: longint; out x, y: float);
begin
  if (i>=0) and (i<FLists.Count) then lists[i].data(j,x,y)
  else begin
    x:=nan;
    y:=nan;
  end;
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

{ TDiagramView }

procedure TDiagramView.modelChanged(sender:Tobject);
begin
  Invalidate;
end;

procedure TDiagramView.layoutChanged(sender: Tobject);
begin
  FDrawer.FLayoutModified:=true;
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
  FDrawer.XAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.YAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.legend.FModifiedEvent:=@layoutChanged;
  FDrawer.FModifiedEvent:=@layoutChanged;
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
  if FModel.fmodified or FDrawer.FLayoutModified then
    FDrawer.update();
  canvas.Draw(0,0,FDrawer.Diagram);
  FModel.fmodified:=false;
  FDrawer.FLayoutModified:=false;
end;

{ TLegend }

procedure TLegend.Setvisible(const AValue: boolean);
begin
  if Fvisible=AValue then exit;
  Fvisible:=AValue;
  domodified;
end;

procedure TLegend.doModified;
begin
  if assigned(FModifiedEvent) then FModifiedEvent(self);
end;

procedure TLegend.Setauto(const AValue: boolean);
begin
  if Fauto=AValue then exit;
  Fauto:=AValue;
  doModified;
end;

procedure TLegend.SetColor(const AValue: TColor);
begin
  if FColor=AValue then exit;
  FColor:=AValue;
  doModified;
end;

procedure TLegend.SetHeight(const AValue: longint);
begin
  if FHeight=AValue then exit;
  FHeight:=AValue;
  doModified;
end;

procedure TLegend.SetWidth(const AValue: longint);
begin
  if FWidth=AValue then exit;
  FWidth:=AValue;
  doModified;
end;

end.

