import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class SDImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  SDImage(this.imageUrl, this.width, this.height, {Key key}) : super(key: key);
  @override
  _SDImageState createState() => _SDImageState();
}

class _SDImageState extends State<SDImage> {
  bool _isTextureReady = false;
  int _textureId = -1;
  MethodChannel _channel = const MethodChannel('s_d_image');

  @override
  void initState() {
    super.initState();
    this.getTexture();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    this.removeTexture();
    super.dispose();
  }

  void getTexture() async {
    try {
      _textureId =
          await _channel.invokeMethod('getTexture', this.widget.imageUrl);
      if (this.mounted) {
        setState(() {
          _isTextureReady = true;
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  void removeTexture() async {
    try {
      int isSuccess =
          await _channel.invokeMethod('removeTexture', this._textureId);
      if (isSuccess == 1) {
        print("移除纹理成功");
      }
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isTextureReady
        ? Container(
            width: this.widget.width,
            height: this.widget.height,
            child: Texture(
              textureId: _textureId,
            ),
          )
        : Container(color: Colors.grey);
  }
}
