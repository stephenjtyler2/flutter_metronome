import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';


enum MetronomeState {
  Playing,
  Stopped,
  Stopping
}

class MetronomeControl extends StatefulWidget {
  MetronomeControl();
  MetronomeControlState createState() => new MetronomeControlState();
}

class MetronomeControlState extends State<MetronomeControl> {

  final _maxRotationAngle = 0.26;
  final _minTempo = 30;
  final _maxTempo = 220;

  List<int> _tapTimes = List();

  int _tempo = 60;

  bool _bobPanning = false;

  MetronomeState _metronomeState = MetronomeState.Stopped;
  int _lastFrameTime=0;
  Timer _tickTimer;
  Timer _frameTimer;
  int _lastEvenTick;
  bool _lastTickWasEven;
  int _tickInterval;

  double _rotationAngle=0;

  MetronomeControlState();

  @override
  void dispose() {
    _frameTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }


  void _start() {
    _metronomeState = MetronomeState.Playing;

    double bps = _tempo/60;
    _tickInterval = 1000~/bps;
    _lastEvenTick = DateTime.now().millisecondsSinceEpoch;
    _tickTimer = new Timer.periodic(new Duration(milliseconds: _tickInterval), _onTick);
    _animationLoop();

    SystemSound.play(SystemSoundType.click);

    if (mounted) setState((){});
  }

  void _animationLoop() {
    _frameTimer?.cancel();
    int thisFrameTime = DateTime.now().millisecondsSinceEpoch;

    if (_metronomeState == MetronomeState.Playing || _metronomeState == MetronomeState.Stopping) {
      int delay = max(0,_lastFrameTime + 17 - DateTime.now().millisecondsSinceEpoch);
      _frameTimer = new Timer(new Duration(milliseconds: delay), ()  { _animationLoop();});
    }
    else {
      _rotationAngle =0;
    }
    if (mounted) setState(() {});
    _lastFrameTime = thisFrameTime;
  }

  void _onTick(Timer t) {
    _lastTickWasEven = t.tick%2 ==0;
    if (_lastTickWasEven) _lastEvenTick = DateTime.now().millisecondsSinceEpoch;

    if (_metronomeState == MetronomeState.Playing) {
      SystemSound.play(SystemSoundType.click);
    }
    else if (_metronomeState == MetronomeState.Stopping) {
      _tickTimer?.cancel();
      _metronomeState = MetronomeState.Stopped;
    }
  }

  void _stop() {
    _metronomeState = MetronomeState.Stopping;
    if (mounted) setState((){});
  }


  void _tap() {
    if (_metronomeState != MetronomeState.Stopped) return;
    int now= DateTime.now().millisecondsSinceEpoch;
    _tapTimes.add(now);
    if (_tapTimes.length>3) {
      _tapTimes.removeAt(0);
    }
    int tapCount=0;
    int tapIntervalSum=0;

    for (int i = _tapTimes.length-1; i>=1; i--) {

      int currentTapTime = _tapTimes[i];
      int previousTapTime = _tapTimes[i-1];
      int currentInterval = currentTapTime - previousTapTime;
      if (currentInterval > 3000) break;

      tapIntervalSum  += currentInterval;
      tapCount++;
    }
    if (tapCount>0) {
      int msBetweenTicks = tapIntervalSum ~/ tapCount;
      double bps = 1000/msBetweenTicks;
      _tempo = min(max((bps * 60).toInt(), _minTempo),_maxTempo);
    }
    if(mounted) setState(() {});
  }


  double _getRotationAngle() {

    double rotationAngle =0;
    double segmentPercent;
    double begin;
    double end;
    Curve curve;

    int now = DateTime.now().millisecondsSinceEpoch;
    double oscillationPercent =0;
    if (_metronomeState == MetronomeState.Playing || _metronomeState == MetronomeState.Stopping) {
      int delta = now - _lastEvenTick;
      if (delta > _tickInterval*2) {
        delta -= (_tickInterval*2);
      }
      oscillationPercent = (delta).toDouble() / (_tickInterval * 2);
      if(oscillationPercent <0 || oscillationPercent>1) {
        oscillationPercent = min(1,max(0,oscillationPercent));
      }
    }

    if (oscillationPercent< 0.25) {
      segmentPercent = oscillationPercent * 4;
      begin =0;
      end = _maxRotationAngle;
      curve = Curves.easeOut;
    }
    else if (oscillationPercent < 0.75) {
      segmentPercent = (oscillationPercent-0.25) * 2;
      begin = _maxRotationAngle;
      end = -_maxRotationAngle;
      curve = Curves.easeInOut;

    }
    else {
      segmentPercent = (oscillationPercent-0.75) * 4;
      begin = -_maxRotationAngle;
      end = 0;
      curve = Curves.easeIn;
    }

    CurveTween curveTween = CurveTween(curve: curve);
    double easedPercent= curveTween.transform(segmentPercent);

    Tween tween = Tween<double>(begin: begin, end: end);
    rotationAngle = tween.transform(easedPercent);

    return rotationAngle;
  }

  @override
  Widget build(BuildContext context) {
    _rotationAngle = _getRotationAngle();
    return Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(height: 20),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    double aspectRatio = 1.5; // height:width
                    double width = (constraints.maxHeight >= constraints.maxWidth * aspectRatio) ? constraints.maxWidth : constraints.maxHeight / aspectRatio;
                    double height = (constraints.maxHeight >= constraints.maxWidth * aspectRatio) ? width * aspectRatio : constraints.maxHeight;

                    return _wand(width, height);
                  }
              )
          ),
          Container(height: 20),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RaisedButton(
                    color: Colors.purple,
                    textColor: Colors.white,
                    child:Text(
                        _metronomeState == MetronomeState.Stopped ? "Start" :
                        _metronomeState == MetronomeState.Stopping ? "Stopping" : "Stop"),
                    onPressed: _metronomeState == MetronomeState.Stopping ? null : () {_metronomeState == MetronomeState.Stopped ? _start() : _stop();}
                ),
                RaisedButton(
                  color: Colors.purple,
                  textColor: Colors.white,
                  child:Text("Tap"),
                  onPressed: _metronomeState == MetronomeState.Stopped ? () {_tap();} : null,
                )
              ]
          ),
          SizedBox(height: 20),
        ]
    );
  }

  Widget _wand(double width, double height) {
    return Container(
      width: width,
      height: height,
      child: GestureDetector(
        onPanDown: (dragDownDetails) {
          RenderBox box = context.findRenderObject();
          Offset localPosition = box.globalToLocal(dragDownDetails.globalPosition);
          if (_bobHitTest(width, height, localPosition)) _bobPanning=true;
        },
        onPanUpdate: (dragUpdateDetails) {
          if (_bobPanning) {
            RenderBox box = context.findRenderObject();
            Offset localPosition = box.globalToLocal(dragUpdateDetails.globalPosition);
            _bobDragTo(width, height, localPosition);
          }
        },
        onPanEnd: (dragEndDetails) {
          _bobPanning=false;
        },
        onPanCancel: () {
          _bobPanning=false;
        },

        child: CustomPaint (
          foregroundPainter: new MetronomeWandPainter(
              width: width,
              height: height,
              tempo: _tempo,
              minTempo: _minTempo,
              maxTempo: _maxTempo,
              rotationAngle: _rotationAngle
          ),

          child: InkWell(),
        ),
      ),
    );

  }
  bool _bobHitTest(double width, double height, Offset localPosition) {
    if (_metronomeState != MetronomeState.Stopped) return false;

    Offset translatedLocalPos = localPosition.translate(-width/2, -height * 0.75);
    WandCoords wandCoords = WandCoords(width, height, _tempo, _minTempo, _maxTempo);

    return ((translatedLocalPos.dy - wandCoords.bobCenter.dy).abs() < height/ 20);
  }

  void _bobDragTo(double width, double height, Offset localPosition) {
    Offset translatedLocalPos = localPosition.translate(-width/2, -height * 0.75);
    WandCoords wandCoords = WandCoords(width, height, _tempo, _minTempo, _maxTempo);

    double bobPercent = (translatedLocalPos.dy - wandCoords.bobMinY) / wandCoords.bobTravel;
    _tempo = min(_maxTempo, max(_minTempo,_minTempo + (bobPercent * (_maxTempo - _minTempo)).toInt()));
    double bps = _tempo/60;
    _tickInterval = 1000~/bps;

    setState((){});
  }
}

class WandCoords {
  Offset bobCenter;
  Offset counterWeightCenter;
  double counterWeightRadius;
  Offset stickTop;
  Offset stickBottom;
  Offset rotationCenter;
  double rotationCenterRadius;
  double bobMinY;
  double bobMaxY;
  double bobTravel;

  // calculates all coordinates relative to the rotation center and scaled based on height and width.
  WandCoords(double width, double height, int tempo, int minTempo, int maxTempo) {
    rotationCenter  = new Offset(0, 0);
    rotationCenterRadius = width/40;

    counterWeightCenter = new Offset(0, height*0.175);
    counterWeightRadius = width/12;

    stickTop = new Offset(0, - height * 0.68);
    stickBottom = new Offset(0, height * 0.175);

    double bobHeight = height / 15;
    bobMinY = stickTop.dy;
    bobMaxY = rotationCenter.dy - rotationCenterRadius - bobHeight/2 - 2;
    bobTravel = bobMaxY - bobMinY;
    double tempoPercent = (tempo - minTempo) / (maxTempo-minTempo);
    double bobPercent = tempoPercent;
    bobCenter = new Offset(0, bobMinY + (bobTravel * bobPercent));
  }
}

class MetronomeWandPainter extends CustomPainter{
  // props required for painting
  double width;
  double height;
  int tempo;
  int minTempo;
  int maxTempo;
  double rotationAngle;

  static ui.Picture wandPicture;


  Color _bobTextColor= Colors.white;
  Map <String, Paint> paints;

  MetronomeWandPainter({this.width, this.height, this.tempo, this.minTempo, this.maxTempo, this.rotationAngle});

  _initFillsAndPaints() {
    if (paints == null ) paints = {
      "strokeBase": Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.015,


      "fillCounterWeight": Paint()
        ..color = Colors.deepPurple
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill,

      "fillRotationCenter": Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill,

      "fillBob": Paint()
        ..color = Colors.teal
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {

    if (paints==null) _initFillsAndPaints();

    if (wandPicture == null) {
      // draw unrotated wand on to a picture canvas
      ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      Canvas pictureCanvas = new Canvas(pictureRecorder);

      _drawWandOnCanvas(pictureCanvas);
      wandPicture = pictureRecorder.endRecording();
    }
    canvas.translate(width / 2, height * .75);
    canvas.rotate(rotationAngle);
    canvas.drawPicture(wandPicture);

  }

  _drawWandOnCanvas(Canvas canvas) {
    WandCoords wandCoords = WandCoords(width, height, tempo, minTempo, maxTempo);

    List<Offset> bobPoints = new List()
      ..add(Offset(wandCoords.bobCenter.dx + width/8, wandCoords.bobCenter.dy + height/20))
      ..add(Offset(wandCoords.bobCenter.dx - width/8, wandCoords.bobCenter.dy + height/20))
      ..add(Offset(wandCoords.bobCenter.dx - width/6, wandCoords.bobCenter.dy - height/20))
      ..add(Offset(wandCoords.bobCenter.dx + width/6, wandCoords.bobCenter.dy - height/20));

    Path bobPath = Path()
      ..addPolygon(bobPoints, true);

    ui.ParagraphBuilder paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: TextDirection.ltr,
        fontSize: width/15,
        textAlign: TextAlign.left,
      ),
    )
      ..pushStyle(ui.TextStyle(color: _bobTextColor))
      ..addText('$tempo');


    ui.Paragraph paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: width/4));


    Offset paragraphPos = Offset(
        wandCoords.bobCenter.dx - paragraph.maxIntrinsicWidth / 2.0,
        wandCoords.bobCenter.dy - paragraph.height / 2.0
    );

    canvas.drawLine(wandCoords.stickTop, wandCoords.stickBottom, paints["strokeBase"]);
    canvas.drawCircle(wandCoords.rotationCenter, wandCoords.rotationCenterRadius, paints["fillRotationCenter"]);
    canvas.drawCircle(wandCoords.counterWeightCenter, wandCoords.counterWeightRadius, paints["fillCounterWeight"]);
    canvas.drawCircle(wandCoords.counterWeightCenter, wandCoords.counterWeightRadius, paints["strokeBase"]);
    canvas.drawPath(bobPath, paints["fillBob"]);
    canvas.drawPath(bobPath, paints["strokeBase"]);
    canvas.drawParagraph(paragraph, paragraphPos);
  }

  @override
  bool shouldRepaint(MetronomeWandPainter oldDelegate) {
    if (oldDelegate.tempo != tempo) {
      wandPicture = null; // we can't re-use the last drawing if the tempo changed
    }

    // if either the rotationAngle or the tempo changed we will need to repaint...
    return (oldDelegate.rotationAngle != rotationAngle || oldDelegate.tempo != tempo);
  }
}