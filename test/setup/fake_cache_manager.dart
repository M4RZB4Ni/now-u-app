// Copyright 2020 Rene Floor. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.
// Taken from https://github.com/Baseflow/flutter_cached_network_image/blob/develop/test/fake_cache_manager.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:app/assets/components/custom_network_image.dart';

class FakeCacheManager extends Mock implements CacheManager {
  void throwsNotFound(String url) {
    when(getFileStream(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    )).thenThrow(HttpExceptionWithStatus(404, 'Invalid statusCode: 404',
        uri: Uri.parse(url)));
  }

  ExpectedData returns(
    String url,
    List<int> imageData, {
    Duration delayBetweenChunks,
  }) {
    const chunkSize = 8;
    final chunks = <Uint8List>[
      for (int offset = 0; offset < imageData.length; offset += chunkSize)
        Uint8List.fromList(imageData.skip(offset).take(chunkSize).toList()),
    ];

    when(getFileStream(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    )).thenAnswer((realInvocation) => _createResultStream(
          url,
          chunks,
          imageData,
          delayBetweenChunks,
        ));

    return ExpectedData(
      chunks: chunks.length,
      totalSize: imageData.length,
      chunkSize: chunkSize,
    );
  }

  Stream<FileResponse> _createResultStream(
    String url,
    List<Uint8List> chunks,
    List<int> imageData,
    Duration delayBetweenChunks,
  ) async* {
    var totalSize = imageData.length;
    var downloaded = 0;
    for (var chunk in chunks) {
      downloaded += chunk.length;
      if (delayBetweenChunks != null) {
        await Future.delayed(delayBetweenChunks);
      }
      yield DownloadProgress(url, totalSize, downloaded);
    }
    var file = MemoryFileSystem().systemTempDirectory.childFile('test.jpg');
    await file.writeAsBytes(imageData);
    yield FileInfo(
        file, FileSource.Online, DateTime.now().add(Duration(days: 1)), url);
  }
}

class FakeImageCacheManager extends Mock implements ImageCacheManager {
  ExpectedData returns(
    String url,
    List<int> imageData, {
    Duration delayBetweenChunks,
  }) {
    const chunkSize = 8;
    final chunks = <Uint8List>[
      for (int offset = 0; offset < imageData.length; offset += chunkSize)
        Uint8List.fromList(imageData.skip(offset).take(chunkSize).toList()),
    ];

    when(getImageFile(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    )).thenAnswer((realInvocation) => _createResultStream(
          url,
          chunks,
          imageData,
          delayBetweenChunks,
        ));

    return ExpectedData(
      chunks: chunks.length,
      totalSize: imageData.length,
      chunkSize: chunkSize,
    );
  }

  Stream<FileResponse> _createResultStream(
    String url,
    List<Uint8List> chunks,
    List<int> imageData,
    Duration delayBetweenChunks,
  ) async* {
    var totalSize = imageData.length;
    var downloaded = 0;
    for (var chunk in chunks) {
      downloaded += chunk.length;
      if (delayBetweenChunks != null) {
        await Future.delayed(delayBetweenChunks);
      }
      yield DownloadProgress(url, totalSize, downloaded);
    }
    var file = MemoryFileSystem().systemTempDirectory.childFile('test.jpg');
    await file.writeAsBytes(imageData);
    yield FileInfo(
        file, FileSource.Online, DateTime.now().add(Duration(days: 1)), url);
  }
}

class ExpectedData {
  final int chunks;
  final int totalSize;
  final int chunkSize;

  const ExpectedData({this.chunks, this.totalSize, this.chunkSize});
}

class TestImageWidget extends StatelessWidget {
  final FakeCacheManager cacheManager;
  final ProgressIndicatorBuilder progressBuilder;
  final PlaceholderWidgetBuilder placeholderBuilder;
  final LoadingErrorWidgetBuilder errorBuilder;
  final String imageUrl;

  TestImageWidget({
    Key key,
    @required this.imageUrl,
    @required this.cacheManager,
    VoidCallback onProgress,
    VoidCallback onPlaceHolder,
    VoidCallback onError,
  })  : progressBuilder = getProgress(onProgress),
        placeholderBuilder = getPlaceholder(onPlaceHolder),
        errorBuilder = getErrorBuilder(onError),
        super(key: key);

  static ProgressIndicatorBuilder getProgress(VoidCallback onProgress) {
    if (onProgress == null) return null;
    return (context, url, progress) {
      onProgress();
      return CircularProgressIndicator();
    };
  }

  static PlaceholderWidgetBuilder getPlaceholder(VoidCallback onPlaceHolder) {
    if (onPlaceHolder == null) return null;
    return (context, url) {
      onPlaceHolder();
      return Placeholder();
    };
  }

  static LoadingErrorWidgetBuilder getErrorBuilder(VoidCallback onError) {
    if (onError == null) return null;
    return (context, error, stacktrace) {
      onError();
      return Icon(Icons.error);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        body: Center(
          child: CustomNetworkImage(
            imageUrl,
            cacheManager: cacheManager,
            progressIndicatorBuilder: progressBuilder,
            placeholder: placeholderBuilder,
            errorWidget: errorBuilder,
          ),
        ),
      ),
    );
  }
}
