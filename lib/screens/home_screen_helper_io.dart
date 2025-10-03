import 'package:flutter/material.dart';

class HomeScreenHelper {
  static Widget buildWebVideoPlayer(String videoUrl) {
    return Container(
      height: 300,
      color: Colors.black87,
      child: const Center(
        child: Text(
          'Preview available on web only',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  static Widget buildWebImageViewer(String imageUrl) {
    return Container(
      height: 300,
      color: Colors.black87,
      child: const Center(
        child: Text(
          'Preview available on web only',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}


