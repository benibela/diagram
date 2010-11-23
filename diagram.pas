unit diagram;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,math,FPimage,IntfGraphics,
  LCLType,LCLProc,LCLIntf;

type
  TAxis=class;
  TValueTranslateEvent=procedure (sender: TAxis; i: float; var translated: string) of object;

  { TLegend }

  //a*x^3+b*x^2+c*x+d
  TDiagramSplinePiece = record
    a,b,c,d: float;
  end;

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
    //** Background color
    property Color:TColor read FColor write SetColor;
    //** Determines if the size is automatically calculated
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
    //**choose a usable resolution for a given range/output
    //**this procedure tries to keep rmin+n*resolution in output coordinates constant
    procedure rangeChanged(const rmin,rmax:float; realSize: longint);
  published
    //**Pen used to draw grids line perpendicular to the axis
    property gridLinePen: TPen read FGridLinePen write SetGridLinePen;
    //**Color of the axis
    property linePen: TPen read FLinePen write SetLinePen;
    property min: float read Fmin write Setmin;
    property max: float read Fmax write Setmax;
    property resolution: float read Fresolution write Setresolution;
    property rangePolicy: TRangePolicy read FrangePolicy write SetrangePolicy;
    //**Function/Event to allow customizaiton of the axis labels
    property valueTranslate: TValueTranslateEvent read FvalueTranslate write SetvalueTranslate;
    property Visible:boolean read FVisible write SetVisible;
    //property ShowText:boolean read FShowText write SetShowText;
  end;
  TDataPoint=record
    x,y:float;
  end;

  const DiagramEpsilon=1e-15;
type
  TModelFlag=(mfEditable);
  TModelFlags=set of TModelFlag;
  TModelRowFlag=(rfFullX, rfFullY); //**< full flags draw lines across the plot
  TModelRowFlags=set of TModelRowFlag;
  //**lsDefault=lsNone in drawer setting, otherwise (in model settings) it means "use drawer setting"
  //**lsNone=no lines, lsLinear=the points are connected with straight lines
  //**lsCubicSpline=the points are connected with a normal cubic spline (needing O(n) additional memory)
  //**lsLocalCubicSpline=the points are connected with a pseudo cubic spline (needing no additional memory, but looks not so nicely)
  TLineStyle=(lsDefault, lsNone, lsLinear, lsCubicSpline, lsLocalCubicSpline);
  TPointStyle = (psDefault, psNone, psPixel, psCircle, psRectangle, psPlus, psCross);
  TDiagramFillStyle = (fsNone, fsLastOverFirst, fsMinOverMax); //**<controls if the space under a line is filled. fsLastOverFirst fills one row after one, fsMinOverMax draw each x-position separately
  TFillGradientFlags = set of (fgGradientX, fgGradientY); //**< controls the color gradient for filling. Notice that fgGradientY is much slower since it switch to single pixel drawing (but fgGradientX makes no difference)

  { TAbstractDiagramModel }

  {** This is the abstract model class which stores the data to be shown
      If you want full customization you can use it as base class, but in most cases a TDiagramDataListModel is easier
  }
  TAbstractDiagramModel = class(TPersistent)
  private
    FOnModified: TNotifyEvent;
    FSplines: array of array of TDiagramSplinePiece; //**stores a spline interpolation of the data (only if necessary)
    FmodifiedSinceSplineCalc: longint; //0: not modified, 1: modified since calculateSplines(<>lsCubicSpline), 2: modified since calculateSplines(lsCubicSpline)
    FDestroyEvents,fmodifiedEvents: TMethodList;

    procedure calculateSplines(defaultLineStyle: TLineStyle); //**< calculates the splines if needed (O(n) memory)
    procedure SetOnModified(const AValue: TNotifyEvent);
  protected
    procedure doModified(row:longint=-1); //**<Call when ever the model data has been changed (give row=-1 if all rows are modified) (it especially important with cubic splines, because they aren't calculated if doModified isn't called)
  public
    constructor create;
    destructor destroy;override;

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

    //**returns the minimum x (default first data point, O(1))
    function minX(i:longint):float; virtual;
    //**returns the maximum x (default last data point, O(1))
    function maxX(i:longint):float; virtual;
    //**returns the minimum value (default scans all values, O(n))
    function minY(i:longint):float; virtual;
    //**returns the maximum value (default scans all values, O(n))
    function maxY(i:longint):float; virtual;

    function getFlags: TModelFlags; virtual;//**<returns model flags (e.g. editable)
    function getRowFlags(i:longint): TModelRowFlags; virtual; //**<returns flags for a given row
    function getRowLineStyle(i:longint):TLineStyle; virtual; //**<overrides drawer line style
    function getRowPointStyle(i:longint):TPointStyle; virtual; //**<overrides drawer line style

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

    //**this returns the position of the interpolation line (linear/cubic) in data coordinates
    function lineApproximationAtX(const defaultLineStyle:TLineStyle; i:longint; const x: float): float;
    //**finds a line like find. (since the line is 1-dimensional the x coordinate is not sufficient and has to be exact)
    function findLineApproximation(const defaultLineStyle:TLineStyle; const x,y:float; const ytolerance: float=DiagramEpsilon): longint;

    procedure addModifiedHandler(event: TNotifyEvent);
    procedure removeModifiedHandler(event: TNotifyEvent);
    procedure addDestroyHandler(event: TNotifyEvent);
    procedure removeDestroyHandler(event: TNotifyEvent);
    property OnModified:TNotifyEvent read FOnModified write SetOnModified;
  end;


  { TDiagramDrawer }
  TClipValues = set of (cvX, cvY);
  //**This class draws the data model into a TBitmap
  TDiagramDrawer = class(TPersistent)
  private
    FAutoSetRangeX: boolean;
    FAutoSetRangeY: boolean;
    FBackColor: TColor;
    FClipValues: TClipValues;
    FDataBackColor: TColor;
    FFillGradient: TFillGradientFlags;
    FLayoutModified: Boolean;
    FLineStyle: TLineStyle;
    FModifiedEvent: TNotifyEvent;
    FFillStyle: TDiagramFillStyle;
    Flegend: TLegend;
    FModel: TAbstractDiagramModel;
    FModelModified: boolean; //don't use fmodel.modified => problem with multiple views (but drawer:1<->1:view)
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
    procedure SetClipValues(const AValue: TClipValues);
    procedure SetDataBackColor(const AValue: TColor);
    procedure SetFillGradient(const AValue: TFillGradientFlags);
    procedure SetFillStyle(const AValue: TDiagramFillStyle);
    procedure SetLineStyle(const AValue: TLineStyle);
    procedure SetModel(AValue: TAbstractDiagramModel);overload;
    procedure SetPointSize(const AValue: longint);
    procedure SetPointStyle(const AValue: TPointStyle);
    procedure SetRangeMaxX(const AValue: float);
    procedure SetRangeMaxY(const AValue: float);
    procedure SetRangeMinX(const AValue: float);
    procedure SetRangeMinY(const AValue: float);
  public
    constructor create;
    function update(): TBitmap; //**<Redraws the bitmap and returns it (and updates the Diagram property)
    destructor destroy;override;

    //**Sets the model to be drawn, if takeOwnership is true, then the model is freed automatically by the drawer, otherwise you have to free it yourself
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean);overload;


    function posToDataX(x: longint): float; //**<Translate a pixel position in the bitmap to the coordinates used by the model
    function posToDataY(y: longint): float; //**<Translate a pixel position in the bitmap to the coordinates used by the model
    function dataToPosX(const x: float): integer; //**<Translate model coordinates to the corresponding pixel in the bitmap (rounds)
    function dataToPosY(const y: float): integer; //**<Translate model coordinates to the corresponding pixel in the bitmap (rounds)
    function pixelSizeX: float; //**< Returns the width of one output pixel in data coordinates
    function pixelSizeY: float; //**< Returns the height of one output pixel in data coordinates

    property Diagram: TBitmap read FDiagram; //**<Last drawn bitmap

    property valueAreaX: longint read fvalueAreaX;
    property ValueAreaY: longint read fvalueAreaY;
    property ValueAreaWidth: longint read FValueAreaWidth;
    property ValueAreaHeight: longint read FValueAreaHeight;
    property ValueAreaRight: longint read FValueAreaRight;
    property ValueAreaBottom: longint read FValueAreaBottom;
  published
    property RangeMinX: float read FRangeMinX write SetRangeMinX;
    property RangeMaxX: float read FRangeMaxX write SetRangeMaxX;
    property RangeMinY: float read FRangeMinY write SetRangeMinY;
    property RangeMaxY: float read FRangeMaxY write SetRangeMaxY;
    property AutoSetRangeX: boolean read FAutoSetRangeX write SetAutoSetRangeX;
    property AutoSetRangeY: boolean read FAutoSetRangeY write SetAutoSetRangeY;
    property legend:TLegend read Flegend; //**< Class for legend settings
    property LeftAxis: TAxis read FLAxis; //**< Axis left from the value area
    property RightAxis: TAxis read FRAxis; //**< Axis right to the value area
    property TopAxis: TAxis read FTAxis; //**< Axis over the value area
    property BottomAxis: TAxis read FBAxis; //**< Axis below the value area
    property HorzMidAxis: TAxis read FXMAxis; //**< Axis from the left to the right side in the vertical mid of the value area (like the x-axis in an plot)
    property VertMidAxis: TAxis read FYMAxis; //**< Axis from the top to the bottom side in the horizontal mid of the value area (like the x-axis in an plot)
    property LineStyle: TLineStyle read FLineStyle write SetLineStyle; //**< Line style used to draw the lines (can be overridden by the model)
    property PointStyle: TPointStyle read FPointStyle write SetPointStyle; //**< Point style used to draw points (can be overridden by the model)
    property PointSize: longint read FPointSize write SetPointSize;
    property FillGradient: TFillGradientFlags read FFillGradient write SetFillGradient ;
    property FillStyle: TDiagramFillStyle read FFillStyle write SetFillStyle;
    property Model: TAbstractDiagramModel read FModel write SetModel;
    property BackColor: TColor read FBackColor write SetBackColor; //**<Background color around the value area
    property DataBackColor: TColor read FDataBackColor write SetDataBackColor; //**<Background color of the value area
    property ClipValues: TClipValues read FClipValues write SetClipValues;
  end;


  { TDiagramView }
  TDiagramPointMovement=(pmSimple, pmAffectNeighbours);
  TDiagramEditAction=(eaMovePoints, eaAddPoints, eaDeletePoints);
  TDiagramEditActions=set of TDiagramEditAction;
  //**This class shows a model and allows the user to interact with it
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
    procedure modelDestroyed(sender:Tobject);
    procedure layoutChanged(sender:Tobject);
    procedure DoOnResize;override;
    procedure SetAllowedEditActions(const AValue: TDiagramEditActions);
    procedure SetModel(const AValue: TAbstractDiagramModel);
    procedure SetPointMovement(const AValue: TDiagramPointMovement);
  public
    constructor create(aowner:TComponent);override;
    destructor destroy;override;
    //**Sets the model, if takeOwnership is true, the model will automatically be freed if the view is freed
    procedure SetModel(amodel: TAbstractDiagramModel; takeOwnership: boolean=false);
    procedure paint;override;
    procedure MouseDown(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer);override;
    procedure MouseUp(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure DoExit; override;
  published
    //**Drawer drawing the diagram, use it to read/set everything relating to the visual output
    property Drawer: TDiagramDrawer read FDrawer;
    //**Specifies how points are moved
    property PointMovement: TDiagramPointMovement read FPointMovement write SetPointMovement;
    //**Controls how the model can be modified
    property AllowedEditActions: TDiagramEditActions read FAllowedEditActions write SetAllowedEditActions;
    //**The model assigned to this view
    property Model: TAbstractDiagramModel read FModel write SetModel;

    property OnAlignInsertBefore;
    property OnAlignPosition;
    property OnDockDrop;
    property OnDockOver;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnUnDock;
    property OnUTF8KeyPress;

    property OnConstrainedResize;
    property OnContextPopup;
    property OnDblClick;
    property OnTripleClick;
    property OnQuadClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnStartDock;
    property OnStartDrag;
  end;

  { TDataList }

  TDataList=class(TPersistent)
  private
    FLineStyle: TLineStyle;
    FPointStyle: TPointStyle;
    FRowNumber: longint;
    FColor: TColor;
    FFlags: TModelRowFlags;
    Ftitle: string;
    procedure DoModified;
    procedure SetColor(const AValue: TColor);
    procedure SetFlags(const AValue: TModelRowFlags);
    procedure SetLineStyle(const AValue: TLineStyle);
    procedure SetPointStyle(const AValue: TPointStyle);
    procedure SetTitle(const AValue: string);
  protected
    maxX,minX,maxY,minY:float;
    owner: TAbstractDiagramModel;
    points: array of TDataPoint;
    pointCount: longint;
    //lastRead: longint; //**<last point returned by nextX (needed for O(1) index lookup)
    procedure rescanYBorder;
    function resortPoint(i:longint):integer;
  public
    constructor create(aowner:TAbstractDiagramModel; aRowNumber: longint; acolor: TColor);
    procedure assign(list:TDataList); //**<assign another list, including colors, etc. (only the owner is excluded)
    procedure assign(list:TPersistent);override;
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

    //xxreads the points from a string by calling sscanf multiple times
    //procedure scanFStr(const s,format:string);

    procedure point(i:longint; out x,y: float); //**<returns the data at position i
  published
    property Color:TColor read FColor write SetColor;
    property Title:string read Ftitle write Settitle;
    property Flags:TModelRowFlags read FFlags write SetFlags;
    property LineStyle: TLineStyle read FLineStyle write SetLineStyle;
    property PointStyle: TPointStyle read FPointStyle write SetPointStyle;
  end;

  { TDiagramDataListModel }

  TDiagramDataListModel = class (TAbstractDiagramModel)
  private
    FFlags: TModelFlags;
    FLists: TFPList;
    function getDataList(i:Integer): TDataList;
    procedure SetFlags(const AValue: TModelFlags);
  public
    constructor create;
    destructor destroy;override;

    //**delete all lists
    procedure deleteLists;virtual;

    //**Set the count of data lists
    procedure setDataRows(c:longint);
    procedure deleteDataRow(i: longint);
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

    function GetFlags: TModelFlags;override;
    function getRowFlags(i:longint): TModelRowFlags; override;
    function getRowLineStyle(i:longint):TLineStyle; override;
    function getRowPointStyle(i:longint):TPointStyle; override;

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

  { TDiagramModelMerger }
  //**This model merges several models together, so they can be drawn at the same time
  //**It can also hide certain rows
  TDiagramModelMerger = class(TAbstractDiagramModel)
  private
    FBaseModel: integer;
    FHideCertainRows: boolean;
    FRowVisible: array of boolean;
    fmodels: TFPList;
    ownerShipModels: TFPList;
    function GetModel(i: longint): TAbstractDiagramModel;
    function rowToRealRow(i:longint; out m, r: longint):boolean;
    function GetRowVisible(i: integer): boolean;
    procedure SetBaseModel(const AValue: integer);
    procedure SetHideCertainRows(const AValue: boolean);
    procedure SetModel(i: longint; const AValue: TAbstractDiagramModel);
    procedure SetRowVisible(i: integer; const AValue: boolean);
    procedure subModelModified(sender: TObject);
    procedure subModelDestroyed(sender: TObject);
  public
    //**adds a model to the model list (if takeOwnership is true, this model is automatically freed in the destructor)
    procedure addModel(model: TAbstractDiagramModel; takeOwnership: boolean=false);
    //**removes an model from the list and adds a new one at this position (or at the end if oldModel don't exist)
    procedure replaceModel(oldModel, newModel: TAbstractDiagramModel; takeOwnership: boolean=false);
    //**removes a certain model (and frees it, if takeOwnership was true)
    procedure removeModel(model:TAbstractDiagramModel);
    //**removes all models (and frees them, if takeOwnership was true)
    procedure removeAllModels();
    //**Deletes a model
    procedure deleteModel(i:longint);
    //**Sets a model
    procedure SetModel(i: longint; const AValue: TAbstractDiagramModel; takeOwnerShip: boolean=false);

    property Models[i:longint]: TAbstractDiagramModel read GetModel write SetModel;

    constructor create;
    constructor create(model: TAbstractDiagramModel; takeOwnership: boolean=false);
    constructor create(model1, model2: TAbstractDiagramModel; takeOwnership1:boolean=false; takeOwnership2: boolean=false);
    destructor destroy;override;

    //overriden model functions
    function dataRows: longint; override;
    function dataTitle(i:longint):string; override;
    procedure setupCanvasForData(i:longint; c: TCanvas); override;
    function dataPoints(i:longint):longint; override;
    procedure data(i,j:longint; out x,y:float); override;
    function setData(i,j:longint; const x,y:float):integer;override;
    function addData(i:longint; const x,y:float):integer;override;
    procedure removeData(i,j:longint);override;

    function minX(i:longint):float; override;
    function maxX(i:longint):float; override;
    function minY(i:longint):float; override;
    function maxY(i:longint):float; override;

    function getFlags: TModelFlags; override;//**<returns model flags (e.g. editable)
    function getRowFlags(i:longint): TModelRowFlags; override; //**<returns flags for a given row
    function getRowLineStyle(i:longint):TLineStyle; override; //**<overrides drawer line style
    function getRowPointStyle(i:longint):TPointStyle; override; //**<overrides drawer line style

    //**This controls if there are invisible rows. Set it to false to make all rows visible
    property HideCertainRows: boolean read FHideCertainRows write SetHideCertainRows;
    //**If RowVisibleAt[i] is false, the row with number i is hidden
    //**Notice that this don't track rows, e.g. if you have one hidden row and remove this one, the row with its number (= the next row, after the deleted one) will be hidden
    //**Setting it to false for one (existing) index, sets HideCertainRows to true
    //**And hidden rows seems to be completely removed from this model, so if row 0 is hidden, data(0,...) returns the data for row 1 (of course only if row 1 isn't hidden) (the sub models this model is based on aren't effected at all)
    property RowVisibleAt[i:integer]: boolean read GetRowVisible write SetRowVisible;

    //**Model used for row independent properies (e.g. model flags)
    property BaseModel: integer read FBaseModel write SetBaseModel;
  end;
implementation
{  Math helper functions  }
const PInfinity=Infinity;
      MInfinity=NegInfinity;

function calcSpline(const spline:TDiagramSplinePiece; const x:float):float;
begin
  //result:=a*x*x*x+b*x*x+c*x+d;
  with spline do
    result:=((a*x+b)*x+c)*x+d;
end;

procedure updateSpline3P(var spline: TDiagramSplinePiece;
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
    //TODO: optimize/make human readable
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

//faster than byte versions
procedure RedGreenBlue(rgb: TColor; out Red, Green, Blue: integer);
begin
  Red := rgb and $000000ff;
  Green := (rgb shr 8) and $000000ff;
  Blue := (rgb shr 16) and $000000ff;
end;

function RGBToColor(R, G, B: integer): TColor;
begin
  Result := (B shl 16) or (G shl 8) or R;
end;


{  Axis }

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
    if IsInfinite(rmin) or IsInfinite(rmax) or IsNan(rmin) or IsNan(rmax) or (realSize=0) then begin
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

procedure TDataList.Settitle(const AValue: string);
begin
  if Ftitle=AValue then exit;
  Ftitle:=AValue;
  doModified;
end;

procedure TDataList.DoModified;
begin
  if Assigned(owner) then owner.doModified(FRowNumber);
end;

procedure TDataList.SetColor(const AValue: TColor);
begin
  if FColor=AValue then exit;
  FColor:=AValue;
  doModified;
end;

procedure TDataList.SetFlags(const AValue: TModelRowFlags);
begin
  if FFlags=AValue then exit;
  FFlags:=AValue;
  DoModified;
end;

procedure TDataList.SetLineStyle(const AValue: TLineStyle);
begin
  if FLineStyle=AValue then exit;
  FLineStyle:=AValue;
  DoModified;
end;

procedure TDataList.SetPointStyle(const AValue: TPointStyle);
begin
  if FPointStyle=AValue then exit;
  FPointStyle:=AValue;
  DoModified;
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

constructor TDataList.create(aowner: TAbstractDiagramModel; aRowNumber: longint;acolor: TColor);
begin
  FRowNumber:=aRowNumber;
  owner:=aowner;
  fcolor:=acolor;
  maxX:=MInfinity;
  minX:=PInfinity;
  maxY:=MInfinity;
  minY:=PInfinity;
  ftitle:='data row';
end;

procedure TDataList.assign(list: TDataList);
begin
  color:=list.color;
  title:=list.title;
  points:=list.points;
  Setlength(points,length(points));//copy
  pointCount:=list.pointCount;
  MaxX:=list.maxX;
  minX:=list.minX;
  maxY:=list.maxY;
  minY:=list.minY;
  if assigned(owner) then owner.doModified(FRowNumber);
end;

procedure TDataList.assign(list: TPersistent);
begin
  if list is tdatalist then assign(TDataList(list))
  else inherited assign(list);
end;

procedure TDataList.clear(keepMemory: boolean=false);
begin
  if not keepMemory then setlength(points,0);
  pointCount:=0;
  maxX:=MInfinity;
  minX:=PInfinity;
  maxY:=MInfinity;
  minY:=PInfinity;
  if assigned(owner) then owner.doModified(FRowNumber);
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
    if assigned(owner) then owner.doModified(FRowNumber);
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
          if assigned(owner) then owner.doModified(FRowNumber);
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
  if assigned(owner) then owner.doModified(FRowNumber);
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
  if (j<0) then exit;
  if (j>=pointCount) then begin
    addPoint(x,y);
    exit;
  end;
  wasBorder:=(points[j].y<=minY) or (points[j].y>=maxY);
  points[j].x:=x;
  points[j].y:=y;
  if wasBorder then rescanYBorder;
  result:=resortPoint(j);
  if assigned(owner) then owner.doModified(FRowNumber);
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
    if assigned(owner) then owner.doModified(FRowNumber);
    exit;
  end;
  wasBorder:=(points[j].y<=minY) or (points[j].y>=maxY);
  move(points[j+1],points[j],sizeof(points[j])*(pointCount-j-1));
  pointCount-=1;
  if j=0 then minX:=points[0].x;
  if wasBorder then rescanYBorder;
  if assigned(owner) then owner.doModified(FRowNumber);
end;
 {
procedure TDataList.scanFStr(const s, format: string);
var c:string;
  len: integer;
  x,y:float;
begin
  clear();
  c:=s;
  while true do begin
    len:=SScanf(c,format,[@x,@y]);
    if len=0
end;
}
//==================================================================================

procedure TDiagramDrawer.SetModel(AValue: TAbstractDiagramModel);
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

procedure TDiagramDrawer.doModified;
begin
  FLayoutModified:=true;
  if Assigned(FModifiedEvent) then FModifiedEvent(self);
end;

procedure TDiagramDrawer.SetAutoSetRangeX(const AValue: boolean);
begin
  if FAutoSetRangeX=AValue then exit;
  FAutoSetRangeX:=AValue;
  if assigned(fmodel) then fmodelModified:=true;  //cause full update
  doModified;
end;

procedure TDiagramDrawer.SetAutoSetRangeY(const AValue: boolean);
begin
  if FAutoSetRangeY=AValue then exit;
  FAutoSetRangeY:=AValue;
  if assigned(fmodel) then fmodelModified:=true;  //cause full update
  doModified;
end;


procedure TDiagramDrawer.SetBackColor(const AValue: TColor);
begin
  if FBackColor=AValue then exit;
  FBackColor:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetClipValues(const AValue: TClipValues);
begin
  if FClipValues=AValue then exit;
  FClipValues:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetDataBackColor(const AValue: TColor);
begin
  if FDataBackColor=AValue then exit;
  FDataBackColor:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetFillGradient(const AValue: TFillGradientFlags);
begin
  if FFillGradient=AValue then exit;
  FFillGradient:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetFillStyle(const AValue: TDiagramFillStyle);
begin
  if FFillStyle=AValue then exit;
  FFillStyle:=AValue;
  doModified;
end;

procedure TDiagramDrawer.SetLineStyle(const AValue: TLineStyle);
begin
  if FLineStyle=AValue then exit;
  FLineStyle:=AValue;
  if assigned(FModel) then FModel.calculateSplines(LineStyle);
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
  fvalueAreaX:=0;
  FValueAreaY:=0;
  FValueAreaWidth:=fdiagram.width;
  FValueAreaRight:=fdiagram.width;
  FValueAreaHeight:=fdiagram.height;
  FValueAreaBottom:=fdiagram.height;
  FFillGradient:=[fgGradientX];
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
    RealValueRect: TRect;
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
      if x>RealValueRect.Right then break;
    end;
  end;

  procedure drawCubicSpline(id:longint);
  var i,x,y,xmax:longint;
      fx,lx,nx: float;
  begin
    //see also calculateSplines, here the splines map P [x1-x1, x2-x1] |-> [y1, y2]
    if (length(fmodel.FSplines) <= id) or (length(fmodel.FSplines[id])<fmodel.dataPoints(id)) then
      exit; //wtf
    getRPos(id,0,x,y);
    canvas.MoveTo(x,y);
    i:=0;
    lx:=FModel.dataX(id,0);
    if FModel.dataPoints(id)>1 then nx:=FModel.dataX(id,1)
    else nx:=lx+10;
    x:=translateX(FModel.minX(id));
    if x<RealValueRect.Left then x:=RealValueRect.Left;
    xmax:=translateX(FModel.maxX(id));
    if xmax>RealValueRect.Right then xmax:=RealValueRect.Right;
    for x:=x to xmax do begin
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
      canvas.LineTo(x,translateY(calcSpline(fmodel.FSplines[id,i],fx-lx)));
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
      x:=translateX(fx0);
      if x>RealValueRect.Right then exit;
      for x:=x to translateX(fx1) do
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
      ps:TPointStyle;
  begin
    ps:=FModel.getRowPointStyle(id);
    if ps=psDefault then ps:=PointStyle;
    for i:=0 to fModel.dataPoints(id)-1 do begin
      getRPos(id,i,x,y);
      if rfFullX in FModel.getRowFlags(id) then
        canvas.Line(fvalueAreaX,y,FValueAreaRight,y);
      if rfFullY in FModel.getRowFlags(id) then
        canvas.Line(x,fvalueAreaY,x,FValueAreaBottom);
      case ps of
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
      if x>RealValueRect.Right then exit;
    end;
  end;

//----------------------------filling drawing----------------------------
  function scaleXGC(color,xpos,xmid:integer): integer;inline; //color gradient X
  begin
    result:=color-abs(color*2*(xpos-xmid)div (3*xmid));
  end;
  function scaleYGC(color,ypos,yvalue:integer): integer;inline;//color gradient Y
  begin
    result:=(color-color div 4)*(FValueAreaBottom-ypos)div (FValueAreaBottom-yvalue)+color div 4;
  end;
  procedure assignLazImageAndFree(lazImage: TLazIntfImage);
  var bitmap,tempmaskbitmap: HBITMAP;
  begin
    lazImage.CreateBitmaps(bitmap,tempmaskbitmap,true);
    result.Handle:=bitmap;
    result.canvas.clipping:=FClipValues<>[];
    if result.canvas.clipping then begin
      result.canvas.ClipRect:=RealValueRect;
      IntersectClipRect(result.canvas.Handle,RealValueRect.Left,RealValueRect.top,RealValueRect.Right,RealValueRect.Bottom);
    end;
    lazImage.Free;
  end;

//TODO: filling to zero line instead of bottom
//TODO: not always clip
  procedure drawFillingLastOverFirst();
  var i,x,xmax,xmid,y,yi: LongInt;
      startColor: TColor;
      RStart, GStart, BStart: integer;
      tempLazImage:TLazIntfImage;
  begin
    if fgGradientY in FFillGradient then begin
      //canvas.gradientfill is too slow since the rect change on every x
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(result.Handle,0);
    end;
    for i:=0 to FModel.dataRows-1 do begin
      if fModel.dataPoints(i)=0 then continue;
      if FModel.getRowLineStyle(i)=lsNone then continue;
      if (LineStyle=lsNone) and (FModel.getRowLineStyle(i)=lsDefault) then continue;

      FModel.setupCanvasForData(i,canvas);
      startColor:=canvas.pen.color;
      if FFillGradient<>[] then begin
        RedGreenBlue(startColor,RStart,GStart,BStart);
        if fgGradientY in FFillGradient then begin //use fp color
          RStart:=RStart + RStart shl 8;
          GStart:=GStart + GStart shl 8;
          BStart:=BStart + BStart shl 8;
        end;
      end;
      xmax:=translateX(FModel.maxX(i));
      if xmax>FValueAreaRight then xmax:=FValueAreaRight;
      x:=translateX(FModel.minX(i));
      if x<fvalueAreaX then x:=fvalueAreaX;
      xmid:=(x+xmax) div 2;

      for x:=x to xmax do begin
        y:=translateY(fmodel.lineApproximationAtX(LineStyle,i,translateXBack(x)));
        if fgGradientY in FFillGradient then begin
          if y<RealValueRect.top then y:=RealValueRect.Top;
          if fgGradientX in FFillGradient then begin
            for yi:=y to FValueAreaBottom-1 do
              tempLazImage[x,yi]:=FPColor(scaleYGC(scaleXGC(RStart,x,xmid),yi,y),
                                          scaleYGC(scaleXGC(GStart,x,xmid),yi,y),
                                          scaleYGC(scaleXGC(BStart,x,xmid),yi,y));
          end else for yi:=y to FValueAreaBottom-1 do
            tempLazImage[x,yi]:=FPColor(scaleYGC(RStart,yi,y),scaleYGC(GStart,yi,y),scaleYGC(BStart,yi,y));
        end else begin
          if fgGradientX in FFillGradient then
            canvas.pen.color:=RGBToColor(scaleXGC(RStart,x,xmid),scaleXGC(GStart,x,xmid),scaleXGC(BStart,x,xmid));
          canvas.Line(x,y,x,FValueAreaBottom);
        end;
      end;
    end;

    if fgGradientY in FFillGradient then
      assignLazImageAndFree(tempLazImage);
  end;

  procedure drawFillingMinOverMax();
  var i,j,r,k,x,temp,y,yi: LongInt;
      fx:float;
      tempY,tempYMap,tempMaxX,tempMinX:array of longint;
      xmid, RStart, GStart, BStart: array of longint; //needed for gradient
      tempLazImage:TLazIntfImage;
  begin
    if fgGradientY in FFillGradient then begin
      //canvas.gradientfill is too slow since the rect change on every x
      tempLazImage:=TLazIntfImage.Create(0,0);
      tempLazImage.LoadFromBitmap(result.Handle,0);
    end;

    setlength(tempY, fmodel.dataRows+1);
    setlength(tempYMap, fmodel.dataRows+1);
    setlength(tempMinX, fmodel.dataRows);
    setlength(tempMaxX, fmodel.dataRows);
    if FFillGradient<>[] then begin
      setlength(xmid, fmodel.dataRows);
      setlength(RStart, fmodel.dataRows);
      setlength(GStart, fmodel.dataRows);
      setlength(BStart, fmodel.dataRows);
    end;
    for i:=0 to FModel.dataRows-1 do begin
      if fModel.dataPoints(i)=0 then continue;
      tempMinX[i]:=translateX(fmodel.minX(i));
      tempMaxX[i]:=translateX(fmodel.maxX(i));
      FModel.setupCanvasForData(i,canvas);
      if FFillGradient<>[] then begin
        xmid[i]:=(tempMinX[i] + tempMaxX[i]) div 2;
        RedGreenBlue(canvas.pen.color,RStart[i],GStart[i],BStart[i]);
        if fgGradientY in FFillGradient then begin //use fp color
          RStart[i]:=RStart[i] + RStart[i] shl 8;
          GStart[i]:=GStart[i] + GStart[i] shl 8;
          BStart[i]:=BStart[i] + BStart[i] shl 8;
        end;
      end;
    end;
    for x:=fvalueAreaX to FValueAreaRight do begin
      j:=0;
      fx:=translateXBack(x);
      for i:=0 to FModel.dataRows do begin
        if fModel.dataPoints(i)=0 then continue;
        if FModel.getRowLineStyle(i)=lsNone then continue;
        if (LineStyle=lsNone) and (FModel.getRowLineStyle(i)=lsDefault) then continue;
        if (x < tempMinX[i]) or (x>tempMaxX[i]) then continue;
        tempY[j]:=translateY(fmodel.lineApproximationAtX(LineStyle,i,fx));
        tempYMap[j]:=i;
        k:=j;
        while (k >0) and (tempY[k-1]>tempY[k]) do begin
          temp:=tempY[k-1];tempY[k-1]:=tempY[k];tempY[k]:=temp;
          temp:=tempYMap[k-1];tempYMap[k-1]:=tempYMap[k];tempYMap[k]:=temp;
          k-=1;
        end;
        j+=1;
      end;
      if j=0 then continue;
      {if tempY[j-1]<FValueAreaBottom then }tempY[j]:=FValueAreaBottom;
      canvas.MoveTo(x,tempY[0]);
      for i:=0 to j-1 do begin
        r:=tempYMap[i];
        if fgGradientY in FFillGradient then begin
          y:=tempY[i];
          if y<RealValueRect.Top then y:=RealValueRect.Top;
          if fgGradientX in FFillGradient then begin
            for yi:=y to tempY[i+1]-1 do
              tempLazImage[x,yi]:=FPColor(scaleYGC(scaleXGC(RStart[r],x,xmid[r]),yi,y),
                                          scaleYGC(scaleXGC(GStart[r],x,xmid[r]),yi,y),
                                          scaleYGC(scaleXGC(BStart[r],x,xmid[r]),yi,y));
          end else for yi:=y to tempY[i+1]-1 do
            tempLazImage[x,yi]:=FPColor(scaleYGC(RStart[r],yi,y),scaleYGC(GStart[r],yi,y),scaleYGC(BStart[r],yi,y));
        end else begin
          if fgGradientX in FFillGradient then canvas.pen.color:=RGBToColor(scaleXGC(RStart[r],x,xmid[r]),scaleXGC(GStart[r],x,xmid[r]),scaleXGC(BStart[r],x,xmid[r]))
          else FModel.setupCanvasForData(r,canvas);
          canvas.LineTo(x,tempY[i+1]);
        end;
      end;
    end;

    if fgGradientY in FFillGradient then
      assignLazImageAndFree(tempLazImage);
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
      res:=round((yend-ystart) / 10);
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

  function getVertAxisWidth(axis:TAxis): longint;
  var p,res: float;
      caption, captionOld: string;
      newWidth: LongInt;
  begin
    captionOld:='';
    result:=0;
    res:=axis.resolution;
    if IsNan(res) or IsInfinite(res)or(res<=0) then
      res:=round((yend-ystart) / 10);
    p:=ystart;
    while p<=yend do begin
      caption:=axis.doTranslate(p);
      if caption<>captionOld then begin
        captionOld:=caption;
        newWidth := canvas.textwidth(caption);
        if newWidth > result then result := newWidth;
      end;
      p+=res;
    end;
  end;

var i,j,pos,legendX:longint;
    usedLineStyle: TLineStyle;
begin
  result:=Diagram;
  canvas:=result.canvas;
  if Diagram.Height=0 then exit;
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
  //setup output height
  FValueAreaY:=3;
  if FTAxis.Visible then FValueAreaY+=AXIS_SIZE;
  FValueAreaBottom:=result.Height-3;
  if FBAxis.Visible then FValueAreaBottom-=AXIS_SIZE;
  if (FLAxis.Visible or FRAxis.Visible) and not (FTAxis.Visible) then //don't truncate last text line
    FValueAreaY+=textHeightC div 2;
  if (FLAxis.Visible or FRAxis.Visible) and not (FBAxis.Visible) then
    FValueAreaBottom-=textHeightC div 2;
  FValueAreaHeight:=FValueAreaBottom-FValueAreaY;
  if FValueAreaHeight<=0 then exit;

  if cvY in FClipValues then begin
    RealValueRect.Top:=fvalueAreaY;
    RealValueRect.Bottom:=FValueAreaBottom;
  end else begin
    RealValueRect.Top:=0;
    RealValueRect.Bottom:=result.Height;
  end;

  //setup ranges (vertical)
  if fmodel.dataRows>0 then begin
    if FAutoSetRangeY then begin
      FRangeMinY:=fmodel.minY;
      if IsInfinite(FRangeMinY) or IsNan(FRangeMinY) then
        FRangeMinY:=0;
      FRangeMaxY:=fmodel.maxY;
      if IsInfinite(FRangeMaxY) or IsNan(FRangeMaxY) or (FRangeMaxY<=FRangeMinY) then
        FRangeMaxY:=FRangeMinY+5;
    end;
    if FLAxis.rangePolicy=rpAuto then FLAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
    if FYMAxis.rangePolicy=rpAuto then FYMAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
    if FRAxis.rangePolicy=rpAuto then FRAxis.rangeChanged(FRangeMinY,FRangeMaxY,FValueAreaHeight);
  end;
  ystart:=RangeMinY;
  yend:=RangeMaxY;
  yfactor:=FValueAreaHeight / (yend-ystart);



  //setup output width
  FValueAreaX:=3;
  if FLAxis.Visible then FValueAreaX+=3+getVertAxisWidth(FLAxis);
  FValueAreaRight:=result.Width-3;
  if legend.visible then FValueAreaRight-=3+legend.width;
  if FRAxis.Visible then FValueAreaRight-=AXIS_SIZE;

  FValueAreaWidth:=FValueAreaRight- FValueAreaX;
  if FValueAreaWidth<=0 then exit;

  if cvX in FClipValues then begin
    RealValueRect.Left:=fvalueAreaX;
    RealValueRect.Right:=FValueAreaRight;
  end else begin
    RealValueRect.Left:=0;
    RealValueRect.Right:=result.width;
  end;

  //setup ranges (horizontal)
  if fmodel.dataRows>0 then begin
    if FAutoSetRangeX then begin
      FRangeMinX:=fmodel.minX;
      if IsInfinite(FRangeMinX) or IsNan(FRangeMinX) then FRangeMinX:=0;
      FRangeMaxX:=fmodel.maxX;
      if IsInfinite(FRangeMaxX) or IsNan(FRangeMaxX) or (FRangeMaxX<=FRangeMinX) then
        FRangeMaxX:=FRangeMinX+5;
    end;
    if FTAxis.rangePolicy=rpAuto then FTAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
    if FXMAxis.rangePolicy=rpAuto then FXMAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
    if FBAxis.rangePolicy=rpAuto then FBAxis.rangeChanged(FRangeMinX,FRangeMaxX,FValueAreaWidth);
  end;
  xstart:=RangeMinX;
  xend:=RangeMaxX;
  xfactor:=FValueAreaWidth / (xend-xstart);


  with result.Canvas do begin
    Clipping:=false;
    SelectClipRGN(canvas.Handle,0);
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

    //activate clipping
    ClipRect:=RealValueRect;
    Clipping:=FClipValues<>[];
    if Clipping then begin
      IntersectClipRect(canvas.Handle,RealValueRect.Left,RealValueRect.top,RealValueRect.Right,RealValueRect.Bottom);
    end;

    //Calculate Spline
    if FModel.FmodifiedSinceSplineCalc<>0 then
      fmodel.calculateSplines(LineStyle);


    //fill values
    case FillStyle of
      fsLastOverFirst: drawFillingLastOverFirst();
      fsMinOverMax: drawFillingMinOverMax();
    end;

    //draw lines + points
    for i:=0 to FModel.dataRows-1 do begin
      if fModel.dataPoints(i)=0 then continue;
      FModel.setupCanvasForData(i,canvas);
      if fModel.dataPoints(i)>1 then begin
        usedLineStyle:=FModel.getRowLineStyle(i);
        if usedLineStyle=lsDefault then usedLineStyle:=LineStyle;
        case usedLineStyle of
          lsLinear: drawLinearLines(i);
          lsCubicSpline: drawCubicSpline(i);
          lsLocalCubicSpline: drawCubicSpline3P(i);
        end;
      end;
      if PointStyle<>psNone then drawPoints(i);
    end;


    //draw legend
    if legend.visible then begin
      if Clipping then begin
        SelectClipRGN(canvas.handle,0);
        Clipping:=false;
      end;
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
  if FValueAreaWidth=0 then exit(1);
  result:=abs((RangeMaxX-RangeMinX) / FValueAreaWidth);
end;

function TDiagramDrawer.pixelSizeY: float;
begin
  if FValueAreaHeight=0 then exit(1);
  result:=abs((RangeMaxY-RangeMinY) / FValueAreaHeight);
end;

{ TAbstractDiagramModel }


procedure TAbstractDiagramModel.doModified(row:longint);
begin
  if row=-1 then
    FmodifiedSinceSplineCalc:=2
  else if (row<>-1) and (dataPoints(row)>1) then
    FmodifiedSinceSplineCalc:=2;//it makes no sense to recalculate splines if there no lines are drawn
  fmodifiedEvents.CallNotifyEvents(self);
end;

constructor TAbstractDiagramModel.create;
begin
  fmodifiedEvents:=TMethodList.Create;
  FDestroyEvents:=TMethodList.Create;
end;

destructor TAbstractDiagramModel.destroy;
begin
  FDestroyEvents.CallNotifyEvents(self);
  FDestroyEvents.free;
  fmodifiedEvents.free;
  inherited destroy;
end;


procedure TAbstractDiagramModel.calculateSplines(defaultLineStyle: TLineStyle);
//taken from Wikipedia
var r,i,n,im:longint;
    xpi,xi,l,alpha:float;
    h,z,my: array of float;
    needSplines: boolean;
begin
  //TODO: find a way to remove the old spline data if it is no longer used (problem even if no view need them, the user app still can need them for lineApproximationAtX)
  needSplines:=false;
  if FmodifiedSinceSplineCalc=0 then exit;
  if (FmodifiedSinceSplineCalc=1) and (defaultLineStyle<>lsCubicSpline) then exit;
  for i:=0 to dataRows-1 do
    case getRowLineStyle(i) of
      lsDefault: if defaultLineStyle=lsCubicSpline then begin
        needSplines:=true;
        break;
      end;
      lsCubicSpline: begin
        needSplines:=true;
        break;
      end;
    end;
  if not needSplines then begin
    exit;//SetLength(FSplines,0);
  end;
  if defaultLineStyle=lsCubicSpline then FmodifiedSinceSplineCalc:=0
  else FmodifiedSinceSplineCalc:=1;
  SetLength(FSplines,dataRows);
  for r:=0 to high(FSplines) do begin
    if ((getRowLineStyle(r)<>lsDefault) or (defaultLineStyle<>lsCubicSpline)) and
      (getRowLineStyle(r)<>lsCubicSpline) then begin
      //setlength(FSplines[r],0);
      continue;
    end;
    n:=dataPoints(r);
    setlength(FSplines[r],n);
    if n=0 then continue;
    if n<=1 then begin
      FSplines[r,0].d:=dataY(r,0);
      FSplines[r,0].a:=0;
      FSplines[r,0].b:=0;
      FSplines[r,0].c:=0;
      continue;
    end;
    setlength(z,n);
    setlength(my,n);
    setlength(h,n);
    data(r,0,xi,FSplines[r,0].d);
    for i:=0 to n-2 do begin
      data(r,i+1,xpi,FSplines[r,i+1].d );
      h[i]:=xpi-xi;
      xi:=xpi;
    end;
    my[0]:=0;z[0]:=0;z[n-1]:=0;
    im:=0;
    for i:=1 to n-2 do begin
      l:=2*(h[i]+h[im]) - h[im]*my[im];
      if abs(l)<h[i] then my[i]:=my[i-1]
      else my[i]:=h[i]/l;
      if abs(h[i])<DiagramEpsilon then
        z[i]:=z[i-1]
      else if abs(h[im])<DiagramEpsilon then begin
        z[i]:=z[i-1];
        im:=i;
      end else begin
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

procedure TAbstractDiagramModel.SetOnModified(const AValue: TNotifyEvent);
begin
  if FOnModified=AValue then exit;
  fmodifiedEvents.Remove(TMethod(FOnModified));
  FOnModified:=AValue;
  fmodifiedEvents.Add(TMethod(FOnModified));
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

function TAbstractDiagramModel.getRowFlags(i:longint): TModelRowFlags;
begin
  result:=[];
end;

function TAbstractDiagramModel.getRowLineStyle(i: longint): TLineStyle;
begin
  Result:=lsDefault;
end;

function TAbstractDiagramModel.getRowPointStyle(i: longint): TPointStyle;
begin
  Result:=psDefault;
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

function TAbstractDiagramModel.lineApproximationAtX(const defaultLineStyle:TLineStyle; i:longint; const x: float): float;
var j:longint;
    x0,y0,x1,y1,x2,y2: float;
    spline: TDiagramSplinePiece;
    ls:TLineStyle;
begin
  if dataPoints(i)=0 then exit(nan);
  if dataPoints(i)=1 then exit(dataY(i,0));
  if x<minX(i) then exit(dataY(i,0));
  if x>maxX(i) then exit(dataY(i,dataPoints(i)-1));
  if FmodifiedSinceSplineCalc<>0 then calculateSplines(defaultLineStyle);
  ls:=getRowLineStyle(i);
  if ls=lsDefault then ls:=defaultLineStyle;
  case ls of
    lsNone, lsLinear: begin
      data(i,0,x1,y1);
      for j:=1 to dataPoints(i)-1 do begin
        data(i,j,x2,y2);
        if (x>=x1) and  (x<=x2) then
          if abs(x1-x2)>DiagramEpsilon then exit((x-x1)*(y2-y1)/(x2-x1)+y1)
          else exit((y1+y2)/2); //better not really correct result than crash
        x1:=x2;y1:=y2;
      end;
    end;
    lsCubicSpline: begin
      data(i,0,x1,y1);
      if (length(FSplines)<i) or (length(FSplines[i])<dataPoints(i)) then
        exit(nan); //wtf
      for j:=1 to dataPoints(i)-1 do begin
        data(i,j,x2,y2);
        if (x>=x1) and  (x<=x2) then
          exit(calcSpline(FSplines[i,j-1],x-x1));
        x1:=x2;y1:=y2;
      end;
    end;
    lsLocalCubicSpline: begin
      data(i,0,x1,y1);
      data(i,1,x2,y2);
      FillChar(spline,sizeof(spline),0);
      updateSpline3P(spline,x1-2*(x2-x1),y1,x1,y1,x2,y2);
      for j:=1 to dataPoints(i)-1 do begin
        //next point
        x0:=x1;y0:=y1;
        x1:=x2;y1:=y2;
        data(i,j,x2,y2);
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

function TAbstractDiagramModel.findLineApproximation(const defaultLineStyle:TLineStyle; const x, y: float; const ytolerance: float
  ): longint;
var i:longint;
    ly, bestdelta: float;
begin
  result:=-1;
  bestdelta:=ytolerance;
  for i:=0 to dataRows-1 do begin
    if (x<minX(i)) or (x>maxX(i)) then continue;
    ly:=lineApproximationAtX(defaultLineStyle, i,x);
    if isNan(ly) then continue;
    if abs(ly-y) <= bestdelta then begin
      bestdelta:=abs(ly-y);
      result:=i;
    end;
  end;
end;

procedure TAbstractDiagramModel.addModifiedHandler(event: TNotifyEvent);
begin
  fmodifiedEvents.Add(TMethod(event));
end;

procedure TAbstractDiagramModel.removeModifiedHandler(event: TNotifyEvent);
begin
  fmodifiedEvents.Remove(TMethod(event));
end;

procedure TAbstractDiagramModel.addDestroyHandler(event: TNotifyEvent);
begin
  FDestroyEvents.Add(TMethod(event));
end;

procedure TAbstractDiagramModel.removeDestroyHandler(event: TNotifyEvent);
begin
  FDestroyEvents.remove(TMethod(event));
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

function TDiagramDataListModel.getRowFlags(i: longint): TModelRowFlags;
begin
  if (i<0) or (i>=FLists.Count) then exit([]);
  Result:=lists[i].Flags;
end;

function TDiagramDataListModel.getRowLineStyle(i: longint): TLineStyle;
begin
  if (i<0) or (i>=FLists.Count) then exit(lsDefault);
  Result:=lists[i].LineStyle;
end;

function TDiagramDataListModel.getRowPointStyle(i: longint): TPointStyle;
begin
  if (i<0) or (i>=FLists.Count) then exit(psDefault);
  Result:=lists[i].PointStyle;
end;

procedure TDiagramDataListModel.SetFlags(const AValue: TModelFlags);
begin
  if FFlags=AValue then exit;
  FFlags:=AValue;
  doModified(-1);
end;

constructor TDiagramDataListModel.create;
begin
  inherited;
  FLists:=TFPList.Create;
end;

destructor TDiagramDataListModel.destroy;
begin
  deleteLists;
  FLists.Free;
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
      flists[i]:=TDataList.Create(self,i,colors[i and $7]);
  end else if flists.count>c then begin
    for i:=c to flists.count-1 do
      TDataList(flists[i]).free;
    FLists.Count:=c;
  end;
end;

procedure TDiagramDataListModel.deleteDataRow(i: longint);
begin
  lists[i].free;
  FLists.Delete(i);
  for i:=i to flists.count-1 do
    lists[i].FRowNumber:=i;
  doModified(-1);
end;

function TDiagramDataListModel.addDataList:TDataList;
const colors:array[0..7] of TColor=(clBlue,clRed,clGreen,clMaroon,clFuchsia,clTeal,clNavy,clBlack);
begin
  Result:=TDataList.Create(self,flists.count,colors[FLists.Count and $7]);
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
  if not (mfEditable in Flags) then exit(-1);
  if (i<0) or (i>=FLists.Count) then exit(-1);
  result:=lists[i].setPoint(j,x,y);
end;

function TDiagramDataListModel.addData(i: longint; const x, y: float): integer;
begin
  if not (mfEditable in Flags) then exit(-1);
  if (i<0) or (i>=FLists.Count) then exit(-1);
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
  FDrawer.FModelModified:=true;
  Invalidate;
end;

procedure TDiagramView.modelDestroyed(sender: Tobject);
begin
  FModel:=nil;
end;

procedure TDiagramView.layoutChanged(sender: Tobject);
begin
  FDrawer.FLayoutModified:=true;
  Invalidate;
end;

procedure TDiagramView.DoOnResize;
begin
  FDrawer.Diagram.Width:=width;
  if height<FDrawer.Diagram.Height-FDrawer.FValueAreaHeight then FDrawer.Diagram.Height:=FDrawer.Diagram.Height-FDrawer.FValueAreaHeight
  else FDrawer.Diagram.Height:=Height;
  if assigned(fmodel) then FDrawer.FModelModified:=true;
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
  if assigned(fmodel) then begin
    FModel.removeModifiedHandler(@modelChanged);
    FModel.removeDestroyHandler(@modelDestroyed);
  end;
  FDrawer.SetModel(amodel,takeOwnership);
  FModel:=amodel;
  if assigned(fmodel) then begin
    FModel.addModifiedHandler(@modelChanged);
    FModel.addDestroyHandler(@modelDestroyed);
    FDrawer.FModelModified:=true;
  end;
end;

procedure TDiagramView.paint;
begin
  if not assigned(FDrawer.FModel) then exit;
  if FDrawer.FLayoutModified or FDrawer.FModelModified then
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

  FDrawer.FModelModified:=false;
  FDrawer.FLayoutModified:=false;
end;

procedure TDiagramView.mouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var fx,fy:float;
    i:longint;
begin
  inherited mouseDown(Button, Shift, X, Y);
  if not assigned(FDrawer.FModel) then exit;
  if mfEditable in FModel.getFlags then begin
    if ([eaMovePoints, eaDeletePoints]*FAllowedEditActions<>[]) then begin
      fX:=FDrawer.posToDataX(x);
      fY:=FDrawer.posToDataY(y);
      FSelPoint:=fmodel.findWithRow(FSelRow, fX,fY,2*FDrawer.PointSize*FDrawer.pixelSizeX,2*FDrawer.PointSize*FDrawer.pixelSizeY);
      FSelPointMoving:=FSelPoint<>-1;
      FHighlightPoint.x:=nan;
    end;
    if (eaAddPoints in FAllowedEditActions) and not FSelPointMoving then begin
      fX:=FDrawer.posToDataX(x);
      fY:=FDrawer.posToDataY(y);
      i:=fmodel.findLineApproximation(FDrawer.LineStyle, fx,fy,10*FDrawer.pixelSizeY);
      if i<>-1 then begin
        FSelRow:=i;
        FSelPoint:= FModel.addData(i,fx,fy);
        FSelPointMoving:=FSelPoint<>-1;
      end;
    end;
    if eaDeletePoints in FAllowedEditActions then SetFocus;
  end;
end;

procedure TDiagramView.mouseMove(Shift: TShiftState; X, Y: Integer);
var i,j:longint;
    fx,fy:float;
begin
  if (not assigned(FModel)) or (FModel.dataRows=0) then begin
    inherited mouseMove(Shift, X, Y);
    exit;
  end;
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
  inherited mouseMove(Shift, X, Y); //so it is modified when mouse move is called
end;

procedure TDiagramView.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  FSelPointMoving:=false;
  if (FSelPoint<>-1) and not (eaDeletePoints in FAllowedEditActions) then begin
    FSelPoint:=-1;
    repaint;
  end;
  inherited MouseUp(Button, Shift, X, Y);
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

{ TDiagramModelMerger }

function TDiagramModelMerger.GetRowVisible(i: integer): boolean;
begin
  if (i>=length(FRowVisible)) or (i<0) then exit(true);
  result:=FRowVisible[i];
end;

procedure TDiagramModelMerger.SetBaseModel(const AValue: integer);
begin
  if FBaseModel=AValue then exit;
  FBaseModel:=AValue;
  doModified(-1);
end;

procedure TDiagramModelMerger.SetHideCertainRows(const AValue: boolean);
begin
  if FHideCertainRows=AValue then exit;
  FHideCertainRows:=AValue;
  if not AValue then SetLength(FRowVisible,0);
end;

procedure TDiagramModelMerger.SetModel(i: longint;
  const AValue: TAbstractDiagramModel);
begin
  SetModel(i,AValue,false);
end;

procedure TDiagramModelMerger.SetModel(i: longint;
  const AValue: TAbstractDiagramModel; takeOwnerShip: boolean=false);
begin
  if (i<0) then exit;
  if (i>=fmodels.Count) then begin
    addModel(AValue);
    exit();
  end;
  Models[i].removeModifiedHandler(@subModelModified);
  TObject(ownerShipModels[i]).Free;
  fmodels[i]:=AValue;
  if takeOwnership then ownerShipModels[i]:=AValue
  else ownerShipModels[i]:=nil; //tricky: TObject(nil).free is valid (and does nothing)
  AValue.addModifiedHandler(@subModelModified);
  AValue.addDestroyHandler(@subModelDestroyed);
  FmodifiedSinceSplineCalc:=max(FmodifiedSinceSplineCalc,avalue.FmodifiedSinceSplineCalc);
  doModified(-1);
end;

procedure TDiagramModelMerger.SetRowVisible(i: integer; const AValue: boolean);
var j:longint;
begin
  if i<0 then exit;
  if i>=length(FRowVisible) then begin
    j:=length(FRowVisible);
    setlength(FRowVisible,i+1);
    for j:=j to high(FRowVisible) do
      FRowVisible[i]:=true;
  end;
  FRowVisible[i]:=AValue;
end;

procedure TDiagramModelMerger.subModelModified(sender: TObject);
begin
  doModified(-1);
end;

procedure TDiagramModelMerger.subModelDestroyed(sender: TObject);
begin
  fmodels.Remove(sender);
  ownerShipModels.Remove(sender);
  doModified(-1);
end;

function TDiagramModelMerger.rowToRealRow(i: longint; out m, r: longint): boolean;
var
  j: Integer;
begin
  m:=-1;
  result:=false;
  if FHideCertainRows then begin
    if fmodels.Count=0 then exit;
    m:=0;
    r:=0;
    j:=0;
    while m<fmodels.count do begin
      while r<TAbstractDiagramModel(FModels[m]).dataRows do begin
        if (j>high(FRowVisible)) or (FRowVisible[j]) then j+=1;
        if i=j then exit;
        r+=1;
      end;
      r:=0;
      m+=1;
    end;
  end else for j:=0 to FModels.count-1 do
    if i<TAbstractDiagramModel(FModels[j]).dataRows then begin
      r:=i;
      m:=j;
      exit(true);
    end else i-=TAbstractDiagramModel(FModels[j]).dataRows;
end;

function TDiagramModelMerger.GetModel(i: longint): TAbstractDiagramModel;
begin
  if (i<0) or (i>=fmodels.Count) then exit(nil);
  result:=TAbstractDiagramModel(FModels[i]);
end;

procedure TDiagramModelMerger.addModel(model: TAbstractDiagramModel;
  takeOwnership: boolean);
begin
  FModels.Add(model);
  if takeOwnership then ownerShipModels.Add(model)
  else ownerShipModels.add(nil); //tricky: TObject(nil).free is valid (and does nothing)
  model.addModifiedHandler(@subModelModified);
  model.addDestroyHandler(@subModelDestroyed);
  FmodifiedSinceSplineCalc:=max(FmodifiedSinceSplineCalc,Model.FmodifiedSinceSplineCalc);
  doModified(-1);
end;

procedure TDiagramModelMerger.replaceModel(oldModel,
  newModel: TAbstractDiagramModel; takeOwnership: boolean);
var i:integer;
begin
  i:=FModels.IndexOf(oldModel);
  if i<0 then addModel(newModel,takeOwnership)
  else SetModel(i,newModel,takeOwnership);
end;

procedure TDiagramModelMerger.removeModel(model: TAbstractDiagramModel);
begin
  deleteModel(FModels.IndexOf(model));
end;

procedure TDiagramModelMerger.removeAllModels();
var i:longint;
begin
  for i:=ownerShipModels.count-1 downto 0 do
    deleteModel(i);
  FModels.Clear;
  ownerShipModels.Clear;
  doModified(-1);
end;

procedure TDiagramModelMerger.deleteModel(i: longint);
begin
  if (i<0) or (i>=fmodels.Count) then exit;
  Models[i].removeModifiedHandler(@subModelModified);
  Models[i].removeDestroyHandler(@subModelDestroyed);
  TObject(ownerShipModels[i]).Free;
  FModels.Delete(i);
  ownerShipModels.Delete(i);
  doModified(-1);
end;

constructor TDiagramModelMerger.create;
begin
  inherited create;
  FModels:=TFPList.Create;
  ownerShipModels:=TFPList.Create;
end;

constructor TDiagramModelMerger.create(model: TAbstractDiagramModel;
  takeOwnership: boolean);
begin
  create;
  addModel(model, takeOwnership);
end;

constructor TDiagramModelMerger.create(model1, model2: TAbstractDiagramModel;
  takeOwnership1: boolean; takeOwnership2: boolean);
begin
  create;
  addModel(model1, takeOwnership1);
  addModel(model2, takeOwnership2);
end;


destructor TDiagramModelMerger.destroy;
var t1,t2:TFPList;
begin
  removeAllModels();
  t1:=fmodels;
  t2:=ownerShipModels;
  inherited destroy;
  t1.Free;
  t2.free;
end;

function TDiagramModelMerger.dataRows: longint;
var i:longint;
begin
  result:=0;
  for i:=0 to FModels.Count-1 do
    result+=TAbstractDiagramModel(FModels[i]).dataRows;
  if FHideCertainRows then
    for i:=0 to max(result-1,high(FRowVisible)) do
      if not FRowVisible[i] then result-=1;

end;

function TDiagramModelMerger.dataTitle(i: longint): string;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit('');
  Result:=TAbstractDiagramModel(FModels[m]).dataTitle(r);
end;

procedure TDiagramModelMerger.setupCanvasForData(i: longint; c: TCanvas);
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit();
  TAbstractDiagramModel(FModels[m]).setupCanvasForData(r, c);
end;

function TDiagramModelMerger.dataPoints(i: longint): longint;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(0);
  Result:=TAbstractDiagramModel(FModels[m]).dataPoints(r);
end;

procedure TDiagramModelMerger.data(i, j: longint; out x, y: float);
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then begin
    x:=nan;
    y:=nan;
    exit();
  end;
  TAbstractDiagramModel(FModels[m]).data(r, j, x, y);
end;

function TDiagramModelMerger.setData(i, j: longint; const x, y: float
  ): integer;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(-1);
  Result:=TAbstractDiagramModel(FModels[m]).setData(r, j, x, y);
end;

function TDiagramModelMerger.addData(i: longint; const x, y: float): integer;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(-1);
  Result:=TAbstractDiagramModel(FModels[m]).addData(r, x, y);
end;

procedure TDiagramModelMerger.removeData(i, j: longint);
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit();
  TAbstractDiagramModel(FModels[m]).removeData(r, j);
end;

function TDiagramModelMerger.minX(i: longint): float;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(0);
  Result:=TAbstractDiagramModel(FModels[m]).minX(r);
end;

function TDiagramModelMerger.maxX(i: longint): float;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(0);
  Result:=TAbstractDiagramModel(FModels[m]).maxX(r);
end;

function TDiagramModelMerger.minY(i: longint): float;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(PInfinity);
  Result:=TAbstractDiagramModel(FModels[m]).minY(r);
end;

function TDiagramModelMerger.maxY(i: longint): float;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(MInfinity);
  Result:=TAbstractDiagramModel(FModels[m]).maxY(r);
end;

function TDiagramModelMerger.getFlags: TModelFlags;
begin
  if FModels.Count=0 then
    exit([]);
  if FBaseModel<=fmodels.count then
    Result:=TAbstractDiagramModel(FModels[FBaseModel]).getFlags
  else
    Result:=TAbstractDiagramModel(FModels[0]).getFlags;
end;

function TDiagramModelMerger.getRowFlags(i: longint): TModelRowFlags;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit([]);
  Result:=TAbstractDiagramModel(FModels[m]).getRowFlags(r);
end;

function TDiagramModelMerger.getRowLineStyle(i: longint): TLineStyle;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(lsDefault);
  Result:=TAbstractDiagramModel(FModels[m]).getRowLineStyle(r);
end;

function TDiagramModelMerger.getRowPointStyle(i: longint): TPointStyle;
var m,r: integer;
begin
  if not rowToRealRow(i,m,r) then
    exit(psDefault);
  Result:=TAbstractDiagramModel(FModels[m]).getRowPointStyle(r);
end;

end.