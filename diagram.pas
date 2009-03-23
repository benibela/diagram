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

  TRangePolicy = (rpAuto, rpApplication);
  TAxis=class(TPersistent)
  private
    FGridLinePen: TPen;
    FLinePen: TPen;
    Fmax: float;
    Fmin: float;
    FModifiedEvent: TNotifyEvent;
    FrangePolicy: TRangePolicy;
    Fresolution: float;
    FShowText: boolean;
    FvalueTranslate: TValueTranslateEvent;
    FVisible: boolean;
    procedure doModified(sender:tobject);

    procedure SetGridLinePen(const AValue: TPen);
    procedure SetLinePen(const AValue: TPen);
    procedure Setmax(const AValue: float);
    procedure Setmin(const AValue: float);
    procedure SetrangePolicy(const AValue: TRangePolicy);
    procedure Setresolution(const AValue: float);
    procedure SetShowText(const AValue: boolean);
    procedure SetvalueTranslate(const AValue: TValueTranslateEvent);
    procedure SetVisible(const AValue: boolean);
  protected
    function doTranslate(const i:float): string;
  public
    constructor create();
    destructor destroy();override;

    //title: string;

    function translate(const i:float): string;inline;
    procedure rangeChanged(const rmin,rmax:float; realSize: longint);
  published
    property gridLinePen: TPen read FGridLinePen write SetGridLinePen;
    property linePen: TPen read FLinePen write SetLinePen;
    property min: float read Fmin write Setmin;
    property max: float read Fmax write Setmax;
    property resolution: float read Fresolution write Setresolution;
    property rangePolicy: TRangePolicy read FrangePolicy write SetrangePolicy;
    property valueTranslate: TValueTranslateEvent read FvalueTranslate write SetvalueTranslate;
    property Visible:boolean read FVisible write SetVisible;
    property ShowText:boolean read FShowText write SetShowText;
  end;
  TDataPoint=record
    x,y:float;
  end;

  const DiagramEpsilon=1e-15;
type
  TModelFlag=(mfEditable);
  TModelFlags=set of TModelFlag;
  //**lsNone=no lines, lsLinear=the points are connected with straight lines
  //**lsCubicSpline=the points are connected with a normal cubic spline (needing O(n) additional memory)
  //**lsLocalCubicSpline=the points are connected with a pseudo cubic spline (needing no additional memory, but looks not so nicely)
  TLineStyle=(lsNone, lsLinear, lsCubicSpline, lsLocalCubicSpline);
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
    //**This returns the number of data rows (override if you use more than 1)
    function dataRows: longint; virtual;
    //**This returns the title of every data row for the legend
    function dataTitle(i:longint):string; virtual;
    //**This setups the canvas (override it to set the color, set pen and brush to the same)
    procedure setupCanvasForData(i:longint; c: TCanvas); virtual;
    //**Returns the count of data points in a given row
    function dataPoints(i:longint):longint; virtual;abstract;
    //**This returns the actual data (you must override it), j from 0 to dataPoints(i)-1, the must be in sorted order (x[i]<x[i+1])
    procedure data(i,j:longint; out x,y:float); virtual;abstract;
    //**Set the data point and returns the new index (default does nothing and returns j) (if you override it, keep in mind that data must return its values in a sorted order)
    function setData(i,j:longint; const x,y:float):integer;virtual;
    //**Add a data point and returns the new index (default does nothing and returns -1) (if you override it, keep in mind that data must return its values in a sorted order)
    function addData(i:longint; const x,y:float):integer;virtual;
    //**removes a certain data point (default does nothing)
    procedure removeData(i,j:longint);virtual;

    //**returns the minimum x (default 0, you should override it)
    function minX(i:longint):float; virtual;
    //**returns the maximum x (default 100, you should override it)
    function maxX(i:longint):float; virtual;
    //**returns the minimum value (default scans all values)
    function minY(i:longint):float; virtual;
    //**returns the maximum value (default scans all values)
    function maxY(i:longint):float; virtual;

    function getFlags: TModelFlags; virtual;//**<returns model flags (e.g. editable)

    //**Searchs the point in row i at position x,y with xtolerance, ytolerance
    //**If y is NaN, only the x position is used
    //**If ytolerance is NaN, the x tolerance is used for it
    //**If the point isn't found, it returns -1
    //**The default implementation checks all points TODO: implement binary search
    function find(i:longint; const x:float; const y:float=NaN; const xtolerance:float=DiagramEpsilon; const ytolerance:float=NaN):longint;virtual;
    //**like find but set the position to the correct values (default calls find)
    function findAndGet(i:longint; var x:float; var y:float=NaN; const xtolerance:float=DiagramEpsilon; const ytolerance:float=NaN):longint;virtual;
    //**like find but searchs in all rows and returns the correct one (default calls find)
    function findWithRow(out i:longint; const x:float; const y:float=NaN; const xtolerance:float=DiagramEpsilon; const ytolerance:float=NaN):longint;virtual;
    //**like findRow but set the position to the correct values (default calls findAndGet)
    function findWithRowAndGet(out i:longint; var x:float; var y:float=NaN; const xtolerance:float=DiagramEpsilon; const ytolerance:float=NaN):longint;virtual;

    function dataX(i,j:longint):float; //**<returns x of point i,j, calls data
    function dataY(i,j:longint):float; //**<returns y of point i,j, calls data

    function minX:float;
    function maxX:float;
    function minY:float;
    function maxY:float;
  end;


  { TDiagramDrawer }
  //a*x^3+b*x^2+c*x+d
  TDiagramSplinePiece = record
    a,b,c,d: float;
  end;
  //**This class draws the data model into a TBitmap
  TDiagramDrawer = class(TPersistent)
  private
    FSplines: array of array of TDiagramSplinePiece;
    FAutoSetRangeX: boolean;
    FAutoSetRangeY: boolean;
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
    FRangeMaxX: float;
    FRangeMaxY: float;
    FRangeMinX: float;
    FRangeMinY: float;
    fvalueAreaX,FValueAreaY,FValueAreaWidth,FValueAreaHeight,FValueAreaRight,FValueAreaBottom: longint;
    FDiagram: TBitmap;
    FLAxis,FYMAxis,FRAxis, FTAxis,FXMAxis,FBAxis: TAxis;
    procedure doModified;
    procedure SetAutoSetRangeX(const AValue: boolean);
    procedure SetAutoSetRangeY(const AValue: boolean);
    procedure SetBackColor(const AValue: TColor);
    procedure SetDataBackColor(const AValue: TColor);
    procedure SetFilled(const AValue: boolean);
    procedure SetLineStyle(const AValue: TLineStyle);
    procedure SetModel(const AValue: TAbstractDiagramModel);
    procedure SetPointSize(const AValue: longint);
    procedure SetPointStyle(const AValue: TPointStyle);
    procedure SetRangeMaxX(const AValue: float);
    procedure SetRangeMaxY(const AValue: float);
    procedure SetRangeMinX(const AValue: float);
    procedure SetRangeMinY(const AValue: float);

    procedure calculateSplines(); //**< always (even if not needed) calculates a spline (O(n) memory)
    procedure updateSpline3P(var spline:TDiagramSplinePiece; const x1,y1,x2,y2,x3,y3: float);
    function calcSpline(const spline:TDiagramSplinePiece; const x:float):float;
  public
    constructor create;
    function update(): TBitmap;
    destructor destroy;override;

    //**Sets the model to be drawn, if takeOwnership is true, then the model is freed automatically by the drawer, otherwise you have to free it yourself
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);

    function posToDataX(x: longint): float;
    function posToDataY(y: longint): float;
    function dataToPosX(const x: float): integer;
    function dataToPosY(const y: float): integer;
    function pixelSizeX: float; //**< Returns the width of one output pixel in data coordinates
    function pixelSizeY: float; //**< Returns the height of one output pixel in data coordinates

    //**this returns the position of the interpolation line (linear or cubic) in data coordinates
    function lineYatX(i:longint; const x: float): float;
    //**finds a line like find. (since the line is 1-dimensional the x coordinate is not sufficient and has to be exact)
    function findLine(const x,y:float; const ytolerance: float=DiagramEpsilon): longint;

    property Diagram: TBitmap read FDiagram;

  published
    property RangeMinX: float read FRangeMinX write SetRangeMinX;
    property RangeMaxX: float read FRangeMaxX write SetRangeMaxX;
    property RangeMinY: float read FRangeMinY write SetRangeMinY;
    property RangeMaxY: float read FRangeMaxY write SetRangeMaxY;
    property AutoSetRangeX: boolean read FAutoSetRangeX write SetAutoSetRangeX;
    property AutoSetRangeY: boolean read FAutoSetRangeY write SetAutoSetRangeY;
    property legend:TLegend read Flegend;
    property LeftAxis: TAxis read FLAxis;
    property RightAxis: TAxis read FRAxis;
    property TopAxis: TAxis read FTAxis;
    property BottomAxis: TAxis read FBAxis;
    property HorzMidAxis: TAxis read FXMAxis;
    property VertMidAxis: TAxis read FYMAxis;
    property LineStyle: TLineStyle read FLineStyle write SetLineStyle;
    property PointStyle: TPointStyle read FPointStyle write SetPointStyle;
    property PointSize: longint read FPointSize write SetPointSize;
    property Filled: boolean read FFilled write SetFilled;
    property Model: TAbstractDiagramModel read FModel write SetModel;
    property BackColor: TColor read FBackColor write SetBackColor;
    property DataBackColor: TColor read FDataBackColor write SetDataBackColor;
  end;


  { TDiagramView }
  TDiagramPointMovement=(pmStandard, pmAffectNeighbours);
  TDiagramEditAction=(eaMovePoints, eaAddPoints, eaDeletePoints);
  TDiagramEditActions=set of TDiagramEditAction;
  TDiagramView = class (TCustomControl)
  private
    FAllowedEditActions: TDiagramEditActions;
    FPointMovement: TDiagramPointMovement;
    FSelRow,FSelPoint:longint;
    FSelPointMoving: boolean;
    FHighlightPoint: TDataPoint;
    FDrawer: TDiagramDrawer;
    FModel: TAbstractDiagramModel;
    procedure modelChanged(sender:Tobject);
    procedure layoutChanged(sender:Tobject);
    procedure DoOnResize;override;
    procedure SetAllowedEditActions(const AValue: TDiagramEditActions);
    procedure SetModel(const AValue: TAbstractDiagramModel);
    procedure SetPointMovement(const AValue: TDiagramPointMovement);
  public
    constructor create(aowner:TComponent);override;
    destructor destroy;override;
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);
    procedure paint;override;
    procedure MouseDown(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer);override;
    procedure MouseUp(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure DoExit; override;
  published
    property Drawer: TDiagramDrawer read FDrawer;
    property PointMovement: TDiagramPointMovement read FPointMovement write SetPointMovement;
    property AllowedEditActions: TDiagramEditActions read FAllowedEditActions write SetAllowedEditActions;
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
    procedure rescanYBorder;
    function resortPoint(i:longint):integer;
  public
    constructor create(aowner:TAbstractDiagramModel; acolor: TColor);
    color: TColor;
    title:string;
    //function getPoint(x:longint): longint;
    procedure clear(keepMemory: boolean=false); //**<removes all points, if keepMemory is true, the memory of the points is not freed
    function count:longint;
    //**adds a point at position (x,y) in the sorted list, removing duplicates on same x. (possible moving all existing points => O(1) if called in right order, O(n) if the inserted point belongs to the beginnning).
    //**It does use an intelligent growth strategy (size *2 if < 512, size+=512 otherwise, starting at 8)
    function addPoint(x,y:float):longint; overload;
    //**adds a point at position (x+1,y) in the sorted list. (possible moving all existing points).
    //**It does use an intelligent growth strategy
    function addPoint(y:float):longint; overload;
    //**sets the point j to the position x,y; reorders point if necessary (possible moving the point j to another index) (can change minY, maxY)
    function setPoint(j:longint; const x,y:float):integer;
    //**removes point j
    procedure removePoint(j:longint);

    procedure point(i:longint; out x,y: float); //**<returns the data at position i
  end;

  { TDiagramDataListModel }

  TDiagramDataListModel = class (TAbstractDiagramModel)
  private
    FFlags: TModelFlags;
    FLists: TFPList;
    function getDataList(i:Integer): TDataList;
    function GetFlags: TModelFlags;override;
    procedure SetFlags(const AValue: TModelFlags);
  public
    constructor create;
    destructor destroy;override;

    //**delete all lists
    procedure deleteLists;virtual;

    //**Set the count of data lists
    procedure setDataRows(c:longint);
    function addDataList:TDataList;
    //**This returns the number of data lists
    function dataRows: longint; override;
    //**This returns the title of every data list for the legend
    function dataTitle(i:longint):string; override;
    //**This set the color to the data list color
    procedure setupCanvasForData(i:longint; c: TCanvas); override;
    //**This returns the number of data points in a given lists
    function dataPoints(i:longint): longint; override;
    //**This returns the actual data (amortized O(1) if called in correct order)
    procedure data(i,j:longint; out x,y:float); override;
    //**Set the data point (only accept changes if flags contains mfEditable, use lists[i].setPoint in other cases)
    function setData(i,j:longint; const x,y:float):integer;override;
    //**Add a data point to an existing row and returns the new index (only accept changes if flags contains mfEditable, use lists[i].addPoint in other cases)
    function addData(i:longint; const x,y:float):integer;override;
    //**removes the data point (only accept changes if flags contains mfEditable, use lists[i].removePoint in other cases)
    procedure removeData(i,j:longint);override;

    //**returns the minimum x
    function minX(i:longint):float; override;overload;
    //**returns the maximum x
    function maxX(i:longint):float; override;overload;
    //**returns the minimum value (O(1))
    function minY(i:longint):float; override;overload;
    //**returns the maximum value (O(1))
    function maxY(i:longint):float; override;overload;

    property lists[i:Integer]: TDataList read getDataList; default;
  published
    property Flags: TModelFlags read GetFlags write SetFlags;
  end;


  { TDiagramFixedWidthCircularDataListModel }

  //**this is a special model you probably don't need
  //**It is like a TDiagramDataListModel but ensures that the last and first point always have
  //**the same y-position if modified by the user and that he can't modify their x-position
  //**(the application interface with lists[i] can modify everything)
  TDiagramFixedWidthCircularDataListModel = class (TDiagramDataListModel)
    function setData(i,j:longint; const x,y:float):integer;override;
    function addData(i:longint; const x,y:float):integer;override;
    procedure removeData(i,j:longint);override;
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

procedure TAxis.SetShowText(const AValue: boolean);
begin
  if FShowText=AValue then exit;
  FShowText:=AValue;
  doModified(self);
end;

procedure TAxis.SetvalueTranslate(const AValue: TValueTranslateEvent);
begin
  if FvalueTranslate=AValue then exit;
  FvalueTranslate:=AValue;
  doModified(self);
end;

procedure TAxis.SetVisible(const AValue: boolean);
begin
  if FVisible=AValue then exit;
  FVisible:=AValue;
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

procedure TAxis.rangeChanged(const rmin,rmax:float; realSize: longint);
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
    if IsInfinite(rmin) or IsInfinite(rmax) or IsNan(rmin) or IsNan(rmax) then begin
      resolution:=NaN;
      exit;
    end;
    min:=rmin;
    max:=rmax;
    if abs(max-min)<1e-16 then resolution:=1
    else if realSize / (max-min)>20 then resolution:=1
    else if realSize / (max-min)>0 then resolution:=(max-min)*30 / realSize
    else resolution:=(max-min)*30 / realSize;

end;

procedure TDataList.point(i: longint; out x, y: float);
begin
  if (i<0) or (i>=pointCount) then begin
    x:=nan;
    y:=nan;
    exit;
  end;
  x:=points[i].x;
  y:=points[i].y;
end;

procedure TDataList.rescanYBorder;
var i:longint;
begin
  maxY:=MInfinity;
  minY:=PInfinity;
  for i:=0 to pointCount-1 do begin
    if points[i].y<minY then minY:=points[i].y;
    if points[i].y>maxY then maxY:=points[i].y;
  end;
end;

function TDataList.resortPoint(i: longint):integer;
var temp:TDataPoint;
begin
  if i>=pointCount then exit;
  //check left side
  while (i>=1) and (points[i-1].x>points[i].x) do begin
    temp:=points[i];
    points[i]:=points[i-1];
    points[i-1]:=temp;
    i-=1;
  end;
  //check right side
  while (i<pointCount-1) and (points[i].x>points[i+1].x) do begin
    temp:=points[i];
    points[i]:=points[i+1];
    points[i+1]:=temp;
    i+=1;
  end;
  result:=i;
  minX:=points[0].x;
  maxX:=points[pointCount-1].x;
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

function TDataList.addPoint(x,y:float):longint;
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
    exit(0);
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
        exit(i);
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
  result:=i;
end;
function TDataList.addPoint(y:float):longint;
begin
  if pointCount=0 then result:=addPoint(0,y)
  else result:=addPoint(points[pointCount-1].x+1,y);
end;

function TDataList.setPoint(j: longint; const x, y: float):integer;
var wasBorder:boolean;
begin
  if (j<0) or (j>=pointCount) then exit;
  wasBorder:=(points[j].y<=minY) or (points[j].y>=maxY);
  points[j].x:=x;
  points[j].y:=y;
  if wasBorder then rescanYBorder;
  result:=resortPoint(j);
  if assigned(owner) then owner.modified;
end;

procedure TDataList.removePoint(j: longint);
var wasBorder:boolean;
begin
  if (j<0) or (j>=pointCount) then exit;
  if j=pointCount-1 then begin
    pointCount-=1;
    if pointCount>0 then begin
      maxX:=points[pointCount-1].x;
      if (maxY<=points[j].y) or (minY>=points[j].y) then rescanYBorder;
    end;
    if assigned(owner) then owner.modified;
    exit;
  end;
  wasBorder:=(points[j].y<=minY) or (points[j].y>=maxY);
  move(points[j+1],points[j],sizeof(points[j])*(pointCount-j-1));
  pointCount-=1;
  if j=0 then minX:=points[0].x;
  if wasBorder then rescanYBorder;
  if assigned(owner) then owner.modified;
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

procedure TDiagramDrawer.SetRangeMaxX(const AValue: float);
begin
  if FRangeMaxX=AValue then exit;
  FRangeMaxX:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetRangeMaxY(const AValue: float);
begin
  if FRangeMaxY=AValue then exit;
  FRangeMaxY:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetRangeMinX(const AValue: float);
begin
  if FRangeMinX=AValue then exit;
  FRangeMinX:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetRangeMinY(const AValue: float);
begin
  if FRangeMinY=AValue then exit;
  FRangeMinY:=AValue;
  doModified;
end;

procedure TDiagramDrawer.calculateSplines();
//taken from Wikipedia
var r,i,n,im:longint;
    xpi,xi,l,alpha:float;
    h,z,my: array of float;
begin
  SetLength(FSplines,FModel.dataRows);
  for r:=0 to high(FSplines) do begin
    n:=FModel.dataPoints(r);
    setlength(FSplines[r],n);
    if n<=1 then continue;
    setlength(z,n);
    setlength(my,n);
    setlength(h,n);
    fmodel.data(r,0,xi,FSplines[r,0].d);
    for i:=0 to n-2 do begin
      fmodel.data(r,i+1,xpi,FSplines[r,i+1].d );
      h[i]:=xpi-xi;
      xi:=xpi;
    end;
    my[0]:=0;z[0]:=0;z[n-1]:=0;
    im:=0;
    for i:=1 to n-2 do begin
      l:=2*(h[i]+h[im]) - h[im]*my[im];
      my[i]:=h[i]/l;
      if abs(h[i])<DiagramEpsilon then
        z[i]:=z[i-1]
      else begin
        alpha:=3*(FSplines[r,i+1].d-FSplines[r,i].d)/h[i] - 3*(FSplines[r,i].d-FSplines[r,i-1].d)/h[im];
        z[i]:=(alpha-h[im]*z[im])/l;
        im:=i;
      end;
    end;
    FSplines[r,n-1].b:=0;
    im:=n-1;
    for i:=n-2 downto 0 do begin
      FSplines[r,i].b:=z[i] - my[i]*FSplines[r,i+1].b;
      if abs(h[i])< DiagramEpsilon then begin
        FSplines[r,i].c:=FSplines[r,i+1].c;
        FSplines[r,i].a:=FSplines[r,i+1].a;
      end else begin
        FSplines[r,i].c:=(FSplines[r,i+1].d-FSplines[r,i].d)/h[i] - h[i]*(FSplines[r,i+1].b+2*FSplines[r,i].b)/3;
        FSplines[r,i].a:=(FSplines[r,i+1].b-FSplines[r,i].b)/(3*h[i]);
        im:=i;
      end;
    end;
  end;
end;

procedure TDiagramDrawer.updateSpline3P(var spline: TDiagramSplinePiece;
  const x1,y1,x2,y2,x3,y3: float);
//P(x1) = y1, P(x2) = y2, P(x3) = y3
//P'(x1) = P0'(x1)
var od1, fr: float;
begin
  with spline do begin
    od1:= (3*a*x1+2*b)*x1+c; //P0'(ox) = 3*a*x*x+2*b*x+c

    {
    SOLVE([a·x1^3 + b·x1*x1 + c·x1 + d = y1, a·x2^3 + b·x2^2 + c·x2 + d = y2, 3·a·x1·x1 + 2·b·ox + c = od1, a·x3^3 + b·x3^2 + c·x3 + d = y3], [b, a, c, d])
    }
    fr:=((x1*x1-2*x1*x3+x3*x3)*(x1*x1-2*x1*x2+x2*x2)*(x2-x3));
    if abs(fr)<DiagramEpsilon then exit;
    fr:=1/fr;
    //TODO: optimize
    a:=fr*(od1*(x1*x1-x1*(x2+x3)+x2*x3)*(x2-x3)+x1*x1*(y2-y3)-2*x1*(x2*(y1-y3)+x3*(y2-y1))+x2*x2*(y1-y3)+x3*x3*(y2-y1));
    b:=-fr*(od1*(x1*x1*x1-x1*(x2*x2+x2*x3+x3*x3)+x2*x3*(x2+x3))*(x2-x3)+2*x1*x1*x1*(y2-y3)-3*x1*x1*(x2*(y1-y3)+x3*(y2-y1))+x2*x2*x2*(y1-y3)+x3*x3*x3*(y2-y1));
    c:=fr*(od1*(x2-x3)*(x1*x1*x1*(x2+x3)-x1*x1*(x2*x2+x2*x3+x3*x3)+x2*x2*x3*x3)+x1*(x1*x1*x1*(y2-y3)-3*x1*(x2*x2*(y1-y3)+x3*x3*(y2-y1))+2*(x2*x2*x2*(y1-y3)+x3*x3*x3*(y2-y1))));
    d:=-fr*(od1*x1*x2*x3*(x1*x1-x1*(x2+x3)+x2*x3)*(x2-x3)+x1*x1*x1*x1*(x3*y2-x2*y3)+2*x1*x1*x1*(x2*x2*y3-x3*x3*y2)-x1*x1*(x2*x2*x2*y3+3*x2*x2*x3*y1-3*x2*x3*x3*y1-x3*x3*x3*y2)+2*x1*x2*x3*y1*(x2+x3)*(x2-x3)-x2*x2*x3*x3*y1*(x2-x3));
(* For smooth second derivate, ignoring third  point:
    {
    SOLVE([a·x1^3 + b·x1*x1 + c·x1 + d = y1, a·x2^3 + b·x2^2 + c·x2 + d = y2, 3·a·x1·x1 + 2·b·x1 + c = od1, 6*a*x1+2*b=od2], [b, a, c, d])
    }
{    fr:=((x1*x1-2*x1*x3+x3*x3)*(x1*x1-2*x1*x2+x2*x2)*(x2-x3));
    if abs(fr)<DiagramEpsilon then exit;
    fr:=1/fr;}
    //TODO: optimize
    a := - 0.5*(2*od1*(x1 - x2) - od2*(x1*x1 - 2*x1*x2 + x2*x2) - 2*(y1 - y2))/(x1*x1*x1 - 3*x1*x1*x2 + 3*x1*x2*x2 - x2*x2*x2);
    b := 0.5*(6*od1*x1*(x1 - x2) - od2*(2*x1*x1*x1 - 3*x1*x1*x2 + x2*x2*x2) + 6*x1*(y2 - y1))/(x1*x1*x1 - 3*x1*x1*x2 + 3*x1*x2*x2 - x2*x2*x2);
    c := 0.5*(x1*(od2*(x1*x1*x1 - 3*x1*x2*x2 + 2*x2*x2*x2) + 6*x1*(y1 - y2)) - 2*od1*(2*x1*x1*x1 - 3*x1*x2*x2 + x2*x2*x2))/(x1*x1*x1 - 3*x1*x1*x2 + 3*x1*x2*x2 - x2*x2*x2);
    d := 0.5*(2*od1*x1*x2*(2*x1*x1 - 3*x1*x2 + x2*x2) - od2*x1*x1*x2*(x1*x1 - 2*x1*x2 + x2*x2) + 2*(x1*x1*x1*y2 - 3*x1*x1*x2*y1 + 3*x1*x2*x2*y1 - x2*x2*x2*y1))/(x1*x1*x1 - 3*x1*x1*x2 + 3*x1*x2*x2 - x2*x2*x2);*)
  end;
end;

function TDiagramDrawer.calcSpline(const spline: TDiagramSplinePiece;
  const x: float):float;
begin
  //result:=a*x*x*x+b*x*x+c*x+d;
  with spline do
    result:=((a*x+b)*x+c)*x+d;
end;

procedure TDiagramDrawer.doModified;
begin
  FLayoutModified:=true;
  if Assigned(FModifiedEvent) then FModifiedEvent(self);
end;

procedure TDiagramDrawer.SetAutoSetRangeX(const AValue: boolean);
begin
  if FAutoSetRangeX=AValue then exit;
  FAutoSetRangeX:=AValue;
  if assigned(fmodel) then fmodel.fmodified:=true;  //cause full update
  doModified;
end;

procedure TDiagramDrawer.SetAutoSetRangeY(const AValue: boolean);
begin
  if FAutoSetRangeY=AValue then exit;
  FAutoSetRangeY:=AValue;
  if assigned(fmodel) then fmodel.fmodified:=true;  //cause full update
  doModified;
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
  SetLength(FSplines,0);
  doModified;
end;

constructor TDiagramDrawer.create;
begin
  FLAxis:=TAxis.Create;
  FBAxis:=TAxis.Create;
  FLAxis.rangePolicy:=rpAuto;
  FBAxis.rangePolicy:=rpAuto;
  FBAxis.gridLinePen.Style:=psClear;
  FLAxis.gridLinePen.Color:=clGray;
  FBAxis.gridLinepen.Color:=clGray;
  FLAxis.linePen.Color:=clBlack;
  FBAxis.linepen.Color:=clBlack;
  FLAxis.Visible:=true;
  FBAxis.Visible:=true;

  FRAxis:=TAxis.create;
  FRAxis.gridLinePen.Style:=psClear;
  FRAxis.Visible:=false;
  FTAxis:=TAxis.create;
  FTAxis.gridLinePen.Style:=psClear;
  FTAxis.Visible:=false;
  FXMAxis:=TAxis.create;
  FXMAxis.gridLinePen.Style:=psClear;
  FXMAxis.Visible:=false;
  FYMAxis:=TAxis.create;
  FYMAxis.gridLinePen.Style:=psClear;
  FYMAxis.Visible:=false;
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
  fRangeMinX:=0;
  fRangeMaxX:=100;
  fRangeMinY:=0;
  fRangeMaxY:=100;
  FAutoSetRangeX:=true;
  FAutoSetRangeY:=true;
end;

destructor TDiagramDrawer.destroy;
begin
  FRAxis.free;
  FTAxis.free;
  FXMAxis.free;
  FYMAxis.free;
  FLAxis.free;
  FBAxis.free;
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
const AXIS_SIZE=20;
      AXIS_DASH_SIZE=2;
var xstart,ystart,xfactor,yfactor,xend,yend: float; //copied ranges
    textHeightC:longint;

  function translateX(const x:float):longint;inline;
  begin
    result:=FValueAreaX+round((x-xstart)*xfactor);
  end;
  function translateXBack(const x:longint):float;inline;
  begin
    result:=(x-FValueAreaX)/xfactor+xstart;
  end;
  function translateY(const y:float):longint;inline;
  begin
    result:=FValueAreaBottom-round((y-ystart)*yfactor);
  end;
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

  procedure drawCubicSpline(id:longint);
  var i,x,y:longint;
      fx,lx,nx: float;
  begin
    //see also calculateSplines, here the splines map P [x1-x1, x2-x1] |-> [y1, y2]
    getRPos(id,0,x,y);
    canvas.MoveTo(x,y);
    i:=0;
    lx:=FModel.dataX(id,0);
    nx:=FModel.dataX(id,i+1);
    for x:=translateX(FModel.minX(id)) to translateX(FModel.maxX(id)) do begin
      fx:=translateXBack(x);
      if fx>=nx then begin
        while fx>=nx do begin
          i+=1;
          if i>=FModel.dataPoints(id)-1 then exit;
          lx:=nx;
          nx:=FModel.dataX(id,i+1);
        end;
        if i>=FModel.dataPoints(id)-1 then break;
      end;
      canvas.LineTo(x,translateY(calcSpline(FSplines[id,i],fx-lx)));
    end;
  end;

  procedure drawCubicSpline3P(id:longint);
  var i,x,x1,y1:longint;
      fx0,fy0,fx1,fy1,fx2,fy2: float;
      spline: TDiagramSplinePiece;
  begin
    //see also lineYatX, here the splines map P [x1, x2] |-> [y1, y2]
    FModel.data(id,0,fx1,fy1);
    translate(fx1,fy1,x1,y1);
    canvas.MoveTo(x1,y1);
    FModel.data(id,1,fx2,fy2);
    FillChar(spline,sizeof(spline),0);
    updateSpline3P(spline,fx1-2*(fx2-fx1),fy1,fx1,fy1,fx2,fy2);
    for i:=1 to fModel.dataPoints(id)-1 do begin
      //next point
      fx0:=fx1;fy0:=fy1;
      fx1:=fx2;fy1:=fy2;
      FModel.data(id,i,fx2,fy2);
      updateSpline3P(spline,fx0,fy0,fx1,fy1,fx2,fy2);
      //draw spline
      for x:=translateX(fx0) to translateX(fx1) do
        canvas.LineTo(x,translateY(calcSpline(spline,translateXBack(x))));
        //canvas.LineTo(ox+x,translateY(calcSpline(spline,x/dw)));
    end;
    //last point with connection to virtual point far right
    updateSpline3P(spline,fx1,fy1,fx2,fy2,fx2+2*(fx2-fx1),fy2);
    //draw spline
    for x:=translateX(fx1) to translateX(fx2) do
      canvas.LineTo(x,translateY(calcSpline(spline,translateXBack(x))));
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

//----------------------------Axis drawing----------------------------
  procedure drawHorzAxis(axis: TAxis; posY: longint; textOverAxis: boolean);
  var p,res: float;
      caption, captionOld: string;
      pos:longint;
  begin
    captionOld:='';
    canvas.pen:=axis.linePen;
    canvas.MoveTo(FValueAreaX,posY);
    canvas.LineTo(FValueAreaRight,posY);
    res:=axis.resolution;
    if IsNan(res) or IsInfinite(res)or(res<=0) then
      res:=round((xend-xstart) / 10);
    p:=xstart;
    while p<=xend do begin
      caption:=axis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=FValueAreaX+round((p-xstart)*xfactor);
        if axis.gridLinePen.Style<>psClear then begin
          canvas.pen:=axis.gridLinePen;
          canvas.MoveTo(pos,FValueAreaY);
          canvas.LineTo(pos,FValueAreaBottom);
          canvas.pen:=axis.linePen;
        end;
        canvas.MoveTo(pos,posY-AXIS_DASH_SIZE);
        canvas.LineTo(pos,posY+AXIS_DASH_SIZE+1);
        if textOverAxis then
          canvas.TextOut(pos-canvas.textwidth(caption) div 2,posY-AXIS_DASH_SIZE-textHeightC-2,caption)
         else
          canvas.TextOut(pos-canvas.textwidth(caption) div 2,posY+AXIS_DASH_SIZE+2,caption);
      end;
      p+=res;
    end;
  end;

  procedure drawVertAxis(axis: TAxis; posX: longint; textLeftFromAxis: boolean);
  var p,res: float;
      caption, captionOld: string;
      pos:longint;
  begin
    captionOld:='';
    canvas.pen:=axis.linePen;
    canvas.MoveTo(posX,FValueAreaY);
    canvas.LineTo(posX,FValueAreaBottom);
    res:=axis.resolution;
    if IsNan(res) or IsInfinite(res)or(res<=0) then
      res:=round((xend-xstart) / 10);
    p:=ystart;
    while p<=yend do begin
      caption:=axis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        pos:=FValueAreaBottom-round((p-ystart)*yfactor);
        if axis.gridLinePen.Style<>psClear then begin
          canvas.pen:=axis.gridLinePen;
          canvas.MoveTo(fvalueAreaX,pos);
          canvas.LineTo(FValueAreaRight,pos);
          canvas.pen:=axis.linePen;
        end;
        canvas.MoveTo(posX-AXIS_DASH_SIZE,pos);
        canvas.LineTo(posX+AXIS_DASH_SIZE+1,pos);
        if textLeftFromAxis then
          canvas.TextOut(posX-AXIS_DASH_SIZE-2-canvas.textwidth(caption),pos-textHeightC div 2,caption)
         else
          canvas.TextOut(posX+AXIS_DASH_SIZE+2,pos-textHeightC div 2,caption);
      end;
      p+=res;
    end;
  end;

var i,j,pos,legendX:longint;

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
    for i:=0 to FModel.dataRows-1 do begin
      j:=result.Canvas.TextWidth(FModel.dataTitle(i));
      if j>legend.width then legend.width:=j;
    end;
    legend.width:=legend.width+20;
    legend.height:=(textHeightC+5)*FModel.dataRows()+5;
  end;
  //setup output area
  FValueAreaX:=3;
  FValueAreaY:=3;
  if FLAxis.Visible then FValueAreaX+=AXIS_SIZE;
  if FTAxis.Visible then FValueAreaY+=AXIS_SIZE;
  FValueAreaRight:=result.Width-3;
  FValueAreaBottom:=result.Height-3;
  if legend.visible then FValueAreaRight-=3+legend.width;
  if FBAxis.Visible then FValueAreaBottom-=AXIS_SIZE;
  if FRAxis.Visible then FValueAreaRight-=AXIS_SIZE;
  if (FLAxis.Visible or FRAxis.Visible) and not (FTAxis.Visible) then //don't truncate last text line
    FValueAreaY+=textHeightC div 2;
  if (FLAxis.Visible or FRAxis.Visible) and not (FBAxis.Visible) then
    FValueAreaBottom-=textHeightC div 2;

  FValueAreaWidth:=FValueAreaRight- FValueAreaX;
  FValueAreaHeight:=FValueAreaBottom-FValueAreaY;
  //setup ranges
  if FAutoSetRangeX then
    if fmodel.dataRows>0 then begin
      FRangeMinX:=fmodel.minX;
      FRangeMaxX:=fmodel.maxX;
      if FRangeMaxX<=FRangeMinX then FRangeMaxX:=FRangeMinX+5;
      if FLAxis.rangePolicy=rpAuto then FLAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
      if FYMAxis.rangePolicy=rpAuto then FYMAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
      if FRAxis.rangePolicy=rpAuto then FRAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
    end;
  if FAutoSetRangeY then
    if fmodel.dataRows>0 then begin
      FRangeMinY:=fmodel.minY;
      FRangeMaxY:=fmodel.maxY;
      if FRangeMaxY<=FRangeMinY then FRangeMaxY:=FRangeMinY+5;
      if FTAxis.rangePolicy=rpAuto then FTAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
      if FXMAxis.rangePolicy=rpAuto then FXMAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
      if FBAxis.rangePolicy=rpAuto then FBAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
    end;
  xstart:=RangeMinX;
  xend:=RangeMaxX;
  xfactor:=FValueAreaWidth / (xend-xstart);
  ystart:=RangeMinY;
  yend:=RangeMaxY;
  yfactor:=FValueAreaHeight / (yend-ystart);


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
    if FLAxis.Visible then drawVertAxis(FLAxis,fvalueAreaX,true);
    if FRAxis.Visible then drawVertAxis(FRAxis,FValueAreaRight,false);
    if FYMAxis.Visible then drawVertAxis(FYMAxis,fvalueAreaX+FValueAreaWidth div 2,false);

    if FTAxis.Visible then drawHorzAxis(FTAxis,fvalueAreaY,true);
    if FBAxis.Visible then drawHorzAxis(FBAxis,FValueAreaBottom,false);
    if FXMAxis.Visible then drawHorzAxis(FXMAxis,fvalueAreaY+FValueAreaHeight div 2,false);

    //Draw Values
    if (LineStyle=lsCubicSpline) and ((FModel.fmodified) or (length(FSplines)=0)) then
      calculateSplines();
    for i:=0 to FModel.dataRows-1 do begin
      if fModel.dataPoints(i)=0 then continue;
      FModel.setupCanvasForData(i,canvas);
      case LineStyle of
        lsLinear: drawLinearLines(i);
        lsCubicSpline: drawCubicSpline(i);
        lsLocalCubicSpline: drawCubicSpline3P(i);
      end;
      if PointStyle<>psNone then drawPoints(i);
    end;

    //fill values
    //TODO: problem, this overrides y-lines, this could run in dataLines*dataPoints*log dataPoints
    if filled then begin
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(result.Handle,0);
      fpbackcolor:=TColorToFPColor(dataBackColor);
      if FLAxis.gridLinePen.Style<>psClear then fplinecolor:=TColorToFPColor(FLAxis.gridLinePen.Color)
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
      legendX:=result.Width-legend.Width-3;
      Rectangle(legendX,(result.Height -legend.height) div 2,
                legendX+legend.width,(result.Height + legend.height) div 2);
      pos:=(result.Height -legend.height) div 2+5;
      for i:=0 to FModel.dataRows-1 do begin
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
  result:=(x-FValueAreaX)*(FRangeMaxX-FRangeMinX) / FValueAreaWidth + FRangeMinX;
end;

function TDiagramDrawer.posToDataY(y: longint): float;
begin
  if FValueAreaHeight=0 then exit(0);
  result:=(FValueAreaBottom- y)*(RangeMaxY-RangeMinY) / FValueAreaHeight + RangeMinY;
end;

function TDiagramDrawer.dataToPosX(const x: float): integer;
begin
  result:=round((x-RangeMinX)*FValueAreaWidth / (RangeMaxX-RangeMinX))+FValueAreaX;
end;

function TDiagramDrawer.dataToPosY(const y: float): integer;
begin
  result:=FValueAreaBottom-round((y-RangeMinY)*FValueAreaHeight / (RangeMaxY-RangeMinY));
end;

function TDiagramDrawer.pixelSizeX: float;
begin
  result:=abs((RangeMaxX-RangeMinX) / FValueAreaWidth);
end;

function TDiagramDrawer.pixelSizeY: float;
begin
  result:=abs((RangeMaxY-RangeMinY) / FValueAreaHeight);
end;

function TDiagramDrawer.lineYatX(i:longint; const x: float): float;
var j:longint;
    x0,y0,x1,y1,x2,y2: float;
    spline: TDiagramSplinePiece;
begin
  if not Assigned(FModel) then exit(nan);
  if FModel.dataPoints(i)=0 then exit(nan);
  if FModel.dataPoints(i)=1 then exit(FModel.dataY(i,0));
  if x<FModel.minX(i) then exit(FModel.dataY(i,0));
  if x>FModel.maxX(i) then exit(FModel.dataY(i,FModel.dataPoints(i)-1));
  case LineStyle of
    lsNone, lsLinear: begin
      FModel.data(i,0,x1,y1);
      for j:=1 to FModel.dataPoints(i)-1 do begin
        FModel.data(i,j,x2,y2);
        if (x>=x1) and  (x<=x2) then
          if abs(x1-x2)>DiagramEpsilon then exit((x-x1)*(y2-y1)/(x2-x1)+y1)
          else exit((y1+y2)/2); //better not really correct result than crash
        x1:=x2;y1:=y2;
      end;
    end;
    lsCubicSpline: begin
      FModel.data(i,0,x1,y1);
      for j:=1 to FModel.dataPoints(i)-1 do begin
        FModel.data(i,j,x2,y2);
        if (x>=x1) and  (x<=x2) then
          exit(calcSpline(FSplines[i,j-1],x-x1));
        x1:=x2;y1:=y2;
      end;
    end;
    lsLocalCubicSpline: begin
      FModel.data(i,0,x1,y1);
      FModel.data(i,1,x2,y2);
      FillChar(spline,sizeof(spline),0);
      updateSpline3P(spline,x1-2*(x2-x1),y1,x1,y1,x2,y2);
      for j:=1 to fModel.dataPoints(i)-1 do begin
        //next point
        x0:=x1;y0:=y1;
        x1:=x2;y1:=y2;
        FModel.data(i,j,x2,y2);
        updateSpline3P(spline,x0,y0,x1,y1,x2,y2);
        if (x>=x0) and (x<=x1) then
          exit(calcSpline(spline,x));
      end;
      //last point with connection to virtual point far right
      updateSpline3P(spline,x1,y1,x2,y2,x2+2*(x2-x1),y2);
      //draw spline
      if (x>=x1) and (x<=x2) then
        exit(calcSpline(spline,x));
    end;
  end;
  result:=nan;
end;

function TDiagramDrawer.findLine(const x, y: float; const ytolerance: float
  ): longint;
var i:longint;
    ly: float;
begin
  for i:=0 to FModel.dataRows-1 do begin
    if (x<FModel.minX(i)) or (x>FModel.maxX(i)) then continue;
    ly:=lineYatX(i,x);
    if isNan(ly) then continue;
    if abs(ly-y) <= ytolerance then exit(i);
  end;
  result:=-1;
end;

{ TAbstractDiagramModel }


procedure TAbstractDiagramModel.modified;
begin
  fmodified:=true;
  if assigned(fmodifiedEvent) then fmodifiedEvent(self);
end;

function TAbstractDiagramModel.dataRows: longint;
begin
  result:=1;
end;

function TAbstractDiagramModel.dataTitle(i: longint): string;
begin
  result:='data';
end;

procedure TAbstractDiagramModel.setupCanvasForData(i: longint; c: TCanvas);
begin
  ;
end;

function TAbstractDiagramModel.setData(i, j: longint; const x, y: float):integer;
begin
  result:=j;
end;

function TAbstractDiagramModel.addData(i: longint; const x, y: float): integer;
begin
  result:=-1;
end;

procedure TAbstractDiagramModel.removeData(i, j: longint);
begin
  ;
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

function TAbstractDiagramModel.getFlags: TModelFlags;
begin
  result:=[];
end;

function TAbstractDiagramModel.find(i: longint; const x: float;
  const y: float; const xtolerance: float; const ytolerance: float): longint;
var j:longint;
    px,py,ryt: float;
begin
  result:=-1;
  if IsNan(y) then begin
    for j:=0 to dataPoints(i)-1 do
      if abs(dataX(i,j)-x) <= xtolerance then exit(j);
  end else begin
    ryt:=ytolerance;
    if IsNan(ryt) then ryt:=xtolerance;
    for j:=0 to dataPoints(i)-1 do begin
      data(i,j,px,py);
      if (abs(px-x) <= xtolerance) and (abs(py-y) <= ytolerance) then exit(j);
    end;
  end;
end;

function TAbstractDiagramModel.findAndGet(i: longint; var x: float;
  var y: float; const xtolerance: float; const ytolerance: float): longint;
begin
  result:=find(i,x,y,xtolerance,ytolerance);
  if result<>-1 then data(i,result,x,y);
end;

function TAbstractDiagramModel.findWithRow(out i: longint; const x: float;
  const y: float; const xtolerance: float; const ytolerance: float): longint;
var j:longint;
begin
  result:=-1;
  for j:=0 to dataRows-1 do begin
    result:=find(j,x,y,xtolerance,ytolerance);
    if result<>-1 then begin
      i:=j;
      exit;
    end;
  end;
end;

function TAbstractDiagramModel.findWithRowAndGet(out i: longint; var x: float;
  var y: float; const xtolerance: float; const ytolerance: float): longint;
var j:longint;
begin
  result:=-1;
  for j:=0 to dataRows-1 do begin
    result:=findAndGet(j,x,y,xtolerance,ytolerance);
    if result<>-1 then begin
      i:=j;
      exit;
    end;
  end;
end;

function TAbstractDiagramModel.dataX(i, j: longint): float;
var t:float;
begin
  data(i,j,result,t);
end;

function TAbstractDiagramModel.dataY(i, j: longint): float;
var t:float;
begin
  data(i,j,t,result);
end;

function TAbstractDiagramModel.minX: float;
var i:longint;
begin
  result:=PInfinity;
  for i:=0 to dataRows-1 do
    result:=min(result,minX(i));
end;

function TAbstractDiagramModel.maxX: float;
var i:longint;
begin
  result:=MInfinity;
  for i:=0 to dataRows-1 do
    result:=max(result,maxX(i));
end;

function TAbstractDiagramModel.minY: float;
var i:longint;
begin
  result:=PInfinity;
  for i:=0 to dataRows-1 do
    result:=min(result,minY(i));
end;

function TAbstractDiagramModel.maxY: float;
var i:longint;
begin
  result:=MInfinity;
  for i:=0 to dataRows-1 do
    result:=max(result,maxY(i));
end;

{ TDiagramDataListModel }

function TDiagramDataListModel.getDataList(i:Integer): TDataList;
begin
  result:=TDataList(FLists[i]);
end;

function TDiagramDataListModel.GetFlags: TModelFlags;
begin
  result:=FFlags;
end;

procedure TDiagramDataListModel.SetFlags(const AValue: TModelFlags);
begin
  if FFlags=AValue then exit;
  FFlags:=AValue;
  modified;
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

procedure TDiagramDataListModel.setDataRows(c: longint);
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

function TDiagramDataListModel.dataRows: longint;
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
  if (i>=0) and (i<FLists.Count) then lists[i].point(j,x,y)
  else begin
    x:=nan;
    y:=nan;
  end;
end;

function TDiagramDataListModel.setData(i, j: longint; const x, y: float):integer;
begin
  if not (mfEditable in Flags) then exit;
  if (i<0) or (i>=FLists.Count) then exit;
  result:=lists[i].setPoint(j,x,y);
end;

function TDiagramDataListModel.addData(i: longint; const x, y: float): integer;
begin
  if not (mfEditable in Flags) then exit;
  if (i<0) or (i>=FLists.Count) then exit;
  result:=lists[i].addPoint(x,y);
end;

procedure TDiagramDataListModel.removeData(i, j: longint);
begin
  if not (mfEditable in Flags) then exit;
  if (i<0) or (i>=FLists.Count) then exit;
  lists[i].removePoint(j);
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

procedure TDiagramView.SetAllowedEditActions(const AValue: TDiagramEditActions
  );
begin
  if FAllowedEditActions=AValue then exit;
  FAllowedEditActions:=AValue;
  ;
end;

procedure TDiagramView.SetModel(const AValue: TAbstractDiagramModel);
begin
  SetModel(AValue,false);
end;

procedure TDiagramView.SetPointMovement(const AValue: TDiagramPointMovement);
begin
  if FPointMovement=AValue then exit;
  FPointMovement:=AValue;
end;

constructor TDiagramView.create(aowner:TComponent);
begin
  inherited;
  FDrawer:=TDiagramDrawer.create;
  FDrawer.Diagram.width:=Width;
  FDrawer.Diagram.height:=height;
  FDrawer.FLAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.FRAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.FTAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.FBAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.FXMAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.FYMAxis.FModifiedEvent:=@layoutChanged;
  FDrawer.legend.FModifiedEvent:=@layoutChanged;
  FDrawer.FModifiedEvent:=@layoutChanged;
  FSelPoint:=-1;
  FHighlightPoint.x:=NaN;
  FPointMovement:=pmAffectNeighbours;
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
  if not IsNan(FHighlightPoint.x) then begin
    canvas.Pen.Style:=psSolid;
    canvas.Brush.Style:=bsSolid;
    canvas.Pen.Color:=clBlue;
    canvas.Brush.Color:=clYellow;
    canvas.EllipseC(FDrawer.dataToPosX(FHighlightPoint.x),FDrawer.dataToPosY(FHighlightPoint.y),3,3);
  end;
  if FSelPoint<>-1 then begin
    canvas.Pen.Style:=psSolid;
    canvas.Brush.Style:=bsSolid;
    canvas.Pen.Color:=clRed;
    canvas.Brush.Color:=clYellow;
    canvas.EllipseC(FDrawer.dataToPosX(FModel.dataX(FSelRow,FSelPoint)),FDrawer.dataToPosY(FModel.dataY(FSelRow,FSelPoint)),3,3);
  end;

  FModel.fmodified:=false;
  FDrawer.FLayoutModified:=false;
end;

procedure TDiagramView.mouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var fx,fy:float;
    i:longint;
begin
  inherited mouseDown(Button, Shift, X, Y);
  if not assigned(FDrawer.FModel) then exit;
  if (mfEditable in FModel.getFlags) and ([eaMovePoints, eaDeletePoints]*FAllowedEditActions<>[]) then begin
    fX:=FDrawer.posToDataX(x);
    fY:=FDrawer.posToDataY(y);
    FSelPoint:=fmodel.findWithRow(FSelRow, fX,fY,2*FDrawer.PointSize*FDrawer.pixelSizeX,2*FDrawer.PointSize*FDrawer.pixelSizeY);
    FSelPointMoving:=FSelPoint<>-1;
    FHighlightPoint.x:=nan;
  end;
  if (eaAddPoints in FAllowedEditActions) and not FSelPointMoving then begin
    fX:=FDrawer.posToDataX(x);
    fY:=FDrawer.posToDataY(y);
    i:=fdrawer.findLine(fx,fy,10*FDrawer.PointSize*FDrawer.pixelSizeY);
    if i<>-1 then begin
      FSelRow:=i;
      FSelPoint:= FModel.addData(i,fx,fy);
      FSelPointMoving:=FSelPoint<>-1;
    end;
  end;
  if eaDeletePoints in FAllowedEditActions then SetFocus;
end;

procedure TDiagramView.mouseMove(Shift: TShiftState; X, Y: Integer);
var i,j:longint;
    fx,fy:float;
begin
  inherited mouseMove(Shift, X, Y);
  if not assigned(FModel) then exit;
  if FModel.dataRows=0 then exit;
  if (FSelPoint<>-1) and (FSelPointMoving) then begin
    //j:=fmodel.findAndGet(FSelRow, FSelPoint.X,FSelPoint.Y,2*FDrawer.PointSize*FDrawer.pixelSizeX,2*FDrawer.PointSize*FDrawer.pixelSizeY);
    {if j=-1 then begin
      FSelPoint:=nan;
      Repaint;
      exit;
    end;}
    j:=fmodel.setData(FSelRow,FSelPoint,FDrawer.posToDataX(X),FDrawer.posToDataY(Y));
    if PointMovement=pmAffectNeighbours then
      if j<FSelPoint then fmodel.setData(FSelRow,FSelPoint,FDrawer.posToDataX(X),FDrawer.posToDataY(Y))
      else if j>FSelPoint then fmodel.setData(FSelRow,FSelPoint,FDrawer.posToDataX(X),FDrawer.posToDataY(Y));
    FSelPoint:=j;
  end else if (mfEditable in FModel.getFlags) and ([eaMovePoints, eaDeletePoints]*FAllowedEditActions<>[]) then begin
    fX:=FDrawer.posToDataX(x);
    fY:=FDrawer.posToDataY(y);
    j:=fmodel.findWithRowAndGet(i, fX,fY,2*FDrawer.PointSize*FDrawer.pixelSizeX,2*FDrawer.PointSize*FDrawer.pixelSizeY);
    if IsNan(FHighlightPoint.x) and (j<>-1) then begin
      FHighlightPoint.x:=fx;
      FHighlightPoint.y:=fy;
      Repaint;
    end else if not IsNan(FHighlightPoint.x) and (j=-1) then begin
      FHighlightPoint.x:=NaN;
      Repaint;
    end;
  end;
end;

procedure TDiagramView.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FSelPointMoving:=false;
  if (FSelPoint<>-1) and not (eaDeletePoints in FAllowedEditActions) then begin
    FSelPoint:=-1;
    repaint;
  end;
  if not assigned(FDrawer.FModel) then exit;
end;

procedure TDiagramView.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
  if (key=VK_DELETE) and (eaDeletePoints in FAllowedEditActions) and (FSelPoint <>-1) and (assigned(fmodel)) then begin
     FModel.removeData(FSelRow,FSelPoint);
     if FSelPoint>=FModel.dataPoints(FSelRow) then FSelPoint:=FModel.dataPoints(FSelRow)-1;
  end;
end;

procedure TDiagramView.DoExit;
begin
  inherited DoExit;
  FSelPoint:=-1;
  FHighlightPoint.x:=nan;
  Repaint;
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

{ TDiagramFixedWidthCircularDataListModel }

function TDiagramFixedWidthCircularDataListModel.setData(i, j: longint;
  const x, y: float): integer;
begin
  if dataPoints(i)=0 then exit;
  if (j=0) or (j=dataPoints(i)-1) then begin
    inherited setData(i, 0, dataX(i,0), y);
    inherited setData(i,dataPoints(i)-1, dataX(i,dataPoints(i)-1), y);
    result:=j;
  end else result:=inherited setData(i, j, x, y);
end;

function TDiagramFixedWidthCircularDataListModel.addData(i: longint; const x,
  y: float): integer;
begin
  if x < minX(i) then exit(-1);
  if x > maxX(i) then exit(-1);
  Result:=inherited addData(i, x, y);
end;

procedure TDiagramFixedWidthCircularDataListModel.removeData(i, j: longint);
begin
  if (j=0) or (j=dataPoints(i)-1) then exit;
  inherited removeData(i, j);
end;

end.
