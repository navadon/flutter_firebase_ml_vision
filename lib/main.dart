import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http; 
import 'package:flutter/material.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:firebase_core/firebase_core.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase ML Vision Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Firebase ML Vision Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _imageUrl;
  Image _image;
  Size _imageSize;

  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector();
  dynamic _scanResults;

  @override
  void initState() {
    super.initState();
    // TODO: Add image URL
    _imageUrl = "..."; 
    _image = Image.network(_imageUrl);
  }

  Future<void> _scanImage() async {
    setState(() {
      _scanResults = null;
    });

    // Prepare local file from image URL
    final File imageFile = await _fileFromImageUrl(_imageUrl);

    // Decode image and get image size (image size will be used when painting)
    var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    setState(() {
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
    });

    // Prepare vision image and process with face detector
    final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFile(imageFile);
    List<Face> faces = await _faceDetector.processImage(visionImage);
    _faceDetector.close();
  
    setState(() {
      _scanResults = faces;   // Update scan results. Use setState to make sure that build() will be called
    });
  }

  CustomPaint _buildResults(dynamic results) {
    CustomPainter painter = FaceDetectorPainter(_imageSize, results, );
    return CustomPaint(foregroundPainter: painter, child: _image,);
  }

  Widget _buildImage() {
    return Container(
      child: Center(
        child: _scanResults == null ? // if scan result is null, display image and process button
          Column( children: <Widget>[ 
            _image,
            ElevatedButton(
              onPressed: _scanImage, 
              child: Text("Process"),
            ),
          ], ) 
          : Column( children: <Widget>[ // if scan result is initialized, display result and text
            _buildResults(_scanResults), 
            Text('Faces found: ${_scanResults.length}'),
          ], )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _image == null ?         // if there is no image loaded (null), display progress indicator 
        CircularProgressIndicator() 
        : _buildImage(),                // if image is loaded, display image and process button
      ), 
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces);

  final Size absoluteImageSize;
  final List<Face> faces;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (final Face face in faces) { // draw rectangles for all detected faces
      canvas.drawRect(
        Rect.fromLTRB(
          face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}

Future<File> _fileFromImageUrl(String imageUrl) async { // convert from image url to local file
    final response = await http.get(Uri.parse(imageUrl));
    print("_fileFromImageUrl: http.get done");

    final directory = await getApplicationDocumentsDirectory();
    print("_fileFromImageUrl: directory initialized");

    final file = File(join(directory.path, 'temp.jpg'));
    print("_fileFromImageUrl: file initialized");

    file.writeAsBytesSync(response.bodyBytes);
    print("_fileFromImageUrl: file.writeAsBytesSync done");

    return file;
}